#!/usr/bin/env bash
set -euo pipefail

JUST_CI_VERSION="1.55.1"
JUST_CI_TARGET="x86_64-unknown-linux-musl"
JUST_CI_MAX_ATTEMPTS=5

destination="${1:-$HOME/.local/bin}"
temporary_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
archive="$(mktemp "${temporary_root%/}/just-${JUST_CI_VERSION}.XXXXXX.tar.gz")"
url="https://github.com/casey/just/releases/download/${JUST_CI_VERSION}/just-${JUST_CI_VERSION}-${JUST_CI_TARGET}.tar.gz"

cleanup() {
    rm -f "$archive"
}
trap cleanup EXIT

mkdir -p "$destination"

for ((attempt = 1; attempt <= JUST_CI_MAX_ATTEMPTS; attempt++)); do
    rm -f "$archive"
    echo "Downloading just ${JUST_CI_VERSION} (attempt ${attempt}/${JUST_CI_MAX_ATTEMPTS})..."

    if curl \
        --proto '=https' \
        --tlsv1.2 \
        --fail \
        --silent \
        --show-error \
        --location \
        --connect-timeout 20 \
        --max-time 180 \
        --output "$archive" \
        "$url" &&
       tar -tzf "$archive" just >/dev/null 2>&1; then
        tar -xzf "$archive" -C "$destination" just
        chmod +x "$destination/just"

        installed_version="$("$destination/just" --version)"
        if [ "$installed_version" != "just ${JUST_CI_VERSION}" ]; then
            echo "Expected just ${JUST_CI_VERSION}, got ${installed_version}." >&2
            exit 1
        fi

        printf '%s\n' "$installed_version"
        exit 0
    fi

    if [ "$attempt" -eq "$JUST_CI_MAX_ATTEMPTS" ]; then
        echo "Failed to download a valid just ${JUST_CI_VERSION} archive after ${JUST_CI_MAX_ATTEMPTS} attempts." >&2
        exit 1
    fi

    sleep "$((attempt * 2))"
done
