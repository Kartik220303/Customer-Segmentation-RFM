-- Create Database

CREATE DATABASE customer_segmentation;
USE customer_segmentation;

-- Creating table and importing
-- STAGING TABLE: stg_customers

CREATE TABLE stg_customers(
    customer_id VARCHAR(20),
    full_name VARCHAR(100),
    email VARCHAR(150),
    gender VARCHAR(20),
    age VARCHAR(10),
    city VARCHAR(50),
    state VARCHAR(50),
    signup_date VARCHAR(30),
    acquisition_channel VARCHAR(50),
    email_opt_in VARCHAR(10),
    loyalty_member VARCHAR(10)
);

-- STAGING TABLE: stg_products

CREATE TABLE stg_products (
    product_id VARCHAR(20),
    product_name VARCHAR(150),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    list_price VARCHAR(30),
    cost_price VARCHAR(30)
);

-- STAGING TABLE: stg_orders

CREATE TABLE stg_orders (
    order_id VARCHAR(20),
    customer_id VARCHAR(20),
    order_date VARCHAR(30),
    channel VARCHAR(30),
    payment_method VARCHAR(30),
    coupon_code VARCHAR(30),
    discount_pct VARCHAR(10),
    shipping_fee VARCHAR(10),
    order_total VARCHAR(30),
    order_status VARCHAR(20)
);

-- STAGING TABLE: stg_order_items

CREATE TABLE stg_order_items (
    order_item_id VARCHAR(20),
    order_id VARCHAR(20),
    product_id VARCHAR(20),
    quantity VARCHAR(10),
    unit_price VARCHAR(30)
);

-- STAGING TABLE: stg_campaign_responses

CREATE TABLE stg_campaign_responses (
    response_id VARCHAR(20),
    campaign_id VARCHAR(20),
    campaign_name VARCHAR(100),
    campaign_type VARCHAR(20),
    customer_id VARCHAR(20),
    sent_date VARCHAR(30),
    opened VARCHAR(10),
    clicked VARCHAR(10),
    converted VARCHAR(10)
);

-- IMPORT VERIFICATION: raw row counts

SELECT 'stg_customers' AS table_name, COUNT(*) AS row_count FROM stg_customers
UNION ALL SELECT 'stg_products', COUNT(*) FROM stg_products
UNION ALL SELECT 'stg_orders', COUNT(*) FROM stg_orders
UNION ALL SELECT 'stg_order_items', COUNT(*) FROM stg_order_items
UNION ALL SELECT 'stg_campaign_responses', COUNT(*) FROM stg_campaign_responses;

-- DUPLICATE CHECK: stg_customers 

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT customer_id) AS distinct_ids
FROM stg_customers;

-- INSPECT DUPLICATE PAIRS: stg_customers

SELECT *
FROM stg_customers
WHERE customer_id IN (
    SELECT customer_id
    FROM stg_customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)
ORDER BY customer_id;

-- DO THE PAIRS DIFFER: stg_customers

SELECT customer_id,
       COUNT(*) AS copies,
       COUNT(DISTINCT full_name COLLATE utf8mb4_bin) AS distinct_names,
       COUNT(DISTINCT email COLLATE utf8mb4_bin) AS distinct_emails
FROM stg_customers
GROUP BY customer_id
HAVING COUNT(*) > 1
   AND (distinct_names > 1 OR distinct_emails > 1);

-- Ids repeated and how often

SELECT customer_id, COUNT(*) AS cnt
FROM stg_customers
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- NULL or BLANK CHECK: stg_customers

SELECT
    SUM(customer_id IS NULL OR TRIM(customer_id) = '') AS customer_id_missing,
    SUM(full_name IS NULL OR TRIM(full_name) = '') AS full_name_missing,
    SUM(email IS NULL OR TRIM(email) = '') AS email_missing,
    SUM(gender IS NULL OR TRIM(gender) = '') AS gender_missing,
    SUM(age IS NULL OR TRIM(age) = '') AS age_missing,
    SUM(city IS NULL OR TRIM(city) = '') AS city_missing,
    SUM(state IS NULL OR TRIM(state) = '') AS state_missing,
    SUM(signup_date IS NULL OR TRIM(signup_date) = '') AS signup_date_missing,
    SUM(acquisition_channel IS NULL OR TRIM(acquisition_channel) = '') AS acq_channel_missing,
    SUM(email_opt_in IS NULL OR TRIM(email_opt_in) = '') AS opt_in_missing,
    SUM(loyalty_member IS NULL OR TRIM(loyalty_member) = '') AS loyalty_missing
FROM stg_customers;

-- CATEGORY CONSISTENCY: stg_customers
-- CATEGORY CONSISTENCY: gender

SELECT gender COLLATE utf8mb4_bin AS gender_value, COUNT(*) AS cnt
FROM stg_customers
GROUP BY 1 ORDER BY cnt DESC;

