#!/usr/bin/env bash
# ----------------------------------------------------------------------
# ntfy.sh – Tiny helper to publish messages to an ntfy (or HTTP) endpoint
#
#   Runtime flags:
#     -u / --url URL        one-shot URL (or show current if no URL)
#     -t / --topic TOPIC    one-shot topic (or show current if none)
#     -m / --method M       GET or POST (or show current if none)
#
#   Persistent defaults (stored in ~/.config/ntfy-cli.conf):
#     -su / --set-url URL
#     -st / --set-topic TOPIC
#     -sm / --set-method M
#
#   Message:
#     - from stdin (echo "msg" | ntfy)
#     - or from remaining command-line args (ntfy "Hello World")
#
#   Credits: GameDirection @ Alex Sierputowski
# ----------------------------------------------------------------------

set -euo pipefail

VERSION="1.3"
CONFIG_FILE="${HOME}/.config/ntfy-cli.conf"

# ---------- load config (if any) ----------
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

# Environment overrides config; config overrides hard defaults
BASE_URL="${NTFY_BASE_URL:-${CFG_BASE_URL:-https://ntfy.sh}}"
CUR_TOPIC="${NTFY_TOPIC:-${CFG_TOPIC:-general}}"
CUR_METHOD="${CFG_METHOD:-POST}"

# One-shot overrides from CLI
CUR_URL=""

CURL_OPTS=(-sS)

usage() {
    cat <<EOF >&2
Usage:
  ntfy [flags] [message...]
  echo "msg" | ntfy [flags]

Runtime options:
  -u, --url [URL]      HTTP(S) endpoint to POST data to.
                       If omitted, defaults to: \$(current-url)
                       If used *without* URL, prints current effective URL.

  -t, --topic [NAME]   Topic name; used only when --url is not given.
                       If used *without* NAME, prints current topic.

  -m, --method [M]     HTTP method: GET or POST (default: \$(current-method))
                       If used *without* M, prints current method.

Persistent defaults (saved in ${CONFIG_FILE}):
  -su, --set-url URL      Set default base URL.
  -st, --set-topic NAME   Set default topic.
  -sm, --set-method M     Set default method (GET or POST).

Other:
  -v, --version        Show version and exit.
  -h, --help           Show this help and exit.

Message:
  If stdin is not a TTY, body is read from stdin.
  Otherwise, any remaining arguments after flags form the message:
      ntfy "Hello World"
      ntfy -u https://ntfy.gamedirection.net -t dogs "hello world"

Environment overrides:
  NTFY_BASE_URL   Base URL
  NTFY_TOPIC      Default topic
EOF
}

show_version() {
    printf 'ntfy.sh version %s\n' "$VERSION"
}

error_exit() {
    printf 'ntfy: %s\n' "$1" >&2
    exit "${2:-1}"
}

save_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"
    {
        printf 'CFG_BASE_URL=%q\n' "${BASE_URL}"
        printf 'CFG_TOPIC=%q\n'     "${CUR_TOPIC}"
        printf 'CFG_METHOD=%q\n'    "${CUR_METHOD}"
    } >"$CONFIG_FILE"
    echo "Saved defaults to ${CONFIG_FILE}"
}

print_current_url() {
    if [[ -n "$CUR_URL" ]]; then
        echo "$CUR_URL"
    else
        echo "${BASE_URL%/}/${CUR_TOPIC}"
    fi
}

# ---------- parse flags (stop at first non-flag) ----------
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        # persistent defaults
        -su|--set-url)
            [[ $# -lt 2 || "$2" =~ ^- ]] && error_exit "Missing URL for $1" 1
            BASE_URL="$2"
            save_config
            exit 0
            ;;
        -st|--set-topic)
            [[ $# -lt 2 || "$2" =~ ^- ]] && error_exit "Missing topic for $1" 1
            CUR_TOPIC="$2"
            save_config
            exit 0
            ;;
        -sm|--set-method)
            [[ $# -lt 2 || "$2" =~ ^- ]] && error_exit "Missing method for $1" 1
            CUR_METHOD="$2"
            save_config
            exit 0
            ;;
        # runtime flags (can also show current)
        -u|--url)
            if [[ $# -ge 2 && ! "$2" =~ ^- ]]; then
                CUR_URL="$2"
                shift 2
                continue
            else
                print_current_url
                exit 0
            fi
            ;;
        -t|--topic)
            if [[ $# -ge 2 && ! "$2" =~ ^- ]]; then
                CUR_TOPIC="$2"
                shift 2
                continue
            else
                echo "$CUR_TOPIC"
                exit 0
            fi
            ;;
        -m|--method)
            if [[ $# -ge 2 && ! "$2" =~ ^- ]]; then
                CUR_METHOD="$2"
                shift 2
                continue
            else
                echo "$CUR_METHOD"
                exit 0
            fi
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --) # explicit end of flags
            shift
            break
            ;;
        -*)
            error_exit "Unknown option: $1" 1
            ;;
        *)
            break
            ;;
    esac
done

# Whatever is left are positional args (potential message)
if [[ $# -gt 0 ]]; then
    ARGS=("$@")
fi

# ---------- build final URL and validate method ----------
if [[ -n "$CUR_URL" ]]; then
    # If CUR_URL has no path component and we have a topic, append it
    if [[ "$CUR_URL" =~ ^https?://[^/]+$ && -n "$CUR_TOPIC" ]]; then
        TARGET_URL="${CUR_URL%/}/${CUR_TOPIC}"
    else
        TARGET_URL="$CUR_URL"
    fi
else
    TARGET_URL="${BASE_URL%/}/${CUR_TOPIC}"
fi

case "$CUR_METHOD" in
    GET|POST) ;;
    *) error_exit "Method must be GET or POST (got \"$CUR_METHOD\")" 1 ;;
esac

# ---------- decide where to get message from ----------
MSG=""
if [ ! -t 0 ]; then
    # Non-tty stdin – prefer stdin
    MSG="$(cat)"
elif [[ ${#ARGS[@]} -gt 0 ]]; then
    # No stdin, but we have positional arguments → join them as message
    MSG="${ARGS[*]}"
else
    usage
    error_exit "No message supplied (stdin empty and no arguments)." 1
fi

# ---------- send via curl ----------
TMP_PAYLOAD="$(mktemp)"
printf '%s' "$MSG" >"$TMP_PAYLOAD"

if [[ "$CUR_METHOD" == "POST" ]]; then
    HTTP_CODE="$(
        curl "${CURL_OPTS[@]}" \
             -X POST \
             --data-binary @"$TMP_PAYLOAD" \
             -o /dev/null \
             -w '%{http_code}' \
             "$TARGET_URL"
    )"
else
    HTTP_CODE="$(
        curl "${CURL_OPTS[@]}" \
             -X GET \
             -o /dev/null \
             -w '%{http_code}' \
             "$TARGET_URL"
    )"
fi

rm -f "$TMP_PAYLOAD"

if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ || "$HTTP_CODE" =~ ^3[0-9][0-9]$ ]]; then
    printf 'ntfy: message sent successfully (HTTP %s)\n' "$HTTP_CODE" >&2
    exit 0
else
    error_exit "Unexpected HTTP status ${HTTP_CODE} from ${TARGET_URL}" 2
fi
