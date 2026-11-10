#!/bin/sh
# start-ai.sh — run a language model from this drive with llama.cpp
# Usage: sh start-ai.sh [model-id | --list]
# Env:   ARK_AI_PORT (default 8081), ARK_AI_CPU=1 (skip the GPU build),
#        ARK_AI_CTX (context length, default 16384)

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
PORT=${ARK_AI_PORT:-8081}
CTX=${ARK_AI_CTX:-16384}
RELEASE=$(head -n 1 "$HERE/llama.cpp/RELEASE")
TAB=$(printf '\t')

list_models() {
    printf '%-18s %6s  %s\n' "ID" "MEMORY" "MODEL"
    while IFS="$TAB" read -r id ram auto model mmproj name; do
        extra=""
        [ "$mmproj" != "-" ] && extra=", reads images"
        [ "$auto" = "no" ] && extra="$extra, pick by name"
        printf '%-18s %3s GB  %s%s\n' "$id" "$ram" "$name" "$extra"
    done < "$HERE/models.tsv"
}

if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
    list_models
    exit 0
fi

# ── What are we running on? ────────────────────────────────────
case "$(uname -s)" in
    Linux)
        os=linux
        ram=$(awk '/^MemTotal:/ { printf "%d", $2 * 1024 / 1000000000 + 0.5 }' /proc/meminfo)
        ;;
    Darwin)
        os=macos
        ram=$(( $(sysctl -n hw.memsize) / 1000000000 ))
        ;;
    *)
        echo "Sorry, I don't have a build for $(uname -s).  On Windows, use start-ai.bat."
        exit 1
        ;;
esac

case "$(uname -m)" in
    x86_64|amd64)   arch=x64 ;;
    aarch64|arm64)  arch=arm64 ;;
    *)
        echo "Sorry, I don't have a build for $(uname -m) processors."
        exit 1
        ;;
esac

platform="$os-$arch"
if [ "$platform" = "linux-x64" ] && [ -z "${ARK_AI_CPU:-}" ]; then
    # The Vulkan build uses most graphics cards, but needs the Vulkan loader
    if ldconfig -p 2>/dev/null | grep -q 'libvulkan\.so\.1' \
        || ls /usr/lib*/libvulkan.so.1 /usr/lib/*/libvulkan.so.1 >/dev/null 2>&1; then
        platform="linux-x64-vulkan"
    fi
fi

archive=$(awk -F "$TAB" -v p="$platform" '$1 == p { print $2 }' "$HERE/llama.cpp/platforms.tsv")
if [ -z "$archive" ] || [ ! -f "$HERE/llama.cpp/$archive" ]; then
    echo "Sorry, I don't have llama.cpp for $platform."
    exit 1
fi

# ── Pick a model ───────────────────────────────────────────────
pick=""
if [ -n "${1:-}" ]; then
    pick=$(awk -F "$TAB" -v id="$1" '$1 == id' "$HERE/models.tsv")
    if [ -z "$pick" ]; then
        echo "I don't have a model called '$1'.  Here's what I have:"
        echo
        list_models
        exit 1
    fi
else
    # Largest automatic model that fits in memory; the smallest if none do
    pick=$(awk -F "$TAB" -v ram="$ram" '$3 == "yes" && $2 <= ram { p = $0 } END { print p }' "$HERE/models.tsv")
    if [ -z "$pick" ]; then
        pick=$(head -n 1 "$HERE/models.tsv")
        echo "This computer has about $ram GB of memory, which is tight.  I'll try the smallest model."
    fi
fi

IFS="$TAB" read -r id need auto model mmproj name <<EOF
$pick
EOF

if [ "$need" -gt "$ram" ]; then
    echo "Warning: $name wants about $need GB of memory and this computer has about $ram GB."
    echo "It may be very slow, or fail to start."
    echo
fi

# ── Unpack llama.cpp to this computer (once) ───────────────────
cache="${XDG_CACHE_HOME:-$HOME/.cache}/the-ark/llama.cpp-$RELEASE-$platform"
server=$(find "$cache" -name llama-server -type f 2>/dev/null | head -n 1)
if [ -z "$server" ]; then
    echo "Unpacking llama.cpp to $cache ..."
    mkdir -p "$cache"
    tar -xzf "$HERE/llama.cpp/$archive" -C "$cache"
    server=$(find "$cache" -name llama-server -type f | head -n 1)
    if [ -z "$server" ]; then
        echo "Couldn't find llama-server in $archive."
        exit 1
    fi
    chmod +x "$server"
    # macOS: files unpacked from a drive can carry a quarantine flag
    [ "$os" = "macos" ] && xattr -dr com.apple.quarantine "$cache" 2>/dev/null || true
fi

# ── Start it ───────────────────────────────────────────────────
echo "Starting $name ($id) on $platform, with about $ram GB of memory."
echo
echo "When it says \"listening on\", open this in a web browser:"
echo
echo "    http://127.0.0.1:$PORT"
echo
echo "Press Ctrl+C to stop."
echo

set -- -m "$HERE/$model" --host 127.0.0.1 --port "$PORT" -c "$CTX"
[ "$mmproj" != "-" ] && set -- "$@" --mmproj "$HERE/$mmproj"

exec "$server" "$@"
