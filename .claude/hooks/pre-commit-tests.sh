#!/usr/bin/env bash
# Hook PreToolUse (Bash): przed `git commit` uruchamia backendowe `pytest -q`
# i blokuje commit (permissionDecision "deny"), gdy testy są czerwone.
#
# Co jest testowane:
#   - zwykły `git commit`: dokładnie zawartość indeksu (to, co wejdzie do commita),
#     wyeksportowana do katalogu tymczasowego; niezaindeksowane zmiany nie wpływają na wynik;
#   - `git commit -a`/`--all`/`<ścieżki>` albo `git add ... && git commit` w tej samej komendzie:
#     indeks jeszcze nie odpowiada commitowi, więc testy idą na drzewie roboczym.
# Commit bez zmian w services/backend/: brak testów, commit przepuszczony.
# Po zielonym teście z indeksu zapisuje hash drzewa services/backend do
# .git/claude-pretest-ok, żeby hook PostToolUse nie uruchamiał tych samych testów drugi raz.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

commit_re='(^|[;&|[:space:]])git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$cmd" | grep -qE "$commit_re" || exit 0
printf '%s' "$cmd" | grep -qE '[[:space:]]--dry-run([[:space:]]|$)' && exit 0

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
cd "$root" 2>/dev/null || exit 0
backend_rel="services/backend"
marker="$(git rev-parse --git-dir)/claude-pretest-ok"
rm -f "$marker"

allow() { exit 0; }
deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# Tryb: indeks czy drzewo robocze.
commit_part=$(printf '%s' "$cmd" | grep -oE 'commit([[:space:]].*)?$' | head -1)
mode=index
if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(add|rm|mv)([[:space:]]|$)' ||
   printf '%s' "$commit_part" | grep -qE '[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all|--include|--only|--)([[:space:]]|$)'; then
  mode=worktree
fi

if [ "$mode" = index ]; then
  git diff --cached --name-only | grep -q "^$backend_rel/" || allow
else
  { git diff --cached --name-only; git diff --name-only; git ls-files --others --exclude-standard; } \
    | grep -q "^$backend_rel/" || allow
fi

pytest_bin="$root/$backend_rel/venv/bin/pytest"
[ -x "$pytest_bin" ] || deny "pre-commit: zmiany w $backend_rel, ale brak $backend_rel/venv - nie da się uruchomić pytest -q. Uruchom ./install.sh."

if [ "$mode" = index ]; then
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/claude-pretest.XXXXXX") || deny "pre-commit: nie udało się utworzyć katalogu tymczasowego."
  trap 'rm -rf "$tmp"' EXIT
  git ls-files -z -- "$backend_rel" | git checkout-index -z --stdin --prefix="$tmp/" || deny "pre-commit: eksport indeksu nie powiódł się."
  run_dir="$tmp/$backend_rel"
  where="zawartość indeksu"
else
  run_dir="$root/$backend_rel"
  where="drzewo robocze (git commit -a / git add w tej samej komendzie)"
fi

out=$(cd "$run_dir" && "$pytest_bin" -q -p no:cacheprovider 2>&1)
rc=$?
summary=$(printf '%s\n' "$out" | grep -E '[0-9]+ (passed|failed|error)' | tail -1)

if [ "$rc" -eq 0 ] || [ "$rc" -eq 5 ]; then
  [ "$mode" = index ] && git write-tree --prefix="$backend_rel/" > "$marker" 2>/dev/null
  # Brak decyzji = zwykły przepływ uprawnień; wynik widać w transkrypcie jako kontekst.
  jq -n --arg c "pre-commit: pytest -q OK na: $where (${summary:-brak testów})." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
  exit 0
fi

deny "pre-commit: pytest -q CZERWONY (kod $rc) na: $where. Commit zablokowany - napraw testy i spróbuj ponownie:"$'\n'"$(printf '%s\n' "$out" | tail -40)"
