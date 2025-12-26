---------------------------------------------------------------------
-- Inside Microsoft SQL Server 2005: T-SQL Querying (MSPress, 2006)
-- Chapter 07 - TOP and APPLY
-- Copyright Itzik Ben-Gan, 2006
-- All Rights Reserved
---------------------------------------------------------------------

---------------------------------------------------------------------
-- SELECT TOP
---------------------------------------------------------------------
SET NOCOUNT ON;
GO

-- Three Most-Recent Orders
USE Northwind;

SELECT TOP(3) OrderID, CustomerID, OrderDate
FROM dbo.Orders
ORDER BY OrderDate DESC, OrderID DESC;

-- Most-Recent One Percent of Orders
SELECT TOP(1) PERCENT OrderID, CustomerID, OrderDate
FROM dbo.Orders
ORDER BY OrderDate DESC, OrderID DESC;
GO

---------------------------------------------------------------------
-- TOP and Determinism
---------------------------------------------------------------------

-- Non-Determinstic
SELECT TOP(3) OrderID, CustomerID, OrderDate
FROM dbo.Orders;

-- Non-Determinstic
SELECT TOP(3) OrderID, CustomerID, OrderDate
FROM dbo.Orders
ORDER BY CustomerID;

-- Determinstic
SELECT TOP(3) OrderID, CustomerID, OrderDate
FROM dbo.Orders
ORDER BY CustomerID, OrderID;

-- Determinstic
SELECT TOP(3) WITH TIES OrderID, CustomerID, OrderDate
FROM dbo.Orders
ORDER BY CustomerID;
GO

---------------------------------------------------------------------
-- TOP and Input Expressions
---------------------------------------------------------------------

-- Top @n Most Recent Orders
DECLARE @n AS INT;
SET @n = 2;

SELECT TOP(@n) OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.Orders
ORDER BY OrderDate DESC, OrderID DESC;

-- Most Recent Average Number of Monthly Orders
SELECT TOP(SELECT COUNT(*)/(DATEDIFF(month,
             MIN(OrderDate), MAX(OrderDate))+1)
           FROM dbo.Orders)
  OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.Orders
ORDER BY OrderDate DESC, OrderID DESC;
GO

---------------------------------------------------------------------
-- TOP and Modifications
---------------------------------------------------------------------

-- Modifying Large Volumes of Data
-- Purging Data in Batches

-- Creating and Populating the LargeOrders Table 
IF OBJECT_ID('dbo.LargeOrders') IS NOT NULL
  DROP TABLE dbo.LargeOrders;
GO
SELECT IDENTITY(int, 1, 1) AS OrderID,
  O1.CustomerID, O1.EmployeeID, O1.OrderDate, O1.RequiredDate,
  O1.ShippedDate, O1.ShipVia, O1.Freight, O1.ShipName, O1.ShipAddress,
  O1.ShipCity, O1.ShipRegion, O1.ShipPostalCode, O1.ShipCountry
INTO dbo.LargeOrders
FROM dbo.Orders AS O1, dbo.Orders AS O2;

CREATE UNIQUE CLUSTERED INDEX idx_od_oid
  ON dbo.LargeOrders(OrderDate, OrderID);
GO

-- Solution Prior to SQL Server 2005
SET ROWCOUNT 5000;
WHILE 1 = 1
BEGIN
  DELETE FROM dbo.LargeOrders
  WHERE OrderDate < '19970101';

  IF @@rowcount < 5000 BREAK;
END
SET ROWCOUNT 0;

-- Solution in SQL Server 2005
WHILE 1 = 1
BEGIN
  DELETE TOP(5000) FROM dbo.LargeOrders
  WHERE OrderDate < '19970101';
  
  IF @@rowcount < 5000 BREAK;
END
GO

-- Updating Data in Batches

