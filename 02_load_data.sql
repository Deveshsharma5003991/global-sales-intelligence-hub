-- Run this AFTER 01_schema.sql, from the same directory as the CSV files.
-- In psql: \i 02_load_data.sql   (relative paths work if you launched psql from this folder)
-- If \copy gives a path error, replace the filenames below with the FULL absolute path
-- to wherever you saved the CSVs on your machine.

\copy customers FROM 'customers.csv' WITH (FORMAT csv, HEADER true);
\copy products  FROM 'products.csv'  WITH (FORMAT csv, HEADER true);
\copy orders    FROM 'orders.csv'    WITH (FORMAT csv, HEADER true);
\copy order_items FROM 'order_items.csv' WITH (FORMAT csv, HEADER true);

-- Quick sanity check after loading
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;
