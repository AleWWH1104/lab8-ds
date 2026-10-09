# Ej. 8 - Incorporacion de 2025

## Objective
Make the pipeline reproducible for yellow and green taxis of 2024, 2025 and 2026 (lab spec 8.1 - 8.7).

## Scope
Download script default years, data download and verification, table regeneration, rerun of the Ej. 3-5 SQL, documentation in `docs/ej8_incorporacion.md`. Dashboard update (8.4 - 8.6) is covered after Ej. 7.

## Constraints
- Route: direct inline for small edits, no SDD.
- TDD: not configured for this repo (scripts + SQL); functional checks only.
- Data never committed. Conventional commits, no AI attribution.
- Env: Colima (`colima start --cpu 4 --memory 6 --disk 60`), docker context `colima`.

## Tasks
- [x] T1 Add 2025 to `ANIOS_POR_DEFECTO` in `scripts/download_data.py` and docstring (8.1) - commit 550c0bd
- [x] T2 Download 2024-2026, run `--verificar`, rerun to prove nothing is re-downloaded (8.2) - route: inline
- [x] T3 Regenerate `data/processed/taxis.duckdb` and rerun Ej. 3-5 SQL on three years (8.3) - commit e5f1402
- [x] T4 Write `docs/ej8_incorporacion.md` and update README / division_trabajo (8.5-8.7)
- [ ] T5 Update dashboard with three years (8.4) - blocked on Ej. 7

## Evidence
- Run 1: 64 downloaded, 0 failed. Run 2: 0 downloaded, 64 already existed. `--verificar`: 64 complete, 0 missing.
- `crear_tabla.py`: 121,184,384 rows, 3,364 MiB. Ej. 3-5 SQL rerun with exit 0 and no error text in outputs.
- Metadata row counts equal read row counts in all 6 groups.

## Next step
Ej. 7 dashboard, then T5.