-- Solution Prior to SQL Server 2005
SET ROWCOUNT 5000;
WHILE 1 = 1
BEGIN
  UPDATE dbo.LargeOrders
    SET CustomerID = N'ABCDE'
  WHERE CustomerID = N'OLDWO';
  
  IF @@rowcount < 5000 BREAK;
END
SET ROWCOUNT 0;

-- Solution in SQL Server 2005
WHILE 1 = 1
BEGIN
  UPDATE TOP(5000) dbo.LargeOrders
    SET CustomerID = N'ABCDE'
  WHERE CustomerID = N'OLDWO';

  IF @@rowcount < 5000 BREAK;
END
GO

-- Cleanup
IF OBJECT_ID('dbo.LargeOrders') IS NOT NULL
  DROP TABLE dbo.LargeOrders;
GO

---------------------------------------------------------------------
-- APPLY
---------------------------------------------------------------------
-- Creation Script for the Function fn_top_products
IF OBJECT_ID('dbo.fn_top_products') IS NOT NULL
  DROP FUNCTION dbo.fn_top_products;
GO
CREATE FUNCTION dbo.fn_top_products
  (@supid AS INT, @catid INT, @n AS INT)
  RETURNS TABLE
AS
RETURN
  SELECT TOP(@n) WITH TIES ProductID, ProductName, UnitPrice
  FROM dbo.Products
  WHERE SupplierID = @supid
    AND CategoryID = @catid
  ORDER BY UnitPrice DESC;
GO

-- Return, for each supplier, the two most expensive beverages
SELECT S.SupplierID, CompanyName, ProductID, ProductName, UnitPrice
FROM dbo.Suppliers AS S
  CROSS APPLY dbo.fn_top_products(S.SupplierID, 1, 2) AS P;

-- Include also suppliers that don't supply beverages
SELECT S.SupplierID, CompanyName, ProductID, ProductName, UnitPrice
FROM dbo.Suppliers AS S
  OUTER APPLY dbo.fn_top_products(S.SupplierID, 1, 2) AS P;

-- Return, for each supplier, the lower of the two most expensive
-- beverage prices
SELECT S.SupplierID, CompanyName,
  (SELECT MIN(UnitPrice)
   FROM dbo.fn_top_products(S.SupplierID, 1, 2) AS P) AS Price
FROM dbo.Suppliers AS S;
GO

---------------------------------------------------------------------
-- Solutions to Common Problems using TOP and APPLY
---------------------------------------------------------------------

---------------------------------------------------------------------
-- TOP n for Each Group
---------------------------------------------------------------------

-- Indexes for Following Problems
USE Northwind;

CREATE UNIQUE INDEX idx_eid_od_oid_i_cid_rd 
  ON dbo.Orders(EmployeeID, OrderDate, OrderID)
     INCLUDE(CustomerID, RequiredDate);

CREATE UNIQUE INDEX idx_oid_qtyd_pid
  ON dbo.[Order Details](OrderID, Quantity DESC, ProductID);
GO

-- Listing 7-1: Solution 1 to the Most Recent Order for each Employee Problem
SELECT OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate 
FROM dbo.Orders AS O1
WHERE OrderID =
  (SELECT TOP(1) OrderID
   FROM dbo.Orders AS O2
   WHERE O2.EmployeeID = O1.EmployeeID
   ORDER BY OrderDate DESC, OrderID DESC);

-- Listing 7-2: Solution 1 to the n Most Recent Orders for each Employee Problem
SELECT OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate 
FROM dbo.Orders AS O1
WHERE OrderID IN
  (SELECT TOP(3) OrderID
   FROM dbo.Orders AS O2
   WHERE O2.EmployeeID = O1.EmployeeID
   ORDER BY OrderDate DESC, OrderID DESC);

