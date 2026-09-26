<p align="center"><img src="logo.svg" alt="review raven logo" width="240"></p>

# review raven marketplace

A plugin marketplace distributing **Review Raven**: a review of the code changes an AI
agent made, which you read and answer. It works with [Claude Code](#claude-code),
[GitHub Copilot CLI](#github-copilot-cli-and-visual-studio-code), [Codex](#codex), and
[GitHub Copilot in VS Code](#github-copilot-cli-and-visual-studio-code).

More at [rottenrei.be/review-raven](https://rottenrei.be/review-raven).

The agent writes a review of what it did — a diagram of the concepts the change
touched, the design decisions it rests on, and a walkthrough of the diff a chunk at a
time. `review-raven` serves that as a web page where you comment on lines, then
approve or request changes. The agent picks your answer up and starts the next round.

## Requirements

| | |
|---|---|
| Platforms | Linux x86_64, macOS arm64 (Apple Silicon), Windows x86_64 |
| First run | Network access, to fetch the binary |

Nothing else is needed: Windows uses the PowerShell that ships with the system, and
no Rust or Node toolchain is required on any platform.

## Installation

### Claude Code

```
/plugin marketplace add karottenreibe/review-raven-marketplace
/plugin install review-raven@review-raven-marketplace
/reload-plugins
```

Or from a shell, without starting a session:

```bash
claude plugin marketplace add karottenreibe/review-raven-marketplace
claude plugin install review-raven@review-raven-marketplace
```

### GitHub Copilot CLI and Visual Studio Code

Copilot CLI reads the same marketplace layout. Add the marketplace, then install the
plugin from it:

```
copilot plugin marketplace add karottenreibe/review-raven-marketplace
copilot plugin install review-raven@review-raven-marketplace
```

This also installs it for GitHub Copilot in VS Code.

### Codex

Codex reads the same marketplace. Add it, then enable Review Raven in `/plugins`
inside a session:

```
codex plugin marketplace add karottenreibe/review-raven-marketplace
```

## Usage

The skill triggers on its own once the agent finishes a non-trivial change, or on
request — "prepare a review", "show me what you changed". The agent writes the review
file, serves it, and gives you a URL. Read it, comment, and press **Approve** or
**Submit**. Submitting stops the server, which is how the agent knows to start the next
round.

## First run

The plugin ships no binaries. On first use it downloads the one archive for your
platform from this repository's [releases](https://github.com/karottenreibe/review-raven-marketplace/releases),
verifies it against `checksums.txt` — which arrives with the plugin over git, not
from the release — and caches the binary it contains under `~/.cache/review-raven/<version>/`.

To install the binary by hand, download the archive for your platform, named after its
Rust target (e.g. `review-raven-x86_64-unknown-linux-musl.tar.gz`, or `.zip` on Windows),
and extract it: it contains a single file, `review-raven` or `review-raven.exe`.
