"""Port tool: the Prologue's sound effects and music, made from nothing but arithmetic (numpy), so there is no licence to carry and no
service to pay. Run:  python3 tools/audio/make_audio.py <out_dir>   (default tilewright/assets/audio)

The sounds are short and plain (steps, the quill, the lantern, chimes, stone and paper); the music is a slow loop per place: a pad of sine
chords, a soft bass and a plucked melody, each in its own mode and speed, with a little echo. They are made to be replaced by recorded
sounds later: the names (the file names) are what the game asks for. Music loops are made to repeat without a seam.
"""
import json
import os
import sys
import wave

import numpy as np

SR = 22050
MSR = 16000          # music is a little duller and a lot smaller
rng = np.random.default_rng(41)


def save(path, x, sr=SR, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = float(np.max(np.abs(x))) or 1.0
    y = np.clip(x / peak * gain, -1, 1)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((y * 32767).astype('<i2').tobytes())


def t_(n, sr=SR):
    return np.arange(int(n * sr)) / sr


def env(n, a=0.005, d=0.1, s=0.0, r=0.0, sr=SR):
    """A simple attack-decay shape over n seconds."""
    t = t_(n, sr)
    e = np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-t / max(d, 1e-4))
    if r:
        e *= np.clip((n - t) / r, 0, 1)
    return e


def lowpass(x, k):
    """A one-pole low-pass: k near 1 is very dull, near 0 is bright."""
    y = np.zeros_like(x)
    a = 0.0
    for i in range(len(x)):
        a = k * a + (1 - k) * x[i]
        y[i] = a
    return y


def noise(n):
    return rng.standard_normal(int(n * SR))


def sine(f, n, sr=SR):
    return np.sin(2 * np.pi * f * t_(n, sr))


def sweep(f0, f1, n, sr=SR):
    t = t_(n, sr)
    f = f0 + (f1 - f0) * (t / n)
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def tone(f, n, a=0.005, d=0.2, sr=SR, harm=(1.0, 0.3, 0.1)):
    t = t_(n, sr)
    x = sum(h * np.sin(2 * np.pi * f * (i + 1) * t) for i, h in enumerate(harm))
    return x * env(n, a, d, sr=sr)


def mix(*parts, n=None):
    n = n or max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p[:n]
    return out


