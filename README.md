# global-sales-intelligence-hub
An end-to-end sales analytics project: a PostgreSQL data model, SQL-driven KPI and cohort/churn analysis, and a Power BI dashboard — built to replace a manual, multi-sheet sales reporting process with a single automated source of truth.
Global Sales Intelligence Hub

An end-to-end sales analytics project: a PostgreSQL data model, SQL-driven KPI and cohort/churn analysis, and a Power BI dashboard — built to replace a manual, multi-sheet sales reporting process with a single automated source of truth.

Problem

Sales performance and customer retention were tracked across scattered spreadsheets, making it slow to answer basic questions like "which accounts are at risk of churning" or "how does this month's cohort compare to last quarter's."

Data Model

Four tables in a simple star-like schema:

customers — company, region, industry, segment, signup date
products — catalog with category and unit price
orders — one row per order, linked to a customer
order_items — line-item detail (quantity, discount, line total) linked to orders and products

See 01_schema.sql for DDL and 02_load_data.sql for the load script.

Analysis (see 03_analysis_queries.sql)
Monthly revenue trend — CTE + LAG() window function for month-over-month growth, plus a rolling 3-month average to smooth seasonality
Top accounts by region — RANK() OVER (PARTITION BY region ...) to surface the top 5 accounts per region without a separate query per region
Cohort retention analysis — customers grouped by signup month, tracking what percentage of each cohort is still ordering N months later (pivoted into a retention heatmap in Power BI)
At-risk / churn segmentation — customers bucketed into Active / Watch / At Risk / Churned based on days since last order and lifetime revenue, for retention targeting
Dashboard (Power BI)

Three pages:

Executive Overview — revenue trend, MoM growth, active customers, AOV
Cohort Retention — retention heatmap by signup cohort
At-Risk Accounts — table of churn-status-flagged accounts sorted by lifetime revenue, so retention efforts focus on the highest-value at-risk accounts first
Tech Stack

PostgreSQL · SQL (CTEs, window functions) · Power BI · DAX

What I'd add next
Automate the refresh with a scheduled ETL job instead of manual CSV load
Add a customer lifetime value (CLV) prediction model
Track discount impact on repeat purchase rate
