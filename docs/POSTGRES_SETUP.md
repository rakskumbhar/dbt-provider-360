# PostgreSQL Setup

This project uses the `dbt-postgres` adapter. The example profile assumes a database called `provider_360_dev`, a dbt service user, and dbt-created schemas for each medallion layer.

## 1. Install dbt for PostgreSQL

```bash
python -m venv .venv
source .venv/bin/activate
pip install dbt-postgres
dbt --version
```

## 2. Create Database and Role

Run as a PostgreSQL admin:

```sql
create database provider_360_dev;

create user provider_360_user with password 'provider_360_password';
grant connect on database provider_360_dev to provider_360_user;
```

Connect to `provider_360_dev` and create schemas:

```sql
create schema if not exists analytics_raw_seed;
create schema if not exists analytics_bronze;
create schema if not exists analytics_silver;
create schema if not exists analytics_gold;
create schema if not exists analytics_audit;
create schema if not exists snapshots;

grant usage, create on schema analytics_raw_seed to provider_360_user;
grant usage, create on schema analytics_bronze to provider_360_user;
grant usage, create on schema analytics_silver to provider_360_user;
grant usage, create on schema analytics_gold to provider_360_user;
grant usage, create on schema analytics_audit to provider_360_user;
grant usage, create on schema snapshots to provider_360_user;
```

In non-prod, dbt prefixes custom schemas with the base profile schema. Because the example profile uses `schema: analytics`, the generated schemas are:

- `analytics_raw_seed`
- `analytics_bronze`
- `analytics_silver`
- `analytics_gold`
- `analytics_audit`

In prod, the custom schema names are used directly:

- `raw_seed`
- `bronze`
- `silver`
- `gold`
- `audit`

## 3. Configure dbt Profile

```bash
mkdir -p ~/.dbt
cp profiles.yml.example ~/.dbt/profiles.yml
```

Set environment variables:

```bash
export DBT_POSTGRES_HOST=localhost
export DBT_POSTGRES_PORT=5432
export DBT_POSTGRES_USER=provider_360_user
export DBT_POSTGRES_PASSWORD=provider_360_password
export DBT_POSTGRES_DATABASE=provider_360_dev
```

## 4. Validate and Run

```bash
dbt deps
dbt parse
dbt seed
dbt run --selector provider360_bronze_to_gold
dbt test --selector provider360_quality_gate
dbt snapshot --select provider_snapshot
dbt run --select tag:audit
```

## 5. Optional Email Delivery

The project can publish dbt run status using PostgreSQL `pg_notify`. A separate listener must send the email.

Example listener query:

```sql
listen provider_360_dbt_alerts;
```

When enabled, the macro sends a JSON payload with:

- `subject`
- `body`
- `recipients`

This keeps dbt focused on transformation and lets enterprise infrastructure own email delivery, retries, auditability, and security.

