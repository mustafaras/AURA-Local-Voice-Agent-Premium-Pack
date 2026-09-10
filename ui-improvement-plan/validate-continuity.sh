#!/usr/bin/env bash
# validate-continuity.sh — the plan-machine referee (Volume III, 00-working-protocol.md §7)
# Cross-audits prompts <-> CURRENT_PHASE <-> PHASE_LEDGER mechanically.
# Exit 0 = coherent; non-zero = stop and repair the machine before any other action.
set -u
cd "$(dirname "$0")" || exit 1

fail() { echo "VALIDATOR: FAIL - $1" >&2; exit 1; }
ok()   { echo "VALIDATOR: $1"; }

# [1] Machinery files exist
for f in 00-working-protocol.md prompts/UI-0.prompt.md prompts/UI-1.prompt.md \
         prompts/UI-2.prompt.md prompts/UI-3.prompt.md prompts/UI-4.prompt.md \
         prompts/UI-5.prompt.md ledger/CURRENT_PHASE.md ledger/PHASE_LEDGER.md; do
  [ -f "$f" ] || fail "missing machinery file: $f"
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
if [ -z "$PROMPT_GATES" ]; then
  fail "no gate rows found in $PROMPT"
fi
if [ "$PROMPT_GATES" != "$CURRENT_GATES" ]; then
  fail "gate parity broken between $PROMPT and ledger/CURRENT_PHASE.md"
fi
GATE_COUNT=$(echo "$PROMPT_GATES" | wc -l | tr -d ' ')
ok "[3] gate parity holds ($ACTIVE: $GATE_COUNT gates)"

# [3b] Status vocabulary check
BAD_STATUS=$(grep -E '^\| G[0-9]+-[0-9]+ \|' ledger/CURRENT_PHASE.md | grep -vE 'pending|in-progress|passed|blocked' | head -3)
if [ -n "$BAD_STATUS" ]; then
  fail "illegal gate status in CURRENT_PHASE (allowed: pending|in-progress|passed|blocked)"
fi
ok "[3b] gate statuses legal"

# [4] last_seq == max SEQ in PHASE_LEDGER
LAST_SEQ=$(grep -m1 '^last_seq:' ledger/CURRENT_PHASE.md | sed 's/last_seq:[[:space:]]*//')
[ -n "$LAST_SEQ" ] || fail "no last_seq line in CURRENT_PHASE.md"
MAX_SEQ=$(grep -oE 'SEQ-[0-9]+' ledger/PHASE_LEDGER.md | sed 's/SEQ-//' | sed 's/^0*//' | sort -n | tail -1)
if [ "$LAST_SEQ" != "$MAX_SEQ" ]; then
  fail "last_seq ($LAST_SEQ) != max SEQ in PHASE_LEDGER ($MAX_SEQ)"
fi
ok "[4] last_seq $LAST_SEQ == max ledger SEQ $MAX_SEQ"

# [5] Transition legality: each phase's first ledger entry must be preceded
#     by an APPROVAL line for the previous -> this phase.
PREV=""
for P in UI-0 UI-1 UI-2 UI-3 UI-4 UI-5; do
  FIRST=$(grep -m1 -n "— ${P} —" ledger/PHASE_LEDGER.md | cut -d: -f1)
  if [ -n "$FIRST" ] && [ -n "$PREV" ]; then
    APPROVAL_LINE=$(grep -n "^APPROVAL: ${PREV} -> ${P}" ledger/PHASE_LEDGER.md | head -1 | cut -d: -f1)
    if [ -z "$APPROVAL_LINE" ]; then
      fail "phase $P has ledger entries but no 'APPROVAL: ${PREV} -> ${P}' precedes them"
    fi
    if [ "$APPROVAL_LINE" -ge "$FIRST" ]; then
      fail "APPROVAL ${PREV}->${P} must appear before ${P}'s first ledger entry"
    fi
  fi
  PREV=$P
done
ok "[5] transition legality verified (approvals precede phase entries)"

echo "VALIDATOR: OK - machine coherent"
exit 0
