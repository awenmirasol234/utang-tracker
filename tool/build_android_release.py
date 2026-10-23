#!/usr/bin/env python3
import json
import os
import subprocess
import sys
from pathlib import Path


REQUIRED_SIGNING_PROPERTIES = (
    "storePassword",
    "keyPassword",
    "keyAlias",
    "storeFile",
)
CLIENT_ID_KEY = "GOOGLE_DRIVE_SERVER_CLIENT_ID"


def load_properties(path):
    properties = {}
    for line_number, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith("!"):
            continue
        if "=" not in line:
            raise ValueError(f"{path} line {line_number} must contain '='")
        name, value = line.split("=", 1)
        properties[name.strip()] = value.strip()
    return properties


def validate_local_configuration(repo_root):
    errors = []
    config_path = repo_root / "config" / "local.json"
    key_properties_path = repo_root / "android" / "key.properties"

    if not config_path.is_file():
        errors.append(
            "Missing config/local.json. Copy config/local.json.example and "
            "set the real OAuth client ID."
        )
    else:
        try:
            configuration = json.loads(config_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            errors.append("config/local.json is not valid JSON.")
        else:
            client_id = str(configuration.get(CLIENT_ID_KEY, "")).strip()
            if not client_id:
                errors.append(f"{CLIENT_ID_KEY} is missing from config/local.json.")
            elif not client_id.endswith(".apps.googleusercontent.com"):
                errors.append(f"{CLIENT_ID_KEY} is not a Google OAuth client ID.")

    if not key_properties_path.is_file():
        errors.append("Missing android/key.properties.")
    else:
        try:
            signing_properties = load_properties(key_properties_path)
        except (OSError, ValueError) as error:
            errors.append(str(error))
        else:
            for name in REQUIRED_SIGNING_PROPERTIES:
                if not signing_properties.get(name, ""):
                    errors.append(f"{name} is missing from android/key.properties.")

            store_file = signing_properties.get("storeFile", "")
            if store_file:
                keystore_path = Path(store_file)
                if not keystore_path.is_absolute():
                    keystore_path = key_properties_path.parent / keystore_path
                if not keystore_path.is_file():
                    errors.append(
                        f"The keystore referenced by storeFile does not exist: "
                        f"{store_file}"
                    )

    return errors


def main():
    repo_root = Path(__file__).resolve().parents[1]
    errors = validate_local_configuration(repo_root)
    if errors:
        for error in errors:
            print(f"error: {error}")
        return 1

    flutter_command = "flutter.bat" if os.name == "nt" else "flutter"
    command = [
        flutter_command,
        "build",
        "apk",
        "--release",
        "--split-per-abi",
        "--target-platform",
        "android-arm,android-arm64",
        "--dart-define-from-file=config/local.json",
    ]
    print("Local Android release configuration passed.", flush=True)
    print(
        "Running: flutter build apk --release "
        "--split-per-abi --target-platform android-arm,android-arm64 "
        "--dart-define-from-file=config/local.json",
        flush=True,
    )
    result = subprocess.run(command, cwd=repo_root)
    if result.returncode != 0:
        return result.returncode

    artifact_directory = repo_root / "build" / "app" / "outputs" / "flutter-apk"
    artifacts = (
        artifact_directory / "app-armeabi-v7a-release.apk",
        artifact_directory / "app-arm64-v8a-release.apk",
    )
    missing_artifacts = [artifact for artifact in artifacts if not artifact.is_file()]
    if missing_artifacts:
        for artifact in missing_artifacts:
            print(f"error: Expected APK was not created: {artifact}")
        return 1
    for artifact in artifacts:
        print(f"Android release APK: {artifact}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
