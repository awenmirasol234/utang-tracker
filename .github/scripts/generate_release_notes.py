#!/usr/bin/env python3
import json
import sys
import os
from pathlib import Path

CATEGORY_TITLES = {
    "added": "Added",
    "changed": "Changed",
    "fixed": "Fixed",
}


def category_title(category):
    return CATEGORY_TITLES.get(category, category)


def main():
    release_notes_json = os.environ.get("RELEASE_NOTES_JSON", "assets/release_notes/current.json")
    tag_name = os.environ.get("TAG_NAME", "")
    if not Path(release_notes_json).is_file():
        print(f"Release notes file not found: {release_notes_json}")
        sys.exit(1)
    with open(release_notes_json, "r", encoding="utf-8-sig") as f:
        data = json.load(f)
    release_date = data.get("date", "")
    with open("RELEASE_NOTES.md", "w", encoding="utf-8", newline="\n") as out:
        out.write(f"What's new in {tag_name}\n")
        out.write("\n")
        out.write(f"Release date: {release_date}\n")
        out.write("\n")
        for category in ("added", "changed", "fixed"):
            notes = data.get("notes", {}).get(category, [])
            if not notes:
                continue
            title = category_title(category)
            out.write(f"## {title}\n")
            out.write("\n")
            for note in notes:
                out.write(f"- {note}\n")
            out.write("\n")
    print("Release notes generated.")

if __name__ == "__main__":
    main()
