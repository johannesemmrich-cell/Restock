#!/usr/bin/env python3
"""Statische Prüfung der Teilung des Jobs ui-test in .github/workflows/ci.yml (Issue #136).

Prüft nur, was ohne Runner prüfbar ist: AC-1 (Matrix, Jobnamen), AC-5 (fail-fast false),
AC-6 (Auswahlmuster A/B), AC-7 (Artefaktnamen), AC-8 (YAML, Limit, Klassenliste genau einmal,
Kommentar). Die Laufzeit-ACs (Zeiten, Testzahl 84) belegen allein echte CI-Läufe.
Aufruf aus dem Repo-Wurzelverzeichnis: python3 docs/artifacts/fix-136-ui-job-teilen/check-ci-split.py
"""
import re
import sys

import yaml

SCHWER = ["ReceiptReviewUITests", "ShoppingRouteUITests",
          "AddItemQuantitySuggestionUITests", "ReceiptResolutionStatsUITests"]
text = open(".github/workflows/ci.yml").read()
job = yaml.safe_load(text)["jobs"]["ui-test"]
fails = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok or not detail else " – " + detail))
    if not ok:
        fails.append(name)


strategy = job.get("strategy") or {}
matrix = strategy.get("matrix") or {}
haelften = matrix.get("half")
check("AC-1 Matrix mit zwei Hälften A und B",
      isinstance(haelften, list) and sorted(map(str, haelften)) == ["A", "B"], "matrix=%s" % matrix)
check("AC-1 Jobname enthält die Hälfte", "matrix.half" in str(job.get("name", "")),
      "name=%s" % job.get("name"))
check("AC-5 fail-fast false", strategy.get("fail-fast") is False)
check("AC-8 timeout-minutes bleibt 60", job.get("timeout-minutes") == 60)

upload = [s for s in job["steps"] if "upload-artifact" in str(s.get("uses", ""))]
check("AC-7 Artefaktname je Hälfte verschieden",
      bool(upload) and "matrix." in str(upload[0]["with"]["name"]),
      str(upload[0]["with"]["name"]) if upload else "kein Upload-Schritt")

run = "\n".join(str(s.get("run", "")) for s in job["steps"] if "xcodebuild test" in str(s.get("run", "")))
check("AC-6 Hälfte B nutzt -skip-testing", "-skip-testing" in run)
check("AC-6 Hälfte A wählt Klassen per -only-testing:RestockUITests/<Klasse>",
      re.search(r"-only-testing:RestockUITests/", run) is not None)
check("AC-8 Klassenliste genau einmal in ci.yml", all(text.count(k) == 1 for k in SCHWER),
      "Treffer je Klasse: %s" % [text.count(k) for k in SCHWER])
check("AC-8 Kommentar nennt die Teilung", re.search(r"(?i)zwei Hälften", text) is not None)

print("\n%d Prüfung(en) fehlgeschlagen" % len(fails))
sys.exit(1 if fails else 0)
