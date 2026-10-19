#!/bin/bash
# Wegwerf-Spike #145 D4: SKTestSession per xcodebuild auf iOS 26.5 und 27.0
cd "$(dirname "$0")"
cp /Users/hem/Developer/Restock/.claude/worktrees/staged-snacking-wolf/Restock.storekit Tests/SKSpikeTests/Restock.storekit
MY_LOCKS=""; SIMS=""
cleanup() {
  for s in $SIMS; do xcrun simctl delete "$s"; done
  for l in $MY_LOCKS; do rm -rf "$l"; done
}
trap cleanup EXIT
take_lock() {
  mkdir "$1" || { echo "ABBRUCH — Sperre $1 belegt: $(cat "$1/owner")"; return 1; }
  MY_LOCKS="$MY_LOCKS $1"; echo "restock-145-d4 skspike $(date '+%Y-%m-%d %H:%M')" > "$1/owner"
}
take_lock /tmp/heavy-build.lock || exit 2
take_lock /tmp/loose-ends-testlauf.lock || exit 2
printf 'pid=%s\nstart=%s\nworktree=%s\ncommand=%s\n' $$ "$(LC_ALL=C date +%s)" "$PWD" "skspike run.sh" > /tmp/loose-ends-testlauf.lock/pid
for rt in 26-5 27-0; do
  U=$(xcrun simctl create "SKSpike-$rt" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-$rt)
  SIMS="$SIMS $U"
  echo "=== iOS $rt ($U) ==="
  xcodebuild test -scheme SKSpike -destination "id=$U" -derivedDataPath build/dd 2>&1 | tee "log-$rt.txt" | grep -E "SPIKE|error|Test Case.*(passed|failed)|Executed|TEST (SUCCEEDED|FAILED)"
done
