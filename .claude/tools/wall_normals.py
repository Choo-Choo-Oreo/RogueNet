import math, sys
from PIL import Image
T=16
def make(name, out, tilt=0.25, bump=2.0, bevel=1.2):
    src=Image.open(name+'.png').convert('RGBA')
    res=Image.new('RGBA',src.size,(128,128,255,0))
    for ty in range(0,src.height,T):
        for tx in range(0,src.width,T):
            px={}
            for y in range(T):
                for x in range(T):
                    px[x,y]=src.getpixel((tx+x,ty+y))
            def alpha(x,y): return px[min(max(x,0),T-1),min(max(y,0),T-1)][3]>0
            def lum(x,y): 
                p=px[min(max(x,0),T-1),min(max(y,0),T-1)]; return sum(p[:3])/765.0
            def top(x,y):
                p=px[min(max(x,0),T-1),min(max(y,0),T-1)]; return p[3]>0 and sum(p[:3])<12
            # face height: luminance, tops take the pixel's own value (no gradient across top)
            def face_h(x,y,cx,cy):
                if alpha(x,y) and not top(x,y): return lum(x,y)
                return lum(cx,cy)
            # blurred top mask for bevel
            def tmask(x,y):
                s=0
                for dy in (-1,0,1):
                    for dx in (-1,0,1):
                        s+=1.0 if top(x+dx,y+dy) else 0.0
                return s/9.0
            for y in range(T):
                for x in range(T):
                    p=px[x,y]
                    if p[3]==0: continue
                    if top(x,y):
                        nx=ny=0.0
                    else:
                        gx=(face_h(x+1,y,x,y)-face_h(x-1,y,x,y))/2
                        gy=(face_h(x,y+1,x,y)-face_h(x,y-1,x,y))/2
                        nx=-gx*bump
                        ny= gy*bump - tilt
                    # bevel: top is raised, so rim pixels tilt away from it
                    bx=(tmask(x+1,y)-tmask(x-1,y))/2
                    by=(tmask(x,y+1)-tmask(x,y-1))/2
                    if not top(x,y):
                        nx+= -bx*bevel
                        ny+=  by*bevel
                    nz=math.sqrt(max(0.05,1-nx*nx-ny*ny)) if abs(nx)<1 and abs(ny)<1 else 0.3
                    l=math.sqrt(nx*nx+ny*ny+nz*nz)
                    nx,ny,nz=nx/l,ny/l,nz/l
                    res.putpixel((tx+x,ty+y),(round(128+nx*127),round(128+ny*127),round(128+nz*127),p[3]))
    res.save(out)
# Per-material knobs. bump = how strongly art detail (mortar, brick edges) shapes the
# normal; tilt = how far the wall face leans toward the viewer; bevel = rim softness.
MATERIALS = {
    'wall_smooth_stone': dict(bump=0.8, tilt=0.25, bevel=1.2),
    'wall_cobble_brick': dict(bump=4.0, tilt=0.25, bevel=1.2),
    'wall_wood_plank': dict(bump=2.5, tilt=0.25, bevel=1.2),
    'wall_rough_cave': dict(bump=3.0, tilt=0.25, bevel=1.2),
    'wall_flesh': dict(bump=2.5, tilt=0.25, bevel=1.2),
}
for n, kw in MATERIALS.items():
    make(n, n+'_normal.png', **kw)
    im=Image.open(n+'_normal.png'); print(n,im.size)
