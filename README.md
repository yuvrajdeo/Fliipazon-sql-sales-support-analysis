# Fliipazon Retail: Sales and Support Analysis using SQL

SQL analysis of sales trends, customer behaviour and agent performance for Fliipazon Retail, written in MySQL.

## Business Problem
Fliipazon Retail wants to understand its business performance and make better decisions. As a consultant data analyst, I used SQL to clean the data and answer questions on sales, customers and agents.

## Dataset
Three tables in the `interview` database:

| Table | Rows | Description |
|---|---|---|
| `agents` | 12 | Sales agents and their commission |
| `customer` | 25 | Customer details, grade, outstanding amount, assigned agent |
| `orders` | 36 | Orders with amount, advance paid, date, customer and agent |

## Questions Covered

### Segment 1: Database, Tables, Columns, Relationships
| # | Question |
|---|---|
| 1.1 | Identify the tables and their columns |
| 1.2 | Count the records in each table |
| 1.3 | Identify and handle missing or inconsistent values |
| 1.4 | Check that data types suit the stored data |
| 1.5 | Identify duplicate records and define a handling strategy |

### Segment 2: Basic Sales Analysis
| # | Question |
|---|---|
| 2.1 | Total orders, total revenue and average order value |
| 2.2 | Agent with the most high-grade (grade 5) customers |
| 2.3 | Top 3 customer cities by total order amount |

### Segment 3: Customer Analysis
| # | Question |
|---|---|
| 3.1 | Total number of customers |
| 3.2 | Top-spending customers by total order value |
| 3.3 | Customer retention: percentage of repeat customers |
| 3.4 | Customer with the maximum outstanding amount in each country |
| 3.5 | Percentage of customers in each grade (1 to 5) |

### Segment 4: Agent Performance Analysis
| # | Question |
|---|---|
| 4.1 | Top 5 agents for a performance bonus |
| 4.2 | Rank agents by number of orders handled |
| 4.3 | Revised commission based on average advance amount collected |

### Segment 5: SQL Tasks
| # | Question |
|---|---|
| 5.1 | Add a column with the average receive amount per country |
| 5.2 | User-defined function `avg_amt` (average outstanding amount for an agent) |
| 5.3 | Stored procedure `cust_detail` (customers of a given grade) |
| 5.4 | Stored procedure `sp_name` using a cursor (comma-separated order numbers of a customer) |


## Data Cleaning
| Issue found | Fix |
|---|---|
| Trailing spaces in text columns (agent code, name, city, etc.) | `TRIM()` |
| Hidden carriage return (`\r`) in `agents.COUNTRY` and `orders.ORD_DESCRIPTION` | `REPLACE(col, CHAR(13), '')` |
| `agents.COUNTRY` had no real values | Set to `NULL` |
| 23 of 25 customer phone numbers were placeholders (e.g. `BBBBBBB`) | Set to `NULL` using `REGEXP` |
| 2 orders reference agent `A013`, who is not in `agents` | Kept as-is and flagged, no assumption made |
| No primary keys on `customer` and `orders` | Added primary keys |
| Oversized data types (`ORD_NUM`, `GRADE`) | Changed to `INT` and `TINYINT` |
| No duplicate records | Checked by ID and by order details |
| Grades only range from 0 to 3 (no grade 4 or 5) | Noted; affects Segments 2 and 3 |

## Key Findings
- **Sales:** 36 orders, total revenue 78,600, average order value 2,183.33.
- **Top cities by order amount:** Chennai (17,000), Mumbai (12,700), London (12,500).
- **Customers:** 25 customers; 32% (8 of 25) are repeat customers. Top spender is Ramanathan (10,500).
- **Top 5 agents by order amount:** Santakumar, Mukesh, Ivan, Anderson, Alford.
- **Most orders handled:** Mukesh (7 orders).
- **Commission revision:** Anderson (0.13 to 0.26) and Alford (0.12 to 0.24). No agent falls in the 750-1000 band.
- **Grade split:** grade 1 = 36%, grade 2 = 40%, grade 3 = 20%, grades 4 and 5 = 0%.

## Assumptions
- "Maximum order amount" for the agent bonus is taken as the total order amount per agent.
- Repeat customers are those with more than one order.
- `grade = 5` returns no rows because no customer has that grade; a data-driven version uses the highest grade that exists.
- Orders of the unknown agent A013 are excluded from agent-level reports.

## SQL Skills Used
Data cleaning, JOINs, GROUP BY / HAVING, subqueries, CTEs (including recursive), window functions (`RANK`, `DENSE_RANK`, `PARTITION BY`), `CASE`, user-defined function, stored procedures, cursor.

## Deliverables
- `data_setup.sql`: creates the database, tables and data
- `sales_support_analysis.sql`: cleaning and all analysis queries (Segments 1 to 5), commented and organised by task number
- `Sales and Support Analysis.docx`: detailed written analysis and interpretation of the results
- `Fliipazon_SQL_Analysis.pptx`: presentation of key findings and recommendations

## How to Run
1. Run `data_setup.sql` in MySQL Workbench.
2. Run `sales_support_analysis.sql` once from top to bottom (MySQL 8.0+ required).

## Author
Yuvraj Kumar Deo

If you found this project useful, feel free to ⭐ the repo!
