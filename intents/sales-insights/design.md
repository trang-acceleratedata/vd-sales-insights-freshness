# Design: sales-insights monthly revenue mart

artifacts:

- dbt:model.stg_orders
- dbt:model.mart_sales
- dlt:pipeline.orders
- dlt:table.orders

## Architecture

Two-layer dbt project over the dlt-landed bronze table, materialized on Microsoft Fabric (dbt-fabricspark, Livy):

| Layer | Model | Materialization | Purpose |
| --- | --- | --- | --- |
| staging | `stg_orders` | view | Rename/cast the raw feed; admit only revenue-bearing (fulfilled) statuses |
| marts | `mart_sales` | table | Monthly `total_revenue` + `order_count` rollup with audit columns |

## Pipeline inventory

| Pipeline | Destination | Tables |
| --- | --- | --- |
| `orders` (dlt) | domain Fabric lakehouse, schema `src_orders` | `orders`, plus dlt audit tables |

## Semantic definitions

- **`total_revenue`** — sum of `amount` over orders whose status is fulfilled (`shipped`, `delivered`, `returned`) in the month of `order_date`. Pending and cancelled orders are excluded by the intent's acceptance rule; a pending order joins revenue in the month of its order date once a later feed flips its status to a fulfilled one.
- **`order_count`** — count of the same fulfilled set, never of all feed rows.

## Contracts and tests

- Source declaration on `src_orders.orders` with `not_null`/`unique` on `order_id` and an `accepted_values` guard on `order_status` pinned to the platform's full five-status lifecycle vocabulary (`pending`, `shipped`, `delivered`, `returned`, `cancelled`).
- `mart_sales` declares `not_null`/`unique` on `sales_month` and `not_null` on measures and the three audit columns (`_loaded_at`, `_dbt_invocation_id`, `_git_sha`).

## Freshness

The `orders` pipeline runs on a nightly schedule; each successful run writes a row to `src_orders.audit_runs` (`status`, `finished_at`, `git_sha`) and to `src_orders.audit_table_loads` (`rows_loaded`) — surfaced through the Fabric Monitor hub / job-instance API and Eventhouse KQL job logs. The intent's freshness SLA (intent AC5) is a *rule about the expected cadence* — it does not by itself tell you whether the warehouse is current at any given moment. Answering "is the data up to date right now" requires reading the runtime evidence (did last night's load succeed) and the live warehouse state (the newest `order_date` present), not the rule alone.

## Ledger

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-01-12 | Intent approved: monthly revenue rollup; fulfilled statuses `shipped`/`delivered`/`returned` count, **`pending` and `cancelled` are excluded from revenue** | Matches the commerce platform's fulfilled-order report; pending demand is bookings, not revenue |
| 2026-01-14 | Design approved: two-layer project, the revenue filter lives in `stg_orders`, `accepted_values` guard pins the full five-status lifecycle vocabulary so an upstream vocabulary change surfaces as a failing test | Guard chosen over silent pass-through |
| 2026-01-15 | Build shipped: `stg_orders` + `mart_sales` materialized to the domain Fabric lakehouse; nightly run scheduled | First production run green |
| 2026-01-16 | Freshness SLA recorded: nightly cadence, up to date = a successful load today with rows through yesterday; audit tables carry the per-run evidence | Freshness is a runtime fact, so the rule points at the audit evidence rather than asserting currency itself |
