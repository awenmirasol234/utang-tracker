#!/usr/bin/env python3
import os
import sys
import shutil
from pathlib import Path

def copy_apk(source_file, output_name):
    release_dir = os.environ.get("RELEASE_DIR", "release-assets")
    source = Path(source_file)
    if not source.is_file():
        print(f"APK not found: {source_file}")
        sys.exit(1)
    dest = Path(release_dir) / output_name
    shutil.copy(source, dest)

def main():
    release_dir = os.environ.get("RELEASE_DIR", "release-assets")
    app_name = os.environ.get("APP_NAME", "utang-tracker")
    tag_name = os.environ.get("TAG_NAME", "")
    Path(release_dir).mkdir(parents=True, exist_ok=True)
    copy_apk(
        "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk",
        f"{app_name}-arm64-v8a-{tag_name}.apk",
    )
    copy_apk(
        "build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk",
        f"{app_name}-armeabi-v7a-{tag_name}.apk",
    )
    print(f"ARM64 and ARM32 APKs prepared in {release_dir}.")

if __name__ == "__main__":
    main()
