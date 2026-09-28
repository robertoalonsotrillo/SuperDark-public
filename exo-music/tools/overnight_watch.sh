#!/bin/sh
# WAS THE LONG RUN TRUSTWORTHY? Answer that BEFORE judging the sound.
#
# The 8 h run of 28 Aug lost 85% of itself: the clock jumped 20,309 s when the
# machine slept, the FIFO reported full 77,491 times, and NO CHARTER METRIC
# NOTICED. The run was scored, discussed and reasoned about before anyone found
# out it was mostly garbage. A long run is only evidence if its own conditions
# held, and nothing currently records those conditions.
#
# This samples the few things that have actually broken overnight here and
# appends one line every 60 s. It touches nothing, holds no locks, and writes to
# /tmp so a full SSD cannot be made worse by the monitor watching for it.
#
#   sh tools/overnight_watch.sh &
#   sh tools/overnight_watch.sh --report        # read it back in the morning
OUT=/tmp/overnight_watch.tsv

if [ "$1" = "--report" ]; then
  [ -f "$OUT" ] || { echo "  no watch file"; exit 1; }
  python3 - "$OUT" <<'PY'
import sys, datetime
rows=[l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if l.strip()]
rows=[r for r in rows if len(r)>=8]
if len(rows)<3: sys.exit("  too few samples")
# DROP SAMPLES FROM BEFORE THE RUN BEING WATCHED.
# The watch is started alongside the factory, so its first sample or two catch
# the PREVIOUS run's log while the new factory is still booting. Counting those
# as "factory down" made the first real report say DO NOT TRUST on a run that
# was clean in every other column -- a watchdog whose first act is a false
# alarm is a watchdog that gets ignored. Anchor on the log the run ended with.
final=rows[-1][7]
rows=[r for r in rows if r[7]==final]
if len(rows)<3: sys.exit("  too few samples for the final run")
t=[float(r[0]) for r in rows]
win=[int(r[3]) for r in rows]; free=[int(r[4]) for r in rows]
fac=[r[1] for r in rows]; spl=[r[2] for r in rows]
print()
print(f"  {len(rows)} samples, {(t[-1]-t[0])/3600:.2f} h wall clock")
print(f"  from {datetime.datetime.fromtimestamp(t[0]):%H:%M} "
      f"to {datetime.datetime.fromtimestamp(t[-1]):%H:%M}")
# 1. CLOCK JUMPS. Samples are 60 s apart; a gap far from 60 means the machine
#    slept or the monitor was starved, and either invalidates the interval.
gaps=[(b-a) for a,b in zip(t,t[1:])]
bad=[(i,g) for i,g in enumerate(gaps) if g>150]
print(f"  clock gaps > 150 s: {len(bad)}" + (f"   LARGEST {max(g for _,g in bad):.0f} s" if bad else "   none"))
# 2. PROCESS DEATH.
print(f"  factory down in {sum(1 for x in fac if x!='up')} samples, "
      f"splitter down in {sum(1 for x in spl if x!='up')}")
# 3. DID THE FACTORY ADVANCE? A live process stuck at one window is worse than
#    a dead one, because it looks healthy.
stalls=sum(1 for a,b in zip(win,win[1:]) if b==a)
print(f"  window counter did not advance in {stalls} of {len(win)-1} intervals")
print(f"  windows {win[0]} -> {win[-1]}  ({win[-1]-win[0]} in the run)")
# 4. DISK.
print(f"  free space {free[0]} -> {free[-1]} GB")
print()
clean = not bad and stalls < len(win)//10 and all(x=='up' for x in fac)
print("  VERDICT: run looks clean" if clean else
      "  VERDICT: DO NOT TRUST THIS RUN WITHOUT LOOKING AT THE ABOVE")
print()
PY
  exit 0
fi

RENDERS=/Volumes/FMA/superdark/renders
while :; do
  NOW=$(date +%s)
  pgrep -f "sclang.*renders/_live.scd" >/dev/null && FAC=up || FAC=DOWN
  pgrep -f fifo_splitter.py >/dev/null && SPL=up || SPL=DOWN
  LOG=$(ls -t "$RENDERS"/live_*.log 2>/dev/null | head -1)
  WIN=$(grep -c '^MASTER' "$LOG" 2>/dev/null || echo 0)
  FREE=$(df -g /Volumes/FMA 2>/dev/null | tail -1 | awk '{print $4}')
  [ -z "$FREE" ] && FREE=0
  SEG=$(du -sm /Volumes/FMA/superdark/segments 2>/dev/null | awk '{print $1}')
  [ -z "$SEG" ] && SEG=0
  SKEW=$(grep -o 'clock skew [-+0-9.]*' /tmp/fifo_splitter.log 2>/dev/null | tail -1 | awk '{print $3}')
  [ -z "$SKEW" ] && SKEW=0
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$NOW" "$FAC" "$SPL" "$WIN" "$FREE" "$SEG" "$SKEW" "$(basename "${LOG:-none}")" >> "$OUT"
  sleep 60
done
