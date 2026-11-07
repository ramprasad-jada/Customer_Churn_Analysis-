
USE customer_churn_analysis;

-- 1. Check all tables
SHOW TABLES;

-- 2. Check customers
SELECT * FROM customers;

-- 3. Check subscriptions
SELECT * FROM subscriptions;

-- 4. Check payments
SELECT * FROM payments;

-- 5. Check support tickets
SELECT * FROM support_tickets;

-- 6. Check churn records
SELECT * FROM churn_records;

-- 7. Count customers
SELECT COUNT(*) AS total_customers
FROM customers;

-- 8. Count churn records
SELECT COUNT(*) AS total_churn_records
FROM churn_records;

-- 9. Check payment table columns
DESCRIBE payments;

-- 10. Check subscription table columns
DESCRIBE subscriptions;


SELECT
    s.customer_id,
    p.payment_id,
    p.subscription_id,
    p.payment_date,
    p.payment_amount,
    p.payment_method,
    p.payment_status
FROM payments p
JOIN subscriptions s
    ON p.subscription_id = s.subscription_id
WHERE s.customer_id = 1;

SELECT COUNT(*) AS total_customers
FROM customers;

SELECT COUNT(*) AS total_subscriptions
FROM subscriptions;

SELECT COUNT(*) AS total_payments
FROM payments;

SELECT COUNT(*) AS total_tickets
FROM support_tickets;

SELECT COUNT(*) AS total_churn_records
FROM churn_records;

SELECT * FROM churn_records;