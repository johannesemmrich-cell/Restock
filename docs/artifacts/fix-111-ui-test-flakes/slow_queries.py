#!/usr/bin/env python3
"""Zählt XCUITest-Abfragen > Schwelle im xcresult (#111, AC-9).

Dauer einer Aktivität = Start der nächsten Aktivität in derselben Testausführung minus eigener Start
(Blätter der activities-Zeitachse). Gezählt werden nur Abfrage-Aktivitäten (Find/Check/Get/Wait for/
Evaluate/Requesting snapshot), keine App-Starts.
"""
import json, subprocess, sys

path, threshold = sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 4.0
QUERY = ("Find", "Check", "Get ", "Wait for", "Evaluat", "Request", "Snapshot", "Synthesize")


def xr(*args):
    out = subprocess.run(["xcrun", "xcresulttool", "get", "test-results", *args, "--path", path],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def test_ids(node):
    if node.get("nodeType") == "Test Case":
        yield node["nodeIdentifier"]
    for c in node.get("children", []):
        yield from test_ids(c)


def leaves(acts):
    for a in acts:
        kids = a.get("childActivities") or []
        if kids:
            yield (a.get("startTime"), a.get("title", ""), False)
            yield from leaves(kids)
        else:
            yield (a.get("startTime"), a.get("title", ""), True)


ids = sorted(set(i for n in xr("tests")["testNodes"] for i in test_ids(n)))
total, slow = 0, []
for tid in ids:
    for run in xr("activities", "--test-id", tid).get("testRuns", []):
        seq = [x for x in leaves(run.get("activities", [])) if x[0] is not None]
        for (t0, title, _), (t1, _, _) in zip(seq, seq[1:]):
            if title.startswith(QUERY):
                total += 1
                if t1 - t0 > threshold:
                    slow.append((round(t1 - t0, 2), tid.split("/")[-1], title[:90]))
print(f"Abfrage-Aktivitäten gesamt: {total}; davon > {threshold} s: {len(slow)}")
for d, t, title in sorted(slow, reverse=True)[:25]:
    print(f"{d:7.2f} s  {t}  {title}")