-- Listing 7-3: Solution 2 to the Most Recent Order for each Employee Problem
SELECT O.OrderID, CustomerID, O.EmployeeID, OrderDate, RequiredDate 
FROM (SELECT EmployeeID,
        (SELECT TOP(1) OrderID
         FROM dbo.Orders AS O2
         WHERE O2.EmployeeID = E.EmployeeID
         ORDER BY OrderDate DESC, OrderID DESC) AS TopOrder
      FROM dbo.Employees AS E) AS EO
  JOIN dbo.Orders AS O
    ON O.OrderID = EO.TopOrder;

-- Listing 7-4: Solution 2 to the n Most Recent Orders for each Employee Problem
SELECT OrderID, CustomerID, E.EmployeeID, OrderDate, RequiredDate 
FROM dbo.Employees AS E
   JOIN dbo.Orders AS O1
     ON OrderID IN
       (SELECT TOP(3) OrderID
        FROM dbo.Orders AS O2
        WHERE O2.EmployeeID = E.EmployeeID
        ORDER BY OrderDate DESC, OrderID DESC);

-- Listing 7-5: Solution 3 to the n Most Recent Orders for each Employee Problem
SELECT OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate 
FROM dbo.Employees AS E
  CROSS APPLY
    (SELECT TOP(3) OrderID, CustomerID, OrderDate, RequiredDate 
     FROM dbo.Orders AS O
     WHERE O.EmployeeID = E.EmployeeID
     ORDER BY OrderDate DESC, OrderID DESC) AS A;
GO

-- Creade optimal index for next solution
CREATE UNIQUE INDEX idx_eid_odD_oidD_i_cid_rd 
  ON dbo.Orders(EmployeeID, OrderDate DESC, OrderID DESC)
     INCLUDE(CustomerID, RequiredDate);
GO

-- Listing 7-6: Solution 4 to the n Most Recent Orders for each Employee Problem
SELECT OrderID, CustomerID, OrderDate, RequiredDate
FROM (SELECT OrderID, CustomerID, OrderDate, RequiredDate,
        ROW_NUMBER() OVER(PARTITION BY EmployeeID
                          ORDER BY OrderDate DESC, OrderID DESC) AS RowNum
      FROM dbo.Orders) AS D
WHERE RowNum <= 3;

-- Solutions for TOP n Order Details for each Order
SELECT D.OrderID, ProductID, Quantity
FROM dbo.Orders AS O
  CROSS APPLY
    (SELECT TOP(3) OD.OrderID, ProductID, Quantity
     FROM [Order Details] AS OD
     WHERE OD.OrderID = O.OrderID
     ORDER BY Quantity DESC, ProductID) AS D;

SELECT OrderID, ProductID, Quantity
FROM (SELECT ROW_NUMBER() OVER(PARTITION BY OrderID 
                               ORDER BY Quantity DESC, ProductID) AS RowNum,
        OrderID, ProductID, Quantity
      FROM dbo.[Order Details]) AS D
WHERE RowNum <= 3;
GO

---------------------------------------------------------------------
-- Matching Current and Previous Occurrences
---------------------------------------------------------------------

-- Listing 7-7: Query Solution 1 Matching Current and Previous Occurrences
SELECT Cur.EmployeeID,
  Cur.OrderID AS CurOrderID, Prv.OrderID AS PrvOrderID,
  Cur.OrderDate AS CurOrderDate, Prv.OrderDate AS PrvOrderDate,
  Cur.RequiredDate AS CurReqDate, Prv.RequiredDate AS PrvReqDate
FROM dbo.Orders AS Cur
  LEFT OUTER JOIN dbo.Orders AS Prv
    ON Prv.OrderID =
       (SELECT TOP(1) OrderID
        FROM dbo.Orders AS O
        WHERE O.EmployeeID = Cur.EmployeeID
          AND (O.OrderDate < Cur.OrderDate
               OR (O.OrderDate = Cur.OrderDate
                   AND O.OrderID < Cur.OrderID))
        ORDER BY OrderDate DESC, OrderID DESC)
ORDER BY Cur.EmployeeID, Cur.OrderDate, Cur.OrderID;

