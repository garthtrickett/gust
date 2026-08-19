#!/usr/bin/env bash
set -euo pipefail

# The GitHub Ubuntu runner image already ships every package this repository
# asks for except ripgrep. Running `apt-get update` to discover that is pure
# cost: it is ~15 s on a good day, over two minutes on a bad one, and it is the
# single cause of every infrastructure failure in the CI incident log.
#
# So: satisfy each request from what is already present, install ripgrep from a
# pinned static binary, and fall through to apt only for what genuinely remains.
# On a healthy runner image this makes no apt call at all. On a changed or
# degraded image it behaves exactly as it always did.
#
# Capabilities are probed, not assumed. `build-essential` is a metapackage that
# may be absent while every tool it pulls in is present, so asking dpkg whether
# it is installed answers the wrong question. Compiling a C file answers the
# right one.

NATIVE_DEPS_CI_MAX_ATTEMPTS=3
NATIVE_DEPS_CI_UPDATE_TIMEOUT=60
NATIVE_DEPS_CI_INSTALL_TIMEOUT=150

packages=("$@")
if [ "${#packages[@]}" -eq 0 ]; then
    echo "No native packages requested." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Does a working C toolchain exist? Compiling proves headers, compiler driver,
# assembler, and linker together, which is what `build-essential` is wanted for.
c_toolchain_works() {
    local probe status
    probe="$(mktemp -d)"
    printf 'int main(void) { return 0; }\n' >"$probe/probe.c"
    if cc "$probe/probe.c" -o "$probe/probe" >/dev/null 2>&1; then
        status=0
    else
        status=1
    fi
    rm -rf "$probe"
    return "$status"
}

package_satisfied() {
    case "$1" in
        build-essential) c_toolchain_works ;;
        gcc)             command -v gcc >/dev/null 2>&1 ;;
        g++)             command -v g++ >/dev/null 2>&1 ;;
        clang)           command -v clang >/dev/null 2>&1 ;;
        make)            command -v make >/dev/null 2>&1 ;;
        curl)            command -v curl >/dev/null 2>&1 ;;
        binutils)        command -v ar >/dev/null 2>&1 && command -v objdump >/dev/null 2>&1 ;;
        ripgrep)         command -v rg >/dev/null 2>&1 ;;
        *)               dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'ok installed' ;;
    esac
}

# Pass 1 — what is already usable?
missing=()
for package in "${packages[@]}"; do
    if package_satisfied "$package"; then
        echo "Already present: $package"
    else
        missing+=("$package")
    fi
done

# Pass 2 — ripgrep comes from its pinned release, never from apt.
if [ "${#missing[@]}" -gt 0 ]; then
    remaining=()
    for package in "${missing[@]}"; do
        if [ "$package" = "ripgrep" ]; then
            destination="${HOME}/.local/bin"
            bash "$(dirname "${BASH_SOURCE[0]}")/install-ripgrep-ci.sh" "$destination"
            export PATH="$destination:$PATH"
            if [ -n "${GITHUB_PATH:-}" ]; then
                echo "$destination" >>"$GITHUB_PATH"
            fi
        else
            remaining+=("$package")
        fi
    done
    missing=("${remaining[@]+"${remaining[@]}"}")
fi

if [ "${#missing[@]}" -eq 0 ]; then
    printf 'Native dependencies satisfied without apt: %s\n' "${packages[*]}"
    exit 0
fi

# Pass 3 — apt, for whatever genuinely remains. Unchanged from before, including
# the bounded network waits: a degraded Ubuntu mirror otherwise blocks on a
# socket until the job is killed, which wedges the runner slot and starves every
# job queued behind it.
apt_options=(
    -o Acquire::Retries=3
    -o Acquire::http::Timeout=20
    -o Acquire::https::Timeout=20
)

for ((attempt = 1; attempt <= NATIVE_DEPS_CI_MAX_ATTEMPTS; attempt++)); do
    echo "Installing native dependencies (attempt ${attempt}/${NATIVE_DEPS_CI_MAX_ATTEMPTS}): ${missing[*]}"

    if timeout "$NATIVE_DEPS_CI_UPDATE_TIMEOUT" sudo -E apt-get "${apt_options[@]}" update &&
       timeout "$NATIVE_DEPS_CI_INSTALL_TIMEOUT" sudo -E apt-get "${apt_options[@]}" \
           install -y --no-install-recommends "${missing[@]}"; then
        still_missing=()
        for package in "${missing[@]}"; do
            if ! package_satisfied "$package"; then
                still_missing+=("$package")
            fi
        done

        if [ "${#still_missing[@]}" -eq 0 ]; then
            printf 'Installed native dependencies: %s\n' "${missing[*]}"
            exit 0
        fi

        echo "apt-get reported success but these packages are missing: ${still_missing[*]}" >&2
    fi

    if [ "$attempt" -eq "$NATIVE_DEPS_CI_MAX_ATTEMPTS" ]; then
        echo "Failed to install native dependencies after ${NATIVE_DEPS_CI_MAX_ATTEMPTS} attempts." >&2
        exit 1
    fi

    sleep "$((attempt * 5))"
done
