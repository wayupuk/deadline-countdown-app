"""Packs PNG files into a Windows .ico (PNG-compressed entries). Usage: pack_ico.py out.ico in1.png in2.png ..."""
import struct
import sys


def size_of(png: bytes) -> tuple[int, int]:
    return struct.unpack('>II', png[16:24])


def main(out: str, inputs: list[str]) -> None:
    images = [open(p, 'rb').read() for p in inputs]
    header = struct.pack('<HHH', 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries, blobs = b'', b''
    for img in images:
        w, h = size_of(img)
        entries += struct.pack('<BBBBHHII', w % 256, h % 256, 0, 0, 1, 32, len(img), offset + len(blobs))
        blobs += img
    open(out, 'wb').write(header + entries + blobs)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:])
