#!/usr/bin/env bash
# ----------------------------------------------------------------------
# ntfy.sh – Tiny helper to publish messages to an ntfy (or HTTP) endpoint
#
#   Version v1
#
#   Generic, repo-agnostic wrapper around curl:
#     - URL can be given directly (-u / --url)
#     - or built from a topic name (-t / --topic, or $NTFY_TOPIC)
#
#   Defaults:
#     BASE:   https://ntfy.sh
#     TOPIC:  ${NTFY_TOPIC:-general}
#
#   Examples:
#     echo "Hello world" | ntfy
#     echo "Warning!"     | ntfy -t sysalerts
#     echo "JSON"         | ntfy -u https://ntfy.gd-short.net/life
#
#   Credits: GameDirection @ Alex Sierputowski
# ----------------------------------------------------------------------

set -euo pipefail

# ---------- Default configuration ----------
BASE_URL="${NTFY_BASE_URL:-https://ntfy.sh}"
DEFAULT_TOPIC="${NTFY_TOPIC:-general}"
DEFAULT_URL="${BASE_URL%/}/${DEFAULT_TOPIC}"
DEFAULT_METHOD="POST"
CURL_OPTS=(-sS)

# ---------- Helper functions ----------
usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [options] < /dev/stdin

Options:
  -u, --url URL      HTTP(S) endpoint to POST data to.
                     If omitted, defaults to: ${DEFAULT_URL}

  -t, --topic NAME   Topic name; used only when --url is not given.
                     Default topic: ${DEFAULT_TOPIC}
                     Effective URL: BASE_URL/TOPIC

  -m, --method M     HTTP method: GET or POST (default: ${DEFAULT_METHOD})
  -h, --help         Show this help and exit.

Environment:
  NTFY_BASE_URL   Base URL (default: https://ntfy.sh)
  NTFY_TOPIC      Default topic (default: general)

Examples:
  echo "All clear" | ntfy
  echo "Watch out!" | ntfy -t myTeamAlert
  printf '{"text":"boom"}' | ntfy -u https://example.com/api --method POST

Exit status:
  0   Success (2xx/3xx)
  1   Invalid usage (no stdin, bad options)
  >1  curl error or unexpected HTTP status
EOF
}

error_exit() {
    printf 'ntfy: %s\n' "$1" >&2
    exit "${2:-1}"
}

# ---------- Argument parsing ----------
URL_ARG=""
TOPIC_ARG=""
METHOD_OPT="${DEFAULT_METHOD}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)
            [[ $# -lt 2 ]] && error_exit "Missing argument for $1" 1
            URL_ARG="$2"
            shift 2
            ;;
        -t|--topic)
            [[ $# -lt 2 ]] && error_exit "Missing argument for $1" 1
            TOPIC_ARG="$2"
            shift 2
            ;;
        -m|--method)
            [[ $# -lt 2 ]] && error_exit "Missing argument for $1" 1
            METHOD_OPT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1" 1
            ;;
    esac
done

# Decide target URL
if [[ -n "$URL_ARG" ]]; then
    TARGET_URL="$URL_ARG"
else
    TOPIC="${TOPIC_ARG:-$DEFAULT_TOPIC}"
    TARGET_URL="${BASE_URL%/}/${TOPIC}"
fi

# Validate method
case "$METHOD_OPT" in
    GET|POST) ;;
    *) error_exit "Method must be GET or POST (got \"$METHOD_OPT\")" 1 ;;
esac

# ---------- Read from stdin ----------
if [ -t 0 ]; then
    # No data piped in
    usage
    error_exit "No data on stdin. Pipe a message into this command." 1
fi

TMP_PAYLOAD="$(mktemp)"
cat > "$TMP_PAYLOAD"

# ---------- Invoke curl ----------
HTTP_CODE=""
if [[ "$METHOD_OPT" == "POST" ]]; then
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

if [[ "$HTTP_CODE" =~ ^2|3[0-9]{2}$ ]] || [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 400 ]]; then
    printf 'ntfy: message sent successfully (HTTP %s)\n' "$HTTP_CODE" >&2
    exit 0
else
    error_exit "Unexpected HTTP status ${HTTP_CODE} from ${TARGET_URL}" 2
fi
