#!/usr/bin/env bash
# ----------------------------------------------------------------------
# install-ntfy-client.sh – bootstrap helper for the generic ntfy client.
#
#   * Detects Bash/Zsh vs Fish automatically and prints the “add to PATH”
#     line that matches your current interactive shell.
#   * Clones (or copies) the source tree into ~/.local/share/ntify,
#     then creates a symlink ~/ .local/bin/ntfy → <repo>/client/cli/scripts/ntify.sh
#   * Idempotent: you can run it many times without breaking anything.
#
#   The only external requirement is `git`; if it isn’t present we fall back to
#   plain directory copy (`cp -a`).
# ----------------------------------------------------------------------
set -euo pipefail

# ---------- Configuration ----------
# The repository root – the directory that contains “client/…”.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"
CONTRIB_DIR="${REPO_ROOT}/client/cli"          # <‑‑ this is what you changed
SHARE_DIR="${HOME}/.local/share/ntify"         # where we clone/copy into
BIN_LINK="${HOME}/.local/bin/ntfy"             # the final link

# ---------- Helper functions ----------
die() {
    printf 'install-ntfy-client: %s\n' "$*" >&2
    exit 1
}

ensure_git_or_copy() {
    if command -v git &>/dev/null; then
        echo "Cloning into ${SHARE_DIR} ..."
        mkdir -p "${SHARE_DIR}"
        # NOTE: we must *not* use --depth when cloning a sub‑directory – it fails.
        # Simple clone of the whole repo, then extract only what we need.
        (cd "$(dirname "$REPO_ROOT")" && git clone --quiet "$1" "$(basename "$SHARE_DIR")")
    else
        echo "Git not found – copying source instead."
        cp -a "${CONTRIB_DIR}" "${SHARE_DIR}"
    fi
}

# The target script *inside* the repo we just installed:
TARGET_SCRIPT="${REPO_ROOT}/scripts/ntify.sh"

install_executable() {
    # Ensure the bin directory exists
    mkdir -p "$(dirname "${BIN_LINK}")"

    # If an existing symlink already points at the right place – nothing to do.
    if [[ -L "${BIN_LINK}" && $(readlink -f "${BIN_LINK}") == "${TARGET_SCRIPT}" ]]; then
        printf 'Symlink already present: %s → %s\n' "${BIN_LINK}" "${TARGET_SCRIPT}"
        return 0
    fi

    # Clean up any dangling link first (this removes the “chmod … cannot operate on…”
    # error you saw). Then create a fresh symlink.
    rm -f "${BIN_LINK}"
    ln -sf "${TARGET_SCRIPT}" "${BIN_LINK}"

    # Make it executable for everybody
    chmod +x "${BIN_LINK}"
}

# ---------- Determine which shell we are using ----------
detect_shell_type() {
    case "$SHELL" in
        */bash|*/zsh)   echo "bash_zsh";;
        *)  if [[ -n "${FISH_VERSION-}" ]]; then
                echo "fish"
            else
                echo "other"
            fi;;
    esac
}

# ---------- Print the correct “add to PATH” line ----------
print_path_addition() {
    local type=$(detect_shell_type)

    case "$type" in
        bash_zsh)
            cat <<'EOS'
# Added by install-ntfy-client.sh – make sure ~/.local/bin is on your PATH.
export PATH="${HOME}/.local/bin:${PATH}"
EOS
            ;;
        fish)
            cat <<'EOS'
# Added by install-ntfy-client.sh – make sure ~/.local/bin is on your PATH.
set -gx PATH $HOME/.local/bin $PATH
EOS
            ;;
        other)
            echo "# No automatic PATH injection for unknown shells. Add it manually."
            ;;
    esac
}

# ---------- Main -------------------------------------------------------
if [[ "$#" -ne 0 ]]; then
    die "Unexpected arguments – just run this script without parameters."
fi

# 1️⃣ Clone / copy the source tree into ~/.local/share/ntify
ensure_git_or_copy "${REPO_ROOT}"
# At this point we expect ${SHARE_DIR}/${CONTRIB_DIR##*/} → i.e. client/cli

# 2️⃣ Create (or replace) the executable symlink in ~/.local/bin
install_executable

# 3️⃣ Print the proper PATH hint for your shell
printf '\n--- Install complete! ---\n'
print_path_addition | tee -a "${HOME}/.profile" >/dev/null   # optional auto‑append
echo "If you are seeing this message, copy the printed line into \`~/.profile\` (or \
\`.bashrc\`, \`.zshrc\`, etc.) if it isn’t already there."

# ----------------------------------------------------------------------
