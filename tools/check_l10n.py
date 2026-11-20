#!/usr/bin/env python3
"""Localization checks for lib/l10n/*.arb (Phase I). No Flutter needed.  Usage: python tools/check_l10n.py [--finder]

Checks (exit 1 on any problem):
  * every .arb parses; app_en.arb is the template; every other app_<lang>.arb has EXACTLY the same keys
  * placeholders in each translation equal the English ones (names), and every placeholder is declared String
    (so numbers are never locale-formatted: Western digits 0-9 in every language)
  * no ICU plural/select (bundled-only plural strings come later), no HTML, no leading/trailing whitespace in values
    (the translation admin trims values), no control/bidi characters in values
  * the Arabic file contains Arabic letters for every value that is not intentionally identical to English
--finder additionally lists hard-coded Text('...') literals in lib/ (informational; never fails the run).
"""
import glob
import json
import os
import re
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, "lib", "l10n")
PH = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
ICU = re.compile(r"\{\s*\w+\s*,\s*(plural|select|selectordinal)\s*,")
HTML = re.compile(r"</?[A-Za-z][^>]*>|&[#A-Za-z0-9]+;")
ARABIC = re.compile(r"[؀-ۿ]")
BIDI = {"‎", "‏", "‪", "‫", "‬", "‭", "‮", "⁦", "⁧", "⁨", "⁩", "؜", "​", "‍", "‌", "﻿"}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def strings(d):
    return {k: v for k, v in d.items() if not k.startswith("@")}


def check():
    problems = []
    en_path = os.path.join(L10N, "app_en.arb")
    if not os.path.exists(en_path):
        return ["lib/l10n/app_en.arb is missing"]
    en_d = load(en_path)
    en = strings(en_d)
    for k, v in en.items():
        meta = en_d.get("@" + k) or {}
        declared = meta.get("placeholders", {}) if isinstance(meta, dict) else {}
        found = set(PH.findall(v))
        if found != set(declared):
            problems.append(f"en.{k}: placeholders {sorted(found)} are not exactly the declared ones {sorted(declared)}")
        for name, spec in declared.items():
            if (spec or {}).get("type") != "String":
                problems.append(f"en.{k}: placeholder {name} must be type String (keeps Western digits)")
    for path in sorted(glob.glob(os.path.join(L10N, "app_*.arb"))):
        lang = os.path.basename(path)[4:-4]
        d = load(path)
        s = strings(d)
        for k, v in s.items():
            if not isinstance(v, str):
                problems.append(f"{lang}.{k}: value must be text")
                continue
            if ICU.search(v):
                problems.append(f"{lang}.{k}: ICU plural/select is not allowed in Phase I")
            if HTML.search(v):
                problems.append(f"{lang}.{k}: contains HTML")
            if v != v.strip():
                problems.append(f"{lang}.{k}: has leading/trailing whitespace")
            if any(ch in BIDI for ch in v) or any(unicodedata.category(c) == "Cc" and c != "\n" for c in v):
                problems.append(f"{lang}.{k}: contains control or bidi characters")
        if lang == "en":
            continue
        for k in sorted(set(en) - set(s)):
            problems.append(f"{lang}: missing key {k}")
        for k in sorted(set(s) - set(en)):
            problems.append(f"{lang}: extra key {k}")
        for k in sorted(set(en) & set(s)):
            if set(PH.findall(en[k])) != set(PH.findall(s[k])):
                problems.append(f"{lang}.{k}: placeholders differ from English")
        if lang == "ar":
            for k in sorted(set(en) & set(s)):
                if not ARABIC.search(s[k]) and s[k] != en[k]:
                    problems.append(f"ar.{k}: no Arabic text (and it differs from English)")
    return problems


def finder():
    rx = re.compile(r"""\bText\(\s*(?:'([^'$]*[A-Za-z]{3}[^']*)'|"([^"$]*[A-Za-z]{3}[^"]*)")""")
    rows = []
    for p in glob.glob(os.path.join(ROOT, "lib", "**", "*.dart"), recursive=True):
        if "/l10n/gen/" in p.replace("\\", "/"):
            continue
        n = len(rx.findall(open(p, encoding="utf-8").read()))
        if n:
            rows.append((n, os.path.relpath(p, ROOT)))
    for n, p in sorted(rows, reverse=True):
        print(f"{n:5d}  {p}")
    print(f"{sum(n for n, _ in rows):5d}  total hard-coded Text literals in {len(rows)} files (informational)")


if __name__ == "__main__":
    probs = check()
    for p in probs:
        print("PROBLEM:", p)
    if "--finder" in sys.argv:
        finder()
    if probs:
        sys.exit(1)
    print("l10n checks passed")
