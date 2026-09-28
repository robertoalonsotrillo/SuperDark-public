#!/usr/bin/env python3
"""Per-machine audibility census.

tools/verify_machines.scd asserts that every machine yields a non-empty score.
That test is too weak: run 40 measured six machines that pass it and are
inaudible, because score entries are not sound. `bu` produced 367 entries and
a file that is digitally zero everywhere.

This reads the isolated renders written by tools/render_all_machines.sh and
reports peak, RMS in dBFS, and the fraction of 50 ms frames below the -60 dBFS
floor. It exits non-zero if any machine falls under the audible threshold.

  python3 audibility.py workdir_music/renders            # report
  python3 audibility.py workdir_music/renders --gate     # report and enforce

The thresholds are read off the measured distribution rather than chosen:
the loudest machine is cr at -28.5 dBFS and the quietest audible one is sc at
-43.7, so -52 dBFS sits below every machine anyone has described as sounding,
and -60 is the point at which a 50 ms frame is treated as silence throughout
this project.
"""
import sys, os, wave, glob
import numpy as np

QUIET = -52.0     # below this, present but weak
INAUDIBLE = -60.0  # below this, the machine does not sound
ORDER = ['sc', 'lu', 'so', 'ma', 'cr', 'te', 'ry', 'an', 'hp', 'st',
         'ht', 'gl', 'cp', 'wa', 'gp', 'bu', 'dr', 'pu', 'hm', 'me']


def measure(path):
    w = wave.open(path)
    n, ch, sr = w.getnframes(), w.getnchannels(), w.getframerate()
    x = np.frombuffer(w.readframes(n), dtype='<i2').astype(np.float32) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)
    rms = float(np.sqrt((x ** 2).mean()))
    k = int(sr * 0.05)
    fr = x[:len(x) // k * k].reshape(-1, k)
    sil = float((np.sqrt((fr ** 2).mean(1)) < 10 ** (INAUDIBLE / 20)).mean() * 100)
    clip = float((np.abs(x) >= 0.999).mean() * 100)
    return float(np.abs(x).max()), 20 * np.log10(rms + 1e-12), sil, clip


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else 'workdir_music/renders'
    gate = '--gate' in sys.argv
    rows, missing = [], []
    for m in ORDER:
        p = os.path.join(d, f'm_{m}.wav')
        if os.path.exists(p):
            rows.append((m,) + measure(p))
        else:
            missing.append(m)

    rows.sort(key=lambda r: -r[2])
    print(f"{'m':4s}{'peak':>8}{'dBFS':>9}{'silent%':>9}{'clip%':>7}")
    bad = []
    for m, pk, db, sil, cl in rows:
        tag = ''
        if db < INAUDIBLE:
            tag = '  INAUDIBLE'
            bad.append(m)
        elif db < QUIET:
            tag = '  quiet'
        print(f'{m:4s}{pk:8.3f}{db:9.1f}{sil:9.1f}{cl:7.3f}{tag}')

    if missing:
        print(f'\nnot rendered: {" ".join(missing)}')
    print(f'\n{len(rows)} measured, {len(bad)} inaudible'
          + (f': {" ".join(bad)}' if bad else ''))
    if gate and bad:
        sys.exit(1)


if __name__ == '__main__':
    main()
