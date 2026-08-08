# The proposal (RFC) process

Nothing enters a roadmap without going through a proposal. Rejected proposals are never
deleted — a well-argued rejection documents learning just as much as a shipped feature.

A proposal is first and foremost a place to **study**: state an intention, research how the
problem is solved elsewhere, sketch a design that fits, and only then decide.

Where a proposal lives — which repository, which directory, how it is numbered — is stated in
`CONVENTIONS.md`, *Proposals*. Read that before step 1 below, which assumes the destination is
already settled.

## Steps

1. Copy `TEMPLATE.md` to `NNNN-short-title.md`, using the next available number.
2. Fill in **Motivation**, set the status to `Draft`, declare the **Scope**, and add it to the
   local index.
3. Grow **Study** and **Proposed design** over time. Move the status to `Exploring` while
   actively researching.
4. When ready, fill in **Decision** with the outcome and its reasoning, and set the status to
   `Accepted` or `Rejected`.
5. Once an accepted proposal is built, set the status to `Implemented` and link the relevant
   commits or pull requests from the Decision section.

## Statuses

| Status | Meaning |
| --- | --- |
| `Draft` | Intention registered; little or no research yet |
| `Exploring` | Actively being studied and expanded |
| `Accepted` | Will be built; ready for implementation |
| `Rejected` | Studied and deliberately not pursued (reasoning in Decision) |
| `Implemented` | Accepted and shipped |

## Supporting artifacts

A proposal that needs companion material — test plans, simulations, data, diagrams — keeps it in
a folder named after the proposal (`NNNN-short-title/`) beside the proposal file, linked from the
relevant section.

**A simulation plan is worth more than a confident paragraph.** Where a design rests on how a
platform actually behaves, measure it: state the working claim, the steps, and what you expect —
then record what happened, including when the claim was refuted. Every round of this kind run so
far corrected a design rather than confirming it.
