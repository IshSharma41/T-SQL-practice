---------------------------------------------------------------------
-- Inside Microsoft SQL Server 2005: T-SQL Querying (MSPress, 2006)
-- Chapter 05 - Joins and Set Operations
-- Copyright Itzik Ben-Gan, 2006
-- All Rights Reserved
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Joins
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Old-Style vs. New Style
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Fundamental Join Types
---------------------------------------------------------------------

---------------------------------------------------------------------
-- CROSS
---------------------------------------------------------------------

SET NOCOUNT ON;
USE Northwind;
GO

-- Get all Possible Combinations, ANSI SQL:1989
SELECT E1.FirstName, E1.LastName AS emp1,
  E2.FirstName, E2.LastName AS emp2
FROM dbo.Employees AS E1, dbo.Employees AS E2;

-- Get all Possible Combinations, ANSI SQL:1992
SELECT E1.FirstName, E1.LastName AS emp1,
  E2.FirstName, E2.LastName AS emp2
FROM dbo.Employees AS E1
  CROSS JOIN dbo.Employees AS E2;
GO

-- Generate Duplicates, using a Literal
SELECT CustomerID, EmployeeID,
  DATEADD(day, n-1, '20060101') AS OrderDate
FROM dbo.Customers, dbo.Employees, dbo.Nums
WHERE n <= 31;
GO

-- Make Sure MyOrders does not Exist
IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
GO

-- Generate Duplicates, using Arguments, 2005
DECLARE @fromdate AS DATETIME, @todate AS DATETIME;
SET @fromdate = '20060101';
SET @todate = '20060131';

SELECT IDENTITY(int, 1, 1) AS OrderID,
  CustomerID, EmployeeID,
  DATEADD(day, n-1, @fromdate) AS OrderDate
INTO dbo.MyOrders
FROM dbo.Customers, dbo.Employees, dbo.Nums
WHERE n <= DATEDIFF(day, @fromdate, @todate) + 1;
GO

-- Make Sure MyOrders does not Exist
IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
GO

DECLARE @fromdate AS DATETIME, @todate AS DATETIME;
SET @fromdate = '20060101';
SET @todate = '20060131';

WITH Orders
AS
( 
  SELECT CustomerID, EmployeeID,
    DATEADD(day, n-1, @fromdate) AS OrderDate
  FROM dbo.Customers, dbo.Employees, dbo.Nums
  WHERE n <= DATEDIFF(day, @fromdate, @todate) + 1
)
SELECT ROW_NUMBER() OVER(ORDER BY OrderDate) AS OrderID,
  CustomerID, EmployeeID, OrderDate
INTO dbo.MyOrders
FROM Orders;
GO

-- Cleanup
DROP TABLE dbo.MyOrders;
GO

-- Avoiding Multiple Subqueries
USE pubs;
GO

-- Create an Index on the qty Column
CREATE INDEX idx_qty ON dbo.sales(qty);
GO

-- Obtaining Aggregates with Subqueries
SELECT stor_id, ord_num, title_id, 
  CONVERT(VARCHAR(10), ord_date, 120) AS ord_date, qty,
  CAST(1.*qty / (SELECT SUM(qty) FROM dbo.sales) * 100
       AS DECIMAL(5, 2)) AS per,
  qty - (SELECT AVG(qty) FROM dbo.sales) AS diff
FROM dbo.sales;

-- Obtaining Aggregates with Cross Join
SELECT stor_id, ord_num, title_id, 
  CONVERT(VARCHAR(10), ord_date, 120) AS ord_date, qty,
  CAST(1.*qty / sumqty * 100 AS DECIMAL(5, 2)) AS per,
  qty - avgqty as diff
FROM dbo.sales,
  (SELECT SUM(qty) AS sumqty, AVG(qty) AS avgqty
   FROM dbo.sales) AS AGG;

-- Obtaining Aggregates with Cross Join using a CTE
WITH Agg AS
(
  SELECT SUM(qty) AS sumqty, AVG(qty) AS avgqty
  FROM dbo.sales
)
SELECT stor_id, ord_num, title_id, 
  CONVERT(VARCHAR(10), ord_date, 120) AS ord_date, qty,
  CAST(1.*qty / sumqty * 100 AS DECIMAL(5, 2)) AS per,
  qty - avgqty as diff
FROM dbo.sales, Agg;

-- Cleanup
DROP INDEX dbo.sales.idx_qty;
GO

