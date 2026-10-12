#!/usr/bin/env python3
"""Extract launcher artwork locally from the installed, user-supplied games."""
from pathlib import Path
import struct, zlib, zipfile, sys
base=Path(sys.argv[1]).expanduser() if len(sys.argv)>1 else Path.home()/'Games/Brutal Doom'
out=Path(sys.argv[2]) if len(sys.argv)>2 else Path(__file__).parent/'Assets'
out.mkdir(parents=True,exist_ok=True)
def wad(name):
 data=(base/'IWADs'/name).read_bytes(); _,n,offset=struct.unpack_from('<4sii',data)
 return {raw.rstrip(b'\0').decode('ascii','replace'):data[p:p+s] for p,s,raw in (struct.unpack_from('<ii8s',data,offset+i*16) for i in range(n))}
def png(name,w,h,pixels):
 def chunk(k,d):return struct.pack('>I',len(d))+k+d+struct.pack('>I',zlib.crc32(k+d)&0xffffffff)
 raw=b''.join(b'\0'+pixels[y*w*4:(y+1)*w*4] for y in range(h))
 (out/(name+'.png')).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
def picture(name,data,palette,flat=None):
 if data.startswith(b'\x89PNG'):(out/(name+'.png')).write_bytes(data);return
 if flat:
  w,h=flat; pix=b''.join(palette[v*3:v*3+3]+b'\xff' for v in data);png(name,w,h,pix);return
 w,h,_,_=struct.unpack_from('<hhhh',data); pix=bytearray(w*h*4)
 assert 0<w<8192 and 0<h<8192
 for x in range(w):
  p=struct.unpack_from('<I',data,8+x*4)[0];prev=-1
  while data[p]!=255:
   top,n=data[p:p+2];p+=3
   if top<=prev:top+=prev
   prev=top
   for y,v in enumerate(data[p:p+n],top):
    if y<h:pix[(y*w+x)*4:(y*w+x+1)*4]=palette[v*3:v*3+3]+b'\xff'
   p+=n+1
 png(name,w,h,pix)
def member(path,name):
 with zipfile.ZipFile(base/path) as z:return z.read(name)
d=wad('DOOM.WAD');pal=d['PLAYPAL'][:768]
picture('doom',d['TITLEPIC'],pal)
picture('stone',d['FLOOR7_2'],pal,(64,64))
picture('brutal-logo',member('Mods/brutalv21.pk3','GRAPHICS/MISC/M_DOOM'),pal)
for key,name in [('doom2','DOOM2.WAD'),('chex','chex.wad'),('chex3','chex3.wad'),('hexen','HEXEN.WAD')]:
 d=wad(name);p=d['PLAYPAL'][:768]
 picture(key,d.get('TITLEPIC',d.get('TITLE')),p,(320,200) if key=='hexen' else None)
 if key.startswith('chex'):picture(key+'-logo',d['M_DOOM'],p)
for key,path,name in [
 ('wolfenstein','Mods/Wolfenstein/ZMC-BWV7.2.pk3','source/unused/graphs/TITLEPIC.png'),
 ('wolfenstein-logo','Mods/Wolfenstein/ZMC-BWV7.2.pk3','graphics/MISC/M_DOOM.png'),
 ('doom64','Mods/Doom64/BD64-VoH_maps_v1.6.1.pk3','graphics/TITLEPIC.png'),
 ('doom64-logo','Mods/Doom64/BD64-VoH_maps_v1.6.1.pk3','textures/misc/BD64LOGO.png'),
 ('hexen-logo','Mods/Hexen/BrutalHexenRPG_V8.0_beta.pk3','GRAPHICS/M_HTIC.png')]:
 (out/(key+'.png')).write_bytes(member(path,name))
print('Extracted',len(list(out.glob('*.png'))),'local artwork files.')