# ------------------------------------------------------------------ sound effects
def sfx():
    s = {}
    # footsteps: grass is a soft brush, stone a click
    s['step_grass'] = lowpass(noise(0.14), 0.82) * env(0.14, 0.004, 0.035)
    s['step_stone'] = mix(lowpass(noise(0.1), 0.6) * env(0.1, 0.002, 0.02), tone(220, 0.1, 0.002, 0.03) * 0.5)
    s['step_wood'] = mix(lowpass(noise(0.12), 0.7) * env(0.12, 0.003, 0.025), tone(150, 0.12, 0.002, 0.05) * 0.6)
    # the quill
    s['quill_swing'] = lowpass(noise(0.2), 0.55) * np.sin(np.pi * t_(0.2) / 0.2) ** 2
    s['quill_hit'] = mix(tone(180, 0.18, 0.001, 0.05), lowpass(noise(0.18), 0.5) * env(0.18, 0.001, 0.04), tone(540, 0.12, 0.001, 0.03) * 0.3)
    s['dash'] = lowpass(noise(0.3), 0.7) * np.sin(np.pi * t_(0.3) / 0.3)
    s['hurt'] = mix(tone(160, 0.3, 0.002, 0.1), sweep(300, 90, 0.3) * env(0.3, 0.002, 0.12) * 0.7)
    s['heal'] = mix(tone(523, 0.5, 0.01, 0.3), np.concatenate([np.zeros(int(SR * 0.08)), tone(659, 0.42, 0.01, 0.3)]), np.concatenate([np.zeros(int(SR * 0.16)), tone(784, 0.34, 0.01, 0.3)]))
    s['crumple'] = mix(lowpass(noise(0.7), 0.6) * env(0.7, 0.01, 0.25), sweep(260, 70, 0.7) * env(0.7, 0.005, 0.3) * 0.6)
    s['fall'] = mix(sweep(700, 90, 0.7) * env(0.7, 0.01, 0.5) * 0.6, np.concatenate([np.zeros(int(SR * 0.5)), tone(70, 0.4, 0.002, 0.12)]) )
    s['crystal'] = mix(tone(1319, 0.5, 0.002, 0.18, harm=(1, 0.2)), np.concatenate([np.zeros(int(SR * 0.07)), tone(1760, 0.45, 0.002, 0.18, harm=(1, 0.2))]))
    s['pickup'] = mix(tone(660, 0.25, 0.003, 0.09), np.concatenate([np.zeros(int(SR * 0.06)), tone(880, 0.3, 0.003, 0.1)]))
    s['item_use'] = mix(sweep(300, 700, 0.18) * env(0.18, 0.002, 0.1), tone(880, 0.2, 0.004, 0.08) * 0.4)
    s['toast'] = tone(990, 0.12, 0.002, 0.04, harm=(1, 0.1)) * 0.5
    s['page'] = lowpass(noise(0.35), 0.45) * np.sin(np.pi * t_(0.35) / 0.35) ** 3 * 0.8
    s['lantern_on'] = mix(tone(330, 0.3, 0.002, 0.08), lowpass(noise(0.3), 0.8) * env(0.3, 0.05, 0.1) * 0.4)
    s['post_light'] = mix(*[np.concatenate([np.zeros(int(SR * d)), tone(f, 1.4 - d, 0.01, 0.7)]) for d, f in [(0, 262), (0.08, 330), (0.16, 392), (0.24, 523)]])
    s['rest'] = mix(*[tone(f, 1.8, 0.05, 0.9, harm=(1, 0.15)) for f in (196, 247, 294)])
    s['gate_open'] = mix(lowpass(noise(1.4), 0.93) * env(1.4, 0.2, 0.6) * 2.0, sweep(60, 40, 1.4) * env(1.4, 0.1, 0.6))
    s['bar_lift'] = mix(lowpass(noise(0.9), 0.5) * np.sin(np.pi * t_(0.9) / 0.9), sweep(200, 600, 0.9) * env(0.9, 0.05, 0.5) * 0.25)
    s['stone_rewrite'] = mix(tone(110, 0.25, 0.002, 0.07), lowpass(noise(0.2), 0.6) * env(0.2, 0.002, 0.04), tone(440, 0.4, 0.004, 0.2) * 0.3)
    s['echo_start'] = sweep(300, 600, 0.3) * env(0.3, 0.01, 0.2)
    s['echo_stop'] = sweep(600, 300, 0.3) * env(0.3, 0.01, 0.2)
    s['enemy_alert'] = mix(tone(330, 0.2, 0.002, 0.07), np.concatenate([np.zeros(int(SR * 0.09)), tone(440, 0.2, 0.002, 0.07)]))
    s['proofread'] = mix(*[np.concatenate([np.zeros(int(SR * d)), tone(f, 0.9 - d, 0.004, 0.35)]) for d, f in [(0, 523), (0.1, 659), (0.2, 784)]])
    s['clang'] = mix(tone(900, 0.5, 0.001, 0.18, harm=(1, 0.8, 0.6, 0.4)), lowpass(noise(0.1), 0.2) * env(0.1, 0.001, 0.02))
    s['snip'] = mix(lowpass(noise(0.12), 0.1) * env(0.12, 0.001, 0.02), tone(2400, 0.12, 0.001, 0.02) * 0.4)
    s['paste'] = mix(lowpass(noise(0.2), 0.7) * env(0.2, 0.005, 0.06), tone(260, 0.15, 0.003, 0.05) * 0.5)
    s['rift'] = mix(sweep(120, 360, 2.5) * np.sin(np.pi * t_(2.5) / 2.5), lowpass(noise(2.5), 0.9) * np.sin(np.pi * t_(2.5) / 2.5) * 1.4)
    s['publish'] = mix(*[np.concatenate([np.zeros(int(SR * d)), tone(f, 3.0 - d, 0.2, 1.2, harm=(1, 0.2))]) for d, f in [(0, 262), (0.3, 330), (0.6, 392), (0.9, 523), (1.2, 659)]])
    s['minigame_hit'] = tone(784, 0.18, 0.002, 0.07)
    s['minigame_miss'] = tone(150, 0.25, 0.002, 0.1)
    return s