---------------------------------------------------------------------
-- INNER
---------------------------------------------------------------------
USE Northwind;
GO

-- Inner Join, ANSI SQL:1992
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C
  JOIN dbo.Orders AS O
    ON C.CustomerID = O.CustomerID
WHERE Country = 'USA';

-- Inner Join, ANSI SQL:1989
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C, dbo.Orders AS O
WHERE C.CustomerID = O.CustomerID
  AND Country = 'USA';
GO

-- Forgetting to Specify Join Condition, ANSI SQL:1989
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C, dbo.Orders AS O;
GO

-- Forgetting to Specify Join Condition, ANSI SQL:1989
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C JOIN dbo.Orders AS O;
GO

---------------------------------------------------------------------
-- OUTER
---------------------------------------------------------------------

-- Outer Join, ANSI SQL:1992
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C
  LEFT OUTER JOIN dbo.Orders AS O
    ON C.CustomerID = O.CustomerID;
GO

-- Changing the Database Compatibility Level to 2000
EXEC sp_dbcmptlevel Northwind, 80;
GO

-- Outer Join, Old-Style Non-ANSI
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C, dbo.Orders AS O
WHERE C.CustomerID *= O.CustomerID;
GO

-- Outer Join with Filter, ANSI SQL:1992
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C
  LEFT OUTER JOIN dbo.Orders AS O
    ON C.CustomerID = O.CustomerID
WHERE O.CustomerID IS NULL;

-- Outer Join with Filter, Old-Style Non-ANSI
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C, dbo.Orders AS O
WHERE C.CustomerID *= O.CustomerID
  AND O.CustomerID IS NULL;

-- "Fixing" Outer Join in Old-Style Problem
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C, dbo.Orders AS O
WHERE C.CustomerID *= O.CustomerID
GROUP BY C.CustomerID, CompanyName, OrderID
HAVING OrderID IS NULL;
GO

-- Changing the Database Compatibility Level Back to 2005
EXEC sp_dbcmptlevel Northwind, 90;
GO

-- Listing 5-1: Creating and Populating the Table T1
USE tempdb;
GO
IF OBJECT_ID('dbo.T1') IS NOT NULL
  DROP TABLE dbo.T1;
GO

CREATE TABLE dbo.T1
(
  keycol  INT         NOT NULL PRIMARY KEY,
  datacol VARCHAR(10) NOT NULL
);
INSERT INTO dbo.T1(keycol, datacol) VALUES(1, 'e');
INSERT INTO dbo.T1(keycol, datacol) VALUES(2, 'f');
INSERT INTO dbo.T1(keycol, datacol) VALUES(3, 'a');
INSERT INTO dbo.T1(keycol, datacol) VALUES(4, 'b');
INSERT INTO dbo.T1(keycol, datacol) VALUES(6, 'c');
INSERT INTO dbo.T1(keycol, datacol) VALUES(7, 'd');

-- Using Correlated Subquery to Find Minimum Missing Value
SELECT MIN(A.keycol + 1)
FROM dbo.T1 AS A
WHERE NOT EXISTS
  (SELECT * FROM dbo.T1 AS B
   WHERE B.keycol = A.keycol + 1);

-- Using Outer Join to Find Minimum Missing Value
SELECT MIN(A.keycol + 1)
FROM dbo.T1 AS A
  LEFT OUTER JOIN dbo.T1 AS B
    ON B.keycol = A.keycol + 1
WHERE B.keycol IS NULL;
GO

---------------------------------------------------------------------
-- Non-Supported Join Types
---------------------------------------------------------------------

---------------------------------------------------------------------
-- NATURAL, UNION Joins
---------------------------------------------------------------------
USE Northwind;
GO

-- NATURAL Join
/*
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C NATURAL JOIN dbo.Orders AS O;
*/

-- Logically Equivalent Inner Join
SELECT C.CustomerID, CompanyName, OrderID
FROM dbo.Customers AS C
  JOIN dbo.Orders AS O
    ON O.CustomerID = O.CustomerID;
GO

---------------------------------------------------------------------
-- Other Categorizations of Joins
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Self Joins
---------------------------------------------------------------------
USE Northwind;
GO

SELECT E.FirstName, E.LastName AS emp,
  M.FirstName, M.LastName AS mgr
