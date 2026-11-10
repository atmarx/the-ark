#!/usr/bin/env bash
# Build the Ark postcard PDF using a project-local typst binary.
# Self-bootstraps: downloads typst into design/.tools/ if missing.
#
# Usage:  design/postcard/build.sh [--reinstall]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESIGN_DIR="$(dirname "$HERE")"
TOOLS_DIR="$DESIGN_DIR/.tools"
TYPST_BIN="$TOOLS_DIR/typst"
FONTS_DIR="$TOOLS_DIR/fonts"
TYPST_VERSION="v0.14.2"
TYPST_TRIPLE="x86_64-unknown-linux-musl"
TYPST_URL="https://github.com/typst/typst/releases/download/${TYPST_VERSION}/typst-${TYPST_TRIPLE}.tar.xz"

# EB Garamond (OFL) — text face for Cartographer's Mercy.
# Static TTFs from upstream (typst does not yet support variable fonts).
# Fetched once, cached in the sandbox alongside the typst binary.
EBG_BASE="https://github.com/octaviopardo/EBGaramond12/raw/master/fonts/ttf"
EBG_FILES=(
  "EBGaramond-Regular.ttf"
  "EBGaramond-Italic.ttf"
  "EBGaramond-Bold.ttf"
  "EBGaramond-BoldItalic.ttf"
  "EBGaramond-SemiBold.ttf"
  "EBGaramond-Medium.ttf"
)

# Inter + JetBrains Mono (OFL) — grotesque + mono for Concrete Poetry.
# Variable TTFs from the google/fonts mirror.  Typst handles variable fonts
# via its built-in CSS-style weight resolver.
GF_BASE="https://github.com/google/fonts/raw/main/ofl"
# Pairs: "url::filename"
GF_FILES=(
  "${GF_BASE}/inter/Inter%5Bopsz%2Cwght%5D.ttf::Inter.ttf"
  "${GF_BASE}/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf::JetBrainsMono.ttf"
)

if [[ "${1:-}" == "--reinstall" ]]; then
  rm -rf "$TYPST_BIN" "$FONTS_DIR"
fi

if [[ ! -x "$TYPST_BIN" ]]; then
  echo "Installing typst ${TYPST_VERSION} to ${TOOLS_DIR}/"
  mkdir -p "$TOOLS_DIR"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -sSL "$TYPST_URL" -o "$tmp/typst.tar.xz"
  tar -xJf "$tmp/typst.tar.xz" -C "$tmp"
  install -m 0755 "$tmp/typst-${TYPST_TRIPLE}/typst" "$TYPST_BIN"
  "$TYPST_BIN" --version
fi

mkdir -p "$FONTS_DIR"

# EB Garamond — text face for Cartographer's Mercy
for f in "${EBG_FILES[@]}"; do
  if [[ ! -s "${FONTS_DIR}/${f}" ]]; then
    echo "Fetching ${f}"
    curl -sSL "${EBG_BASE}/${f}" -o "${FONTS_DIR}/${f}"
  fi
done

# Inter + JetBrains Mono — grotesque + mono for Concrete Poetry
for pair in "${GF_FILES[@]}"; do
  url="${pair%%::*}"
  name="${pair##*::}"
  if [[ ! -s "${FONTS_DIR}/${name}" ]]; then
    echo "Fetching ${name}"
    curl -sSL "$url" -o "${FONTS_DIR}/${name}"
  fi
done

cd "$HERE"
"$TYPST_BIN" compile --font-path "$FONTS_DIR" postcard.typ postcard.pdf
echo "Wrote: $HERE/postcard.pdf"
"$TYPST_BIN" compile --font-path "$FONTS_DIR" mini.typ mini.pdf
echo "Wrote: $HERE/mini.pdf"
"$TYPST_BIN" compile --font-path "$FONTS_DIR" mega.typ mega.pdf
echo "Wrote: $HERE/mega.pdf"
"$TYPST_BIN" compile --font-path "$FONTS_DIR" concrete.typ concrete.pdf
echo "Wrote: $HERE/concrete.pdf"
"$TYPST_BIN" compile --font-path "$FONTS_DIR" floppy-sleeves.typ floppy-sleeves.pdf
echo "Wrote: $HERE/floppy-sleeves.pdf"
