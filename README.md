# 📌 DataOps demo (your first ELT process)

This project template is designed to practice elt process on AWS.

## Install Docker Engine on Ubuntu

First, build the images, then start the containers

```bash
docker compose up -d --build
```

Stop and remove containers, networks and remove named volumes declared in the "volumes" section of the Compose file and anonymous volumes attached to containers

```bash
docker compose down -v
```

## PostgreSQL interactive terminal

Access the warehouse

```bash
docker exec -it dbt_postgres psql -U dbt_user -d dbt_warehouse
```

List all databases on the PostgreSQL server

```bash
\l
```

Exit the PostgreSQL console

```bash
\q
```

## DBT (Data Build Tool)

Start dbt with dbt_project

```bash
docker compose run --rm dbt init dbt_project
```

Debug the configuration

```bash
docker compose run --rm dbt debug --project-dir dbt_project
```

Load static CSV files from your project’s seed-paths into your data warehouse as tables

```bash
docker compose run --rm dbt seed --project-dir dbt_project
```

Generate executable SQL from source files for models

```bash
docker compose run --rm dbt compile --project-dir dbt_project
```

Execute compiled SQL model files against the current target database

```bash
docker compose run --rm dbt run --project-dir dbt_project
```

## SQL queries

```bash
SELECT * FROM dev_squema.ecommerce_sales WHERE cast(order_date as date) > current_date LIMIT 10;
```

```bash
SELECT count(*) FROM dev_squema.ecommerce_sales WHERE cast(order_date as date) > current_date;
```

```bash
SELECT transaction_id, count(*) FROM dev_schema.ecommerce_sales group by transaction_id having count(*) > 1;
```
