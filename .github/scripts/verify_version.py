#!/usr/bin/env python3
import json
import re
import sys
import os
from datetime import datetime

def load_release_notes(path):
    try:
        with open(path, "r", encoding="utf-8-sig") as file:
            return json.load(file)
    except Exception:
        return None

def main():
    tag_name = os.environ.get("TAG_NAME", "")
    release_notes_json = os.environ.get("RELEASE_NOTES_JSON", "assets/release_notes/current.json")
    tag_version = tag_name[1:] if tag_name.startswith("v") else tag_name
    app_version = ""
    try:
        with open("pubspec.yaml", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("version:"):
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        app_version = parts[1].split("+")[0]
                    break
    except FileNotFoundError:
        pass
    release_notes = load_release_notes(release_notes_json)
    notes_version = ""
    if isinstance(release_notes, dict):
        notes_version = str(release_notes.get("version", ""))

    def validate_release_notes_schema():
        data = release_notes
        if not isinstance(data, dict):
            return False
        if not isinstance(data.get("version"), str):
            return False
        if not isinstance(data.get("date"), str):
            return False
        notes = data.get("notes")
        if not isinstance(notes, dict):
            return False
        for key in ("added", "changed", "fixed"):
            arr = notes.get(key)
            if not isinstance(arr, list):
                return False
            if not all(isinstance(item, str) for item in arr):
                return False
        return True

    def validate_release_date():
        data = release_notes
        if not isinstance(data, dict):
            return False
        notes_date = str(data.get("date", ""))
        if not re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", notes_date):
            return False
        try:
            parsed = datetime.fromisoformat(notes_date)
            parsed_date = parsed.strftime("%Y-%m-%d")
        except ValueError:
            try:
                parsed = datetime.strptime(notes_date, "%Y-%m-%d")
                parsed_date = parsed.strftime("%Y-%m-%d")
            except ValueError:
                return False
        return parsed_date == notes_date

    if not validate_release_notes_schema():
        print("Release notes do not match the required schema.")
        sys.exit(1)
    if not validate_release_date():
        print("Release notes date must be a valid date in YYYY-MM-DD format.")
        sys.exit(1)
    if tag_version != app_version:
        print("Tag version does not match pubspec.yaml.")
        print(f"Tag: {tag_version}")
        print(f"App: {app_version}")
        sys.exit(1)
    if tag_version != notes_version:
        print("Tag version does not match release notes.")
        print(f"Tag: {tag_version}")
        print(f"Release notes: {notes_version}")
        sys.exit(1)
    print(f"Version verified: {tag_version}")

if __name__ == "__main__":
    main()
