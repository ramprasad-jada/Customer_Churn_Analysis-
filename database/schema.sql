-- =====================================================
-- CUSTOMER CHURN ANALYSIS - DATABASE SCHEMA (MySQL 8+)
-- Reconstructed from the columns used in queries/*.sql
-- =====================================================

CREATE DATABASE IF NOT EXISTS customer_churn_analysis
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE customer_churn_analysis;

DROP TABLE IF EXISTS churn_records;
DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS services;
DROP TABLE IF EXISTS plans;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id        INT PRIMARY KEY,
    customer_name      VARCHAR(100) NOT NULL,
    age                INT CHECK (age BETWEEN 15 AND 100),
    gender             VARCHAR(10),
    city               VARCHAR(50),
    email              VARCHAR(120) UNIQUE,
    registration_date  DATE
) ENGINE=InnoDB;

CREATE TABLE plans (
    plan_id      INT PRIMARY KEY,
    plan_name    VARCHAR(50) NOT NULL,
    monthly_fee  DECIMAL(10,2) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE services (
    service_id    INT PRIMARY KEY,
    service_name  VARCHAR(50) NOT NULL,
    service_type  VARCHAR(50)
) ENGINE=InnoDB;

CREATE TABLE subscriptions (
    subscription_id      INT PRIMARY KEY,
    customer_id          INT NOT NULL,
    plan_id              INT NOT NULL,
    service_id           INT,
    start_date           DATE NOT NULL,
    end_date             DATE,
    subscription_status  VARCHAR(20) NOT NULL,   -- Active / Cancelled / Expired
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (plan_id)     REFERENCES plans(plan_id),
    FOREIGN KEY (service_id)  REFERENCES services(service_id)
) ENGINE=InnoDB;

CREATE TABLE payments (
    payment_id       INT PRIMARY KEY,
    subscription_id  INT NOT NULL,
    payment_date     DATE NOT NULL,
    payment_amount   DECIMAL(10,2) NOT NULL,
    payment_method   VARCHAR(30),
    payment_status   VARCHAR(20) NOT NULL,       -- Success / Failed / Pending
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(subscription_id)
) ENGINE=InnoDB;

CREATE TABLE support_tickets (
    ticket_id          INT PRIMARY KEY,
    customer_id        INT NOT NULL,
    issue_category     VARCHAR(50),
    resolution_status  VARCHAR(20),              -- Resolved / Open / Escalated / Pending
    ticket_date        DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;

CREATE TABLE churn_records (
    churn_id      INT PRIMARY KEY,
    customer_id   INT NOT NULL,
    churn_status  VARCHAR(20) NOT NULL,          -- Churned / At Risk
    churn_date    DATE,
    churn_reason  VARCHAR(100),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
) ENGINE=InnoDB;
