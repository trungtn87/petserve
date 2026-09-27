"""Regression checks for the v3 tail-on-face bug and the v4 rest bind.
python tools/rig/test_dark_pet_v4.py (numpy required)
"""
from pathlib import Path
import json
import struct
import numpy as np
ROOT = Path(__file__).resolve().parents[2] / 'assets/pets/dark_pet'

def load(name):
    blob = (ROOT / name).read_bytes()
    length = struct.unpack_from('<I', blob, 12)[0]
    doc = json.loads(blob[20:20 + length])
    data = blob[28 + length:]
    def array(index):
        a = doc['accessors'][index]
        v = doc['bufferViews'][a['bufferView']]
        dtype = {5121: 'u1', 5123: '<u2', 5126: '<f4'}[a['componentType']]
        count = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
        return np.frombuffer(data, dtype=dtype, offset=v.get('byteOffset', 0) + a.get('byteOffset', 0), count=a['count'] * count).reshape(a['count'], count)
    return doc, array

def main():
    old, old_array = load('dark_pet_rigged_v3.glb')
    doc, array = load('dark_pet_rigged_v4.glb')
    before = old['meshes'][0]['primitives'][0]
    primitive = doc['meshes'][0]['primitives'][0]
    for name in ['POSITION', 'NORMAL']:
        assert np.array_equal(old_array(before['attributes'][name]), array(primitive['attributes'][name])), name + ' changed'
    assert np.array_equal(old_array(before['indices']), array(primitive['indices']))
    positions = array(primitive['attributes']['POSITION'])
    joints = array(primitive['attributes']['JOINTS_0'])
    weights = array(primitive['attributes']['WEIGHTS_0'])
    joint_nodes = doc['skins'][0]['joints']
    names = [doc['nodes'][node]['name'] for node in joint_nodes]
    assert np.isfinite(weights).all() and np.all(weights >= 0)
    assert np.max(np.abs(weights.sum(1) - 1)) < 1e-6
    assert joints.max() < len(joint_nodes)
    tail_indices = [i for i, name in enumerate(names) if name.startswith('Tail_')]
    tail_weights = (weights * np.isin(joints, tail_indices)).sum(1)
    assert tail_weights[positions[:, 2] > 0].max() == 0
    assert tail_weights[positions[:, 2] < -.5].min() > .999
    parents = {child: i for i, n in enumerate(doc['nodes']) for child in n.get('children', [])}
    def global_matrix(node, rotations=None):
        data = doc['nodes'][node]
        assert 'rotation' not in data and 'scale' not in data, 'v4 stores simple local translation rests'
        m = np.eye(4)
        m[:3, 3] = data.get('translation', (0, 0, 0))
        if rotations and data.get('name') in rotations:
            m[:3, :3] = rotations[data['name']]
        return global_matrix(parents[node], rotations) @ m if node in parents else m
    bind = array(doc['skins'][0]['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
    def skin(rotations=None):
        transforms = np.array([global_matrix(n, rotations) @ b for n, b in zip(joint_nodes, bind)])
        h = np.column_stack([positions, np.ones(len(positions))])
        transformed = np.einsum('vkij,vj->vki', transforms[joints], h)
        return (transformed[:, :, :3] * weights[:, :, None]).sum(1)
    assert np.max(np.abs(skin() - positions)) < 1e-6, 'Rest pose must preserve mesh'
    a = np.deg2rad(8)
    yaw = np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])
    tail_pose = skin({'Tail_01': yaw, 'Tail_02': yaw})
    face = positions[:, 2] > 0
    assert np.max(np.abs(tail_pose[face] - positions[face])) < 1e-6, 'Tail moved face geometry'
    assert np.max(np.linalg.norm(tail_pose[positions[:, 2] < -.5] - positions[positions[:, 2] < -.5], axis=1)) > .06
    head_pose = skin({'Head': yaw})
    tail = positions[:, 2] < -.5
    assert np.max(np.abs(head_pose[tail] - positions[tail])) < 1e-6, 'Head moved tail geometry'
    assert np.max(np.linalg.norm(head_pose[face] - positions[face], axis=1)) > .02
    print('PASS: unchanged mesh, normalized skin, valid bind/rest, tail moves tail not face, head does not move tail')

if __name__ == '__main__':
    main()
