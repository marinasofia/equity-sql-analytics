SELECT
	load_id, COUNT(*) AS occurrences
FROM
	loads
GROUP BY load_id
HAVING COUNT(*) > 1;

SELECT
	origin_city, destination_city
FROM routes
GROUP BY origin_city, destination_city
HAVING COUNT(*) > 1


SHOW COLUMNS FROM LOADS;
DESCRIBE LOADS;



DROP TEMPORARY TABLE IF EXISTS loads_march;


CREATE TEMPORARY TABLE loads_march AS
SELECT *
FROM loads
WHERE load_date BETWEEN '2023-03-01' AND '2023-03-31';



SELECT * FROM loads_march; 



DROP TEMPORARY TABLE IF EXISTS trips_march;

CREATE TEMPORARY TABLE trips_march AS
SELECT t.*
FROM trips t
JOIN loads_march lm ON t.load_id = lm.load_id;

SELECT * FROM trips_march;



SELECT
	COUNT(*)
FROM
	loads_march;

SELECT
	COUNT(*)
FROM
	trips_march;
    
    
SELECT DISTINCT
    lm.load_id, c.customer_name, lm.revenue
FROM
    loads_march lm
        INNER JOIN
    customers c ON lm.customer_id = c.customer_id;


SELECT 
    lm.load_id, r.origin_city, r.destination_city
FROM
    loads_march lm
        LEFT JOIN
    routes r ON lm.route_id = r.route_id
WHERE r.route_id IS NULL;


SELECT 
    r.route_id, lm.load_id, r.destination_city
FROM
    loads_march lm
        LEFT JOIN
    routes r ON lm.route_id = r.route_id
WHERE
    lm.load_id IS NULL;
    

SELECT lm.load_id, r.origin_city, r.destination_city
FROM loads_march lm
LEFT JOIN routes r ON lm.route_id = r.route_id
UNION SELECT lm.load_id, r.origin_city, r.destination_city
FROM loads_march lm
RIGHT JOIN routes r ON lm.route_id = r.route_id




CREATE TEMPORARY TABLE loads_march2 AS
SELECT * FROM loads_march;



SELECT 
    lm.load_id, r.origin_city, r.destination_city
FROM
    loads_march lm
        LEFT JOIN
    routes r ON lm.route_id = r.route_id 
UNION SELECT 
    lm2.load_id, r.origin_city, r.destination_city
FROM
    loads_march2 lm2
        RIGHT JOIN
    routes r ON lm2.route_id = r.route_id;


