# Adversary Dialog fix-52-fuzzy-price-match

Spec: docs/specs/models/shopping-item-fuzzy-price-match.md
Changed files (per adversary_dialog.py required-files, base c87977d9b050716db157de203d38e73fbfaef2fb):
- SmartCart/Models/ShoppingItem.swift

### Runde 1

## Round 1 Claim vs Evidence

Claim (spec): a new, isolated, conservative Levenshtein fallback (distance <= 1 AND shorter name
>= 5 chars) is added to ShoppingItem.init's learned-price lookup, only evaluated when the
existing substring check finds nothing, with the existing tie-break logic re-used unmodified.

Independently executed (not trusting the builder's own artifact):

1. Isolated fuzzy suite:
xcodebuild -only-testing:RestockTests/ShoppingItemFuzzyPriceMatchTests test
Test Suite 'ShoppingItemFuzzyPriceMatchTests' passed
Executed 7 tests, with 0 failures (0 unexpected) in 0.009s
Saved: docs/artifacts/fix-52-fuzzy-price-match/adversary-fuzzy-test-run.txt

2. Full unit regression suite (not just the new tests):
xcodebuild -only-testing:RestockTests test
Test Suite 'RestockTests.xctest' passed
Executed 302 tests, with 0 failures (0 unexpected) in 1.754s
Saved: docs/artifacts/fix-52-fuzzy-price-match/adversary-full-unit-run.txt
This includes PriceProvenanceMigrationTests, existing substring-match and tie-break coverage,
confirmed green in the same run, no regression.

3. Diff review of SmartCart/Models/ShoppingItem.swift against base c87977d9: exactly the
   scope the spec describes, substringKeys extracted, matchingKeys falls back to fuzzy
   filtering only via the empty branch of a ternary, plus two new static functions
   isFuzzyLearnedPriceMatch and levenshteinDistance. About 28 added lines, 1 line changed.
   No other file touched, matches required-files and the spec Affected Files section.

Round 1 verdict on the surface: all 7 tests map 1 to 1 to AC-1 through AC-7 and pass, full
suite green. Per protocol this is NOT accepted at face value, round 2 probes for gaming,
boundary and structural risk.

### Runde 2

## Round 2 Adversarial Probing

Probe 1, Is the gate a stub that always returns true or false, tests gamed?
Ruled out by cross-referencing opposite-direction tests in the same run: AC-1
(testFuzzyMatchFindsLearnedPriceForTyposaitanSeitan) and AC-6
(testFuzzyMatchAppliesExistingTieBreakingAmongMultipleCandidates) require the gate to return
true for real fuzzy pairs; AC-3 and AC-4
(testFuzzyMatchRejectsDistanceAboveThresholdMilchMehl, testFuzzyMatchRejectsDistanceAboveThresholdBananenMandeln)
require it to return false for real non-matches. A constant stub could not pass both groups
at once. Code reference: SmartCart/Models/ShoppingItem.swift line 201 to 203 shows a real,
non-stub implementation, min of a.count and b.count greater or equal 5 and levenshteinDistance
less or equal 1.

Probe 2, Does AC-7 really not execute the fuzzy branch, or does it just logically override it?
The spec Error Handling bullet 3 demands the fuzzy branch is not executed at all, not merely
outvoted. Code reference: SmartCart/Models/ShoppingItem.swift line 145 to 146, the ternary
assigns substringKeys when non-empty, else the fuzzy filter. Swift ternary lazily evaluates
only the chosen branch, when substringKeys is non-empty the fuzzy filter closure is never
invoked, this is a language guarantee, not just an outcome. Confirmed structurally and
behaviorally via testExistingSubstringMatchTakesPrecedenceOverFuzzyMatch, AC-7, passing with
the expected hackfleisch gemischt 500g to 4.99 result.

Probe 3, Case sensitivity, are learnedPrices keys guaranteed lowercase, so the new fuzzy
filter, which does not re-lowercase the key, only itemLower, does not silently diverge from
the existing substring check same assumption?
Checked every write site to store learnedPrices dictionary:
SmartCart/Views/Prices/ReceiptScannerView.swift line 691, key is lineLower, pre-lowercased.
SmartCart/Views/Prices/ActualPriceEntryView.swift line 162 to 163, key is item name lowercased.
SmartCart/Services/SyncCoordinator.swift line 241, mirrors an already-lowercased remote key.
SmartCart/Models/ShoppingItem.swift line 558, mirrors an existing already lowercase key.
SmartCart/SmartCartApp.swift line 225, literal lowercase seed parmesan.
All sites normalize before writing. The new fuzzy branch inherits exactly the same
pre-existing, unmodified assumption the substring branch already relied on, line 139 to 142,
which also never re-lowercases the key. Not a new risk introduced by this change.

Probe 4, Side effects, any hidden write in the new code path?
Code reference: SmartCart/Models/ShoppingItem.swift line 137 to 157, the whole
rawLearnedMatch closure, including the new lines 143 to 146, and line 201 to 220, the two new
static functions, contain only let, filter, max and return statements, no assignment to
store learnedPrices, learnedPriceDates, or learnedPriceUnits anywhere in the diff. Matches
spec Side effects Keine.

Probe 5, Boundary of the length gate, is it inclusive at 5, as the spec text says minimum
length 5 characters, or off by one, silently excluding legitimate 5 character pairs?
No dedicated unit test hits the boundary at exactly 5, the table shortest passing case is
saitan seitan at 6 characters, the shortest rejected case, eis, is 3 characters, the gap at 4
and the boundary at 5 itself are untested. Resolved by direct code inspection rather than
demanding a new test, since this is a read only arithmetic check, SmartCart/Models/ShoppingItem.swift
line 202 reads min of a count and b count greater or equal 5, inclusive at 5, matching the
spec stated gate exactly. This is a minor test coverage gap, no AC requires an exact 5 case,
not a defect.

Probe 6, Tie-break on fuzzy candidates with identical learnedPriceDates, not covered by AC-6,
which uses two different dates?
Code reference: SmartCart/Models/ShoppingItem.swift line 147 to 151, the max by tie-break
closure operates on matchingKeys regardless of whether that set came from the substring
branch or the new fuzzy branch, line 145 to 146 assigns to the same matchingKeys variable
consumed identically below. This is not a separate code path requiring its own proof, it is
the same, previously existing and already covered logic,
testShoppingItemPicksDeterministicWinnerWhenMultipleLearnedPricesMatchWithoutDates in
PriceProvenanceMigrationTests, confirmed green in the full regression run, now simply fed a
smaller candidate set. No new risk.

Probe 7, Spec metadata, test_targets frontmatter says RestockTests Models
ShoppingItemFuzzyPriceMatchTests swift, but the file actually created and registered in the
Xcode project is RestockTests ShoppingItemFuzzyPriceMatchTests swift, no Models
subdirectory.
Verified, RestockTests has no subdirectories at all, find RestockTests maxdepth 2 type d
returns only RestockTests itself, the flat placement matches existing project convention,
and the file is correctly registered in all four required project pbxproj locations,
PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase, verified by grep. This is a
stale path in the spec own frontmatter, not an implementation defect, and has no
ShoppingItem swift code reference to attach as a Finding per the reporting rule, noted here
for completeness, not raised as a blocking Finding.

## Checklist Verification

Confirmation AC-1, saitan seitan fuzzy hit.
Code reference: SmartCart/Models/ShoppingItem.swift line 145 to 146.
Evidence: testFuzzyMatchFindsLearnedPriceForTyposaitanSeitan passed, estimatedPrice equals
4.99, estimatedPriceIsAutoDerived equals false, see adversary-fuzzy-test-run.txt.
Status: CONFIRMED

Confirmation AC-2, reis eis, length gate rejects, isolated gate function.
Code reference: SmartCart/Models/ShoppingItem.swift line 201 to 203.
Evidence: testFuzzyGateRejectsReisEisBelowLengthGate passed, calling
ShoppingItem.isFuzzyLearnedPriceMatch with reis and eis directly, not via init.
Status: CONFIRMED

Confirmation AC-3, milch mehl, distance above threshold, via full init.
Code reference: SmartCart/Models/ShoppingItem.swift line 201 to 203.
Evidence: testFuzzyMatchRejectsDistanceAboveThresholdMilchMehl passed,
estimatedPriceIsAutoDerived equals true.
Status: CONFIRMED

Confirmation AC-4, bananen mandeln, distance above threshold, via full init.
Code reference: SmartCart/Models/ShoppingItem.swift line 201 to 203.
Evidence: testFuzzyMatchRejectsDistanceAboveThresholdBananenMandeln passed,
estimatedPriceIsAutoDerived equals true.
Status: CONFIRMED

Confirmation AC-5, apfel apfelsaft, distance above threshold, isolated gate function.
Code reference: SmartCart/Models/ShoppingItem.swift line 201 to 203.
Evidence: testFuzzyGateRejectsApfelApfelsaftAboveDistanceThreshold passed, calling
ShoppingItem.isFuzzyLearnedPriceMatch with apfel and apfelsaft directly.
Status: CONFIRMED

Confirmation AC-6, two fuzzy candidates, existing tie-break by newer learnedPriceDates wins.
Code reference: SmartCart/Models/ShoppingItem.swift line 147 to 151.
Evidence: testFuzzyMatchAppliesExistingTieBreakingAmongMultipleCandidates passed,
estimatedPrice equals 5.99, the seiten key, the younger date.
Status: CONFIRMED

Confirmation AC-7, existing substring match takes unconditional precedence, fuzzy branch not
executed.
Code reference: SmartCart/Models/ShoppingItem.swift line 145 to 146.
Evidence: testExistingSubstringMatchTakesPrecedenceOverFuzzyMatch passed, estimatedPrice
equals 4.99 via the hackfleisch gemischt 500g substring key, ternary lazy evaluation means
the fuzzy filter closure is never invoked when substringKeys is non-empty, see Probe 2.
Status: CONFIRMED

Confirmation, Side effects, read only, Expected Behavior and Error Handling sections.
Code reference: SmartCart/Models/ShoppingItem.swift line 137 to 157.
Evidence: no write or assignment to store learnedPrices, learnedPriceDates, or
learnedPriceUnits anywhere in the new or touched lines, see Probe 4.
Status: CONFIRMED

Confirmation, Regression, full RestockTests suite, including existing substring and
tie-break tests.
Code reference: SmartCart/Models/ShoppingItem.swift line 137 to 157.
Evidence: independent run, 302 tests, 0 failures, see adversary-full-unit-run.txt,
including PriceProvenanceMigrationTests.
Status: CONFIRMED

## Findings

No blocking findings. All probed risks, Probe 1 through Probe 7, resolved to CONFIRMED or
explicitly non-blocking observations. Probe 5, untested exact boundary case, resolved by
code inspection, not a defect. Probe 7, stale spec frontmatter path, not an implementation
defect, no qualifying code reference in the changed file.

VERDICT: VERIFIED
Tests: 302 passed, full RestockTests suite, independently run, 0 failed.
7 of 7 new fuzzy match tests passed, independently run.
Edge cases: 7 adversarial probes run, gaming or stub check, structural non execution of
fuzzy branch on substring hit, case sensitivity inheritance, side effect absence, length
gate boundary, equal date tie break code path identity, spec metadata path, none broke
the implementation.
Regressions: None found, existing substring match and tie break tests green in the same
run.
Checklist: 7 of 7 Acceptance Criteria proven, AC-1 through AC-7, plus Expected Behavior,
Side effects and Definition of Done regression bullet confirmed.

## Geprüfte Dateien

- sha256:dbd27518c43d3042c1c9349098af72e4ab549d30fe77d1656a07551f8e590846  SmartCart/Models/ShoppingItem.swift

## Geprüfte Dateien

- sha256:dbd27518c43d3042c1c9349098af72e4ab549d30fe77d1656a07551f8e590846  SmartCart/Models/ShoppingItem.swift