-- CATEGORY CONSISTENCY: email_opt_in

SELECT email_opt_in COLLATE utf8mb4_bin AS opt_in_value, COUNT(*) AS cnt
FROM stg_customers
GROUP BY 1 ORDER BY cnt DESC;

-- CATEGORY CONSISTENCY: loyalty_member

SELECT loyalty_member COLLATE utf8mb4_bin AS loyalty_value, COUNT(*) AS cnt
FROM stg_customers
GROUP BY 1 ORDER BY cnt DESC;

-- CATEGORY CONSISTENCY: city (with length)

SELECT city COLLATE utf8mb4_bin AS city_value, LENGTH(city) AS len, COUNT(*) AS cnt
FROM stg_customers
GROUP BY 1, 2 ORDER BY city_value;

-- AGE RANGE CHECK: stg_customers

SELECT MIN(CAST(age AS UNSIGNED)) AS min_age,
       MAX(CAST(age AS UNSIGNED)) AS max_age
FROM stg_customers
WHERE age REGEXP '^[0-9]+$';

-- DATE FORMAT DIAGNOSIS: stg_customers

SELECT
  SUM(signup_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS iso,
  SUM(signup_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$') AS slash,
  SUM(signup_date REGEXP '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{2}$') AS dd_mon_yy,
  SUM(signup_date REGEXP '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$') AS dd_mm_yyyy,
  SUM(signup_date REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$') AS month_name,
  COUNT(*) AS total
FROM stg_customers;

-- AGE OUTLIERS: stg_customers

SELECT age, COUNT(*) AS cnt
FROM stg_customers
WHERE age REGEXP '^[0-9]+$'
  AND (CAST(age AS UNSIGNED) < 18 OR CAST(age AS UNSIGNED) > 70)
GROUP BY age
ORDER BY CAST(age AS UNSIGNED);

-- NON-NUMERIC AGE CHECK: stg_customers

SELECT COUNT(*) AS non_numeric_age
FROM stg_customers
WHERE TRIM(age) <> '' AND age NOT REGEXP '^[0-9]+$';

-- DATE FORMAT CHECK: orders and campaigns

SELECT 'stg_orders' AS tbl,
       SUM(order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') AS iso_rows,
       COUNT(*) AS total_rows
FROM stg_orders
UNION ALL
SELECT 'stg_campaign_responses',
       SUM(sent_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
       COUNT(*)
FROM stg_campaign_responses;

-- SLASH DATE ORDER CHECK: stg_customers

SELECT
  SUM(CAST(SUBSTRING_INDEX(signup_date,'/',1) AS UNSIGNED) > 12) AS first_gt_12,
  SUM(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(signup_date,'/',2),'/',-1) AS UNSIGNED) > 12) AS second_gt_12
FROM stg_customers
WHERE signup_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$';

-- DASH DATE ORDER CHECK: stg_customers

SELECT
  SUM(CAST(SUBSTRING_INDEX(signup_date,'-',1) AS UNSIGNED) > 12) AS first_gt_12,
  SUM(CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(signup_date,'-',2),'-',-1) AS UNSIGNED) > 12) AS second_gt_12,
  SUM(CAST(SUBSTRING_INDEX(signup_date,'-',1) AS UNSIGNED) <= 12
      AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(signup_date,'-',2),'-',-1) AS UNSIGNED) <= 12) AS both_le_12
FROM stg_customers
WHERE signup_date REGEXP '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$';

-- SIGNUP DATE CONVERSION TEST

SELECT COUNT(*) AS total_rows,
       SUM(signup_clean IS NULL) AS failed_conversions,
       MIN(signup_clean) AS earliest,
       MAX(signup_clean) AS latest
FROM (
    SELECT CASE
        WHEN signup_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(signup_date, '%Y-%m-%d')
        WHEN signup_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%m/%d/%Y')
        WHEN signup_date REGEXP '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%d-%m-%Y')
        WHEN signup_date REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%M %d, %Y')
    END AS signup_clean
    FROM stg_customers
) t;

-- CATEGORY CONSISTENCY: state and acquisition_channel

SELECT 'state' AS col, state COLLATE utf8mb4_bin AS value, LENGTH(state) AS len, COUNT(*) AS cnt
FROM stg_customers
GROUP BY 1, 2, 3
UNION ALL
SELECT 'acquisition_channel', acquisition_channel COLLATE utf8mb4_bin, LENGTH(acquisition_channel), COUNT(*)
FROM stg_customers
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC;

-- BUILD stg_customers_clean

