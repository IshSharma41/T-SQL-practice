/*
Oregon's Prior Month's Sales
ID: 2160
Difficulty: Easy
Last Updated: December 2025

Problem:
Calculate the total revenue generated from Oregon-based customers
for April 2022.
*/

SELECT 
    SUM(O.cost_in_dollars * O.units_sold) AS total_revenue
FROM online_customers AS C
JOIN online_orders AS O
    ON O.customer_id = C.id
WHERE C.state = 'Oregon'
  AND MONTH(O.date_sold) = 4
  AND YEAR(O.date_sold) = 2022;