FROM dbo.Employees AS E
  LEFT OUTER JOIN dbo.Employees AS M
    ON E.ReportsTo = M.EmployeeID;
GO

---------------------------------------------------------------------
-- Non-Equi Joins
---------------------------------------------------------------------

-- Cross without Mirrored Pairs and without Self
SELECT E1.EmployeeID, E1.LastName, E1.FirstName,
  E2.EmployeeID, E2.LastName, E2.FirstName
FROM dbo.Employees AS E1
  JOIN dbo.Employees AS E2
    ON E1.EmployeeID < E2.EmployeeID;

-- Calculating Row Numbers using a Join
SELECT O1.OrderID, O1.CustomerID, O1.EmployeeID, COUNT(*) AS rn
FROM dbo.Orders AS O1
  JOIN dbo.Orders AS O2
    ON O2.OrderID <= O1.OrderID
GROUP BY O1.OrderID, O1.CustomerID, O1.EmployeeID;

---------------------------------------------------------------------
-- Multi-Table Joins
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Controlling the Physical Join Evaluation Order 
---------------------------------------------------------------------

-- Suppliers that Supplied Products to Customers
SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID
  JOIN dbo.[Order Details] AS OD
    ON OD.OrderID = O.OrderID
  JOIN dbo.Products AS P
    ON P.ProductID = OD.ProductID
  JOIN dbo.Suppliers AS S
    ON S.SupplierID = P.SupplierID;

-- Controlling the Physical Join Evaluation Order 
SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID
  JOIN dbo.[Order Details] AS OD
    ON OD.OrderID = O.OrderID
  JOIN dbo.Products AS P
    ON P.ProductID = OD.ProductID
  JOIN dbo.Suppliers AS S
    ON S.SupplierID = P.SupplierID
OPTION (FORCE ORDER);

---------------------------------------------------------------------
-- Controlling the Logical Join Evaluation Order
---------------------------------------------------------------------

-- Including Customers with no Orders, Attempt with Left Join
SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  LEFT OUTER JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID
  JOIN dbo.[Order Details] AS OD
    ON OD.OrderID = O.OrderID
  JOIN dbo.Products AS P
    ON P.ProductID = OD.ProductID
  JOIN dbo.Suppliers AS S
    ON S.SupplierID = P.SupplierID;

-- Multiple Left Joins
SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  LEFT OUTER JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID
  LEFT OUTER JOIN dbo.[Order Details] AS OD
    ON OD.OrderID = O.OrderID
  LEFT OUTER JOIN dbo.Products AS P
    ON P.ProductID = OD.ProductID
  LEFT OUTER JOIN dbo.Suppliers AS S
    ON S.SupplierID = P.SupplierID;

-- Right Join Performed Last
SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Orders AS O
  JOIN dbo.[Order Details] AS OD
    ON OD.OrderID = O.OrderID
  JOIN dbo.Products AS P
    ON P.ProductID = OD.ProductID
  JOIN dbo.Suppliers AS S
    ON S.SupplierID = P.SupplierID
  RIGHT OUTER JOIN dbo.Customers AS C
    ON O.CustomerID = C.CustomerID;

-- Using Parenthesis
SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  LEFT OUTER JOIN 
    (dbo.Orders AS O
       JOIN dbo.[Order Details] AS OD
         ON OD.OrderID = O.OrderID
       JOIN dbo.Products AS P
         ON P.ProductID = OD.ProductID
       JOIN dbo.Suppliers AS S
         ON S.SupplierID = P.SupplierID)
      ON O.CustomerID = C.CustomerID;

-- Changing ON Clause Order
SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  LEFT OUTER JOIN 
    dbo.Orders AS O
       JOIN dbo.[Order Details] AS OD
         ON OD.OrderID = O.OrderID
       JOIN dbo.Products AS P
         ON P.ProductID = OD.ProductID
       JOIN dbo.Suppliers AS S
         ON S.SupplierID = P.SupplierID
      ON O.CustomerID = C.CustomerID;

SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  LEFT OUTER JOIN dbo.Orders AS O
  JOIN dbo.Products AS P
  JOIN dbo.[Order Details] AS OD
    ON P.ProductID = OD.ProductID
    ON OD.OrderID = O.OrderID
  JOIN dbo.Suppliers AS S
    ON S.SupplierID = P.SupplierID
    ON O.CustomerID = C.CustomerID;

