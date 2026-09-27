"""Repair the known +Z-facing v3 reference asset, without changing its mesh.
Run: python tools/rig/refine_dark_pet_v4.py
Requires numpy. Input v3 remains unchanged. Output rest vertices/normals/indices
are byte-identical; joints, inverse bind matrices and weights are repaired.
Coordinates are authored specifically for this model, NOT an auto-rigger.
"""
from pathlib import Path
import json
import struct
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/pets/dark_pet/dark_pet_rigged_v3.glb'
DEST = SOURCE.with_name('dark_pet_rigged_v4.glb')

def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)

def build():
    raw = SOURCE.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    data = bytearray(raw[28 + size:])
    def accessor(i):
        a = doc['accessors'][i]
        view = doc['bufferViews'][a['bufferView']]
        count = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
        dtype = {5126: '<f4', 5121: 'u1', 5123: '<u2'}[a['componentType']]
        return np.frombuffer(data, dtype=dtype, count=a['count'] * count,
                             offset=view.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(a['count'], count)
    skin = doc['skins'][0]
    joint_nodes = skin['joints']
    names = [doc['nodes'][i]['name'] for i in joint_nodes]
    slots = {name: i for i, name in enumerate(names)}
    # Global rest pivots measured against the actual mesh in glTF coordinates.
    pivots = {
        'Root': (0, 0, 0), 'Body': (0, .32, .1),
        'Neck': (0, .67, .52), 'Head': (0, .90, .56),
        'Ear_L': (-.34, 1.32, .60), 'Ear_R': (.34, 1.32, .60),
        'Leg_FL': (-.22, .36, .63), 'Leg_FR': (.22, .36, .63),
        'Leg_BL': (-.18, .32, -.05), 'Leg_BR': (.18, .32, -.05),
        'Tail_01': (0, .45, -.25), 'Tail_02': (0, .47, -.53),
        'Tail_03': (0, .57, -.79), 'Tail_04': (0, .83, -.92),
    }
    parents = {child: i for i, node in enumerate(doc['nodes']) for child in node.get('children', [])}
    for node_id in joint_nodes:
        node = doc['nodes'][node_id]
        parent_name = doc['nodes'][parents[node_id]]['name']
        origin = np.array(pivots.get(parent_name, (0, 0, 0)))
        node['translation'] = (np.array(pivots[node['name']]) - origin).tolist()
        node.pop('rotation', None)
        node.pop('scale', None)
    inverse_bind = accessor(skin['inverseBindMatrices'])
    for i, name in enumerate(names):
        matrix = np.eye(4)
        matrix[:3, 3] = -np.array(pivots[name])
        inverse_bind[i] = matrix.T.reshape(16) # glTF column-major matrices
    primitive = doc['meshes'][0]['primitives'][0]
    positions = accessor(primitive['attributes']['POSITION'])
    indices = accessor(primitive['attributes']['JOINTS_0'])
    weights = accessor(primitive['attributes']['WEIGHTS_0'])
    x, y, z = positions.T
    values = np.zeros((len(positions), len(names)), dtype=np.float64)
    # Head, neck and body blend only on front anatomy. Tail is resolved below.
    head = smooth(.68, .98, y)
    neck = (1 - head) * smooth(.50, .77, y) * .65
    values[:, slots['Head']] = head
    values[:, slots['Neck']] = neck
    values[:, slots['Body']] = 1 - head - neck
    # Ear influence starts above the eye/cheek region.
    ear = smooth(1.30, 1.57, y) * smooth(.14, .32, np.abs(x))
    values *= (1 - ear[:, None])
    for name, mask in [('Ear_L', x < 0), ('Ear_R', x >= 0)]:
        values[:, slots[name]] += ear * mask
    leg = (1 - smooth(.20, .40, y)) * smooth(.045, .15, np.abs(x))
    front = smooth(.23, .42, z)
    values *= 1 - leg[:, None]
    for side, mask in [('L', x < 0), ('R', x >= 0)]:
        values[:, slots['Leg_F' + side]] += leg * front * mask
        values[:, slots['Leg_B' + side]] += leg * (1 - front) * mask
    # Behind the torso in -Z, not the left side of the face in -X.
    tail_mask = smooth(-.20, -.48, z)
    tail_pivots = np.array([pivots['Tail_%02d' % i] for i in range(1, 5)])
    # Arc-length coordinates on the authored tail centreline, with a tip segment.
    line = np.vstack([tail_pivots, (0, 1.08, -.95)])
    best_distance = np.full(len(positions), np.inf)
    curve_t = np.zeros(len(positions))
    for i in range(4):
        vector = line[i + 1] - line[i]
        t = np.clip(((positions - line[i]) @ vector) / (vector @ vector), 0, 1)
        distance = np.sum((positions - (line[i] + t[:, None] * vector)) ** 2, axis=1)
        use = distance < best_distance
        curve_t[use] = i + t[use]
        best_distance[use] = distance[use]
    tail_weights = np.maximum(0, 1 - np.abs(curve_t[:, None] - np.arange(4)))
    tail_weights[curve_t >= 3] = (0, 0, 0, 1)
    tail_weights /= np.maximum(tail_weights.sum(1, keepdims=True), 1e-12)
    values *= 1 - tail_mask[:, None]
    for i in range(4):
        values[:, slots['Tail_%02d' % (i + 1)]] += tail_mask * tail_weights[:, i]
    # GLB carries four influences per vertex. Retain strongest and normalize.
    order = np.argsort(-values, axis=1, kind='stable')[:, :4]
    top = np.take_along_axis(values, order, axis=1)
    top /= top.sum(1, keepdims=True)
    indices[:] = order
    weights[:] = top
    assert np.isfinite(weights).all() and np.max(np.abs(weights.sum(1) - 1)) < 1e-6
    tail_columns = np.array([slots['Tail_%02d' % i] for i in range(1, 5)])
    final_tail = (weights * np.isin(indices, tail_columns)).sum(1)
    assert np.max(final_tail[z > 0]) == 0, 'Tail must not deform front/face'
    assert np.min(final_tail[z < -.5]) > .999, 'Tail tip must belong to tail bones'
    # Neutral matte diagnostic material; original GLB has no materials or UVs.
    doc['materials'] = [{'name': 'RigInspectionSlate', 'pbrMetallicRoughness': {
        'baseColorFactor': [.07, .09, .125, 1], 'metallicFactor': 0, 'roughnessFactor': .92}}]
    primitive['material'] = 0
    # Update helper markers too, so they do not describe the old anatomy.
    for node in doc['nodes']:
        marker_name = node.get('name', '').removeprefix('Rig_')
        if node.get('name', '').startswith('Rig_') and marker_name in pivots:
            node['translation'] = list(pivots[marker_name])
    doc['asset']['generator'] = 'PetVerse reference rig repair v4'
    doc['buffers'][0]['byteLength'] = len(data)
    encoded = json.dumps(doc, separators=(',', ':')).encode()
    encoded += b' ' * ((-len(encoded)) % 4)
    data += b'\0' * ((-len(data)) % 4)
    total = 12 + 8 + len(encoded) + 8 + len(data)
    DEST.write_bytes(struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(encoded), 0x4E4F534A) + encoded + struct.pack('<II', len(data), 0x004E4942) + data)
    print('Created', DEST.name, '| face tail influence = 0 | tail ownership = 1 | mesh unchanged')

if __name__ == '__main__':
    build()
