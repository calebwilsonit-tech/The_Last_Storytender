"""Writes the Ludo.ai manifests that give every creature views from all around, so none of them looks in one direction only.

    python3 -I tools/art/ludo_directions.py rotate [subject ...]    -> art/ludo_manifests/directions_rotate.json  (run with ludo_batch.py)
    python3 -I tools/art/ludo_directions.py animate [subject ...]   -> art/ludo_manifests/directions_animate.json (run with ludo_animate.py)

A subject is an Error kind (err_bare ...), a boss (boss_critic ...) or a villager (garrick, pip, maud). Its still picture (the front view, camera 0)
is turned to 45, 90, 135 and 180 degrees with rotateSprite (the left-hand views are the right-hand ones mirrored by the project); each new view is
then animated: an idle (forge, 2 s) and an attack (forge, 1.5 s) for the Errors and bosses. The villagers already have 0, 45, 135 and 180: they only
get the 90 degree view and its idle."""
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
VIEWS = ['045', '090', '135', '180']
TURN = {'045': 45, '090': 90, '135': 135, '180': 180}
SUBJECTS = {}
for k in ['bare', 'censor', 'dangler', 'ellipsis', 'mite', 'runon']:
    SUBJECTS[f'err_{k}'] = ('errors', f'err_{k}_idle', VIEWS, True)
for k in ['cold', 'critic', 'spoiler', 'scissor']:
    SUBJECTS[f'boss_{k}'] = ('bosses', f'boss_{k}_idle', VIEWS, True)
for k in ['garrick', 'pip', 'maud']:
    SUBJECTS[k] = ('characters', f'{k}_S', ['090'], False)
ATTACK = {'err': 'rearing up and slamming both paws down', 'boss': 'lunging with both fists in a furious attack'}


def still(sub):
    folder, name, _, _ = SUBJECTS[sub]
    return f'art/incoming2/{folder}/{name}.png'


def main():
    mode = sys.argv[1]
    subs = sys.argv[2:] or list(SUBJECTS)
    jobs = []
    for sub in subs:
        folder, name, views, fights = SUBJECTS[sub]
        for v in views:
            view_png = f'art/incoming2/directions/{sub}_{v}_s0.png'
            if mode == 'rotate':
                jobs.append({'out': f'art/incoming2/directions/{sub}_{v}', 'kind': 'rotate', 'image': still(sub), 'n': 1, 'rmbg': True, 'extra': {'camera_rotation': TURN[v]}})
            else:
                jobs.append({'out': f'art/incoming2/anim/{sub}_{v}_idle', 'image': view_png, 'motion': 'idle breathing, a gentle sway', 'model': 'forge', 'duration': 2, 'frames': 9})
                if fights:
                    motion = ATTACK['err'] if sub.startswith('err_') else ATTACK['boss']
                    jobs.append({'out': f'art/incoming2/anim/{sub}_{v}_attack', 'image': view_png, 'motion': motion, 'model': 'forge', 'duration': 1.5, 'frames': 9})
    out = os.path.join(REPO, 'art', 'ludo_manifests', f'directions_{mode}.json')
    json.dump(jobs, open(out, 'w'), indent=1)
    print(len(jobs), 'jobs ->', out)


if __name__ == '__main__':
    main()
