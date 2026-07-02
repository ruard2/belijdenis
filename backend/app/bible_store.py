from __future__ import annotations

from html import unescape
from html.parser import HTMLParser
import json
import re
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BIBLES_DIR = PROJECT_ROOT / "bibles"

BOOK_CODES = {
    "gen": "GEN",
    "genesis": "GEN",
    "exo": "EXO",
    "exodus": "EXO",
    "lev": "LEV",
    "leviticus": "LEV",
    "num": "NUM",
    "numeri": "NUM",
    "deu": "DEU",
    "deuteronomium": "DEU",
    "jos": "JOS",
    "jozua": "JOS",
    "ric": "RIC",
    "richteren": "RIC",
    "rut": "RUT",
    "1samuel": "1SA",
    "1sam": "1SA",
    "1sa": "1SA",
    "2samuel": "2SA",
    "2sam": "2SA",
    "2sa": "2SA",
    "1koningen": "1KI",
    "1kon": "1KI",
    "1ki": "1KI",
    "2koningen": "2KI",
    "2kon": "2KI",
    "2ki": "2KI",
    "1kronieken": "1CH",
    "1kron": "1CH",
    "1chronieken": "1CH",
    "1ch": "1CH",
    "2kronieken": "2CH",
    "2kron": "2CH",
    "2chronieken": "2CH",
    "2ch": "2CH",
    "ezra": "EZR",
    "ezr": "EZR",
    "neh": "NEH",
    "nehemia": "NEH",
    "est": "EST",
    "esther": "EST",
    "job": "JOB",
    "ps": "PSA",
    "psa": "PSA",
    "psalm": "PSA",
    "psalmen": "PSA",
    "spr": "PRO",
    "spreuken": "PRO",
    "prediker": "ECC",
    "hooglied": "SNG",
    "hgl": "SNG",
    "isa": "ISA",
    "jesaja": "ISA",
    "jer": "JER",
    "jeremia": "JER",
    "klaagliederen": "LAM",
    "klaagl": "LAM",
    "ezk": "EZK",
    "ezechiel": "EZK",
    "ezechiël": "EZK",
    "dan": "DAN",
    "daniel": "DAN",
    "daniël": "DAN",
    "hos": "HOS",
    "hosea": "HOS",
    "joel": "JOL",
    "joël": "JOL",
    "amo": "AMO",
    "amos": "AMO",
    "oba": "OBA",
    "obadja": "OBA",
    "jon": "JON",
    "jona": "JON",
    "mic": "MIC",
    "micha": "MIC",
    "nah": "NAM",
    "nahum": "NAM",
    "hab": "HAB",
    "habakuk": "HAB",
    "zef": "ZEP",
    "zefanja": "ZEP",
    "hag": "HAG",
    "haggai": "HAG",
    "zec": "ZEC",
    "zacharia": "ZEC",
    "mal": "MAL",
    "maleachi": "MAL",
    "maleachï": "MAL",
    "mat": "MAT",
    "mattheus": "MAT",
    "mattheüs": "MAT",
    "mrk": "MRK",
    "markus": "MRK",
    "luk": "LUK",
    "lukas": "LUK",
    "jhn": "JHN",
    "joh": "JHN",
    "johannes": "JHN",
    "act": "ACT",
    "handelingen": "ACT",
    "rom": "ROM",
    "romeinen": "ROM",
    "1korinthe": "1CO",
    "1korintiers": "1CO",
    "1korintiërs": "1CO",
    "1kor": "1CO",
    "1co": "1CO",
    "2korinthe": "2CO",
    "2korintiers": "2CO",
    "2korintiërs": "2CO",
    "2kor": "2CO",
    "2co": "2CO",
    "gal": "GAL",
    "galaten": "GAL",
    "efeze": "EPH",
    "efezers": "EPH",
    "ef": "EPH",
    "eph": "EPH",
    "filippenzen": "PHP",
    "fil": "PHP",
    "php": "PHP",
    "col": "COL",
    "kol": "COL",
    "kolossenzen": "COL",
    "1thessalonicenzen": "1TH",
    "1thess": "1TH",
    "1th": "1TH",
    "2thessalonicenzen": "2TH",
    "2thess": "2TH",
    "2th": "2TH",
    "1timotheus": "1TI",
    "1tim": "1TI",
    "1ti": "1TI",
    "2timotheus": "2TI",
    "2tim": "2TI",
    "2ti": "2TI",
    "tit": "TIT",
    "titus": "TIT",
    "filemon": "FIL",
    "filémon": "FIL",
    "flm": "FIL",
    "heb": "HEB",
    "hebreeen": "HEB",
    "hebreeën": "HEB",
    "jak": "JAS",
    "jakobus": "JAS",
    "1petrus": "1PE",
    "1pet": "1PE",
    "1pe": "1PE",
    "2petrus": "2PE",
    "2pet": "2PE",
    "2pe": "2PE",
    "1johannes": "1JN",
    "1joh": "1JN",
    "1jn": "1JN",
    "2johannes": "2JN",
    "2joh": "2JN",
    "2jn": "2JN",
    "3johannes": "3JN",
    "3joh": "3JN",
    "3jn": "3JN",
    "jud": "JUD",
    "judas": "JUD",
    "openbaring": "REV",
    "op": "REV",
    "rev": "REV",
}

