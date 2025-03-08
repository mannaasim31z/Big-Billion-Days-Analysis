# Demographic Analysis

-- 1. Gender wise customers
WITH gender_customer AS (
SELECT gender,COUNT(customer_id) AS customers
FROM customers
GROUP BY gender)
SELECT gender,ROUND(customers*100/SUM(customers) OVER(),2) AS percentage
FROM gender_customer
ORDER BY percentage DESC;

-- 2. Age Group Wise Customers
WITH age_group AS (
SELECT 
CASE 
WHEN age BETWEEN 18 AND 30 THEN '18-30'
WHEN age BETWEEN 31 AND 40 THEN '31-40'
WHEN age BETWEEN 41 AND 50 THEN '41-50'
WHEN age BETWEEN 51 AND 60 THEN '51-60'
ELSE '60+' END AS age_group,COUNT(customer_id) AS customers
FROM customers
GROUP BY age_group)
SELECT age_group,customers,ROUND(customers*100/SUM(customers) OVER(),2) AS percentage
FROM age_group
ORDER BY age_group;

-- 3. Age Group and Gender Wise Customer
WITH age_group_gender AS (
SELECT 
CASE 
WHEN age BETWEEN 18 AND 30 THEN '18-30'
WHEN age BETWEEN 31 AND 40 THEN '31-40'
WHEN age BETWEEN 41 AND 50 THEN '41-50'
WHEN age BETWEEN 51 AND 60 THEN '51-60'
ELSE '60+' END AS age_group,gender,COUNT(customer_id) AS customers
FROM customers
GROUP BY age_group,gender)

SELECT age_group,
MAX(CASE WHEN gender='Male' THEN customers ELSE NULL END) AS Male,
MAX(CASE WHEN gender='Female' THEN customers ELSE NULL END) AS Female,
MAX(CASE WHEN gender='Other' THEN customers ELSE NULL END) AS Other
FROM age_group_gender
GROUP BY age_group;

-- 4. Pincode Wise Customers
SELECT pincode,COUNT(customer_id) AS customers
FROM customers
GROUP BY pincode;

-- Order Analysis
-- 1. Products that ordered most in a order
SELECT order_id,i.product_id,GROUP_CONCAT(DISTINCT(product_type)) AS product_combo
FROM order_items i 
LEFT JOIN products p 
ON i.product_id=p.product_id
GROUP BY order_id
ORDER BY order_id,i.product_id;

-- 2. Orders During Pre BBD, During DDB and Post BBD
WITH bbd_timing AS (
SELECT order_id,order_timestamp,
CASE 
WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing
FROM orders)
SELECT timing,COUNT(DISTINCT(DATE(order_timestamp))) AS days_count,
COUNT(order_id) AS total_orders,
ROUND(COUNT(order_id)/COUNT(DISTINCT(DATE(order_timestamp))),0) AS avg_orders_per_day
FROM bbd_timing
GROUP BY timing;

-- 3. Total Sales During Pre BBD, During DDB and Post BBD
SELECT 
CASE 
WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,
SUM(price) AS total_sales
FROM orders o 
LEFT JOIN returns r
ON o.order_id=r.order_id
LEFT JOIN products p 
ON o.product_id=p.product_id
WHERE r.order_id IS NULL 
GROUP BY timing;

-- 4. Total Sales Per Day During Pre BBD, During DDB and Post BBD
WITH sales AS (
SELECT 
CASE 
WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,
price,DATE(order_timestamp) AS order_date
FROM orders o 
LEFT JOIN returns r
ON o.order_id=r.order_id
LEFT JOIN products p 
ON o.product_id=p.product_id
WHERE r.order_id IS NULL)
SELECT timing,ROUND(SUM(price)/1000000,2) AS total_sales_millions,
ROUND(SUM(price)/COUNT(DISTINCT(order_date))/1000000,2) AS sales_per_day_millions
FROM sales
GROUP BY timing;

-- 5. Top Hours During Pre BBD, During DDB and Post BBD
WITH hourly_orders AS (
SELECT HOUR(order_timestamp) AS hour_no,
CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,COUNT(order_id) AS total_orders
FROM orders
GROUP BY hour_no,timing),
top_hours AS (
SELECT hour_no,timing,total_orders,DENSE_RANK() OVER(PARTITION BY timing ORDER BY total_orders DESC) AS rnk
FROM hourly_orders)
SELECT timing,hour_no,total_orders
FROM top_hours
WHERE rnk<=2;

