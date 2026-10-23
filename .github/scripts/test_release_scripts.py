#!/usr/bin/env python3
import base64
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

def main():
    repo_root = Path(__file__).resolve().parents[2]
    test_dir = Path(tempfile.mkdtemp())
    try:
        def generate_notes(fixture, output_dir):
            output_dir.mkdir(parents=True, exist_ok=True)
            env = os.environ.copy()
            env["TAG_NAME"] = "v1.0.35"
            env["RELEASE_NOTES_JSON"] = str(fixture)
            script = repo_root / ".github" / "scripts" / "generate_release_notes.py"
            result = subprocess.run(
                [sys.executable, str(script)],
                cwd=output_dir,
                env=env,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                print(result.stdout, file=sys.stdout)
                print(result.stderr, file=sys.stderr)
                sys.exit(result.returncode)

        def assert_contains(expected, file_path):
            content = file_path.read_text(encoding="utf-8")
            if expected not in content:
                print(f"Expected '{expected}' not found in {file_path}")
                print(f"Content was:\n{content}")
                sys.exit(1)

        def assert_no_category_headings(file_path):
            content = file_path.read_text(encoding="utf-8")
            if re.search(r"^## (Added|Changed|Fixed)$", content, re.MULTILINE):
                print(f"Empty release note categories were rendered in {file_path}.")
                sys.exit(1)

        mixed_json = test_dir / "mixed.json"
        mixed_json.write_text(
            '{"version":"1.0.35","date":"2026-08-05","notes":{"added":["New item"],"changed":["Changed item"],"fixed":["Fixed item"]}}',
            encoding="utf-8",
        )
        generate_notes(mixed_json, test_dir / "mixed")
        mixed_output = test_dir / "mixed" / "RELEASE_NOTES.md"
        assert_contains("Release date: 2026-08-05", mixed_output)
        assert_contains("## Added", mixed_output)
        assert_contains("## Changed", mixed_output)
        assert_contains("## Fixed", mixed_output)
        changed_json = test_dir / "changed.json"
        changed_json.write_text(
            '{"version":"1.0.35","date":"2026-08-05","notes":{"added":[],"changed":["Changed item"],"fixed":[]}}',
            encoding="utf-8",
        )
        generate_notes(changed_json, test_dir / "changed")
        changed_output = test_dir / "changed" / "RELEASE_NOTES.md"
        assert_contains("## Changed", changed_output)
        changed_content = Path(changed_output).read_text(encoding="utf-8")
        if re.search(r"^## (Added|Fixed)$", changed_content, re.MULTILINE):
            print(f"Empty Added or Fixed category was rendered in {changed_output}.")
            sys.exit(1)
        empty_json = test_dir / "empty.json"
        empty_json.write_text(
            '{"version":"1.0.35","date":"2026-08-05","notes":{"added":[],"changed":[],"fixed":[]}}',
            encoding="utf-8",
        )
        generate_notes(empty_json, test_dir / "empty")
        assert_no_category_headings(test_dir / "empty" / "RELEASE_NOTES.md")

        configuration_script = (
            repo_root / ".github" / "scripts" / "check_release_configuration.py"
        )
        required_names = (
            "SIGNING_KEY_BASE64",
            "KEY_STORE_PASSWORD",
            "KEY_PASSWORD",
            "KEY_ALIAS",
            "GOOGLE_DRIVE_SERVER_CLIENT_ID",
        )

        def check_configuration(values):
            env = os.environ.copy()
            for name in required_names:
                env.pop(name, None)
            env.update(values)
            return subprocess.run(
                [sys.executable, str(configuration_script)],
                cwd=repo_root,
                env=env,
                capture_output=True,
                text=True,
            )

        valid_configuration = {
            "SIGNING_KEY_BASE64": base64.b64encode(b"test keystore").decode(),
            "KEY_STORE_PASSWORD": "store-password",
            "KEY_PASSWORD": "key-password",
            "KEY_ALIAS": "utang-tracker",
            "GOOGLE_DRIVE_SERVER_CLIENT_ID": "client-id.apps.googleusercontent.com",
        }
        valid_result = check_configuration(valid_configuration)
        if valid_result.returncode != 0:
            print(valid_result.stdout, file=sys.stdout)
            print(valid_result.stderr, file=sys.stderr)
            sys.exit(valid_result.returncode)

        missing_result = check_configuration(
            {
                **valid_configuration,
                "KEY_ALIAS": "",
            }
        )
        if missing_result.returncode == 0 or "KEY_ALIAS" not in missing_result.stdout:
            print("Missing release configuration was not detected.")
            sys.exit(1)

        invalid_result = check_configuration(
            {
                **valid_configuration,
                "SIGNING_KEY_BASE64": "not-base64",
                "GOOGLE_DRIVE_SERVER_CLIENT_ID": "not-a-client-id",
            }
        )
        if (
            invalid_result.returncode == 0
            or "SIGNING_KEY_BASE64 is not valid base64" not in invalid_result.stdout
            or "GOOGLE_DRIVE_SERVER_CLIENT_ID" not in invalid_result.stdout
        ):
            print("Invalid release configuration was not detected.")
            sys.exit(1)

        local_release_script = repo_root / "tool" / "build_android_release.py"
        module_spec = importlib.util.spec_from_file_location(
            "build_android_release",
            local_release_script,
        )
        local_release_module = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(local_release_module)
        local_release_root = test_dir / "local-release"
        (local_release_root / "config").mkdir(parents=True)
        (local_release_root / "android").mkdir()
        (local_release_root / "config" / "local.json").write_text(
            json.dumps(
                {
                    "GOOGLE_DRIVE_SERVER_CLIENT_ID": (
                        "client-id.apps.googleusercontent.com"
                    )
                }
            ),
            encoding="utf-8",
        )
        (local_release_root / "android" / "key.properties").write_text(
            "storePassword=store-password\n"
            "keyPassword=key-password\n"
            "keyAlias=utang-tracker\n"
            "storeFile=app/release.keystore\n",
            encoding="utf-8",
        )
        (local_release_root / "android" / "app").mkdir()
        (local_release_root / "android" / "app" / "release.keystore").write_bytes(
            b"test keystore"
        )
        local_errors = local_release_module.validate_local_configuration(
            local_release_root
        )
        if local_errors:
            print("Valid local release configuration was rejected.")
            print("\n".join(local_errors))
            sys.exit(1)

        print("Release script tests passed.")
    finally:
        shutil.rmtree(str(test_dir), ignore_errors=True)

if __name__ == "__main__":
    main()
