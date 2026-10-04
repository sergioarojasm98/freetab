"""Merge tools/translations_<lang>.json into Freetab/Localizable.xcstrings (run after `xcstringstool sync`).

Keys without a translation are reported; format-only keys ("0", "+%lld", "%@ · %@", "Freetab") are left as-is.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Freetab/Localizable.xcstrings"
UNTRANSLATED = {"0", "+%lld", "%@ · %@", "Freetab"}


def main(lang: str = "es") -> int:
    catalog = json.loads(CATALOG.read_text())
    translations = json.loads((ROOT / f"tools/translations_{lang}.json").read_text())
    missing = []
    for key, entry in catalog["strings"].items():
        if key in UNTRANSLATED:
            entry["shouldTranslate"] = False
            continue
        value = translations.get(key)
        if value is None:
            missing.append(key)
            continue
        entry.setdefault("localizations", {})[lang] = {"stringUnit": {"state": "translated", "value": value}}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    stale = sorted(set(translations) - set(catalog["strings"]))
    print(f"{lang}: {len(catalog['strings']) - len(missing) - len(UNTRANSLATED & set(catalog['strings']))} translated, "
          f"{len(missing)} missing, {len(stale)} unused")
    for key in missing:
        print("  missing:", key)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
