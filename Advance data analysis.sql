----------------------------Advance Data analytics--------------------------------
--Answer bussiness Analytics------
---It is done using complex queries,window functions,CTE ,Subqueries------
---This helps in generating reports---
-----------------------------------------------------------------------------------


/*
===============================================================================
7.Change Over Time Analysis
===============================================================================
Purpose:
    - To track trends, growth, and changes in key metrics over time.
    - For time-series analysis and identifying seasonality.
    - To measure growth or decline over specific periods.

SQL Functions Used:
    - Date Functions: DATEPART(), DATETRUNC(), FORMAT()
    - Aggregate Functions: SUM(), COUNT(), AVG()
===============================================================================
*/


--Analyze sales performance over time
select 
year(order_date) as order_year,
sum(sales_amount) as total_sales,
from gold.fact_sales
group by year(order_date)
order by year(order_date)

--Analyze sales performance over time (months)
select
year(order_date) as year,
datepart(month,order_date)as order_month,
sum(sales_amount) as total_sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null
group by year(order_date), datepart(month,order_date)
order by year(order_date),datepart(month,order_date)

--Analyze sales performance over time in the year 2013
select
year(order_date) as year,
month(order_date)as order_month,
sum(sales_amount) as total_sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where year(order_date) = 2013
group by year(order_date), month(order_date)
order by year(order_date),month(order_date)

/*
===============================================================================
8.Cumulative Analysis
===============================================================================
Purpose:
    - To calculate running totals or moving averages for key metrics.
    - To track performance over time cumulatively.
    - Useful for growth analysis or identifying long-term trends.

SQL Functions Used:
    - Window Functions: SUM() OVER(), AVG() OVER()
===============================================================================
*/


--calculate the total sales per month
-- and the running total of sales over time
select
order_date,total_sales,
sum(total_sales) over(partition by order_date order by order_date) as running_total_sales from(
	select 
	datetrunc(month,order_date) as order_date,
	sum(sales_amount)as total_sales
	from gold.fact_sales
	where order_date is not null
	group by datetrunc(month,order_date)
)t

--calculate the total sales per year
-- and the running total of sales over time
--and moving average of price
select
order_date,total_sales,avg_price,
sum(total_sales) over(order by order_date) as running_total_sales,
avg(avg_price) over(order by order_date) as moving_average_price from(
	select 
	year(order_date) as order_date,
	sum(sales_amount)as total_sales,
	avg(price) as avg_price
	from gold.fact_sales
	where order_date is not null
	group by year(order_date)
)t

--calculate the total sales per month
-- and moving average of price over time
select
order_date,total_sales,avg_price,
avg(avg_price) over(partition by order_date order by order_date) as movig_average_price,
sum(total_sales) over(partition by order_date order by order_date) as running_total_sales from(
	select 
	datetrunc(month,order_date) as order_date,
	sum(sales_amount)as total_sales,avg(price) as avg_price
	from gold.fact_sales
	where order_date is not null
	group by datetrunc(month,order_date)
)t

/*
===============================================================================
9.Performance Analysis (Year-over-Year, Month-over-Month)
===============================================================================
Purpose:
    - To measure the performance of products, customers, or regions over time.
    - For benchmarking and identifying high-performing entities.
    - To track yearly trends and growth.

SQL Functions Used:
    - LAG(): Accesses data from previous rows.
    - AVG() OVER(): Computes average values within partitions.
    - CASE: Defines conditional logic for trend analysis.
===============================================================================
*/

--analyze the yearly performance of products 
--by comparing each products sales to both its average sales performance 
--and the previous years sales
with yearly_product_sales as(
select
year(f.order_date) as order_year,p.product_name,
sum(f.sales_amount) as current_sales
from gold.fact_sales f 
left join gold.dim_products p
on f.product_key=p.product_key
where order_date is not null
group by year(f.order_date),p.product_name
)
select 
order_year,product_name,current_sales,
avg(current_sales) over(partition by product_name) as avg_sales,
current_sales-avg(current_sales) over(partition by product_name) as diff_avg,
case
when current_sales-avg(current_sales) over(partition by product_name)>0 then 'above avg'
when current_sales-avg(current_sales) over(partition by product_name)<0 then 'below avg'
else 'avg'
end avg_change,
lag(current_sales) over(partition by product_name order by order_year) as previous_year_sales,
current_sales - lag(current_sales) over(partition by product_name order by order_year) as diff_py,
case
when current_sales-lag(current_sales) over(partition by product_name order by order_year)>0 
then 'increase'
when current_sales-lag(current_sales) over(partition by product_name order by order_year)<0 then 'decrease'
else 'no change'
end py_change
from yearly_product_sales

/*
===============================================================================
10.Part-to-Whole Analysis
===============================================================================
Purpose:
    - To compare performance or metrics across dimensions or time periods.
    - To evaluate differences between categories.
    - Useful for A/B testing or regional comparisons.

SQL Functions Used:
    - SUM(), AVG(): Aggregates values for comparison.
    - Window Functions: SUM() OVER() for total calculations.
===============================================================================
*/

--which category contribute the most of sales

with category_sales as(
select category ,
sum(f.sales_amount) as total_sales
from gold.fact_sales  f
left join gold.dim_products p
on p.product_key =f.product_key
group by category
)
select
category,total_sales,
sum(total_sales) over() as overall_sales,
concat(round(cast(total_sales as float)/sum(total_sales) over(),2)*100,'%') as percent_sales
from category_sales
order by total_sales desc
/*
===============================================================================
11.Data Segmentation Analysis
===============================================================================
Purpose:
    - To group data into meaningful categories for targeted insights.
    - For customer segmentation, product categorization, or regional analysis.

SQL Functions Used:
    - CASE: Defines custom segmentation logic.
    - GROUP BY: Groups data into segments.
===============================================================================
*/

/*segment products into cost ranges and
count how many products fall into each segement*/
with product_segments as(
select
product_key,PRODUCT_name ,cost,
case when cost <100 then 'below 100'
     when cost between 100 and 500 then '100-500'
	 when cost between 500 and 1000 then '500-1000'
	 else 'above 1000'
	 end cost_range from gold.dim_products)
select
cost_range,count(product_key) as total_products
from product_segments
group by cost_range
order by total_products DESC;


/* group customers into 3 segments based on their spending behaviour.
VIP:at least 12 months of history and spending more than $5000
REGULAR:at least 12 months of history but spending $5000 or less
NEW: lifespan less than 12 months
*/
with customer_spending as(
select 
c.customer_key,
sum(f.sales_amount) as total_spending,
min(order_date) as first_order,
max(order_date) as last_order,
datediff(month,min(order_date),max(order_date)) as lifespan
from gold.fact_sales f
left join gold.dim_customers c
on f.customer_key=c.customer_key
group by c.customer_key)
select 
customer_key,
total_spending,
lifespan,
case when lifespan>=12 and total_spending>5000 then 'VIP'
     when lifespan>=12 and total_spending<=5000 then 'REGULAR'
	 Else 'NEW'
end segment
from customer_spending

--count of the customers in segemnt
WITH customer_spending1 AS (
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(order_date) AS first_order,
        MAX(order_date) AS last_order,
        DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT 
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT 
        customer_key,
        CASE 
            WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending1
) AS segmented_customers
GROUP BY customer_segment
ORDER BY total_customers DESC;


