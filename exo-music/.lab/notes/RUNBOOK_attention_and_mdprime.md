# Runbook: the attention comparison and M-D′

Written 16 September 2026, 00:55, while arm A runs. Every step is one command.
If this session is interrupted, the next one can pick up from whichever step
last completed, because each leaves a checkpoint or a bundle behind.

Pre-registrations that govern this:
- `.lab/measurements/2026-09-15_attention_prereg.md`
- `.lab/measurements/2026-09-16_partial_hold_prime_prereg.md`

    export PY=/opt/homebrew/bin/python3
    cd .../SUPERDARK/exo-music

---

## Arm A — champion, `attention_weight` 0.0

**Started 00:29:59**, checkpoint `ck_260916_002959_armA-champion-aw0`,
log `live_260916_002600.log`, start epoch in `/tmp/armA_since`.

Ends at **02:30**. Then:

    sh tools/eval_rig.sh run --checkpoint ck_260916_002959_armA-champion-aw0 \
      --policy superdark_release@1 --arm champion --since $(cat /tmp/armA_since)

Note the bundle path it prints.

## Arm B — candidate, `attention_weight` 0.15

Hot-reloads; **no restart**, so the factory and the trace stay identical and the
one-change rule holds.

    $PY - <<'EOF'
    import json, os
    p='workdir_music/mutable/policy.json'; d=json.load(open(p))
    d['attention_weight']=0.15
    json.dump(d, open(p+'.tmp','w'), indent=1, sort_keys=True); os.replace(p+'.tmp',p)
    EOF
    sleep 30 && date +%s > /tmp/armB_since
    $PY tools/checkpoint.py create --label armB-candidate-aw015 \
      --note "ARM B / CANDIDATE: attention_weight 0.15, hot-reloaded, everything else identical to arm A"

Confirm within a minute that the mechanism is actually firing, because it never
has before today:

    grep -c '^ATTEND' /Volumes/FMA/superdark/renders/live_260916_002600.log

Run two hours, then:

    sh tools/eval_rig.sh run --checkpoint <armB ckpt> \
      --policy superdark_release@1 --arm candidate --since $(cat /tmp/armB_since)

## Compare and gate — shadow comparison #1

    sh tools/eval_rig.sh compare --candidate <armB bundle> --champion <armA bundle>
    sh tools/eval_rig.sh gate --comparison <cmp dir> --policy superdark_release@1

Expect `margins_unset`. That is correct and is the point: the gate promotes
nothing until five shadow comparisons have set the margins from data.

Then spend the budget honestly:

    $PY tools/measure_registry.py use <measure> --change chg_260916_attention

## M-D′ — the fresh macro isolation

Needs a restart, which is why it comes last. The restart also brings the staged
`BLOWUP` instrumentation live.

    $PY tools/checkpoint.py create --label pre-mdprime
    # stop
    pkill -f "_live.scd"; sleep 2; pkill -x sclang; sleep 1
    pkill -x scsynth; pkill -f caffeinate; sleep 2
    # isolate
    $PY - <<'EOF'
    import json, os
    p='workdir_music/mutable/policy.json'; d=json.load(open(p))
    d['layers_active']="macro"; d['attention_weight']=0.0
    json.dump(d, open(p+'.tmp','w'), indent=1, sort_keys=True); os.replace(p+'.tmp',p)
    EOF
    nohup sh tools/start_loop.sh > /tmp/mdprime_start.log 2>&1 &

`start_loop.sh` **refuses to start the ingest daemon** when fewer than three
layers are active. Verify that it did refuse:

    grep -A4 "ISOLATION RUN" /tmp/mdprime_start.log
    pgrep -f self_ingest.py | wc -l      # must be 0

Two hours. Then preserve the audio before the ring can delete it:

    # concat segments whose START falls inside the run, as eval_run does
    ffmpeg -f concat -safe 0 -i <list> -ac 1 -ar 22050 \
      /Volumes/FMA/superdark/measurements/mc_isolation_260916.wav

Score it:

    $PY tools/partial_hold.py prime \
      --factory /Volumes/FMA/superdark/measurements/mc_isolation_260916.wav \
      --diverse /Volumes/FMA/superdark/measurements/diverse_600clips.wav \
      --out /Volumes/FMA/superdark/measurements/mdprime_260916.json

## Restore normal operation

    # stop, then
    $PY - <<'EOF'
    import json, os
    p='workdir_music/mutable/policy.json'; d=json.load(open(p))
    d['layers_active']="macro mid micro"
    json.dump(d, open(p+'.tmp','w'), indent=1, sort_keys=True); os.replace(p+'.tmp',p)
    EOF
    $PY tools/checkpoint.py restore <pre-mdprime ckpt>   # drops the isolation's memory
    nohup sh tools/start_loop.sh > /tmp/restore_start.log 2>&1 &

The restore matters: an isolation run writes sections describing a factory that
does not exist in normal operation, and on 15 September twenty of them were left
in the operator until Roberto caught it.

## Standing checks between steps

    L=$(ls -t /Volumes/FMA/superdark/renders/live_*.log | head -1)
    grep -c FILL_STALL $L; grep -c BLOWUP $L; grep -c UNTRACKED $L
    pgrep -f self_ingest.py | wc -l        # 1 normally, 0 during isolation
    $PY tools/seal_rig.py verify
