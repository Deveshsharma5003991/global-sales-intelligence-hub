-- Global Sales Intelligence Hub
-- Schema: run this first in psql or pgAdmin

DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
    customer_id     INT PRIMARY KEY,
    company_name    VARCHAR(150) NOT NULL,
    contact_name    VARCHAR(100),
    region          VARCHAR(50),
    industry        VARCHAR(50),
    segment         VARCHAR(20),
    signup_date     DATE NOT NULL
);

CREATE TABLE products (
    product_id      INT PRIMARY KEY,
    product_name    VARCHAR(150) NOT NULL,
    category        VARCHAR(50),
    unit_price      NUMERIC(10,2)
);

CREATE TABLE orders (
    order_id        INT PRIMARY KEY,
    customer_id     INT REFERENCES customers(customer_id),
    order_date      DATE NOT NULL,
    sales_rep       VARCHAR(50)
);

CREATE TABLE order_items (
    order_item_id   INT PRIMARY KEY,
    order_id        INT REFERENCES orders(order_id),
    product_id      INT REFERENCES products(product_id),
    quantity        INT NOT NULL,
    discount_pct    NUMERIC(5,2) DEFAULT 0,
    line_total      NUMERIC(12,2) NOT NULL
);

-- Indexes that matter once this is at real scale (mirrors partition-pruning /
-- query-optimization talking points from your resume)
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