BOOK_CHAPTERS = {
    "GEN": 50,
    "EXO": 40,
    "LEV": 27,
    "NUM": 36,
    "DEU": 34,
    "JOS": 24,
    "RIC": 21,
    "RUT": 4,
    "1SA": 31,
    "2SA": 24,
    "1KI": 22,
    "2KI": 25,
    "1CH": 29,
    "2CH": 36,
    "EZR": 10,
    "NEH": 13,
    "EST": 10,
    "JOB": 42,
    "PSA": 150,
    "PRO": 31,
    "ECC": 12,
    "SNG": 8,
    "ISA": 66,
    "JER": 52,
    "LAM": 5,
    "EZK": 48,
    "DAN": 12,
    "HOS": 14,
    "JOL": 3,
    "AMO": 9,
    "OBA": 1,
    "JON": 4,
    "MIC": 7,
    "NAM": 3,
    "HAB": 3,
    "ZEP": 3,
    "HAG": 2,
    "ZEC": 14,
    "MAL": 4,
    "MAT": 28,
    "MRK": 16,
    "LUK": 24,
    "JHN": 21,
    "ACT": 28,
    "ROM": 16,
    "1CO": 16,
    "2CO": 13,
    "GAL": 6,
    "EPH": 6,
    "PHP": 4,
    "COL": 4,
    "1TH": 5,
    "2TH": 3,
    "1TI": 6,
    "2TI": 4,
    "TIT": 3,
    "FIL": 1,
    "HEB": 13,
    "JAS": 5,
    "1PE": 5,
    "2PE": 3,
    "1JN": 5,
    "2JN": 1,
    "3JN": 1,
    "JUD": 1,
    "REV": 22,
}

TRANSLATIONS = {
    "HSV": "bijbel_hsv",
    "NBV21": "bijbel_nbv21",
    "BGT": "bijbel_BGT",
}


def available_translations() -> list[dict[str, str]]:
    return [
        {"id": translation, "label": translation}
        for translation, folder in TRANSLATIONS.items()
        if (BIBLES_DIR / folder).exists()
    ]


def get_passage(reference: str, translation: str) -> dict[str, Any]:
    parsed = parse_reference(reference)
    folder = BIBLES_DIR / TRANSLATIONS.get(translation.upper(), "")
    if not folder.exists():
        return _missing(reference, translation, "Vertaling niet gevonden.")

    candidates = passage_candidates(folder, parsed["book"], parsed["chapter"])
    if not candidates:
        return _missing(reference, translation, "Bijbelhoofdstuk niet gevonden.")

    attempts: list[str] = []
    last_payload: dict[str, Any] | None = None

    for label, data in candidates:
        verses = extract_verses(data, parsed["start"], parsed["end"])
        unusable_reason = unusable_text_reason(verses, parsed["book"], label)
        attempts.append(unusable_reason or f"{label}: bruikbaar")
        if unusable_reason is None:
            return {
                "reference": reference,
                "translation": translation.upper(),
                "book": parsed["book"],
                "chapter": parsed["chapter"],
                "start": parsed["start"],
                "end": parsed["end"],
                "source_url": data.get("url", ""),
                "source": label,
                "attempts": attempts,
                "verses": verses,
                "status": "ok",
                "message": "",
            }
        last_payload = data

    return {
        "reference": reference,
        "translation": translation.upper(),
        "book": parsed["book"],
        "chapter": parsed["chapter"],
        "start": parsed["start"],
        "end": parsed["end"],
        "source_url": (last_payload or {}).get("url", ""),
        "source": candidates[-1][0],
        "attempts": attempts,
        "verses": [],
        "status": "source_unusable",
        "message": "Geen bruikbare lokale Bijbeltekst gevonden voor deze passage.",
    }


