# Code Review: commit #2 planu listing-filters (przed cp/2) | unstaged + untracked na `Location_description`

Baza: branch `Location_description`, HEAD `777e6b0`, zakres: `git diff` (unstaged: `services/backend/main.py`), `git diff --cached` (pusty, nic nie jest zaindeksowane), nieśledzony `services/backend/tests/api/test_listings.py` (pełna treść). Plan: `.agent/plans/listing-filters.md` wiersz #2 (`cp/1` istnieje, `cp/2` nie).
Zmiany: 2 pliki, +98/−1 linii (`main.py` +21/−1, `tests/api/test_listings.py` +76 nowy).

Uwaga: oba pliki są poza indeksem (jeden unstaged, jeden untracked); przed commitem trzeba zaindeksować oba, inaczej commit nie obejmie testów albo endpointu.

**Werdykt: APPROVE**

## Testy

| Bramka | Komenda | Wynik |
|--------|---------|-------|
| backend | `cd services/backend && source venv/bin/activate && pytest -q` | 31 passed in 8.23s (26 dotychczasowych + 5 nowych z `test_listings.py`; wynik obejmuje drzewo robocze, czyli dokładnie zmiany przeznaczone do commita) |
| migracja | nie dotyczy | brak zmian w `models.py` i `alembic/versions/` |
| frontend / e2e | nie dotyczy | brak zmian w tych serwisach |

## Zgodność z planem

| Sprawdzenie | Wynik | Uwagi |
|-------------|-------|-------|
| Pliki w wierszu #2 | OK | `main.py`, `tests/api/test_listings.py` (nowy), dokładnie jak w wierszu |
| Strażnik zakresu | OK | blok z planu dosłownie (`git diff --name-only 953e7de...HEAD`, z wyjątkiem TOOLING): pusto. Uzupełnienie o drzewo robocze (`git diff --name-only HEAD` + `git ls-files --others --exclude-standard`, te same `ALLOWED`/`TOOLING`): pusto |
| Budżet | 98 l. / 2 pliki vs 120 l. / 2 pliki | w budżecie |
| Komunikat commita | n/d | commit jeszcze nie istnieje; do użycia: `feat(backend): GET /listings/ z paginacją i limitem 500` |
| Przypadki testowe z planu | 5/5 | pusto → `[]`; jeden rekord → pola summary + `location` i brak `url`/`description_text` (asercja równości całego JSON, a rekord ma ustawione `url` i `description_text`); `skip=1&limit=1` → drugi rekord; `limit=501` → 422; `skip=-1` → 422 |
| Decyzje D-n | OK | D9: endpoint publiczny jak `GET /locations/`; D10: limit 500 tylko na `/listings/`, `/locations/` bez zmian; D11: komentarz o kolejności tras statycznych przed `/listings/{id}` |

Treść zgodna z sekcją "2. `GET /listings/` + testy": `skip: int = Query(0, ge=0)`, `limit: int = Query(100, ge=1, le=500)`, `response_model=List[schemas.ListingSummary]`, `select(models.Listing).options(selectinload(models.Listing.location)).order_by(models.Listing.listing_id)` (`main.py:189-203`). Helper `make_listing` tworzy Location/Building/Owner/Features + Listing zgodnie ze wzorcem z `test_delete_location_used_by_listing_returns_409`.

Uwaga z cp/1 (selectinload relacji `location`): spełniona. `main.py:198` ładuje `Listing.location` przez `selectinload`, a test `test_read_listings_returns_summary_with_location` faktycznie to weryfikuje: fixture `db` i `client` w `tests/conftest.py` używają osobnych sesji (osobne `async_sessionmaker` na wspólnym silniku), więc obiekt nie pochodzi z mapy tożsamości sesji testowej i bez `selectinload` serializacja `location` rzuciłaby `MissingGreenlet`. `order_by(listing_id)` po kluczu głównym daje deterministyczną paginację, co pokrywa test paginacji.

Kolejność i charakter zmiany: commit nie używa niczego z #3+ (brak filtrów, zależności `listing_filters`, `/count`), nie miesza `refactor` z `feat`, nie zmienia istniejących endpointów (jedyna zmiana w istniejącym kodzie to importy `Query` i `selectinload`). Kontrakt istniejący nienaruszony; nowy endpoint zgodny z kontraktem z sekcji 1. Bezpieczeństwo: brak `text()`/f-stringów w SQL, górny limit 500, schemat `ListingSummary` nie zawiera pól spoza kontraktu, brak sekretów, brak CORS.

## Znaleziska

Brak znalezisk.

## Rekomendacja dla commit-planner

Brak.