-- Listing 7-8: Query Solution 2 Matching Current and Previous Occurrences
SELECT Cur.EmployeeID,
  Cur.OrderID AS CurOrderID, Prv.OrderID AS PrvOrderID,
  Cur.OrderDate AS CurOrderDate, Prv.OrderDate AS PrvOrderDate,
  Cur.RequiredDate AS CurReqDate, Prv.RequiredDate AS PrvReqDate
FROM (SELECT EmployeeID, OrderID, OrderDate, RequiredDate,
        (SELECT TOP(1) OrderID
         FROM dbo.Orders AS O2
         WHERE O2.EmployeeID = O1.EmployeeID
           AND (O2.OrderDate < O1.OrderDate
                OR O2.OrderDate = O1.OrderDate
                   AND O2.OrderID < O1.OrderID)
         ORDER BY OrderDate DESC, OrderID DESC) AS PrvOrderID
      FROM dbo.Orders AS O1) AS Cur
  LEFT OUTER JOIN dbo.Orders AS Prv
    ON Cur.PrvOrderID = Prv.OrderID
ORDER BY Cur.EmployeeID, Cur.OrderDate, Cur.OrderID;

-- Listing 7-9: Query Solution 3 Matching Current and Previous Occurrences
SELECT Cur.EmployeeID,
  Cur.OrderID AS CurOrderID, Prv.OrderID AS PrvOrderID,
  Cur.OrderDate AS CurOrderDate, Prv.OrderDate AS PrvOrderDate,
  Cur.RequiredDate AS CurReqDate, Prv.RequiredDate AS PrvReqDate
FROM dbo.Orders AS Cur
  OUTER APPLY
    (SELECT TOP(1) OrderID, OrderDate, RequiredDate
     FROM dbo.Orders AS O
     WHERE O.EmployeeID = Cur.EmployeeID
       AND (O.OrderDate < Cur.OrderDate
            OR (O.OrderDate = Cur.OrderDate
               AND O.OrderID < Cur.OrderID))
     ORDER BY OrderDate DESC, OrderID DESC) AS Prv
ORDER BY Cur.EmployeeID, Cur.OrderDate, Cur.OrderID;

-- Listing 7-10: Query Solution 4 Matching Current and Previous Occurrences
WITH OrdersRN AS
(
  SELECT EmployeeID, OrderID, OrderDate, RequiredDate,
    ROW_NUMBER() OVER(PARTITION BY EmployeeID
                      ORDER BY OrderDate, OrderID) AS rn
  FROM dbo.Orders
)
SELECT Cur.EmployeeID,
  Cur.OrderID AS CurOrderID, Prv.OrderID AS PrvOrderID,
  Cur.OrderDate AS CurOrderDate, Prv.OrderDate AS PrvOrderDate,
  Cur.RequiredDate AS CurReqDate, Prv.RequiredDate AS PrvReqDate
FROM OrdersRN AS Cur
  LEFT OUTER JOIN OrdersRN AS Prv
    ON Cur.EmployeeID = Prv.EmployeeID
    AND Cur.rn = Prv.rn + 1
ORDER BY Cur.EmployeeID, Cur.OrderDate, Cur.OrderID;
GO

-- Cleanup
DROP INDEX dbo.Orders.idx_eid_od_oid_i_cid_rd;
DROP INDEX dbo.Orders.idx_eid_odD_oidD_i_cid_rd;
DROP INDEX dbo.[Order Details].idx_oid_qtyd_pid;
GO

---------------------------------------------------------------------
-- Paging
---------------------------------------------------------------------

-- Index for Paging Problem
CREATE INDEX idx_od_oid_i_cid_eid
  ON dbo.Orders(OrderDate, OrderID) INCLUDE(CustomerID, EmployeeID);
GO

-- Cleanup before Creation of Procedures
IF OBJECT_ID('dbo.usp_firstpage') IS NOT NULL
  DROP PROC dbo.usp_firstpage;
