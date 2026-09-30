#!/usr/bin/env bash
set -euo pipefail

# This hook runs only in Claude Code on the web, which is a remote environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# This variable holds one more directory for the PATH. The fallback function
# below sets it. It stays empty when the usual installation succeeds.
FALLBACK_BIN=""

# Install mise, if it is not installed already.
#
# Use the official installer at mise.run. A direct download of a mise release
# needs the version number first. The "releases/latest" page of github.com
# shows that number, but it returns error 403 in a web session. That error
# applies to the "releases/latest" page only. It does not apply to a release
# asset with a pinned tag. The fallback below thus can use a pinned asset, but
# this step cannot.
#
# The installer at mise.run gets mise from mise.jdx.dev. It also examines the
# checksum, finds the operating system and the architecture, and installs mise
# in $HOME/.local/bin/mise.
if ! command -v mise &>/dev/null; then
  curl -fsSL https://mise.run | sh
fi

export PATH="$HOME/.local/bin:$PATH"

# Get Elixir from a release asset on github.com.
#
# The usual source of the prebuilt files is builds.hex.pm. The network policy
# of a session can block that host. A release asset with a pinned tag stays
# available. The error 403 above applies to the "releases/latest" page only.
#
# This function does not put the files in the directory of mise. It puts them
# in a separate directory, and it adds that directory to the PATH. Thus the
# records of mise stay correct.
install_elixir_from_github() {
  local full version otp_major target url

  full=$(awk '/^elixir/ {print $2}' "$PROJECT_DIR/.tool-versions")
  version="${full%-otp-*}"
  otp_major="${full##*-otp-}"
  target="$HOME/.local/elixir-$full"
  url="https://github.com/elixir-lang/elixir/releases/download/v${version}/elixir-otp-${otp_major}.zip"

  if [ ! -x "$target/bin/elixir" ]; then
    echo "The hook gets Elixir $full from github.com."
    mkdir -p "$target"
    curl -fsSL "$url" -o "$target/elixir.zip"
    unzip -qo "$target/elixir.zip" -d "$target"
    rm -f "$target/elixir.zip"
    chmod +x "$target"/bin/*
  fi

  FALLBACK_BIN="$target/bin"
}

# Install Erlang and Elixir. The versions are in the .tool-versions file.
#
# A failure here is most often a short network fault. Thus the hook runs the
# command a second time before it uses the fallback.
if ! mise install --yes && ! mise install --yes; then
  echo "The command mise install failed two times."

  # Erlang has no prebuilt file on github.com. A build from source needs more
  # than 10 minutes on this machine. This hook does not do such a build,
  # because the hook runs at the start of every session. The hook stops here
  # and shows the command that builds Erlang.
  if ! mise which erl &>/dev/null && ! command -v erl &>/dev/null; then
    echo "Erlang is absent. The network policy probably blocks the host builds.hex.pm." >&2
    echo "To build Erlang from source, run this command:" >&2
    echo "  MISE_ALL_COMPILE=1 mise install erlang --yes" >&2
    exit 1
  fi

  # Erlang is present, so only Elixir is absent.
  install_elixir_from_github
fi

# Make mise active and keep the paths for the session.
eval "$(mise activate bash)"

# Keep the mise shims and the environment for the Claude session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"${FALLBACK_BIN:+$FALLBACK_BIN:}$HOME/.local/share/mise/shims:$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  echo 'export ELIXIR_ERL_OPTIONS="+fnu"' >> "$CLAUDE_ENV_FILE"
fi

# Install hex and rebar. The command mix deps.get needs them.
export PATH="${FALLBACK_BIN:+$FALLBACK_BIN:}$PATH"
mix local.hex --force --if-missing
mix local.rebar --force --if-missing
