-- =====================================================
-- CUSTOMER CHURN ANALYSIS - CHURN QUERIES (MySQL 8+)
-- =====================================================
-- CHURN DEFINITION
--   A customer is CHURNED if churn_records has a row with churn_status = 'Churned'.
--   'At Risk' rows are customers still subscribed but flagged as likely to leave.
-- =====================================================

USE customer_churn_analysis;

-- -----------------------------------------------------
-- 0. Feature view: one row per subscribed customer
--    Aggregates are computed in separate subqueries so joins never multiply rows.
-- -----------------------------------------------------
CREATE OR REPLACE VIEW customer_churn_features AS
SELECT
    c.customer_id,
    c.age,
    c.gender,
    c.city,
    p.plan_name,
    p.monthly_fee,
    DATEDIFF(COALESCE(s.end_date, CURDATE()), s.start_date)  AS tenure_days,
    COALESCE(pay.total_payments, 0)                          AS total_payments,
    COALESCE(pay.failed_payments, 0)                         AS failed_payments,
    COALESCE(pay.failed_payments * 1.0 / NULLIF(pay.total_payments, 0), 0) AS failed_payment_rate,
    COALESCE(t.total_tickets, 0)                             AS total_tickets,
    COALESCE(t.unresolved_tickets, 0)                        AS unresolved_tickets,
    CASE WHEN cr.customer_id IS NOT NULL THEN 1 ELSE 0 END   AS churned
FROM customers c
JOIN subscriptions s ON s.customer_id = c.customer_id
JOIN plans p         ON p.plan_id = s.plan_id
LEFT JOIN (
    SELECT subscription_id,
           COUNT(*) AS total_payments,
           SUM(payment_status = 'Failed') AS failed_payments
    FROM payments
    GROUP BY subscription_id
) pay ON pay.subscription_id = s.subscription_id
LEFT JOIN (
    SELECT customer_id,
           COUNT(*) AS total_tickets,
           SUM(resolution_status <> 'Resolved') AS unresolved_tickets
    FROM support_tickets
    GROUP BY customer_id
) t ON t.customer_id = c.customer_id
LEFT JOIN (
    SELECT DISTINCT customer_id
    FROM churn_records
    WHERE churn_status = 'Churned'
) cr ON cr.customer_id = c.customer_id;

-- -----------------------------------------------------
-- 1. Overall churn rate
-- -----------------------------------------------------
SELECT
    COUNT(*)                                  AS subscribed_customers,
    SUM(churned)                              AS churned_customers,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2)   AS churn_rate_pct
FROM customer_churn_features;

-- -----------------------------------------------------
-- 2. Churn by plan
-- -----------------------------------------------------
SELECT plan_name,
       COUNT(*)                                AS customers,
       SUM(churned)                            AS churned,
       ROUND(100.0 * SUM(churned) / COUNT(*), 2) AS churn_rate_pct
FROM customer_churn_features
GROUP BY plan_name
ORDER BY churn_rate_pct DESC;

-- -----------------------------------------------------
-- 3. Churn by city
-- -----------------------------------------------------
SELECT city,
       COUNT(*)                                AS customers,
       SUM(churned)                            AS churned,
       ROUND(100.0 * SUM(churned) / COUNT(*), 2) AS churn_rate_pct
FROM customer_churn_features
GROUP BY city
ORDER BY churn_rate_pct DESC;

-- -----------------------------------------------------
-- 4. Churn by age group
-- -----------------------------------------------------
SELECT
    CASE WHEN age < 25 THEN 'Under 25'
         WHEN age BETWEEN 25 AND 34 THEN '25-34'
         WHEN age BETWEEN 35 AND 44 THEN '35-44'
         WHEN age BETWEEN 45 AND 54 THEN '45-54'
         ELSE '55+' END AS age_group,
    COUNT(*)                                AS customers,
    SUM(churned)                            AS churned,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2) AS churn_rate_pct
FROM customer_churn_features
GROUP BY age_group
ORDER BY MIN(age);

-- -----------------------------------------------------
-- 5. Churn by gender
-- -----------------------------------------------------
SELECT gender,
       COUNT(*)                                AS customers,
       SUM(churned)                            AS churned,
       ROUND(100.0 * SUM(churned) / COUNT(*), 2) AS churn_rate_pct
FROM customer_churn_features
GROUP BY gender;

