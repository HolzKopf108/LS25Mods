"""Eigene Monitorgeometrie, BC1-DDS und Modellvorschau mit Python-Standardbibliothek.

Koordinaten in Metern: X rechts, Y oben, sichtbare Bildschirmseite +Z.
Formatabgleich am 04.10.2026:
https://i3d.giants.ch/schema/i3d-1.6.xsd
https://gdn.giants-software.com/documentation_i3d.php
FS25-Exporter 10.x, _xmlWriteShape_Mesh / _xmlBuild:
https://github.com/dtapgaming/GiantsExporterRework-Blender/blob/main/io_export_i3d_reworked/i3d_export.py
Es werden keine Geometrie, Textur oder Implementierung fremder Projekte kopiert.
Inline-I3D ist ein Entwicklungsasset. GE10-Import und FS25-Sichttest stehen aus.
"""

from pathlib import Path
import math
import struct
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[1]
ASSETS = MOD / "assets" / "monitor"
COLORS = ((210, 215, 214), (211, 195, 65), (62, 190, 190), (87, 178, 93),
          (183, 79, 182), (195, 72, 71), (68, 92, 187))


def xyz(values):
    return " ".join(f"{v:.7g}" for v in values)


class Mesh:
    def __init__(self, name, color):
        self.name, self.color = name, color
        self.vertices, self.triangles = [], []

    def face(self, points, normal, uv=None):
        start = len(self.vertices)
        if uv is None:
            uv = [(0, 0), (1, 0), (1, 1), (0, 1)][:len(points)]
        self.vertices.extend(zip(points, [normal] * len(points), uv))
        self.triangles.extend((start, start + i, start + i + 1)
                              for i in range(1, len(points) - 1))

    def box(self, center, size):
        x, y, z = center
        a, b, c = (s / 2 for s in size)
        self.face([(x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)], (0,0,1))
        self.face([(x+a,y-b,z-c),(x-a,y-b,z-c),(x-a,y+b,z-c),(x+a,y+b,z-c)], (0,0,-1))
        self.face([(x+a,y-b,z+c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x+a,y+b,z+c)], (1,0,0))
        self.face([(x-a,y-b,z-c),(x-a,y-b,z+c),(x-a,y+b,z+c),(x-a,y+b,z-c)], (-1,0,0))
        self.face([(x-a,y+b,z+c),(x+a,y+b,z+c),(x+a,y+b,z-c),(x-a,y+b,z-c)], (0,1,0))
        self.face([(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y-b,z+c),(x-a,y-b,z+c)], (0,-1,0))

    def shell(self, width, height, depth, bevel):
        # Eight corner points, counterclockwise as seen from +Z.
        a, b = width / 2, height / 2
        ring = [(-a+bevel,-b),(a-bevel,-b),(a,-b+bevel),(a,b-bevel),
                (a-bevel,b),(-a+bevel,b),(-a,b-bevel),(-a,-b+bevel)]
        for front, normal in ((True, (0,0,1)), (False, (0,0,-1))):
            points = [(x,y,depth/2 if front else -depth/2) for x,y in ring]
            if not front:
                points.reverse()
            for i in range(1, len(points)-1):
                self.face([points[0],points[i],points[i+1]], normal, [(0,0)]*3)
        for i, (x1,y1) in enumerate(ring):
            x2, y2 = ring[(i+1) % len(ring)]
            length = math.hypot(x2-x1, y2-y1)
            self.face([(x1,y1,depth/2),(x1,y1,-depth/2),
                       (x2,y2,-depth/2),(x2,y2,depth/2)],
                      ((y2-y1)/length, -(x2-x1)/length, 0))


def meshes():
    display = Mesh("display", (24, 55, 62))
    display.face([(-.128,-.072,.021),(.128,-.072,.021),
                  (.128,.072,.021),(-.128,.072,.021)], (0,0,1))
    case = Mesh("housing", (51, 61, 65))
    case.shell(.286, .177, .040, .009)
    mount = Mesh("mount", (32, 40, 44))
    mount.box((0,-.100,-.045), (.025,.195,.027))
    mount.box((0,-.007,-.035), (.082,.056,.030))
    mount.box((0,-.204,-.024), (.093,.018,.105))
    details = Mesh("details", (145, 158, 162))
    # Small corner fasteners and lower bezel power button.
    for x in (-.136,.136):
        for y in (-.080,.080):
            details.box((x,y,.0205),(.0035,.0035,.001))
    details.box((.108,-.080,.0205), (.011,.002,.001))
    return [display, case, mount, details]


