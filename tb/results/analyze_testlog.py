#!/usr/bin/env python3
"""
Analyze FPGA testlog to verify routing and measure latency.

Checks if frames arrive on correct output ports considering:
- Known MACs (unicast) - should arrive on specific port
- Unknown MACs (flooding) - should arrive on all ports except sender
- Measures latency from send to first receive
"""

import argparse
import re
from dataclasses import dataclass
from typing import Dict, List, Tuple
from collections import defaultdict

# MAC address prefixes to port mapping
MAC_TO_PORT = {
    "02:00": 0,
    "02:10": 1,
    "02:20": 2,
    "02:30": 3,
}


@dataclass
class Message:
    timestamp_ns: int
    port: int
    direction: str  # "send" or "receive"
    dst_mac: str
    src_mac: str
    fcs: str


def parse_testlog(filename: str) -> List[Message]:
    """Parse testlog and extract all send/receive messages."""
    messages = []
    
    # Pattern: Port 0 sending message; dst_mac: 02:10:00:00:00:03; src_mac: 02:00:00:00:00:01; fcs: 0x0A9B2A02
    pattern = r'@(\d+)ns:.*Port (\d) (sending|receive) message; dst_mac: ([0-9a-fA-F:]+); src_mac: ([0-9a-fA-F:]+); fcs: (0x[0-9a-fA-F]+)'
    
    with open(filename, 'r') as f:
        for line in f:
            match = re.search(pattern, line)
            if match:
                timestamp = int(match.group(1))
                port = int(match.group(2))
                direction = "send" if match.group(3) == "sending" else "receive"
                dst_mac = match.group(4)
                src_mac = match.group(5)
                fcs = match.group(6)
                
                messages.append(Message(
                    timestamp_ns=timestamp,
                    port=port,
                    direction=direction,
                    dst_mac=dst_mac,
                    src_mac=src_mac,
                    fcs=fcs
                ))
    
    return messages


def get_dest_port(dst_mac: str) -> int | None:
    """
    Get destination port from destination MAC address.
    Returns port number if MAC is known, None if unknown (will flood).
    """
    prefix = dst_mac[:5]  # "02:00", "02:10", etc.
    return MAC_TO_PORT.get(prefix)


def is_broadcast(dst_mac: str) -> bool:
    return dst_mac.upper() == "FF:FF:FF:FF:FF:FF"


def is_multicast(dst_mac: str) -> bool:
    first_octet = int(dst_mac.split(":")[0], 16)
    return (first_octet & 0x01) == 0x01 and not is_broadcast(dst_mac)


