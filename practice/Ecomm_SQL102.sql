CREATE TABLE sales_lab AS SELECT order_id,
    customer_id,
    product_id,
    category,
    price,
    discount,
    quantity,
    payment_method,
    order_date,
    delivery_time_days,
    region,
    returned,
    total_amount,
    shipping_cost,
    profit_margin,
    customer_age,
    customer_gender FROM
    ecommerce_sales_34500
LIMIT 5000;


SELECT 
    order_id,
    price,
    CASE
        WHEN price < 50 THEN 'ECO-BUDGET'
        WHEN price < 200 THEN 'MID-BUDGET'
        WHEN price < 500 THEN 'HIGH-BUDGET'
        ELSE 'LUXURY'
    END AS price_category
FROM
    sales_lab;


SELECT 
    order_id,
    delivery_time_days,
    returned,
    CASE
        WHEN
            delivery_time_days > 9
                AND returned = 'Yes'
        THEN
            'Late and Returned'
        WHEN delivery_time_days > 9 THEN 'Returned Only'
        ELSE 'All Good'
    END AS order_flag
FROM
    sales_lab;
 
 
 
SELECT 
    order_id, category, total_amount
FROM
    sales_lab
ORDER BY CASE category
    WHEN 'Electronics' THEN 1
    WHEN 'Fasion' THEN 2
    ELSE 3
END;


SELECT 
    order_id, returned, delivery_time_days, total_amount
FROM
    sales_lab
WHERE
    CASE
        WHEN returned = 'Yes' AND total_amount < 300 THEN 1
        WHEN returned = 'No' AND delivery_time_days > 10 THEN 1
        ELSE 0
    END = 1;
    
    
    
SELECT 
    order_id, category, price,
    CASE
        WHEN price > (SELECT AVG(price) FROM sales_lab) THEN 'Above Average'
        WHEN price = (SELECT AVG(price) FROM sales_lab) THEN 'Exactly Average'
        ELSE 'Below Average'
    END AS price_avg_class
FROM
    sales_lab;
    

SELECT 
    order_id,
    category,
    price,
    CASE
        WHEN
            price > (SELECT 
                    AVG(sl2.price)
                FROM
                    sales_lab sl2
                WHERE
                    sl1.category = sl2.category)
        THEN
            'Above Average'
        ELSE 'AT or Below Average'
    END AS category_price_class
FROM
    sales_lab sl1;


/* Flag each order "Out performing Region" if it's total_amount is above the average total_amount for its region,
AND that region's average is itself above teh overall average. This chains 2 subqueries inside one CASE */

SELECT 
    region,
    total_amount,
    order_id,
    CASE
        WHEN
            total_amount > (SELECT 
                    AVG(s2.total_amount)
                FROM
                    sales_lab s2
                WHERE
                    s2.region = s1.region)
                AND (SELECT 
                    AVG(s2.total_amount)
                FROM
                    sales_lab s3
                WHERE
                    s3.region = s1.region) > (SELECT 
                    AVG(total_amount)
                FROM
                    sales_lab)
        THEN
            'Out-performing Region'
        ELSE 'Average'
    END AS region_flag
FROM
    sales_lab s1;