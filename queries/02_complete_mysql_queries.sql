
-- =====================================================
-- CUSTOMER CHURN ANALYSIS
-- COMPLETE MYSQL PROJECT QUERIES
-- =====================================================

USE customer_churn_analysis;

-- =====================================================
-- 1. DATABASE VERIFICATION
-- =====================================================

SHOW DATABASES;
SELECT DATABASE();
SHOW TABLES;

SELECT 'customers' AS table_name, COUNT(*) AS total FROM customers
UNION ALL
SELECT 'plans', COUNT(*) FROM plans
UNION ALL
SELECT 'services', COUNT(*) FROM services
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets
UNION ALL
SELECT 'churn_records', COUNT(*) FROM churn_records;


-- =====================================================
-- 2. BASIC SQL QUERIES
-- =====================================================

SELECT * FROM customers;
SELECT * FROM plans;
SELECT * FROM services;
SELECT * FROM subscriptions;
SELECT * FROM payments;
SELECT * FROM support_tickets;
SELECT * FROM churn_records;

SELECT customer_id, customer_name, age, city FROM customers;
SELECT * FROM customers WHERE city = 'Hyderabad';
SELECT * FROM customers WHERE age > 25;
SELECT * FROM customers WHERE age BETWEEN 20 AND 40;
SELECT * FROM customers WHERE city IN ('Hyderabad', 'Bangalore');
SELECT * FROM customers WHERE customer_name LIKE 'R%';
SELECT * FROM customers WHERE email IS NOT NULL;
SELECT DISTINCT city FROM customers;
SELECT * FROM customers ORDER BY age ASC;
SELECT * FROM customers ORDER BY age DESC;
SELECT * FROM customers LIMIT 5;

SELECT * FROM plans WHERE monthly_fee > 500;
SELECT * FROM payments WHERE payment_status = 'Success';


-- =====================================================
-- 3. AGGREGATE FUNCTIONS
-- =====================================================

SELECT COUNT(*) AS total_customers FROM customers;
SELECT AVG(age) AS average_age FROM customers;
SELECT MIN(age) AS minimum_age FROM customers;
SELECT MAX(age) AS maximum_age FROM customers;

SELECT SUM(monthly_fee) AS total_plan_fees FROM plans;
SELECT AVG(monthly_fee) AS average_plan_fee FROM plans;
SELECT MAX(monthly_fee) AS highest_plan_fee FROM plans;
SELECT MIN(monthly_fee) AS lowest_plan_fee FROM plans;

SELECT SUM(payment_amount) AS total_payments FROM payments;
SELECT AVG(payment_amount) AS average_payment FROM payments;
SELECT MAX(payment_amount) AS highest_payment FROM payments;
SELECT MIN(payment_amount) AS lowest_payment FROM payments;

SELECT COUNT(*) AS total_tickets FROM support_tickets;
SELECT COUNT(*) AS active_subscriptions
FROM subscriptions
WHERE subscription_status = 'Active';


-- =====================================================
-- 4. GROUP BY AND HAVING
-- =====================================================

SELECT city, COUNT(*) AS total_customers
FROM customers
GROUP BY city;

SELECT gender, COUNT(*) AS total_customers
FROM customers
GROUP BY gender;

SELECT plan_id, COUNT(*) AS total_subscriptions
FROM subscriptions
GROUP BY plan_id;

SELECT subscription_status, COUNT(*) AS total_subscriptions
FROM subscriptions
GROUP BY subscription_status;

SELECT payment_status, COUNT(*) AS total_payments
FROM payments
GROUP BY payment_status;

SELECT issue_category, COUNT(*) AS total_tickets
FROM support_tickets
GROUP BY issue_category;

SELECT city, COUNT(*) AS total_customers
FROM customers
GROUP BY city
HAVING COUNT(*) > 1;


-- =====================================================
-- 5. JOINS
-- =====================================================

-- INNER JOIN
SELECT c.customer_name, s.subscription_id, s.subscription_status
FROM customers c
INNER JOIN subscriptions s
ON c.customer_id = s.customer_id;

-- LEFT JOIN
SELECT c.customer_name, s.subscription_id
FROM customers c
LEFT JOIN subscriptions s
ON c.customer_id = s.customer_id;

-- RIGHT JOIN
SELECT c.customer_name, s.subscription_id
FROM customers c
RIGHT JOIN subscriptions s
ON c.customer_id = s.customer_id;

-- CROSS JOIN
SELECT c.customer_name, p.plan_name
FROM customers c
CROSS JOIN plans p;

