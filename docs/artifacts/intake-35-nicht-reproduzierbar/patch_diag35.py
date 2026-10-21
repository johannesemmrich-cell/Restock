#!/usr/bin/env python3
"""Setzt die DIAG35-Protokollzeilen in die Wegwerf-Kopie von HomeView.swift (nur Diagnose, nie fürs Repo)."""
import sys

path = sys.argv[1]
src = open(path, encoding="utf-8").read()

LOG = ('Logger(subsystem: "restock.diag35", category: "handoff").notice("DIAG35 trigger=\\(TRIGGER, privacy: .public) '
       'activeStores=\\(activeStores.count, privacy: .public) sheetOpen=\\(pendingReceiptScan != nil, privacy: .public) '
       'payloadWaiting=\\(UserDefaults(suiteName: SharedModelContainer.appGroupID)?.data(forKey: "pendingShareExtensionReceipt") != nil, privacy: .public)")')

replacements = [
    ("import UIKit\nimport UniformTypeIdentifiers",
     "import UIKit\nimport UniformTypeIdentifiers\nimport os"),
    ('                if url.scheme == "restock", url.host == "receiptscan" {\n                    checkPendingReceiptScan()',
     '                if url.scheme == "restock", url.host == "receiptscan" {\n                    checkPendingReceiptScan(trigger: "onOpenURL")'),
    ("                checkPendingQuickAdd()\n                checkPendingReceiptScan()\n                syncStoreOrder()",
     '                checkPendingQuickAdd()\n                checkPendingReceiptScan(trigger: "onAppear")\n                syncStoreOrder()'),
    ("                    checkPendingQuickAdd()\n                    checkPendingReceiptScan()\n                } else {",
     '                    checkPendingQuickAdd()\n                    checkPendingReceiptScan(trigger: "scenePhaseActive")\n                } else {'),
    ("                if draggingStoreID == nil { syncStoreOrder() }",
     "                " + LOG.replace("TRIGGER", '"activeStoresChanged"') + "\n                if draggingStoreID == nil { syncStoreOrder() }"),
    ("    private func checkPendingReceiptScan() {\n",
     '    private func checkPendingReceiptScan(trigger: String = "unbekannt") {\n        ' + LOG.replace("TRIGGER", "trigger") + "\n"),
]
for old, new in replacements:
    if src.count(old) != 1:
        print("NICHT EINDEUTIG:", old[:60].replace("\n", "⏎"), "Treffer:", src.count(old))
        sys.exit(1)
    src = src.replace(old, new)
open(path, "w", encoding="utf-8").write(src)
print("DIAG35 eingesetzt:", path)
