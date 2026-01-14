/*
===============================================================================
📂 Advanced Sales Analysis
===============================================================================
Project Overview:
This script performs a deep dive into sales data to uncover performance trends, 
customer behaviors, and product profitability. It moves beyond basic aggregations 
to provide strategic insights for decision-making using advanced SQL techniques.

Analysis Methods:
- Change-over-Time Analysis
- Cumulative Analysis
- Performance Analysis
- Proportional Analysis
- Data Segmentation

Technical Stack: 
- Window Functions (SUM OVER, AVG OVER, LAG)
- CTEs (Common Table Expressions)
- Date Manipulations
- Nested Queries
===============================================================================
*/

/*
-------------------------------------------------------------------------------
1. Change Over Time Analysis
-------------------------------------------------------------------------------
Objective: To track sales velocity and customer traffic trends across different time horizons.
Business Value: Helps in identifying seasonality peaks and analyzing long-term growth patterns.
*/

-- Analysis 1.1: Standard Analysis (Year & Month components)
SELECT
    YEAR(order_date) as order_year,
    MONTH(order_date) as order_month,
    SUM(sales_amount) as total_Sales,
    COUNT(DISTINCT customer_key) as total_customers,
    SUM(quantity) as total_quantitiy
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

-- Analysis 1.2: Truncated Date Analysis (Cleaner Timeline for Visualization)
SELECT
    DATETRUNC(month, order_date) as order_date,
    SUM(sales_amount) as total_Sales,
    COUNT(DISTINCT customer_key) as total_customers,
    SUM(quantity) as total_quantitiy
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);

/*
💡 Key Insight:
By utilizing DATETRUNC, we standardize the reporting period. This makes it easier to 
visualize seasonality (e.g., spikes in Q4 due to holidays) vs. organic monthly growth.
*/


/*
-------------------------------------------------------------------------------
2. Cumulative Analysis (Running Totals)
-------------------------------------------------------------------------------
Objective: To visualize the aggregate growth trajectory of the business over time.
Business Value: A running total helps stakeholders understand the overall momentum 
and financial health of the company better than simple monthly snapshots.
*/

SELECT
    order_date,
    total_sales,
    -- Calculate cumulative sales over time using Window Functions
    SUM(total_sales) OVER (ORDER BY order_date) as running_total_sales,
    -- Smooth out price fluctuations using moving average
    AVG(avg_price) OVER (ORDER BY order_date) as moving_averages_price
FROM
(
    -- Subquery: Aggregate data by Year first to simplify the outer window function
    SELECT
        DATETRUNC(year, order_date) as order_date,
        SUM(sales_amount) as total_sales,
        AVG(price) as avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
) t;

/*
💡 Key Insight:
The Running Total confirms if the business is maintaining an upward trajectory. 
The Moving Average Price helps detect if we are gradually discounting products too heavily 
or successfully increasing our Average Selling Price (ASP) over years.
*/


/*
-------------------------------------------------------------------------------
3. Product Performance Analysis (Year-over-Year)
-------------------------------------------------------------------------------
Objective: To benchmark product performance against average standards and calculate YoY growth.
Business Value: Identifies "Star" products vs "Laggards" and flags distinct changes 
in performance compared to the previous year.
*/

WITH yearly_product_sales as (
    SELECT
        YEAR(f.order_date) as order_year,
        p.product_name,
        SUM(f.sales_amount) as current_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
)
SELECT
    order_year,
    product_name,
    current_sales,
    
    -- Compare current sales against average performance for this product
    AVG(current_sales) OVER (PARTITION BY product_name) as avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) as diff_avg,
    CASE 
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END avg_change,
    
    -- Year-Over-Year Analysis using LAG function
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) py_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) as diff_py,
    CASE 
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;

/*
💡 Key Insight:
Using LAG(), we created a dynamic YoY Growth metric. This instantly flags products 
with declining sales ("Decrease"), signaling the need for inventory review or marketing intervention.
*/


/*
-------------------------------------------------------------------------------
4. Proportional Analysis (Part-to-Whole)
-------------------------------------------------------------------------------
Objective: To determine market share per category.
Business Value: Assists in resource allocation by identifying which categories 
drive the majority of revenue (Pareto Principle).
*/

WITH category_sales as (
    SELECT
        category,
        SUM(sales_amount) as total_sales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
    GROUP BY category
)
SELECT
    category,
    total_sales,
    -- Calculate Grand Total across all result sets (empty OVER clause)
    SUM(total_sales) OVER () overall_sales,
    -- Calculate Percentage Share
    CONCAT(ROUND((CAST (total_sales as FLOAT) / SUM(total_sales) OVER ())*100, 2), '%') as percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;

/*
💡 Key Insight:
Calculates the exact contribution of each category. Strategies should focus on protecting 
the core assets (top categories contributing >80% revenue).
*/


/*
-------------------------------------------------------------------------------
5. Strategic Segmentation (Product & Customer)
-------------------------------------------------------------------------------
Objective: To group data into meaningful clusters for targeted strategies.
Business Value: Enables personalized marketing (for customers) and portfolio optimization (for products).
*/

-- A. Product Cost Segmentation
WITH product_segments AS(
    SELECT
        product_key,
        product_name,
        cost,
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END cost_range
    FROM gold.dim_products
)
SELECT
    cost_range,
    COUNT(product_key) as total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;


-- B. Customer Value Segmentation (RFM approach)
WITH customer_spending as (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) as total_spending,
        MIN(order_date) as first_order,
        MAX(order_date) as last_order,
        -- Calculate Customer Lifespan in Months
        DATEDIFF(month, MIN(order_date), MAX(order_date)) as lifespan
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT
    customer_segment,
    COUNT(customer_key) as total_customers
FROM (
    SELECT
        customer_key,
        CASE 
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END customer_segment
    FROM customer_spending 
) t
GROUP BY customer_segment
ORDER BY total_customers DESC;

/*
💡 Key Insight:
- VIPs: High spenders with >12 months history. Action: Loyalty programs.
- New: Low lifespan. Action: Onboarding campaigns to increase retention.
*/