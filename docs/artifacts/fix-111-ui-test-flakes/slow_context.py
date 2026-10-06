#!/usr/bin/env python3
"""Zeigt für jede Abfrage > Schwelle den Pfad der Elternaktivitäten (#111): lag sie in der neuen
Warte-Hilfe (Schleife ohne eigene Aktivität → Elternteil ist der Testschritt) oder in einer alten Stelle?"""
import json, subprocess, sys

path, threshold = sys.argv[1], float(sys.argv[2])
QUERY = ("Find", "Check", "Get ", "Wait for", "Evaluat", "Request", "Snapshot", "Synthesize")


def xr(*args):
    return json.loads(subprocess.run(["xcrun", "xcresulttool", "get", "test-results", *args, "--path", path],
                                     capture_output=True, text=True, check=True).stdout)


def ids(n):
    if n.get("nodeType") == "Test Case":
        yield n["nodeIdentifier"]
    for c in n.get("children", []):
        yield from ids(c)


def walk(acts, trail):
    for a in acts:
        kids = a.get("childActivities") or []
        yield (a.get("startTime"), a.get("title", ""), trail)
        yield from walk(kids, trail + [a.get("title", "")[:70]])


for tid in sorted(set(i for n in xr("tests")["testNodes"] for i in ids(n))):
    for r_i, run in enumerate(xr("activities", "--test-id", tid).get("testRuns", [])):
        seq = [x for x in walk(run.get("activities", []), []) if x[0] is not None]
        for k, ((t0, title, trail), (t1, _, _)) in enumerate(zip(seq, seq[1:])):
            if title.startswith(QUERY) and t1 - t0 > threshold:
                print(f"{t1 - t0:6.2f} s  {tid.split('/')[-1]} Iteration {r_i + 1}: {title[:80]}")
                for p in trail:
                    print(f"           in: {p}")
                for _, t, _ in seq[max(0, k - 3):k + 3]:
                    print(f"           ~ {t[:90]}")
