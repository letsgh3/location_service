"""Liczy mutation score z mutants/mutmut-cicd-stats.json i sprawdza próg.

Użycie (z services/backend/, po `mutmut run` i `mutmut export-cicd-stats`):
    python scripts/mutation_score.py --min 60

Score = (killed + timeout) / (total - skipped) * 100. Mutanty bez testów,
podejrzane i przerwane liczą się jako niezabite. Gdy ustawiona jest zmienna
GITHUB_STEP_SUMMARY, dopisuje tabelę do podsumowania joba w GitHub Actions.
Kod wyjścia 1, gdy score jest poniżej progu albo nie ma żadnych mutantów.
"""
import argparse
import json
import os
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stats", type=Path, default=Path("mutants/mutmut-cicd-stats.json"))
    parser.add_argument("--min", type=float, required=True, help="minimalny score w procentach")
    args = parser.parse_args()

    stats = json.loads(args.stats.read_text())
    detected = stats["killed"] + stats["timeout"]
    considered = stats["total"] - stats["skipped"]
    if considered <= 0:
        print("Brak mutantów do oceny - sprawdź konfigurację [tool.mutmut].")
        return 1

    score = detected / considered * 100
    passed = score >= args.min
    verdict = "OK" if passed else "PONIŻEJ PROGU"
    line = f"Mutation score: {score:.2f}% ({detected}/{considered}), próg {args.min:.0f}% - {verdict}"
    print(line)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        rows = "\n".join(f"| {key} | {value} |" for key, value in stats.items())
        with open(summary, "a", encoding="utf-8") as f:
            f.write(f"## Testy mutacyjne (mutmut)\n\n**{line}**\n\n| status | liczba |\n|---|---|\n{rows}\n")

    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
