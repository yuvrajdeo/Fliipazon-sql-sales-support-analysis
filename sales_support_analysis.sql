/* HOW TO RUN:
   1. Run data_setup.sql first (creates the interview database, tables and data).
   2. Then run this file ONCE from top to bottom.
   (ALTER TABLE statements fail if run a second time because the changes already exist.)
*/
USE interview;

SHOW TABLES;

/* =====================================================================
   SEGMENT 1: DATABASE - TABLES, COLUMNS, RELATIONSHIPS
   ===================================================================== */
-- 1.1 Tables and their columns (information schema)
SELECT TABLE_NAME, ORDINAL_POSITION AS col_no, COLUMN_NAME, COLUMN_TYPE,
       IS_NULLABLE, COLUMN_KEY
FROM   information_schema.COLUMNS
WHERE  TABLE_SCHEMA = 'interview'
ORDER  BY TABLE_NAME, ORDINAL_POSITION;

-- 1.2 Record count per table  (expected: agents 12, customer 25, orders 36)
SELECT 'agents' as table_name, COUNT(*) AS row_count FROM agents
UNION ALL
SELECT 'customer' as table_name, COUNT(*) AS row_count FROM customer
UNION ALL
SELECT 'orders' as table_name, COUNT(*) AS row_count FROM orders;

-- 1.3 Missing / inconsistent values --------------------------------------
-- analysing each character length and extra spaces in agents table
SELECT agent_code, agent_name, working_area, phone_no,
       CHAR_LENGTH(agent_code) AS code_len,
       CHAR_LENGTH(agent_name) AS name_len,
       CHAR_LENGTH(working_area) AS area_len,
       CHAR_LENGTH(phone_no) AS phone_len,
       CHAR_LENGTH(country) AS country_len
FROM agents;
-- count rows with padded text
-- CHAR_LENGTH is used because MySQL ignores trailing spaces in '=' and '<>'
SELECT
  SUM(CHAR_LENGTH(agent_code) <> CHAR_LENGTH(TRIM(agent_code))) AS code_padded,
  SUM(CHAR_LENGTH(agent_name) <> CHAR_LENGTH(TRIM(agent_name))) AS name_padded,
  SUM(CHAR_LENGTH(working_area) <> CHAR_LENGTH(TRIM(working_area))) AS area_padded,
  SUM(CHAR_LENGTH(phone_no) <> CHAR_LENGTH(TRIM(phone_no))) AS phone_padded
FROM agents;

-- Workbench blocks UPDATE without a key in WHERE, so disable safe mode for cleaning
SET SQL_SAFE_UPDATES = 0;

-- Cleaning tables: remove extra spaces
UPDATE agents
SET agent_code = TRIM(agent_code),
	agent_name = TRIM(agent_name),
    working_area = TRIM(working_area),
    phone_no = TRIM(phone_no);

UPDATE customer
SET cust_city = TRIM(cust_city),
	agent_code = TRIM(agent_code);
    
UPDATE orders
SET agent_code = TRIM(agent_code);

-- count rows of country with \r in agents table
SELECT COUNT(*) AS rows_with_cr
FROM agents
WHERE country LIKE CONCAT('%', CHAR(13), '%');

-- agents.COUNTRY held only a hidden carriage return (\r) in all 12 rows,so no real country data existed. Cleaned values are set to NULL.
UPDATE agents
SET country = NULLIF(TRIM(REPLACE(country, CHAR(13), '')), '');

UPDATE orders
SET ord_description = TRIM(REPLACE(ord_description, CHAR(13), ''));

SELECT cust_code, cust_name, phone_no
FROM customer
WHERE phone_no NOT REGEXP '^[0-9]{3}-[0-9]{8}$';

-- modifying the phone_no column of customers to null, 23 of 25 customers have placeholder phone numbers; set to NULL
ALTER TABLE customer MODIFY phone_no VARCHAR(17) NULL;

UPDATE customer 
SET phone_no = NULL
WHERE phone_no NOT REGEXP '^[0-9]{3}-[0-9]{8}$';

SET SQL_SAFE_UPDATES = 1;

