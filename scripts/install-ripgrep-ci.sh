#!/usr/bin/env bash
set -euo pipefail

# ripgrep is the only package the Ubuntu runner image does not already ship, and
# fetching it through apt requires an `apt-get update` — the slow, mirror-
# dependent step responsible for every infrastructure failure in the CI incident
# log. Install it the same way `install-just-ci.sh` installs just: a pinned
# static musl binary from the project's own GitHub release.

RIPGREP_CI_VERSION="14.1.1"
RIPGREP_CI_TARGET="x86_64-unknown-linux-musl"
RIPGREP_CI_MAX_ATTEMPTS=5

destination="${1:-$HOME/.local/bin}"
temporary_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
archive="$(mktemp "${temporary_root%/}/ripgrep-${RIPGREP_CI_VERSION}.XXXXXX.tar.gz")"
stem="ripgrep-${RIPGREP_CI_VERSION}-${RIPGREP_CI_TARGET}"
url="https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_CI_VERSION}/${stem}.tar.gz"

cleanup() {
    rm -f "$archive"
}
trap cleanup EXIT

mkdir -p "$destination"

for ((attempt = 1; attempt <= RIPGREP_CI_MAX_ATTEMPTS; attempt++)); do
    rm -f "$archive"
    echo "Downloading ripgrep ${RIPGREP_CI_VERSION} (attempt ${attempt}/${RIPGREP_CI_MAX_ATTEMPTS})..."

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
       tar -tzf "$archive" "${stem}/rg" >/dev/null 2>&1; then
        tar -xzf "$archive" -C "$destination" --strip-components=1 "${stem}/rg"
        chmod +x "$destination/rg"

        # `rg --version` prints "ripgrep <version> (rev <sha>)", so match the
        # leading version field rather than the whole line.
        installed_version="$("$destination/rg" --version | head -n 1)"
        if [ "${installed_version%% (*}" != "ripgrep ${RIPGREP_CI_VERSION}" ]; then
            echo "Expected ripgrep ${RIPGREP_CI_VERSION}, got ${installed_version}." >&2
            exit 1
        fi

        printf '%s\n' "$installed_version"
        exit 0
    fi

    if [ "$attempt" -eq "$RIPGREP_CI_MAX_ATTEMPTS" ]; then
        echo "Failed to download a valid ripgrep ${RIPGREP_CI_VERSION} archive after ${RIPGREP_CI_MAX_ATTEMPTS} attempts." >&2
        exit 1
    fi

    sleep "$((attempt * 2))"
done
