#!/usr/bin/env bash
# Automatyczna walidacja zaindeksowanych zmian przed commitem (skill /safe-commit).
# Użycie: validate.sh <plik_z_komunikatem>
# Wynik: tabela PASS/WARN/FAIL/SKIP, kod wyjścia 1 przy dowolnym FAIL.
# Zmienne: SAFE_COMMIT_E2E=1 włącza testy e2e, SAFE_COMMIT_SKIP_TESTS=1 pomija testy (raportowane jako SKIP).

set -u
msg_file="${1:-}"
root=$(git rev-parse --show-toplevel) || exit 2
cd "$root" || exit 2

rows=()
fail=0
add() { # status, check, details
  rows+=("$(printf '| %-15s | %-4s | %s |' "$2" "$1" "$3")")
  [ "$1" = "FAIL" ] && fail=1
  return 0
}

staged=$(git diff --cached --name-only --diff-filter=ACMRD)
if [ -z "$staged" ]; then
  add FAIL staged "brak zaindeksowanych zmian"
else
  add PASS staged "$(printf '%s\n' "$staged" | wc -l | tr -d ' ') plik(ów)"
fi

# --- komunikat ---
header=""
[ -n "$msg_file" ] && [ -f "$msg_file" ] && header=$(head -n1 "$msg_file")
cc_re='^(feat|fix|refactor|perf|test|docs|build|ci|chore|style|revert)(\([a-z0-9._-]+\))?!?: [^ ].*[^.]$'
if [ -z "$header" ]; then
  add FAIL message "brak pliku z komunikatem lub pusty nagłówek"
elif ! printf '%s' "$header" | grep -qE "$cc_re"; then
  add FAIL message "nagłówek niezgodny z Conventional Commits: '$header'"
elif [ "${#header}" -gt 72 ]; then
  add FAIL message "nagłówek ma ${#header} znaków (> 72)"
elif [ "$(sed -n 2p "$msg_file")" != "" ]; then
  add FAIL message "druga linia komunikatu musi być pusta"
else
  add PASS message "$header"
fi

# --- zakres vs serwisy ---
services=$(printf '%s\n' "$staged" | sed -n 's#^services/\([^/]*\)/.*#\1#p' | sort -u)
nsvc=$(printf '%s' "$services" | grep -c . || true)
scope=$(printf '%s' "$header" | sed -n 's/^[a-z]*(\([^)]*\)).*/\1/p')
if [ -z "$staged" ]; then
  add SKIP scope "brak zmian"
elif [ "$nsvc" -gt 1 ]; then
  add WARN scope "zmiany w kilku serwisach: $(echo $services) (jeden commit = jeden serwis)"
elif [ "$nsvc" -eq 1 ] && [ "$scope" != "$services" ]; then
  add WARN scope "zakres '${scope:-brak}' ≠ serwis '$services'"
else
  add PASS scope "${scope:-bez zakresu}"
fi

# --- zakazane pliki ---
bad=$(printf '%s\n' "$staged" | grep -E '(^|/)\.env($|\.)|\.db$|(^|/)(venv|node_modules|__pycache__|dist)/' | grep -vE '\.env\.example$' || true)
if [ -n "$bad" ]; then
  add FAIL forbidden-files "$(echo $bad)"
else
  add PASS forbidden-files "brak"
fi

# --- sekrety w dodanych liniach ---
secret_re='-----BEGIN [A-Z ]*PRIVATE KEY-----|(SECRET_KEY|[A-Z_]*API_KEY|[A-Z_]*TOKEN|PASSWORD)[[:space:]]*[=:][[:space:]]*["'"'"']?[A-Za-z0-9+/_=-]{16,}|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}'
hits=$(git diff --cached -U0 | grep -E '^\+[^+]' | grep -E -- "$secret_re" | sed -E 's#([A-Za-z0-9+/_=-]{4})[A-Za-z0-9+/_=-]{8,}#\1***#g' | cut -c1-80 || true)
if [ -n "$hits" ]; then
  add FAIL secrets "podejrzane linie: $(printf '%s' "$hits" | head -3 | tr '\n' ' ')"
else
  add PASS secrets "brak"
fi

# --- migracja Alembic ---
if printf '%s\n' "$staged" | grep -qx 'services/backend/sql_app/models.py'; then
  if git diff --cached --name-only --diff-filter=A | grep -q '^services/backend/alembic/versions/.*\.py$'; then
    add PASS migration "models.py + nowa migracja"
  else
    add FAIL migration "models.py zmieniony bez nowej migracji w alembic/versions/"
  fi
else
  add SKIP migration "models.py bez zmian"
fi

if printf '%s\n' "$staged" | grep -qx 'docs/schema.md' && ! printf '%s\n' "$staged" | grep -qx 'services/backend/sql_app/models.py'; then
  add WARN schema-doc "docs/schema.md jest generowany; zmiana bez models.py wygląda na ręczną edycję"
fi

# --- testy ---
unstaged=$(git diff --name-only)
run_gate() { # name, service dir, command
  local name=$1 dir=$2 cmd=$3 out rc
  if ! printf '%s\n' "$staged" | grep -q "^services/$dir/"; then
    add SKIP "$name" "brak zmian w services/$dir"
    return
  fi
  if [ "${SAFE_COMMIT_SKIP_TESTS:-0}" = "1" ]; then
    add SKIP "$name" "SAFE_COMMIT_SKIP_TESTS=1"
    return
  fi
  out=$(cd "services/$dir" && bash -c "$cmd" 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    add PASS "$name" "$(printf '%s\n' "$out" | grep -E 'passed|failed|built in|error' | tail -1)"
  else
    add FAIL "$name" "kod $rc: $(printf '%s\n' "$out" | grep -E 'FAILED|Error|error|failed' | head -3 | tr '\n' ' ')"
    printf '%s\n' "--- $name (ostatnie linie) ---" "$(printf '%s\n' "$out" | tail -25)" >&2
  fi
  if printf '%s\n' "$unstaged" | grep -q "^services/$dir/"; then
    add WARN unstaged "services/$dir ma niezaindeksowane zmiany; $name objął też je"
  fi
}

if [ -x services/backend/venv/bin/pytest ]; then
  run_gate backend-tests backend "venv/bin/pytest -q"
elif printf '%s\n' "$staged" | grep -q '^services/backend/'; then
  add FAIL backend-tests "brak services/backend/venv (uruchom ./install.sh)"
fi

if [ -d services/frontend/node_modules ]; then
  run_gate frontend-build frontend "npm run build --silent"
elif printf '%s\n' "$staged" | grep -q '^services/frontend/'; then
  add FAIL frontend-build "brak services/frontend/node_modules (uruchom ./install.sh)"
fi

if printf '%s\n' "$staged" | grep -q '^services/e2e/'; then
  if [ "${SAFE_COMMIT_E2E:-0}" != "1" ]; then
    add SKIP e2e-tests "wolne; włącz SAFE_COMMIT_E2E=1"
  elif [ -x services/e2e/venv/bin/pytest ]; then
    run_gate e2e-tests e2e "venv/bin/pytest -q"
  else
    add FAIL e2e-tests "brak services/e2e/venv (uruchom ./install.sh --with-e2e)"
  fi
fi

echo "| Sprawdzenie     | Wynik | Szczegóły |"
echo "|-----------------|------|-----------|"
printf '%s\n' "${rows[@]}"
if [ "$fail" -eq 1 ]; then
  echo "WYNIK: FAIL (nie commituj)"
  exit 1
fi
echo "WYNIK: OK"
