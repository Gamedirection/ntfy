#!/usr/bin/env bash
# install-cli.sh – install the ntfy CLI into your home directory.
set -euo pipefail

# Where this script lives (client/cli/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="${SCRIPT_DIR}"                       # current directory
SHARE_DIR="${HOME}/.local/share/ntfy"        # where we install the CLI
BIN_LINK="${HOME}/.local/bin/ntfy"           # symlink users will run

die() {
  printf 'install-ntfy: %s\n' "$*" >&2
  exit 1
}

install_files() {
  echo "Installing files into ${SHARE_DIR}"
  rm -rf "${SHARE_DIR}"
  mkdir -p "$(dirname "${SHARE_DIR}")"
  cp -a "${CLI_DIR}" "${SHARE_DIR}"
}

install_symlink() {
  mkdir -p "$(dirname "${BIN_LINK}")"
  rm -f "${BIN_LINK}"
  ln -s "${SHARE_DIR}/ntfy.sh" "${BIN_LINK}"
  chmod +x "${SHARE_DIR}/ntfy.sh"
}

print_path_instructions() {
  # Detect shell for correct PATH syntax
  local shell_type="other"
  case "${SHELL:-}" in
    */bash|*/zsh) shell_type="bash_zsh" ;;
    */fish)       shell_type="fish" ;;
  esac

  echo
  echo "To make sure 'ntfy' is on your PATH permanently, add this line to your shell config:"
  echo

  case "$shell_type" in
    bash_zsh)
      echo '  export PATH="$HOME/.local/bin:$PATH"'
      echo
      echo "For example, put it into ~/.bashrc or ~/.zshrc."
      ;;
    fish)
      echo '  set -gx PATH $HOME/.local/bin $PATH'
      echo
      echo "Put that into ~/.config/fish/config.fish."
      ;;
    *)
      echo '  export PATH="$HOME/.local/bin:$PATH"'
      echo
      echo "Add it to your shell's startup file."
      ;;
  esac
}

main() {
  if [[ $# -ne 0 ]]; then
    die "Unexpected arguments – just run ./install-cli.sh with no options."
  fi

  install_files
  install_symlink

  echo
  echo "✅ ntfy CLI installed."
  echo "Binary: ${BIN_LINK}"
  print_path_instructions
}

main "$@"
