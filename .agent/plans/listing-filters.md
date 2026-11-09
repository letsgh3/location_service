# Plan: filtrowanie ogłoszeń (zakresy cen i metrażu, pokoje, miasto/dzielnica z podpowiedziami, licznik, reset)

Brief: treść zadania (wymagania podane wprost; w `docs/*.md` brak sekcji o filtrach). Baza: branch `Location_description`, HEAD `953e7de` (drzewo czyste). Bramki na starcie:
`pytest -q` (backend) = 26 passed, `npm run build` = OK, e2e `pytest -q` = FAIL (brak `services/e2e/venv`, nie uruchomiono).

**Blokada #0 (e2e):** bramka e2e nie działa, bo `services/e2e/venv` nie istnieje. Commity #13–#15 są zablokowane do czasu `./install.sh --with-e2e` uruchomionego przez użytkownika. Commity #1–#12 i #16 można wykonać niezależnie.

**Stan wyjściowy, który kształtuje plan:**
- Wszystkie pola z briefu istnieją: `Listing.price_total_zl`, `price_sqm_zl`, `area` (Float), `rooms` (Integer), `Location.city`, `city_district` (String). **Bez zmian modelu i bez migracji**, `docs/schema.md` nietknięty.
- `GET /listings/` **nie istnieje** (plan `.agent/plans/listings.md` nie został wykonany), nie ma też `POST /listings/` ani widoku ogłoszeń. Plan zawiera więc najpierw minimalną listę (kontrakt z `listings.md`), potem filtry. Patrz D2.
- FastAPI 0.104.1: brak modeli parametrów query (`Annotated[Model, Query()]` jest od 0.115), więc filtry to zależność-funkcja z `Query(...)`.

**Zakres:** `services/backend/main.py`, `services/backend/sql_app/schemas.py`, `services/backend/tests/api/test_listings.py` (nowy), `services/frontend/src/api.js`, `services/frontend/src/App.jsx`, `services/frontend/src/ListingsView.jsx` (nowy), `services/frontend/src/ListingFilters.jsx` (nowy), `services/e2e/tests/conftest.py`, `services/e2e/tests/test_listing_filters.py` (nowy), `README.md`, `services/backend/README.md`, `services/backend/CLAUDE.md`, `services/frontend/README.md`, `services/e2e/README.md`
**Poza zakresem:** `services/backend/sql_app/models.py`, `services/backend/alembic/`, `docs/` (w tym generowany `docs/schema.md`), `services/backend/tests/conftest.py`, `services/frontend/src/App.css`, `package.json`/`package-lock.json`, `pyproject.toml`, `requirements.txt`, `.github/`, `CLAUDE.md` (root), `.agent/` (poza tym plikiem)

## Tabela commitów

