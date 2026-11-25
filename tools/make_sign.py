"""Gera a plaquinha fincada dos canteiros de obra, em assets/custom/:
sign_post.png (estaca) e sign_board.png (tábua, esticada na horizontal conforme o nome).

Uso, na raiz do projeto: python tools/make_sign.py
"""
import os
import struct
import zlib

## Cada caractere do desenho vira um bloco de PIXEL x PIXEL, para o visual "pixelado".
PIXEL = 2
OUTPUT_DIR = "assets/custom"

COLORS = {
    ".": (0, 0, 0, 0),
    "K": (20, 24, 32, 255),      # contorno
    "D": (112, 60, 48, 255),     # sombra
    "M": (166, 106, 62, 255),    # veios
    "O": (242, 162, 82, 255),    # madeira
    "L": (255, 210, 128, 255),   # brilho
}

POST = [
    ".KKKKK.",
    "KDLLLOK",
    "KDOLLOK",
    "KDOLOOK",
] + ["KDOLLOK"] * 13 + [
    "KDOOLOK",
    "KDMOLOK",
    "KDOLLOK",
    "KDOLLK.",
    "KDOLMK.",
    ".KDLLOK",
    ".KDMLOK",
    ".KDOLOK",
    ".KDOOOK",
]

BOARD = [
    "..KKKKKKKKKKKKKKKKKKKKKKKKKKKK..",
    ".KDLLLLLLLLOOLLLLLLLLLLLMLLLLLK.",
    "KDDOOOOOOOOOOOOOOOOOOOOOOOOOOOOK",
    "KDDOOMMOOOOOOOOOOOOOOOOOOOOMMOOK",
    "KDDOOOOOOOOOOOOOOOOOOOOOOOOOOOK.",
    ".KDDOOOOOOOOOOOOOOOOOOOOOOOOOOK.",
    ".KDOOOOOOOOOOOOOOOOOOOOOOOOOOOOK",
    "KDDOOOOOOOOOOOOOOOOOOOOOOOOMOOOK",
    "KDDOMMMOOOOOOOOOOOOOOOOOOOOOOOOK",
    "KDOOOOOOOOOOOOOOOOOOOOOOOMMOOOK.",
    ".KDOOOOOOOOMOOOOOOOOOOOOOOOOOOK.",
    ".KDDDDDDDDDDDDDDDDDDDDDDDDDDDDK.",
    "..KKKKKKKKKKKKKKKKKKKKKKKKKKKK..",
]


def write_png(path, art):
    width = len(art[0])
    assert all(len(row) == width for row in art), "linhas com larguras diferentes em " + path
    rows = []
    for line in art:
        row = b"".join(bytes(COLORS[char]) * PIXEL for char in line)
        rows.extend([b"\x00" + row] * PIXEL)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    header = struct.pack(">IIBBBBB", width * PIXEL, len(art) * PIXEL, 8, 6, 0, 0, 0)
    with open(path, "wb") as file:
        file.write(b"\x89PNG\r\n\x1a\n")
        file.write(chunk(b"IHDR", header))
        file.write(chunk(b"IDAT", zlib.compress(b"".join(rows), 9)))
        file.write(chunk(b"IEND", b""))
    print("gerado:", path)


os.makedirs(OUTPUT_DIR, exist_ok=True)
write_png(OUTPUT_DIR + "/sign_post.png", POST)
write_png(OUTPUT_DIR + "/sign_board.png", BOARD)
