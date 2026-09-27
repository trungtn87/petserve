# Dark Pet rig v3 - deterministic region weights for Blender 4.x
# Usage: blender --background --python rig_dark_pet_v3.py -- input.glb output.glb
import bpy, sys
from pathlib import Path
from mathutils import Vector

argv=sys.argv
args=argv[argv.index('--')+1:] if '--' in argv else []
INPUT=Path(args[0]) if len(args)>0 else Path(r'F:\project\assets\pets\dark\3d\runtime\dark_pet_runtime.glb')
OUTPUT=Path(args[1]) if len(args)>1 else Path(r'F:\project\assets\pets\dark\3d\runtime\dark_pet_rigged_v3.glb')
BONES=['Root','Body','Neck','Head','Ear_L','Ear_R','Leg_FL','Leg_FR','Leg_BL','Leg_BR','Tail_01','Tail_02','Tail_03','Tail_04']

def clamp(x,a=0.,b=1.): return max(a,min(b,x))
def smooth(a,b,x):
 t=clamp((x-a)/(b-a)); return t*t*(3-2*t)
def clear():
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def import_mesh():
 bpy.ops.import_scene.gltf(filepath=str(INPUT)); ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
 if not ms: raise RuntimeError('No mesh')
 bpy.ops.object.select_all(action='DESELECT')
 for o in ms:o.select_set(True)
 bpy.context.view_layer.objects.active=ms[0]
 if len(ms)>1:bpy.ops.object.join()
 o=bpy.context.object;o.name='DarkPetMesh';bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return o
def bounds(o):
 p=[o.matrix_world@Vector(c) for c in o.bound_box];return Vector((min(v.x for v in p),min(v.y for v in p),min(v.z for v in p))),Vector((max(v.x for v in p),max(v.y for v in p),max(v.z for v in p)))
def bone(ar,n,h,t,p=None,c=False):
 b=ar.edit_bones.new(n);b.head=h;b.tail=t
 if p:b.parent=p;b.use_connect=c
 return b
def make_arm(o):
 mn,mx=bounds(o);s=mx-mn;cx=(mn.x+mx.x)/2;cy=(mn.y+mx.y)/2
 bpy.ops.object.armature_add(enter_editmode=True);ao=bpy.context.object;ao.name='DarkPetSkeleton';ar=ao.data;ar.name='DarkPetArmature';ar.edit_bones.remove(ar.edit_bones[0])
 root=bone(ar,'Root',(cx,cy,mn.z),(cx,cy,mn.z+s.z*.10));body=bone(ar,'Body',(cx,cy,mn.z+s.z*.10),(cx,cy,mn.z+s.z*.49),root)
 neck=bone(ar,'Neck',(cx,cy,mn.z+s.z*.47),(cx,cy,mn.z+s.z*.62),body,True);head=bone(ar,'Head',(cx,cy,mn.z+s.z*.60),(cx,cy,mn.z+s.z*.82),neck,True)
 bone(ar,'Ear_L',(cx-s.x*.17,cy,mn.z+s.z*.78),(cx-s.x*.28,cy,mn.z+s.z*.99),head);bone(ar,'Ear_R',(cx+s.x*.17,cy,mn.z+s.z*.78),(cx+s.x*.28,cy,mn.z+s.z*.99),head)
 for n,x,y in [('Leg_FL',cx-s.x*.24,cy-s.y*.17),('Leg_FR',cx+s.x*.24,cy-s.y*.17),('Leg_BL',cx-s.x*.27,cy+s.y*.17),('Leg_BR',cx+s.x*.27,cy+s.y*.17)]:bone(ar,n,(x,y,mn.z+s.z*.34),(x,y,mn.z+s.z*.025),body)
 p0=Vector((cx-s.x*.31,cy+s.y*.10,mn.z+s.z*.36));ps=[p0,p0+Vector((-s.x*.17,s.y*.04,s.z*.03)),p0+Vector((-s.x*.29,s.y*.08,s.z*.10)),p0+Vector((-s.x*.37,s.y*.11,s.z*.20)),p0+Vector((-s.x*.40,s.y*.13,s.z*.31))];p=body
 for i in range(4):p=bone(ar,'Tail_%02d'%(i+1),ps[i],ps[i+1],p,i>0)
 bpy.ops.object.mode_set(mode='OBJECT');ao.show_in_front=True;return ao
def weight(o):
 for g in list(o.vertex_groups):o.vertex_groups.remove(g)
 gs={n:o.vertex_groups.new(name=n) for n in BONES};mn,mx=bounds(o);s=mx-mn;cx=(mn.x+mx.x)/2;cy=(mn.y+mx.y)/2
 for v in o.data.vertices:
  p=o.matrix_world@v.co;xn=(p.x-cx)/s.x;yn=(p.y-cy)/s.y;z=(p.z-mn.z)/s.z;w={n:0. for n in BONES}
  # smoother body-neck-head transition
  h=smooth(.585,.70,z);n=max(0.,1.-abs(z-.565)/.115)*1.35;w['Head']=h*1.55;w['Neck']=n*(1-h*.55);w['Body']=max(.025,1-h*.92-n*.48)
  # ears get strong independent ownership only at high lateral head regions
  if z>.745:
   e=smooth(.745,.91,z)*smooth(.115,.235,abs(xn))*4.2
   if xn<0:w['Ear_L']=e
   else:w['Ear_R']=e
   w['Head']*=1-clamp(e*.18,0,.88);w['Neck']*=1-clamp(e*.22,0,.95)
  # feet/legs: stronger low-region ownership, narrow center exclusion
  if z<.405:
   leg=(1-smooth(.255,.405,z))*smooth(.075,.185,abs(xn))*4.0
   front=yn<0
   key=('Leg_FL' if xn<0 else 'Leg_FR') if front else ('Leg_BL' if xn<0 else 'Leg_BR');w[key]=leg;w['Body']*=1-clamp(leg*.18,0,.9)
  # preserve v2 tail concept
  if xn<-.25:
   t=smooth(.25,.42,-xn)
   if t>0:
    tz=clamp((z-.28)/.42);cs=[.08,.34,.62,.88];vs=[max(0.,1-abs(tz-c)/.36) for c in cs];sm=sum(vs) or 1
    for i,val in enumerate(vs):w['Tail_%02d'%(i+1)]+=t*(val/sm)*3
    w['Body']*=1-t*.8;w['Head']*=1-t*.9
  total=sum(w.values()) or 1
  for k,val in w.items():
   if val>.0001:gs[k].add([v.index],val/total,'REPLACE')
def bind(o,a):
 o.parent=a;o.matrix_parent_inverse=a.matrix_world.inverted();m=o.modifiers.new('Armature','ARMATURE');m.object=a
def main():
 if not INPUT.exists():raise FileNotFoundError(INPUT)
 clear();o=import_mesh();a=make_arm(o);weight(o);bind(o,a);OUTPUT.parent.mkdir(parents=True,exist_ok=True);bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',use_selection=True,export_apply=False,export_yup=True,export_skins=True,export_animations=True);print('DARK_PET_RIG_V3_OK',OUTPUT)
main()
