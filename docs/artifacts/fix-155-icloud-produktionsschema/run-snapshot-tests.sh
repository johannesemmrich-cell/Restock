#!/bin/zsh
# Fährt MirroredSchemaSnapshotTests (Issue #155) auf Restock-Validate unter beiden Sperren.
# Aufruf: run-snapshot-tests.sh <ausgabedatei> [weitere -only-testing-Ziele …]
set -u
out="$1"; shift
root="${0:A:h:h:h:h}"
heavy=/tmp/heavy-build.lock
lauf=/tmp/loose-ends-testlauf.lock
me="restock-155 snapshot-tests $(date)"

# Beide frei → heavy nehmen → testlauf nehmen, sonst heavy sofort zurück.
while true; do
  if [[ ! -e $heavy && ! -e $lauf ]] && mkdir $heavy 2>/dev/null; then
    if mkdir $lauf 2>/dev/null; then break; fi
    rm -rf $heavy
  fi
  sleep 30
done
echo "$me" > $heavy/owner
echo "$me" > $lauf/owner
print -l "pid=$$" "start=$(LC_ALL=C date +%s)" "worktree=$root" "command=xcodebuild test MirroredSchemaSnapshotTests" > $lauf/pid
trap 'grep -q "pid=$$" $lauf/pid 2>/dev/null && rm -rf $lauf; grep -q "restock-155" $heavy/owner 2>/dev/null && rm -rf $heavy' EXIT

only=(-only-testing:RestockTests/MirroredSchemaSnapshotTests "$@")
cd "$root"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme Restock -project Restock.xcodeproj \
  -destination 'platform=iOS Simulator,id=8F696920-4B9A-40A7-96F0-7697BE887CC7' \
  -derivedDataPath build/dd-155 "${only[@]}" > "$out" 2>&1
echo "exit=$?" >> "$out"
