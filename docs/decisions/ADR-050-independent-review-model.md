# ADR-050 — What "Independent Sign-Off" Means for a Local-Only, Single-User Product

- **Status:** Accepted
- **Accepted:** 2026-08-30 by the release owner (user), who approved the independence model in full.
- **Date:** 2026-08-30
- **Owners:** AURA Runtime Completion Program / release owner (user)
- **Scope:** R12 beta sign-offs, `beta-readiness.json` `signoffs`, SP-030, SP-031

## Context

R12 requires five sign-offs — `security`, `privacy`,
`accessibility_localization`, `release_recovery`, `product_truthfulness` — and
SP-030 cannot complete until they exist. They have blocked SP-030 across several
attempts, and the blocker is real: **independence is a fact, not a permission.**
The release owner's authority, however broad, cannot make the implementing agent
independent of its own work, and `scripts/validate_beta_readiness.py` now
enforces that mechanically (`evaluator_is_implementing_agent: false`).

Two things make the original gate a poor fit as literally written:

1. **The process was designed for a different product shape.** A five-seat
   independent review board presumes a distributed product with external users,
   a release organization, and staff in distinct roles. ADR-049 made AURA
   permanently **local-only, single-user, never externally distributed**. There
   is no release org, no external user population, and no second engineer.

2. **The repository's own rule is already weaker than "hire an auditor."**
   `docs/operations/INDEPENDENT_SECURITY_REVIEW.md` states: *"The engineer who
   wrote the feature under review must not be the sole reviewer. The reviewer
   must not have opened the PRs being reviewed. Reviewers document conflicts of
   interest in the ledger entry."* The R12 prompt likewise asks to *"obtain
   documented review"*, not to obtain an external audit.

Leaving the gate un-interpretable does not make the product safer; it makes the
record dishonest in the other direction — a permanently unreachable gate invites
either indefinite blockage or a quiet fabrication. This ADR chooses the third
option: state exactly what independence means here, and exactly what is being
given up.

## Decision

**1. Independence is defined by authorship, not by employer or vendor.**
A reviewer is independent of an artifact iff it did not author that artifact and
did not open the commits under review. This matches the repository's existing
independence rule.

**2. Cross-agent review is an accepted independence mechanism, with disclosure.**
Where two different agents authored different parts of the system, each may serve
as the independent reviewer of the other's work. The sign-off record MUST
disclose: reviewer identity, what the reviewer did and did not author, and the
fact that reviewer and author are LLM agents of the same class. This is
explicitly **not** a human expert audit and must never be recorded as one.

**3. The release owner is the signatory for owner-judgment domains.**
`release_recovery` and `product_truthfulness` are owner decisions, not technical
audits. The release owner did not author the code and is independent under (1).
Owner sign-off MUST be based on a **falsification packet** — a document stating
what to check, where the evidence is, and what observation would prove the claim
wrong — not on a summary asserting that things are fine.

**4. An agent may never sign off its own work.** No exception, no owner override.
A reviewer that authored any part of an artifact — including a remediation it
wrote in response to its own finding — is disqualified for that artifact and must
say so in the record.

**5. Automated tooling corroborates but never substitutes.** Adversarial suites,
validators and scanners are non-authorial evidence and strengthen a sign-off;
they are not themselves a sign-off.

**6. What is consciously NOT obtained.** No human expert security audit, no
penetration test, no external accessibility certification, no third-party privacy
review, no runtime fuzzing campaign. These are out of scope for a local-only,
single-user product with no external users, and their absence is an **accepted
risk**, recorded as such — not a closed gate.

## Consequences

- SP-030's sign-off gate becomes reachable without fabrication, because the bar
  is stated instead of assumed.
- Every sign-off record carries its own limitations, so a future reader sees what
  the sign-off was worth rather than a bare "obtained".
- The product is **not** claimed to have passed an external audit anywhere, and
  any document implying otherwise is a defect.
- If AURA ever leaves local-only scope, this ADR must be revisited **before**
  release: the accepted risks in (6) are only acceptable because there are no
  external users. Superseding ADR-049 supersedes this one.
- The first application of (2) is already recorded:
  `docs/operations/INDEPENDENT_SECURITY_REVIEW_FINDINGS.md` Round 2, which found
  one High-severity defect (F-001, an unauthenticated crash inside the IPC
  authentication check) that the prior in-session review had missed — evidence
  that cross-agent review has non-trivial detection power rather than being a
  formality.

## Alternatives considered

- **Keep the gate as literally written.** Rejected: it is unreachable for this
  product shape, and an unreachable gate produces either permanent blockage or
  silent fabrication. Neither is safer.
- **Let the owner's blanket approval close the sign-offs.** Rejected: approval is
  authority, not review. It would record a review that never happened.
- **Let the implementing agent self-review with a fresh context.** Rejected, and
  now mechanically blocked. This was the SP-025 Round 1 accommodation; Round 2
  demonstrates why it is insufficient — a genuinely non-authorial reader found a
  High-severity defect that the self-review had marked "no finding".
- **Obtain a real external audit.** Not rejected on merit — it is simply not
  available for this project, and pretending otherwise would be the dishonesty
  this ADR exists to prevent. Recorded as accepted risk (6).

## Falsifiers

Any claim that AURA passed an external, human, or third-party security, privacy,
or accessibility audit; that a sign-off was obtained from an evaluator who
authored the reviewed artifact; or that the accepted risks in (6) were closed
rather than accepted, would falsify this ADR.
