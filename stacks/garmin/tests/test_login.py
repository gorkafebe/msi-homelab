"""Offline tests of stacks/garmin/login/login.py.

Run inside the login image with NO network (make garmin-test):
    docker run --rm --network none -v ...:/app/tests:ro --entrypoint python \
        msi-homelab/garmin-login:0.3.20 -I -m unittest discover -s /app/tests -p 'test_login.py' -v

What they prove, without ever contacting Garmin:
  * one run sends the credentials at most ONCE (one strategy, one TLS
    fingerprint), also when Garmin answers 429;
  * wrong credentials stop at once;
  * the real code path with no network ends in a clean error, no retry;
  * only complete DI token files count as usable;
  * the script refuses credentials in the environment and piped input.
"""
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock

sys.path.insert(0, "/app")
import login  # noqa: E402

from garminconnect import GarminConnectAuthenticationError, GarminConnectTooManyRequestsError  # noqa: E402
from garminconnect.client import Client  # noqa: E402

STRATEGY_METHODS = ("_mobile_login_requests", "_widget_web_login",
                    "_portal_web_login_cffi", "_portal_web_login_requests")


class Counter:
    def __init__(self, exc=None):
        self.calls = 0
        self.exc = exc

    def __call__(self, *args, **kwargs):
        self.calls += 1
        if self.exc:
            raise self.exc


class LoginTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        login.TOKEN_DIR = self.tmp.name
        login.TOKEN_FILE = os.path.join(self.tmp.name, "garmin_tokens.json")
        login.HOLD_MARKER = os.path.join(self.tmp.name, "fetcher.hold")

    def tearDown(self):
        self.tmp.cleanup()

    def run_with_mobile(self, exc):
        """Patch the mobile request and count every strategy."""
        mobile = Counter(exc)
        others = {name: Counter(RuntimeError("must not be called")) for name in STRATEGY_METHODS}
        patches = [mock.patch.object(Client, "_do_mobile_login", mobile)]
        patches += [mock.patch.object(Client, name, c) for name, c in others.items()]
        for p in patches:
            p.start()
        try:
            with redirect_stdout(io.StringIO()):
                code = login.login_once("demo@example.com", "not-a-real-password", prompt_mfa=lambda: "000000")
        finally:
            for p in patches:
                p.stop()
        return code, mobile.calls, {n: c.calls for n, c in others.items()}

    def test_429_means_exactly_one_attempt(self):
        code, mobile, others = self.run_with_mobile(GarminConnectTooManyRequestsError("429"))
        self.assertEqual(code, login.EXIT_RATE)
        self.assertEqual(mobile, 1, "credentials must be sent once, with one fingerprint")
        self.assertEqual(sum(others.values()), 0, f"other strategies ran: {others}")

    def test_wrong_credentials_stop_at_once(self):
        code, mobile, others = self.run_with_mobile(GarminConnectAuthenticationError("401"))
        self.assertEqual(code, login.EXIT_CREDENTIALS)
        self.assertEqual(mobile, 1)
        self.assertEqual(sum(others.values()), 0)

    def test_no_network_real_path_fails_cleanly(self):
        # Real mobile strategy, real HTTP client: in a --network none container
        # name resolution fails. Other strategies are counted, must stay at 0.
        others = {name: Counter() for name in STRATEGY_METHODS}
        with mock.patch.multiple(Client, **others):
            buf = io.StringIO()
            with redirect_stdout(buf):
                code = login.login_once("demo@example.com", "not-a-real-password", prompt_mfa=lambda: "000000")
        self.assertIn(code, (login.EXIT_OTHER, login.EXIT_RATE))
        self.assertEqual(sum(c.calls for c in others.values()), 0)
        self.assertFalse(os.path.exists(login.TOKEN_FILE))

    def test_usable_tokens(self):
        f = login.TOKEN_FILE
        self.assertFalse(login.usable_tokens(f))
        for content, ok in (
            ("not json", False),
            (json.dumps({"di_token": None, "di_refresh_token": None, "di_client_id": None}), False),
            (json.dumps({"di_token": "a", "di_refresh_token": "", "di_client_id": "c"}), False),
            (json.dumps({"di_token": "a", "di_refresh_token": "b", "di_client_id": "c"}), True),
        ):
            with open(f, "w", encoding="utf-8") as fh:
                fh.write(content)
            self.assertEqual(login.usable_tokens(f), ok, content)

    def test_refuses_credentials_in_environment(self):
        with mock.patch.dict(os.environ, {"GARMINCONNECT_EMAIL": "demo@example.com"}):
            with redirect_stdout(io.StringIO()):
                self.assertEqual(login.main([]), login.EXIT_REFUSED)

    def test_refuses_without_terminal(self):
        with mock.patch.object(sys.stdin, "isatty", return_value=False):
            with redirect_stdout(io.StringIO()):
                self.assertEqual(login.main([]), login.EXIT_REFUSED)


if __name__ == "__main__":
    unittest.main()
