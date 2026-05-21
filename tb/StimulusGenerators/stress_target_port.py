#!/usr/bin/env python3
"""
Generate stimulus files that stress a single output port by having all other ports
send traffic addressed to that port.

Output: tb/stimulus_port0.txt .. tb/stimulus_port3.txt

Usage:
  python3 tb/stress_target_port.py --target 2 --frames 2000 --payload 256

Defaults:
  target=3, frames=2000 per sender, payload=512 bytes

The script creates frames with Ethernet-like layout:
  preamble: 0x55 x7, sfd 0xD5
  dst MAC (6 bytes) -> set to target port's prefix
  src MAC (6 bytes) -> unique per sender
  payload (variable)
  fcs (4 bytes) -> random placeholder

Be cautious: large frame counts produce large files and long simulations.
"""

import argparse
import os
import random
from pathlib import Path

TB_DIR = Path(__file__).resolve().parents[0]

# MAC prefixes by port (matches testbench expectation)
PORT_MAC_PREFIX = {
    0: [0x02, 0x00],
    1: [0x02, 0x10],
    2: [0x02, 0x20],
    3: [0x02, 0x30],
}

PREAMBLE = [0x55] * 7
SFD = [0xD5]

# ---------------------------------------------------------------------------
# CRC32 lookup table (MSB-first, poly 0x04C11DB7) — same as GenerateValidFramesFor4Ports
# ---------------------------------------------------------------------------
CRC_TABLE = [
    0x00000000, 0x04C11DB7, 0x09823B6E, 0x0D4326D9,
    0x130476DC, 0x17C56B6B, 0x1A864DB2, 0x1E475005,
    0x2608EDB8, 0x22C9F00F, 0x2F8AD6D6, 0x2B4BCB61,
    0x350C9B64, 0x31CD86D3, 0x3C8EA00A, 0x384FBDBD,
    0x4C11DB70, 0x48D0C6C7, 0x4593E01E, 0x4152FDA9,
    0x5F15ADAC, 0x5BD4B01B, 0x569796C2, 0x52568B75,
    0x6A1936C8, 0x6ED82B7F, 0x639B0DA6, 0x675A1011,
    0x791D4014, 0x7DDC5DA3, 0x709F7B7A, 0x745E66CD,
    0x9823B6E0, 0x9CE2AB57, 0x91A18D8E, 0x95609039,
    0x8B27C03C, 0x8FE6DD8B, 0x82A5FB52, 0x8664E6E5,
    0xBE2B5B58, 0xBAEA46EF, 0xB7A96036, 0xB3687D81,
    0xAD2F2D84, 0xA9EE3033, 0xA4AD16EA, 0xA06C0B5D,
    0xD4326D90, 0xD0F37027, 0xDDB056FE, 0xD9714B49,
    0xC7361B4C, 0xC3F706FB, 0xCEB42022, 0xCA753D95,
    0xF23A8028, 0xF6FB9D9F, 0xFBB8BB46, 0xFF79A6F1,
    0xE13EF6F4, 0xE5FFEB43, 0xE8BCCD9A, 0xEC7DD02D,
    0x34867077, 0x30476DC0, 0x3D044B19, 0x39C556AE,
    0x278206AB, 0x23431B1C, 0x2E003DC5, 0x2AC12072,
    0x128E9DCF, 0x164F8078, 0x1B0CA6A1, 0x1FCDBB16,
    0x018AEB13, 0x054BF6A4, 0x0808D07D, 0x0CC9CDCA,
    0x7897AB07, 0x7C56B6B0, 0x71159069, 0x75D48DDE,
    0x6B93DDDB, 0x6F52C06C, 0x6211E6B5, 0x66D0FB02,
    0x5E9F46BF, 0x5A5E5B08, 0x571D7DD1, 0x53DC6066,
    0x4D9B3063, 0x495A2DD4, 0x44190B0D, 0x40D816BA,
    0xACA5C697, 0xA864DB20, 0xA527FDF9, 0xA1E6E04E,
    0xBFA1B04B, 0xBB60ADFC, 0xB6238B25, 0xB2E29692,
    0x8AAD2B2F, 0x8E6C3698, 0x832F1041, 0x87EE0DF6,
    0x99A95DF3, 0x9D684044, 0x902B669D, 0x94EA7B2A,
    0xE0B41DE7, 0xE4750050, 0xE9362689, 0xEDF73B3E,
    0xF3B06B3B, 0xF771768C, 0xFA325055, 0xFEF34DE2,
    0xC6BCF05F, 0xC27DEDE8, 0xCF3ECB31, 0xCBFFD686,
    0xD5B88683, 0xD1799B34, 0xDC3ABDED, 0xD8FBA05A,
    0x690CE0EE, 0x6DCDFD59, 0x608EDB80, 0x644FC637,
    0x7A089632, 0x7EC98B85, 0x738AAD5C, 0x774BB0EB,
    0x4F040D56, 0x4BC510E1, 0x46863638, 0x42472B8F,
    0x5C007B8A, 0x58C1663D, 0x558240E4, 0x51435D53,
    0x251D3B9E, 0x21DC2629, 0x2C9F00F0, 0x285E1D47,
    0x36194D42, 0x32D850F5, 0x3F9B762C, 0x3B5A6B9B,
    0x0315D626, 0x07D4CB91, 0x0A97ED48, 0x0E56F0FF,
    0x1011A0FA, 0x14D0BD4D, 0x19939B94, 0x1D528623,
    0xF12F560E, 0xF5EE4BB9, 0xF8AD6D60, 0xFC6C70D7,
    0xE22B20D2, 0xE6EA3D65, 0xEBA91BBC, 0xEF68060B,
    0xD727BBB6, 0xD3E6A601, 0xDEA580D8, 0xDA649D6F,
    0xC423CD6A, 0xC0E2D0DD, 0xCDA1F604, 0xC960EBB3,
    0xBD3E8D7E, 0xB9FF90C9, 0xB4BCB610, 0xB07DABA7,
    0xAE3AFBA2, 0xAAFBE615, 0xA7B8C0CC, 0xA379DD7B,
    0x9B3660C6, 0x9FF77D71, 0x92B45BA8, 0x9675461F,
    0x8832161A, 0x8CF30BAD, 0x81B02D74, 0x857130C3,
    0x5D8A9099, 0x594B8D2E, 0x5408ABF7, 0x50C9B640,
    0x4E8EE645, 0x4A4FFBF2, 0x470CDD2B, 0x43CDC09C,
    0x7B827D21, 0x7F436096, 0x7200464F, 0x76C15BF8,
    0x68860BFD, 0x6C47164A, 0x61043093, 0x65C52D24,
    0x119B4BE9, 0x155A565E, 0x18197087, 0x1CD86D30,
    0x029F3D35, 0x065E2082, 0x0B1D065B, 0x0FDC1BEC,
    0x3793A651, 0x3352BBE6, 0x3E119D3F, 0x3AD08088,
    0x2497D08D, 0x2056CD3A, 0x2D15EBE3, 0x29D4F654,
    0xC5A92679, 0xC1683BCE, 0xCC2B1D17, 0xC8EA00A0,
    0xD6AD50A5, 0xD26C4D12, 0xDF2F6BCB, 0xDBEE767C,
    0xE3A1CBC1, 0xE760D676, 0xEA23F0AF, 0xEEE2ED18,
    0xF0A5BD1D, 0xF464A0AA, 0xF9278673, 0xFDE69BC4,
    0x89B8FD09, 0x8D79E0BE, 0x803AC667, 0x84FBDBD0,
    0x9ABC8BD5, 0x9E7D9662, 0x933EB0BB, 0x97FFAD0C,
    0xAFB010B1, 0xAB710D06, 0xA6322BDF, 0xA2F33668,
    0xBCB4666D, 0xB8757BDA, 0xB5365D03, 0xB1F740B4,
]


