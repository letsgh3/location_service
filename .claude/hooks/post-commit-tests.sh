#!/usr/bin/env bash
# Hook PostToolUse (Bash): po udanym `git commit` uruchamia backendowe `pytest -q`
# i przekazuje wynik agentowi.
#   zielone -> hookSpecificOutput.additionalContext (informacja dla agenta)
#   czerwone -> decision "block" + reason (agent dostaje wynik i musi zareagować;
#               commit już istnieje, więc poprawka to nowy commit `fix`, nie --amend)
# Inne komendy Bash i nieudane commity: brak wyjścia, kod 0.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# `git commit` jako osobne polecenie (także po &&, ;, |), z opcjami typu `git -C dir commit`.
# Nie łapie `git commit-tree`. Fałszywe trafienia (np. `echo git commit`) odsiewa sprawdzenie refloga niżej.
printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)' || exit 0
# --dry-run niczego nie commituje.
printf '%s' "$cmd" | grep -qE '[[:space:]]--dry-run([[:space:]]|$)' && exit 0

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
cd "$root" 2>/dev/null || exit 0

# Udany commit = ostatni wpis refloga HEAD to commit sprzed chwili.
# (Nieudany commit, np. "nothing to commit" albo odrzucony przez hook gita, nie tworzy wpisu.)
last=$(git reflog -1 --format='%gs|%ct' 2>/dev/null) || exit 0
subject=${last%|*}
when=${last##*|}
case "$subject" in commit*) ;; *) exit 0 ;; esac
[ $(( $(date +%s) - when )) -le 300 ] || exit 0

head=$(git log -1 --format='%h %s')
backend="$root/services/backend"
if [ ! -x "$backend/venv/bin/pytest" ]; then
  jq -n --arg c "post-commit [$head]: pominięto pytest -q (brak services/backend/venv; uruchom ./install.sh)." \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  exit 0
fi

out=$(cd "$backend" && venv/bin/pytest -q 2>&1)
rc=$?
summary=$(printf '%s\n' "$out" | grep -E '[0-9]+ (passed|failed|error)' | tail -1)

# 0 = zielone, 5 = brak zebranych testów
if [ "$rc" -eq 0 ] || [ "$rc" -eq 5 ]; then
  jq -n --arg c "post-commit [$head]: pytest -q OK (${summary:-brak testów})." \
    '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
  exit 0
fi

tail_out=$(printf '%s\n' "$out" | tail -40)
jq -n --arg r "post-commit [$head]: pytest -q CZERWONY (kod $rc). Commit już istnieje - napraw testy kolejnym commitem fix, nie --amend:"$'\n'"$tail_out" \
  --arg m "post-commit: pytest -q czerwony po $head" \
  '{decision: "block", reason: $r, systemMessage: $m}'
exit 0