def make_i3d(model):
    ET.register_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")
    root = ET.Element("i3D", {"name":"TractorMediaScreen", "version":"1.6",
        "{http://www.w3.org/2001/XMLSchema-instance}noNamespaceSchemaLocation":
        "http://i3d.giants.ch/schema/i3d-1.6.xsd"})
    export = ET.SubElement(ET.SubElement(root,"Asset"),"Export")
    export.set("program", "TractorMediaScreen procedural model")
    export.set("version", "0.1.0.0")
    files = ET.SubElement(root,"Files")
    ET.SubElement(files,"File",fileId="1",filename="black.dds")
    materials = ET.SubElement(root,"Materials")
    for i, mesh in enumerate(model, 1):
        material = ET.SubElement(materials,"Material",materialId=str(i),name=mesh.name,
            diffuseColor="1 1 1 1" if i == 1 else xyz([v/255 for v in mesh.color]+[1]),
            specularColor="0 0 0" if i == 1 else "0.1 0.1 0.1")
        if i == 1:
            ET.SubElement(material,"Texture",fileId="1")
    shapes = ET.SubElement(root,"Shapes")
    for i, mesh in enumerate(model, 1):
        radius = max(math.sqrt(sum(v*v for v in p)) for p, _, _ in mesh.vertices)
        shape = ET.SubElement(shapes,"IndexedTriangleSet",name=mesh.name,shapeId=str(i),
            bvCenter="0 0 0",bvRadius=f"{radius:.7g}")
        vertices = ET.SubElement(shape,"Vertices",count=str(len(mesh.vertices)),normal="true",uv0="true")
        for position, normal, uv in mesh.vertices:
            ET.SubElement(vertices,"v",p=xyz(position),n=xyz(normal),t0=xyz(uv))
        triangles = ET.SubElement(shape,"Triangles",count=str(len(mesh.triangles)))
        for triangle in mesh.triangles:
            ET.SubElement(triangles,"t",vi=xyz(triangle))
        subsets = ET.SubElement(shape,"Subsets",count="1")
        ET.SubElement(subsets,"Subset",firstVertex="0",numVertices=str(len(mesh.vertices)),
                      firstIndex="0",numIndices=str(3*len(mesh.triangles)))
    scene = ET.SubElement(root,"Scene")
    group = ET.SubElement(scene,"TransformGroup",name="monitorRoot",nodeId="1")
    for i, mesh in enumerate(model, 1):
        ET.SubElement(group,"Shape",name=mesh.name,shapeId=str(i),materialIds=str(i),
            nodeId=str(i+2),castsShadows="false" if i==1 else "true",
            receiveShadows="false" if i==1 else "true",clipDistance="80")
    ET.indent(root, space="  ")
    ET.ElementTree(root).write(ASSETS / "monitor.i3d", encoding="utf-8", xml_declaration=True)


