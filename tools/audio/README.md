# Audio

The port's sounds and music are made by code (no paid generation): `make_audio.py` writes 32 sound effects, 12 music tracks and the mixer
settings into a folder of WAV files.

`tilewright/assets/audio/` is **not** in git (about 10 MB of generated files). `tools/port/run_porter.sh` makes it every time it builds the
project. To make just the audio:

```
python3 tools/audio/make_audio.py tilewright/assets/audio
```

Needs Python 3 with numpy.