def passage_candidates(
    folder: Path,
    book: str,
    chapter: int,
) -> list[tuple[str, dict[str, Any]]]:
    candidates: list[tuple[str, dict[str, Any]]] = []

    direct = folder / f"{book}_{chapter:03}.json"
    if direct.exists():
        data = json.loads(direct.read_text(encoding="utf-8"))
        if _needs_numbered_verses(data):
            data = _ensure_numbered_verses(direct, data)
        candidates.append((direct.name, data))

    full = folder / f"{book}_full.json"
    if full.exists():
        full_data = json.loads(full.read_text(encoding="utf-8"))
        chapter_data = full_data.get("chapters", {}).get(f"chapter_{chapter}")
        if isinstance(chapter_data, dict):
            candidates.append((f"{full.name} > chapter_{chapter}", chapter_data))

    complete = folder / "complete_bible.json"
    if complete.exists():
        complete_data = json.loads(complete.read_text(encoding="utf-8"))
        chapter_data = complete_data.get(book, {}).get(f"chapter_{chapter}")
        if isinstance(chapter_data, dict):
            candidates.append((f"{complete.name} > {book}.chapter_{chapter}", chapter_data))

    return candidates


def parse_reference(reference: str) -> dict[str, int | str]:
    match = re.match(
        r"^\s*([1-3]?\s*[A-Za-zÀ-ÿ]+)\s+(\d+)(?::(\d+)(?:-(\d+))?)?\s*$",
        reference,
    )
    if not match:
        raise ValueError(f"Kan Bijbelreferentie niet lezen: {reference}")

    raw_book_name = match.group(1).replace(" ", "")
    book_code = raw_book_name.upper()
    book_name = raw_book_name.lower()
    if book_code not in BOOK_CHAPTERS:
        book_code = BOOK_CODES.get(book_name, "")
    if not book_code:
        raise ValueError(f"Onbekend Bijbelboek: {match.group(1)}")

    chapter = int(match.group(2))
    if chapter < 1 or chapter > BOOK_CHAPTERS.get(book_code, chapter):
        raise ValueError(f"{book_code} heeft geen hoofdstuk {chapter}")
    start = int(match.group(3) or 1)
    end = int(match.group(4)) if match.group(4) else (start if match.group(3) else None)
    return {"book": book_code, "chapter": chapter, "start": start, "end": end}


def extract_verses(data: dict[str, Any], start: int, end: int | None) -> list[dict[str, Any]]:
    numbered_verses = data.get("numbered_verses")
    if isinstance(numbered_verses, list):
        by_number: dict[int, str] = {}
        for verse in numbered_verses:
            if not isinstance(verse, dict):
                continue
            try:
                number = int(verse["number"])
            except (KeyError, TypeError, ValueError):
                continue
            by_number[number] = clean_text(str(verse.get("text", "")))
        last = end if end is not None else max(by_number.keys(), default=start)
        return [
            {"number": verse_number, "text": by_number[verse_number]}
            for verse_number in range(start, last + 1)
            if by_number.get(verse_number)
        ]

    raw_verses = data.get("verses", [])
    if not isinstance(raw_verses, list):
        return []

    verse_parts: dict[int, list[str]] = {}
    for item in raw_verses:
        if not isinstance(item, dict) or "verse" not in item:
            continue
        try:
            number = int(item["verse"])
        except (TypeError, ValueError):
            continue
        text = clean_text(str(item.get("text", "")))
        if text:
            verse_parts.setdefault(number, []).append(text)

    if verse_parts:
        last = end if end is not None else max(verse_parts.keys(), default=start)
        return [
            {"number": verse_number, "text": clean_text(" ".join(verse_parts[verse_number]))}
            for verse_number in range(start, last + 1)
            if verse_parts.get(verse_number)
        ]

    extracted: list[dict[str, Any]] = []
    last = end if end is not None else len(raw_verses)
    for verse_number in range(start, last + 1):
        index = verse_number - 1
        if index < 0 or index >= len(raw_verses):
            continue
        text = clean_text(str(raw_verses[index]))
        extracted.append({"number": verse_number, "text": text})
    return extracted


def _needs_numbered_verses(data: dict[str, Any]) -> bool:
    if data.get("numbered_verses"):
        return False
    verses = data.get("verses")
    if isinstance(verses, list) and any(isinstance(item, dict) and "verse" in item for item in verses):
        return False
    url = data.get("url", "")
    return isinstance(url, str) and url.startswith("http")


