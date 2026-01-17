# ntfy CLI helper

A tiny, dependency‑light CLI wrapper around `curl` for sending messages to an [ntfy](https://ntfy.sh/) server (or any HTTP endpoint).

It’s designed to be:

- Easy to install (single script + small installer).
- Easy to use (`ntfy "Hello World"`).
- Easy to customize (persistent defaults for base URL, topic, method).
- Generic enough for other people’s setups.

Authored by **GameDirection @ Alex Sierputowski**.

---

## Features

- Send notifications from:
  - **stdin**: `echo "msg" \| ntfy`
  - **arguments**: `ntfy "Hello World"`
- Target any ntfy server:
  - Base URL & topic via config or flags.
- Runtime flags:
  - `-u, --url [URL]` – one‑shot endpoint, or show current effective URL.
  - `-t, --topic [NAME]` – one‑shot topic, or show current topic.
  - `-m, --method [M]` – `GET` or `POST`, or show current method.
- Persistent defaults (saved under `~/.config/ntfy-cli.conf`):
  - `-su, --set-url URL` – set default base URL.
  - `-st, --set-topic NAME` – set default topic.
  - `-sm, --set-method M` – set default method.
- Introspective flags:
  - `-v, --version` – show CLI version.
  - `-h, --help` – show usage.

---

## Installation

These instructions assume you’re inside the cloned ntfy repo fork.

```bash
cd client/cli
./install-cli.sh
```

What the installer does:

1. Copies `client/cli` into:

   ```text
   ~/.local/share/ntfy
   ```

2. Creates a symlink:

   ```text
   ~/.local/bin/ntfy -> ~/.local/share/ntfy/ntfy.sh
   ```

3. Prints a line you should add to your shell startup file to ensure
   `~/.local/bin` is on your `PATH`.

### Make sure `~/.local/bin` is on your PATH

#### Bash / Zsh

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then reload:

```bash
source ~/.bashrc      # or: source ~/.zshrc
```

#### Fish

Add to `~/.config/fish/config.fish`:

```fish
set -gx PATH $HOME/.local/bin $PATH
```

Then restart fish or open a new terminal.

### Verify installation

```bash
which ntfy        # should print: /home/<user>/.local/bin/ntfy
ntfy -v           # prints ntfy.sh version X.Y
ntfy -h           # shows help
```

---

## Basic usage

### Using defaults

If you haven’t set any defaults yet, the CLI behaves like:

- Base URL: `https://ntfy.sh`
- Topic: `general`
- Method: `POST`

Examples:

```bash
# Send with args
ntfy "Hello World"

# Send from stdin
echo "Hello from stdin" | ntfy
```

Both will POST to:

```text
https://ntfy.sh/general
```

---

## Setting persistent defaults

Defaults are stored in:

```text
~/.config/ntfy-cli.conf
```

and are read on every run.

### Set your base URL

```bash
ntfy -su https://ntfy.your-domain.com
```

### Set your default topic

```bash
ntfy -st life
```

### Set your default method (optional)

```bash
ntfy -sm POST      # or GET
```

After that:

```bash
ntfy "Hi from defaults"
```

will POST to:

```text
https://ntfy.your-domain.com/life
```

### Inspect current effective values

```bash
ntfy -u    # prints current effective URL (base + topic)
ntfy -t    # prints current topic
ntfy -m    # prints current method
ntfy -v    # prints version
```

Using the options **without** an argument shows the current value instead of sending a message.

---

## Runtime flags and examples

You can override defaults at any time per call.

### Send a message with a specific topic (using default base URL)

```bash
ntfy -st life                      # one-time setup (optional)
ntfy -t MyTopic "MyTopic event"  # -> BASE_URL/MyTopic
```

### Send to a fully-specified URL

If you pass a full URL that already includes the topic:

```bash
ntfy -u https://ntfy.your-domain.com/MyTopic "hello from $HOSTNAME"
```

If you prefer to pass **base URL + topic separately**, the script can combine them:

```bash
ntfy -u https://ntfy.your-domain.com -t MyTopic "hello from $HOSTNAME"
```

The CLI detects a “bare” base (no path) and appends `/MyTopic`, resulting in:

```text
https://ntfy.your-domain.com/MyTopic
```

### Using stdin vs arguments

- If **stdin is non‑TTY** (e.g. in a pipe), stdin is used as the message:

  ```bash
  echo "piped message" | ntfy
  ```

- If stdin is a TTY and you pass trailing args, they are joined into the message:

  ```bash
  ntfy "Multi word message from args"
  ntfy -t alerts "Disk space low on /dev/nvme0n1"
  ```

- If there is no stdin and no args, the CLI prints usage and exits with error.

---

## HTTP details

- Methods: `POST` or `GET` (default: `POST`).
- Body: raw text (whatever you pipe in or pass as arguments).
- Status handling:
  - Any `2xx` or `3xx` → success (exit 0).
  - Anything else → error (non‑zero exit, prints status and URL).

---

## Configuration file

`~/.config/ntfy-cli.conf` is a small shell snippet the CLI sources:

```bash
CFG_BASE_URL='https://ntfy.your-domain.com'
CFG_TOPIC='life'
CFG_METHOD='POST'
```

You normally don’t edit this by hand; you use:

```bash
ntfy -su URL
ntfy -st TOPIC
ntfy -sm METHOD
```

to update it.

If you ever want to reset to factory defaults:

```bash
rm -f ~/.config/ntfy-cli.conf
```

Then rerun `ntfy` or set new defaults.

---

## Uninstall

To remove the CLI from your user account:

```bash
rm -f  ~/.local/bin/ntfy
rm -rf ~/.local/share/ntfy
rm -f  ~/.config/ntfy-cli.conf
```

You may also want to remove the `PATH` line you added from your shell config.

---

## Credits

CLI wrapper by **GameDirection @ Alex Sierputowski**  
Built as a small, generic addon for the ntfy project so others can install and adapt it to their own servers and workflows.

