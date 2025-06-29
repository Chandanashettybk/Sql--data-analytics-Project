/*
===============================================================================
Database Exploration
===============================================================================
Purpose:
    - To explore the structure of the database, including the list of tables and their schemas.
    - To inspect the columns and metadata for specific tables.

Table Used:
    - INFORMATION_SCHEMA.TABLES
    - INFORMATION_SCHEMA.COLUMNS
===============================================================================
*/

-- Retrieve a list of all tables in the database
SELECT 
    TABLE_CATALOG, 
    TABLE_SCHEMA, 
    TABLE_NAME, 
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES;

-- Retrieve all columns for a specific table (dim_customers)
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';


/*
===============================================================================
2. Dimensions Exploration
===============================================================================
Purpose:
    - To explore the structure of dimension tables.
	
SQL Functions Used:
    - DISTINCT
    - ORDER BY
===============================================================================
*/

--explore all unique countrys our customers come from
select distinct country from gold.dim_customers
order by country

--explore all major categories
select distinct category, subcategory ,product_name from gold.dim_products
order by  category, subcategory ,product_name

/*
===============================================================================
3. Date Range Exploration 
===============================================================================
Purpose:
    - To determine the temporal boundaries of key data points.
    - To understand the range of historical data.

SQL Functions Used:
    - MIN(), MAX(), DATEDIFF()
===============================================================================
*/

--find the date of first and last order
--how many years of sales available
select 
min(order_date) as first_order ,
max(order_date) as last_order ,
datediff(year,min(order_date),max(order_date)) as order_range,
datediff(month,min(order_date),max(order_date)) as order_range_month --also check for month 
from gold.fact_sales

--find the youngest and oldest customers and their age
select min(birthdate) as oldest_customer,
datediff(year,min(birthdate),getdate()) as age,
max(birthdate) as youngest_customer,
datediff(year,max(birthdate),getdate()) as age
from gold.dim_customers

--find highest sales and lowest sales
select max(sales_amount) as highest_sales,
min(sales_amount) as lowest_sales from gold.fact_sales

/*
===============================================================================
4.Measures Exploration (Key Metrics)
===============================================================================
Purpose:
    - To calculate aggregated metrics (e.g., totals, averages) for quick insights.
    - To identify overall trends or spot anomalies.

SQL Functions Used:
    - COUNT(), SUM(), AVG()
===============================================================================
*/

--find how many items are sold
select sum(quantity) as items_sold from gold.fact_sales

--find average selling price
select avg(price) as avg_price from gold.fact_sales

--find total number of orders
select count(order_number) as total_orders from gold.fact_sales
select count(distinct order_number) as total_orders from gold.fact_sales

--find total number of products
select count(product_name) as total_products from gold.dim_products

--find total number of customers
select count(customer_key) as total_customers from gold.dim_customers

----find total number of customers placed orders
select count(distinct customer_key) as total_cust_orders from gold.fact_sales

--generate a report that shows all  the key metrics of the business
select 'Total sales' as measure_name ,sum(sales_amount) as measure_value from gold.fact_sales
union all
select 'Total quantity' , sum(quantity) from gold.fact_sales
union all
select 'average price' , avg(price) from gold.fact_sales
union all
select 'Total no. of orders' , count(distinct order_number) from gold.fact_sales
union all
select 'Total no. of products' ,count(product_name) from gold.dim_products
union all
select 'Total no. of customers' ,count(customer_key) from gold.dim_customers


/*
===============================================================================
5.Magnitude Analysis
===============================================================================
Purpose:
    - To quantify data and group results by specific dimensions.
    - For understanding data distribution across categories.

SQL Functions Used:
    - Aggregate Functions: SUM(), COUNT(), AVG()
    - GROUP BY, ORDER BY
===============================================================================
*/

--find total customers by countries
select 
count(customer_KEY) as total_customers,country from gold.dim_customers
group by country
order by total_customers desc

--find total customers by gender
select 
count(customer_key) as total_customers,gender from gold.dim_customers
group by gender
order by total_customers desc

--find total products by category
select 
count(product_key) as total_products,category from gold.dim_products
group by category
order by total_products desc

--what is the average costs in each category
select category,
avg(cost) as average_price from gold.dim_products
group by category
order by average_price desc

--what is the total revenue generated for each category
select
p.category,sum(s.sales_amount) as total_revenue from gold.fact_sales s
left join gold.dim_products p
on p.product_key=s.product_key
group by category
order by total_revenue 

--find  total revenue generated for each customers
--also gives which customer generates highest revenue(desc) and lowest revenue(asc)
select
c.customer_key,c.first_name,c.last_name,
sum(s.sales_amount) as total_revenue from gold.fact_sales s
left join gold.dim_customers c
on c.customer_key=s.customer_key
group by c.customer_key,c.first_name,c.last_name
order by total_revenue desc

--what is the distribution of sold items across countries
select
c.country,
sum(s.quantity) as total_sold_items from gold.fact_sales s
left join gold.dim_customers c
on c.customer_key=s.customer_key
group by c.country
order by total_sold_items desc

/*
===============================================================================
6.Ranking Analysis
===============================================================================
Purpose:
    - To rank items (e.g., products, customers) based on performance or other metrics.
    - To identify top performers or laggards.

SQL Functions Used:
    - Window Ranking Functions: RANK(), DENSE_RANK(), ROW_NUMBER(), TOP
    - Clauses: GROUP BY, ORDER BY
===============================================================================
*/

--which 5 products generates highest revenue
--simple ranking
select top 5
p.product_name,sum(s.sales_amount) as total_revenue from gold.fact_sales s
left join gold.dim_products p
on p.product_key=s.product_key
group by product_name
order by total_revenue desc

-- Complex but Flexibly Ranking Using Window Functions
SELECT *
FROM (
    SELECT
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_products
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.product_name
) AS ranked_products
WHERE rank_products <= 5;

--what are 5 worst performing products in term of sales
select top 5
p.product_name,sum(s.sales_amount) as total_revenue from gold.fact_sales s
left join gold.dim_products p
on p.product_key=s.product_key
group by product_name
order by total_revenue

--top 3 customers with fewest orders
select top 3
c.customer_key,c.first_name,c.last_name,
count(distinct f.order_number) as total_orders from gold.fact_sales f
left join gold.dim_customers c
on c.customer_key=f.customer_key
group by c.customer_key,c.first_name,c.last_name
order by total_orders

--find top 10 customers generated highest revenue
select top 10
c.customer_key,c.first_name,c.last_name,
sum(s.sales_amount) as total_revenue from gold.fact_sales s
left join gold.dim_customers c
on c.customer_key=s.customer_key
group by c.customer_key,c.first_name,c.last_name
order by total_revenue desc