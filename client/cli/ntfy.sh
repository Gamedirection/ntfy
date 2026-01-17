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
#   Message body:
#     - from stdin (echo "msg" | ntfy)
#     - or from remaining command-line args (ntfy "Hello World")
#
#   Message headers / ntfy options (all become curl -H headers):
#     --title TEXT           X-Title
#     --sid ID               X-Sequence-ID
#     --priority N           X-Priority
#     --tags TAGS            X-Tags
#     --delay VALUE          X-Delay (at/in)
#     --actions STR          X-Actions
#     --click URL            X-Click
#     --attach URL           X-Attach
#     --markdown             X-Markdown: true
#     --icon URL             X-Icon
#     --filename NAME        X-Filename
#     --email ADDRESS        X-Email
#     --call NUMBER          X-Call
#     --cache VALUE          X-Cache
#     --firebase VALUE       X-Firebase
#     --up VALUE             X-UnifiedPush
#     --poll-id ID           X-Poll-ID
#     --auth TOKEN           Authorization: Bearer TOKEN
#     --content-type TYPE    Content-Type
#
#   Credits: GameDirection @ Alex Sierputowski
# ----------------------------------------------------------------------
set -euo pipefail

VERSION="1.4"
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

# curl options and headers
CURL_OPTS=(-sS)
HEADERS=()    # array of -H "Header: value"

usage() {
    cat <<EOF >&2
Usage:
  ntfy [flags] [message...]
  echo "msg" | ntfy [flags]

Runtime options:
  -u, --url [URL]      HTTP(S) endpoint to send data to.
                       If omitted, defaults to: \$(current-url)
                       If used without URL, prints current effective URL.
  -t, --topic [NAME]   Topic name; used when --url is not given.
                       If used without NAME, prints current topic.
  -m, --method [M]     HTTP method: GET or POST (default: \$(current-method))
                       If used without M, prints current method.

Persistent defaults (saved in ${CONFIG_FILE}):
  -su, --set-url URL      Set default base URL.
  -st, --set-topic NAME   Set default topic.
  -sm, --set-method M     Set default method (GET or POST).

Message headers / ntfy options:
  --title TEXT           Set X-Title
  --sid ID               Set X-Sequence-ID
  --priority N           Set X-Priority
  --tags TAGS            Set X-Tags (e.g. "warning,skull")
  --delay VALUE          Set X-Delay (or at/in timestamp, e.g. "10m")
  --actions STR          Set X-Actions
  --click URL            Set X-Click
  --attach URL           Set X-Attach
  --markdown             Set X-Markdown: true
  --icon URL             Set X-Icon
  --filename NAME        Set X-Filename
  --email ADDRESS        Set X-Email
  --call NUMBER          Set X-Call
  --cache VALUE          Set X-Cache
  --firebase VALUE       Set X-Firebase
  --up VALUE             Set X-UnifiedPush
  --poll-id ID           Set X-Poll-ID
  --auth TOKEN           Set Authorization: Bearer TOKEN
  --content-type TYPE    Set Content-Type

Other:
  -v, --version        Show version and exit.
  -h, --help           Show this help and exit.

Message:
  If stdin is not a TTY, body is read from stdin.
  Otherwise, any remaining arguments after flags form the message:
      ntfy "Hello World"
      ntfy -u https://ntfy.gd-short.net -t dogs "hello world"

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

        # header / ntfy options (all turned into -H)
        --title)
            [[ $# -lt 2 ]] && error_exit "Missing value for --title" 1
            HEADERS+=(-H "X-Title: $2")
            shift 2
            ;;
        --sid)
            [[ $# -lt 2 ]] && error_exit "Missing value for --sid" 1
            HEADERS+=(-H "X-Sequence-ID: $2")
            shift 2
            ;;
        --priority)
            [[ $# -lt 2 ]] && error_exit "Missing value for --priority" 1
            HEADERS+=(-H "X-Priority: $2")
            shift 2
            ;;
        --tags)
            [[ $# -lt 2 ]] && error_exit "Missing value for --tags" 1
            HEADERS+=(-H "X-Tags: $2")
            shift 2
            ;;
        --delay)
            [[ $# -lt 2 ]] && error_exit "Missing value for --delay" 1
            HEADERS+=(-H "X-Delay: $2")
            shift 2
            ;;
        --actions)
            [[ $# -lt 2 ]] && error_exit "Missing value for --actions" 1
            HEADERS+=(-H "X-Actions: $2")
            shift 2
            ;;
        --click)
            [[ $# -lt 2 ]] && error_exit "Missing value for --click" 1
            HEADERS+=(-H "X-Click: $2")
            shift 2
            ;;
        --attach)
            [[ $# -lt 2 ]] && error_exit "Missing value for --attach" 1
            HEADERS+=(-H "X-Attach: $2")
            shift 2
            ;;
        --markdown)
            HEADERS+=(-H "X-Markdown: true")
            shift 1
            ;;
        --icon)
            [[ $# -lt 2 ]] && error_exit "Missing value for --icon" 1
            HEADERS+=(-H "X-Icon: $2")
            shift 2
            ;;
        --filename)
            [[ $# -lt 2 ]] && error_exit "Missing value for --filename" 1
            HEADERS+=(-H "X-Filename: $2")
            shift 2
            ;;
        --email)
            [[ $# -lt 2 ]] && error_exit "Missing value for --email" 1
            HEADERS+=(-H "X-Email: $2")
            shift 2
            ;;
        --call)
            [[ $# -lt 2 ]] && error_exit "Missing value for --call" 1
            HEADERS+=(-H "X-Call: $2")
            shift 2
            ;;
        --cache)
            [[ $# -lt 2 ]] && error_exit "Missing value for --cache" 1
            HEADERS+=(-H "X-Cache: $2")
            shift 2
            ;;
        --firebase)
            [[ $# -lt 2 ]] && error_exit "Missing value for --firebase" 1
            HEADERS+=(-H "X-Firebase: $2")
            shift 2
            ;;
        --up)
            [[ $# -lt 2 ]] && error_exit "Missing value for --up" 1
            HEADERS+=(-H "X-UnifiedPush: $2")
            shift 2
            ;;
        --poll-id)
            [[ $# -lt 2 ]] && error_exit "Missing value for --poll-id" 1
            HEADERS+=(-H "X-Poll-ID: $2")
            shift 2
            ;;
        --auth)
            [[ $# -lt 2 ]] && error_exit "Missing value for --auth" 1
            HEADERS+=(-H "Authorization: Bearer $2")
            shift 2
            ;;
        --content-type)
            [[ $# -lt 2 ]] && error_exit "Missing value for --content-type" 1
            HEADERS+=(-H "Content-Type: $2")
            shift 2
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
        curl "${CURL_OPTS[@]}" "${HEADERS[@]}" \
             -X POST \
             --data-binary @"$TMP_PAYLOAD" \
             -o /dev/null \
             -w '%{http_code}' \
             "$TARGET_URL"
    )"
else
    HTTP_CODE="$(
        curl "${CURL_OPTS[@]}" "${HEADERS[@]}" \
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