SELECT DISTINCT C.CompanyName AS customer, S.CompanyName AS supplier
FROM dbo.Customers AS C
  LEFT OUTER JOIN dbo.Orders AS O
  JOIN dbo.[Order Details] AS OD
  JOIN dbo.Products AS P
  JOIN dbo.Suppliers AS S
    ON S.SupplierID = P.SupplierID
    ON P.ProductID = OD.ProductID
    ON OD.OrderID = O.OrderID
    ON O.CustomerID = C.CustomerID;
GO

---------------------------------------------------------------------
-- Semi Joins
---------------------------------------------------------------------

-- Left Semi Join
SELECT DISTINCT C.CustomerID, C.CompanyName
FROM dbo.Customers AS C
  JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID
WHERE Country = N'Spain';

-- Left Semi Join using EXISTS
SELECT CustomerID, CompanyName
FROM dbo.Customers AS C
WHERE Country = N'Spain'
  AND EXISTS
    (SELECT * FROM dbo.Orders AS O
     WHERE O.CustomerID = C.CustomerID);

-- Left Anti Semi Join
SELECT C.CustomerID, C.CompanyName
FROM dbo.Customers AS C
  LEFT OUTER JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID
WHERE Country = N'Spain'
  AND O.CustomerID IS NULL;

-- Left Anti Semi Join uing EXISTS
SELECT CustomerID, CompanyName
FROM dbo.Customers AS C
WHERE Country = N'Spain'
  AND NOT EXISTS
    (SELECT * FROM dbo.Orders AS O
     WHERE O.CustomerID = C.CustomerID);

---------------------------------------------------------------------
-- Sliding Total of Previous Year
---------------------------------------------------------------------

-- Listing 5-2: Creating and Populating the MonthlyOrders Table
IF OBJECT_ID('dbo.MonthlyOrders') IS NOT NULL
  DROP TABLE dbo.MonthlyOrders;
GO

SELECT 
  CAST(CONVERT(CHAR(6), OrderDate, 112) + '01' AS DATETIME)
    AS ordermonth,
  COUNT(*) AS numorders
INTO dbo.MonthlyOrders
FROM dbo.Orders
GROUP BY CAST(CONVERT(CHAR(6), OrderDate, 112) + '01' AS DATETIME);

CREATE UNIQUE CLUSTERED INDEX idx_ordermonth ON dbo.MonthlyOrders(ordermonth);
GO

-- Querying the Content of MonthlyOrders
SELECT * FROM dbo.MonthlyOrders;

-- Self, Non-Equi, Multi-Table Join
-- Sliding Total of Previous Year
SELECT 
  CONVERT(VARCHAR(6), O1.ordermonth, 112) AS frommonth,
  CONVERT(VARCHAR(6), O2.ordermonth, 112) AS tomonth,
  SUM(O3.numorders) AS numorders
FROM dbo.MonthlyOrders AS O1
  JOIN dbo.MonthlyOrders AS O2
    ON DATEADD(month, -11, O2.ordermonth) = O1.ordermonth
  JOIN dbo.MonthlyOrders AS O3
    ON O3.ordermonth BETWEEN O1.ordermonth AND O2.ordermonth
GROUP BY O1.ordermonth, O2.ordermonth;

-- Sliding Total of Previous Year, Including all Months
SELECT 
  CONVERT(VARCHAR(6), 
    COALESCE(O1.ordermonth,
      (SELECT MIN(ordermonth) FROM dbo.MonthlyOrders)),
    112) AS frommonth,
  CONVERT(VARCHAR(6), O2.ordermonth, 112) AS tomonth,
  SUM(O3.numorders) AS numorders,
  DATEDIFF(month,
    COALESCE(O1.ordermonth,
      (SELECT MIN(ordermonth) FROM dbo.MonthlyOrders)),
    O2.ordermonth) + 1 AS nummonths
FROM dbo.MonthlyOrders AS O1
  RIGHT JOIN dbo.MonthlyOrders AS O2
    ON DATEADD(month, -11, O2.ordermonth) = O1.ordermonth
  JOIN dbo.MonthlyOrders AS O3
    ON O3.ordermonth BETWEEN COALESCE(O1.ordermonth, '19000101')
                         AND O2.ordermonth
GROUP BY O1.ordermonth, O2.ordermonth;

-- Cleanup
DROP TABLE dbo.MonthlyOrders;
GO

---------------------------------------------------------------------
-- Join Algorithms
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Nested Loops
---------------------------------------------------------------------

