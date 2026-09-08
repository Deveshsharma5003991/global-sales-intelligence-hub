-- ============================================================
-- Global Sales Intelligence Hub — Analysis Queries
-- Maps to resume claims: CTEs, window functions, cohort analysis,
-- churn/at-risk segmentation, consolidated reporting
-- ============================================================


-- ------------------------------------------------------------
-- 1. MONTHLY REVENUE TREND (replaces the manual multi-sheet process)
-- ------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date) AS order_month,
        SUM(oi.line_total) AS revenue,
        COUNT(DISTINCT o.order_id) AS order_count,
        COUNT(DISTINCT o.customer_id) AS active_customers
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY 1
)
SELECT
    order_month,
    revenue,
    order_count,
    active_customers,
    ROUND(revenue / NULLIF(order_count, 0), 2) AS avg_order_value,
    -- window function: month-over-month growth
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 2
    ) AS mom_growth_pct,
    -- window function: rolling 3-month average
    ROUND(AVG(revenue) OVER (ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS rolling_3mo_avg
FROM monthly_revenue
ORDER BY order_month;


-- ------------------------------------------------------------
-- 2. TOP CUSTOMERS BY REVENUE, RANKED WITHIN EACH REGION
--    (window function: RANK / PARTITION BY)
-- ------------------------------------------------------------
WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.region,
        c.segment,
        SUM(oi.line_total) AS total_revenue
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY c.customer_id, c.company_name, c.region, c.segment
)
SELECT
    region,
    company_name,
    segment,
    total_revenue,
    RANK() OVER (PARTITION BY region ORDER BY total_revenue DESC) AS rank_in_region
FROM customer_revenue
QUALIFY rank_in_region <= 5  -- Postgres 16+: use QUALIFY, else wrap in outer SELECT with WHERE
ORDER BY region, rank_in_region;

-- Postgres < 16 fallback (no QUALIFY support) — wrap it:
-- SELECT * FROM (
--     SELECT region, company_name, segment, total_revenue,
--            RANK() OVER (PARTITION BY region ORDER BY total_revenue DESC) AS rank_in_region
--     FROM customer_revenue
-- ) ranked
-- WHERE rank_in_region <= 5
-- ORDER BY region, rank_in_region;


-- ------------------------------------------------------------
-- 3. COHORT ANALYSIS — retention by signup month
--    (this is the headline "cohort analysis to surface churn patterns" bullet)
-- ------------------------------------------------------------
WITH cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', signup_date) AS cohort_month
    FROM customers
),
customer_activity AS (
    SELECT
        o.customer_id,
        DATE_TRUNC('month', o.order_date) AS activity_month
    FROM orders o
    GROUP BY o.customer_id, DATE_TRUNC('month', o.order_date)
),
cohort_activity AS (
    SELECT
        c.cohort_month,
        ca.activity_month,
        -- months since signup, as an integer offset
        (EXTRACT(YEAR FROM ca.activity_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
            + (EXTRACT(MONTH FROM ca.activity_month) - EXTRACT(MONTH FROM c.cohort_month)) AS month_number,
        ca.customer_id
    FROM cohorts c
    JOIN customer_activity ca ON ca.customer_id = c.customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS num_customers
    FROM cohorts
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    ca.month_number,
    COUNT(DISTINCT ca.customer_id) AS active_customers,
    cs.num_customers AS cohort_size,
    ROUND(100.0 * COUNT(DISTINCT ca.customer_id) / cs.num_customers, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs ON cs.cohort_month = ca.cohort_month
WHERE ca.month_number >= 0
GROUP BY ca.cohort_month, ca.month_number, cs.num_customers
ORDER BY ca.cohort_month, ca.month_number;

-- Pivot the above in Power BI as a cohort-retention heatmap
-- (rows = cohort_month, columns = month_number, values = retention_pct)


-- ------------------------------------------------------------
-- 4. AT-RISK / CHURNED CUSTOMER SEGMENTATION
--    (the "segment at-risk accounts for retention targeting" bullet)
-- ------------------------------------------------------------
WITH last_order AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_order_date
    FROM orders
    GROUP BY customer_id
),
customer_lifetime AS (
    SELECT
        c.customer_id,
        c.company_name,
        c.region,
        c.segment,
        c.signup_date,
        lo.last_order_date,
        (SELECT SUM(oi.line_total)
         FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
         WHERE o.customer_id = c.customer_id) AS lifetime_revenue,
        CURRENT_DATE - lo.last_order_date AS days_since_last_order
    FROM customers c
    LEFT JOIN last_order lo ON lo.customer_id = c.customer_id
)
SELECT
    customer_id,
    company_name,
    region,
    segment,
    lifetime_revenue,
    last_order_date,
    days_since_last_order,
    CASE
        WHEN last_order_date IS NULL THEN 'Never Ordered'
        WHEN days_since_last_order > 180 THEN 'Churned'
        WHEN days_since_last_order BETWEEN 90 AND 180 THEN 'At Risk'
        WHEN days_since_last_order BETWEEN 45 AND 89 THEN 'Watch'
        ELSE 'Active'
    END AS churn_status
FROM customer_lifetime
ORDER BY lifetime_revenue DESC NULLS LAST;


-- ------------------------------------------------------------
-- 5. PRODUCT CATEGORY PERFORMANCE (for a Power BI matrix visual)
-- ------------------------------------------------------------
SELECT
    p.category,
    COUNT(DISTINCT oi.order_id) AS orders_containing_category,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS revenue,
    ROUND(AVG(oi.discount_pct), 1) AS avg_discount_pct
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY revenue DESC;
