# Code Review: commit #1 planu listing-filters (cp/1)

Baza: branch `Location_description`, HEAD `fd1d2f6` (== `cp/1`), zakres `git show cp/1` (diff względem rodzica `953e7de`). Plan: `.agent/plans/listing-filters.md` wiersz #1.
Zmiany: 1 plik (`services/backend/sql_app/schemas.py`), +22/−0 linii.

Niezacommitowane zmiany w drzewie roboczym (`.claude/agents/*.md`, `CLAUDE.md`, `.agent/plans/listing-filters.md`) są poza przeglądem; nie dotyczą `services/backend/`, więc wynik testów odpowiada dokładnie stanowi `cp/1`.

**Werdykt: APPROVE**

## Testy

| Bramka | Komenda | Wynik |
|--------|---------|-------|
| backend | `cd services/backend && source venv/bin/activate && pytest -q` | 26 passed in 8.41s (bez regresji względem stanu wyjściowego z planu: 26 passed) |
| backend (kontrola ad hoc, tylko odczyt) | `python -I -c ...` (walidacja `ListingSummary.model_validate` na nietrwałym obiekcie ORM `Listing` z relacją `location`) | OK: `{'listing_id': 1, 'rooms': 2, 'area': 50.0, 'price_total_zl': 1000000.0, 'price_sqm_zl': 20000.0, 'location': {'city': 'Kraków', 'city_district': 'Podgórze'}}`, pola `url`/`description_text` pominięte; `ListingCount(total=0)` → `{'total': 0}` |
| migracja | nie dotyczy | brak zmian w `models.py` i `alembic/versions/` |
| frontend / e2e | nie dotyczy | brak zmian w tych serwisach |

## Zgodność z planem

| Sprawdzenie | Wynik | Uwagi |
|-------------|-------|-------|
| Pliki w wierszu #1 | OK | tylko `services/backend/sql_app/schemas.py` |
| Strażnik zakresu | OK | `git diff --name-only 953e7de...HEAD` → tylko `services/backend/sql_app/schemas.py` |
| Budżet | 22 l. / 1 plik vs 30 l. / 1 plik | w budżecie |
| Komunikat commita | OK | `feat(backend): schematy LocationSummary, ListingSummary i ListingCount` identyczny z kolumną Commit (+ stopka Co-Authored-By) |
| Przypadki testowe z planu | n/d | plan dla #1 nie przewiduje przypadków testowych (wyjątek: zmiana czysto schematowa, weryfikacja import + regresja) |
| Decyzje D-n | OK | kształt zgodny z sekcją "1. Kontrakt" co do pola i typu; `ListingCount` jako osobny schemat zgodnie z D1; zagnieżdżone `location` jak w `ListingDetail` |

Dodatkowo: typy pól zgodne z modelem (`Listing.rooms` Integer, `area`/`price_total_zl`/`price_sqm_zl` Float, wszystkie nullable → `Optional[...] = None`; `Location.city`/`city_district` String nullable). `location: LocationSummary` jest wymagane, co jest poprawne, bo `Listing.location_id` ma `nullable=False`. Brak pól wrażliwych. Commit nie używa niczego z #2+, nie miesza `refactor` z `feat`, nie zmienia istniejących schematów ani endpointów (kontrakt istniejący nienaruszony; nowe schematy nie są jeszcze nigdzie używane).

## Znaleziska

Brak znalezisk.

Uwaga na następny krok (nie znalezisko dla #1): `location: LocationSummary` wymaga, by w #2 relacja była ładowana `selectinload(models.Listing.location)`, inaczej serializacja w sesji async rzuci `MissingGreenlet`. Plan #2 to przewiduje; do sprawdzenia przy przeglądzie cp/2.

## Rekomendacja dla commit-planner

Brak.