-- Nested Loops
SELECT C.CustomerID, C.CompanyName, O.OrderID, O.OrderDate
FROM dbo.Customers AS C
 JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID
WHERE C.CustomerID = N'ALFKI';
GO

---------------------------------------------------------------------
-- Merge
---------------------------------------------------------------------

-- Merge
SELECT O.OrderID, O.OrderDate, OD.ProductID, OD.Quantity
FROM dbo.Orders AS O
  JOIN dbo.[Order Details] AS OD
    ON O.OrderID = OD.OrderID;

-- Merge with Sort
SELECT C.CustomerID, CompanyName, ContactName, ContactTitle,
  OrderID, OrderDate
FROM dbo.Customers AS C
 JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID;
GO

---------------------------------------------------------------------
-- Hash
---------------------------------------------------------------------

-- Drop MyOrders and MyOrderDetails if already Exist
IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
IF OBJECT_ID('dbo.MyOrderDetails') IS NOT NULL
  DROP TABLE dbo.MyOrderDetails;
GO

-- Create Copies of MyOrders and MyOrderDetails
SELECT * INTO dbo.MyOrders FROM dbo.Orders;
SELECT * INTO dbo.MyOrderDetails FROM dbo.[Order Details];
GO

-- Hash
SELECT O.OrderID, O.OrderDate, OD.ProductID, OD.Quantity
FROM dbo.MyOrders AS O
  JOIN dbo.MyOrderDetails AS OD
    ON O.OrderID = OD.OrderID;

-- Cleanup
DROP TABLE dbo.MyOrders;
DROP TABLE dbo.MyOrderDetails;
GO

-- Forcing Join Strategy
SELECT C.CustomerID, C.CompanyName, O.OrderID
FROM dbo.Customers AS C
 INNER LOOP JOIN dbo.Orders AS O
    ON O.CustomerID = C.CustomerID;

SELECT C.CustomerID, C.CompanyName, O.OrderID
FROM dbo.Customers AS C, dbo.Orders AS O
WHERE O.CustomerID = C.CustomerID
OPTION (LOOP JOIN);

---------------------------------------------------------------------
-- Separating Elements
---------------------------------------------------------------------

-- Listing 5-3: Creating and Populating the Table Arrays
USE tempdb;
GO
IF OBJECT_ID('dbo.Arrays') IS NOT NULL
  DROP TABLE dbo.Arrays;
GO

CREATE TABLE dbo.Arrays
(
  arrid VARCHAR(10)   NOT NULL PRIMARY KEY,
  array VARCHAR(8000) NOT NULL
)

INSERT INTO Arrays(arrid, array) VALUES('A', '20,22,25,25,14');
INSERT INTO Arrays(arrid, array) VALUES('B', '30,33,28');
INSERT INTO Arrays(arrid, array) VALUES('C', '12,10,8,12,12,13,12,14,10,9');
INSERT INTO Arrays(arrid, array) VALUES('D', '-4,-6,-4,-2');
GO

-- Solution to Separating Elements Problem, Step 1
SELECT arrid, array, n
FROM dbo.Arrays
  JOIN dbo.Nums
    ON n <= LEN(array)
    AND SUBSTRING(array, n, 1) = ',';

-- Solution to Separating Elements Problem, Step 2
SELECT arrid, array, n
FROM dbo.Arrays
  JOIN dbo.Nums
    ON n <= LEN(array)
    AND SUBSTRING(',' + array, n, 1) = ',';

-- Solution to Separating Elements Problem, Step 3
SELECT arrid, 
  SUBSTRING(array, n, CHARINDEX(',', array + ',', n) - n) AS element
FROM dbo.Arrays
  JOIN dbo.Nums
    ON n <= LEN(array)
    AND SUBSTRING(',' + array, n, 1) = ',';

-- Solution to Separating Elements Problem, Step 4
SELECT arrid,
  n - LEN(REPLACE(LEFT(array, n), ',', '')) + 1 AS pos,
  CAST(SUBSTRING(array, n, CHARINDEX(',', array + ',', n) - n)
       AS INT) AS element
FROM dbo.Arrays
  JOIN dbo.Nums
    ON n <= LEN(array)
    AND SUBSTRING(',' + array, n, 1) = ',';

