/*
===============================================================================
📂 Customer Report
===============================================================================
Project Overview:
This script creates a consolidated "Customer Report" View (`gold.report_customers`).
It serves as a central data source for CRM and Marketing dashboards.

Key Features:
- 360-Degree View: Combines demographic data with transactional behavior.
- Segmentation: Automatically classifies customers into VIP, Regular, and New groups.
- KPI Calculation: Computes critical metrics like Recency, Average Order Value (AOV), 
  and Customer Lifespan.

Technical Stack: 
- SQL Views for Data Abstraction
- CTEs for modular logic (Base -> Aggregate -> Calculate)
- Conditional Logic (CASE WHEN) for segmentation
===============================================================================
*/

CREATE VIEW gold.report_customers AS

/*
-------------------------------------------------------------------------------
Step 1: Base Query
-------------------------------------------------------------------------------
Objective: Gather raw transaction data and link it with customer demographics.
Calculates dynamic fields like 'Age' based on birthdate.
*/
WITH base_query AS(
    SELECT
        f.order_number,
        f.product_key,
        f.sales_amount,
        f.quantity,
        f.order_date,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) as customer_name,
        DATEDIFF(year, c.birthdate, GETDATE()) as age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
    WHERE order_date IS NOT NULL
)

/*
-------------------------------------------------------------------------------
Step 2: Customer Aggregation
-------------------------------------------------------------------------------
Objective: Summarize metrics at the customer level (Granularity Change).
This step calculates the "Total" metrics needed for lifetime value analysis.
*/
, customer_aggregation as(
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) as total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) as total_products,
        MAX(order_date) as last_order_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) as lifespan
    FROM base_query
    GROUP BY
        customer_key,
        customer_number,
        customer_name,
        age
)

/*
-------------------------------------------------------------------------------
Step 3: Segmentation & Final KPI Calculation
-------------------------------------------------------------------------------
Objective: Derive actionable insights (Segments & Ratios) from the aggregated data.
*/
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    
    -- Demographic Segmentation
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END as age_group,
    
    -- Business Value Segmentation (Logic: Tenure + Spending)
    CASE 
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END as customer_segment,
    
    last_order_date,
    
    -- Recency: Months since last purchase (Crucial for Churn Analysis)
    DATEDIFF(month, last_order_date, GETDATE()) as recency,
    
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    
    -- Average Order Value (AOV): Efficiency of each transaction
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END as avg_order_value,
    
    -- Average Monthly Spend: Value of customer over time
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END as avg_monthly_spend
FROM customer_aggregation;

/*
💡 Key Insight from this View:
1. Segmentation: Enables the marketing team to target "VIPs" differently from "New" customers.
2. Recency: A high recency value indicates a customer is "At Risk" of churning.
3. AOV vs. Frequency: Distinguishes between customers who buy often (low AOV) vs. 
   customers who buy big (high AOV).
*/