| # | Commit (conventional) | Serwis | Pliki | Weryfikacja | Budżet |
|---|-----------------------|--------|-------|-------------|--------|
| 1 | `feat(backend): schematy LocationSummary, ListingSummary i ListingCount` | backend | `sql_app/schemas.py` | `pytest -q` (wyjątek: czysto schematowa zmiana, import + regresja) | 30 l. / 1 plik |
| 2 | `feat(backend): GET /listings/ z paginacją i limitem 500` | backend | `main.py`, `tests/api/test_listings.py` (nowy) | `pytest -q` | 120 l. / 2 pliki |
| 3 | `feat(backend): filtry zakresów ceny, ceny za m² i metrażu w GET /listings/` | backend | `main.py`, `tests/api/test_listings.py` | `pytest -q` | 140 l. / 2 pliki |
| 4 | `feat(backend): wielokrotny filtr rooms w GET /listings/` | backend | `main.py`, `tests/api/test_listings.py` | `pytest -q` | 60 l. / 2 pliki |
| 5 | `feat(backend): filtry city i city_district w GET /listings/` | backend | `main.py`, `tests/api/test_listings.py` | `pytest -q` | 70 l. / 2 pliki |
| 6 | `feat(backend): GET /listings/count z tymi samymi filtrami` | backend | `main.py`, `tests/api/test_listings.py` | `pytest -q` | 80 l. / 2 pliki |
| 7 | `feat(backend): podpowiedzi GET /listings/cities i /listings/districts` | backend | `main.py`, `tests/api/test_listings.py` | `pytest -q` | 150 l. / 2 pliki |
| 8 | `feat(frontend): klient API ogłoszeń, licznika i podpowiedzi` | frontend | `src/api.js` | `npm run build` (wyjątek: brak runnera testów; pokrycie w #13–#15) | 40 l. / 1 plik |
| 9 | `feat(frontend): widok ogłoszeń przełączany w App` | frontend | `src/ListingsView.jsx` (nowy), `src/App.jsx` | `npm run build` + ręcznie `npm run dev` (wyjątek: brak runnera; pusta baza dev, sprawdzalne tylko przełączanie widoku i stan „Brak ogłoszeń”) | 140 l. / 2 pliki |
| 10 | `feat(frontend): panel filtrów zakresów, pokoi i miasta z resetem` | frontend | `src/ListingFilters.jsx` (nowy), `src/ListingsView.jsx` | `npm run build` + ręcznie `npm run dev` (wyjątek: brak runnera; w DevTools/Network query string, np. `rooms=2&rooms=3`, komunikat min > max, reset czyści pola) | 170 l. / 2 pliki |
| 11 | `feat(frontend): dynamiczny licznik wyników filtrów` | frontend | `src/ListingsView.jsx` | `npm run build` + ręcznie `npm run dev` (wyjątek: brak runnera; przy pustej bazie licznik „Znaleziono: 0” i zapytanie `/api/listings/count` w Network) | 40 l. / 1 plik |
| 12 | `feat(frontend): autouzupełnianie miasta i dzielnicy w filtrach` | frontend | `src/ListingFilters.jsx` | `npm run build` + ręcznie `npm run dev` (wyjątek: brak runnera; przy pustej bazie sprawdzalne tylko zapytania `/api/listings/cities?prefix=` w Network) | 80 l. / 1 plik |
| 13 | `test(e2e): fixture listing_factory i test widoku ogłoszeń` | e2e | `tests/conftest.py`, `tests/test_listing_filters.py` (nowy) | `pytest -q` (blokada #0) | 90 l. / 2 pliki |
| 14 | `test(e2e): filtry zakresów, pokoi, walidacja i reset ogłoszeń` | e2e | `tests/test_listing_filters.py` | `pytest -q` (blokada #0) | 130 l. / 1 plik |
| 15 | `test(e2e): licznik wyników i autouzupełnianie miasta i dzielnicy` | e2e | `tests/test_listing_filters.py` | `pytest -q` (blokada #0) | 80 l. / 1 plik |
| 16 | `docs: filtry ogłoszeń w README i CLAUDE.md serwisów` | docs | `README.md`, `services/backend/README.md`, `services/backend/CLAUDE.md`, `services/frontend/README.md`, `services/e2e/README.md` | `grep -n "endpoints yet" services/backend/CLAUDE.md services/backend/README.md` zwraca pusto; `grep -c "/listings/count" services/backend/README.md` ≥ 1; przegląd | 60 l. / 5 plików |

Kolejność: kontrakt → backend → frontend → e2e → docs. Każdy krok kończy się zieloną bramką swojego serwisu,
potem `git diff --stat` i tag `cp/<n>`.

## Co dokładnie wchodzi w każdy krok

### 1. Kontrakt (STOP po tym kroku, do akceptacji)

```python
class LocationSummary(BaseModel):
    city: Optional[str] = None
    city_district: Optional[str] = None
    model_config = ConfigDict(from_attributes=True)

class ListingSummary(BaseModel):
    listing_id: int
    rooms: Optional[int] = None
    area: Optional[float] = None
    price_total_zl: Optional[float] = None
    price_sqm_zl: Optional[float] = None
    location: LocationSummary
    model_config = ConfigDict(from_attributes=True)

class ListingCount(BaseModel):
    total: int
```

Kontrakt HTTP (implementowany w #2–#7), wszystkie parametry filtrów opcjonalne:

- `GET /listings/?skip&limit&price_total_min&price_total_max&price_sqm_min&price_sqm_max&area_min&area_max&rooms=2&rooms=3&city&city_district` → `List[ListingSummary]`
- `GET /listings/count?<te same filtry, bez skip/limit>` → `ListingCount`
- `GET /listings/cities?prefix&limit` → `List[str]`; `GET /listings/districts?city=<wymagane>&prefix&limit` → `List[str]`
- 422: min > max w dowolnej parze, wartość ujemna, `rooms` < 1 lub nie-int, `limit` poza zakresem, brak `city` w `/districts`.

Zagnieżdżone `location` jak w `ListingDetail` i w `listings.md` (D1 tamtego planu), `from_attributes=True` mapuje relację bez `computed_field`. Licznik jako osobny endpoint, żeby `GET /listings/` zwracał gołą listę jak `GET /locations/` (D1).

### 2. `GET /listings/` + testy

- Publiczny jak `GET /locations/`. `skip: int = Query(0, ge=0)`, `limit: int = Query(100, ge=1, le=500)`, `response_model=List[schemas.ListingSummary]`.
- `select(models.Listing).options(selectinload(models.Listing.location)).order_by(models.Listing.listing_id)`. Bez `selectinload` serializacja `listing.location` w sesji async rzuca `MissingGreenlet`; `order_by` daje deterministyczną paginację.
- `tests/api/test_listings.py`: helper `make_listing(db, city=..., city_district=..., **pola)` tworzący Location/Building/Owner/Features + Listing, wzorzec z `test_delete_location_used_by_listing_returns_409` (4 FK non-null). Ten jeden plik obsłuży też #3–#7.
- Przypadki: pusto → `[]`; jeden rekord → pola summary + `location.city`, brak `url`/`description_text`; `skip=1&limit=1` → drugi rekord; `limit=501` → 422; `skip=-1` → 422.

### 3. Filtry zakresów

- Zależność `listing_filters(...)` w `main.py` zwracająca dataclass `ListingFilters`; parametry `Optional[float] = Query(None, ge=0)`. Para min > max → `HTTPException(422, detail="<pole>_min must not be greater than <pole>_max")`. Detal jako string, bo `request()` w `api.js` pokazuje tylko `detail` typu string (D7).
- Helper `apply_listing_filters(stmt, f)` dokłada `where` z granicami włącznie (`>=`, `<=`); #6 użyje tego samego helpera dla count.
- Przypadki: bez parametrów wynik identyczny jak w #2 (zgodność wsteczna); min, max, min==max (granice włącznie) dla każdej z trzech par; kombinacja dwóch filtrów; rekord z `NULL` w filtrowanym polu wypada, gdy filtr jest aktywny; min > max → 422 (parametryzacja po 3 parach); wartość ujemna → 422.

### 4. `rooms` jako powtarzalny parametr

- `rooms: Optional[List[int]] = Query(None)`, warunek `Listing.rooms.in_(...)`. Wartość < 1 walidowana ręcznie w zależności → 422 (w FastAPI 0.104 `ge` na liście nie działa per element).
- Przypadki: `rooms=2` → tylko 2; `rooms=2&rooms=3` → 2 i 3, bez 1 i 4; `rooms=0` → 422; `rooms=abc` → 422; `rooms` łączy się z filtrem ceny (AND).

### 5. Filtry `city` / `city_district`

- `.join(models.Listing.location)` w `apply_listing_filters` (inner join jest bezpieczny, bo FK jest non-null), dopasowanie dokładne `==` (D5); `city_district` działa też bez `city`.
- Przypadki: dokładne miasto; miasto + dzielnica; nieistniejące miasto → `[]`; join nie dubluje wierszy i nie psuje `selectinload`.

### 6. `GET /listings/count`

- `select(func.count(models.Listing.listing_id)).select_from(models.Listing)` + ten sam `apply_listing_filters` i ta sama zależność `listing_filters` (te same 422). `response_model=schemas.ListingCount`.
- Trasę deklaruj przed ewentualnym przyszłym `/listings/{listing_id}`, bo inaczej `count` trafi do parametru int i skończy się 422.
- Przypadki: pusto → `{"total": 0}`; bez filtrów = liczba wszystkich; z filtrami `total` == długość listy przy `limit=500`; `total` ignoruje paginację (np. 3 rekordy, a lista z `limit=1` ma 1 element); min > max → 422.

### 7. Podpowiedzi miast i dzielnic

- `GET /listings/cities`: `select(Location.city).join(Listing).where(city IS NOT NULL, city != '', city.ilike(prefix_esc + '%', escape='\\')).distinct().order_by(Location.city).limit(limit)`; `prefix: str = Query("", max_length=100)`, `limit: int = Query(10, ge=1, le=50)`. Znaki `%`, `_` i `\` w prefiksie escapujemy, żeby nie działały jak wildcard.
- `GET /listings/districts`: jak wyżej po `city_district`, z `city: str = Query(..., min_length=1)` i warunkiem `Location.city == city`.
- Pułapka: SQLite `lower()`/`LIKE` porównują bez rozróżniania wielkości liter tylko znaki ASCII (`kra` → `Kraków` działa, `łód` → `Łódź` nie). Patrz D4.
- Przypadki: pusto → `[]`; duplikaty zwijane (dwa ogłoszenia w tym samym mieście → jedno); prefiks bez rozróżniania wielkości liter (ASCII); `%` nie działa jak wildcard; lokalizacja bez ogłoszeń nie jest podpowiadana (D3); `NULL` i `''` pominięte; `limit`; dzielnice tylko z podanego miasta; brak `city` → 422; `limit=51` → 422.

### 8. Klient API

- Czysta, eksportowana funkcja `buildListingQuery(filters)`: `URLSearchParams`, pomija `''`/`null`, `rooms` dodaje przez `append` (powtarzalny parametr). `listListings(filters, opts)`, `countListings(filters, opts)`, `suggestCities(prefix, opts)`, `suggestDistricts(city, prefix, opts)`, wszystko przez `request()`. `opts` przekazuje `signal` (AbortController) do `fetch`.

### 9. Widok ogłoszeń

- `ListingsView.jsx`: nagłówek `h1` „Ogłoszenia”, tabela Miasto / Dzielnica / Pokoje / Metraż / Cena / Cena za m² (`toLocaleString('pl-PL')`), stany ładowania, błędu i pustej listy. Tylko istniejące klasy (`container`, `page-header`, `card`, `table-wrap`, `alert`, `empty-state`, `loading-cell`, `table-foot`), bez zmian w `App.css`.
- `App.jsx`: stan `view` i dwa przyciski „Lokalizacje”/„Ogłoszenia” (`btn btn-ghost`). Domyślny widok to lokalizacje, bo fixture e2e `logged_in_page` czeka na nagłówek „Lokalizacje”. `Locations` zostaje w `App.jsx`.

### 10. Panel filtrów + reset

- `ListingFilters.jsx`, komponent kontrolowany `{ value, onChange, onReset }`: pola `Field` „Miasto”, „Dzielnica”, „Cena od/do”, „Cena za m² od/do”, „Metraż od/do” (`type="number"`, `min=0`; `Field` przepuszcza `type` przez spread), `fieldset` z `legend` „Liczba pokoi” i checkboxami 1–5, przycisk „Wyczyść filtry”.
- Walidacja po stronie klienta: min > max → hint „Wartość „od” nie może być większa niż „do”.” i brak zapytania. Backend i tak zwraca 422.
- `ListingsView`: stan filtrów, debounce 300 ms, `AbortController`, żeby wolna odpowiedź nie nadpisała nowszej. Reset przywraca `EMPTY_FILTERS` i od razu odświeża listę.

### 11. Licznik

- Równoległe `countListings` z tymi samymi filtrami (wspólny debounce i abort). Tekst „Znaleziono: N” w elemencie z `aria-live="polite"`, bez `role="status"`, bo ta rola jest już zajęta przez toast i e2e używa `get_by_role("status")`. Stopka: „Wyświetlono X z N”, gdzie X to wiersze na stronie (limit 100).

### 12. Autouzupełnianie

- `<datalist>` dla „Miasto” i „Dzielnica” (natywne, dostępne, bez zależności); atrybut `list` przez spread w `Field`. Podpowiedzi pobierane z debounce 250 ms; dzielnice tylko przy niepustym mieście; zmiana miasta czyści dzielnicę.

### 13. Fixture seedująca + test widoku

- Ogłoszeń nie da się założyć przez API (brak `POST /listings/`), więc fixture `listing_factory` zapisuje rekordy przez stdlib `sqlite3` do tymczasowej bazy e2e (D8). To nie jest import kodu backendu, więc reguła „serwisy nie importują się nawzajem” jest zachowana. Ścieżka bazy wydzielona do fixture sesyjnej, z której korzysta `app_base_url`. Przy `E2E_BASE_URL` fixture robi `pytest.skip`.
- Test: zaseedowane ogłoszenie w unikalnym mieście (`E2E-<uuid>`) widoczne po przełączeniu na „Ogłoszenia”.

### 14. E2E filtrów

- Każdy test zaczyna od wpisania swojego unikalnego miasta w filtr „Miasto” (baza współdzielona w sesji). Lokatory: `get_by_label("Cena od")`, `get_by_role("group", name="Liczba pokoi").get_by_label("2")`, `get_by_role("button", name="Wyczyść filtry")`.
- Przypadki: zakres ceny; cena za m²; metraż; pokoje 2+3; min > max pokazuje hint; reset czyści pola i przywraca wiersze.

### 15. E2E licznika i podpowiedzi

- Licznik: 3 ogłoszenia w mieście → „Znaleziono: 3”, po filtrze ceny → „Znaleziono: 1”.
- Podpowiedzi: `datalist` nie jest dostępny przez role, więc sprawdzenie idzie przez `page.locator("#<id datalisty> option")` z wartością miasta i dzielnicy. To jedyny selektor CSS i trzeba go skomentować w teście (konwencja e2e dopuszcza go, gdy nie ma alternatywy).

### 16. Dokumentacja

- `services/backend/CLAUDE.md` i `services/backend/README.md`: zdania „Listing … no (API) endpoints yet” są po #2 nieprawdziwe. Do README dochodzą wiersze tabeli API dla `/listings/`, `/listings/count`, `/listings/cities`, `/listings/districts` oraz przykład `curl` z `rooms=2&rooms=3`.
- `README.md` (root): kolumna Status dla backendu, frontendu i e2e. `services/frontend/README.md`: sekcja Structure (`ListingsView.jsx`, `ListingFilters.jsx`). `services/e2e/README.md`: Structure (`test_listing_filters.py`) i wyjątek od seedowania przez API (D8).

## Decyzje do zatwierdzenia przed kodem

| # | Decyzja | Wybór w planie | Alternatywa |
|---|---------|----------------|-------------|
| D1 | Dostarczenie licznika | osobny `GET /listings/count` → `{"total": N}` z tą samą zależnością filtrów; lista zostaje gołą tablicą jak `/locations/`, więc kontrakt się nie łamie | koperta `{items, total}` (łamie kształt listy) albo nagłówek `X-Total-Count` (niewidoczny w `response_model`/OpenAPI, `request()` czyta tylko body) |
| D2 | Brak `GET /listings/` | **Zatwierdzone (2026-11-09): ten plan zastępuje `listings.md`.** Plan zawiera minimalną listę i widok (#1, #2, #9), więc `listings.md` staje się nieaktualny | najpierw wykonać `listings.md`, potem usunąć stąd #2 i #9 i dopasować #1 (dodać `city_district`, `price_sqm_zl`, `ListingCount`) |
| D3 | Źródło podpowiedzi | tylko miasta/dzielnice, które mają ogłoszenia (join z `listing`), żeby podpowiedź nie prowadziła do pustego wyniku | wszystkie wpisy z tabeli `location` |
| D4 | Wielkość liter w prefiksie | `ilike` (w SQLite tylko ASCII, „łód” nie znajdzie „Łódź”) | filtrowanie `casefold()` w Pythonie na liście distinct (pełny Unicode, kosztem pobrania wszystkich wartości) |
| D5 | Dopasowanie `city`/`city_district` w liście | dokładne `==` (wartości pochodzą z podpowiedzi) | `ilike` prefiksowe lub bez rozróżniania wielkości liter |
| D6 | Wybór pokoi | checkboxy 1–5, dokładne wartości | opcja „5+” (wymaga dodatkowego `rooms_min` w API) |
| D7 | Format 422 dla min > max | `HTTPException(422, detail=str)`, po angielsku jak istniejące detale; frontend i tak waliduje wcześniej | `RequestValidationError` z listą błędów jak natywne 422 FastAPI |
| D8 | Seedowanie ogłoszeń w e2e | `sqlite3` bezpośrednio do tymczasowej bazy e2e, skip przy `E2E_BASE_URL` (świadome odstępstwo od konwencji „seed przez `api`”) | najpierw `POST /listings/` (+ Building/Owner/Features), osobny PR |
| D9 | Autoryzacja nowych GET | publiczne jak `GET /locations/` | wymagany token |
| D10 | Limit 500 | tylko `/listings/`; `/locations/` bez zmian | ujednolicić, osobny wpis |
| D11 | Ścieżki `count`/`cities`/`districts` | pod `/listings/`, deklarowane przed każdą przyszłą trasą `/listings/{id}` | osobny prefiks `/suggestions/...` |
| D12 | Stan filtrów w UI | lokalny stan + debounce, bez synchronizacji z URL; domyślny widok „Lokalizacje” | filtry w query stringu adresu (deep link) |

## Rozważone i odrzucone (świadomie poza tym planem)

- **`build(frontend): Vitest i test jednostkowy buildListingQuery`** (opcjonalny, osobny commit/PR): `buildListingQuery` z #8 to najbardziej podatna na błędy logika frontendu (powtarzalne `rooms`, pomijanie pustych pól), a e2e pokrywa ją tylko pośrednio i wolno. Wymaga zmian w `package.json` i `package-lock.json` oraz `npm install`, czyli jest poza zakresem tego planu. #8 celowo wydziela czystą funkcję, żeby ten commit był tani: ok. 40 l. / 3 pliki, weryfikacja `npm test && npm run build`.
- **`feat(backend): POST /listings/`**: umożliwiłby seedowanie e2e przez `api`, ale wymaga też tworzenia Building/Owner/Features. To osobna funkcja, osobny PR (D8).
- **`perf(backend): indeksy na listing.price_total_zl, price_sqm_zl, area, rooms`**: zmiana modelu + migracja Alembic + regeneracja `docs/schema.md`, a brief jej nie wymaga przy obecnym wolumenie. Osobny wpis.
- **`feat(frontend): paginacja widoku ogłoszeń`**: licznik pokazuje pełne N, tabela pierwsze 100. Brief nie wymaga stronicowania UI, osobny wpis.
- **`refactor(frontend): wydziel Locations.jsx z App.jsx`**: czysty move ok. 350 linii, ponad budżet; przełącznik widoku wystarcza bez tego.
- **Skrypt seedujący bazę dev (`scripts/seed_listings.py`)**: baza dev ma 0 ogłoszeń, więc ręczna kontrola #9–#12 jest częściowa. Osobny wpis.
- **Limit w `GET /locations/`**: zmiana istniejącego zachowania (D10).

## Strażnik zakresu

```bash
ALLOWED='^(README\.md|services/backend/(main\.py|sql_app/schemas\.py|tests/api/test_listings\.py|README\.md|CLAUDE\.md)|services/frontend/(src/(api\.js|App\.jsx|ListingsView\.jsx|ListingFilters\.jsx)|README\.md)|services/e2e/(tests/(conftest\.py|test_listing_filters\.py)|README\.md))$'
# Narzędzia agentów commitowane osobno jako chore(agents), poza tabelą planu (zatwierdzone 2026-11-09):
TOOLING='^(CLAUDE\.md|\.claude/((agents|skills|hooks)/.*|settings\.json)|\.agent/(plans/listing-filters\.md|reviews/listing-filters-.*\.md))$'
OUT=$(git diff --name-only 953e7de...HEAD | grep -vE "$ALLOWED" | grep -vE "$TOOLING")
[ -z "$OUT" ] || { echo "Pliki poza zakresem:"; echo "$OUT"; exit 1; }
```

## Protokół wykonania

```text
Wykonaj commit #N z .agent/plans/listing-filters.md. Tylko ten commit.
1. komenda weryfikacji z tabeli,
2. git diff --stat, strażnik zakresu,
2a. przegląd agentem code-reviewer (zmiany w drzewie roboczym, plan + numer commita); REQUEST_CHANGES → popraw i powtórz 1–2a,
3. zielone, w budżecie i APPROVE → commit z komunikatem z planu, git tag cp/N,
4. stop, czekaj na "dalej".
Odchylenie (nowy plik, >1.5× budżetu) → zgłoś, nie wykonuj.
Po #1 STOP do akceptacji kontraktu. #13–#15 dopiero po usunięciu blokady #0 (services/e2e/venv).
```