-- 6. Payment Method For Different Timing
WITH payment_method_timing AS (
SELECT payment_method,
CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,
ROUND(COUNT(order_id)/COUNT(DISTINCT(DATE(order_timestamp))),0) AS per_day_orders
FROM orders
GROUP BY payment_method,timing)
SELECT payment_method,
MAX(CASE WHEN timing='Pre BBD' THEN per_day_orders ELSE NULL END) AS 'Pre BBD',
MAX(CASE WHEN timing='During BBD' THEN per_day_orders ELSE NULL END) AS 'During BBD',
MAX(CASE WHEN timing='Post BBD' THEN per_day_orders ELSE NULL END) AS 'Post BBD'
FROM payment_method_timing
GROUP BY payment_method;

-- 7. Total Ontime and late deliveries
WITH order_analysis AS (
SELECT COUNT(*) AS total_orders,
COUNT(CASE WHEN actual_delivery_timestamp<=expected_delivery_timestamp THEN order_id ELSE NULL END) AS ontime_orders,
COUNT(CASE WHEN actual_delivery_timestamp>expected_delivery_timestamp THEN order_id ELSE NULL END) AS late_orders
FROM orders)
SELECT ontime_orders*100/total_orders AS ontime_delivery_percentage,
late_orders*100/total_orders AS late_delivery_percentage
FROM order_analysis;

-- 8. Pre BBD During BBD and Post BBD Order Deivery Analysis
WITH order_delivery_timing AS (
SELECT 
CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,COUNT(*) AS total_orders,
COUNT(CASE WHEN actual_delivery_timestamp<=expected_delivery_timestamp THEN order_id ELSE NULL END) AS ontime_orders,
COUNT(CASE WHEN actual_delivery_timestamp>expected_delivery_timestamp THEN order_id ELSE NULL END) AS late_orders
FROM orders
GROUP BY timing)
SELECT timing,ROUND(ontime_orders*100/total_orders,2) AS ontime_delivery_percentage,
ROUND(late_orders*100/total_orders,2) AS late_delivery_percentage
FROM order_delivery_timing;

-- 9. Delivery Partnerwise Delay Percentage
WITH delivery_partner_delay AS (
SELECT delivery_partner,COUNT(*) AS order_delayed
FROM orders 
WHERE actual_delivery_timestamp>expected_delivery_timestamp
GROUP BY delivery_partner)
SELECT delivery_partner,ROUND(order_delayed*100/SUM(order_delayed) OVER(),2) AS percentage_delayed
FROM delivery_partner_delay;

-- 10. Late Delivery Time
WITH delay_day AS (
SELECT order_id,actual_delivery_timestamp,expected_delivery_timestamp,
TIMESTAMPDIFF(DAY,expected_delivery_timestamp,actual_delivery_timestamp) AS day_delay
FROM orders
WHERE actual_delivery_timestamp>expected_delivery_timestamp),
delay_histogram AS (
SELECT day_delay,COUNT(*) AS orders
FROM delay_day
GROUP BY day_delay)
SELECT day_delay,ROUND(orders*100/SUM(orders) OVER(),0) AS percentage
FROM delay_histogram
ORDER BY day_delay;

-- 11. Top 5 Pincodes with most delayed Orders
WITH delayed_location AS (
SELECT pincode,COUNT(order_id) AS delay_orders
FROM orders
WHERE actual_delivery_timestamp>expected_delivery_timestamp
GROUP BY pincode),
top_delay_locations AS (
SELECT pincode,delay_orders,DENSE_RANK() OVER(ORDER BY delay_orders DESC) AS rnk,
ROUND(delay_orders*100/SUM(delay_orders) OVER(),2) AS percentage
FROM delayed_location)
SELECT pincode,delay_orders,percentage
FROM top_delay_locations
WHERE rnk<=5;

-- 12. Weekly Orders Trends
SELECT WEEK(STR_TO_DATE(d.full_date, '%m/%d/%Y')) AS week_no,COUNT(order_id) AS total_orders
FROM dates d 
LEFT JOIN orders o 
ON STR_TO_DATE(d.full_date, '%m/%d/%Y')=DATE(o.order_timestamp)
GROUP BY week_no
ORDER BY week_no;

-- Product Analysis
-- 1. Top 5 Products by Sales
WITH product_sales AS (
SELECT CONCAT(product_type,'-',brand) AS product_name,
CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,
ROUND(SUM(price)/1000000,2) AS total_sales
FROM products p 
JOIN orders o 
ON p.product_id=o.product_id
LEFT JOIN returns r 
ON r.order_id=o.order_id
WHERE r.order_id IS NULL
GROUP BY product_name,timing),
top_products AS (
SELECT timing,product_name,total_sales,DENSE_RANK() OVER(PARTITION BY timing ORDER BY total_sales DESC) AS rnk
FROM product_sales)
SELECT timing,product_name,total_sales
FROM top_products
WHERE rnk<=3;