CREATE TABLE stg_customers_clean AS
SELECT
    customer_id,
    TRIM(full_name) AS full_name,
    NULLIF(LOWER(TRIM(email)), '') AS email,
    CASE
        WHEN UPPER(TRIM(gender)) IN ('MALE', 'M') THEN 'Male'
        WHEN UPPER(TRIM(gender)) IN ('FEMALE', 'F') THEN 'Female'
        WHEN UPPER(TRIM(gender)) IN ('OTHER', 'O') THEN 'Other'
    END AS gender,
    CASE
        WHEN age REGEXP '^[0-9]+$'
         AND CAST(age AS UNSIGNED) BETWEEN 18 AND 100
            THEN CAST(age AS UNSIGNED)
    END AS age,
    CASE
        WHEN TRIM(city) = '' THEN NULL
        ELSE CONCAT(UPPER(LEFT(TRIM(city), 1)), LOWER(SUBSTRING(TRIM(city), 2)))
    END AS city,
    state,
    CASE
        WHEN signup_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(signup_date, '%Y-%m-%d')
        WHEN signup_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%m/%d/%Y')
        WHEN signup_date REGEXP '^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%d-%m-%Y')
        WHEN signup_date REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
            THEN STR_TO_DATE(signup_date, '%M %d, %Y')
    END AS signup_date,
    acquisition_channel,
    CASE
        WHEN UPPER(TRIM(email_opt_in)) IN ('YES', 'Y', 'TRUE') THEN 'Yes'
        WHEN UPPER(TRIM(email_opt_in)) IN ('NO', 'N', 'FALSE') THEN 'No'
    END AS email_opt_in,
    loyalty_member
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_id) AS rn
    FROM stg_customers
) t
WHERE rn = 1;

-- ROW COUNT CHECK

SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_ids
FROM stg_customers_clean;

-- VALIDATE stg_customers_clean: nulls, ages, dates

SELECT
    SUM(email IS NULL) AS email_nulls,
    SUM(age IS NULL) AS age_nulls,
    SUM(city IS NULL) AS city_nulls,
    SUM(signup_date IS NULL) AS date_nulls,
    MIN(age) AS min_age,
    MAX(age) AS max_age,
    MIN(signup_date) AS earliest_signup,
    MAX(signup_date) AS latest_signup
FROM stg_customers_clean;

-- VALIDATE stg_customers_clean: gender, opt-in, loyalty

SELECT 'gender' AS col, gender COLLATE utf8mb4_bin AS value, COUNT(*) AS cnt
FROM stg_customers_clean GROUP BY 1, 2
UNION ALL
SELECT 'email_opt_in', email_opt_in COLLATE utf8mb4_bin, COUNT(*)
FROM stg_customers_clean GROUP BY 1, 2
UNION ALL
SELECT 'loyalty_member', loyalty_member COLLATE utf8mb4_bin, COUNT(*)
FROM stg_customers_clean GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- DUPLICATE CHECK: stg_products
-- -- Total rows vs distinct product IDs

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT product_id) AS distinct_ids
FROM stg_products;

-- Which product IDs repeat, and how often

SELECT product_id, COUNT(*) AS cnt
FROM stg_products
GROUP BY product_id
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- INSPECT DUPLICATE PRODUCTS: stg_products

SELECT *
FROM stg_products
WHERE product_id IN ('P102', 'P106')
ORDER BY product_id;

-- NULL / BLANK CHECK: stg_products

SELECT
    SUM(product_id   IS NULL OR TRIM(product_id) = '') AS product_id_missing,
    SUM(product_name IS NULL OR TRIM(product_name) = '') AS product_name_missing,
    SUM(category     IS NULL OR TRIM(category) = '') AS category_missing,
    SUM(sub_category IS NULL OR TRIM(sub_category) = '') AS sub_category_missing,
    SUM(list_price   IS NULL OR TRIM(list_price) = '') AS list_price_missing,
    SUM(cost_price   IS NULL OR TRIM(cost_price) = '') AS cost_price_missing
FROM stg_products;

-- CATEGORY CONSISTENCY: stg_products

SELECT category COLLATE utf8mb4_bin AS category_value,
       LENGTH(category) AS len,
       COUNT(*) AS cnt
FROM stg_products
GROUP BY 1, 2
ORDER BY category_value;

-- SUB-CATEGORY CONSISTENCY: stg_products

SELECT
    COUNT(DISTINCT sub_category COLLATE utf8mb4_bin) AS distinct_raw,
    COUNT(DISTINCT LOWER(TRIM(sub_category))) AS distinct_cleaned,
    SUM(LENGTH(sub_category) <> LENGTH(TRIM(sub_category))) AS padded_rows
FROM stg_products;

-- PRICE FORMAT AND RANGE CHECK: stg_products

SELECT
    SUM(list_price NOT REGEXP '^[0-9]+([.][0-9]+)?$') AS bad_list_price,
    SUM(cost_price NOT REGEXP '^[0-9]+([.][0-9]+)?$') AS bad_cost_price,
    MIN(CAST(list_price AS DECIMAL(10,2))) AS min_list,
    MAX(CAST(list_price AS DECIMAL(10,2))) AS max_list,
    MIN(CAST(cost_price AS DECIMAL(10,2))) AS min_cost,
    MAX(CAST(cost_price AS DECIMAL(10,2))) AS max_cost
