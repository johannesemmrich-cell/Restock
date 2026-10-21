#!/usr/bin/env python3
"""Lädt die vollständigen Protokolle aller roten CI-Läufe und zählt den Vorbedingungsfehler aus #35."""
import json, re, subprocess

S = "/private/tmp/claude-501/-Users-hem-Developer-Restock/2056e5d3-1e6f-4f64-8836-8af6e613992a/scratchpad"
NEEDLE = "Sheet ist nicht erschienen"
runs = json.load(open(f"{S}/ci-runs.json"))
total_hits = 0
rows = []
for r in runs:
    if r["workflowName"] != "CI" or r["conclusion"] != "failure":
        continue
    log = subprocess.run(["gh", "run", "view", str(r["databaseId"]), "--log"],
                         capture_output=True, text=True).stdout
    hits = log.count(NEEDLE)
    receipt_fail = sorted(set(re.findall(r"ReceiptReviewUITests (\w+)\]' failed", log)))
    other_fail = sorted(set(re.findall(r"-\[RestockUITests\.(\w+ \w+)\]' failed", log)))
    rows.append((r["databaseId"], r["createdAt"][:10], r["headBranch"][:28], len(log.splitlines()), hits, receipt_fail, other_fail))
    total_hits += hits
with open(f"{S}/ci-logs-35-result.txt", "w") as f:
    for row in rows:
        line = f"{row[0]} {row[1]} {row[2]:28} zeilen={row[3]:7} nicht-erschienen={row[4]} ReceiptReview-rot={row[5]} rot={row[6]}"
        print(line)
        f.write(line + "\n")
    print("Treffer gesamt:", total_hits)
    f.write(f"Treffer gesamt: {total_hits}\n")
