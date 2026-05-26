#!/usr/bin/env bash
set -euo pipefail

dbt deps
dbt seed --select raw_provider
dbt run --select tag:provider360
dbt test --select tag:provider360
dbt snapshot --select provider_snapshot
dbt run --select tag:audit