FROM stg_products;

-- COST VS LIST PRICE: stg_products

SELECT product_id, product_name, list_price, cost_price,
       CAST(cost_price AS DECIMAL(10,2)) - CAST(list_price AS DECIMAL(10,2)) AS cost_minus_list
FROM stg_products
WHERE CAST(cost_price AS DECIMAL(10,2)) >= CAST(list_price AS DECIMAL(10,2))
ORDER BY product_id;

-- BUILD stg_products_clean

CREATE TABLE stg_products_clean AS
SELECT
    product_id,
    product_name,
    category,
    sub_category,
    CAST(list_price AS DECIMAL(10,2)) AS list_price,
    CASE
        WHEN CAST(cost_price AS DECIMAL(10,2)) < CAST(list_price AS DECIMAL(10,2))
            THEN CAST(cost_price AS DECIMAL(10,2))
    END AS cost_price
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS rn
    FROM stg_products
) t
WHERE rn = 1;

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT product_id) AS distinct_ids,
       SUM(cost_price IS NULL) AS null_costs
FROM stg_products_clean;

-- ROW COUNT CHECK

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT product_id) AS distinct_ids,
       SUM(cost_price IS NULL) AS null_costs
FROM stg_products_clean;

-- DUPLICATE CHECK: stg_orders
-- Total rows vs distinct order IDs

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS distinct_ids
FROM stg_orders;

-- How many order IDs repeat, and the highest repeat count

SELECT COUNT(*) AS repeated_ids,
       MAX(cnt) AS max_copies
FROM (
    SELECT order_id, COUNT(*) AS cnt
    FROM stg_orders
    GROUP BY order_id
    HAVING COUNT(*) > 1
) t;

-- DO THE DUPLICATE ORDER PAIRS DIFFER: stg_orders

SELECT order_id,
       COUNT(*) AS copies,
       COUNT(DISTINCT CONCAT_WS('|', customer_id, order_date, channel, payment_method,
                                coupon_code, discount_pct, shipping_fee, order_total, order_status)
             COLLATE utf8mb4_bin) AS distinct_versions
FROM stg_orders
GROUP BY order_id
HAVING COUNT(*) > 1
   AND distinct_versions > 1;
   
-- ORPHAN CUSTOMER CHECK: stg_orders

SELECT COUNT(*) AS orphan_order_rows,
       COUNT(DISTINCT customer_id) AS orphan_customers
FROM stg_orders
WHERE customer_id NOT IN (SELECT customer_id FROM stg_customers_clean);

-- WHICH CUSTOMER IDS ARE ORPHANS?

SELECT customer_id, COUNT(*) AS orders
FROM stg_orders
WHERE customer_id NOT IN (SELECT customer_id FROM stg_customers_clean)
GROUP BY customer_id
ORDER BY customer_id;

-- ORDER TOTAL FORMAT CHECK: stg_orders

SELECT
    SUM(order_total IS NULL OR TRIM(order_total) = '') AS blank_total,
    SUM(order_total LIKE 'Rs%') AS currency_text,
    SUM(order_total REGEXP '^[0-9]+([.][0-9]+)?$') AS clean_numeric,
    COUNT(*) AS total_rows
FROM stg_orders;

-- CURRENCY TEXT CONVERSION TEST: stg_orders

SELECT COUNT(*) AS rows_converted,
       MIN(v) AS min_value,
       MAX(v) AS max_value,
       SUM(v) AS total_value
FROM (
    SELECT CAST(REPLACE(REPLACE(order_total, 'Rs. ', ''), ',', '') AS DECIMAL(12,2)) AS v
    FROM stg_orders
    WHERE order_total LIKE 'Rs%'
) t;

-- RECONCILE ORDER TOTALS WITH ORDER ITEMS

WITH o AS (
    SELECT DISTINCT
           order_id,
           CAST(discount_pct AS DECIMAL(5,2)) AS discount_pct,
           CASE
               WHEN order_total LIKE 'Rs%'
                   THEN CAST(REPLACE(REPLACE(order_total, 'Rs. ', ''), ',', '') AS DECIMAL(12,2))
               WHEN order_total REGEXP '^[0-9]+([.][0-9]+)?$'
                   THEN CAST(order_total AS DECIMAL(12,2))
           END AS stored_total
    FROM stg_orders
),
i AS (
    SELECT order_id,
           SUM(CAST(quantity AS UNSIGNED) * CAST(unit_price AS DECIMAL(12,2))) AS items_total
    FROM stg_order_items
    GROUP BY order_id
)
SELECT COUNT(*) AS orders_with_stored_total,
       SUM(ABS(o.stored_total - ROUND(i.items_total * (1 - o.discount_pct / 100), 2)) > 0.01) AS mismatches,
       SUM(i.order_id IS NULL) AS orders_with_no_items
