# Intent: sales-insights monthly revenue mart

artifacts:

- dbt:model.stg_orders
- dbt:model.mart_sales
- dlt:pipeline.orders
- dlt:table.orders

## Business context

Finance needs a monthly revenue rollup from the commerce platform's order feed. The number they reconcile against is the platform's own "fulfilled orders" total, so the mart must count every order that reached a fulfilled state — and only those.

## Source

The `orders` dlt pipeline lands the commerce platform's order feed into the domain Fabric lakehouse at `src_orders.orders`, one row per order, refreshed nightly. The platform's order lifecycle carries five statuses: `pending` (placed, not yet fulfilled), `shipped`, `delivered`, `returned`, and `cancelled`.

## Acceptance criteria

1. `mart_sales` carries one row per calendar month with `total_revenue` and `order_count`.
2. `total_revenue` counts **fulfilled orders only** — statuses `shipped`, `delivered`, and `returned` (returns net out upstream, so they stay in revenue).
3. **Pending and cancelled orders are excluded from revenue.** A `pending` order counts only once it fulfils and its status flips on a later feed; a `cancelled` order never counts.
4. Monthly totals must reconcile with the commerce platform's fulfilled-order report within rounding.
5. **Freshness SLA.** The `orders` feed is refreshed by a nightly scheduled load. The warehouse is considered up to date when the most recent successful load landed on the current calendar day and `src_orders.orders` carries order rows through the prior calendar day. Staleness beyond one missed nightly load is an incident.

## Non-goals

- No per-product or per-customer breakdowns in this intent.
- No pipeline-of-record for pending demand: bookings/backlog reporting is a separate intent if Finance ever asks for it.
- No currency conversion; the feed is single-currency EUR.