-- CUSTOMER + SUBSCRIPTION + PLAN
SELECT
    c.customer_name,
    p.plan_name,
    p.monthly_fee,
    s.start_date,
    s.subscription_status
FROM customers c
INNER JOIN subscriptions s
ON c.customer_id = s.customer_id
INNER JOIN plans p
ON s.plan_id = p.plan_id;

-- SUBSCRIPTION + PAYMENT
SELECT
    s.subscription_id,
    s.subscription_status,
    p.payment_amount,
    p.payment_date,
    p.payment_status
FROM subscriptions s
LEFT JOIN payments p
ON s.subscription_id = p.subscription_id;

-- CUSTOMER + SUPPORT TICKETS
SELECT
    c.customer_name,
    t.issue_category,
    t.resolution_status
FROM customers c
LEFT JOIN support_tickets t
ON c.customer_id = t.customer_id;

-- CUSTOMER + CHURN RECORDS
SELECT
    c.customer_name,
    cr.churn_status,
    cr.churn_date,
    cr.churn_reason
FROM customers c
LEFT JOIN churn_records cr
ON c.customer_id = cr.customer_id;


-- =====================================================
-- 6. SUBQUERIES
-- =====================================================

-- Customers older than average age
SELECT *
FROM customers
WHERE age > (SELECT AVG(age) FROM customers);

-- Plans above average monthly fee
SELECT *
FROM plans
WHERE monthly_fee > (SELECT AVG(monthly_fee) FROM plans);

-- Customers having subscriptions
SELECT *
FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM subscriptions
);

-- Customers without subscriptions
SELECT *
FROM customers
WHERE customer_id NOT IN (
    SELECT customer_id
    FROM subscriptions
    WHERE customer_id IS NOT NULL
);

-- Payments greater than average payment
SELECT *
FROM payments
WHERE payment_amount > (
    SELECT AVG(payment_amount) FROM payments
);

-- Correlated subquery: customers with at least one ticket
SELECT *
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM support_tickets t
    WHERE t.customer_id = c.customer_id
);


-- =====================================================
-- 7. CASE STATEMENTS
-- =====================================================

SELECT
    customer_name,
    age,
    CASE
        WHEN age < 25 THEN 'Young'
        WHEN age BETWEEN 25 AND 40 THEN 'Adult'
        WHEN age > 40 THEN 'Senior'
        ELSE 'Unknown'
    END AS age_group
FROM customers;

SELECT
    subscription_id,
    subscription_status,
    CASE
        WHEN subscription_status = 'Active' THEN 'Current'
        WHEN subscription_status = 'Expired' THEN 'Ended'
        ELSE 'Other'
    END AS status_description
FROM subscriptions;

SELECT
    payment_id,
    payment_amount,
    CASE
        WHEN payment_amount >= 1000 THEN 'High'
        WHEN payment_amount >= 500 THEN 'Medium'
        ELSE 'Low'
    END AS payment_category
FROM payments;


-- =====================================================
-- 8. STRING, DATE AND NUMERICAL FUNCTIONS
-- =====================================================

-- STRING FUNCTIONS
SELECT UPPER(customer_name) AS uppercase_name FROM customers;
SELECT LOWER(customer_name) AS lowercase_name FROM customers;
SELECT LENGTH(customer_name) AS name_length FROM customers;
SELECT CONCAT(customer_name, ' - ', city) AS customer_details
FROM customers;
SELECT TRIM(customer_name) AS trimmed_name FROM customers;
SELECT SUBSTRING(customer_name, 1, 3) AS short_name FROM customers;

-- DATE FUNCTIONS
SELECT CURDATE() AS today;
SELECT NOW() AS current_datetime;
SELECT YEAR(registration_date) AS registration_year FROM customers;
SELECT MONTH(registration_date) AS registration_month FROM customers;
SELECT DATEDIFF(CURDATE(), registration_date) AS customer_days
FROM customers
WHERE registration_date IS NOT NULL;

-- NUMERICAL FUNCTIONS
SELECT ROUND(monthly_fee, 0) AS rounded_fee FROM plans;
SELECT CEIL(monthly_fee) AS ceiling_fee FROM plans;
SELECT FLOOR(monthly_fee) AS floor_fee FROM plans;
SELECT ABS(-100) AS absolute_value;
SELECT MOD(10, 3) AS remainder;
SELECT POWER(2, 3) AS power_result;


-- =====================================================
-- 9. VIEWS
-- =====================================================

CREATE OR REPLACE VIEW customer_subscription_view AS
SELECT
    c.customer_id,
    c.customer_name,
    c.city,
    s.subscription_id,
    s.subscription_status,
    p.plan_name,
    p.monthly_fee
