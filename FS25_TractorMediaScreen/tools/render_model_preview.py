"""Render the actual generated mesh to a PNG without a game or external library."""
from pathlib import Path
import math
import struct
import zlib
from generate_monitor import meshes

MOD = Path(__file__).resolve().parents[1]


def main():
    width, height = 1000, 580
    pixels = bytearray(bytes((16, 33, 42)) * width * height)
    depths = [-math.inf] * (width * height)
    faces = []
    for ox, oy, yaw, pitch in ((270, 220, 0, 0), (745, 210, -.65, .25)):
        def project(point):
            x, y, z = point
            xx, zz = x*math.cos(yaw)+z*math.sin(yaw), -x*math.sin(yaw)+z*math.cos(yaw)
            yy, depth = y*math.cos(pitch)-zz*math.sin(pitch), y*math.sin(pitch)+zz*math.cos(pitch)
            return ox+xx*1100, oy-yy*1100, depth
        for mesh in meshes():
            for triangle in mesh.triangles:
                points = [project(mesh.vertices[i][0]) for i in triangle]
                a, b, c = points
                area = (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
                if area >= 0:
                    continue
                shade = .8 if mesh.vertices[triangle[0]][1][2] == 0 else 1
                color = bytes(int(channel*shade) for channel in mesh.color)
                faces.append((sum(p[2] for p in points), points, color))
    for _, points, color in faces:
        ta, tb, tc = points
        denominator = (tb[1]-tc[1])*(ta[0]-tc[0])+(tc[0]-tb[0])*(ta[1]-tc[1])
        ymin = max(0, math.floor(min(p[1] for p in points)))
        ymax = min(height-1, math.ceil(max(p[1] for p in points)))
        for y in range(ymin, ymax+1):
            xs = []
            for a, b in zip(points, points[1:]+points[:1]):
                if min(a[1],b[1]) <= y+.5 < max(a[1],b[1]):
                    xs.append(a[0]+(y+.5-a[1])/(b[1]-a[1])*(b[0]-a[0]))
            if len(xs) < 2:
                continue
            left, right = max(0, math.ceil(min(xs)-.5)), min(width-1, math.floor(max(xs)-.5))
            for x in range(left, right+1):
                u = ((tb[1]-tc[1])*(x+.5-tc[0])+(tc[0]-tb[0])*(y+.5-tc[1]))/denominator
                v = ((tc[1]-ta[1])*(x+.5-tc[0])+(ta[0]-tc[0])*(y+.5-tc[1]))/denominator
                depth = u*ta[2]+v*tb[2]+(1-u-v)*tc[2]
                if depth < depths[y*width+x]:
                    continue
                depths[y*width+x] = depth
                index = (y*width+x)*3
                pixels[index:index+3] = color
    raw = b"".join(b"\0"+pixels[y*width*3:(y+1)*width*3] for y in range(height))
    def chunk(name, data):
        return struct.pack(">I", len(data))+name+data+struct.pack(">I", zlib.crc32(name+data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">2I5B",width,height,8,2,0,0,0))
    png += chunk(b"IDAT",zlib.compress(raw,9))+chunk(b"IEND",b"")
    destination = MOD / "assets/monitor/monitor_preview.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(png)
    print(destination)


if __name__ == "__main__":
    main()
