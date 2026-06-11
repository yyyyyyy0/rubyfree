#!/usr/bin/env bash
set -euo pipefail

# fetch-dict-sources.sh — download the dictionary SOURCE files (build-time only).
#
# This is the ONLY networking step in the whole project, and it runs at *build* time on
# a developer machine, never in the shipped app. The runtime stays fully offline: only
# the generated words.tsv / kanji.tsv are bundled.
#
# Sources (EDRDG, CC-BY-SA 4.0 — see NOTICE):
#   JMdict_e   : http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz
#   kanjidic2  : http://www.edrdg.org/kanjidic/kanjidic2.xml.gz
#
# Output: .dict-cache/JMdict_e.xml and .dict-cache/kanjidic2.xml (gitignored).

cd "$(dirname "$0")/.."
CACHE=".dict-cache"
mkdir -p "$CACHE"

fetch() {
  local url="$1" out="$2"
  if [[ -f "$out" ]]; then
    echo "==> already present: $out (delete to refresh)"
    return
  fi
  echo "==> downloading $url"
  curl -fSL "$url" -o "$out.gz"
  gunzip -f "$out.gz"
  echo "==> wrote $out"
}

fetch "http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz" "$CACHE/JMdict_e.xml"
fetch "http://www.edrdg.org/kanjidic/kanjidic2.xml.gz" "$CACHE/kanjidic2.xml"

echo "==> done. Next: swift Scripts/build-dict.swift $CACHE/JMdict_e.xml $CACHE/kanjidic2.xml Sources/RubyfreeCore/Resources"