FROM customers c
LEFT JOIN subscriptions s
ON c.customer_id = s.customer_id
LEFT JOIN plans p
ON s.plan_id = p.plan_id;

CREATE OR REPLACE VIEW payment_details_view AS
SELECT
    p.payment_id,
    p.payment_date,
    p.payment_amount,
    p.payment_status,
    s.subscription_id,
    s.customer_id
FROM payments p
LEFT JOIN subscriptions s
ON p.subscription_id = s.subscription_id;

CREATE OR REPLACE VIEW support_details_view AS
SELECT
    c.customer_name,
    t.ticket_id,
    t.issue_category,
    t.resolution_status,
    t.ticket_date
FROM customers c
LEFT JOIN support_tickets t
ON c.customer_id = t.customer_id;

-- Display views
SELECT * FROM customer_subscription_view;
SELECT * FROM payment_details_view;
SELECT * FROM support_details_view;

SHOW FULL TABLES
WHERE TABLE_TYPE = 'VIEW';


-- =====================================================
-- 10. INDEXES
-- =====================================================

-- Check existing indexes
SHOW INDEX FROM customers;
SHOW INDEX FROM subscriptions;
SHOW INDEX FROM payments;

-- Create indexes only if they do not already exist

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'customers'
     AND INDEX_NAME = 'idx_customers_city') = 0,
    'CREATE INDEX idx_customers_city ON customers(city)',
    'SELECT "Customer city index already exists"'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'subscriptions'
     AND INDEX_NAME = 'idx_subscriptions_status') = 0,
    'CREATE INDEX idx_subscriptions_status ON subscriptions(subscription_status)',
    'SELECT "Subscription status index already exists"'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = 'payments'
     AND INDEX_NAME = 'idx_payments_date') = 0,
    'CREATE INDEX idx_payments_date ON payments(payment_date)',
    'SELECT "Payment date index already exists"'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;



-- =====================================================
-- 11. STORED PROCEDURES
-- =====================================================

DROP PROCEDURE IF EXISTS GetAllCustomers;
DROP PROCEDURE IF EXISTS GetCustomersByCity;
DROP PROCEDURE IF EXISTS GetCustomerSubscriptionDetails;

DELIMITER $$

CREATE PROCEDURE GetAllCustomers()
BEGIN
    SELECT * FROM customers;
END $$

CREATE PROCEDURE GetCustomersByCity(IN input_city VARCHAR(50))
BEGIN
    SELECT *
    FROM customers
    WHERE city = input_city;
END $$

CREATE PROCEDURE GetCustomerSubscriptionDetails(IN input_id INT)
BEGIN
    SELECT
        c.customer_name,
        s.subscription_id,
        s.subscription_status,
        p.plan_name
    FROM customers c
    LEFT JOIN subscriptions s
        ON c.customer_id = s.customer_id
    LEFT JOIN plans p
        ON s.plan_id = p.plan_id
    WHERE c.customer_id = input_id;
END $$

DELIMITER ;

-- Execute procedures
CALL GetAllCustomers();
CALL GetCustomersByCity('Hyderabad');
CALL GetCustomerSubscriptionDetails(1);

-- =====================================================
-- 12. STORED FUNCTION
-- =====================================================

DROP FUNCTION IF EXISTS GetTotalCustomerPayments;

DELIMITER $$

