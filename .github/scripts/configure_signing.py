#!/usr/bin/env python3
import os
import sys
import base64
from pathlib import Path

def main():
    signing_key_base64 = os.environ.get("SIGNING_KEY_BASE64", "")
    key_store_password = os.environ.get("KEY_STORE_PASSWORD", "")
    key_password = os.environ.get("KEY_PASSWORD", "")
    key_alias = os.environ.get("KEY_ALIAS", "")
    required_values = (
        ("SIGNING_KEY_BASE64", signing_key_base64),
        ("KEY_STORE_PASSWORD", key_store_password),
        ("KEY_PASSWORD", key_password),
        ("KEY_ALIAS", key_alias),
    )
    for name, value in required_values:
        if not value:
            print(f"{name} is missing.")
            sys.exit(1)
    keystore_path = Path("android/app/release.keystore")
    keystore_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        decoded = base64.b64decode(signing_key_base64, validate=True)
    except Exception:
        decoded = base64.b64decode(signing_key_base64)
    keystore_path.write_bytes(decoded)
    key_properties_path = Path("android/key.properties")
    key_properties_path.parent.mkdir(parents=True, exist_ok=True)
    with open(key_properties_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"storePassword={key_store_password}\n")
        f.write(f"keyPassword={key_password}\n")
        f.write(f"keyAlias={key_alias}\n")
        f.write("storeFile=app/release.keystore\n")
    print("Android signing configured.")

if __name__ == "__main__":
    main()