# ------------------------------------------------------------------ music
NOTE = {n: 440 * 2 ** ((i - 9) / 12) for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}


def hz(name, octave):
    return NOTE[name] * 2 ** (octave - 4)


def pad(freqs, n, sr, soft=1.0):
    t = t_(n, sr)
    x = sum(np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * soft for f in freqs)
    # slow swell and fall
    return x * (np.sin(np.pi * t / n) ** 0.6)


def pluck(f, n, sr, decay=0.5):
    t = t_(n, sr)
    return (np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * 2 * f * t) + 0.15 * np.sin(2 * np.pi * 3 * f * t)) * np.minimum(t / 0.004, 1) * np.exp(-t / decay)


def echo_loop(x, sr, delay=0.37, gain=0.35, taps=4):
    """An echo that wraps around the loop, so the last note's tail runs into the first bar."""
    y = x.copy()
    for k in range(1, taps + 1):
        y += np.roll(x, int(sr * delay * k)) * (gain ** k)
    return y


def track(root, mode, prog, bpm, bars, melody, sr=MSR, pluck_decay=0.6, bass=True, tempo_feel=1.0, pad_gain=1.0, mel_gain=0.55, density=2, seed=0):
    """A loop: `bars` bars of 4 beats; `prog` is chord roots as scale degrees (0-based), the pad plays triads, the bass the root, the melody a
    pattern of scale degrees (None = rest) in eighth notes, repeated."""
    r = np.random.default_rng(seed)
    scale = {
        'major': [0, 2, 4, 5, 7, 9, 11],
        'minor': [0, 2, 3, 5, 7, 8, 10],
        'dorian': [0, 2, 3, 5, 7, 9, 10],
        'lydian': [0, 2, 4, 6, 7, 9, 11],
        'phrygian': [0, 1, 3, 5, 7, 8, 10],
        'mixolydian': [0, 2, 4, 5, 7, 9, 10],
    }[mode]
    base = hz(root, 3)

    def deg(d, octv=0):
        o, i = divmod(d, 7)
        return base * 2 ** ((scale[i] + 12 * (o + octv)) / 12)

    beat = 60.0 / bpm
    bar = beat * 4
    n = int(sr * bar * bars)
    out = np.zeros(n)
    for b in range(bars):
        c = prog[b % len(prog)]
        start = int(sr * bar * b)
        chord = [deg(c), deg(c + 2), deg(c + 4)]
        p = pad(chord, bar * 1.15, sr) * 0.12 * pad_gain
        out[start : start + len(p)] += p[: n - start]
        if bass:
            for k in range(2):
                bs = start + int(sr * beat * 2 * k)
                bn = pluck(deg(c, -1), beat * 2, sr, 0.5) * 0.28
                out[bs : bs + len(bn)] += bn[: max(0, n - bs)]
        # melody, in eighth notes
        steps = int(8 * tempo_feel)
        for e in range(8):
            d = melody[(b * 8 + e) % len(melody)]
            if d is None:
                continue
            if r.random() > 0.9 and density < 3:
                continue
            ms = start + int(sr * beat * 0.5 * e)
            mn = pluck(deg(c + d, 1), beat * 1.6, sr, pluck_decay) * mel_gain * 0.2
            out[ms : ms + len(mn)] += mn[: max(0, n - ms)]
    out = echo_loop(out, sr)
    # crossfade the seam: a loop that ends where it begins
    return out