CREATE FUNCTION GetTotalCustomerPayments(input_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE total_amount DECIMAL(10,2);

    SELECT COALESCE(SUM(p.payment_amount), 0)
    INTO total_amount
    FROM payments p
    INNER JOIN subscriptions s
        ON p.subscription_id = s.subscription_id
    WHERE s.customer_id = input_id;

    RETURN total_amount;
END $$

DELIMITER ;

-- Execute function
SELECT
    customer_id,
    customer_name,
    GetTotalCustomerPayments(customer_id) AS total_payments
FROM customers;



-- =====================================================
-- 13. TRIGGER
-- =====================================================

-- Create an additional helper table for trigger demonstration
CREATE TABLE IF NOT EXISTS payment_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    payment_id INT,
    action_type VARCHAR(30),
    action_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Remove the old trigger before recreating it
DROP TRIGGER IF EXISTS after_payment_insert;

DELIMITER $$

CREATE TRIGGER after_payment_insert
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    INSERT INTO payment_audit(payment_id, action_type)
    VALUES (NEW.payment_id, 'INSERT');
END $$

DELIMITER ;

-- Verify trigger
SHOW TRIGGERS;

-- View audit records
SELECT * FROM payment_audit;

-- =====================================================
-- 14. TCL COMMANDS
-- =====================================================

-- Temporary table for TCL demonstration
DROP TEMPORARY TABLE IF EXISTS transaction_demo;

CREATE TEMPORARY TABLE transaction_demo (
    id INT PRIMARY KEY,
    description VARCHAR(100)
);

-- Start transaction
START TRANSACTION;

INSERT INTO transaction_demo
VALUES (1, 'First record');

SAVEPOINT sp1;

INSERT INTO transaction_demo
VALUES (2, 'Second record');

-- Roll back only the second insertion
ROLLBACK TO SAVEPOINT sp1;

-- Check remaining record
SELECT * FROM transaction_demo;

-- Commit transaction
COMMIT;

-- Clean up
DROP TEMPORARY TABLE IF EXISTS transaction_demo;

-- =====================================================
-- 15. NORMALIZATION - EXAMPLE
-- =====================================================

-- Display table structures
DESCRIBE customers;
DESCRIBE plans;
DESCRIBE services;
DESCRIBE subscriptions;
DESCRIBE payments;
DESCRIBE support_tickets;
DESCRIBE churn_records;

-- Display table relationships
SHOW CREATE TABLE subscriptions;
SHOW CREATE TABLE payments;
SHOW CREATE TABLE support_tickets;
SHOW CREATE TABLE churn_records;

-- Normalization concepts:
-- 1NF: Each column contains atomic values.
-- 2NF: Non-key attributes depend on the complete primary key.
-- 3NF: Non-key attributes do not depend on other non-key attributes.


-- =====================================================
-- 16. CUSTOMER CHURN ANALYSIS
-- =====================================================

-- 1. Total customers
SELECT COUNT(*) AS total_customers
FROM customers;

-- 2. Active subscriptions
SELECT COUNT(*) AS active_subscriptions
FROM subscriptions
WHERE subscription_status = 'Active';

-- 3. Expired subscriptions
SELECT COUNT(*) AS expired_subscriptions
FROM subscriptions
WHERE subscription_status = 'Expired';

-- 4. Churn status summary
SELECT churn_status, COUNT(*) AS total
FROM churn_records
GROUP BY churn_status;

-- 5. Churn reasons
SELECT churn_reason, COUNT(*) AS total
FROM churn_records
GROUP BY churn_reason;

-- 6. Customer payment summary
SELECT
    c.customer_id,
    c.customer_name,
    COALESCE(SUM(p.payment_amount), 0) AS total_payments
FROM customers c
LEFT JOIN subscriptions s
    ON c.customer_id = s.customer_id
LEFT JOIN payments p
    ON s.subscription_id = p.subscription_id
GROUP BY c.customer_id, c.customer_name;

-- 7. Customers with support tickets
SELECT
    c.customer_name,
    COUNT(st.ticket_id) AS total_tickets
FROM customers c
LEFT JOIN support_tickets st
    ON c.customer_id = st.customer_id
GROUP BY c.customer_id, c.customer_name;

-- 8. Subscription details
SELECT
    c.customer_name,
    p.plan_name,
    s.subscription_status,
    s.start_date,
    s.end_date
FROM customers c
INNER JOIN subscriptions s
    ON c.customer_id = s.customer_id
INNER JOIN plans p
    ON s.plan_id = p.plan_id;

-- 9. Customers without churn records
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN churn_records cr
    ON c.customer_id = cr.customer_id
WHERE cr.customer_id IS NULL;


-- =====================================================
-- 17. FINAL PROJECT VERIFICATION
-- =====================================================

-- Confirm database
SELECT DATABASE();

-- List all tables
SHOW TABLES;

-- Count records in all seven original tables
SELECT 'customers' AS table_name, COUNT(*) AS total FROM customers
UNION ALL
SELECT 'plans', COUNT(*) FROM plans
UNION ALL
SELECT 'services', COUNT(*) FROM services
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets
UNION ALL
SELECT 'churn_records', COUNT(*) FROM churn_records;

-- Verify views
SHOW FULL TABLES
WHERE Table_type = 'VIEW';

-- Verify procedures and functions
SHOW PROCEDURE STATUS
WHERE Db = DATABASE();

SHOW FUNCTION STATUS
WHERE Db = DATABASE();

-- Verify triggers
SHOW TRIGGERS;

-- Verify indexes
SHOW INDEX FROM customers;
SHOW INDEX FROM subscriptions;
SHOW INDEX FROM payments;

-- Final customer report
SELECT * FROM customers;