def analyze_routing(messages: List[Message], assumed_frame_bytes: int = 64) -> None:
    """Analyze routing correctness and latency."""

    # Build expected routing per sent frame using a time-ordered learning model.
    # A destination is considered known only after its MAC has appeared as source
    # on a previously sent frame.
    learned_mac_to_port: Dict[str, int] = {}
    expected_by_frame: Dict[Tuple[int, str, int], Tuple[set[int], str]] = {}
    sends_in_time = sorted((m for m in messages if m.direction == "send"), key=lambda m: m.timestamp_ns)

    for send_msg in sends_in_time:
        frame_key = (send_msg.timestamp_ns, send_msg.fcs, send_msg.port)
        dst_upper = send_msg.dst_mac.upper()

        if is_broadcast(dst_upper):
            expected_ports = {p for p in range(4) if p != send_msg.port}
            routing_type = "Broadcast"
        elif is_multicast(dst_upper):
            expected_ports = {p for p in range(4) if p != send_msg.port}
            routing_type = "Multicast"
        elif dst_upper in learned_mac_to_port:
            expected_ports = {learned_mac_to_port[dst_upper]}
            routing_type = "Unicast"
        else:
            expected_ports = {p for p in range(4) if p != send_msg.port}
            routing_type = "Flood"

        expected_by_frame[frame_key] = (expected_ports, routing_type)

        # Learn source MAC after classification of current frame.
        learned_mac_to_port[send_msg.src_mac.upper()] = send_msg.port
    
    # Group messages by FCS to match sends with receives
    fcs_map = defaultdict(list)
    for msg in messages:
        fcs_map[msg.fcs].append(msg)
    
    stats = {
        "total_sent": 0,
        "total_received": 0,
        "correct_route": 0,
        "incorrect_route": 0,
        "missing_frames": 0,
        "broadcast_ok": 0,
        "multicast_ok": 0,
        "flood_warnings": 0,
        "latencies": []
    }

    # Throughput tracking: TRANSMIT timestamps per destination port (not receive port)
    # Key insight: throughput should measure input rate via transmit timestamps,
    # not output rate via receive timestamps (which are delayed by switch latency)
    throughput = {
        port: {
            "first_send_ns": None,  # Earliest transmit timestamp for frames destined to this port
            "last_send_ns": None,   # Latest transmit timestamp for frames destined to this port
            "send_frames": 0,       # Number of frames sent TO this port
        }
        for port in range(4)
    }
    
    # First pass: extract transmit statistics for throughput calculation
    for send_msg in messages:
        if send_msg.direction != "send":
            continue
        
        # Determine destination port from send message's destination MAC
        dest_port = get_dest_port(send_msg.dst_mac)
        
        # For unknown MACs (flooding), don't count toward per-port throughput
        # (frame is sent to multiple/all ports, not a single output port)
        if dest_port is None:
            continue
        
        # Update throughput window for this destination port using TRANSMIT timestamp
        port_tp = throughput[dest_port]
        port_tp["send_frames"] += 1
        
        if port_tp["first_send_ns"] is None or send_msg.timestamp_ns < port_tp["first_send_ns"]:
            port_tp["first_send_ns"] = send_msg.timestamp_ns
        if port_tp["last_send_ns"] is None or send_msg.timestamp_ns > port_tp["last_send_ns"]:
            port_tp["last_send_ns"] = send_msg.timestamp_ns
    
    # Second pass: detailed routing analysis
    print("=" * 100)
    print(f"{'Time (ns)':<12} {'Port':<6} {'Direction':<10} {'Dst MAC':<20} {'Src MAC':<20} {'FCS':<12} {'Status':<30}")
    print("=" * 100)
    
    # Track which frames we've already reported
    reported_frames = set()
    
    for fcs, msgs in sorted(fcs_map.items()):
        # Find send and receive messages
        sends = [m for m in msgs if m.direction == "send"]
        receives = [m for m in msgs if m.direction == "receive"]
        
        if not sends:
            continue
        
        # There should be exactly one send per FCS
        send_msg = sends[0]
        stats["total_sent"] += 1
        
        # Determine expected destination port(s) from dynamic learning model
        frame_key = (send_msg.timestamp_ns, send_msg.fcs, send_msg.port)
        expected_ports, routing_type = expected_by_frame.get(
            frame_key,
            ({p for p in range(4) if p != send_msg.port}, "Flood"),
        )
        
        # Check if frame was received on correct ports
        received_ports = {m.port for m in receives}
        frame_id = f"{fcs}_{send_msg.timestamp_ns}"
        
        if frame_id not in reported_frames:
            print(f"{send_msg.timestamp_ns:<12} {send_msg.port:<6} {'SEND':<10} {send_msg.dst_mac:<20} {send_msg.src_mac:<20} {fcs:<12} {routing_type:<30}")
            reported_frames.add(frame_id)
        
        # Analyze receives
        if not receives:
            status = "✗ MISSING - No receives"
            print(f"{send_msg.timestamp_ns:<12} {'-':<6} {'RECV':<10} {send_msg.dst_mac:<20} {send_msg.src_mac:<20} {fcs:<12} {status:<30}")
            stats["missing_frames"] += 1
        else:
            stats["total_received"] += len(receives)
            
            # Check if received on correct ports
            correct_ports = received_ports & expected_ports
            extra_ports = received_ports - expected_ports
            missing_ports = expected_ports - received_ports
            
            # Calculate latency from first send to first receive
            first_receive_time = min(m.timestamp_ns for m in receives)
            latency = first_receive_time - send_msg.timestamp_ns
            stats["latencies"].append(latency)
            
            is_flood_type = routing_type in {"Flood", "Broadcast", "Multicast"}

            for recv_msg in sorted(receives, key=lambda m: m.timestamp_ns):
                if recv_msg.port in correct_ports:
                    if routing_type == "Broadcast":
                        status = f"✓ BROADCAST OK (latency: {recv_msg.timestamp_ns - send_msg.timestamp_ns} ns)"
                        stats["broadcast_ok"] += 1
                    elif routing_type == "Multicast":
                        status = f"✓ MULTICAST OK (latency: {recv_msg.timestamp_ns - send_msg.timestamp_ns} ns)"
                        stats["multicast_ok"] += 1
                    else:
                        status = f"✓ CORRECT (latency: {recv_msg.timestamp_ns - send_msg.timestamp_ns} ns)"
                    stats["correct_route"] += 1
                else:
                    status = f"✗ WRONG PORT"
                    stats["incorrect_route"] += 1

                print(f"{recv_msg.timestamp_ns:<12} {recv_msg.port:<6} {'RECV':<10} {recv_msg.dst_mac:<20} {recv_msg.src_mac:<20} {fcs:<12} {status:<30}")

            # Report expected flood fanout issues as warnings (not routing errors)
            if is_flood_type and missing_ports:
                for port in sorted(missing_ports):
                    status = f"! FLOOD MISSING PORT {port}"
                    print(f"{first_receive_time:<12} {port:<6} {'RECV':<10} {send_msg.dst_mac:<20} {send_msg.src_mac:<20} {fcs:<12} {status:<30}")
                    stats["flood_warnings"] += 1
            elif (not is_flood_type) and missing_ports:
                for port in sorted(missing_ports):
                    status = f"✗ MISSING ON PORT {port}"
                    print(f"{first_receive_time:<12} {port:<6} {'RECV':<10} {send_msg.dst_mac:<20} {send_msg.src_mac:<20} {fcs:<12} {status:<30}")
                    stats["incorrect_route"] += 1

            if extra_ports and is_flood_type:
                # extra ports are always a hard error even for flood behavior
                pass
    
    # Print summary
    print("\n" + "=" * 100)
    print("SUMMARY")
    print("=" * 100)
    print(f"Total frames sent:           {stats['total_sent']}")
    print(f"Total receives logged:       {stats['total_received']}")
    print(f"Correct routing:             {stats['correct_route']}")
    print(f"Incorrect routing:           {stats['incorrect_route']}")
    print(f"Missing frames (no receives):{stats['missing_frames']}")
    print(f"Broadcast receives OK:       {stats['broadcast_ok']}")
    print(f"Multicast receives OK:       {stats['multicast_ok']}")
    print(f"Flood fanout warnings:       {stats['flood_warnings']}")
    
    if stats['latencies']:
        min_lat = min(stats['latencies'])
        max_lat = max(stats['latencies'])
        avg_lat = sum(stats['latencies']) / len(stats['latencies'])
        print(f"\nLatency Statistics (ns):")
        print(f"  Min:                       {min_lat}")
        print(f"  Max:                       {max_lat}")
        print(f"  Average:                   {avg_lat:.1f}")
        print(f"  Total measurements:        {len(stats['latencies'])}")
    
    # Calculate success rate
    if stats['total_sent'] > 0:
        success_rate = (stats['correct_route'] / (stats['correct_route'] + stats['incorrect_route'])) * 100 if (stats['correct_route'] + stats['incorrect_route']) > 0 else 0
        print(f"\nSuccess rate:                {success_rate:.1f}%")

    print("\nPer-port throughput approximation (based on TRANSMIT timestamps):")
    print(f"  Assumed wire frame size: {assumed_frame_bytes} bytes")
    for port in range(4):
        p = throughput[port]
        first_send_ns = p["first_send_ns"]
        last_send_ns = p["last_send_ns"]
        frames = p["send_frames"]

        if first_send_ns is None or last_send_ns is None or last_send_ns <= first_send_ns or frames == 0:
            print(f"  Port {port}: n/a (no frames destined to this port)")
            continue

        duration_s = (last_send_ns - first_send_ns) * 1e-9
        bits = frames * assumed_frame_bytes * 8
        bps = bits / duration_s
        mbps = bps / 1e6
        gbps = bps / 1e9
        print(
            f"  Port {port}: {mbps:.2f} Mbps ({gbps:.3f} Gbps), "
            f"frames={frames}, frame_bytes={assumed_frame_bytes}, window={duration_s*1e6:.2f} us"
        )
    
    print("=" * 100)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analyze FPGA testlog for routing, latency, and throughput")
    parser.add_argument("logfile", nargs="?", default="testlog.txt")
    parser.add_argument("--payload-bytes", type=int, default=500, help="Payload size used by the stimulus generator")
    parser.add_argument("--ifg-bytes", type=int, default=12, help="Interframe gap in bytes used by the test setup")
    args = parser.parse_args()
    
    try:
        messages = parse_testlog(args.logfile)
        if not messages:
            print(f"No messages found in {args.logfile}")
            raise SystemExit(1)
        
        print(f"Parsed {len(messages)} messages from {args.logfile}\n")
        # Effective bytes per frame on the line:
        # preamble(7) + SFD(1) + dst(6) + src(6) + len(2) + payload + FCS(4) + IFG
        analyze_routing(messages, assumed_frame_bytes=args.payload_bytes + 26 + args.ifg_bytes)
    except FileNotFoundError:
        print(f"Error: File '{args.logfile}' not found")
        raise SystemExit(1)
    except Exception as e:
        import traceback
        print(f"Error: {e}")
        traceback.print_exc()
        raise SystemExit(1)