def music():
    m = {}
    m['music_title'] = track('D', 'dorian', [0, 5, 3, 4], 58, 8, [0, None, 2, None, 4, None, 2, None, 1, None, 3, None, 5, None, 3, 1], pluck_decay=0.9)
    m['music_storybook'] = track('A', 'minor', [0, 3, 5, 4], 64, 8, [4, 2, 0, 2, 4, None, 2, None, 3, 1, 3, 5, None, 3, 1, None], pluck_decay=0.7)
    m['music_overworld'] = track('G', 'lydian', [0, 4, 1, 3], 72, 8, [0, 2, 4, 2, 5, 4, 2, None, 1, 3, 5, 3, 6, 5, 3, None], pluck_decay=0.55)
    m['music_forge'] = track('E', 'phrygian', [0, 1, 0, 6], 66, 8, [0, None, 1, 0, None, 3, None, 1, 0, None, 4, None, 3, 1, None, 0], pluck_decay=0.5, pad_gain=1.2)
    m['music_pip'] = track('C', 'major', [0, 4, 5, 3], 84, 8, [2, 4, 2, 5, 4, 2, 0, 2, 4, 6, 4, 2, 5, 4, 2, 4], pluck_decay=0.35, mel_gain=0.7)
    m['music_maud'] = track('F', 'mixolydian', [0, 3, 4, 0], 76, 8, [0, 2, 4, None, 2, 0, None, 2, 3, 5, 3, None, 4, 2, 0, None], pluck_decay=0.45)
    m['music_scissor'] = track('B', 'dorian', [0, 5, 0, 6], 92, 8, [0, None, 4, None, 0, 5, None, 4, 2, None, 6, None, 4, 2, 0, None], pluck_decay=0.25, mel_gain=0.75)
    m['music_boss_critic'] = track('D', 'minor', [0, 5, 3, 6], 104, 8, [0, 0, 2, 0, 4, 0, 2, 0, 1, 1, 3, 1, 5, 1, 3, 1], pluck_decay=0.3, pad_gain=1.3, mel_gain=0.8)
    m['music_boss_spoiler'] = track('C#', 'phrygian', [0, 1, 6, 0], 116, 8, [0, 2, 4, 2, 0, 2, 4, 6, 5, 3, 1, 3, 5, 3, 1, 0], pluck_decay=0.22, pad_gain=1.1, mel_gain=0.85)
    m['music_boss_cold'] = track('F#', 'minor', [0, 6, 5, 6], 88, 8, [4, None, None, 2, None, None, 0, None, 4, None, None, 5, None, None, 3, None], pluck_decay=0.9, pad_gain=1.5, mel_gain=0.6)
    m['music_boss_scissor'] = track('A', 'minor', [0, 6, 5, 3], 126, 8, [0, 4, 0, 4, 2, 5, 2, 5, 1, 4, 1, 4, 3, 6, 3, 5], pluck_decay=0.18, mel_gain=0.9)
    m['music_ending'] = track('G', 'major', [0, 4, 5, 3, 0, 4, 1, 4], 60, 8, [4, None, 2, None, 0, None, 2, None, 4, None, 5, None, 7, None, 4, None], pluck_decay=1.1, pad_gain=1.3)
    return m


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join('tilewright', 'assets', 'audio')
    os.makedirs(out, exist_ok=True)
    for name, x in sfx().items():
        save(os.path.join(out, f'{name}.wav'), x, SR, 0.8)
    mix_music = {}
    for name, x in music().items():
        save(os.path.join(out, f'{name}.wav'), x, MSR, 0.7)
        mix_music[name] = {'volume': 0.55, 'loopStart': 0, 'loopEnd': 0, 'fade': 1.5}
    sounds = {n: {'volume': 0.6, 'bus': 'sfx', 'pitchVariation': 0.06, 'volumeVariation': 0.1, 'cooldown': 0.05, 'variants': []} for n in sfx()}
    for n in ('step_grass', 'step_stone', 'step_wood'):
        sounds[n]['volume'] = 0.35
        sounds[n]['pitchVariation'] = 0.12
    mixer = {'schemaVersion': 1, 'buses': {'master': 1, 'music': 1, 'sfx': 1, 'voice': 1}, 'ducking': {'enabled': True, 'amount': 0.5, 'attack': 0.15, 'release': 0.6}, 'sounds': sounds, 'music': mix_music}
    with open(os.path.join(out, 'mixer.json'), 'w', encoding='utf8') as f:
        json.dump(mixer, f, indent=2)
        f.write('\n')
    print(f'{len(sfx())} sounds, {len(mix_music)} music tracks -> {out}')


if __name__ == '__main__':
    main()