-- Verify cleaning: padded rows remaining (expected: all 0)
SELECT 'agents.agent_code' AS col_name, COUNT(*) AS padded_rows
FROM agents WHERE CHAR_LENGTH(agent_code) <> CHAR_LENGTH(TRIM(agent_code))
UNION ALL
SELECT 'customer.cust_city', COUNT(*)
FROM customer WHERE CHAR_LENGTH(cust_city) <> CHAR_LENGTH(TRIM(cust_city))
UNION ALL
SELECT 'customer.agent_code', COUNT(*)
FROM customer WHERE CHAR_LENGTH(agent_code) <> CHAR_LENGTH(TRIM(agent_code))
UNION ALL
SELECT 'orders.agent_code', COUNT(*)
FROM orders WHERE CHAR_LENGTH(agent_code) <> CHAR_LENGTH(TRIM(agent_code))
UNION ALL
SELECT 'orders.ord_description (CR)', COUNT(*)
FROM orders WHERE ord_description LIKE CONCAT('%', CHAR(13), '%');

-- Orphan agent check: orders referencing an agent that does not exist
SELECT DISTINCT o.agent_code AS orphan_agent_code      -- expected: A013
FROM orders o
LEFT JOIN agents a ON o.agent_code = a.agent_code
WHERE a.agent_code IS NULL;

-- Finding: 2 orders (200115, 200132) reference agent A013, which is not in the agents table.
-- Both orders belong to customer C00013, whose agent in the customer table is A003 (likely a typo).
-- Decision: data kept as-is and flagged. No assumption made about the correct agent.
SELECT ord_num, cust_code, agent_code, ord_amount
FROM orders
WHERE agent_code = 'A013';

SELECT GRADE, COUNT(*) AS customers
FROM customer
GROUP BY GRADE
ORDER BY GRADE;

-- 1.4 after analysing the data types of the columns in each table, it needs some alteration in some columns
ALTER TABLE orders MODIFY ord_num INT NOT NULL;
ALTER TABLE customer MODIFY grade TINYINT;

DESCRIBE orders;
DESCRIBE customer;

-- 1.5 Duplicate check: customer, agents and orders (expected: no rows)
SELECT cust_code, COUNT(*) AS cnt   
FROM customer
GROUP BY cust_code
HAVING COUNT(*) > 1;

SELECT agent_code, COUNT(*) AS cnt 
FROM agents
GROUP BY agent_code 
HAVING COUNT(*) > 1;

SELECT ord_num, COUNT(*) AS cnt
FROM orders
GROUP BY ord_num
HAVING COUNT(*) > 1;

SELECT cust_code, agent_code, ord_date, ord_amount,
       COUNT(*) AS cnt 
FROM orders
GROUP BY cust_code, agent_code, ord_date, ord_amount
HAVING COUNT(*) > 1;

-- Adding primary keys (customer and orders had none)
ALTER TABLE customer ADD PRIMARY KEY (cust_code);
ALTER TABLE orders ADD PRIMARY KEY (ord_num);

/* =====================================================================
   SEGMENT 2: BASIC SALES ANALYSIS
   ===================================================================== */
-- 2.1 retrieve the total number of orders, total revenue, and average order value.
SELECT COUNT(*) AS total_orders,
SUM(ord_amount) AS total_revenue,
ROUND(AVG(ord_amount),2) AS avg_order_value
FROM orders;

-- 2.2 agents who has the highest count of customers with a grade of 5
SELECT a.agent_name, COUNT(*) AS high_grade_customers
FROM agents a
JOIN customer c
ON a.agent_code = c.agent_code
WHERE c.grade = 5
GROUP BY a.agent_code, a.agent_name
ORDER BY high_grade_customers DESC
LIMIT 1;
-- Note: no customer has grade 5 (grades are 0 to 3 only), so this returns an empty result.
-- below uses the highest grade that exists instead.
SELECT a.agent_name, COUNT(*) AS high_grade_customers
FROM agents a
JOIN customer c
ON a.agent_code = c.agent_code
WHERE c.grade = (SELECT MAX(grade) FROM customer) 
GROUP BY a.agent_code, a.agent_name
ORDER BY high_grade_customers DESC
LIMIT 1;

