#!/usr/bin/env python3
"""Genereert DinnerCore/EmojiCatalogData.swift uit de officiele Unicode-data.

Bronnen:
  - https://unicode.org/Public/emoji/<versie>/emoji-test.txt  (welke emoji bestaan
    en in welke groep ze zitten)
  - https://github.com/unicode-org/cldr  common/annotations/<taal>.xml
    (de trefwoorden per emoji, per taal)

Draaien:  python3 Tools/generate-emoji-catalog.py
De uitvoer wordt gecommit; de app doet zelf nooit een netwerkverzoek.
"""

import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

EMOJI_VERSION = "16.0"
LANGUAGES = ["en", "nl", "de", "fr", "es"]
EMOJI_TEST_URL = f"https://unicode.org/Public/emoji/{EMOJI_VERSION}/emoji-test.txt"
CLDR_URL = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/{lang}.xml"

# Alleen groepen waar een avondmaaltijd uit komt. Dranken, snoep en serviesgoed
# leveren vooral ruis op ("taart" hoort bij het toetje, niet bij het hoofdgerecht),
# maar food-sweet blijft erin omdat mensen pannenkoeken als avondeten eten.
WANTED_SUBGROUPS = {
    "food-fruit",
    "food-vegetable",
    "food-prepared",
    "food-asian",
    "food-marine",
    "food-sweet",
}

# Trefwoorden die op zoveel emoji zitten dat ze niets onderscheiden.
STOPWORDS = {
    # Nederlands en Engels
    "eten", "voedsel", "honger", "hongerig", "maaltijd", "lekker", "smakelijk",
    "food", "hungry", "meal", "eat", "dish", "cuisine", "restaurant",
    "plant", "plantaardig", "vegetable", "groente", "fruit", "vrucht",
    "dier", "animal", "gerecht",
    # Duits, Frans, Spaans
    "essen", "lebensmittel", "hunger", "hungrig", "mahlzeit", "gericht",
    "gemuse", "gemuese", "obst", "pflanze", "tier", "speise", "lecker",
    "nourriture", "aliment", "repas", "faim", "plat", "legume", "cuisine",
    "manger", "fruits", "animal", "plante",
    "comida", "alimento", "hambre", "plato", "verdura", "vegetal",
    "comer", "fruta", "planta",
}

VARIATION_SELECTOR = "️"


def fetch(url: str) -> str:
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read().decode("utf-8")


def strip_variation(emoji: str) -> str:
    return emoji.replace(VARIATION_SELECTOR, "")


def parse_emoji_test(text: str):
    """Levert de emoji uit de gewenste subgroepen op, in bronvolgorde."""
    emojis = []
    subgroup = None
    for line in text.splitlines():
        if line.startswith("# subgroup:"):
            subgroup = line.split(":", 1)[1].strip()
            continue
        if not line or line.startswith("#"):
            continue
        if subgroup not in WANTED_SUBGROUPS:
            continue
        if "; fully-qualified" not in line:
            continue
        comment = line.split("#", 1)[1].strip()
        emoji = comment.split(" ", 1)[0]
        # Huidskleurvarianten leveren dezelfde betekenis met een andere codepoint.
        if any(0x1F3FB <= ord(ch) <= 0x1F3FF for ch in emoji):
            continue
        emojis.append(emoji)
    return emojis


def parse_annotations(xml: str):
    """cp -> (trefwoorden, naam) uit een CLDR-annotatiebestand."""
    keywords, names = {}, {}
    pattern = re.compile(r'<annotation cp="([^"]+)"(?: type="(tts)")?>([^<]*)</annotation>')
    for cp, tts, body in pattern.findall(xml):
        key = strip_variation(cp)
        value = body.strip()
        if tts == "tts":
            names[key] = value
        else:
            keywords[key] = [part.strip() for part in value.split("|") if part.strip()]
    return keywords, names


def normalise(word: str) -> str:
    """Kleine letters, zonder accenten — zo matcht 'rosti' ook op 'rösti'."""
    lowered = word.strip().lower()
    decomposed = unicodedata.normalize("NFD", lowered)
    stripped = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return unicodedata.normalize("NFC", stripped)


def usable(word: str) -> bool:
    if len(word) < 3:
        return False
    if word in STOPWORDS:
        return False
    if not all(ch.isalpha() or ch in " -" for ch in word):
        return False
    return True


def main() -> int:
    print(f"Ophalen {EMOJI_TEST_URL}", file=sys.stderr)
    emojis = parse_emoji_test(fetch(EMOJI_TEST_URL))
    print(f"  {len(emojis)} emoji in de gekozen groepen", file=sys.stderr)

    per_language = {}
    for lang in LANGUAGES:
        url = CLDR_URL.format(lang=lang)
        print(f"Ophalen {url}", file=sys.stderr)
        per_language[lang] = parse_annotations(fetch(url))

    entries = []
    for emoji in emojis:
        key = strip_variation(emoji)
        words = []
        for lang in LANGUAGES:
            keywords, names = per_language[lang]
            for word in [names.get(key, "")] + keywords.get(key, []):
                normalised = normalise(word)
                if usable(normalised) and normalised not in words:
                    words.append(normalised)
        if words:
            entries.append((emoji, words))

    print(f"  {len(entries)} emoji met bruikbare trefwoorden", file=sys.stderr)

    # Compact formaat: emoji, dubbele punt, trefwoorden met komma's, puntkomma
    # ertussen. Een groot Swift-array van tuples kost minuten compileertijd;
    # een string die bij eerste gebruik ontleed wordt kost niets.
    packed = ";".join(f"{emoji}:{','.join(words)}" for emoji, words in entries)

    lines = [
        "// Gegenereerd door Tools/generate-emoji-catalog.py — niet met de hand aanpassen.",
        f"// Bron: Unicode CLDR ({'/'.join(LANGUAGES)}) en emoji-test.txt {EMOJI_VERSION}.",
        f"// {len(entries)} emoji.",
        "",
        "enum EmojiCatalogData {",
        "    /// `emoji:trefwoord,trefwoord;emoji:...`, ontleed bij eerste gebruik.",
        f'    static let packed = "{packed}"',
        "}",
        "",
    ]

    output = Path(__file__).resolve().parent.parent / "DinnerCore" / "EmojiCatalogData.swift"
    output.write_text("\n".join(lines), encoding="utf-8")
    print(f"Geschreven: {output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