FROM o
LEFT JOIN i ON i.order_id = o.order_id
WHERE o.stored_total IS NOT NULL;

-- LIST THE 16 MISMATCHED ORDERS

WITH o AS (
    SELECT DISTINCT
           order_id,
           CAST(discount_pct AS DECIMAL(5,2)) AS discount_pct,
           CASE
               WHEN order_total LIKE 'Rs%'
                   THEN CAST(REPLACE(REPLACE(order_total, 'Rs. ', ''), ',', '') AS DECIMAL(12,2))
               WHEN order_total REGEXP '^[0-9]+([.][0-9]+)?$'
                   THEN CAST(order_total AS DECIMAL(12,2))
           END AS stored_total
    FROM stg_orders
),
i AS (
    SELECT order_id,
           SUM(CAST(quantity AS UNSIGNED) * CAST(unit_price AS DECIMAL(12,2))) AS items_total
    FROM stg_order_items
    GROUP BY order_id
)
SELECT o.order_id,
       o.stored_total,
       ROUND(i.items_total * (1 - o.discount_pct / 100), 2) AS rebuilt_total,
       o.stored_total - ROUND(i.items_total * (1 - o.discount_pct / 100), 2) AS difference
FROM o
JOIN i ON i.order_id = o.order_id
WHERE o.stored_total IS NOT NULL
  AND ABS(o.stored_total - ROUND(i.items_total * (1 - o.discount_pct / 100), 2)) > 0.01
ORDER BY difference DESC;

-- ORDER ITEMS INTEGRITY CHECK: stg_order_items

SELECT
    COUNT(*) AS total_rows,
    SUM(order_id NOT IN (SELECT order_id FROM stg_orders))AS orphan_order_ids,
    SUM(product_id NOT IN (SELECT product_id FROM stg_products_clean)) AS orphan_product_ids,
    SUM(CAST(quantity AS UNSIGNED) = 0) AS zero_quantity
FROM stg_order_items;

-- ORDER ITEMS FORMAT CHECK: stg_order_items

SELECT
    COUNT(DISTINCT order_item_id) AS distinct_item_ids,
    SUM(quantity   NOT REGEXP '^[0-9]+$') AS bad_quantity,
    SUM(unit_price NOT REGEXP '^[0-9]+([.][0-9]+)?$') AS bad_unit_price,
    MAX(CAST(quantity AS UNSIGNED)) AS max_quantity,
    MIN(CAST(unit_price AS DECIMAL(10,2))) AS min_price,
    MAX(CAST(unit_price AS DECIMAL(10,2))) AS max_price
FROM stg_order_items;

-- CATEGORY CONSISTENCY: order_status

SELECT order_status COLLATE utf8mb4_bin AS status_value,
       LENGTH(order_status) AS len,
       COUNT(*) AS cnt
FROM stg_orders
GROUP BY 1, 2
ORDER BY cnt DESC;

-- STATUS STANDARDISATION TEST: stg_orders

SELECT
    CASE
        WHEN UPPER(TRIM(order_status)) = 'DELIVERED' THEN 'Delivered'
        WHEN UPPER(TRIM(order_status)) = 'RETURNED' THEN 'Returned'
        WHEN UPPER(TRIM(order_status)) IN ('CANCELLED', 'CANCELED') THEN 'Cancelled'
    END AS status_clean,
    COUNT(*) AS cnt
FROM stg_orders
GROUP BY 1
ORDER BY cnt DESC;

-- CATEGORY CONSISTENCY: remaining orders columns

SELECT 'channel' AS col, channel COLLATE utf8mb4_bin AS value, COUNT(*) AS cnt
FROM stg_orders GROUP BY 1, 2
UNION ALL
SELECT 'payment_method', payment_method COLLATE utf8mb4_bin, COUNT(*)
FROM stg_orders GROUP BY 1, 2
UNION ALL
SELECT 'coupon | discount', CONCAT(coupon_code, ' | ', discount_pct) COLLATE utf8mb4_bin, COUNT(*)
FROM stg_orders GROUP BY 1, 2
UNION ALL
SELECT 'shipping_fee', shipping_fee COLLATE utf8mb4_bin, COUNT(*)
FROM stg_orders GROUP BY 1, 2
UNION ALL
SELECT 'padded_values_total', '',
       SUM(LENGTH(channel) <> LENGTH(TRIM(channel))
        OR LENGTH(payment_method) <> LENGTH(TRIM(payment_method))
        OR LENGTH(coupon_code) <> LENGTH(TRIM(coupon_code))
        OR LENGTH(customer_id) <> LENGTH(TRIM(customer_id)))
FROM stg_orders
ORDER BY 1, 3 DESC;

-- BUILD stg_orders_clean

