#!/usr/bin/env python3
import base64
import os
import sys


REQUIRED_SECRETS = (
    "SIGNING_KEY_BASE64",
    "KEY_STORE_PASSWORD",
    "KEY_PASSWORD",
    "KEY_ALIAS",
)
GOOGLE_DRIVE_CLIENT_ID = "GOOGLE_DRIVE_SERVER_CLIENT_ID"


def validate_configuration(environment):
    errors = []
    for name in REQUIRED_SECRETS:
        if not environment.get(name, "").strip():
            errors.append(f"Missing required GitHub Secret: {name}")

    signing_key = environment.get("SIGNING_KEY_BASE64", "").strip()
    if signing_key:
        try:
            decoded_key = base64.b64decode(signing_key, validate=True)
            if not decoded_key:
                errors.append("SIGNING_KEY_BASE64 is empty after decoding")
        except Exception:
            errors.append("SIGNING_KEY_BASE64 is not valid base64")

    client_id = environment.get(GOOGLE_DRIVE_CLIENT_ID, "").strip()
    if not client_id:
        errors.append(
            "Missing required GitHub repository Variable: "
            f"{GOOGLE_DRIVE_CLIENT_ID}"
        )
    elif not client_id.endswith(".apps.googleusercontent.com"):
        errors.append(
            f"{GOOGLE_DRIVE_CLIENT_ID} must be a Google OAuth client ID"
        )

    return errors


def main():
    errors = validate_configuration(os.environ)
    if errors:
        for error in errors:
            print(f"::error::{error}")
        sys.exit(1)
    print("Release configuration preflight passed.")


if __name__ == "__main__":
    main()
