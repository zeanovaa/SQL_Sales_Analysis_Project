# Sales & Customer Analytics Data Warehouse

## Project Overview

This project involves building a Data Warehouse solution using SQL Server (T-SQL) to analyze sales performance, customer behavior, and product trends. The goal is to transform raw sales data into actionable business insights, facilitating data-driven decision-making for marketing and inventory management.

## Business Impact & Insights

This analysis provides the following strategic value:

- **Customer Retention**  
  Identified "VIP" vs. "Reguler" vs. "New" customers through RFM (Recency, Frequency, Monetary) segmentation, enabling targeted retention strategies.

- **Product Optimization**  
  Classified inventory into "High-Performer", "Mid-Range", and "Low-Performer" categories to optimize stock levels and pricing strategies.

- **Trend Analysis**  
  Uncovered seasonality and year-over-year growth patterns to forecast demand more accurately.

## Technical Stack

**Database**  
Microsoft SQL Server

**SQL Skills**

- Advanced Analysis: Window Functions (`OVER`, `RANK`, `LAG`), CTEs, and Subqueries  
- Data Modeling: Star Schema design (Fact & Dimension tables)  
- ETL: Bulk inserts and data type handling  
- Reporting: Creating SQL Views for persistent reporting layers  

## Repository Structure

````
├── flat-files/ # Raw CSV data files
│ ├── dim_customers.csv
│ ├── dim_products.csv
│ └── fact_sales.csv
├── scripts/ # SQL Source Code
│ ├── init_database.sql # Database creation & data loading
│ ├── 1_advanced_analysis.sql # Ad-hoc analytical queries
│ ├── 2_customer_report.sql # View: Consolidated customer metrics
│ └── 3_product_report.sql # View: Consolidated product metrics
└── README.md
````

## Database Schema

The project uses a Star Schema architecture optimized for analytics:

- **gold.fact_sales**  
  Transactional data (Sales, Quantity, Dates)

- **gold.dim_customers**  
  Customer demographics and attributes

- **gold.dim_products**  
  Product hierarchy (Category, Subcategory) and costs

## Key Analysis Modules

### 1. Advanced Sales Analysis

Focuses on time-series analysis and growth metrics.

- **Features**: Year-over-Year growth calculation, cumulative sales (running totals), and proportional analysis  
- **Value**: Determines the overall health and trajectory of the sales pipeline  

### 2. Customer Report View

A consolidated view for CRM and Marketing teams.

- **Features**: Aggregates total spend, order frequency, and calculates customer lifespan  
- **Logic**: Segments customers into VIP, Regular, and New based on purchasing history  

### 3. Product Report View

A performance dashboard for the Product and Sales team.

- **Features**: Tracks revenue, profit margins (Sales vs Cost), and inventory velocity  
- **Logic**: Flags product performance status (High/Mid/Low) to identify Cash Cows and potential Dead Stock  

## How to Run

1. **Setup Database**  
   Open `scripts/init_database.sql` in SSMS. Update the file paths in the `BULK INSERT` commands to match your local directory where the `datasets/` folder is located.

2. **Execute Init Script**  
   Run the script to create the database, schema, and load the data.

3. **Run Analysis**  
   Execute scripts `1`, `2`, and `3` to generate reports and views.