-- 2.3 Top 3 customer cities by total order amount
SELECT c.cust_city, SUM(o.ord_amount) AS total_order_amount
FROM customer c
JOIN orders o
ON c.cust_code = o.cust_code
GROUP BY c.cust_city
ORDER BY total_order_amount DESC
LIMIT 3;

/* =====================================================================
   SEGMENT 3: CUSTOMER ANALYSIS
   ===================================================================== */
-- 3.1 Calculate the total number of customers
SELECT COUNT(*) AS total_customers FROM customer;

-- 3.2 Identify the top-spending customers based on their total order value
SELECT cust_code, cust_name, total_spent, spend_rank
FROM
	(SELECT c.cust_code, c.cust_name, SUM(o.ord_amount) AS total_spent, RANK() OVER(ORDER BY SUM(o.ord_amount) DESC) AS spend_rank
	FROM customer c
	JOIN orders o
	ON c.cust_code = o.cust_code
	GROUP BY c.cust_code, c.cust_name) t
WHERE spend_rank <= 5
ORDER BY spend_rank, cust_name;
-- Ravindran and Avinash tie at 5000, so LIMIT 5 would drop one arbitrarily; RANK() keeps both

-- 3.3 Analyse customer retention by calculating the percentage of repeat customers
SELECT COUNT(*) AS total_customers,
SUM(order_count > 1) AS repeat_customers,
ROUND(SUM(order_count > 1)/ COUNT(*) * 100,2) AS repeat_cust_percentage
FROM (
	SELECT cust_code, COUNT(*) AS order_count
	FROM orders 
	GROUP BY cust_code) t;

-- 3.4 customer with maximum outstanding amount in each country
SELECT cust_name, cust_country, outstanding_amt
FROM(	
SELECT cust_name, cust_country, outstanding_amt, RANK() OVER(PARTITION BY cust_country ORDER BY outstanding_amt DESC) AS rnk
FROM customer) t
WHERE rnk = 1
ORDER BY cust_country, cust_name;

-- 3.5 percentage of customers in each grade category (1 to 5). 
WITH RECURSIVE grades AS (
    SELECT 1 AS grade
    UNION ALL
    SELECT grade + 1 FROM grades WHERE grade < 5
)
SELECT g.grade,
       COUNT(c.cust_code) AS customers,
       ROUND(100 * COUNT(c.cust_code) / (SELECT COUNT(*) FROM customer), 2) AS pct_of_customers
FROM grades g
LEFT JOIN customer c
  ON c.grade = g.grade
GROUP BY g.grade
ORDER BY g.grade;
-- Note: grades 4 and 5 do not exist in the data, so they show 0%.

/* =====================================================================
   SEGMENT 4: AGENT PERFORMANCE ANALYSIS
   ===================================================================== */
-- 4.1 Top 5 agents by total order amount (performance bonus)
SELECT agent_code, agent_name, total_order_amount, amount_rank
FROM (
    SELECT a.agent_code,
           a.agent_name,
           SUM(o.ord_amount) AS total_order_amount,
           RANK() OVER (ORDER BY SUM(o.ord_amount) DESC) AS amount_rank
    FROM agents a
    JOIN orders o
	ON a.agent_code = o.agent_code
    GROUP BY a.agent_code, a.agent_name
) t
WHERE amount_rank <= 5
ORDER BY amount_rank, agent_name;

-- 4.2 Rank agents by number of orders handled
SELECT agent_code, agent_name, total_order_count, order_rank
FROM (
    SELECT a.agent_code,
           a.agent_name,
           COUNT(o.ord_num) AS total_order_count,
           DENSE_RANK() OVER (ORDER BY COUNT(o.ord_num) DESC) AS order_rank
    FROM agents a
    LEFT JOIN orders o
	ON a.agent_code = o.agent_code
    GROUP BY a.agent_code, a.agent_name
) t
ORDER BY order_rank, agent_name;

-- 4.3 New commission based on average advance amount collected
SELECT a.agent_code,
       a.agent_name,
       a.commission AS old_commission,
       ROUND(AVG(o.advance_amount), 2) AS avg_advance_amount,
       ROUND(
         CASE
           WHEN AVG(o.advance_amount) > 1000 THEN a.commission * 2
           WHEN AVG(o.advance_amount) >= 750 THEN a.commission * 1.5
           ELSE a.commission 
         END, 2) AS updated_commision
