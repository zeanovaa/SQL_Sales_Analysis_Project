/*
===============================================================================
📂 Product Report
===============================================================================
Project Overview:
This script creates the "Product Report" View (`gold.report_products`).
It provides a comprehensive overview of product performance, helping stakeholders 
identify high-value items and slow-moving inventory.

Key Features:
- Performance Segmentation: Categorizes products (High/Mid/Low) based on revenue.
- Pricing Analysis: Calculates Average Selling Price (ASP) to monitor discounting trends.
- Inventory Health: Tracks 'Recency' to identify obsolete or slow-moving products.

Technical Stack: 
- SQL Views for Reporting
- Aggregation with NULL handling (NULLIF)
- Date Difference functions for Lifecycle Analysis
===============================================================================
*/

CREATE VIEW gold.report_products AS

/*
-------------------------------------------------------------------------------
Step 1: Base Query
-------------------------------------------------------------------------------
Objective: Consolidate sales transactions with product details.
This prepares the raw data for granular analysis.
*/
WITH base_query AS(
    SELECT
        f.order_number,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        f.order_date,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
    WHERE order_date IS NOT NULL
)

/*
-------------------------------------------------------------------------------
Step 2: Product Aggregation
-------------------------------------------------------------------------------
Objective: Summarize performance metrics at the Product Level.
Includes a calculation for Average Selling Price (ASP) to track real-world pricing.
*/
, product_aggregation AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        SUM(sales_amount) as total_sales,
        SUM(quantity) as total_quantity,
        COUNT(DISTINCT order_number) as total_orders,
        COUNT(DISTINCT customer_key) as total_customers,
        MAX(order_date) as last_sale_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) as lifespan,
        -- Calculate ASP (Total Sales / Quantity) ensuring no division by zero
        ROUND(AVG(CAST(sales_amount as FLOAT) / NULLIF(quantity,0)), 2) AS avg_selling_price
    FROM base_query
    GROUP BY
        product_key,
        product_name,
        category,
        subcategory,
        cost
)

/*
-------------------------------------------------------------------------------
Step 3: Segmentation & Final KPI Calculation
-------------------------------------------------------------------------------
Objective: Classify products and derive advanced metrics for portfolio management.
*/
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    
    -- Recency: Months since last sale (Critical for Inventory Management)
    DATEDIFF(month, last_sale_date, GETDATE()) as recency_month,
    
    -- Product Segmentation based on Revenue Contribution
    CASE 
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,
    
    total_sales,
    total_quantity,
    total_orders,
    total_customers,
    lifespan,
    avg_selling_price,
    
    -- Average Order Revenue (AOR): How much revenue does this product typically generate per order?
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,
    
    -- Average Monthly Revenue: Income stability metric
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue
FROM product_aggregation;

/*
💡 Key Insight from this View:
1. Product Segmentation: Quickly identifies the "Cash Cows" (High-Performers) vs. items that may need to be delisted.
2. Recency: Products with high recency (e.g., > 6 months) may be obsolete or require clearance sales.
3. Average Selling Price: Comparing this against 'Cost' allows for margin analysis (not shown here but enabled by this view).
*/