---
name: review-raven
description: Write a review file describing code changes you just made in any repository, so the user can read them in the review raven web viewer. Use after finishing a non-trivial change set, or when the user asks you to "prepare a review", "show me what you changed", or "write a review file".
---

# Writing a review for review raven

The reader already sees the diff.
The review supplies what the diff cannot: which parts of the system did the change touch, whether its shape is right, and why this change over an alternative.

## The loop

1. `review-raven --new` from the changed repository.
   It writes a seeded review file and lists the changed files to account for.
2. Replace every `TODO`; delete blocks and fields you do not need.
3. `review-raven <file> --check`.
   Fix what it reports.
4. Run `review-raven <file>` in the background and **outside the sandbox** (inside it, the user likely cannot reach the port).
   Give the user the printed URL.
5. Do not edit anything until it exits; the tree at submission is the next round's baseline.
6. Do what it printed on exit.
   On changes requested, answer every comment under `previous` before serving the next round.

If `review-raven` is not on `PATH`, run `bin/review-raven` (`bin\review-raven.cmd` on Windows) from two directories above this skill's directory.

## The parts

| Part | Field | Scope | Question |
|---|---|---|---|
| Ideal design | `ideal` | Whole change | Would you build it the same way on a clean slate? |
| Last round | `previous` | Previous round | What did the reviewer ask for, and what came of it? |
| Architecture | `toc`, `architecture` | Whole change | Which parts of the system architecture did the change touch? |
| Design | `design.decisions`, `caveats` | Whole change | Why this shape, and what will surprise the reviewer? |
| Implementation | `intro`, `narrative` | This round | How was it carried out, concept by concept? |

Each part must make sense when read alone.
Never state the same point in two parts.
Do not restate instructions or decisions the user gave.
From the second round on, leave `base` as the tool set it.

## Answering the last round

For each comment under `previous`, write only `reply` and `concept`:

- `reply`: what you changed, in a sentence or two, addressed to the reviewer.
  Do the implementation before writing the replies.
- `concept`: the section that shows the implementation.
  Omit it for a comment you did not act on, and say why in the reply.
  Never delete a comment.
- `on: "reply"` means your previous answer (`quote`) was not accepted.
  Re-read the implementation; do not repeat the claim.

## Architecture

- `toc`: "In order to <goal>, I needed to" and a list with one terse sentence per section, in narrative order.
  Link each sentence to its section as `[sentence](#concept-id)`.
- One box per logical concept, never per file, function or commit.
  Three to eight boxes, including surrounding `context` concepts.
- `kind: touched` for a concept this round created or altered; `context` otherwise.
  Each `touched` box needs a narrative section; a concept not worth one is `context` or omitted.
- `row`/`col`: inputs above what they flow into; related concepts in one column; one box per cell.
- Every box has at least one arrow.
  Label arrows with a one-to-four-word relationship ("asks it to decide").

## Design

- `ideal`: how you would design the affected feature on a clean slate.
  Omit if identical to the current design.
- `decisions`: every decision you made without the user.
  For each: the choice, the constraint that forced it, its cost, and `rejected` options with why each lost (`rejected` may be empty).
- `caveats`: what will surprise the reviewer.
  Short noun-phrase title, detail below.
  Not a change summary.

## Implementation

- `intro`: the problem, in terms a reader new to this code understands, before naming any file.
  On later rounds, what this round set out to fix.
- `narrative`: one section per `touched` concept, each exactly once.
  Order sections so they build on each other.
- Section `title`: a full sentence stating what is true about the concept after the change.
- Each `diff` block has a `text` passage above it saying why the chunk exists.
  The first passage of a section is written for someone who has never seen the code.
- `ranges` span each chunk edge to edge; every changed line falls inside some block's ranges.
  Unrelated edits in one file are separate blocks.
  Omit `ranges` only for added or deleted files.
- Reasoning about a single line belongs in a code comment, not the review.