-- Solution based on Recursive CTEs
WITH SplitCTE AS
(
  SELECT arrid, 1 AS pos, 1 AS startpos,
    CHARINDEX(',', array + ',') - 1 AS endpos
  FROM dbo.Arrays
  WHERE LEN(array) > 0

  UNION ALL

  SELECT Prv.arrid, Prv.pos + 1, Prv.endpos + 2,
    CHARINDEX(',', Cur.array + ',', Prv.endpos + 2) - 1
  FROM SplitCTE AS Prv
    JOIN dbo.Arrays AS Cur
      ON Cur.arrid = Prv.arrid
      AND CHARINDEX(',', Cur.array + ',', Prv.endpos + 2) > 0
)
SELECT A.arrid, pos,
  CAST(SUBSTRING(array, startpos, endpos-startpos+1) AS INT) AS element
FROM dbo.Arrays AS A
  JOIN SplitCTE AS S
    ON S.arrid = A.arrid
ORDER BY arrid, pos;

-- Solution that "Seems" Correct
SELECT CAST(arrid AS VARCHAR(10)) AS arrid,
    REPLACE(array, ',',
      CHAR(13)+CHAR(10) + CAST(arrid AS VARCHAR(10))+SPACE(10)) AS value
FROM dbo.Arrays;
GO

---------------------------------------------------------------------
-- Set Operations
---------------------------------------------------------------------

---------------------------------------------------------------------
-- UNION
---------------------------------------------------------------------

---------------------------------------------------------------------
-- UNION DISTINCT
---------------------------------------------------------------------

USE Northwind;
GO

-- UNION DISTINCT
SELECT Country, Region, City FROM dbo.Employees
UNION
SELECT Country, Region, City FROM dbo.Customers;

---------------------------------------------------------------------
-- UNION ALL
---------------------------------------------------------------------

-- UNION ALL
SELECT Country, Region, City FROM dbo.Employees
UNION ALL
SELECT Country, Region, City FROM dbo.Customers;

---------------------------------------------------------------------
-- EXCEPT
---------------------------------------------------------------------

---------------------------------------------------------------------
-- EXCEPT DISTINCT
---------------------------------------------------------------------

-- EXCEPT DISTINCT, Pre-2005
SELECT Country, Region, City
FROM (SELECT DISTINCT 'E' AS Source, Country, Region, City
      FROM dbo.Employees
      UNION ALL
      SELECT DISTINCT 'C', Country, Region, City
      FROM dbo.Customers) AS UA
GROUP BY Country, Region, City
HAVING COUNT(*) = 1 AND MAX(Source) = 'E';

-- EXCEPT DISTINCT, Employees EXCEPT Customers
SELECT Country, Region, City FROM dbo.Employees
EXCEPT
SELECT Country, Region, City FROM dbo.Customers;

-- EXCEPT DISTINCT, Customers EXCEPT Employees
SELECT Country, Region, City FROM dbo.Customers
EXCEPT
SELECT Country, Region, City FROM dbo.Employees;

---------------------------------------------------------------------
-- EXCEPT ALL
---------------------------------------------------------------------

-- EXCEPT ALL, Pre-2005
SELECT Country, Region, City
FROM (SELECT Country, Region, City,
        MAX(CASE WHEN Source = 'E' THEN Cnt ELSE 0 END) ECnt,
        MAX(CASE WHEN Source = 'C' THEN Cnt ELSE 0 END) CCnt
      FROM (SELECT 'E' AS Source, 
              Country, Region, City, COUNT(*) AS Cnt
            FROM dbo.Employees
            GROUP BY Country, Region, City

            UNION ALL

            SELECT 'C', Country, Region, City, COUNT(*)
            FROM dbo.Customers
            GROUP BY Country, Region, City) AS UA
      GROUP BY Country, Region, City) AS P
  JOIN dbo.Nums
    ON n <= ECnt - CCnt;

-- EXCEPT ALL
WITH EXCEPT_ALL
AS
(
  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY Country, Region, City
           ORDER     BY Country, Region, City) AS rn,
    Country, Region, City
    FROM dbo.Employees

  EXCEPT

  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY Country, Region, City
           ORDER     BY Country, Region, City) AS rn,
    Country, Region, City
  FROM dbo.Customers
)
SELECT Country, Region, City
FROM EXCEPT_ALL;

---------------------------------------------------------------------
-- INTERSCET
---------------------------------------------------------------------

