"""Validación reproducible del manifiesto por plataforma (sin servicios externos)."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("generate-manifest.py")
SHA_A = "a" * 64
SHA_B = "b" * 64


class ReleaseManifestTest(unittest.TestCase):
    def generate(self, previous=None, mac_sha=""):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            old = root / "previous.json"
            if previous is not None:
                old.write_text(json.dumps(previous), encoding="utf-8")
            output = root / "latest.json"
            env = dict(os.environ, BARLYTICS_UPDATE_MANDATORY="false")
            subprocess.run([
                sys.executable, str(SCRIPT),
                "--version", "1.0.0",
                "--build", "2019001000",
                "--windows-sha", SHA_A,
                "--linux-sha", SHA_B,
                "--macos-sha", mac_sha,
                "--previous", str(old),
                "--output", str(output),
            ], env=env, check=True)
            return json.loads(output.read_text(encoding="utf-8"))

    def test_android_only_enabled_after_published_job(self):
        result = self.generate()
        self.assertTrue(result["platforms"]["android"]["enabled"])
        self.assertEqual(2019001000, result["platforms"]["android"]["build"])
        self.assertIn("com.mcode.barlytics", result["platforms"]["android"]["url"])
        for platform in ("windows", "linux"):
            self.assertEqual(2019001000, result["platforms"][platform]["build"])

    def test_previous_macos_must_keep_its_original_build(self):
        previous = {"platforms": {
            "macos": {
                "version": "1.0.0", "build": 2019000800,
                "url": "https://www.barlytics.com.co/downloads/BarLytics-macOS.dmg",
                "enabled": True, "sha256": SHA_A,
            },
        }}
        result = self.generate(previous, mac_sha=SHA_A)
        self.assertEqual(2019000800, result["platforms"]["macos"]["build"])
        result = self.generate(previous, mac_sha=SHA_B)
        self.assertFalse(result["platforms"]["macos"]["enabled"])

    def test_previous_testflight_release_is_not_replaced_by_a_new_web_build(self):
        previous = {"platforms": {"ios": {
            "version": "1.0.0", "build": 2026110419201,
            "enabled": True,
            "url": "https://apps.apple.com/app/testflight/id899247664",
            "channel": "testflight",
        }}}
        result = self.generate(previous)
        self.assertEqual(2026110419201, result["platforms"]["ios"]["build"])
        self.assertEqual("testflight", result["platforms"]["ios"]["channel"])

    def test_no_published_ios_release_leaves_channel_disabled(self):
        result = self.generate()
        self.assertEqual({"enabled": False}, result["platforms"]["ios"])


if __name__ == "__main__":
    unittest.main()
