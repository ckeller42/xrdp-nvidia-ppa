#!/usr/bin/env python3
"""Count 'box pixels' in dumped 32bpp RDP pointers: alpha==0 pixels that a client which
ignores the alpha channel would draw opaque, because the AND mask does not mark them
transparent. With a second argument CUTOFF also count 'halo pixels' (0 < alpha < CUTOFF),
which such clients draw as an opaque dark outline. Exit 0 only if both totals are 0."""
import glob, sys

cutoff = int(sys.argv[2]) if len(sys.argv) > 2 else 0
halo_total = 0

total = 0; seen = 0
for p in sorted(glob.glob(sys.argv[1] + "/ptr-*.bin")):
    raw = open(p, "rb").read()
    hdr, data = raw.split(b"\n", 1)
    w, h, bpp, xlen, alen = map(int, hdr.split())
    if bpp != 32:
        continue
    seen += 1
    xor, andm = data[:xlen], data[xlen:xlen + alen]
    and_stride = ((w + 15) // 16) * 2          # 1bpp rows padded to 16 bits
    box = 0
    halo = sum(1 for i in range(w * h) if 0 < xor[i * 4 + 3] < cutoff)
    halo_total += halo
    for y in range(h):
        for x in range(w):
            a = xor[(y * w + x) * 4 + 3]
            masked = (andm[y * and_stride + x // 8] >> (7 - x % 8)) & 1 if alen else 0
            if a == 0 and not masked:
                box += 1
    print(f"{p.rsplit('/', 1)[1]}: {w}x{h} bpp{bpp} and_len={alen} box_pixels={box} halo_pixels={halo}")
    total += box
print(f"POINTERS_32BPP={seen} BOX_PIXELS={total} HALO_PIXELS={halo_total} (cutoff {cutoff})")
sys.exit(0 if seen and total == 0 and halo_total == 0 else 1)
