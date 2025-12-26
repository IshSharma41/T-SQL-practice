---------------------------------------------------------------------
-- Inside Microsoft SQL Server 2005: T-SQL Querying (MSPress, 2006)
-- Chapter 08 - Data Modification
-- Copyright Itzik Ben-Gan, 2006
-- All Rights Reserved
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Inserting Data
---------------------------------------------------------------------

---------------------------------------------------------------------
-- SELECT INTO
---------------------------------------------------------------------

-- Create a copy of Shippers
SELECT ShipperID, CompanyName, Phone
INTO #MyShippers
FROM Northwind.dbo.Shippers;
GO

-- Creating an Empty Copy of a Table
SET NOCOUNT ON;
USE tempdb;
GO

IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
GO

SELECT *
INTO dbo.MyOrders
FROM Northwind.dbo.Orders
WHERE 1 = 2;
GO

-- Do not Preserve IDENTITY Property
IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
GO

SELECT OrderID+0 AS OrderID, CustomerID, EmployeeID, OrderDate,
  RequiredDate, ShippedDate, ShipVia, Freight, ShipName, 
  ShipAddress, ShipCity, ShipRegion, ShipPostalCode, ShipCountry
INTO dbo.MyOrders
FROM Northwind.dbo.Orders
WHERE 1 = 2;
GO

---------------------------------------------------------------------
-- INSERT EXEC
---------------------------------------------------------------------

-- Listing 8-1: Creation script for paging stored procedures
USE Northwind;
GO

-- Index for paging problem
IF INDEXPROPERTY(OBJECT_ID('dbo.Orders'),
     'idx_od_oid_i_cid_eid', 'IndexID') IS NOT NULL
  DROP INDEX dbo.Orders.idx_od_oid_i_cid_eid;
GO
CREATE INDEX idx_od_oid_i_cid_eid
  ON dbo.Orders(OrderDate, OrderID, CustomerID, EmployeeID);
GO

-- First Rows
IF OBJECT_ID('dbo.usp_firstrows') IS NOT NULL
  DROP PROC dbo.usp_firstrows;
GO
CREATE PROC dbo.usp_firstrows
  @n AS INT = 10 -- num rows
AS
SELECT TOP(@n) ROW_NUMBER() OVER(ORDER BY OrderDate, OrderID) AS RowNum,
  OrderID, OrderDate, CustomerID, EmployeeID
FROM dbo.Orders
ORDER BY OrderDate, OrderID;
GO

-- Next Rows
IF OBJECT_ID('dbo.usp_nextrows') IS NOT NULL
  DROP PROC dbo.usp_nextrows;
GO
CREATE PROC dbo.usp_nextrows
  @anchor_rownum  AS INT = 0, -- row number of last row in prev page
  @anchor_key     AS INT,     -- key of last row in prev page,
  @n              AS INT = 10 -- num rows
AS
SELECT TOP(@n)
  @anchor_rownum
    + ROW_NUMBER() OVER(ORDER BY O.OrderDate, O.OrderID) AS RowNum,
  O.OrderID, O.OrderDate, O.CustomerID, O.EmployeeID
FROM dbo.Orders AS O
  JOIN dbo.Orders AS A
    ON A.OrderID = @anchor_key
    AND (O.OrderDate >= A.OrderDate
         AND (O.OrderDate > A.OrderDate
              OR O.OrderID > A.OrderID))
ORDER BY O.OrderDate, O.OrderID;
GO

-- Create Table #CachedPages
IF OBJECT_ID('tempdb..#CachedPages') IS NOT NULL
  DROP TABLE #CachedPages;
GO
CREATE TABLE #CachedPages
(
  RowNum     INT NOT NULL PRIMARY KEY,
  OrderID    INT NOT NULL UNIQUE,
  OrderDate  DATETIME,
  CustomerID NCHAR(5),
  EmployeeID INT
);
GO

-- Listing 8-2: Creation script for the stored procedure usp_getpage
IF OBJECT_ID('dbo.usp_getpage') IS NOT NULL
  DROP PROC dbo.usp_getpage;
GO
CREATE PROC dbo.usp_getpage
  @from_rownum AS INT,       -- row number of first row in requested page
  @to_rownum   AS INT,       -- row number of last row in requested page
  @rc          AS INT OUTPUT -- number of rows returned
AS

SET NOCOUNT ON;

