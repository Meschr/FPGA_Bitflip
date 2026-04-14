def crc16_mac(mac_int: int) -> int:
    c = 0xFFFF
    for i in range(47, -1, -1):
        b = ((mac_int >> i) & 1) ^ ((c >> 15) & 1)
        c = (c << 1) & 0xFFFF
        if b:
            c ^= 0x8005
    return c & 0x1FFF


def mac_int_to_str(mac_int: int) -> str:
    bytes_ = [(mac_int >> (8 * i)) & 0xFF for i in range(5, -1, -1)]
    return ":".join(f"{b:02X}" for b in bytes_)


test_macs = [
    0xAABBCCDDEEFF,
    0x112233445566,
    0xDEADBEEF0001,
    0xCAFEBABE1234,
    0x001122334455,
    0xFFFFFFFFFFFF,
    0x000000000000,
    0x010000000000,
]

print("=" * 45)
print(f"  {'MAC-Adresse':<21}  {'Hash (dez)':>10}  {'Hash (hex)':>8}")
print("=" * 45)
for mac in test_macs:
    h = crc16_mac(mac)
    print(f"  {mac_int_to_str(mac):<21}  {h:>10}  {h:>8} (0x{h:04X})")
print("=" * 45)