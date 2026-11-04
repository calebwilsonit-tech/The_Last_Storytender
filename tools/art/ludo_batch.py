"""Runs a list of Ludo.ai generations and saves the pictures.

    python ludo_batch.py <manifest.json> [workers]

The API key is read from the LUDO_KEY environment variable or from the file named by LUDO_KEY_FILE (never from the repo).
The manifest is a list of jobs:
  {"out": "art/incoming2/items/icon_ink_blot",   # path without extension; results are saved as <out>_s0.png, _s1.png ...
   "kind": "style" | "image" | "edit" | "pose" | "rotate",
   "prompt": "...",
   "style_image": "art/training/props_10.png",    # kind "style"; "image" (kind edit/pose/rotate): a file or URL
   "image_type": "item-icon", "n": 3,
   "rmbg": true,                                   # take the background off every result afterwards
   "extra": {...}}                                 # more fields for the request body
Existing outputs are skipped, so a run can be repeated after a crash."""
import base64, concurrent.futures, io, json, os, sys, time, urllib.request, urllib.error

from PIL import Image

BASE = 'https://api.ludo.ai/api/'
KEY = os.environ.get('LUDO_KEY') or open(os.environ['LUDO_KEY_FILE']).read().strip()
PATHS = {'animate': 'assets/sprite/animate', 'style': 'assets/image/style', 'image': 'assets/image', 'edit': 'assets/image/edit',
         'pose': 'assets/sprite/pose', 'rotate': 'assets/sprite/rotate', 'rmbg': 'assets/image/remove-background'}


def call(method, path, body=None, timeout=90):
    req = urllib.request.Request(BASE + path, method=method, headers={'Authorization': 'ApiKey ' + KEY, 'Content-Type': 'application/json'},
                                 data=json.dumps(body).encode() if body is not None else None)
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            text = e.read().decode('utf8', 'replace')
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(5 + attempt * 10)
                continue
            raise RuntimeError(f'{e.code} {text[:300]}')
        except Exception:
            time.sleep(5 + attempt * 5)
    raise RuntimeError('gave up: ' + path)


def data_uri(src):
    if src.startswith('http') or src.startswith('data:'):
        return src
    im = Image.open(src)
    buf = io.BytesIO()
    im.convert('RGBA' if im.mode in ('RGBA', 'LA', 'P') else 'RGB').save(buf, 'PNG')
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()


def run_job(path, body):
    job = call('POST', path, body)
    jid = job['id']
    while True:
        j = call('GET', f'assets/jobs/{jid}?wait=30', timeout=100)
        if j['status'] == 'succeeded':
            return j
        if j['status'] in ('failed', 'cancelled'):
            raise RuntimeError(f'{path} {j["status"]}: {j.get("error")}')


def urls_of(j):
    r = j['result']
    if isinstance(r, dict):
        r = [r]
    return [x['url'] for x in r if x.get('url')]


def fetch(url, dest):
    data = urllib.request.urlopen(url, timeout=120).read()
    Image.open(io.BytesIO(data)).convert('RGBA').save(dest)


def do(job):
    out = job['out']
    if os.path.exists(out + '_s0.png'):
        return out, 'skip', 0
    os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
    kind = job.get('kind', 'style')
    body = {'prompt': job['prompt']} if 'prompt' in job else {}
    if kind == 'style':
        body['style_image'] = data_uri(job['style_image'])
        body['image_type'] = job.get('image_type', 'sprite')
    elif kind == 'image':
        body['image_type'] = job.get('image_type', 'sprite')
    else:
        body['image'] = data_uri(job['image'])
    if 'n' in job:
        body['n'] = job['n']
    body.update(job.get('extra', {}))
    j = run_job(PATHS[kind], body)
    cost = j.get('credits_charged', 0)
    urls = urls_of(j)
    for i, u in enumerate(urls):
        dest = f'{out}_s{i}.png'
        if job.get('rmbg'):
            r = run_job(PATHS['rmbg'], {'image': u})
            cost += r.get('credits_charged', 0)
            u = urls_of(r)[0]
        fetch(u, dest)
    return out, 'ok', cost


def main():
    jobs = json.load(open(sys.argv[1]))
    workers = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    total = 0
    with concurrent.futures.ThreadPoolExecutor(workers) as ex:
        futs = {ex.submit(do, j): j for j in jobs}
        for f in concurrent.futures.as_completed(futs):
            try:
                out, status, cost = f.result()
                total += cost
                print(status, out, cost, flush=True)
            except Exception as e:
                print('FAIL', futs[f]['out'], e, flush=True)
    print('credits charged this run:', round(total, 2))


if __name__ == "__main__":
    main()