CREATE TABLE stg_orders_clean AS
WITH item_totals AS (
    SELECT order_id,
           SUM(CAST(quantity AS UNSIGNED) * CAST(unit_price AS DECIMAL(12,2))) AS items_total
    FROM stg_order_items
    GROUP BY order_id
),
dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_id) AS rn
    FROM stg_orders
)
SELECT
    d.order_id,
    d.customer_id,
    STR_TO_DATE(d.order_date, '%Y-%m-%d') AS order_date,
    d.channel,
    d.payment_method,
    d.coupon_code,
    CAST(d.discount_pct AS DECIMAL(5,2)) AS discount_pct,
    CAST(d.shipping_fee AS DECIMAL(8,2)) AS shipping_fee,
    CASE
        WHEN d.order_total LIKE 'Rs%'
            THEN CAST(REPLACE(REPLACE(d.order_total, 'Rs. ', ''), ',', '') AS DECIMAL(12,2))
        WHEN d.order_total REGEXP '^[0-9]+([.][0-9]+)?$'
            THEN CAST(d.order_total AS DECIMAL(12,2))
        ELSE ROUND(i.items_total * (1 - CAST(d.discount_pct AS DECIMAL(5,2)) / 100), 2)
    END AS order_total,
    CASE
        WHEN d.order_total LIKE 'Rs%'
          OR d.order_total REGEXP '^[0-9]+([.][0-9]+)?$' THEN 'Stored'
        ELSE 'Rebuilt from items'
    END AS total_source,
    CASE
        WHEN UPPER(TRIM(d.order_status)) = 'DELIVERED' THEN 'Delivered'
        WHEN UPPER(TRIM(d.order_status)) = 'RETURNED' THEN 'Returned'
        WHEN UPPER(TRIM(d.order_status)) IN ('CANCELLED', 'CANCELED') THEN 'Cancelled'
    END                                            AS order_status
FROM dedup d
LEFT JOIN item_totals i ON i.order_id = d.order_id
WHERE d.rn = 1
  AND d.customer_id IN (SELECT customer_id FROM stg_customers_clean);
  
  -- VALIDATE stg_orders_clean
  
  SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS distinct_ids,
       SUM(order_total IS NULL) AS null_totals,
       SUM(total_source = 'Rebuilt from items') AS rebuilt_totals,
       MIN(order_date) AS earliest,
       MAX(order_date) AS latest,
       MIN(order_total) AS min_total,
       MAX(order_total) AS max_total,
       ROUND(SUM(order_total), 2) AS grand_total
FROM stg_orders_clean;

-- BUILD stg_order_items_clean

CREATE TABLE stg_order_items_clean AS
SELECT
    i.order_item_id,
    i.order_id,
    CASE
        WHEN i.product_id IN (SELECT product_id FROM stg_products_clean) THEN i.product_id
    END AS product_id,
    CASE
        WHEN CAST(i.quantity AS UNSIGNED) > 0 THEN CAST(i.quantity AS UNSIGNED)
    END AS quantity,
    CAST(i.unit_price AS DECIMAL(10,2)) AS unit_price
FROM stg_order_items i
WHERE i.order_id IN (SELECT order_id FROM stg_orders_clean);

-- VALIDATE stg_order_items_clean

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_item_id) AS distinct_items,
       COUNT(DISTINCT order_id) AS orders_covered,
       SUM(product_id IS NULL) AS null_products,
       SUM(quantity IS NULL) AS null_quantities,
       SUM(quantity) AS total_units
FROM stg_order_items_clean;

-- DUPLICATE CHECK: stg_campaign_responses

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT response_id) AS distinct_ids
FROM stg_campaign_responses;

SELECT COUNT(*) AS repeated_ids,
       MAX(cnt) AS max_copies
FROM (
    SELECT response_id, COUNT(*) AS cnt
    FROM stg_campaign_responses
    GROUP BY response_id
    HAVING COUNT(*) > 1
) t;

-- DO THE DUPLICATE RESPONSE PAIRS DIFFER: stg_campaign_responses

SELECT response_id,
       COUNT(*) AS copies,
       COUNT(DISTINCT CONCAT_WS('|', campaign_id, campaign_name, campaign_type, customer_id,
                                sent_date, opened, clicked, converted)
             COLLATE utf8mb4_bin) AS distinct_versions
FROM stg_campaign_responses
GROUP BY response_id
HAVING COUNT(*) > 1
   AND distinct_versions > 1;
   
-- ORPHAN CUSTOMER CHECK: stg_campaign_responses

SELECT COUNT(*) AS orphan_rows,
       COUNT(DISTINCT customer_id) AS orphan_customers,
       MIN(customer_id) AS lowest_id,
       MAX(customer_id) AS highest_id
FROM stg_campaign_responses
WHERE customer_id NOT IN (SELECT customer_id FROM stg_customers_clean);

-- CATEGORY CONSISTENCY: opened, clicked, converted

