# Ej. 7 - Indicadores y tablero

## Objective
At least 10 analysis questions and 6 indicators, each backed by documented SQL on DuckDB, visualized in Metabase and interpreted, grouped in one dashboard (lab spec 7.1 - 7.8).

## Design decision
Metabase queries a small pre-aggregated cube (`data/processed/indicadores.duckdb`) instead of `viajes_limpios`: the view uses `DISTINCT ON` over 121M rows (6-22 s per query) and a dashboard fires all cards in parallel inside a 6 GB VM. The cube is rebuilt from `taxis.duckdb` by `scripts/crear_indicadores.py`, so adding a year is one command.

## Route
Direct inline. Reason: all files share one design context; a cold writer would re-derive it. Trigger evidence: 4+ new files, kept inline on purpose.

## Constraints
- Data never committed. Conventional commits, no AI attribution. TDD not configured; functional checks only.
- Metabase credentials are local-dev only, documented in the script.
- Indicator SQL lives in `sql/ej7_indicadores.sql` and is the single source for the Metabase cards.

## Tasks
- [x] T1 `sql/ej7_cubo.sql` + `scripts/crear_indicadores.py`, build `indicadores.duckdb`
- [x] T2 `sql/ej7_indicadores.sql` (>= 6 indicators) runs with `run_sql.py --db`
- [x] T3 `scripts/crear_tablero.py`: Metabase setup, DuckDB connection, cards, dashboard via API
- [x] T4 Screenshots of the dashboard in `docs/img/`
- [x] T5 `docs/ej7_indicadores.md`: 10+ questions, justification, SQL docs, interpretation (7.1, 7.6 - 7.8)
- [x] T6 README: how to generate the dashboard

## Evidence
- Cube: 46,828 + 1,538 rows, 2.8 MiB, built in 42 s (commit e7a3581).
- Metabase: 10 cards created and executed through the API, all `completed` with expected row counts (commit 9919968).
- T4: first attempt to enable public sharing was denied by the permission classifier and not worked around; user then authorized it explicitly. Screenshot via headless Chrome, public link deleted and `enable-public-sharing` restored to false afterwards (link now returns HTTP 400).
- Layout fix after review of the first capture: 7.3 legend and 0-100 axis, five rows of two cards.

## Next step
Ej. 9 discussion, then final README check and clean-clone test.
