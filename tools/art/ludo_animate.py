"""Animates the still Ludo.ai pictures (art/incoming2) into looping sprite sheets with the animateSprite endpoint, for the Errors, the bosses and the villagers.

    python3 -I tools/art/ludo_animate.py <manifest.json> [workers]
The API key is read as in ludo_batch.py. The manifest is a list of jobs:
  {"out": "art/incoming2/anim/err_bare_idle",     # saved as <out>.json (its layout and the job) and <out>_f<N>.png (every frame; the sheet is not kept)
   "image": "art/incoming2/errors/err_bare_idle.png", "motion": "idle breathing", "model": "forge", "duration": 2, "frames": 9,
   "extra": {...}}                                  # more fields for the request (frame_size, margin_ratio_*, ...)
Existing outputs are skipped. Credits: the model's rate times the seconds (forge 1.5/s, hydra 3/s with 3 s the shortest)."""
import concurrent.futures
import io
import json
import os
import sys
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ludo_batch as B  # noqa: E402


def do(job):
    out = job['out']
    if os.path.exists(out + '.json'):
        return out, 'skip', 0
    os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
    body = {'initial_image': B.data_uri(job['image']), 'motion_prompt': job['motion'], 'model': job.get('model', 'forge'), 'duration': job.get('duration', 2),
            'frames': job.get('frames', 9), 'individual_frames': True, 'frame_size': 0, 'loop': True}
    body.update(job.get('extra', {}))
    j = B.run_job(B.PATHS['animate'], body)
    r = j['result']
    r = r[0] if isinstance(r, list) else r
    for i, u in enumerate(r.get('individual_frame_urls') or []):
        Image.open(io.BytesIO(urllib.request.urlopen(u, timeout=120).read())).convert('RGBA').save(f'{out}_f{i}.png')
    json.dump({k: r.get(k) for k in ('num_frames', 'num_cols', 'num_rows')} | {'credits': j.get('credits_charged'), 'job': job}, open(out + '.json', 'w'), indent=1)
    return out, 'ok', j.get('credits_charged', 0)


def main():
    jobs = json.load(open(sys.argv[1]))
    workers = int(sys.argv[2]) if len(sys.argv) > 2 else 3
    total = 0
    with concurrent.futures.ThreadPoolExecutor(workers) as ex:
        futs = {ex.submit(do, j): j for j in jobs}
        for f in concurrent.futures.as_completed(futs):
            try:
                out, status, cost = f.result()
                total += cost or 0
                print(status, out, cost, flush=True)
            except Exception as e:
                print('FAIL', futs[f]['out'], e, flush=True)
    print('credits charged this run:', round(total, 2))


if __name__ == '__main__':
    main()