SELECT 'opened' AS col, opened COLLATE utf8mb4_bin AS value, COUNT(*) AS cnt
FROM stg_campaign_responses GROUP BY 1, 2
UNION ALL
SELECT 'clicked', clicked COLLATE utf8mb4_bin, COUNT(*)
FROM stg_campaign_responses GROUP BY 1, 2
UNION ALL
SELECT 'converted', converted COLLATE utf8mb4_bin, COUNT(*)
FROM stg_campaign_responses GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- YES/NO STANDARDISATION TEST: stg_campaign_responses

SELECT 'opened' AS col,
       CASE WHEN UPPER(TRIM(opened)) IN ('YES', 'Y', 'TRUE', '1')  THEN 'Yes'
            WHEN UPPER(TRIM(opened)) IN ('NO', 'N', 'FALSE', '0')  THEN 'No' END AS value,
       COUNT(*) AS cnt
FROM stg_campaign_responses GROUP BY 1, 2
UNION ALL
SELECT 'clicked',
       CASE WHEN UPPER(TRIM(clicked)) IN ('YES', 'Y', 'TRUE', '1') THEN 'Yes'
            WHEN UPPER(TRIM(clicked)) IN ('NO', 'N', 'FALSE', '0') THEN 'No' END,
       COUNT(*)
FROM stg_campaign_responses GROUP BY 1, 2
UNION ALL
SELECT 'converted',
       CASE WHEN UPPER(TRIM(converted)) IN ('YES', 'Y', 'TRUE', '1') THEN 'Yes'
            WHEN UPPER(TRIM(converted)) IN ('NO', 'N', 'FALSE', '0') THEN 'No' END,
       COUNT(*)
FROM stg_campaign_responses GROUP BY 1, 2
ORDER BY 1, 2;

-- FUNNEL LOGIC CHECK: stg_campaign_responses

WITH m AS (
    SELECT
        CASE WHEN UPPER(TRIM(opened))    IN ('YES','Y','TRUE','1') THEN 'Yes' ELSE 'No' END AS opened,
        CASE WHEN UPPER(TRIM(clicked))   IN ('YES','Y','TRUE','1') THEN 'Yes' ELSE 'No' END AS clicked,
        CASE WHEN UPPER(TRIM(converted)) IN ('YES','Y','TRUE','1') THEN 'Yes' ELSE 'No' END AS converted
    FROM (SELECT DISTINCT * FROM stg_campaign_responses) d
)
SELECT COUNT(*)                                        AS unique_rows,
       SUM(converted = 'Yes' AND clicked = 'No')       AS converted_without_click,
       SUM(clicked   = 'Yes' AND opened  = 'No')       AS clicked_without_open,
       SUM(converted = 'Yes' AND opened  = 'No')       AS converted_without_open
FROM m;

-- CAMPAIGN ATTRIBUTE CHECK: stg_campaign_responses

SELECT campaign_id COLLATE utf8mb4_bin AS campaign_id,
       campaign_name COLLATE utf8mb4_bin AS campaign_name,
       campaign_type COLLATE utf8mb4_bin AS campaign_type,
       COUNT(DISTINCT sent_date) AS distinct_send_dates,
       COUNT(*) AS cnt
FROM stg_campaign_responses
GROUP BY 1, 2, 3
ORDER BY campaign_id;

-- BUILD stg_campaign_responses_clean

CREATE TABLE stg_campaign_responses_clean AS
WITH dedup AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY response_id ORDER BY response_id) AS rn
    FROM stg_campaign_responses
),
m AS (
    SELECT
        response_id,
        campaign_id,
        campaign_name,
        campaign_type,
        customer_id,
        STR_TO_DATE(sent_date, '%Y-%m-%d') AS sent_date,
        CASE WHEN UPPER(TRIM(opened)) IN ('YES','Y','TRUE','1') THEN 'Yes' ELSE 'No' END AS opened,
        CASE WHEN UPPER(TRIM(clicked)) IN ('YES','Y','TRUE','1') THEN 'Yes' ELSE 'No' END AS clicked,
        CASE WHEN UPPER(TRIM(converted)) IN ('YES','Y','TRUE','1') THEN 'Yes' ELSE 'No' END AS converted
    FROM dedup
    WHERE rn = 1
      AND customer_id IN (SELECT customer_id FROM stg_customers_clean)
)
SELECT m.*,
       CASE WHEN converted = 'Yes' AND clicked = 'No'
            THEN 'Converted without click' END AS funnel_issue
FROM m;

-- VALIDATE stg_campaign_responses_clean

SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT response_id) AS distinct_ids,
       SUM(funnel_issue IS NOT NULL) AS flagged_rows,
       SUM(opened = 'Yes') AS opened_yes,
       SUM(clicked = 'Yes') AS clicked_yes,
       SUM(converted = 'Yes') AS converted_yes,
       MIN(sent_date) AS earliest,
       MAX(sent_date) AS latest
