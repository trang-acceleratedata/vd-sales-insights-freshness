"""Orders dlt pipeline for the sales-insights product (Fabric destination).

Lands the commerce platform's nightly order feed into the domain Fabric
lakehouse at ``src_orders.orders`` and writes the dlt audit tables
(``audit_runs``, ``audit_table_loads``) alongside it. Runs nightly via the
platform scheduler; the eval seeds its output and audit rows directly, so this
module is provenance/reference for the operate scenario, not executed by setup.
"""

import dlt


@dlt.resource(name="orders", write_disposition="merge", primary_key="order_id")
def orders(feed_rows):
    """Yield order rows exactly as the commerce platform emits them.

    Columns: order_id, customer_id, order_date, order_status, amount.
    ``order_status`` is the platform's fulfilment vocabulary; the dbt source
    contract pins the accepted values.
    """
    yield from feed_rows


def run(feed_rows):
    pipeline = dlt.pipeline(
        pipeline_name="orders",
        destination="filesystem",  # Fabric OneLake Delta staging via the studio runtime
        dataset_name="src_orders",
    )
    return pipeline.run(orders(feed_rows))