FROM agents a
LEFT JOIN orders o
  ON a.agent_code = o.agent_code
GROUP BY a.agent_code, a.agent_name, a.commission
ORDER BY a.agent_code;

/* =====================================================================
   SEGMENT 5: SQL TASKS
   ===================================================================== */
-- 5.1 -Add a new column named avg_rcv_amt in the table customers which contains the average receive amount for every country. Display all columns from the customer table along with the avg_rcv_amt column in the last.
-- Step 1: add a new column to store the average receive amount
ALTER TABLE customer ADD COLUMN avg_rcv_amt DECIMAL(12,2);

-- Step 2: average receive amount per country
SELECT cust_country,
       ROUND(AVG(receive_amt), 2) AS avg_rcv
FROM customer
GROUP BY cust_country
ORDER BY cust_country;

SET SQL_SAFE_UPDATES = 0;
-- Step 3: fill the new column using the per-country averages
UPDATE customer c
JOIN (SELECT cust_country,
      ROUND(AVG(receive_amt), 2) AS avg_rcv
      FROM customer
      GROUP BY cust_country) x
ON c.cust_country = x.cust_country
SET c.avg_rcv_amt = x.avg_rcv;

SET SQL_SAFE_UPDATES = 1;

SELECT * FROM customer;

-- 5.2 Write a sql query to create and call a UDF named avg_amt to return the average outstanding amount of the customers which are managed by a given agent. Also, call the UDF with the agent name ‘Mukesh’.
-- Step 1: average outstanding amount of Mukesh's customers (plain query)
SELECT AVG(c.outstanding_amt)
FROM customer c
JOIN agents a
  ON c.agent_code = a.agent_code
WHERE a.agent_name = 'Mukesh';

-- 5.2 Step 2: create UDF avg_amt
DELIMITER $$
CREATE FUNCTION avg_amt(p_agent_name VARCHAR(40))
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_avg DECIMAL(12,2);

    SELECT AVG(c.outstanding_amt)
    INTO v_avg
    FROM customer c
    JOIN agents a
	ON c.agent_code = a.agent_code
    WHERE a.agent_name = p_agent_name;

    RETURN v_avg;
END$$
DELIMITER ;
-- call the UDF with agent name 'Mukesh'
SELECT avg_amt('Mukesh') AS avg_outstanding_amt;

-- 5.3 Write a sql query to create and call a subroutine called cust_detail to return all the details of the customer which are having the given grade. Also, call the subroutine with grade 2
DELIMITER $$
CREATE PROCEDURE cust_detail(IN p_grade INT)
BEGIN
    SELECT *
    FROM customer
    WHERE grade = p_grade;
END$$
DELIMITER ;
-- call the procedure with grade 2
CALL cust_detail(2);

-- 5.4 Write a stored procedure sp_name which will return the concatenated ord_num (comma separated) of the customer with input customer code using cursor. Also, write the procedure call query with cust_code ‘C00015’.
DELIMITER $$
CREATE PROCEDURE sp_name(IN p_cust_code VARCHAR(6))
BEGIN
    DECLARE v_ord_num VARCHAR(10);
    DECLARE v_result TEXT DEFAULT '';
    DECLARE v_done INT DEFAULT 0;

    DECLARE cur_orders CURSOR FOR
        SELECT ORD_NUM
        FROM orders
        WHERE CUST_CODE = p_cust_code
        ORDER BY ORD_NUM;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = 1;

    OPEN cur_orders;

    read_loop: LOOP
        FETCH cur_orders INTO v_ord_num;
        IF v_done = 1 THEN
            LEAVE read_loop;
        END IF;

        IF v_result = '' THEN
            SET v_result = v_ord_num;
        ELSE
            SET v_result = CONCAT(v_result, ',', v_ord_num);
        END IF;
    END LOOP;

    CLOSE cur_orders;

    SELECT v_result AS ord_numbers;
END$$
DELIMITER ;

-- Call
CALL sp_name('C00015');