def _ensure_numbered_verses(path: Path, data: dict[str, Any]) -> dict[str, Any]:
    try:
        numbered = fetch_numbered_verses(str(data["url"]), str(data["book"]), int(data["chapter"]))
    except Exception:
        return data
    if not numbered:
        return data

    data["numbered_verses"] = numbered
    data["numbered_verse_count"] = len(numbered)
    try:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    except OSError:
        pass
    return data


def fetch_numbered_verses(url: str, book: str, chapter: int) -> list[dict[str, Any]]:
    request = Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(request, timeout=20) as response:
        html = response.read().decode("utf-8", errors="replace")
    parser = VerseHtmlParser(book, chapter)
    parser.feed(html)
    return parser.verses()


class VerseHtmlParser(HTMLParser):
    def __init__(self, book: str, chapter: int) -> None:
        super().__init__(convert_charrefs=True)
        self.book = book
        self.chapter = chapter
        self.active_verses: list[int | None] = []
        self.parts: dict[int, list[str]] = {}

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr_map = dict(attrs)
        verse_id = attr_map.get("data-verse-org-id") or attr_map.get("id")
        verse_number = self._verse_number(verse_id or "")
        self.active_verses.append(verse_number if verse_number is not None else self._current_verse())

    def handle_endtag(self, tag: str) -> None:
        if self.active_verses:
            self.active_verses.pop()

    def handle_data(self, data: str) -> None:
        verse_number = self._current_verse()
        text = clean_text(unescape(data))
        if verse_number is None or not text:
            return
        if text in {"HSV", "Herziene Statenvertaling"}:
            return
        self.parts.setdefault(verse_number, []).append(text)

    def _current_verse(self) -> int | None:
        for verse_number in reversed(self.active_verses):
            if verse_number is not None:
                return verse_number
        return None

    def _verse_number(self, verse_id: str) -> int | None:
        match = re.search(rf"{re.escape(self.book)}\.{self.chapter}\.(\d+)\b", verse_id)
        if not match:
            return None
        return int(match.group(1))

    def verses(self) -> list[dict[str, Any]]:
        result = []
        for number in sorted(self.parts):
            text = clean_text(" ".join(self.parts[number]))
            if text:
                result.append({"number": number, "text": text})
        return result


def clean_text(text: str) -> str:
    if "Ã" in text or "Â" in text:
        try:
            text = text.encode("latin1").decode("utf-8")
        except UnicodeError:
            pass
    if "Ã" in text or "â" in text:
        try:
            text = text.encode("latin1").decode("utf-8")
        except UnicodeError:
            pass
    text = re.sub(r"\s+", " ", text).strip()
    return text


def clean_text(text: str) -> str:
    for _ in range(2):
        if not any(
            marker in text
            for marker in ("Ã", "Â", "â€", "â€™", "â€œ", "â€�", "â€“", "â€”")
        ):
            break
        try:
            repaired = text.encode("latin1").decode("utf-8")
        except UnicodeError:
            break
        if repaired == text:
            break
        text = repaired
    text = re.sub(r"\s+", " ", text).strip()
    return text


def clean_text(text: str) -> str:
    markers = ("Ã", "Â", chr(226), chr(65533))
    for _ in range(2):
        if not any(marker in text for marker in markers):
            break
        try:
            repaired = text.encode("latin1").decode("utf-8")
        except UnicodeError:
            break
        if repaired == text:
            break
        text = repaired
    text = re.sub(r"\s+", " ", text).strip()
    return text


def unusable_text_reason(
    verses: list[dict[str, Any]],
    expected_book: str,
    filename: str,
) -> str | None:
    combined = " ".join(verse["text"] for verse in verses).lower()
    if not combined:
        return f"{filename} is gevonden, maar bevat geen leesbare verzen voor deze passage."
    if expected_book != "GEN" and "in het begin schiep god" in combined:
        return (
            f"{filename} is gevonden, maar de inhoud lijkt Genesis 1 te zijn "
            f"in plaats van {expected_book}."
        )
    if "gratis account" in combined or "extra bijbelvertalingen" in combined:
        return (
            f"{filename} is gevonden, maar bevat vooral website-interface tekst "
            "in plaats van Bijbeltekst."
        )
    return None


def _missing(reference: str, translation: str, message: str) -> dict[str, Any]:
    return {
        "reference": reference,
        "translation": translation.upper(),
        "verses": [],
        "status": "missing",
        "message": message,
    }
