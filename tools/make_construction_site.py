"""Gera assets/custom/house_construction_site.png: o canteiro de obras da casa (2x2 tiles, 128x128 px).

Arte própria da equipe, desenhada por código para combinar com o Tiny Swords (contorno escuro).
Uso, na raiz do projeto: python tools/make_construction_site.py
"""
import os
import random
import struct
import zlib

SIZE = 128
OUTPUT = "assets/custom/house_construction_site.png"

CLEAR = (0, 0, 0, 0)
OUTLINE = (34, 32, 52, 255)
DIRT = (181, 137, 92, 255)
DIRT_DARK = (154, 112, 76, 255)
DIRT_LIGHT = (205, 164, 112, 255)
DIRT_EDGE = (120, 88, 66, 255)
WOOD = (150, 98, 64, 255)
WOOD_DARK = (108, 68, 52, 255)
WOOD_LIGHT = (196, 140, 86, 255)
ROPE = (236, 218, 170, 255)
ROPE_DARK = (170, 140, 104, 255)

random.seed(7)  # sempre o mesmo desenho
pixels = [[CLEAR] * SIZE for _ in range(SIZE)]


def put(x, y, color):
    if 0 <= x < SIZE and 0 <= y < SIZE:
        pixels[y][x] = color


def rect(x0, y0, x1, y1, color):
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(x, y, color)


def draw_dirt(left, top, right, bottom):
    """Retângulo de terra remexida, com bordas irregulares em blocos de 4 px."""
    inside = set()
    jitter = {}
    for y in range(top, bottom):
        for x in range(left, right):
            side = jitter.setdefault(("y", y // 4), (random.randint(0, 4), random.randint(0, 4)))
            cap = jitter.setdefault(("x", x // 4), (random.randint(0, 4), random.randint(0, 4)))
            corner = min(x - left, right - 1 - x) + min(y - top, bottom - 1 - y)
            if left + side[0] <= x < right - side[1] and top + cap[0] <= y < bottom - cap[1] and corner > 7:
                inside.add((x, y))
    for x, y in inside:
        edge = any((x + dx, y + dy) not in inside for dx in (-2, 0, 2) for dy in (-2, 0, 2))
        put(x, y, DIRT_EDGE if edge else DIRT)
    # Torrões e sulcos.
    for _ in range(70):
        x, y = random.randint(left + 8, right - 14), random.randint(top + 8, bottom - 10)
        color = random.choice((DIRT_DARK, DIRT_DARK, DIRT_LIGHT))
        rect(x, y, x + random.choice((2, 4, 6)), y + 2, color)


def draw_rope(x0, y0, x1, y1, sag):
    """Corda esticada entre duas estacas, com uma leve barriga."""
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        t = i / steps
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t + sag * 4 * t * (1 - t))
        if abs(x1 - x0) >= abs(y1 - y0):
            put(x, y - 1, OUTLINE)
            put(x, y, ROPE)
            put(x, y + 1, ROPE_DARK)
            put(x, y + 2, OUTLINE)
        else:
            put(x - 1, y, OUTLINE)
            put(x, y, ROPE)
            put(x + 1, y, ROPE_DARK)
            put(x + 2, y, OUTLINE)


def draw_stake(x, foot, height=26):
    """Estaca de madeira com contorno; (x, foot) é o centro da base."""
    top = foot - height
    rect(x - 7, foot - 1, x + 8, foot + 3, DIRT_EDGE)  # sombra
    rect(x - 5, top + 2, x + 5, foot, OUTLINE)
    rect(x - 3, top, x + 3, foot + 2, OUTLINE)
    rect(x - 3, top + 2, x + 3, foot, WOOD)
    rect(x - 3, top + 2, x - 1, foot, WOOD_LIGHT)
    rect(x + 1, top + 2, x + 3, foot, WOOD_DARK)
    rect(x - 3, top + 2, x + 3, top + 5, WOOD_LIGHT)  # topo cortado
    rect(x - 3, top + 8, x + 3, top + 11, ROPE)  # amarração


def write_png(path):
    raw = b"".join(b"\x00" + bytes(c for pixel in row for c in pixel) for row in pixels)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as file:
        file.write(b"\x89PNG\r\n\x1a\n")
        file.write(chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)))
        file.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        file.write(chunk(b"IEND", b""))


LEFT, RIGHT, BACK, FRONT = 12, 115, 34, 118

draw_dirt(5, 18, 123, 126)
# Fundo primeiro, frente por último, para a frente ficar por cima.
draw_rope(LEFT, BACK - 17, RIGHT, BACK - 17, 4)
draw_rope(LEFT, BACK - 17, LEFT, FRONT - 17, 0)
draw_rope(RIGHT, BACK - 17, RIGHT, FRONT - 17, 0)
draw_stake(LEFT, BACK)
draw_stake(RIGHT, BACK)
draw_rope(LEFT, FRONT - 17, RIGHT, FRONT - 17, 6)
draw_stake(LEFT, FRONT)
draw_stake(RIGHT, FRONT)
write_png(OUTPUT)
print("gerado:", OUTPUT)