GO
IF OBJECT_ID('dbo.usp_nextpage') IS NOT NULL
  DROP PROC dbo.usp_nextpage;
GO
IF OBJECT_ID('dbo.usp_prevpage') IS NOT NULL
  DROP PROC dbo.usp_prevpage;
GO

-- First Page
CREATE PROC dbo.usp_firstpage
  @n AS INT = 10
AS
SELECT TOP(@n) OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.Orders
ORDER BY OrderDate, OrderID;
GO

-- Test Proc
EXEC dbo.usp_firstpage;
GO

-- Next Page
CREATE PROC dbo.usp_nextpage
  @anchor AS INT, -- key of last row in prev page
  @n AS INT = 10
AS
SELECT TOP(@n) O.OrderID, O.OrderDate, O.CustomerID, O.EmployeeID
FROM dbo.Orders AS O
  JOIN dbo.Orders AS A
    ON A.OrderID = @anchor
    AND (O.OrderDate > A.OrderDate
         OR (O.OrderDate = A.OrderDate
             AND O.OrderID > A.OrderID))
ORDER BY O.OrderDate, O.OrderID;
GO

-- Test Proc
EXEC dbo.usp_nextpage @anchor = 10257;
EXEC dbo.usp_nextpage @anchor = 10267;
GO

---------------------------------------------------------------------
-- Logcial Transformations
---------------------------------------------------------------------

-- Creating and Populating the MyOrders Table
IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
GO
SELECT * INTO dbo.MyOrders FROM dbo.Orders
CREATE INDEX idx_dt ON dbo.MyOrders(OrderDate);
GO

-- Anchor: OrderDate - '19980506', OrderID - 11075

-- Listing 7-11: Query Using OR Logic
SELECT OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.MyOrders
WHERE OrderDate > '19980506'
   OR (OrderDate = '19980506' AND OrderID > 11075);

-- Listing 7-12: Query Using AND Logic
SELECT OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.MyOrders
WHERE OrderDate >= '19980506'
  AND (OrderDate > '19980506' OR OrderID > 11075);

-- Index on Both Columns
CREATE INDEX idx_dt_oid ON dbo.MyOrders(OrderDate, OrderID);
GO

-- Rerun queries in Listing 7-11 and Listing 7-12

-- Cleanup
IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
GO

-- Optimized Next Page
ALTER PROC dbo.usp_nextpage
  @anchor AS INT, -- key of last row in prev page
  @n AS INT = 10
AS
SELECT TOP(@n) O.OrderID, O.OrderDate, O.CustomerID, O.EmployeeID
FROM dbo.Orders AS O
  JOIN dbo.Orders AS A
    ON A.OrderID = @anchor
    AND (O.OrderDate >= A.OrderDate
         AND (O.OrderDate > A.OrderDate
              OR O.OrderID > A.OrderID))
ORDER BY O.OrderDate, O.OrderID;
GO

-- Test Proc
EXEC dbo.usp_nextpage @anchor = 10257;
GO

-- Previous Page
CREATE PROC dbo.usp_prevpage
  @anchor AS INT, -- key of first row in next page
  @n AS INT = 10
AS
SELECT OrderID, OrderDate, CustomerID, EmployeeID
FROM (SELECT TOP(@n) O.OrderID, O.OrderDate, O.CustomerID, O.EmployeeID
      FROM dbo.Orders AS O
        JOIN dbo.Orders AS A
          ON A.OrderID = @anchor
          AND (O.OrderDate <= A.OrderDate
               AND (O.OrderDate < A.OrderDate
                    OR O.OrderID < A.OrderID))
      ORDER BY O.OrderDate DESC, O.OrderID DESC) AS D
ORDER BY OrderDate, OrderID;
GO

-- Test Proc
EXEC dbo.usp_prevpage @anchor = 10268;
EXEC dbo.usp_prevpage @anchor = 10258;
GO

-- For dynamic paging see dynamic execution chapter
-- For flexible scrollable paging see row numbers solution

