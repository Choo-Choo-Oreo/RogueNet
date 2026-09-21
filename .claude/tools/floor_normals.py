import math, sys
from PIL import Image
S="C:/Users/Orea/Documents/Project-Godot/RogueNet/resources/gfx/tileset/"
T=16; K=[1,2,1]
def make_floor(name, lum_weight=1.5, blur_passes=1, strength=4.5, fade=2, alpha_weight=0.0):
    d=Image.open(S+name+".png").convert("RGBA"); W,H=d.size; px=d.load()
    height=[[0.0]*W for _ in range(H)]
    for ty in range(0,H,T):
        for tx in range(0,W,T):
            vals=[(0.299*px[x,y][0]+0.587*px[x,y][1]+0.114*px[x,y][2])/255.0 for y in range(ty,ty+T) for x in range(tx,tx+T) if px[x,y][3]>0]
            mean=sum(vals)/len(vals) if vals else 0.0
            for y in range(ty,ty+T):
                for x in range(tx,tx+T):
                    r,g,b,a=px[x,y]
                    height[y][x]=(lum_weight*((0.299*r+0.587*g+0.114*b)/255.0)+alpha_weight) if a>0 else lum_weight*mean
    def blur(h):
        out=[[0.0]*W for _ in range(H)]
        for y in range(H):
            for x in range(W):
                tx,ty=x//T*T,y//T*T; acc=0.0; ws=0.0
                for j in range(-1,2):
                    for i in range(-1,2):
                        xx=min(max(x+i,tx),tx+T-1); yy=min(max(y+j,ty),ty+T-1)
                        w=K[i+1]*K[j+1]; acc+=h[yy][xx]*w; ws+=w
                out[y][x]=acc/ws
        return out
    for _ in range(blur_passes): height=blur(height)
    def dist(x,y):
        tx,ty=x//T*T,y//T*T; best=fade
        for j in range(-fade,fade+1):
            for i in range(-fade,fade+1):
                xx,yy=x+i,y+j
                if xx<tx or xx>=tx+T or yy<ty or yy>=ty+T or px[xx,yy][3]==0: best=min(best,max(abs(i),abs(j)))
        return best
    res=Image.new("RGBA",(W,H)); rp=res.load()
    for y in range(H):
        for x in range(W):
            tx,ty=x//T*T,y//T*T
            def hs(xx,yy):
                xx=min(max(xx,tx),tx+T-1); yy=min(max(yy,ty),ty+T-1); return height[yy][xx]
            if px[x,y][3]==0: nx=ny=0.0
            else:
                f=min(dist(x,y)/fade,1.0)
                nx=-(hs(x+1,y)-hs(x-1,y))*0.5*strength*f; ny=(hs(x,y+1)-hs(x,y-1))*0.5*strength*f
            l=math.sqrt(nx*nx+ny*ny+1.0)
            rp[x,y]=(round((nx/l*0.5+0.5)*255),round((ny/l*0.5+0.5)*255),round((1/l*0.5+0.5)*255),255)
    return res
if __name__=="__main__":
    for n in ["floor_dirt","floor_grass"]:
        r=make_floor(n); r.save("normals/"+n+"_normal.png")
        d=Image.open(S+n+".png").convert("RGBA")
        row=Image.new("RGB",(2*288+10,288),(30,30,30))
        bg=Image.new("RGBA",d.size,(60,60,60,255)); bg.alpha_composite(d)
        row.paste(bg.convert("RGB").resize((288,288),Image.NEAREST),(0,0)); row.paste(r.convert("RGB").resize((288,288),Image.NEAREST),(298,0))
        row.save("prev_"+n+".png"); print("ok",n)