-- -----------------------------------------------------
-- 6. Churn reasons
-- -----------------------------------------------------
SELECT churn_reason,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_churn
FROM churn_records
WHERE churn_status = 'Churned'
GROUP BY churn_reason
ORDER BY customers DESC;

-- -----------------------------------------------------
-- 7. Tenure: average months before churn vs. months retained so far
-- -----------------------------------------------------
SELECT
    CASE WHEN churned = 1 THEN 'Churned' ELSE 'Retained' END AS segment,
    ROUND(AVG(tenure_days) / 30.44, 1)                       AS avg_tenure_months
FROM customer_churn_features
GROUP BY churned;

-- -----------------------------------------------------
-- 8. Failed payments: churned vs retained
-- -----------------------------------------------------
SELECT
    CASE WHEN churned = 1 THEN 'Churned' ELSE 'Retained' END AS segment,
    ROUND(100.0 * AVG(failed_payment_rate), 2)                 AS avg_failed_payment_pct,
    ROUND(AVG(failed_payments), 2)                           AS avg_failed_payments
FROM customer_churn_features
GROUP BY churned;

-- -----------------------------------------------------
-- 9. Support tickets: churned vs retained
-- -----------------------------------------------------
SELECT
    CASE WHEN churned = 1 THEN 'Churned' ELSE 'Retained' END AS segment,
    ROUND(AVG(total_tickets), 2)                             AS avg_tickets,
    ROUND(AVG(unresolved_tickets), 2)                        AS avg_unresolved_tickets
FROM customer_churn_features
GROUP BY churned;

-- Churn rate by number of tickets raised
SELECT
    LEAST(total_tickets, 3)                 AS tickets_raised_cap3,
    COUNT(*)                                AS customers,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2) AS churn_rate_pct
FROM customer_churn_features
GROUP BY tickets_raised_cap3
ORDER BY tickets_raised_cap3;

-- Churn rate by failed-payment band
SELECT
    CASE WHEN failed_payment_rate = 0   THEN '0%'
         WHEN failed_payment_rate < 0.1 THEN '<10%'
         WHEN failed_payment_rate < 0.2 THEN '10-20%'
         ELSE '20%+' END AS failed_payment_band,
    COUNT(*)                                AS customers,
    ROUND(100.0 * SUM(churned) / COUNT(*), 2) AS churn_rate_pct
FROM customer_churn_features
GROUP BY failed_payment_band
ORDER BY MIN(failed_payment_rate);

-- -----------------------------------------------------
-- 10. Monthly churn trend
-- -----------------------------------------------------
SELECT DATE_FORMAT(churn_date, '%Y-%m') AS churn_month,
       COUNT(*)                         AS churned_customers
FROM churn_records
WHERE churn_status = 'Churned' AND churn_date IS NOT NULL
GROUP BY churn_month
ORDER BY churn_month;

-- -----------------------------------------------------
-- 11. Revenue impact (monthly fee of churned vs at-risk customers)
-- -----------------------------------------------------
SELECT cr.churn_status,
       COUNT(DISTINCT cr.customer_id) AS customers,
       SUM(p.monthly_fee)             AS monthly_revenue
FROM churn_records cr
JOIN subscriptions s ON s.customer_id = cr.customer_id
JOIN plans p         ON p.plan_id = s.plan_id
GROUP BY cr.churn_status;

-- -----------------------------------------------------
-- 12. At-risk watchlist: active customers with warning signs
--     (simple rule-based score; the ML model in src/train_model.py refines this)
-- -----------------------------------------------------
SELECT *
FROM (
    SELECT f.customer_id, c.customer_name, f.plan_name, f.city,
           ROUND(f.failed_payment_rate, 3) AS failed_payment_rate,
           f.total_tickets, f.unresolved_tickets,
           ( (f.failed_payment_rate >= 0.15)
           + (f.unresolved_tickets >= 1)
           + (f.total_tickets >= 3)
           + (f.plan_name = 'Basic') ) AS risk_flags
    FROM customer_churn_features f
    JOIN customers c ON c.customer_id = f.customer_id
    WHERE f.churned = 0
) scored
WHERE risk_flags >= 2
ORDER BY risk_flags DESC, failed_payment_rate DESC;

-- -----------------------------------------------------
-- 13. Customers with no subscription (prospects)
-- -----------------------------------------------------
SELECT c.customer_id, c.customer_name, c.city
FROM customers c
LEFT JOIN subscriptions s ON s.customer_id = c.customer_id
WHERE s.subscription_id IS NULL;
