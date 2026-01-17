#!/usr/bin/env bash
# ----------------------------------------------------------------------
# install-ntfy.sh – bootstrap helper for the generic ntfy wrapper.
#
#   Version 1.0 – now works correctly in Bash, Zsh, Fish (and any other
#                 shell by emitting raw commands).
#
#   What it does:
#     • Detects the current interactive shell.
#     • Prints the proper command that makes ~/.local/bin appear on $PATH.
#     • Creates the symlink ~/.local/bin/ntfy → ../share/ntify/scripts/ntfy.sh
#       (and checks if the link already exists).
#     • Clones/copies the contrib directory into ~/.local/share/ntify .
#
#   It is deliberately *idempotent* – you can run it many times without
#   harming anything.
# ----------------------------------------------------------------------
set -euo pipefail

# ---------- Configuration ----------
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$(pwd)")"
CONTRIB_DIR="${REPO_ROOT}/client/cli"
SHARE_DIR="${HOME}/.local/share/ntify"
BIN_LINK="${HOME}/.local/bin/ntfy"

# ---------- Helper functions ----------
die() {
    printf 'install-ntfy: %s\n' "$*" >&2
    exit 1
}

ensure_git_or_copy() {
    if command -v git &>/dev/null; then
        echo "Cloning into ${SHARE_DIR} ..."
        mkdir -p "${SHARE_DIR}"
        (cd "${SHARE_DIR}" && git clone --depth 1 "$1" .)
    else
        echo "Git not found – copying source instead."
        cp -a "${CONTRIB_DIR}" "${SHARE_DIR}"
    fi
}

install_executable() {
    mkdir -p "$(dirname "${BIN_LINK}")"
    if [[ -L "${BIN_LINK}" && $(
            readlink -f "${BIN_LINK}") == "${SHARE_DIR}/scripts/ntfy.sh" ]]; then
        echo "Already installed: ${BIN_LINK}"
        return 0
    fi
    ln -sf "${SHARE_DIR}/scripts/ntfy.sh" "${BIN_LINK}"
    chmod +x "${BIN_LINK}"
}

# ---------- Print the right “add to PATH” line ----------
print_path_addition() {
    # Use $SHELL but, if it points to a non‑interactive binary,
    # fall back to an empty string so we can detect fish via $FISH.
    local shell_type="other"

    case "${SHELL:-}" in
        */bash|*/zsh|*/sh)   shell_type="bash_zsh" ;;
        *) if [[ -n "${FISH_VERSION-}" ]]; then
                shell_type="fish"
             fi
            ;;

    esac

    case "$shell_type" in
        bash_zsh)
            cat <<'EOS'
# Added by install-ntfy.sh – make sure ~/.local/bin is on your PATH.
export PATH="${HOME}/.local/bin:${PATH}"
EOS
            ;;
        fish)
            cat <<'EOS'
# Added by install-ntfy.sh – make sure ~/.local/bin is on your PATH.
set -gx PATH $HOME/.local/bin $PATH
EOS
            ;;
        *)
            echo "# Added by install-ntfy.sh – you will need to add ~/.local/bin manually."
            ;;
    esac
}

# ---------- Main ----------
if [[ "$#" -ne 0 ]]; then
    die "Unexpected arguments – just run this script without parameters."
fi

ensure_git_or_copy "${REPO_ROOT}"          # clone or copy as needed
install_executable                         # create the symlink
print_path_addition                        # now emit the correct command

cat <<'EOS'

--------------------------------------------------------------
Installation complete!

1️⃣  ~/.local/bin/ntfy is linked and executable.
2️⃣  The block above has been printed for *your* current shell.

   • If you run Bash or Zsh, paste the `export PATH=…` line
     into your ~/.bashrc or ~/.zshrc and reload it.

   • If you are using Fish, paste the `set -gx …$` line into
     ~/.config/fish/config.fish (or just type it once in a running
     session).

3️⃣  Verify that everything works:

   $ ntfy --version                # should display the version string
   $ echo $PATH | grep .local/bin   # must contain your local bin directory

--------------------------------------------------------------
EOS
