#!/usr/bin/env bash
# validate-continuity.sh — the PA plan-machine referee (00-working-protocol.md §7)
# Cross-audits prompts <-> CURRENT_PHASE <-> PHASE_LEDGER mechanically.
# Exit 0 = coherent; non-zero = stop and repair the machine before any other action.
set -u
cd "$(dirname "$0")" || exit 1

fail() { echo "VALIDATOR: FAIL - $1" >&2; exit 1; }
ok()   { echo "VALIDATOR: $1"; }

PHASES="PA-0 PA-1 PA-2 PA-3 PA-4 PA-5 PA-6"

# [1] Machinery files exist
for f in 00-working-protocol.md ledger/CURRENT_PHASE.md ledger/PHASE_LEDGER.md; do
  [ -f "$f" ] || fail "missing machinery file: $f"
done
for P in $PHASES; do
  [ -f "prompts/${P}.prompt.md" ] || fail "missing prompt file: prompts/${P}.prompt.md"
done
ok "[1] machinery files present"

# [2] active_phase names an existing prompt
ACTIVE=$(grep -m1 '^active_phase:' ledger/CURRENT_PHASE.md | sed 's/active_phase:[[:space:]]*//')
[ -n "$ACTIVE" ] || fail "no active_phase line in CURRENT_PHASE.md"
PROMPT="prompts/${ACTIVE}.prompt.md"
[ -f "$PROMPT" ] || fail "active_phase '$ACTIVE' has no prompt file: $PROMPT"
ok "[2] active_phase $ACTIVE -> $PROMPT exists"

# [3] Gate parity (both directions, prompt <-> CURRENT_PHASE)
PROMPT_GATES=$(grep -oE '^\| G[0-9]+-[0-9]+ ' "$PROMPT" | awk '{print $2}' | sort)
CURRENT_GATES=$(grep -oE '^\| G[0-9]+-[0-9]+ ' ledger/CURRENT_PHASE.md | awk '{print $2}' | sort)
[ -n "$PROMPT_GATES" ] || fail "no gate rows found in $PROMPT"
[ "$PROMPT_GATES" = "$CURRENT_GATES" ] || fail "gate parity broken between $PROMPT and ledger/CURRENT_PHASE.md"
GATE_COUNT=$(echo "$PROMPT_GATES" | wc -l | tr -d ' ')
ok "[3] gate parity holds ($ACTIVE: $GATE_COUNT gates)"

# [3b] Status vocabulary check
BAD_STATUS=$(grep -E '^\| G[0-9]+-[0-9]+ \|' ledger/CURRENT_PHASE.md | grep -vE '\| (pending|in-progress|passed|blocked) \|' | head -3)
[ -z "$BAD_STATUS" ] || fail "illegal gate status in CURRENT_PHASE (allowed: pending|in-progress|passed|blocked)"
ok "[3b] gate statuses legal"

# [4] last_seq == max SEQ in PHASE_LEDGER
LAST_SEQ=$(grep -m1 '^last_seq:' ledger/CURRENT_PHASE.md | sed 's/last_seq:[[:space:]]*//')
[ -n "$LAST_SEQ" ] || fail "no last_seq line in CURRENT_PHASE.md"
MAX_SEQ=$(grep -oE '^## SEQ-[0-9]+' ledger/PHASE_LEDGER.md | sed 's/## SEQ-//' | sed 's/^0*//' | sort -n | tail -1)
[ "$LAST_SEQ" = "$MAX_SEQ" ] || fail "last_seq ($LAST_SEQ) != max SEQ in PHASE_LEDGER ($MAX_SEQ)"
ok "[4] last_seq $LAST_SEQ == max ledger SEQ $MAX_SEQ"

# [5] Transition legality: each phase's first ledger entry must be preceded
#     by an APPROVAL line for the previous -> this phase.
PREV=""
for P in $PHASES; do
  FIRST=$(grep -m1 -n "— ${P} —" ledger/PHASE_LEDGER.md | cut -d: -f1)
  if [ -n "$FIRST" ] && [ -n "$PREV" ]; then
    APPROVAL_LINE=$(grep -n "^APPROVAL: ${PREV} -> ${P}" ledger/PHASE_LEDGER.md | head -1 | cut -d: -f1)
    [ -n "$APPROVAL_LINE" ] || fail "phase $P has ledger entries but no 'APPROVAL: ${PREV} -> ${P}' precedes them"
    [ "$APPROVAL_LINE" -lt "$FIRST" ] || fail "APPROVAL ${PREV}->${P} must appear before ${P}'s first ledger entry"
  fi
  PREV=$P
done
# PA-0 itself opens only on the owner's token.
FIRST0=$(grep -m1 -n "— PA-0 —" ledger/PHASE_LEDGER.md | cut -d: -f1)
if [ -n "$FIRST0" ]; then
  OPEN0=$(grep -n '^APPROVAL: PLAN -> PA-0' ledger/PHASE_LEDGER.md | head -1 | cut -d: -f1)
  [ -n "$OPEN0" ] || fail "PA-0 has ledger entries but no 'APPROVAL: PLAN -> PA-0' (token ONAY PA-0) precedes them"
  [ "$OPEN0" -lt "$FIRST0" ] || fail "APPROVAL PLAN->PA-0 must appear before PA-0's first ledger entry"
fi
ok "[5] transition legality verified (approvals precede phase entries)"

# [6] Policy-change gate (protocol A7): every [policy]-tagged gate that is
#     'passed' in CURRENT_PHASE must have a PASSED ledger entry carrying an
#     'adr: ADR-' line before the next '## ' heading.
POLICY_GATES=$(grep -E '^\| G[0-9]+-[0-9]+ \|.*\[policy\]' "$PROMPT" | awk '{print $2}')
for G in $POLICY_GATES; do
  STATUS=$(grep -E "^\| ${G} \|" ledger/CURRENT_PHASE.md | awk -F'|' '{gsub(/ /,"",$4); print $4}')
  if [ "$STATUS" = "passed" ]; then
    ENTRY=$(awk -v g="— ${ACTIVE} — ${G} PASSED" '
      $0 ~ "^## SEQ-" { inblk = index($0, g) > 0; next }
      inblk && /^- adr: ADR-[0-9]+/ { found = 1 }
      END { print found ? "yes" : "no" }' ledger/PHASE_LEDGER.md)
    [ "$ENTRY" = "yes" ] || fail "[policy] gate ${G} is passed but its ledger entry has no 'adr: ADR-NNN' line (A7)"
  fi
done
ok "[6] policy-change gate satisfied for passed [policy] gates"

echo "VALIDATOR: OK - machine coherent"
exit 0
