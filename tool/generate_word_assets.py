import csv
import json
import re
from collections import OrderedDict
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE_CSV = ROOT / "ecdict.csv"
BUILTIN_JSON = ROOT / "assets" / "data" / "builtin_words.json"
OXFORD_JSON = ROOT / "assets" / "data" / "oxford_words.json"

WORD_PATTERN = re.compile(r"^[A-Za-z][A-Za-z'-]*$")
TAG_TO_SOURCE = OrderedDict(
    [
        ("cet4", "cet4"),
        ("cet6", "cet6"),
        ("ky", "kaoyan"),
        ("ielts", "ielts"),
        ("toefl", "toefl"),
    ]
)
COMMON_TAGS = {"zk", "gk", "cet4", "cet6", "ky", "ielts", "toefl"}


def normalize_word(word: str) -> str:
    return word.strip().lower()


def should_keep_word(word: str) -> bool:
    return bool(WORD_PATTERN.fullmatch(word.strip()))


def clean_meaning(text: str) -> str:
    cleaned = (text or "").replace("\r", "\n").strip()
    if not cleaned:
        return ""
    lines = [line.strip() for line in cleaned.split("\n") if line.strip()]
    collapsed = "；".join(lines)
    collapsed = collapsed.replace("\\r", "；")
    collapsed = collapsed.replace("\\n", "；")
    collapsed = re.sub(r"\s+", " ", collapsed)
    return collapsed.strip("； ").strip()


def write_json(path: Path, items: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(items, ensure_ascii=True, indent=2) + "\n",
        encoding="utf-8",
    )


def is_common_lookup_word(row: dict[str, str]) -> bool:
    oxford_level = (row.get("oxford") or "").strip()
    collins = int((row.get("collins") or "0") or 0)
    bnc = int((row.get("bnc") or "0") or 0)
    frq = int((row.get("frq") or "0") or 0)
    tags = set((row.get("tag") or "").lower().split())
    return bool(
        (oxford_level and oxford_level != "0")
        or collins > 0
        or bnc > 0
        or frq > 0
        or tags.intersection(COMMON_TAGS)
    )


def main() -> None:
    if not SOURCE_CSV.exists():
        raise SystemExit(f"Missing source file: {SOURCE_CSV}")

    builtin_seen: dict[str, dict[str, str]] = {
        source: OrderedDict() for source in TAG_TO_SOURCE.values()
    }
    oxford_seen: OrderedDict[str, dict[str, str]] = OrderedDict()

    with SOURCE_CSV.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            word = (row.get("word") or "").strip()
            if not word or not should_keep_word(word):
                continue

            meaning = clean_meaning(row.get("translation") or row.get("definition") or "")
            if not meaning:
                continue

            tags = set((row.get("tag") or "").lower().split())
            normalized_word = normalize_word(word)

            for raw_tag, source in TAG_TO_SOURCE.items():
                if raw_tag not in tags or normalized_word in builtin_seen[source]:
                    continue
                builtin_seen[source][normalized_word] = {
                    "word": word,
                    "meaning": meaning,
                    "source": source,
                }

            if is_common_lookup_word(row) and normalized_word not in oxford_seen:
                oxford_seen[normalized_word] = {
                    "word": word,
                    "meaning": meaning,
                }

    builtin_items: list[dict[str, str]] = []
    for source in TAG_TO_SOURCE.values():
        builtin_items.extend(
            sorted(
                builtin_seen[source].values(),
                key=lambda item: item["word"].lower(),
            )
        )

    oxford_items = sorted(
        oxford_seen.values(),
        key=lambda item: item["word"].lower(),
    )

    write_json(BUILTIN_JSON, builtin_items)
    write_json(OXFORD_JSON, oxford_items)

    print("builtin counts:")
    for source in TAG_TO_SOURCE.values():
        print(f"  {source}: {len(builtin_seen[source])}")
    print(f"  total: {len(builtin_items)}")
    print(f"oxford total: {len(oxford_items)}")


if __name__ == "__main__":
    main()
