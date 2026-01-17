## Clone or download the repo somewhere accessible (e.g. ~/dev/myrepo)
`sudo git -y && mkdir -p /dev/ntfy && git archive --remote https://github.com/Gamedirection/ntfy.git client/cli | tar -xvf -`

## Compiling manpage

`groff -Tman client/cli/man/ntfy.1.source > /usr/share/man/man1/ntfy.1`
or, on macOS/Linux with local man-db:
`mkdir -p ~/.local/share/man && gzip -c client/cli/man/ntfy.1.source > ~/.local/share/man/ntfy.1.gz`
