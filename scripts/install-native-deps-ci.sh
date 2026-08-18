#!/usr/bin/env bash
set -euo pipefail

NATIVE_DEPS_CI_MAX_ATTEMPTS=3
NATIVE_DEPS_CI_UPDATE_TIMEOUT=60
NATIVE_DEPS_CI_INSTALL_TIMEOUT=150

packages=("$@")
if [ "${#packages[@]}" -eq 0 ]; then
    echo "No native packages requested." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Bound every network wait inside apt itself. A degraded Ubuntu mirror
# otherwise blocks on a socket until the job is killed, which wedges the
# runner slot and starves every job queued behind it.
apt_options=(
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=20
    -o Acquire::https::Timeout=20
)

for ((attempt = 1; attempt <= NATIVE_DEPS_CI_MAX_ATTEMPTS; attempt++)); do
    echo "Installing native dependencies (attempt ${attempt}/${NATIVE_DEPS_CI_MAX_ATTEMPTS}): ${packages[*]}"

    if timeout "$NATIVE_DEPS_CI_UPDATE_TIMEOUT" sudo -E apt-get "${apt_options[@]}" update &&
       timeout "$NATIVE_DEPS_CI_INSTALL_TIMEOUT" sudo -E apt-get "${apt_options[@]}" \
           install -y --no-install-recommends "${packages[@]}"; then
        missing=()
        for package in "${packages[@]}"; do
            if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'ok installed'; then
                missing+=("$package")
            fi
        done

        if [ "${#missing[@]}" -eq 0 ]; then
            printf 'Installed native dependencies: %s\n' "${packages[*]}"
            exit 0
        fi

        echo "apt-get reported success but these packages are missing: ${missing[*]}" >&2
    fi

    if [ "$attempt" -eq "$NATIVE_DEPS_CI_MAX_ATTEMPTS" ]; then
        echo "Failed to install native dependencies after ${NATIVE_DEPS_CI_MAX_ATTEMPTS} attempts." >&2
        exit 1
    fi

    sleep "$((attempt * 5))"
done