---------------------------------------------------------------------
-- INTERSECT DISTINCT
---------------------------------------------------------------------

-- INTERSECT DISTINCT, Pre-2005
SELECT Country, Region, City
FROM (SELECT DISTINCT Country, Region, City FROM dbo.Employees
      UNION ALL
      SELECT DISTINCT Country, Region, City FROM dbo.Customers) AS UA
GROUP BY Country, Region, City
HAVING COUNT(*) = 2;

-- INTERSECT DISTINCT
SELECT Country, Region, City FROM dbo.Employees
INTERSECT
SELECT Country, Region, City FROM dbo.Customers;

---------------------------------------------------------------------
-- INTERSECT ALL
---------------------------------------------------------------------

-- INTERSECT ALL, Pre-2005
SELECT Country, Region, City
FROM (SELECT Country, Region, City, MIN(Cnt) AS MinCnt
      FROM (SELECT Country, Region, City, COUNT(*) AS Cnt
            FROM dbo.Employees
            GROUP BY Country, Region, City

            UNION ALL

            SELECT Country, Region, City, COUNT(*)
            FROM dbo.Customers
            GROUP BY Country, Region, City) AS UA
      GROUP BY Country, Region, City
      HAVING COUNT(*) > 1) AS D
  JOIN dbo.Nums
    ON n <= MinCnt;

-- INTERSECT ALL
WITH INTERSECT_ALL
AS
(
  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY Country, Region, City
           ORDER     BY Country, Region, City) AS rn,
    Country, Region, City
  FROM dbo.Employees

  INTERSECT

  SELECT
    ROW_NUMBER() 
      OVER(PARTITION BY Country, Region, City
           ORDER     BY Country, Region, City) AS rn,
    Country, Region, City
    FROM dbo.Customers
)
SELECT Country, Region, City
FROM INTERSECT_ALL;

---------------------------------------------------------------------
-- Precedence
---------------------------------------------------------------------

-- INTERSECT Precedes EXCEPT
SELECT Country, Region, City FROM dbo.Suppliers
EXCEPT
SELECT Country, Region, City FROM dbo.Employees
INTERSECT
SELECT Country, Region, City FROM dbo.Customers;

-- Using Parenthesis
(SELECT Country, Region, City FROM dbo.Suppliers
 EXCEPT
 SELECT Country, Region, City FROM dbo.Employees)
INTERSECT
SELECT Country, Region, City FROM dbo.Customers;

-- Using INTO with Set Operations
SELECT Country, Region, City INTO #T FROM dbo.Suppliers
EXCEPT
SELECT Country, Region, City FROM dbo.Employees
INTERSECT
SELECT Country, Region, City FROM dbo.Customers;

-- Cleanup
DROP TABLE #T;
GO

---------------------------------------------------------------------
-- Circumventing Unsupported Logical Phases
---------------------------------------------------------------------

-- Number of Cities per Country Covered by Both Customers
-- and Employees
SELECT Country, COUNT(*) AS NumCities
FROM (SELECT Country, Region, City FROM dbo.Employees
      UNION
      SELECT Country, Region, City FROM dbo.Customers) AS U
GROUP BY Country;

-- Two most recent orders for employees 3 and 5
SELECT EmployeeID, OrderID, OrderDate
FROM (SELECT TOP 2 EmployeeID, OrderID, OrderDate
      FROM dbo.Orders
      WHERE EmployeeID = 3
      ORDER BY OrderDate DESC, OrderID DESC) AS D1

UNION ALL

SELECT EmployeeID, OrderID, OrderDate
FROM (SELECT TOP 2 EmployeeID, OrderID, OrderDate
      FROM dbo.Orders
      WHERE EmployeeID = 5
      ORDER BY OrderDate DESC, OrderID DESC) AS D2;

-- Sorting each Input Independently
SELECT EmployeeID, CustomerID, OrderID, OrderDate
FROM (SELECT 1 AS SortCol, CustomerID, EmployeeID, OrderID, OrderDate
      FROM dbo.Orders
      WHERE CustomerID = N'ALFKI'

      UNION ALL

      SELECT 2 AS SortCol, CustomerID, EmployeeID, OrderID, OrderDate
      FROM dbo.Orders
      WHERE EmployeeID = 3) AS U
ORDER BY SortCol,
  CASE WHEN SortCol = 1 THEN OrderID END,
  CASE WHEN SortCol = 2 THEN OrderDate END DESC;
