import struct
from pathlib import Path

project_root = Path(__file__).resolve().parents[2]
data = (project_root / "data" / "ne_10m_land.shp").read_bytes()
records = []
off = 100
while off + 8 <= len(data):
    length = struct.unpack(">i", data[off + 4:off + 8])[0] * 2
    c = off + 8
    shape_type = struct.unpack("<i", data[c:c + 4])[0]
    if shape_type == 5:
        minx, miny, maxx, maxy = struct.unpack("<4d", data[c + 4:c + 36])
        part_count, point_count = struct.unpack("<2i", data[c + 36:c + 44])
        p = c + 44
        starts = list(struct.unpack("<" + "i" * part_count, data[p:p + part_count * 4]))
        p += part_count * 4
        coords = list(struct.iter_unpack("<2d", data[p:p + point_count * 16]))
        starts.append(point_count)
        rings = [coords[starts[i]:starts[i + 1]] for i in range(part_count)]
        records.append((minx, miny, maxx, maxy, rings))
    off = c + length

def ring_contains(ring, x, y):
    inside = False
    n = len(ring)
    for i in range(n):
        j = n - 1 if i == 0 else i - 1
        xi, yi = ring[i]
        xj, yj = ring[j]
        if ((yi > y) != (yj > y)) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
    return inside

for x, y in [(-114,22.8),(0,0),(-140,0),(10,40),(114,22.8),(-116,32)]:
    hits = []
    for idx, (minx,miny,maxx,maxy,rings) in enumerate(records):
        if not (minx <= x <= maxx and miny <= y <= maxy):
            continue
        n = sum(ring_contains(r, x, y) for r in rings)
        if n % 2:
            hits.append((idx, n, len(rings), (minx,miny,maxx,maxy)))
    print((x,y), "matches", hits[:8], "count", len(hits))
print("records", len(records), "first rings", len(records[0][4]))