DECLARE
  @last_key    AS INT, -- key of last row in #CachedPages
  @last_rownum AS INT, -- row number of last row in #CachedPages
  @numrows     AS INT; -- number of missing rows in #CachedPages

-- Get anchor values from last cached row
SELECT @last_rownum = RowNum, @last_key = OrderID
FROM (SELECT TOP(1) RowNum, OrderID
      FROM #CachedPages ORDER BY RowNum DESC) AS D;

-- If temporary table is empty insert first rows to #CachedPages
IF @last_rownum IS NULL
  INSERT INTO #CachedPages
    EXEC dbo.usp_firstrows
      @n = @to_rownum;
ELSE
BEGIN
  SET @numrows = @to_rownum - @last_rownum;
  IF @numrows > 0
    INSERT INTO #CachedPages
      EXEC dbo.usp_nextrows
        @anchor_rownum = @last_rownum,
        @anchor_key    = @last_key,
        @n             = @numrows;
END

-- Return requested page
SELECT *
FROM #CachedPages
WHERE RowNum BETWEEN @from_rownum AND @to_rownum
ORDER BY RowNum;

SET @rc = @@rowcount;
GO

-- Get rows 1-10
DECLARE @rc AS INT;

EXEC dbo.usp_getpage
  @from_rownum = 1,
  @to_rownum   = 10,
  @rc          = @rc OUTPUT;

IF @rc = 0
  PRINT 'No more pages.'
ELSE IF @rc < 10
  PRINT 'Reached last page.';
GO

-- Examine #CachedPages; you will find 10 rows
SELECT * FROM #CachedPages;
GO

-- Get rows 21-30
DECLARE @rc AS INT;

EXEC dbo.usp_getpage
  @from_rownum = 21,
  @to_rownum   = 30,
  @rc          = @rc OUTPUT;

IF @rc = 0
  PRINT 'No more pages.'
ELSE IF @rc < 10
  PRINT 'Reached last page.';
GO

-- Examine #CachedPages; you will find 30 rows
SELECT * FROM #CachedPages;
GO

-- Cleanup
IF OBJECT_ID('tempdb..#CachedPages') IS NOT NULL
  DROP TABLE #CachedPages;
GO
IF INDEXPROPERTY(OBJECT_ID('dbo.Orders'),
     'idx_od_oid_i_cid_eid', 'IndexID') IS NOT NULL
  DROP INDEX dbo.Orders.idx_od_oid_i_cid_eid;
GO
IF OBJECT_ID('dbo.usp_firstrows') IS NOT NULL
  DROP PROC dbo.usp_firstrows;
GO
IF OBJECT_ID('dbo.usp_nextrows') IS NOT NULL
  DROP PROC dbo.usp_nextrows;
GO
IF OBJECT_ID('dbo.usp_getpage') IS NOT NULL
  DROP PROC dbo.usp_getpage;
GO

---------------------------------------------------------------------
-- Inserting New Rows
---------------------------------------------------------------------
-- Listing 8-3: Create and populate sample tables
USE tempdb;
GO
IF OBJECT_ID('dbo.MyOrders') IS NOT NULL
  DROP TABLE dbo.MyOrders;
GO
IF OBJECT_ID('dbo.MyCustomers') IS NOT NULL
  DROP TABLE dbo.MyCustomers;
GO
IF OBJECT_ID('dbo.StageCusts') IS NOT NULL
  DROP TABLE dbo.StageCusts;
GO
IF OBJECT_ID('dbo.StageOrders') IS NOT NULL
  DROP TABLE dbo.StageOrders;
GO

SELECT *
INTO dbo.MyCustomers
FROM Northwind.dbo.Customers
WHERE CustomerID < N'M';

ALTER TABLE dbo.MyCustomers ADD PRIMARY KEY(CustomerID);

SELECT *
INTO dbo.MyOrders
FROM Northwind.dbo.Orders
WHERE CustomerID < N'M';

ALTER TABLE dbo.MyOrders ADD
  PRIMARY KEY(OrderID),
  FOREIGN KEY(CustomerID) REFERENCES dbo.MyCustomers;

SELECT *
INTO dbo.StageCusts
FROM Northwind.dbo.Customers;

ALTER TABLE dbo.StageCusts ADD PRIMARY KEY(CustomerID);

SELECT C.CustomerID, CompanyName, ContactName, ContactTitle,
  Address, City, Region, PostalCode, Country, Phone, Fax,
  OrderID, EmployeeID, OrderDate, RequiredDate, ShippedDate,
  ShipVia, Freight, ShipName, ShipAddress, ShipCity, ShipRegion,
  ShipPostalCode, ShipCountry
INTO dbo.StageOrders
FROM Northwind.dbo.Customers AS C
  JOIN Northwind.dbo.Orders AS O
    ON O.CustomerID = C.CustomerID;

CREATE UNIQUE CLUSTERED INDEX idx_cid_oid
  ON dbo.StageOrders(CustomerID, OrderID);
ALTER TABLE dbo.StageOrders ADD PRIMARY KEY NONCLUSTERED(OrderID);
GO

-- Insert New Rows From StageCusts
INSERT INTO dbo.MyCustomers(CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
  SELECT CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax
  FROM dbo.StageCusts AS S
  WHERE NOT EXISTS
    (SELECT * FROM dbo.MyCustomers AS T
     WHERE T.CustomerID = S.CustomerID);

-- Insert New Customers From StageOrders using DISTINCT
INSERT INTO dbo.MyCustomers(CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
  SELECT DISTINCT CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax
  FROM dbo.StageOrders AS S
  WHERE NOT EXISTS
    (SELECT * FROM dbo.MyCustomers AS T
     WHERE T.CustomerID = S.CustomerID);

-- Insert New Customers From StageOrders using MIN
INSERT INTO dbo.MyCustomers(CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
  SELECT CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax
  FROM dbo.StageOrders AS S
  WHERE NOT EXISTS
    (SELECT * FROM dbo.MyCustomers AS T
     WHERE T.CustomerID = S.CustomerID)
    AND S.OrderID = (SELECT MIN(OrderID) FROM dbo.StageOrders AS S2
                     WHERE S2.CustomerID = S.CustomerID);

-- Insert New Customers From StageOrders using Row Numbers
INSERT INTO dbo.MyCustomers(CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
  SELECT CustomerID, CompanyName, ContactName,
    ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax
  FROM (SELECT
          ROW_NUMBER() OVER(PARTITION BY CustomerID ORDER BY OrderID) AS rn,
          CustomerID, CompanyName, ContactName, ContactTitle, Address, City,
          Region, PostalCode, Country, Phone, Fax
        FROM dbo.StageOrders) AS S
  WHERE NOT EXISTS
    (SELECT * FROM dbo.MyCustomers AS T
     WHERE T.CustomerID = S.CustomerID)
    AND rn = 1;
GO

---------------------------------------------------------------------
-- INSERT with OUTPUT
---------------------------------------------------------------------

-- Generating Surrogate Keys for Customers
USE tempdb;
GO
IF OBJECT_ID('dbo.CustomersDim') IS NOT NULL
  DROP TABLE dbo.CustomersDim;
GO

CREATE TABLE dbo.CustomersDim
(
  KeyCol      INT          NOT NULL IDENTITY PRIMARY KEY,
  CustomerID  NCHAR(5)     NOT NULL,
  CompanyName NVARCHAR(40) NOT NULL,
  /* ... other columns ... */
);

-- Insert New Customers and Get their Surrogate Keys
DECLARE @NewCusts TABLE
(
  CustomerID NCHAR(5) NOT NULL PRIMARY KEY,
  KeyCol     INT      NOT NULL UNIQUE
);

INSERT INTO dbo.CustomersDim(CustomerID, CompanyName)
    OUTPUT inserted.CustomerID, inserted.KeyCol
    INTO @NewCusts
    -- OUTPUT inserted.CustomerID, inserted.KeyCol
  SELECT CustomerID, CompanyName
  FROM Northwind.dbo.Customers
  WHERE Country = N'UK';

SELECT CustomerID, KeyCol FROM @NewCusts;
GO

---------------------------------------------------------------------
-- Sequence Mechanisms
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Identity Columns
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Custom Sequences
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Synchronous Sequence Generation
---------------------------------------------------------------------

-- Sequence Table
USE tempdb;
GO
IF OBJECT_ID('dbo.SyncSeq') IS NOT NULL
  DROP TABLE dbo.SyncSeq;
GO

CREATE TABLE dbo.SyncSeq(val INT);
INSERT INTO dbo.SyncSeq VALUES(0);
GO

---------------------------------------------------------------------
-- Single Sequence Value
---------------------------------------------------------------------

-- Sequence Proc
IF OBJECT_ID('dbo.usp_SyncSeq') IS NOT NULL
  DROP PROC dbo.usp_SyncSeq;
GO

CREATE PROC dbo.usp_SyncSeq
  @val AS INT OUTPUT
AS
UPDATE dbo.SyncSeq
  SET @val = val = val + 1;
GO

-- Get Next Sequence
DECLARE @key AS INT;
EXEC dbo.usp_SyncSeq @val = @key OUTPUT;
SELECT @key;

-- Reset Sequence
UPDATE dbo.SyncSeq SET val = 0;
GO

---------------------------------------------------------------------
-- Block of Sequence Values
---------------------------------------------------------------------

-- Alter Sequence Proc to Support a Block of Sequence Values
ALTER PROC dbo.usp_SyncSeq
  @val AS INT OUTPUT,
  @n   AS INT = 1
AS
UPDATE dbo.SyncSeq
  SET @val = val + 1, val = val + @n;
GO

-- Assign Sequence Values to Multiple Rows

-- Using Specialized UPDATE
IF OBJECT_ID('tempdb..#CustsStage') IS NOT NULL
  DROP TABLE #CustsStage
GO

DECLARE @key AS INT, @rc AS INT;

SELECT CustomerID, 0 AS KeyCol
INTO #CustsStage
FROM Northwind.dbo.Customers
WHERE Country = N'UK';

SET @rc = @@rowcount;
EXEC dbo.usp_SyncSeq @val = @key OUTPUT, @n = @rc;

SET @key = @key -1;
UPDATE #CustsStage SET @key = KeyCol = @key + 1;

SELECT CustomerID, KeyCol FROM #CustsStage;
GO

-- Specialized Update can be substituted with CTE and ROW_NUMBER
WITH CustsStageRN AS
(
  SELECT KeyCol, ROW_NUMBER() OVER(ORDER BY CustomerID) AS RowNum
  FROM #CustsStage
)
UPDATE CustsStageRN SET KeyCol = RowNum + @key;
GO

-- Using IDENTITY / ROW_NUMBER
IF OBJECT_ID('tempdb..#CustsStage') IS NOT NULL
  DROP TABLE #CustsStage
GO

DECLARE @key AS INT, @rc AS INT;

SELECT CustomerID, IDENTITY(int, 1, 1) AS rn
  -- In 2005 can use ROW_NUMBER() OVER(ORDER BY CustomerID)
INTO #CustsStage
FROM Northwind.dbo.Customers
WHERE Country = N'UK';

SET @rc = @@rowcount;
EXEC dbo.usp_SyncSeq @val = @key OUTPUT, @n = @rc;

SELECT CustomerID, rn + @key - 1 AS KeyCol FROM #CustsStage;
GO

---------------------------------------------------------------------
-- Asynchronous Sequence Generation
---------------------------------------------------------------------

-- Sequence Table
USE tempdb;
GO
IF OBJECT_ID('dbo.AsyncSeq') IS NOT NULL
  DROP TABLE dbo.AsyncSeq;
GO

CREATE TABLE dbo.AsyncSeq(val INT IDENTITY);
GO

-- Sequence Proc
IF OBJECT_ID('dbo.usp_AsyncSeq') IS NOT NULL
  DROP PROC dbo.usp_AsyncSeq;
GO

CREATE PROC dbo.usp_AsyncSeq
  @val AS INT OUTPUT
AS
BEGIN TRAN
  SAVE TRAN S1;
  INSERT INTO dbo.AsyncSeq DEFAULT VALUES;
  SET @val = SCOPE_IDENTITY();
  ROLLBACK TRAN S1;
COMMIT TRAN
GO

-- Get Next Sequence
DECLARE @key AS INT;
EXEC dbo.usp_AsyncSeq @val = @key OUTPUT;
SELECT @key;

-- Reset Sequence
TRUNCATE TABLE dbo.AsyncSeq;

DBCC CHECKIDENT('dbo.AsyncSeq', RESEED, 0);
GO

---------------------------------------------------------------------
-- Global Unique Identifiers
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Deleting Data
---------------------------------------------------------------------

---------------------------------------------------------------------
-- TRUNCATE vs. DELETE
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Removing Rows with Duplicate Data
---------------------------------------------------------------------
-- DDL & Sample Data
USE tempdb;
GO
IF OBJECT_ID('dbo.OrdersDups') IS NOT NULL
  DROP TABLE dbo.OrdersDups
GO

SELECT OrderID+0 AS OrderID, CustomerID, EmployeeID, OrderDate,
  RequiredDate, ShippedDate, ShipVia, Freight, ShipName, ShipAddress,
  ShipCity, ShipRegion, ShipPostalCode, ShipCountry 
INTO dbo.OrdersDups
FROM Northwind.dbo.Orders, dbo.Nums
WHERE n <= 100;
GO

-- Complete rows are duplicates / Many duplicates
-- Unique column not required
-- 5 seconds
SELECT DISTINCT * INTO dbo.OrdersTmp FROM dbo.OrdersDups;
DROP TABLE dbo.OrdersDups;
EXEC sp_rename 'dbo.OrdersTmp', 'OrdersDups';
-- Add constraints, indexes, triggers
GO

-- Duplicates in specific set of columns (e.g., OrderID)
-- Small number of duplicates
-- Unique column required
-- Index on dupcol, uniquecol recommended
-- 14 seconds
ALTER TABLE dbo.OrdersDups
  ADD KeyCol INT NOT NULL IDENTITY;
CREATE UNIQUE INDEX idx_OrderID_KeyCol
  ON dbo.OrdersDups(OrderID, KeyCol);
GO
DELETE FROM dbo.OrdersDups
WHERE EXISTS
  (SELECT *
   FROM dbo.OrdersDups AS O2
   WHERE O2.OrderID = dbo.OrdersDups.OrderID
     AND O2.KeyCol > dbo.OrdersDups.KeyCol);
GO

-- Duplicates in specific set of columns (e.g., OrderID)
-- Large number of duplicates
-- Unique column required
-- Index on dupcol, uniquecol recommended
-- 2 seconds
ALTER TABLE dbo.OrdersDups
  ADD KeyCol INT NOT NULL IDENTITY;
CREATE UNIQUE INDEX idx_OrderID_KeyCol
  ON dbo.OrdersDups(OrderID, KeyCol);
GO

SELECT O.OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate,
  ShippedDate, ShipVia, Freight, ShipName, ShipAddress, ShipCity,
  ShipRegion, ShipPostalCode, ShipCountry
INTO dbo.OrdersTmp
FROM dbo.OrdersDups AS O
  JOIN (SELECT OrderID, MAX(KeyCol) AS mx
        FROM dbo.OrdersDups
        GROUP BY OrderID) AS U
    ON O.OrderID = U.OrderID
    AND O.KeyCol = U.mx;

DROP TABLE dbo.OrdersDups;
EXEC sp_rename 'dbo.OrdersTmp', 'OrdersDups';
-- Recreate constraints, indexes
GO

-- SQL Server 2005
-- Duplicates in either whole row, or specific set of columns
-- For small or large number of duplicates
-- Unique column not required
-- 1 second
WITH Dups AS
(
  SELECT *,
    ROW_NUMBER() OVER(PARTITION BY OrderID ORDER BY OrderID) AS rn
  FROM dbo.OrdersDups
)
DELETE FROM Dups WHERE rn > 1;
GO

---------------------------------------------------------------------
-- DELETE Using Joins
---------------------------------------------------------------------

USE Northwind;
GO

-- Delete order details for orders placed
-- on or after '19980506'

-- T-SQL Specific Syntax
SELECT OD.*
FROM dbo.[Order Details] AS OD
  JOIN dbo.Orders AS O
    ON OD.OrderID = O.OrderID
WHERE O.OrderDate >= '19980506';

BEGIN TRAN

DELETE FROM OD
FROM dbo.[Order Details] AS OD
  JOIN dbo.Orders AS O
    ON OD.OrderID = O.OrderID
WHERE O.OrderDate >= '19980506';

ROLLBACK TRAN

-- ANSI Syntax
BEGIN TRAN

DELETE FROM dbo.[Order Details]
WHERE EXISTS
  (SELECT *
   FROM dbo.Orders AS O
   WHERE O.OrderID = dbo.[Order Details].OrderID
     AND O.OrderDate >= '19980506');

ROLLBACK TRAN
GO

-- Delete from a table variable

-- Invalid
DECLARE @MyOD TABLE
(
  OrderID   INT NOT NULL,
  ProductID INT NOT NULL,
  PRIMARY KEY(OrderID, ProductID)
);

INSERT INTO @MyOD VALUES(10001, 14);
INSERT INTO @MyOD VALUES(10001, 51);
INSERT INTO @MyOD VALUES(10001, 65);
INSERT INTO @MyOD VALUES(10248, 11);
INSERT INTO @MyOD VALUES(10248, 42);

/*
DELETE FROM @MyOD
WHERE EXISTS
  (SELECT * FROM dbo.[Order Details] AS OD
   WHERE OD.OrderID = @MyOD.OrderID
     AND OD.ProductID = @MyOD.ProductID);

Msg 137, Level 15, State 2, Line 17
Must declare the scalar variable "@MyOD".
*/

-- Valid Non-Standard
DELETE FROM MyOD
FROM @MyOD AS MyOD
WHERE EXISTS
  (SELECT * FROM dbo.[Order Details] AS OD
   WHERE OD.OrderID = MyOD.OrderID
     AND OD.ProductID = MyOD.ProductID);

DELETE FROM MyOD
FROM @MyOD AS MyOD
  JOIN dbo.[Order Details] AS OD
    ON OD.OrderID = MyOD.OrderID
   AND OD.ProductID = MyOD.ProductID;

-- Valid Standard
WITH MyOD AS (SELECT * FROM @MyOD)
DELETE FROM MyOD
WHERE EXISTS
  (SELECT * FROM dbo.[Order Details] AS OD
   WHERE OD.OrderID = MyOD.OrderID
     AND OD.ProductID = MyOD.ProductID);
GO

---------------------------------------------------------------------
-- DELETE with OUTPUT
---------------------------------------------------------------------

-- Create BigOrders
SET NOCOUNT ON;
USE tempdb;
GO
IF OBJECT_ID('dbo.LargeOrders') IS NOT NULL
  DROP TABLE dbo.LargeOrders;
GO
SELECT IDENTITY(int, 1, 1) AS OrderID, CustomerID, EmployeeID,
  DATEADD(day, n-1, '20000101') AS OrderDate,
  CAST('a' AS CHAR(200)) AS Filler
INTO dbo.LargeOrders
FROM Northwind.dbo.Customers AS C,
  Northwind.dbo.Employees AS E,
  dbo.Nums
WHERE n <= DATEDIFF(day, '20000101', '20061231') + 1;

CREATE UNIQUE CLUSTERED INDEX idx_od_oid
  ON dbo.LargeOrders(OrderDate, OrderID)

ALTER TABLE dbo.LargeOrders ADD PRIMARY KEY NONCLUSTERED(OrderID);
GO

-- Delete orders placed prior to 2001 (don't run)
WHILE 1 = 1
BEGIN
  DELETE TOP (5000) FROM dbo.LargeOrders WHERE OrderDate < '20020101';
  IF @@rowcount < 5000 BREAK;
END
GO

-- Purging and Archiving
IF OBJECT_ID('dbo.OrdersArchive') IS NOT NULL
  DROP TABLE dbo.OrdersArchive;
GO
CREATE TABLE dbo.OrdersArchive
(
  OrderID    INT       NOT NULL PRIMARY KEY NONCLUSTERED,
  CustomerID NCHAR(5)  NOT NULL,
  EmployeeID INT       NOT NULL,
  OrderDate  DATETIME  NOT NULL,
  Filler     CHAR(200) NOT NULL
);
CREATE UNIQUE CLUSTERED INDEX idx_od_oid
  ON dbo.OrdersArchive(OrderDate, OrderID);
GO

WHILE 1=1
BEGIN
  BEGIN TRAN
    DELETE TOP(5000) FROM dbo.LargeOrders
      OUTPUT deleted.* INTO dbo.OrdersArchive
    WHERE OrderDate < '20010101';

    IF @@rowcount < 5000
    BEGIN
      COMMIT TRAN
      BREAK;
    END
  COMMIT TRAN
END
GO

---------------------------------------------------------------------
-- Updating Data
---------------------------------------------------------------------

---------------------------------------------------------------------
-- UPDATE Using Joins
---------------------------------------------------------------------

-- Standard
USE Northwind;

BEGIN TRAN

  UPDATE dbo.Orders
    SET ShipCountry = (SELECT C.Country FROM dbo.Customers AS C
                       WHERE C.CustomerID = dbo.Orders.CustomerID),
        ShipRegion =  (SELECT C.Region FROM dbo.Customers AS C
                       WHERE C.CustomerID = dbo.Orders.CustomerID),
        ShipCity =    (SELECT C.City FROM dbo.Customers AS C
                       WHERE C.CustomerID = dbo.Orders.CustomerID)
  WHERE CustomerID IN
    (SELECT CustomerID FROM dbo.Customers WHERE Country = 'USA');

ROLLBACK TRAN

-- Non-Standard
BEGIN TRAN

  UPDATE O
    SET ShipCountry = C.Country,
        ShipRegion = C.Region,
        ShipCity = C.City
  FROM dbo.Orders AS O
    JOIN dbo.Customers AS C
      ON O.CustomerID = C.CustomerID
  WHERE C.Country = 'USA';

ROLLBACK TRAN

-- Non-Standard with a Join and a CTE
BEGIN TRAN;

WITH UPD_CTE AS
(
  SELECT
    O.ShipCountry AS set_Country, C.Country AS get_Country,
    O.ShipRegion  AS set_Region,  C.Region  AS get_Region,
    O.ShipCity    AS set_City,    C.City    AS get_City
  FROM dbo.Orders AS O
    JOIN dbo.Customers AS C
      ON O.CustomerID = C.CustomerID
  WHERE C.Country = 'USA'
)
UPDATE UPD_CTE
  SET set_Country = get_Country,
      set_Region  = get_Country,
      set_City    = get_City;

ROLLBACK TRAN
GO

-- Non-Deterministic Update
USE tempdb;
GO
IF OBJECT_ID('dbo.Orders') IS NOT NULL
  DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Customers') IS NOT NULL
  DROP TABLE dbo.Customers;
GO

CREATE TABLE dbo.Customers
(
  custid VARCHAR(5) NOT NULL PRIMARY KEY,
  qty    INT        NULL
);

INSERT INTO dbo.Customers(custid) VALUES('A');
INSERT INTO dbo.Customers(custid) VALUES('B');

CREATE TABLE dbo.Orders
(
  orderid INT        NOT NULL PRIMARY KEY,
  custid  VARCHAR(5) NOT NULL REFERENCES dbo.Customers,
  qty     INT        NOT NULL
);

INSERT INTO dbo.Orders(orderid, custid, qty) VALUES(1, 'A', 20);
INSERT INTO dbo.Orders(orderid, custid, qty) VALUES(2, 'A', 10);
INSERT INTO dbo.Orders(orderid, custid, qty) VALUES(3, 'A', 30);
INSERT INTO dbo.Orders(orderid, custid, qty) VALUES(4, 'B', 35);
INSERT INTO dbo.Orders(orderid, custid, qty) VALUES(5, 'B', 45);
INSERT INTO dbo.Orders(orderid, custid, qty) VALUES(6, 'B', 15);

UPDATE Customers
  SET qty = O.qty
FROM dbo.Customers AS C
  JOIN dbo.Orders AS O
    ON C.custid = O.custid;

SELECT custid, qty FROM dbo.Customers;
GO

-- Cleanup
IF OBJECT_ID('dbo.Orders') IS NOT NULL
  DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Customers') IS NOT NULL
  DROP TABLE dbo.Customers;
GO

---------------------------------------------------------------------
-- UPDATE with OUTPUT
---------------------------------------------------------------------

-- Message Processing
USE tempdb;
GO
IF OBJECT_ID('dbo.Messages') IS NOT NULL
  DROP TABLE dbo.Messages;
GO

CREATE TABLE dbo.Messages
(
  msgid   INT          NOT NULL IDENTITY ,
  msgdate DATETIME     NOT NULL DEFAULT(GETDATE()),
  msg     VARCHAR(MAX) NOT NULL,
  status  VARCHAR(20)  NOT NULL DEFAULT('new'),
  CONSTRAINT PK_Messages 
    PRIMARY KEY NONCLUSTERED(msgid),
  CONSTRAINT UNQ_Messages_status_msgid 
    UNIQUE CLUSTERED(status, msgid),
  CONSTRAINT CHK_Messages_status
    CHECK (status IN('new', 'open', 'done'))
);
GO

-- Generate messages; run from multiple sessions
SET NOCOUNT ON;
USE tempdb;
GO
DECLARE @msg AS VARCHAR(MAX);
WHILE 1=1
BEGIN
  SET @msg = 'msg' + RIGHT('000000000'
    + CAST(CAST(RAND()*2000000000 AS INT)+1 AS VARCHAR(10)), 10);
  INSERT INTO dbo.Messages(msg) VALUES(@msg);
  WAITFOR DELAY '00:00:01';
END
GO

-- Process messages; run from multiple sessions
SET NOCOUNT ON;
USE tempdb;
GO

DECLARE @Msgs TABLE(msgid INT, msgdate DATETIME, msg VARCHAR(MAX));
DECLARE @n AS INT;
SET @n = 3;

WHILE 1 = 1
BEGIN
  UPDATE TOP(@n) dbo.Messages WITH(READPAST) SET status = 'open'
    OUTPUT inserted.msgid, inserted.msgdate, inserted.msg INTO @Msgs
    OUTPUT inserted.msgid, inserted.msgdate, inserted.msg
  WHERE status = 'new';

  IF @@rowcount > 0
  BEGIN
    PRINT 'Processing messages...';
    /* ...process messages here... */
    
    WITH UPD_CTE AS
    (
      SELECT M.status
      FROM dbo.Messages AS M
        JOIN @Msgs AS N
          ON M.msgid = N.msgid
    )
    UPDATE UPD_CTE
      SET status = 'done';

    DELETE FROM @Msgs;
  END
  ELSE
  BEGIN
    PRINT 'No messages to process.';
    WAITFOR DELAY '00:00:01';
  END
END
GO

---------------------------------------------------------------------
-- Assignment SELECT and UPDATE
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Asignment SELECT
---------------------------------------------------------------------
USE Northwind;
GO

DECLARE @EmpID AS INT, @Pattern AS NVARCHAR(100);

SET @Pattern = N'Davolio'; -- Try also N'Ben-Gan', N'D%';
SET @EmpID = 999;

SELECT @EmpID = EmployeeID
FROM dbo.Employees
WHERE LastName LIKE @Pattern;

SELECT @EmpID;

-- Safe Assignment
DECLARE @EmpID AS INT, @Pattern AS NVARCHAR(100);

SET @Pattern = N'Davolio'; -- Try also N'Ben-Gan', N'D%';
SET @EmpID = 999;

SET @EmpID = (SELECT EmployeeID
              FROM dbo.Employees
              WHERE LastName LIKE @Pattern);

SELECT @EmpID;
GO

-- Assignment SELECT with Multiple Assignments
DECLARE @FirstName AS NVARCHAR(10), @LastName AS NVARCHAR(20);

SELECT @FirstName = NULL, @LastName = NULL;

SELECT @FirstName = FirstName, @LastName = LastName
FROM dbo.Employees
WHERE EmployeeID = 3;

SELECT @FirstName, @LastName;
GO

-- Multi-Row Assignment
DECLARE @Orders AS VARCHAR(8000), @CustomerID AS NCHAR(5);
SET @CustomerID = N'ALFKI';
SET @Orders = '';

SELECT @Orders = @Orders + CAST(OrderID AS VARCHAR(10)) + ';'
FROM dbo.Orders
WHERE CustomerID = @CustomerID;

SELECT @Orders;

-- Multi-Row Assignment with ORDER BY
DECLARE @Orders AS VARCHAR(8000), @CustomerID AS NCHAR(5);
SET @CustomerID = N'ALFKI';
SET @Orders = '';

SELECT @Orders = @Orders + CAST(OrderID AS VARCHAR(10)) + ';'
FROM dbo.Orders
WHERE CustomerID = @CustomerID
ORDER BY OrderDate, OrderID;

SELECT @Orders;
GO

---------------------------------------------------------------------
-- Assignment UPDATE
---------------------------------------------------------------------
USE tempdb;
GO
IF OBJECT_ID('dbo.T1') IS NOT NULL
  DROP TABLE dbo.T1;
GO

CREATE TABLE dbo.T1
(
  col1 INT        NOT NULL,
  col2 VARCHAR(5) NOT NULL
);

INSERT INTO dbo.T1(col1, col2) VALUES(0, 'A');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'B');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'C');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'C');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'C');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'B');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'A');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'A');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'C');
INSERT INTO dbo.T1(col1, col2) VALUES(0, 'C');
go

DECLARE @i AS INT;
SET @i = 0;
UPDATE dbo.T1 SET @i = col1 = @i + 1;
GO

-- SQL Server 2005
WITH T1RN AS
(
  SELECT col1, ROW_NUMBER() OVER(ORDER BY col2) AS RowNum
  FROM dbo.T1
)
UPDATE T1RN SET col1 = RowNum;
GO