-- Cleanup
DROP INDEX dbo.Orders.idx_od_oid_i_cid_eid;
GO

---------------------------------------------------------------------
-- Random Rows
---------------------------------------------------------------------

-- Attempt to get Random Row
SELECT TOP(1) OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.Orders
ORDER BY RAND();

-- Deterministic Random
SELECT RAND(5);
SELECT RAND();

-- Non-Deterministic Random
SELECT CHECKSUM(NEWID());

-- Solutions to Random Row
SELECT TOP(1) OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.Orders
ORDER BY CHECKSUM(NEWID());

SELECT TOP(1) OrderID, OrderDate, CustomerID, EmployeeID
FROM (SELECT TOP(100e0*(CHECKSUM(NEWID()) + 2147483649)/4294967296e0) PERCENT
        OrderID, OrderDate, CustomerID, EmployeeID
      FROM dbo.Orders
      ORDER BY OrderID) AS D
ORDER BY OrderID DESC;

-- N Random Rows for rach Employee
SELECT OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate 
FROM dbo.Employees AS E
  CROSS APPLY
    (SELECT TOP(3) OrderID, CustomerID, OrderDate, RequiredDate 
     FROM dbo.Orders AS O
     WHERE O.EmployeeID = E.EmployeeID
     ORDER BY CHECKSUM(NEWID())) AS A;
GO

---------------------------------------------------------------------
-- Median
---------------------------------------------------------------------
-- Listing 7-13: Creating and Populating the Groups Table
USE tempdb;
GO
IF OBJECT_ID('dbo.Groups') IS NOT NULL
  DROP TABLE dbo.Groups;
GO

CREATE TABLE dbo.Groups
(
  groupid  VARCHAR(10) NOT NULL,
  memberid INT         NOT NULL,
  string   VARCHAR(10) NOT NULL,
  val      INT         NOT NULL,
  PRIMARY KEY (groupid, memberid)
);
    
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('a', 3, 'stra1', 6);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('a', 9, 'stra2', 7);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('b', 2, 'strb1', 3);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('b', 4, 'strb2', 7);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('b', 5, 'strb3', 3);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('b', 9, 'strb4', 11);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('c', 3, 'strc1', 8);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('c', 7, 'strc2', 10);
INSERT INTO dbo.Groups(groupid, memberid, string, val)
  VALUES('c', 9, 'strc3', 12);
GO

-- Median for whole Table
SELECT
  ((SELECT MAX(val)
    FROM (SELECT TOP(50) PERCENT val
          FROM dbo.Groups
          ORDER BY val) AS M1)
   +
   (SELECT MIN(val)
    FROM (SELECT TOP(50) PERCENT val
          FROM dbo.Groups
          ORDER BY val DESC) AS M2))
  /2. AS median;

-- Median for each Group
SELECT groupid,
  ((SELECT MAX(val)
    FROM (SELECT TOP(50) PERCENT val
          FROM dbo.Groups AS H1
          WHERE H1.groupid = G.groupid
          ORDER BY val) AS M1)
   +
   (SELECT MIN(val)
    FROM (SELECT TOP(50) PERCENT val
          FROM dbo.Groups AS H2
          WHERE H2.groupid = G.groupid
          ORDER BY val DESC) AS M2))
  /2. AS median
FROM dbo.Groups AS G
GROUP BY groupid;

-- SQL Server 2000 Solution
SELECT DISTINCT groupid,
  ((SELECT MAX(val)
    FROM (SELECT TOP 50 PERCENT val
          FROM dbo.Groups AS H1
          WHERE H1.groupid = G.groupid
          ORDER BY val) AS M1)
   +
   (SELECT MIN(val)
    FROM (SELECT TOP 50 PERCENT val
          FROM dbo.Groups AS H2
          WHERE H2.groupid = G.groupid
          ORDER BY val DESC) AS M2))
  /2. AS median
FROM dbo.Groups AS G;
