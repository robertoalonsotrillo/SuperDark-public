#!/usr/bin/env python3
"""Lift BehaviorTrimmed's weight formulas out of the class and into data.

The 20 machines are selected by 20 hand-written expressions of the form

    w_sc = ((weights.at(\\sc) * 100) + 5
        - (density_delta / 10)
        - (windowsize_delta / 10)
        + (percpitch_delta / 10)
        + (avgflat_delta / 10)
    ).linlin(0, 100, 0.0, 1.0, clip: \\minmax),

which is a bias, a set of signed feature coefficients, and an output range.
Nothing about that needs to be code. As long as it is code it cannot change
without recompiling the class library, and recompiling kills the running
server and every buffer with it — so the factory could never learn anything
while it was playing.

This extracts them verbatim so the mutable version STARTS IDENTICAL to what
the class does. Any later difference is then attributable to the agent rather
than to my transcription.

  python3 extract_weights.py BehaviorTrimmed.sc mutable/weights.json
"""
import json, re, sys

FEATURES = ['density', 'windowsize', 'percpitch', 'avgcent',
            'avgrolloff', 'avgflat', 'avgrms']


def main():
    src, out = sys.argv[1], sys.argv[2]
    s = open(src).read()

    # order matters: it is the order of `targets` and of `calib`
    order = re.search(r'targets\s*=\s*\[(.*?)\];', s, re.S).group(1)
    targets = re.findall(r'\\(\w+)', order)

    machines = {}
    for m in targets:
        blk = re.search(
            r'w_' + m + r'\s*=\s*\(\((?:.*?)\)\s*\*\s*100\)\s*\+\s*(-?[\d.]+)(.*?)\)\.linlin\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)',
            s, re.S)
        if not blk:
            print(f'  MISS {m}', file=sys.stderr)
            continue
        bias = float(blk.group(1))
        body = blk.group(2)
        lo_in, hi_in, lo_out, hi_out = (float(blk.group(i)) for i in (3, 4, 5, 6))

        coef = {}
        for sign, feat, div in re.findall(
                r'([+-])\s*\((\w+)_delta\s*/\s*([\d.]+)\)', body):
            coef[feat] = round((1.0 if sign == '+' else -1.0) / float(div), 6)

        machines[m] = dict(bias=bias, coef=coef,
                           range=[lo_in, hi_in, lo_out, hi_out])

    doc = {
        '_comment': (
            'Lifted verbatim from BehaviorTrimmed.sc so the live factory starts '
            'identical to the class. The factory re-reads this file at every '
            'window boundary, so an agent can change selection while it plays. '
            'weight = clip(prev*100 + bias + sum(coef[f] * delta[f]), range) '
            'where delta[f] = linlin(this_mean[f] / prev_mean[f], 0, 2, -100, 100).'),
        '_features': FEATURES,
        'machines': machines,
    }
    with open(out, 'w') as f:
        json.dump(doc, f, indent=2)

    print(f'{len(machines)} machines -> {out}')
    for m, d in machines.items():
        terms = ' '.join(f'{k}{v:+.4f}' for k, v in d['coef'].items())
        print(f'  {m:4s} bias {d["bias"]:>4}  cap {d["range"][3]:<5} {terms}')


if __name__ == '__main__':
    main()
