"""One-shot, manual first login to Garmin Connect.

Run it ONCE, by hand, in a terminal (docs/GARMIN.md shows the exact command).
It asks for the e-mail, the password (hidden, with getpass) and, if the
account has it, the MFA code; it makes ONE login attempt and stores only the
session tokens in the garmin-tokens volume. The fetcher then works from those
tokens and never sees the password.

Why so strict (docs/GARMIN.md):
  * Garmin answers repeated logins with HTTP 429/427 and may lock the account
    for a long time. garminconnect normally tries up to five strategies and
    several TLS fingerprints in one login() call; here only ONE strategy with
    ONE fingerprint is allowed, so one run = one set of credentials sent.
  * Nothing is retried. On any failure the script explains and exits.
  * The password lives only in this process's memory: never in a file, the
    environment, an argument or a log. Library logging is switched off.

Library: garminconnect 0.3.20 (pinned with hashes in requirements.txt). Its
token file has the same path and keys as the 0.3.7 used by the fetcher; that
compatibility is read from both versions' source code, NOT tested against
Garmin (docs/GARMIN.md, "Token compatibility").
"""
import getpass
import json
import logging
import os
import sys

TOKEN_DIR = os.environ.get("TOKEN_DIR", "/tokens")
TOKEN_FILE = os.path.join(TOKEN_DIR, "garmin_tokens.json")
HOLD_MARKER = os.path.join(TOKEN_DIR, "fetcher.hold")

# The only strategy kept: the mobile login that 0.3.20 fixed, with one TLS
# fingerprint. All the others in 0.3.20 are skipped.
KEEP_STRATEGY = "mobile+cffi"
ALL_STRATEGIES = {"mobile+cffi", "mobile+requests", "widget+cffi", "portal+cffi", "portal+requests"}
ONE_IMPERSONATION = ("safari_ios",)

EXIT_OK, EXIT_REFUSED, EXIT_EXISTS, EXIT_RATE, EXIT_CREDENTIALS, EXIT_OTHER, EXIT_NOT_PERSISTABLE = 0, 1, 2, 3, 4, 5, 6


def usable_tokens(path=TOKEN_FILE):
    """True if the file holds the three DI token fields the fetcher needs."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return False
    return isinstance(data, dict) and all(
        isinstance(data.get(k), str) and data.get(k) for k in ("di_token", "di_refresh_token", "di_client_id")
    )


def restrict_to_one_attempt(garmin):
    """Make login() send the credentials at most once."""
    from garminconnect.client import sso

    sso.MOBILE_IMPERSONATIONS = ONE_IMPERSONATION
    garmin.client.skip_strategies = ALL_STRATEGIES - {KEEP_STRATEGY}


def login_once(email, password, prompt_mfa):
    """One login attempt. Returns an exit code; never raises for login errors."""
    from garminconnect import (
        Garmin,
        GarminConnectAuthenticationError,
        GarminConnectConnectionError,
        GarminConnectTooManyRequestsError,
    )

    garmin = Garmin(email=email, password=password, prompt_mfa=prompt_mfa)
    restrict_to_one_attempt(garmin)
    try:
        garmin.login(TOKEN_DIR)
    except GarminConnectTooManyRequestsError:
        print("Garmin refused the attempt as rate-limited or blocked (HTTP 429/427).\n"
              "Do NOT try again now: wait several hours (a day is safer) before one new attempt.")
        return EXIT_RATE
    except GarminConnectAuthenticationError:
        print("Garmin rejected the e-mail/password (or the MFA code).\n"
              "Check them in the Garmin Connect web site first; repeated wrong attempts can lock the account.")
        return EXIT_CREDENTIALS
    except GarminConnectConnectionError as err:
        print(f"Login did not complete ({type(err).__name__}). It may be a network problem or a bot\n"
              "challenge from Garmin. Do not retry in a loop; see docs/GARMIN.md.")
        return EXIT_OTHER
    except Exception as err:  # noqa: BLE001 - report the type only, never the message
        print(f"Unexpected error during login: {type(err).__name__}. Nothing was retried.")
        return EXIT_OTHER
    finally:
        password = None  # noqa: F841 - drop our reference as early as possible

    if not usable_tokens():
        print("Login succeeded but Garmin returned a web-only session that cannot be saved\n"
              "(no DI tokens). The fetcher cannot use it. Do not retry now; see docs/GARMIN.md.")
        return EXIT_NOT_PERSISTABLE
    os.chmod(TOKEN_FILE, 0o600)
    if os.path.exists(HOLD_MARKER):
        os.remove(HOLD_MARKER)
        print("Removed the fetcher's hold marker.")
    print("Tokens saved in the garmin-tokens volume (mode 600). Restart the fetcher\n"
          "to use them (docs/GARMIN.md). The password was not stored anywhere.")
    return EXIT_OK


def main(argv):
    logging.disable(logging.CRITICAL)
    for name in ("GARMINCONNECT_EMAIL", "GARMINCONNECT_BASE64_PASSWORD", "GARMINTOKENS"):
        if os.environ.get(name):
            print(f"Refusing to run: {name} is set in the environment. Credentials are typed, never configured.")
            return EXIT_REFUSED
    if not sys.stdin.isatty():
        print("Refusing to run without a terminal: the password must be typed (hidden), not piped.")
        return EXIT_REFUSED
    if usable_tokens() and "--replace" not in argv:
        print("A usable token file already exists. Nothing to do.\n"
              "To replace it on purpose, run again with --replace.")
        return EXIT_EXISTS
    if os.path.exists(TOKEN_FILE):
        os.replace(TOKEN_FILE, TOKEN_FILE + ".old")
        print("Moved the previous token file to garmin_tokens.json.old.")

    print("One login attempt will be made. Nothing is retried.")
    email = input("Garmin e-mail: ").strip()
    password = getpass.getpass("Garmin password (hidden): ")
    if not email or not password:
        print("Empty e-mail or password: nothing was sent.")
        return EXIT_REFUSED
    try:
        return login_once(email, password, prompt_mfa=lambda: input("MFA code (e-mail or SMS): ").strip())
    finally:
        password = None  # noqa: F841


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
