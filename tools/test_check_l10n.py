"""Self-test for tools/check_l10n.py.  Run: python -m unittest tools/test_check_l10n.py   (from the repo root)"""
import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_l10n as C  # noqa: E402

EN = {"@@locale": "en", "hi": "Hello {name}", "@hi": {"placeholders": {"name": {"type": "String"}}}, "bye": "Bye"}
AR = {"@@locale": "ar", "hi": "مرحبا {name}", "bye": "وداعا"}


class T(unittest.TestCase):
    def run_with(self, en, ar):
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d)
        for lang, data in (("en", en), ("ar", ar)):
            with open(os.path.join(d, f"app_{lang}.arb"), "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False)
        old = C.L10N
        C.L10N = d
        try:
            return C.check()
        finally:
            C.L10N = old

    def test_clean_files_pass(self):
        self.assertEqual(self.run_with(EN, AR), [])

    def test_missing_and_extra_keys(self):
        p = self.run_with(EN, {"hi": "مرحبا {name}", "extra": "x"})
        self.assertTrue(any("missing key bye" in x for x in p) and any("extra key extra" in x for x in p))

    def test_placeholder_mismatch_and_non_string_type(self):
        self.assertTrue(any("placeholders differ" in x for x in self.run_with(EN, {**AR, "hi": "مرحبا"})))
        bad = {**EN, "@hi": {"placeholders": {"name": {"type": "int"}}}}
        self.assertTrue(any("must be type String" in x for x in self.run_with(bad, AR)))

    def test_plural_html_whitespace_bidi_and_untranslated(self):
        for value, needle in (("{n, plural, one{a} other{b}}", "ICU"), ("<b>x</b>", "HTML"), (" x", "whitespace"),
                              ("x‮", "control or bidi"), ("Goodbye", "no Arabic text")):
            p = self.run_with(EN, {**AR, "bye": value})
            self.assertTrue(any(needle in x for x in p), (value, p))


if __name__ == "__main__":
    unittest.main()
