#!/usr/bin/env python3
"""Tests for tools/gen_remote_l10n.py (run: python tools/test_gen_remote_l10n.py)."""
import importlib.util, pathlib, re, subprocess, sys, tempfile, unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("gen", ROOT / "tools/gen_remote_l10n.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


class GenTests(unittest.TestCase):
    def test_checked_in_files_are_current(self):
        r = subprocess.run([sys.executable, str(ROOT / "tools/gen_remote_l10n.py"), "--check"], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_every_bundled_member_is_overridden_once(self):
        schema, cls, n = gen.build()
        self.assertEqual(n, 1151)
        self.assertEqual(len(re.findall(r"^  @override$", cls, re.M)), n)
        self.assertEqual(len(re.findall(r"^  '\w+': <String>\[", schema, re.M)), n)

    def test_parameterised_member_keeps_signature_and_arguments(self):
        _, cls, _ = gen.build()
        self.assertIn("String otpSentTo(String phone) {", cls)
        self.assertIn("fillRemoteTemplate(t, <String, String>{'phone': phone})", cls)
        self.assertIn("super.otpSentTo(phone)", cls)

    def test_generation_is_deterministic(self):
        self.assertEqual(gen.build(), gen.build())

    def test_arb_files_not_touched_by_generator(self):
        src = (ROOT / "tools/gen_remote_l10n.py").read_text(encoding="utf-8")
        self.assertNotIn("write_text(ROOT", src)
        self.assertNotIn(".arb\").write", src)


if __name__ == "__main__":
    unittest.main(verbosity=2)
