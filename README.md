# Review Raven marketplace

A [Claude Code plugin marketplace](https://code.claude.com/docs/en/discover-plugins) distributing **Review Raven**:
a plugin to review the code changes an AI agent made.

It gives you:

- an assessment of the change's design (is it ideal? any caveats?)
- an overview over the architecture of the change
- the decisions the agent made without consulting you
- and a diff narrative: the diff of all changed files in a logical order with some explanatory remarks

You can comment directly on these elements and submit all your comments to the agent to implement.

Use it to:

- quickly assess if the agent made the right choices
- design-review changes in repos where you don't read all the code line-by-line
- or review changes line-by-line in a logical order

## Requirements

| | |
|---|---|
| Platforms | Linux x86_64, macOS arm64 (Apple Silicon), Windows x86_64 |
| First run | Network access, to fetch the binary |

## Installation

```bash
claude plugin marketplace add karottenreibe/review-raven-marketplace
claude plugin install review-raven@review-raven-marketplace
```

Or from within a Claude session:

```
/plugin marketplace add karottenreibe/review-raven-marketplace
/plugin install review-raven@review-raven-marketplace
/reload-plugins
```

### GitHub Copilot CLI

Copilot CLI reads the same plugin layout, so the plugin can be installed there with:

```
copilot plugin install karottenreibe/review-raven-marketplace
```

## Usage

The skill triggers on its own once the agent finishes a non-trivial change, or on
request — "prepare a review", "show me what you changed".
The agent writes the review file, serves it, and gives you a URL.
Open it in your browser, review the changes, comment, and press **Approve** or **Submit**.
Submitting stops the server and the agent starts working on your comments.
Approving tells it to stop.

You can prompt in your CLAUDE.md/AGENTS.md that the agent should commit after a review is approved, if you want that.

## First run

The plugin requires the `review-raven` binary, which is not included in the marketplace.
On first use it downloads the one binary for your platform from this repository's [releases](https://github.com/karottenreibe/review-raven-marketplace/releases), verifies it against `checksums.txt` from this marketplace repo and caches it under `~/.cache/review-raven/<version>/`.

In Claude, a `SessionStart` hook warms that cache when you start your next session, so the plugin makes one network request when a session starts until the binary is cached.
It is silent, never blocks startup, and backs off for an hour after a failure.

