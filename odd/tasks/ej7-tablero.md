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
- [ ] T1 `sql/ej7_cubo.sql` + `scripts/crear_indicadores.py`, build `indicadores.duckdb`
- [ ] T2 `sql/ej7_indicadores.sql` (>= 6 indicators) runs with `run_sql.py --db`
- [ ] T3 `scripts/crear_tablero.py`: Metabase setup, DuckDB connection, cards, dashboard via API
- [ ] T4 Screenshots of the dashboard in `docs/img/`
- [ ] T5 `docs/ej7_indicadores.md`: 10+ questions, justification, SQL docs, interpretation (7.1, 7.6 - 7.8)
- [ ] T6 README: how to generate the dashboard

## Evidence
(pending)

## Next step
T1