def crc32_table(data: bytes) -> bytes:
    crc = 0xFFFFFFFF
    for byte in data:
        top = (crc >> 24) ^ byte
        crc = ((crc << 8) & 0xFFFFFFFF) ^ CRC_TABLE[top & 0xFF]
    crc ^= 0xFFFFFFFF
    import struct
    return struct.pack(">I", crc)


def bytes_to_hexline(bts):
    return " ".join(f"{x:02X}" for x in bts)


def mac_bytes_to_str(mac_bytes):
    return ":".join(f"{b:02X}" for b in mac_bytes)


def gen_frame(dst_bytes, src_bytes, payload_size):
    # payload
    payload = bytes(random.getrandbits(8) for _ in range(payload_size))
    import struct
    length_field = struct.pack(">H", len(payload))
    header = dst_bytes + src_bytes + length_field
    frame = header + payload
    fcs = crc32_table(frame)
    wire = PREAMBLE + SFD + list(frame) + list(fcs)
    return wire, dst_bytes, src_bytes, list(fcs)


def write_stim_files(target, frames_per_sender, payload_size, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    # Initialize files for ports 0..3
    files = {p: open(out_dir / f"stimulus_port{p}.txt", "w") for p in range(4)}

    learned_mac = bytes([PORT_MAC_PREFIX[target][0], PORT_MAC_PREFIX[target][1], 0x00, 0x00, 0x00, 0xFF])
    learned_mac_str = mac_bytes_to_str(learned_mac)
    learn_src = learned_mac
    learn_dst = bytes([0x02, 0x00, 0x00, 0x00, 0x00, 0x01])

    try:
        # First let the target port advertise the MAC that should be learned.
        learn_frame, _, _, _ = gen_frame(learn_dst, learn_src, payload_size)
        learn_src_str = mac_bytes_to_str(learn_src)
        files[target].write(
            f"# Learn port {target} MAC first: dst=02:00:00:00:00:01 src={learn_src_str} payload={payload_size}\n"
        )
        files[target].write(bytes_to_hexline(learn_frame) + "\n\n")

        # Then generate traffic from the other ports to the learned MAC on port 3.
        for sender in range(4):
            if sender == target:
                continue

            for i in range(1, frames_per_sender + 1):
                src_mac = bytes([PORT_MAC_PREFIX[sender][0], PORT_MAC_PREFIX[sender][1], 0x00, 0x00, 0x00, sender])
                frame, _, _, _ = gen_frame(learned_mac, src_mac, payload_size)
                # comment line
                src_str = mac_bytes_to_str(src_mac)
                files[sender].write(f"# Port {sender} -> Port {target} frame {i}: dst={learned_mac_str} src={src_str} payload={payload_size}\n")
                # bytes line
                files[sender].write(bytes_to_hexline(frame) + "\n\n")
    finally:
        for f in files.values():
            f.close()


def main():
    parser = argparse.ArgumentParser(description="Generate stress-test stimulus files targeting one switch output port")
    parser.add_argument("--target", type=int, default=3, choices=range(4), help="Target output port (0-3)")
    parser.add_argument("--frames", type=int, default=2000, help="Number of frames per sender (each of the 3 senders)")
    parser.add_argument("--payload", type=int, default=512, help="Payload size in bytes (not including headers)")
    parser.add_argument("--out", type=str, default="tb", help="Output directory for stimulus files (relative to workspace)" )
    parser.add_argument("--max-frame-size", type=int, default=1518, help="Maximum total frame size (including preamble/mac/fcs). Will truncate payload if exceeded.")
    args = parser.parse_args()

    out_dir = Path(args.out)

    # compute header length: preamble+sfd(8) + dst(6) + src(6) + fcs(4)
    header_len = len(PREAMBLE) + 6 + 6 + 4
    if args.payload + header_len > args.max_frame_size:
        max_payload = args.max_frame_size - header_len
        print(f"Requested payload {args.payload} too large, truncating to {max_payload}")
        payload_size = max(0, max_payload)
    else:
        payload_size = args.payload

    total_frames = args.frames * 3
    est_size_each = (header_len + payload_size) * args.frames
    print(f"Generating {args.frames} frames per sender -> {total_frames} frames total targeting port {args.target}")
    print(f"Each file approx {est_size_each/1024:.1f} KB")

    # Safety limit to avoid runaway files
    if args.frames > 20000:
        print("frames per sender too large (>20000). Aborting for safety.")
        return

    write_stim_files(args.target, args.frames, payload_size, out_dir)
    print(f"Wrote stimulus files to {out_dir}")


if __name__ == '__main__':
    main()