-- 2. Products That generate 70% of Revenue
WITH product_sales AS (
SELECT CONCAT(product_type,'-',brand) AS product_name,ROUND(SUM(price)/1000000,2) AS total_sales
FROM products p 
JOIN orders o 
ON p.product_id=o.product_id
LEFT JOIN returns r 
ON r.order_id=o.order_id
WHERE r.order_id IS NULL
GROUP BY product_name),
top_products AS (
SELECT product_name,total_sales,
SUM(total_sales) OVER(ORDER BY total_sales DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_sales,
0.7*SUM(total_sales) OVER() AS 70_percent_total_sales
FROM product_sales)
SELECT product_name,total_sales
FROM top_products
WHERE running_sales<=70_percent_total_sales;

-- 3. Top Brands of Each Product
WITH top_products AS (
SELECT product_type,brand,ROUND(SUM(price)/1000000,2) AS total_sales
FROM products p 
JOIN orders o 
ON p.product_id=o.product_id
LEFT JOIN returns r 
ON r.order_id=o.order_id
WHERE r.order_id IS NULL
GROUP BY product_type,brand),
product_rank AS (
SELECT product_type,brand,total_sales,
DENSE_RANK() OVER(PARTITION BY product_type ORDER BY total_sales DESC) AS rnk
FROM top_products)
SELECT product_type,brand,total_sales
FROM product_rank
WHERE rnk<=2;

-- 4. Each Product wise Top & Bottom Sold Products
WITH product_sales AS (
SELECT product_type,brand,ROUND(SUM(price)/1000000,2) AS total_sales
FROM products p 
JOIN orders o 
ON p.product_id=o.product_id
LEFT JOIN returns r 
ON r.order_id=o.order_id
WHERE r.order_id IS NULL
GROUP BY product_type,brand),
top_bottom_products AS (
SELECT product_type,brand,total_sales,
RANK() OVER(PARTITION BY product_type ORDER BY total_sales DESC) AS rnk1,
RANK() OVER(PARTITION BY product_type ORDER BY total_sales ASC) AS rnk2
FROM product_sales)
SELECT product_type,
MAX(CASE WHEN rnk1=1 THEN brand ELSE NULL END) AS top_sold_brand,
MAX(CASE WHEN rnk2=1 THEN brand ELSE NULL END) AS bottom_sold_brand
FROM top_bottom_products
GROUP BY product_type;

-- 5. Genderwise top 3 Product sold
WITH gender_product_sales AS (
SELECT gender,CONCAT(product_type,'-',brand) AS product_name,ROUND(SUM(price)/1000000,2) AS total_sales
FROM products p 
JOIN orders o 
ON p.product_id=o.product_id
LEFT JOIN returns r 
ON r.order_id=o.order_id
LEFT JOIN customers c 
ON c.customer_id=o.customer_id
WHERE r.order_id IS NULL
GROUP BY product_name,gender)
SELECT gender,product_name,total_sales,DENSE_RANK() OVER(PARTITION BY gender ORDER BY total_sales DESC) AS rnk
FROM gender_product_sales;

-- 6. Age Group wise Most and least Ordered Product
WITH age_group_product_sales AS (
SELECT 
CASE 
WHEN age BETWEEN 18 AND 30 THEN '18-30'
WHEN age BETWEEN 31 AND 45 THEN '31-45'
WHEN age BETWEEN 46 AND 55 THEN '46-55'
ELSE '55+' END AS age_group,CONCAT(product_type,'-',brand) AS product_name,
ROUND(SUM(price)/1000000,2) AS total_sales
FROM products p 
JOIN orders o 
ON p.product_id=o.product_id
LEFT JOIN returns r 
ON r.order_id=o.order_id
LEFT JOIN customers c 
ON c.customer_id=o.customer_id
WHERE r.order_id IS NULL
GROUP BY age_group,product_name),
top_products AS (
SELECT age_group,product_name,total_sales,
RANK() OVER(PARTITION BY age_group ORDER BY total_sales DESC) AS rnk1,
RANK() OVER(PARTITION BY age_group ORDER BY total_sales ASC) AS rnk2
FROM age_group_product_sales)
SELECT age_group,
MAX(CASE WHEN rnk1=1 THEN product_name ELSE NULL END) AS most_sold_product,
MAX(CASE WHEN rnk2=1 THEN product_name ELSE NULL END) AS least_sold_product,
MAX(CASE WHEN rnk1=1 THEN total_sales ELSE NULL END) AS most_sold_product_sales,
MAX(CASE WHEN rnk2=1 THEN total_sales ELSE NULL END) AS least_sold_product_sales
FROM top_products
GROUP BY age_group;

-- Order Return Analysis
-- 1. Total Amount Loss Due to Return
SELECT CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,
ROUND(SUM(CASE WHEN r.order_id IS NOT NULL THEN price ELSE 0 END)/1000000,2) AS return_products_amount,
ROUND(SUM(price)/1000000,2) AS total_sales,
ROUND(SUM(CASE WHEN r.order_id IS NOT NULL THEN price ELSE 0 END)*100/SUM(price),2) AS return_amount_percentage
FROM orders o 
LEFT JOIN returns r 
ON o.order_id=r.order_id
LEFT JOIN products p 
ON p.product_id=o.product_id
GROUP BY timing;

-- 2. Return Reason During BBD,Pre BBD,Post BBD
WITH returned_orders AS (
SELECT CASE WHEN DATE(o.order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(o.order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,
return_reason,COUNT(r.order_id) AS orders
FROM returns r 
JOIN orders o ON o.order_id=r.order_id
GROUP BY return_reason,timing)
SELECT timing,return_reason,ROUND(orders*100/SUM(orders) OVER(),2) AS percentage
FROM returned_orders
ORDER BY timing;

-- 3. Top 2 Products for each Return Reason
WITH return_product AS (
SELECT return_reason,CONCAT(product_type,'-',brand) AS product_name,COUNT(return_id) AS return_orders
FROM returns r 
JOIN orders o 
ON r.order_id=o.order_id
JOIN products p 
ON p.product_id=o.product_id
GROUP BY return_reason,product_name),
ranking AS (
SELECT return_reason,product_name,return_orders,
DENSE_RANK() OVER(PARTITION BY return_reason ORDER BY return_orders DESC) AS rnk
FROM return_product)
SELECT return_reason,product_name,return_orders
FROM ranking 
WHERE rnk<=2;

-- 4. Most Returned Product Categories
WITH return_product AS (
SELECT 
CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,return_reason,COUNT(return_id) AS return_orders
FROM returns r 
JOIN orders o ON r.order_id=o.order_id
JOIN products p ON p.product_id=o.product_id
GROUP BY timing,return_reason),
top_reasons AS (
SELECT timing,return_reason,return_orders,
DENSE_RANK() OVER(PARTITION BY timing ORDER BY return_orders DESC) AS rnk
FROM return_product)
SELECT timing,return_reason,return_orders
FROM top_reasons
WHERE rnk<=3;

-- 5. For No Longer Needed Return Reason Is there any delay for delvery?
SELECT CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,
COUNT(*) AS total_returned,
COUNT(CASE WHEN actual_delivery_timestamp>expected_delivery_timestamp THEN r.order_id ELSE NULL END) AS delayed_returns,
COUNT(CASE WHEN actual_delivery_timestamp>expected_delivery_timestamp THEN r.order_id ELSE NULL END)*100/COUNT(*) AS delayed_percentage
FROM returns r 
JOIN orders o 
ON o.order_id=r.order_id
WHERE return_reason='No Longer Needed'
GROUP BY timing;

-- 6. Pincode Wise Returned Orders
WITH returned_pincodes AS (
SELECT CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,pincode,
COUNT(o.order_id) AS returned_orders
FROM orders o
JOIN returns r 
ON r.order_id=o.order_id
GROUP BY pincode,timing),
top_returned_pincodes AS (
SELECT timing,pincode,returned_orders,
DENSE_RANK() OVER(PARTITION BY timing ORDER BY returned_orders DESC) AS rnk 
FROM returned_pincodes)
SELECT timing,pincode,returned_orders
FROM top_returned_pincodes
WHERE rnk<=3;

-- 7. Avg Time For Delivery For Most Returned Orders
WITH location_delay AS (
SELECT CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,pincode,
ROUND(AVG(TIMESTAMPDIFF(DAY,order_timestamp,actual_delivery_timestamp)),0) AS delivery_time,
ROUND(AVG(TIMESTAMPDIFF(DAY,expected_delivery_timestamp,actual_delivery_timestamp)),0) AS delay_time,
COUNT(o.order_id) AS returned_orders
FROM orders o
JOIN returns r 
ON r.order_id=o.order_id
GROUP BY timing,pincode
ORDER BY timing),
top_returned_location AS (
SELECT *,DENSE_RANK() OVER(PARTITION BY timing ORDER BY returned_orders DESC) AS rnk
FROM location_delay)
SELECT timing,pincode,delivery_time,delay_time
FROM top_returned_location
WHERE rnk<=3;

--  Repeat & Repeated Customers Analysis
-- 1. New & Repeat Users During Pre, During and Post BBD and Sales
WITH customer_type AS (
SELECT CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,customer_id,order_timestamp,price,r.return_id,
MIN(order_timestamp) OVER(PARTITION BY customer_id) AS first_order_date
FROM orders o 
JOIN products p 
ON p.product_id=o.product_id
LEFT JOIN returns r ON r.order_id=o.order_id)
SELECT timing,
COUNT(DISTINCT(CASE WHEN order_timestamp=first_order_date THEN customer_id ELSE NULL END)) AS new_customer,
COUNT(DISTINCT(CASE WHEN order_timestamp>first_order_date THEN customer_id ELSE NULL END)) AS repeat_customer,
ROUND(SUM(CASE WHEN order_timestamp=first_order_date  AND return_id IS NULL THEN price ELSE NULL END)/1000000,2) AS new_customer_sales_millions,
ROUND(SUM(CASE WHEN order_timestamp>first_order_date AND return_id IS NULL THEN price ELSE NULL END)/1000000,2) AS repeat_customer_sales_millions
FROM customer_type
GROUP BY timing;

-- 2. Weekly Trend of New and Repeated Customers
WITH weekly_customers AS (
SELECT WEEK(STR_TO_DATE(d.full_date, '%m/%d/%Y')) AS week_no,customer_id,order_timestamp,
MIN(order_timestamp) OVER(PARTITION BY customer_id) AS first_order_date
FROM dates d 
LEFT JOIN orders o ON STR_TO_DATE(d.full_date, '%m/%d/%Y')=DATE(o.order_timestamp))
SELECT week_no,
COUNT(DISTINCT(CASE WHEN order_timestamp=first_order_date THEN customer_id ELSE NULL END)) AS new_customer,
COUNT(DISTINCT(CASE WHEN order_timestamp>first_order_date THEN customer_id ELSE NULL END)) AS repeat_customer
FROM weekly_customers
GROUP BY week_no
ORDER BY week_no;

-- 3. Repeated & New Users Most & Least Orders Products
WITH product_sales AS (
SELECT CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,customer_id,order_timestamp,
MIN(order_timestamp) OVER(PARTITION BY customer_id) AS first_order_date,
CONCAT(product_type,'-',brand) AS product_name
FROM orders o 
JOIN products p ON p.product_id=o.product_id),
top_products AS (
SELECT timing,
CASE 
WHEN order_timestamp=first_order_date THEN 'new_customer'
WHEN order_timestamp>first_order_date THEN 'repeat_customer'
END AS customer_type,product_name,COUNT(*) AS orders
FROM product_sales
GROUP BY timing,customer_type,product_name),
product_rank AS (
SELECT timing,customer_type,product_name,orders,
DENSE_RANK() OVER(PARTITION BY timing,customer_type ORDER BY orders DESC) AS rnk
FROM top_products)
SELECT timing,customer_type,product_name,orders
FROM product_rank
WHERE rnk<=2;

-- 4. Pre BBD,During BBD and Post BBD Age Groupwise New & Repeated Customers
WITH age_group_customer_type AS (
SELECT CASE WHEN DATE(order_timestamp)<'2024-09-09' THEN 'Pre BBD'
WHEN DATE(order_timestamp) BETWEEN '2024-09-09' AND '2024-09-19' THEN 'During BBD'
ELSE 'Post BBD' END AS timing,o.customer_id,order_timestamp,
MIN(order_timestamp) OVER(PARTITION BY customer_id) AS first_order_date,
CASE 
WHEN age BETWEEN 18 AND 30 THEN '18-30'
WHEN age BETWEEN 31 AND 45 THEN '31-45'
WHEN age BETWEEN 46 AND 55 THEN '46-55'
ELSE '55+' END AS age_group
FROM orders o 
JOIN customers c 
ON c.customer_id=o.customer_id)
SELECT timing,age_group,
COUNT(DISTINCT(CASE WHEN order_timestamp=first_order_date THEN customer_id ELSE NULL END)) AS new_customer,
COUNT(DISTINCT(CASE WHEN order_timestamp>first_order_date THEN customer_id ELSE NULL END)) AS repeat_customer
FROM age_group_customer_type
GROUP BY timing,age_group;