def rgb565(rgb):
    r,g,b = rgb
    return (r*31//255 << 11) | (g*63//255 << 5) | (b*31//255)


def expand565(value):
    return ((value>>11)*255//31, ((value>>5)&63)*255//63, (value&31)*255//31)


def encode_bc1(pixels, width, height):
    output = bytearray()
    for by in range(0, height, 4):
        for bx in range(0, width, 4):
            block = [pixels[min(by+y,height-1)*width+min(bx+x,width-1)] for y in range(4) for x in range(4)]
            # Endpoints selected along the block's dominant color range.
            lo = tuple(min(p[c] for p in block) for c in range(3))
            hi = tuple(max(p[c] for p in block) for c in range(3))
            c0,c1 = sorted((rgb565(lo),rgb565(hi)), reverse=True)
            if c0 == c1:
                if c0 < 65535:
                    c0 += 1
                else:
                    c1 -= 1
            a,b = expand565(c0),expand565(c1)
            palette = [a,b,tuple((2*a[c]+b[c])//3 for c in range(3)),
                       tuple((a[c]+2*b[c])//3 for c in range(3))]
            indices = 0
            for i, pixel in enumerate(block):
                best = min(range(4), key=lambda j: sum((pixel[c]-palette[j][c])**2 for c in range(3)))
                indices |= best << (2*i)
            output.extend(struct.pack("<HHI",c0,c1,indices))
    return output


def write_dds(path, width, height, pixel_function):
    pixels = [pixel_function(x,y) for y in range(height) for x in range(width)]
    levels, w, h = [], width, height
    while True:
        levels.append(encode_bc1(pixels,w,h))
        if w == h == 1:
            break
        nw,nh = max(1,w//2),max(1,h//2)
        pixels = [tuple(sum(pixels[min(2*y+dy,h-1)*w+min(2*x+dx,w-1)][c]
                                  for dy in range(2) for dx in range(2))//4 for c in range(3))
                  for y in range(nh) for x in range(nw)]
        w,h = nw,nh
    header = [124,0xA1007,height,width,len(levels[0]),0,len(levels)] + [0]*11
    header += [32,4,struct.unpack("<I",b"DXT1")[0],0,0,0,0,0]
    header += [0x401008,0,0,0,0]
    path.write_bytes(b"DDS " + struct.pack("<31I",*header) + b"".join(levels))


def test_pixel(x,y):
    color = (14,23,30)
    if 25 <= y < 325:
        color = COLORS[min(6,x*7//512)]
    if 350 <= y < 450:
        v = int(x/511*255)
        color = (v,v,v)
    if x < 4 or x > 507 or y < 4 or y > 507:
        color = (240,242,244)
    # Direction markers distinguish top/left from bottom/right after UV loading.
    if 14 <= x < 38 and 14 <= y < 55:
        color = (255,255,255)
    if 474 <= x < 498 and 457 <= y < 498:
        color = (232,92,54)
    # Circle is corrected for a 16:9 surface, despite the square DDS storage.
    ring = math.sqrt(((x-256)/105)**2 + ((y-230)/(105*16/9))**2)
    if .965 < ring < 1.035:
        color = (245,245,245)
    if abs(x-256) < 2 or abs(y-230) < 3:
        color = (20,25,32)
    return color


def icon_pixel(x,y):
    color = (12+y//35,29+y//22,39+y//18)
    if y > 410-(x//7):
        color = (39,83,63)
    if y > 467-(x//11):
        color = (67,111,76)
    if 237 <= x < 276 and 308 <= y < 414 or 180 <= x < 335 and 401 <= y < 421:
        color = (159,178,180)
    if 68 <= x < 445 and 114 <= y < 334:
        color = (222,232,228)
    if 77 <= x < 436 and 123 <= y < 325:
        color = (28,45,54)
    if 90 <= x < 423 and 136 <= y < 313:
        color = (42+(x-90)//12,95+(y-136)//10,101)
    if 221 <= x < 295 and abs(y-224) < (295-x)*.64:
        color = (237,247,216)
    if 397 <= x < 411 and 316 <= y < 320:
        color = (173,217,108)
    return color


def make_preview(model):
    # Orthographic projection of the same mesh positions, no invented cabin fit.
    chunks = ['<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="650" viewBox="0 0 1100 650">',
              '<rect width="1100" height="650" fill="#10212a"/>',
              '<g font-family="Arial,sans-serif" fill="#edf3ed">',
              '<text x="45" y="52" font-size="28">Tractor Media Screen</text>',
              '<text x="45" y="80" font-size="15" fill="#a8bfc5">Eigenes Entwicklungsmodell 0.1.0.0 | Noch kein FS25-Sichttest</text>']
    for ox,oy,scale,yaw,pitch,label in [(300,320,1000,0,0,"Vorderansicht"),(810,300,1000,-.65,.25,"Modellansicht")]:
        faces = []
        def project(p):
            x,y,z = p
            xx,zz = x*math.cos(yaw)+z*math.sin(yaw), -x*math.sin(yaw)+z*math.cos(yaw)
            yy,z2 = y*math.cos(pitch)-zz*math.sin(pitch), y*math.sin(pitch)+zz*math.cos(pitch)
            return (ox+xx*scale,oy-yy*scale,z2)
        for mesh in model:
            for triangle in mesh.triangles:
                points = [project(mesh.vertices[i][0]) for i in triangle]
                cross = (points[1][0]-points[0][0])*(points[2][1]-points[0][1])-(points[1][1]-points[0][1])*(points[2][0]-points[0][0])
                if cross >= 0:
                    continue
                shade = .80 if mesh.vertices[triangle[0]][1][2] == 0 else 1
                color = "#"+"".join(f"{int(c*shade):02x}" for c in mesh.color)
                # The chosen front-facing views allow the inset glass to be
                # drawn after the shell without triangle-centroid sorting artifacts.
                faces.append((mesh.name == "display",sum(p[2] for p in points),points,color))
        for _,_,points,color in sorted(faces,key=lambda row: (row[0],row[1])):
            coords = " ".join(f"{p[0]:.2f},{p[1]:.2f}" for p in points)
            chunks.append(f'<polygon points="{coords}" fill="{color}" stroke="{color}" stroke-width=".4"/>')
        chunks.append(f'<text x="{ox}" y="565" text-anchor="middle" font-size="18">{label}</text>')
    chunks += ['<text x="45" y="610" font-size="15" fill="#a8bfc5">Display 256 x 144 mm (16:9) | Gehaeuse 286 x 177 x 40 mm | Blickrichtung zur Vorderseite: -Z</text>',
               '</g></svg>']
    (ASSETS / "preview.svg").write_text("\n".join(chunks)+"\n", encoding="utf-8")


def main():
    ASSETS.mkdir(parents=True,exist_ok=True)
    model = meshes()
    make_i3d(model)
    write_dds(ASSETS / "black.dds",4,4,lambda x,y:(0,0,0))
    write_dds(ASSETS / "testPattern.dds",512,512,test_pixel)
    write_dds(MOD / "icon.dds",512,512,icon_pixel)
    make_preview(model)
    triangles = sum(len(mesh.triangles) for mesh in model)
    print(f"Monitor erzeugt: {triangles} Dreiecke, Display nodeId=3, Pfad 0>0, Front +Z")
    print(ASSETS / "preview.svg")


if __name__ == "__main__":
    main()