FROM stg_campaign_responses_clean;

-- CROSS-TABLE INTEGRITY CHECK

SELECT
  (SELECT COUNT(*) FROM stg_orders_clean
    WHERE customer_id NOT IN (SELECT customer_id FROM stg_customers_clean)) AS orders_no_customer,
  (SELECT COUNT(*) FROM stg_order_items_clean
    WHERE order_id NOT IN (SELECT order_id FROM stg_orders_clean)) AS items_no_order,
  (SELECT COUNT(*) FROM stg_order_items_clean
    WHERE product_id IS NOT NULL
      AND product_id NOT IN (SELECT product_id FROM stg_products_clean)) AS items_no_product,
  (SELECT COUNT(*) FROM stg_campaign_responses_clean
    WHERE customer_id NOT IN (SELECT customer_id FROM stg_customers_clean)) AS responses_no_customer,
  (SELECT COUNT(*) FROM stg_orders_clean
    WHERE order_id NOT IN (SELECT order_id FROM stg_order_items_clean)) AS orders_no_items,
  (SELECT COUNT(*) FROM stg_customers_clean
    WHERE customer_id NOT IN (SELECT customer_id FROM stg_orders_clean)) AS customers_no_orders;
    
-- BUILD rfm_base

CREATE TABLE rfm_base AS
SELECT
    customer_id,
    DATEDIFF('2026-07-01', MAX(order_date)) AS recency_days,
    COUNT(*) AS frequency,
    SUM(order_total) AS monetary
FROM stg_orders_clean
WHERE order_status = 'Delivered'
GROUP BY customer_id;

-- VALIDATE rfm_base

SELECT COUNT(*) AS customers,
       MIN(recency_days) AS min_recency,
       MAX(recency_days) AS max_recency,
       MIN(frequency) AS min_frequency,
       MAX(frequency) AS max_frequency,
       MIN(monetary) AS min_monetary,
       MAX(monetary) AS max_monetary,
       SUM(monetary) AS total_monetary
FROM rfm_base;

-- BUILD rfm_scores

CREATE TABLE rfm_scores AS
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    CAST(CEIL(5 * CUME_DIST() OVER (ORDER BY recency_days DESC)) AS UNSIGNED) AS r_score,
    CAST(CEIL(5 * CUME_DIST() OVER (ORDER BY frequency)) AS UNSIGNED) AS f_score,
    CAST(CEIL(5 * CUME_DIST() OVER (ORDER BY monetary)) AS UNSIGNED) AS m_score
FROM rfm_base;

-- VALIDATE SCORE DISTRIBUTIONS

SELECT 'R' AS dim, r_score AS score, COUNT(*) AS cnt FROM rfm_scores GROUP BY r_score
UNION ALL
SELECT 'F', f_score, COUNT(*) FROM rfm_scores GROUP BY f_score
UNION ALL
SELECT 'M', m_score, COUNT(*) FROM rfm_scores GROUP BY m_score
ORDER BY dim, score;

-- BUILD rfm_segments

CREATE TABLE rfm_segments AS
SELECT s.*,
       CASE
           WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
           WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
           WHEN r_score >= 4 AND f_score = 1 THEN 'New Customers'
           WHEN r_score >= 4 AND f_score IN (2, 3) THEN 'Potential Loyalists'
           WHEN r_score = 3 THEN 'Needs Attention'
           WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
           WHEN r_score = 2 THEN 'Hibernating'
           ELSE 'Lost'
       END AS segment
FROM rfm_scores s;

-- SEGMENT SUMMARY

SELECT segment,
       COUNT(*) AS customers,
       ROUND(AVG(recency_days), 1) AS avg_recency,
       ROUND(AVG(frequency), 1) AS avg_frequency,
       ROUND(AVG(monetary), 1) AS avg_monetary,
       ROUND(SUM(monetary), 0) AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;

-- CAMPAIGN ENGAGEMENT BY SEGMENT

SELECT COALESCE(g.segment, 'No delivered order') AS segment,
       COUNT(*) AS sends,
       SUM(r.opened = 'Yes') AS opens,
       SUM(r.clicked = 'Yes') AS clicks,
       SUM(r.converted = 'Yes') AS conversions,
       ROUND(100 * SUM(r.opened = 'Yes') / COUNT(*), 1) AS open_rate,
       ROUND(100 * SUM(r.clicked = 'Yes') / COUNT(*), 1) AS click_rate,
       ROUND(100 * SUM(r.converted = 'Yes') / COUNT(*), 1) AS conversion_rate
FROM stg_campaign_responses_clean r
LEFT JOIN rfm_segments g ON g.customer_id = r.customer_id
GROUP BY 1
ORDER BY sends DESC;

-- EXPORT QUERY: rfm_segments

SELECT customer_id, recency_days, frequency, monetary,
       r_score, f_score, m_score, segment
FROM rfm_segments
ORDER BY customer_id;