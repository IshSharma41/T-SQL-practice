---------------------------------------------------------------------
-- Inside Microsoft SQL Server 2005: T-SQL Querying (MSPress, 2006)
-- Chapter 03 - Query Tuning
-- Copyright Itzik Ben-Gan, 2006
-- All Rights Reserved
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Sample Data for this Chapter
---------------------------------------------------------------------

-- Listing 3-1: Creation Script for Sample Database and Tables
SET NOCOUNT ON;
USE master;
GO
IF DB_ID('Performance') IS NULL
  CREATE DATABASE Performance;
GO
USE Performance;
GO

-- Creating and Populating the Nums Auxiliary Table
IF OBJECT_ID('dbo.Nums') IS NOT NULL
  DROP TABLE dbo.Nums;
GO
CREATE TABLE dbo.Nums(n INT NOT NULL PRIMARY KEY);
DECLARE @max AS INT, @rc AS INT;
SET @max = 1000000;
SET @rc = 1;

INSERT INTO Nums VALUES(1);
WHILE @rc * 2 <= @max
BEGIN
  INSERT INTO dbo.Nums SELECT n + @rc FROM dbo.Nums;
  SET @rc = @rc * 2;
END

INSERT INTO dbo.Nums 
  SELECT n + @rc FROM dbo.Nums WHERE n + @rc <= @max;
GO

-- Drop Data Tables if Exist
IF OBJECT_ID('dbo.VEmpOrders') IS NOT NULL
  DROP VIEW dbo.VEmpOrders;
GO
IF OBJECT_ID('dbo.Orders') IS NOT NULL
  DROP TABLE dbo.Orders;
GO
IF OBJECT_ID('dbo.Customers') IS NOT NULL
  DROP TABLE dbo.Customers;
GO
IF OBJECT_ID('dbo.Employees') IS NOT NULL
  DROP TABLE dbo.Employees;
GO
IF OBJECT_ID('dbo.Shippers') IS NOT NULL
  DROP TABLE dbo.Shippers;
GO

-- Data Distribution Settings
DECLARE
  @numorders   AS INT,
  @numcusts    AS INT,
  @numemps     AS INT,
  @numshippers AS INT,
  @numyears    AS INT,
  @startdate   AS DATETIME;

SELECT
  @numorders   =   1000000,
  @numcusts    =     20000,
  @numemps     =       500,
  @numshippers =         5,
  @numyears    =         4,
  @startdate   = '20030101';

-- Creating and Populating the Customers Table
CREATE TABLE dbo.Customers
(
  custid   CHAR(11)     NOT NULL,
  custname NVARCHAR(50) NOT NULL
);

INSERT INTO dbo.Customers(custid, custname)
  SELECT
    'C' + RIGHT('000000000' + CAST(n AS VARCHAR(10)), 10) AS custid,
    N'Cust_' + CAST(n AS VARCHAR(10)) AS custname
  FROM dbo.Nums
  WHERE n <= @numcusts;

ALTER TABLE dbo.Customers ADD
  CONSTRAINT PK_Customers PRIMARY KEY(custid);

-- Creating and Populating the Employees Table
CREATE TABLE dbo.Employees
(
  empid     INT          NOT NULL,
  firstname NVARCHAR(25) NOT NULL,
  lastname  NVARCHAR(25) NOT NULL
);

INSERT INTO dbo.Employees(empid, firstname, lastname)
  SELECT n AS empid,
    N'Fname_' + CAST(n AS NVARCHAR(10)) AS firstname,
    N'Lname_' + CAST(n AS NVARCHAR(10)) AS lastname
  FROM dbo.Nums
  WHERE n <= @numemps;

ALTER TABLE dbo.Employees ADD
  CONSTRAINT PK_Employees PRIMARY KEY(empid);

-- Creating and Populating the Shippers Table
CREATE TABLE dbo.Shippers
(
  shipperid   VARCHAR(5)   NOT NULL,
  shippername NVARCHAR(50) NOT NULL
);

INSERT INTO dbo.Shippers(shipperid, shippername)
  SELECT shipperid, N'Shipper_' + shipperid AS shippername
  FROM (SELECT CHAR(ASCII('A') - 2 + 2 * n) AS shipperid
        FROM dbo.Nums
        WHERE n <= @numshippers) AS D;

ALTER TABLE dbo.Shippers ADD
  CONSTRAINT PK_Shippers PRIMARY KEY(shipperid);

-- Creating and Populating the Orders Table
CREATE TABLE dbo.Orders
(
  orderid   INT        NOT NULL,
  custid    CHAR(11)   NOT NULL,
  empid     INT        NOT NULL,
  shipperid VARCHAR(5) NOT NULL,
  orderdate DATETIME   NOT NULL,
  filler    CHAR(155)  NOT NULL DEFAULT('a')
);

INSERT INTO dbo.Orders(orderid, custid, empid, shipperid, orderdate)
  SELECT n AS orderid,
    'C' + RIGHT('000000000'
            + CAST(
                1 + ABS(CHECKSUM(NEWID())) % @numcusts
                AS VARCHAR(10)), 10) AS custid,
    1 + ABS(CHECKSUM(NEWID())) % @numemps AS empid,
    CHAR(ASCII('A') - 2
           + 2 * (1 + ABS(CHECKSUM(NEWID())) % @numshippers)) AS shipperid,
      DATEADD(day, n / (@numorders / (@numyears * 365.25)), @startdate)
        -- late arrival with earlier date
        - CASE WHEN n % 10 = 0
            THEN 1 + ABS(CHECKSUM(NEWID())) % 30
            ELSE 0 
          END AS orderdate
  FROM dbo.Nums
  WHERE n <= @numorders
  ORDER BY CHECKSUM(NEWID());

CREATE CLUSTERED INDEX idx_cl_od ON dbo.Orders(orderdate);

CREATE NONCLUSTERED INDEX idx_nc_sid_od_cid
  ON dbo.Orders(shipperid, orderdate, custid);

CREATE UNIQUE INDEX idx_unc_od_oid_i_cid_eid
  ON dbo.Orders(orderdate, orderid)
  INCLUDE(custid, empid);

ALTER TABLE dbo.Orders ADD
  CONSTRAINT PK_Orders PRIMARY KEY NONCLUSTERED(orderid),
  CONSTRAINT FK_Orders_Customers
    FOREIGN KEY(custid)    REFERENCES dbo.Customers(custid),
  CONSTRAINT FK_Orders_Employees
    FOREIGN KEY(empid)     REFERENCES dbo.Employees(empid),
  CONSTRAINT FK_Orders_Shippers
    FOREIGN KEY(shipperid) REFERENCES dbo.Shippers(shipperid);
GO

---------------------------------------------------------------------
-- Tuning Methodology
---------------------------------------------------------------------

-- Drop clustered index
USE Performance;
GO
DROP INDEX dbo.Orders.idx_cl_od;
GO

-- Listing 3-2: Sample Queries
SET NOCOUNT ON;
USE Performance;
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 3;
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 5;
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 7;
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = '20060212';
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = '20060118';
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate = '20060828';
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20060101'
  AND orderdate < '20060201';
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20060401'
  AND orderdate < '20060501';
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20060201'
  AND orderdate < '20070301';
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20060501'
  AND orderdate < '20060601';
GO

---------------------------------------------------------------------
-- Analyze Waits at the Instance Level
---------------------------------------------------------------------

-- SQL Server 2005
SELECT
  wait_type,
  waiting_tasks_count,
  wait_time_ms,
  max_wait_time_ms,
  signal_wait_time_ms
FROM sys.dm_os_wait_stats
ORDER BY wait_type;

-- SQL Server 2000
DBCC SQLPERF(WAITSTATS);

-- Isolate top waits
WITH Waits AS
(
  SELECT
    wait_type,
    wait_time_ms / 1000. AS wait_time_s,
    100. * wait_time_ms / SUM(wait_time_ms) OVER() AS pct,
    ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn
  FROM sys.dm_os_wait_stats
  WHERE wait_type NOT LIKE '%SLEEP%'
  -- filter out additional irrelevant waits
)
SELECT
  W1.wait_type, 
  CAST(W1.wait_time_s AS DECIMAL(12, 2)) AS wait_time_s,
  CAST(W1.pct AS DECIMAL(12, 2)) AS pct,
  CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct
FROM Waits AS W1
  JOIN Waits AS W2
    ON W2.rn <= W1.rn
GROUP BY W1.rn, W1.wait_type, W1.wait_time_s, W1.pct
HAVING SUM(W2.pct) - W1.pct < 90 -- percentage threshold
ORDER BY W1.rn;
GO

-- Create the WaitStats table
USE Performance;
GO
IF OBJECT_ID('dbo.WaitStats') IS NOT NULL
  DROP TABLE dbo.WaitStats;
GO

SELECT GETDATE() AS dt,
  wait_type, waiting_tasks_count, wait_time_ms,
  max_wait_time_ms, signal_wait_time_ms
INTO dbo.WaitStats
FROM sys.dm_os_wait_stats
WHERE 1 = 2;

ALTER TABLE dbo.WaitStats
  ADD CONSTRAINT PK_WaitStats PRIMARY KEY(dt, wait_type);
CREATE INDEX idx_type_dt ON dbo.WaitStats(wait_type, dt);
GO

-- Load waitstats data on regular intervals
INSERT INTO Performance.dbo.WaitStats
  SELECT GETDATE(),
    wait_type, waiting_tasks_count, wait_time_ms,
    max_wait_time_ms, signal_wait_time_ms
FROM sys.dm_os_wait_stats;
GO

-- Creation script for fn_interval_waits function
IF OBJECT_ID('dbo.fn_interval_waits') IS NOT NULL
  DROP FUNCTION dbo.fn_interval_waits;
GO

CREATE FUNCTION dbo.fn_interval_waits
  (@fromdt AS DATETIME, @todt AS DATETIME)
RETURNS TABLE
AS

RETURN
  WITH Waits AS
  (
    SELECT dt, wait_type, wait_time_ms,
      ROW_NUMBER() OVER(PARTITION BY wait_type
                        ORDER BY dt) AS rn
    FROM dbo.WaitStats
    WHERE dt >= @fromdt
      AND dt < @todt + 1
  )
  SELECT Prv.wait_type, Prv.dt AS start_time,
    CAST((Cur.wait_time_ms - Prv.wait_time_ms)
           / 1000. AS DECIMAL(12, 2)) AS interval_wait_s
  FROM Waits AS Cur
    JOIN Waits AS Prv
      ON Cur.wait_type = Prv.wait_type
      AND Cur.rn = Prv.rn + 1
      AND Prv.dt <= @todt;
GO

-- Return interval waits
SELECT wait_type, start_time, interval_wait_s
FROM dbo.fn_interval_waits('20060212', '20060215') AS F
ORDER BY SUM(interval_wait_s) OVER(PARTITION BY wait_type) DESC,
  wait_type, start_time;
GO

-- Prepare view for pivot table
IF OBJECT_ID('dbo.VIntervalWaits') IS NOT NULL
  DROP VIEW dbo.VIntervalWaits;
GO

CREATE VIEW dbo.VIntervalWaits
AS

SELECT wait_type, start_time, interval_wait_s
FROM dbo.fn_interval_waits('20060212', '20060215') AS F;
GO

---------------------------------------------------------------------
-- Correlate Waits with Queues
---------------------------------------------------------------------

-- SQL Server 2005
SELECT
  object_name,
  counter_name,
  instance_name,
  cntr_value,
  cntr_type
FROM sys.dm_os_performance_counters;

-- SQL Server 2000
SELECT
  object_name,
  counter_name,
  instance_name,
  cntr_value,
  cntr_type
FROM master.dbo.sysperfinfo;
GO

---------------------------------------------------------------------
-- Determine Course of Action
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Drill Down to the Database/File Level
---------------------------------------------------------------------

-- SQL Server 2005

-- Analyze DB IO
WITH DBIO AS
(
  SELECT
    DB_NAME(IVFS.database_id) AS db,
    CASE WHEN MF.type = 1 THEN 'log' ELSE 'data' END AS file_type,
    SUM(IVFS.num_of_bytes_read + IVFS.num_of_bytes_written) AS io,
    SUM(IVFS.io_stall) AS io_stall
  FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS IVFS
    JOIN sys.master_files AS MF
      ON IVFS.database_id = MF.database_id
      AND IVFS.file_id = MF.file_id
  GROUP BY DB_NAME(IVFS.database_id), MF.type
)
SELECT db, file_type, 
  CAST(1. * io / (1024 * 1024) AS DECIMAL(12, 2)) AS io_mb,
  CAST(io_stall / 1000. AS DECIMAL(12, 2)) AS io_stall_s,
  CAST(100. * io_stall / SUM(io_stall) OVER()
       AS DECIMAL(10, 2)) AS io_stall_pct,
  ROW_NUMBER() OVER(ORDER BY io_stall DESC) AS rn
FROM DBIO
ORDER BY io_stall DESC;

-- SQL Server 2000
SELECT * FROM ::fn_virtualfilestats(15, 1);
GO

---------------------------------------------------------------------
-- Drill Down to the Process Level
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Trace Performance Workload
---------------------------------------------------------------------

-- Listing 3-3: Creation Script for the sp_perfworkload_trace_start Stored Procedure
SET NOCOUNT ON;
USE master;
GO

IF OBJECT_ID('dbo.sp_perfworkload_trace_start') IS NOT NULL
  DROP PROC dbo.sp_perfworkload_trace_start;
GO

CREATE PROC dbo.sp_perfworkload_trace_start
  @dbid      AS INT,
  @tracefile AS NVARCHAR(254),
  @traceid   AS INT OUTPUT
AS

-- Create a Queue
DECLARE @rc          AS INT;
DECLARE @maxfilesize AS BIGINT;

SET @maxfilesize = 5;

EXEC @rc = sp_trace_create @traceid OUTPUT, 0, @tracefile, @maxfilesize, NULL 
IF (@rc != 0) GOTO error;

-- Client side File and Table cannot be scripted

-- Set the events
DECLARE @on AS BIT;
SET @on = 1;
EXEC sp_trace_setevent @traceid, 10, 15, @on;
EXEC sp_trace_setevent @traceid, 10, 8, @on;
EXEC sp_trace_setevent @traceid, 10, 16, @on;
EXEC sp_trace_setevent @traceid, 10, 48, @on;
EXEC sp_trace_setevent @traceid, 10, 1, @on;
EXEC sp_trace_setevent @traceid, 10, 17, @on;
EXEC sp_trace_setevent @traceid, 10, 10, @on;
EXEC sp_trace_setevent @traceid, 10, 18, @on;
EXEC sp_trace_setevent @traceid, 10, 11, @on;
EXEC sp_trace_setevent @traceid, 10, 12, @on;
EXEC sp_trace_setevent @traceid, 10, 13, @on;
EXEC sp_trace_setevent @traceid, 10, 14, @on;
EXEC sp_trace_setevent @traceid, 45, 8, @on;
EXEC sp_trace_setevent @traceid, 45, 16, @on;
EXEC sp_trace_setevent @traceid, 45, 48, @on;
EXEC sp_trace_setevent @traceid, 45, 1, @on;
EXEC sp_trace_setevent @traceid, 45, 17, @on;
EXEC sp_trace_setevent @traceid, 45, 10, @on;
EXEC sp_trace_setevent @traceid, 45, 18, @on;
EXEC sp_trace_setevent @traceid, 45, 11, @on;
EXEC sp_trace_setevent @traceid, 45, 12, @on;
EXEC sp_trace_setevent @traceid, 45, 13, @on;
EXEC sp_trace_setevent @traceid, 45, 14, @on;
EXEC sp_trace_setevent @traceid, 45, 15, @on;
EXEC sp_trace_setevent @traceid, 41, 15, @on;
EXEC sp_trace_setevent @traceid, 41, 8, @on;
EXEC sp_trace_setevent @traceid, 41, 16, @on;
EXEC sp_trace_setevent @traceid, 41, 48, @on;
EXEC sp_trace_setevent @traceid, 41, 1, @on;
EXEC sp_trace_setevent @traceid, 41, 17, @on;
EXEC sp_trace_setevent @traceid, 41, 10, @on;
EXEC sp_trace_setevent @traceid, 41, 18, @on;
EXEC sp_trace_setevent @traceid, 41, 11, @on;
EXEC sp_trace_setevent @traceid, 41, 12, @on;
EXEC sp_trace_setevent @traceid, 41, 13, @on;
EXEC sp_trace_setevent @traceid, 41, 14, @on;

-- Set the Filters
DECLARE @intfilter AS INT;
DECLARE @bigintfilter AS BIGINT;

-- Application name filter
EXEC sp_trace_setfilter @traceid, 10, 0, 7, N'SQL Server Profiler%';
-- Database ID filter
EXEC sp_trace_setfilter @traceid, 3, 0, 0, @dbid;

-- Set the trace status to start
EXEC sp_trace_setstatus @traceid, 1;

-- Print trace id and file name for future references
PRINT 'Trace ID: ' + CAST(@traceid AS VARCHAR(10))
  + ', Trace File: ''' + @tracefile + '.trc''';

GOTO finish;

error: 
PRINT 'Error Code: ' + CAST(@rc AS VARCHAR(10));

finish: 
GO

-- Start the trace
DECLARE @dbid AS INT, @traceid AS INT;
SET @dbid = DB_ID('Performance');

EXEC dbo.sp_perfworkload_trace_start
  @dbid      = @dbid,
  @tracefile = 'c:\temp\Perfworkload 20060828',
  @traceid   = @traceid OUTPUT;
GO

-- Stop the trace (assuming trace id was 2)
EXEC sp_trace_setstatus 2, 0;
EXEC sp_trace_setstatus 2, 2;
GO

---------------------------------------------------------------------
-- Analyze Trace Data
---------------------------------------------------------------------

-- Load trace data to table
SET NOCOUNT ON;
USE Performance;
GO
IF OBJECT_ID('dbo.Workload') IS NOT NULL
  DROP TABLE dbo.Workload;
GO

SELECT CAST(TextData AS NVARCHAR(MAX)) AS tsql_code,
  Duration AS duration
INTO dbo.Workload
FROM sys.fn_trace_gettable('c:\temp\Perfworkload 20060828.trc', NULL) AS T
WHERE Duration IS NOT NULL;
GO

-- Aggregate trace data by query
SELECT
  tsql_code,
  SUM(duration) AS total_duration
FROM dbo.Workload
GROUP BY tsql_code;

-- Aggregate trace data by query prefix
SELECT
  SUBSTRING(tsql_code, 1, 100) AS tsql_code,
  SUM(duration) AS total_duration
FROM dbo.Workload
GROUP BY SUBSTRING(tsql_code, 1, 100);

-- Adjust substring length
SELECT
  SUBSTRING(tsql_code, 1, 94) AS tsql_code,
  SUM(duration) AS total_duration
FROM dbo.Workload
GROUP BY SUBSTRING(tsql_code, 1, 94);

-- Query Signature

-- Query template
DECLARE @my_templatetext AS NVARCHAR(MAX);
DECLARE @my_parameters   AS NVARCHAR(MAX);

EXEC sp_get_query_template 
  N'SELECT * FROM dbo.T1 WHERE col1 = 3 AND col2 > 78',
  @my_templatetext OUTPUT,
  @my_parameters OUTPUT;

SELECT @my_templatetext AS querysig, @my_parameters AS params;
GO

-- Listing 3-4: Creation Script for the fn_SQLSigTSQL UDF
IF OBJECT_ID('dbo.fn_SQLSigTSQL') IS NOT NULL
  DROP FUNCTION dbo.fn_SQLSigTSQL;
GO

CREATE FUNCTION dbo.fn_SQLSigTSQL 
  (@p1 NTEXT, @parselength INT = 4000)
RETURNS NVARCHAR(4000)

--
-- This function is provided "AS IS" with no warranties,
-- and confers no rights. 
-- Use of included script samples are subject to the terms specified at
-- http://www.microsoft.com/info/cpyright.htm
-- 
-- Strips query strings
AS
BEGIN 
  DECLARE @pos AS INT;
  DECLARE @mode AS CHAR(10);
  DECLARE @maxlength AS INT;
  DECLARE @p2 AS NCHAR(4000);
  DECLARE @currchar AS CHAR(1), @nextchar AS CHAR(1);
  DECLARE @p2len AS INT;

  SET @maxlength = LEN(RTRIM(SUBSTRING(@p1,1,4000)));
  SET @maxlength = CASE WHEN @maxlength > @parselength 
                     THEN @parselength ELSE @maxlength END;
  SET @pos = 1;
  SET @p2 = '';
  SET @p2len = 0;
  SET @currchar = '';
  set @nextchar = '';
  SET @mode = 'command';

  WHILE (@pos <= @maxlength)
  BEGIN
    SET @currchar = SUBSTRING(@p1,@pos,1);
    SET @nextchar = SUBSTRING(@p1,@pos+1,1);
    IF @mode = 'command'
    BEGIN
      SET @p2 = LEFT(@p2,@p2len) + @currchar;
      SET @p2len = @p2len + 1 ;
      IF @currchar IN (',','(',' ','=','<','>','!')
        AND @nextchar BETWEEN '0' AND '9'
      BEGIN
        SET @mode = 'number';
        SET @p2 = LEFT(@p2,@p2len) + '#';
        SET @p2len = @p2len + 1;
      END 
      IF @currchar = ''''
      BEGIN
        SET @mode = 'literal';
        SET @p2 = LEFT(@p2,@p2len) + '#''';
        SET @p2len = @p2len + 2;
      END
    END
    ELSE IF @mode = 'number' AND @nextchar IN (',',')',' ','=','<','>','!')
      SET @mode= 'command';
    ELSE IF @mode = 'literal' AND @currchar = ''''
      SET @mode= 'command';

    SET @pos = @pos + 1;
  END
  RETURN @p2;
END
GO

-- Test fn_SQLSigTSQL Function
SELECT dbo.fn_SQLSigTSQL
  (N'SELECT * FROM dbo.T1 WHERE col1 = 3 AND col2 > 78', 4000);
GO

-- Listing 3-5: fn_SQLSigCLR and fn_RegexReplace Functions, C# Version
/*
using System.Text;
using Microsoft.SqlServer.Server;
using System.Data.SqlTypes;
using System.Text.RegularExpressions;

public partial class SQLSignature
{
    // fn_SQLSigCLR
    [SqlFunction(IsDeterministic = true, DataAccess = DataAccessKind.None)]
    public static SqlString fn_SQLSigCLR(SqlString querystring)
    {
        return (SqlString)Regex.Replace(
            querystring.Value,
            @"([\s,(=<>!](?![^\]]+[\]]))(?:(?:(?:(?#    expression coming
             )(?:([N])?(')(?:[^']|'')*('))(?#           character
             )|(?:0x[\da-fA-F]*)(?#                     binary
             )|(?:[-+]?(?:(?:[\d]*\.[\d]*|[\d]+)(?#     precise number
             )(?:[eE]?[\d]*)))(?#                       imprecise number
             )|(?:[~]?[-+]?(?:[\d]+))(?#                integer
             ))(?:[\s]?[\+\-\*\/\%\&\|\^][\s]?)?)+(?#   operators
             ))",
            @"$1$2$3#$4");
    }

    // fn_RegexReplace - for generic use of RegEx-based replace
    [SqlFunction(IsDeterministic = true, DataAccess = DataAccessKind.None)]
    public static SqlString fn_RegexReplace(
        SqlString input, SqlString pattern, SqlString replacement)
    {
        return (SqlString)Regex.Replace(
            input.Value, pattern.Value, replacement.Value);
    }
}
*/

-- Enable CLR
EXEC sp_configure 'clr enable', 1;
RECONFIGURE;
GO

-- Create assembly 
USE Performance;
CREATE ASSEMBLY SQLSignature
FROM 'C:\SQLSignature\SQLSignature\bin\Debug\SQLSignature.dll';
GO

-- Create fn_SQLSigCLR and fn_RegexReplace functions
CREATE FUNCTION dbo.fn_SQLSigCLR(@querystring AS NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
WITH RETURNS NULL ON NULL INPUT 
EXTERNAL NAME SQLSignature.SQLSignature.fn_SQLSigCLR;
GO

CREATE FUNCTION dbo.fn_RegexReplace(
  @input       AS NVARCHAR(MAX),
  @pattern     AS NVARCHAR(MAX),
  @replacement AS NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
WITH RETURNS NULL ON NULL INPUT 
EXTERNAL NAME SQLSignature.SQLSignature.fn_RegexReplace;
GO

-- Return trace data with query signature
SELECT
  dbo.fn_SQLSigCLR(tsql_code) AS sig,
  duration
FROM dbo.Workload;

SELECT 
  dbo.fn_RegexReplace(tsql_code,
    N'([\s,(=<>!](?![^\]]+[\]]))(?:(?:(?:(?#    expression coming
     )(?:([N])?('')(?:[^'']|'''')*(''))(?#      character
     )|(?:0x[\da-fA-F]*)(?#                     binary
     )|(?:[-+]?(?:(?:[\d]*\.[\d]*|[\d]+)(?#     precise number
     )(?:[eE]?[\d]*)))(?#                       imprecise number
     )|(?:[~]?[-+]?(?:[\d]+))(?#                integer
     ))(?:[\s]?[\+\-\*\/\%\&\|\^][\s]?)?)+(?#   operators
     ))',
    N'$1$2$3#$4') AS sig,
  duration
FROM dbo.Workload;

-- Return trace data with query signature checksum
SELECT
  CHECKSUM(dbo.fn_SQLSigCLR(tsql_code)) AS cs,
  duration
FROM dbo.Workload;
GO

-- Add cs column to Workload table
ALTER TABLE dbo.Workload ADD cs INT NOT NULL DEFAULT (0);
GO
UPDATE dbo.Workload
  SET cs = CHECKSUM(dbo.fn_SQLSigCLR(tsql_code));

CREATE CLUSTERED INDEX idx_cl_cs ON dbo.Workload(cs);
GO

-- Query Workload
SELECT tsql_code, duration, cs
FROM dbo.Workload;
GO

-- Aggregate data by query signature checksum

-- Load aggregate data into temporary table
IF OBJECT_ID('tempdb..#AggQueries') IS NOT NULL
  DROP TABLE #AggQueries;
GO

SELECT cs, SUM(duration) AS total_duration,
  100. * SUM(duration) / SUM(SUM(duration)) OVER() AS pct,
  ROW_NUMBER() OVER(ORDER BY SUM(duration) DESC) AS rn
INTO #AggQueries
FROM dbo.Workload
GROUP BY cs;

CREATE CLUSTERED INDEX idx_cl_cs ON #AggQueries(cs);
GO

-- Show aggregate data
SELECT cs, total_duration, pct, rn
FROM #AggQueries
ORDER BY rn;

-- Show running totals
SELECT AQ1.cs,
  CAST(AQ1.total_duration / 1000.
    AS DECIMAL(12, 2)) AS total_s, 
  CAST(SUM(AQ2.total_duration) / 1000.
    AS DECIMAL(12, 2)) AS running_total_s, 
  CAST(AQ1.pct AS DECIMAL(12, 2)) AS pct, 
  CAST(SUM(AQ2.pct) AS DECIMAL(12, 2)) AS run_pct, 
  AQ1.rn
FROM #AggQueries AS AQ1
  JOIN #AggQueries AS AQ2
    ON AQ2.rn <= AQ1.rn
GROUP BY AQ1.cs, AQ1.total_duration, AQ1.pct, AQ1.rn
HAVING SUM(AQ2.pct) - AQ1.pct <= 90 -- percentage threshold
--  OR AQ1.rn <= 5
ORDER BY AQ1.rn;

-- Isolate top offenders
WITH RunningTotals AS
(
  SELECT AQ1.cs,
    CAST(AQ1.total_duration / 1000.
      AS DECIMAL(12, 2)) AS total_s, 
    CAST(SUM(AQ2.total_duration) / 1000.
      AS DECIMAL(12, 2)) AS running_total_s, 
    CAST(AQ1.pct AS DECIMAL(12, 2)) AS pct, 
    CAST(SUM(AQ2.pct) AS DECIMAL(12, 2)) AS run_pct, 
    AQ1.rn
  FROM #AggQueries AS AQ1
    JOIN #AggQueries AS AQ2
      ON AQ2.rn <= AQ1.rn
  GROUP BY AQ1.cs, AQ1.total_duration, AQ1.pct, AQ1.rn
  HAVING SUM(AQ2.pct) - AQ1.pct <= 90 -- percentage threshold
--  OR AQ1.rn <= 5
)
SELECT RT.rn, RT.pct, W.tsql_code
FROM RunningTotals AS RT
  JOIN dbo.Workload AS W
    ON W.cs = RT.cs
ORDER BY RT.rn;

-- Isolate sig of top offenders and a sample query of each sig
WITH RunningTotals AS
(
  SELECT AQ1.cs,
    CAST(AQ1.total_duration / 1000.
      AS DECIMAL(12, 2)) AS total_s, 
    CAST(SUM(AQ2.total_duration) / 1000.
      AS DECIMAL(12, 2)) AS running_total_s, 
    CAST(AQ1.pct AS DECIMAL(12, 2)) AS pct, 
    CAST(SUM(AQ2.pct) AS DECIMAL(12, 2)) AS run_pct, 
    AQ1.rn
  FROM #AggQueries AS AQ1
    JOIN #AggQueries AS AQ2
      ON AQ2.rn <= AQ1.rn
  GROUP BY AQ1.cs, AQ1.total_duration, AQ1.pct, AQ1.rn
  HAVING SUM(AQ2.pct) - AQ1.pct <= 90 -- percentage threshold
)
SELECT RT.rn, RT.pct, S.sig, S.tsql_code AS sample_query
FROM RunningTotals AS RT
  CROSS APPLY
    (SELECT TOP(1) tsql_code, dbo.fn_SQLSigCLR(tsql_code) AS sig
     FROM dbo.Workload AS W
     WHERE W.cs = RT.cs) AS S
ORDER BY RT.rn;
GO

---------------------------------------------------------------------
-- Tune Indexes/Queries
---------------------------------------------------------------------

-- Create clustered index
CREATE CLUSTERED INDEX idx_cl_od ON dbo.Orders(orderdate);
GO

-- Start a trace
DECLARE @dbid AS INT, @traceid AS INT;
SET @dbid = DB_ID('Performance');

EXEC dbo.sp_perfworkload_trace_start
  @dbid      = @dbid,
  @tracefile = 'c:\temp\Perfworkload 20060829',
  @traceid   = @traceid OUTPUT;
GO

-- Stop the trace (assuming trace id: 2)
EXEC sp_trace_setstatus 2, 0;
EXEC sp_trace_setstatus 2, 2;
GO

---------------------------------------------------------------------
-- Tools for Query Tuning
---------------------------------------------------------------------
SET NOCOUNT ON;
USE Performance;
GO

---------------------------------------------------------------------
-- syscachobjects
---------------------------------------------------------------------

-- sys.syscacheobjects
SELECT * FROM sys.syscacheobjects;

SELECT * FROM sys.dm_exec_cached_plans;
SELECT * FROM sys.dm_exec_plan_attributes(<handle>);
SELECT * FROM sys.dm_exec_sql_text(<handle>);
GO

---------------------------------------------------------------------
-- Clearing the Cache
---------------------------------------------------------------------

-- Clearing data from cache
DBCC DROPCLEANBUFFERS;

-- Clearing execution plans from cache
DBCC FREEPROCCACHE;
GO

-- Clearin execution plans for a particular database
DBCC FLUSHPROCINDB(15);
GO

---------------------------------------------------------------------
-- Dynamic Management Objects
---------------------------------------------------------------------

---------------------------------------------------------------------
-- STATISTICS IO
---------------------------------------------------------------------

-- First clear cache
DBCC DROPCLEANBUFFERS;

-- Then run
SET STATISTICS IO ON;

SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20060101'
  AND orderdate < '20060201';
GO

SET STATISTICS IO OFF;
GO

---------------------------------------------------------------------
-- Measuring Runtime of Queries
---------------------------------------------------------------------

-- STATISTICS TIME

-- First clear cache
DBCC DROPCLEANBUFFERS;
DBCC FREEPROCCACHE;

-- Then run
SET STATISTICS TIME ON;

SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderdate >= '20060101'
  AND orderdate < '20060201';

SET STATISTICS TIME OFF;
GO

---------------------------------------------------------------------
-- Analyzing Execution Plans
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Graphical Execution Plans
---------------------------------------------------------------------

SELECT custid, empid, shipperid, COUNT(*) AS numorders
FROM dbo.Orders
WHERE orderdate >= '20060201'
  AND orderdate < '20060301'
GROUP BY custid, empid, shipperid
WITH CUBE;
GO

-- Comparing cost of two query plans
SELECT custid, empid, shipperid, COUNT(*) AS numorders
FROM dbo.Orders
WHERE orderdate >= '20060201'
  AND orderdate < '20060301'
GROUP BY custid, empid, shipperid
WITH CUBE;

SELECT custid, empid, shipperid, COUNT(*) AS numorders
FROM dbo.Orders
WHERE orderdate >= '20060201'
  AND orderdate < '20060301'
GROUP BY custid, empid, shipperid
WITH ROLLUP;
GO

---------------------------------------------------------------------
-- Textual Showplans
---------------------------------------------------------------------

-- SHOWPLAN_TEXT
SET SHOWPLAN_TEXT ON;
GO
SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 280885;
GO
SET SHOWPLAN_TEXT OFF;
GO

-- SHOWPLAN_ALL
SET SHOWPLAN_ALL ON;
GO
-- Run above query
SET SHOWPLAN_ALL OFF;
GO

-- STATISTICS PROFILE 
SET STATISTICS PROFILE ON;
GO
-- Run above query
SET STATISTICS PROFILE OFF;
GO

---------------------------------------------------------------------
-- XML Showplans
---------------------------------------------------------------------

-- SHOWPLAN_XML
SET SHOWPLAN_XML ON;
GO

SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 280885;
GO

SET SHOWPLAN_XML OFF;
GO

-- STATISTICS XML
SET STATISTICS XML ON;
GO

SELECT orderid, custid, empid, shipperid, orderdate, filler
FROM dbo.Orders
WHERE orderid = 280885;

SET STATISTICS XML OFF;
GO

-- Hints

-- USE PLAN

-- Generate XML plan
SET SHOWPLAN_XML ON;
GO
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE orderid >= 2147483647;
GO
SET SHOWPLAN_XML OFF;
GO

-- Use XML plan value in USE PLAN hint
DECLARE @oid AS INT;
SET @oid = 1000000;

SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE orderid >= @oid
OPTION (USE PLAN
N'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.0" Build="9.00.1399.06">
  <BatchSequence>
    <Batch>
      <Statements>
        <StmtSimple StatementText="SELECT orderid, custid, empid, shipperid, orderdate&#xD;&#xA;FROM dbo.Orders&#xD;&#xA;WHERE orderid &gt;= 2147483647;&#xD;&#xA;" StatementId="1" StatementCompId="1" StatementType="SELECT" StatementSubTreeCost="0.00657038" StatementEstRows="1" StatementOptmLevel="FULL" StatementOptmEarlyAbortReason="GoodEnoughPlanFound">
          <StatementSetOptions QUOTED_IDENTIFIER="false" ARITHABORT="true" CONCAT_NULL_YIELDS_NULL="false" ANSI_NULLS="false" ANSI_PADDING="false" ANSI_WARNINGS="false" NUMERIC_ROUNDABORT="false" />
          <QueryPlan CachedPlanSize="14">
            <RelOp NodeId="0" PhysicalOp="Nested Loops" LogicalOp="Inner Join" EstimateRows="1" EstimateIO="0" EstimateCPU="4.18e-006" AvgRowSize="40" EstimatedTotalSubtreeCost="0.00657038" Parallel="0" EstimateRebinds="0" EstimateRewinds="0">
              <OutputList>
                <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderid" />
                <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="custid" />
                <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="empid" />
                <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="shipperid" />
                <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderdate" />
              </OutputList>
              <NestedLoops Optimized="1">
                <OuterReferences>
                  <ColumnReference Column="Uniq1002" />
                  <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderdate" />
                </OuterReferences>
                <RelOp NodeId="2" PhysicalOp="Index Seek" LogicalOp="Index Seek" EstimateRows="1" EstimateIO="0.003125" EstimateCPU="0.0001581" AvgRowSize="23" EstimatedTotalSubtreeCost="0.0032831" Parallel="0" EstimateRebinds="0" EstimateRewinds="0">
                  <OutputList>
                    <ColumnReference Column="Uniq1002" />
                    <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderid" />
                    <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderdate" />
                  </OutputList>
                  <IndexScan Ordered="1" ScanDirection="FORWARD" ForcedIndex="0" NoExpandHint="0">
                    <DefinedValues>
                      <DefinedValue>
                        <ColumnReference Column="Uniq1002" />
                      </DefinedValue>
                      <DefinedValue>
                        <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderid" />
                      </DefinedValue>
                      <DefinedValue>
                        <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderdate" />
                      </DefinedValue>
                    </DefinedValues>
                    <Object Database="[Performance]" Schema="[dbo]" Table="[Orders]" Index="[PK_Orders]" />
                    <SeekPredicates>
                      <SeekPredicate>
                        <StartRange ScanType="GE">
                          <RangeColumns>
                            <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderid" />
                          </RangeColumns>
                          <RangeExpressions>
                            <ScalarOperator ScalarString="(2147483647)">
                              <Const ConstValue="(2147483647)" />
                            </ScalarOperator>
                          </RangeExpressions>
                        </StartRange>
                      </SeekPredicate>
                    </SeekPredicates>
                  </IndexScan>
                </RelOp>
                <RelOp NodeId="4" PhysicalOp="Clustered Index Seek" LogicalOp="Clustered Index Seek" EstimateRows="1" EstimateIO="0.003125" EstimateCPU="0.0001581" AvgRowSize="28" EstimatedTotalSubtreeCost="0.0032831" Parallel="0" EstimateRebinds="0" EstimateRewinds="0">
                  <OutputList>
                    <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="custid" />
                    <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="empid" />
                    <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="shipperid" />
                  </OutputList>
                  <IndexScan Lookup="1" Ordered="1" ScanDirection="FORWARD" ForcedIndex="0" NoExpandHint="0">
                    <DefinedValues>
                      <DefinedValue>
                        <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="custid" />
                      </DefinedValue>
                      <DefinedValue>
                        <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="empid" />
                      </DefinedValue>
                      <DefinedValue>
                        <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="shipperid" />
                      </DefinedValue>
                    </DefinedValues>
                    <Object Database="[Performance]" Schema="[dbo]" Table="[Orders]" Index="[idx_cl_od]" TableReferenceId="-1" />
                    <SeekPredicates>
                      <SeekPredicate>
                        <Prefix ScanType="EQ">
                          <RangeColumns>
                            <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderdate" />
                            <ColumnReference Column="Uniq1002" />
                          </RangeColumns>
                          <RangeExpressions>
                            <ScalarOperator ScalarString="[Performance].[dbo].[Orders].[orderdate]">
                              <Identifier>
                                <ColumnReference Database="[Performance]" Schema="[dbo]" Table="[Orders]" Column="orderdate" />
                              </Identifier>
                            </ScalarOperator>
                            <ScalarOperator ScalarString="[Uniq1002]">
                              <Identifier>
                                <ColumnReference Column="Uniq1002" />
                              </Identifier>
                            </ScalarOperator>
                          </RangeExpressions>
                        </Prefix>
                      </SeekPredicate>
                    </SeekPredicates>
                  </IndexScan>
                </RelOp>
              </NestedLoops>
            </RelOp>
            <ParameterList>
              <ColumnReference Column="@1" ParameterCompiledValue="(2147483647)" />
            </ParameterList>
          </QueryPlan>
        </StmtSimple>
      </Statements>
    </Batch>
  </BatchSequence>
</ShowPlanXML>');
GO

---------------------------------------------------------------------
-- Index Tuning
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Table and Index Structures
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Pages and Extents
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Heap
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Clustered Index
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Nonclustered Index on a Heap
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Nonclustered Index on a Clustered Table
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Index Access Methods
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Table Scan/Unordered Clustered Index Scan
---------------------------------------------------------------------

SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders;

---------------------------------------------------------------------
-- Unordered Covering Nonclustered Index Scan
---------------------------------------------------------------------
SELECT orderid
FROM dbo.Orders;

---------------------------------------------------------------------
-- Ordered Clustered Index Scan
---------------------------------------------------------------------
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
ORDER BY orderdate;

---------------------------------------------------------------------
-- Ordered Covering Nonclustered Index Scan
---------------------------------------------------------------------
SELECT orderid, orderdate
FROM dbo.Orders
ORDER BY orderid;

-- With segmentation
SELECT orderid, custid, empid, orderdate
FROM dbo.Orders AS O1
WHERE orderid = 
  (SELECT MAX(orderid)
   FROM dbo.Orders AS O2
   WHERE O2.orderdate = O1.orderdate);

---------------------------------------------------------------------
-- Nonclustered Index Seek + Ordered Partial Scan + Lookups
---------------------------------------------------------------------
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE orderid BETWEEN 101 AND 120;

---------------------------------------------------------------------
-- Unordered Nonclustered Index Scan + Lookups
---------------------------------------------------------------------

-- Non-first column in index; auto created statistics
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE custid = 'C0000000001';

SELECT name
FROM sys.stats
WHERE object_id = OBJECT_ID('dbo.Orders')
  AND auto_created = 1;

-- String cardinalities
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE custid LIKE '%9999';

---------------------------------------------------------------------
-- Clustered Index Seek + Ordered Partial Scan
---------------------------------------------------------------------
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE orderdate = '20060212';

---------------------------------------------------------------------
-- Covering Nonclustered Index Seek + Ordered Partial Scan
---------------------------------------------------------------------
SELECT shipperid, orderdate, custid
FROM dbo.Orders
WHERE shipperid = 'C'
  AND orderdate >= '20060101'
  AND orderdate < '20070101';
GO

-- INCLUDE Non-Key Columns
DROP INDEX dbo.Orders.idx_nc_sid_od_cid;

CREATE NONCLUSTERED INDEX idx_nc_sid_od_i_cid
  ON dbo.Orders(shipperid, orderdate)
  INCLUDE(custid);
GO

---------------------------------------------------------------------
-- Index Intersection
---------------------------------------------------------------------
SELECT orderid, custid
FROM dbo.Orders
WHERE shipperid = 'A';
GO

---------------------------------------------------------------------
-- Indexed Views
---------------------------------------------------------------------
IF OBJECT_ID('dbo.VEmpOrders') IS NOT NULL
  DROP VIEW dbo.VEmpOrders;
GO
CREATE VIEW dbo.VEmpOrders
  WITH SCHEMABINDING
AS

SELECT empid, YEAR(orderdate) AS orderyear, COUNT_BIG(*) AS numorders
FROM dbo.Orders
GROUP BY empid, YEAR(orderdate);
GO

CREATE UNIQUE CLUSTERED INDEX idx_ucl_eid_oy
  ON dbo.VEmpOrders(empid, orderyear);
GO

SELECT empid, orderyear, numorders
FROM dbo.VEmpOrders;

SELECT empid, YEAR(orderdate) AS orderyear, COUNT_BIG(*) AS numorders
FROM dbo.Orders
GROUP BY empid, YEAR(orderdate);
GO

---------------------------------------------------------------------
-- Index Optimization Scale
---------------------------------------------------------------------

-- Drop all indexes besides the clustered index from Orders
-- Or rerun Listing 1, after removing all index and primary key
-- creation statements on Orders, only keep clustered index

-- Query
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE orderid >= 999001; -- change value for different selectivities
GO

---------------------------------------------------------------------
-- Table Scan (Unordered Clustered Index Scan)
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Unordered Covering Nonclustered Index Scan
---------------------------------------------------------------------

-- Create index
CREATE NONCLUSTERED INDEX idx_nc_od_i_oid_cid_eid_sid
  ON dbo.Orders(orderdate)
  INCLUDE(orderid, custid, empid, shipperid);
GO

-- Run query

-- Drop index
DROP INDEX dbo.Orders.idx_nc_od_i_oid_cid_eid_sid;
GO

---------------------------------------------------------------------
-- Unordered Nonclustered Index Scan + Lookups
---------------------------------------------------------------------

-- Create index
CREATE NONCLUSTERED INDEX idx_nc_od_i_oid
  ON dbo.Orders(orderdate)
  INCLUDE(orderid);
GO

-- Run query

-- Drop index
DROP INDEX dbo.Orders.idx_nc_od_i_oid;
GO

---------------------------------------------------------------------
-- Nonclustered Index Seek + Ordered Partial Scan + Lookups
---------------------------------------------------------------------

-- Create index
CREATE UNIQUE NONCLUSTERED INDEX idx_unc_oid
  ON dbo.Orders(orderid);
GO

-- Run query

-- Determining selectivity point
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE orderid >= 500001; -- use binary algorithm to determine points

-- Selectivity point where index is first used
SELECT orderid, custid, empid, shipperid, orderdate
FROM dbo.Orders
WHERE orderid >= 992820;
GO

-- Drop index
DROP INDEX dbo.Orders.idx_unc_oid;
GO

---------------------------------------------------------------------
-- Clustered Index Seek + Ordered Partial Scan
---------------------------------------------------------------------

-- Drop existing clustered index, and create the new one
DROP INDEX dbo.Orders.idx_cl_od;
CREATE UNIQUE CLUSTERED INDEX idx_cl_oid ON dbo.Orders(orderid);
GO

-- Run query

-- Restore original clustered index
DROP INDEX dbo.Orders.idx_cl_oid;
CREATE CLUSTERED INDEX idx_cl_od ON dbo.Orders(orderdate);
GO

---------------------------------------------------------------------
-- Covering Nonclustered Index Seek + Ordered Partial Scan
---------------------------------------------------------------------

-- Create index
CREATE UNIQUE NONCLUSTERED INDEX idx_unc_oid_i_od_cid_eid_sid
  ON dbo.Orders(orderid)
  INCLUDE(orderdate, custid, empid, shipperid);
GO

-- Run query

-- Drop index
DROP INDEX dbo.Orders.idx_unc_oid_i_od_cid_eid_sid;
GO

---------------------------------------------------------------------
-- Index Optimization Scale Summary and Analysis
---------------------------------------------------------------------

-- Low-level I/O, locking, latching, and access method activity
SELECT * 
FROM sys.dm_db_index_operational_stats(
  DB_ID('Performance'), null, null, null);

-- Counts of index operations
SELECT *
FROM sys.dm_db_index_usage_stats;
GO

---------------------------------------------------------------------
-- Fragmentation
---------------------------------------------------------------------

-- Fragmentation Information in SQL Server 2005
SELECT * 
FROM sys.dm_db_index_physical_stats(
  DB_ID('Performance'), NULL, NULL, NULL, NULL);
GO

-- Fragmentation Information in SQL Server 2000
DBCC SHOWCONTIG WITH ALL_INDEXES, TABLERESULTS, NO_INFOMSGS;
 
-- Online Index Rebuild
ALTER INDEX idx_cl_od ON dbo.Orders REBUILD WITH (ONLINE = ON);
GO

-- Index Reorganize
ALTER INDEX idx_cl_od ON dbo.Orders REORGANIZE;
GO

---------------------------------------------------------------------
-- Partitioning
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Preparing Sample Data
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Data Preparation
---------------------------------------------------------------------

---------------------------------------------------------------------
-- Max Concurrent Sessions
---------------------------------------------------------------------

-- Listing 3-6: Creating and Populating Sessions
SET NOCOUNT ON;
USE Performance;
GO
IF OBJECT_ID('dbo.Sessions') IS NOT NULL
  DROP TABLE dbo.Sessions;
GO

CREATE TABLE dbo.Sessions
(
  keycol    INT         NOT NULL IDENTITY,
  app       VARCHAR(10) NOT NULL,
  usr       VARCHAR(10) NOT NULL,
  host      VARCHAR(10) NOT NULL,
  starttime DATETIME    NOT NULL,
  endtime   DATETIME    NOT NULL,
  CONSTRAINT PK_Sessions PRIMARY KEY(keycol),
  CHECK(endtime > starttime)
);

INSERT INTO dbo.Sessions
  VALUES('app1', 'user1', 'host1', '20030212 08:30', '20030212 10:30');
INSERT INTO dbo.Sessions
  VALUES('app1', 'user2', 'host1', '20030212 08:30', '20030212 08:45');
INSERT INTO dbo.Sessions
  VALUES('app1', 'user3', 'host2', '20030212 09:00', '20030212 09:30');
INSERT INTO dbo.Sessions
  VALUES('app1', 'user4', 'host2', '20030212 09:15', '20030212 10:30');
INSERT INTO dbo.Sessions
  VALUES('app1', 'user5', 'host3', '20030212 09:15', '20030212 09:30');
INSERT INTO dbo.Sessions
  VALUES('app1', 'user6', 'host3', '20030212 10:30', '20030212 14:30');
INSERT INTO dbo.Sessions
  VALUES('app1', 'user7', 'host4', '20030212 10:45', '20030212 11:30');
INSERT INTO dbo.Sessions
  VALUES('app1', 'user8', 'host4', '20030212 11:00', '20030212 12:30');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user8', 'host1', '20030212 08:30', '20030212 08:45');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user7', 'host1', '20030212 09:00', '20030212 09:30');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user6', 'host2', '20030212 11:45', '20030212 12:00');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user5', 'host2', '20030212 12:30', '20030212 14:00');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user4', 'host3', '20030212 12:45', '20030212 13:30');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user3', 'host3', '20030212 13:00', '20030212 14:00');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user2', 'host4', '20030212 14:00', '20030212 16:30');
INSERT INTO dbo.Sessions
  VALUES('app2', 'user1', 'host4', '20030212 15:30', '20030212 17:00');

CREATE INDEX idx_nc_app_st_et ON dbo.Sessions(app, starttime, endtime);
GO

-- Query returning maximum number of concurrent sessions
SELECT app, MAX(concurrent) AS mx
FROM (SELECT app,
        (SELECT COUNT(*)
         FROM dbo.Sessions AS S2
         WHERE S1.app = S2.app
           AND S1.ts >= S2.starttime
           AND S1.ts < S2.endtime) AS concurrent
      FROM (SELECT DISTINCT app, starttime AS ts
            FROM dbo.Sessions) AS S1) AS C
GROUP BY app;
GO

-- Listing 3-7: Populate Sessions with Inadequate Sample Data
SET NOCOUNT ON;
USE Performance;
GO
IF OBJECT_ID('dbo.BigSessions') IS NOT NULL
  DROP TABLE dbo.BigSessions;
GO
SELECT IDENTITY(int, 1, 1) AS keycol,
  app, usr, host, starttime, endtime
INTO dbo.BigSessions
FROM dbo.Sessions AS S, Nums
WHERE n <= 62500;

ALTER TABLE dbo.BigSessions
  ADD CONSTRAINT PK_BigSessions PRIMARY KEY(keycol);
CREATE INDEX idx_nc_app_st_et
  ON dbo.BigSessions(app, starttime, endtime);
GO

-- Query against BigSessions
SELECT app, MAX(concurrent) AS mx
FROM (SELECT app,
        (SELECT COUNT(*)
         FROM dbo.BigSessions AS S2
         WHERE S1.app = S2.app
           AND S1.ts >= S2.starttime
           AND S1.ts < S2.endtime) AS concurrent
      FROM (SELECT DISTINCT app, starttime AS ts
            FROM dbo.BigSessions) AS S1) AS C
GROUP BY app;
GO

-- Revised Query against BigSessions
SELECT app, MAX(concurrent) AS mx
FROM (SELECT app,
        (SELECT COUNT(*)
         FROM dbo.BigSessions AS S2
         WHERE S1.app = S2.app
           AND S1.starttime >= S2.starttime
           AND S1.starttime < S2.endtime) AS concurrent
      FROM dbo.BigSessions AS S1) AS C
GROUP BY app;

-- Listing 3-8: Populate Sessions with Adequate Sample Data
SET NOCOUNT ON;
USE Performance;
GO
IF OBJECT_ID('dbo.BigSessions') IS NOT NULL
  DROP TABLE dbo.BigSessions;
GO

SELECT
  IDENTITY(int, 1, 1) AS keycol, 
  D.*,
  DATEADD(
    second,
    1 + ABS(CHECKSUM(NEWID())) % (20*60),
    starttime) AS endtime
INTO dbo.BigSessions
FROM
(
  SELECT 
    'app' + CAST(1 + ABS(CHECKSUM(NEWID())) % 10 AS VARCHAR(10)) AS app,
    'user1' AS usr,
    'host1' AS host,
    DATEADD(
      second,
      1 + ABS(CHECKSUM(NEWID())) % (30*24*60*60),
      '20040101') AS starttime
  FROM dbo.Nums
  WHERE n <= 1000000
) AS D;

ALTER TABLE dbo.BigSessions
  ADD CONSTRAINT PK_BigSessions PRIMARY KEY(keycol);
CREATE INDEX idx_nc_app_st_et
  ON dbo.BigSessions(app, starttime, endtime);
GO

---------------------------------------------------------------------
-- TABLESAMPLE
---------------------------------------------------------------------

-- Simple example for TABLESAMPLE
SELECT *
FROM Performance.dbo.Orders TABLESAMPLE (1000 ROWS);

SET NOCOUNT ON;
USE Performance;
GO

-- Using TABLESAMPLE with ROWS (coverted to percent)
SELECT *
FROM dbo.Orders TABLESAMPLE SYSTEM (1000 ROWS);

-- Using TABLESAMPLE with PERCENT
SELECT *
FROM dbo.Orders TABLESAMPLE (0.1 PERCENT);

-- Using TABLESAMPLE and TOP to limit upper bound
SELECT TOP(1000) *
FROM dbo.Orders TABLESAMPLE (2000 ROWS);

-- Using TABLESAMPLE with the REPEATABLE option
SELECT *
FROM dbo.Orders TABLESAMPLE (1000 ROWS) REPEATABLE(42);
GO

-- With small tables you might not get any rows
SELECT *
FROM AdventureWorks.Sales.StoreContact TABLESAMPLE (1 ROWS);

-- Using TOP and CHECKSUM(NEWID())
-- Full table scn
SELECT TOP(1) *
FROM AdventureWorks.Sales.StoreContact
ORDER BY CHECKSUM(NEWID());

-- Bernoulli
SELECT * 
FROM AdventureWorks.Sales.StoreContact
WHERE ABS((customerid%customerid)+CHECKSUM(NEWID()))/POWER(2.,31) < 0.01; -- probability
GO

---------------------------------------------------------------------
-- Set-Based vs. Iterative/Procedural Approach and a Tuning Exercise
---------------------------------------------------------------------

SET NOCOUNT ON;
USE Performance;
GO

-- Make sure only clustered index and primary key exist
CREATE CLUSTERED INDEX idx_cl_od ON dbo.Orders(orderdate);

ALTER TABLE dbo.Orders ADD
  CONSTRAINT PK_Orders PRIMARY KEY NONCLUSTERED(orderid);
GO

-- Add a few rows to Shippers and Orders
INSERT INTO dbo.Shippers(shipperid, shippername) VALUES('B', 'Shipper_B');
INSERT INTO dbo.Shippers(shipperid, shippername) VALUES('D', 'Shipper_D');
INSERT INTO dbo.Shippers(shipperid, shippername) VALUES('F', 'Shipper_F');
INSERT INTO dbo.Shippers(shipperid, shippername) VALUES('H', 'Shipper_H');
INSERT INTO dbo.Shippers(shipperid, shippername) VALUES('X', 'Shipper_X');
INSERT INTO dbo.Shippers(shipperid, shippername) VALUES('Y', 'Shipper_Y');
INSERT INTO dbo.Shippers(shipperid, shippername) VALUES('Z', 'Shipper_Z');

INSERT INTO dbo.Orders(orderid, custid, empid, shipperid, orderdate)
  VALUES(1000001, 'C0000000001', 1, 'B', '20000101');
INSERT INTO dbo.Orders(orderid, custid, empid, shipperid, orderdate)
  VALUES(1000002, 'C0000000001', 1, 'D', '20000101');
INSERT INTO dbo.Orders(orderid, custid, empid, shipperid, orderdate)
  VALUES(1000003, 'C0000000001', 1, 'F', '20000101');
INSERT INTO dbo.Orders(orderid, custid, empid, shipperid, orderdate)
  VALUES(1000004, 'C0000000001', 1, 'H', '20000101');
GO

-- Create covering index for problem
CREATE NONCLUSTERED INDEX idx_nc_sid_od
  ON dbo.Orders(shipperid, orderdate);
GO

-- Listing 3-9: Cursor Solution
DECLARE
  @sid     AS VARCHAR(5),
  @od      AS DATETIME,
  @prevsid AS VARCHAR(5),
  @prevod  AS DATETIME;

DECLARE ShipOrdersCursor CURSOR FAST_FORWARD FOR
  SELECT shipperid, orderdate
  FROM dbo.Orders
  ORDER BY shipperid, orderdate;

OPEN ShipOrdersCursor;

FETCH NEXT FROM ShipOrdersCursor INTO @sid, @od;

SELECT @prevsid = @sid, @prevod = @od;

WHILE @@fetch_status = 0
BEGIN
  IF @prevsid <> @sid AND @prevod < '20010101' PRINT @prevsid;
  SELECT @prevsid = @sid, @prevod = @od;
  FETCH NEXT FROM ShipOrdersCursor INTO @sid, @od;
END

IF @prevod < '20010101' PRINT @prevsid;

CLOSE ShipOrdersCursor;

DEALLOCATE ShipOrdersCursor;
GO

-- Set-based solution 1
SELECT shipperid
FROM dbo.Orders
GROUP BY shipperid
HAVING MAX(orderdate) < '20010101';

-- Get maximum date for a particular shipper
SELECT MAX(orderdate) FROM dbo.Orders WHERE shipperid = 'A';

-- Set-based solution 2
SELECT shipperid
FROM (SELECT shipperid,
        (SELECT MAX(orderdate)
         FROM dbo.Orders AS O
         WHERE O.shipperid = S.shipperid) AS maxod
      FROM dbo.Shippers AS S) AS D
WHERE maxod < '20010101';

-- Set-based solution 3
SELECT shipperid
FROM (SELECT shipperid,
        (SELECT MAX(orderdate)
         FROM dbo.Orders AS O
         WHERE O.shipperid = S.shipperid) AS maxod
      FROM dbo.Shippers AS S) AS D
WHERE COALESCE(maxod, '99991231') < '20010101';

-- Set-based solution 4
SELECT shipperid
FROM dbo.Shippers AS S
WHERE NOT EXISTS
  (SELECT * FROM dbo.Orders AS O
   WHERE O.shipperid = S.shipperid
     AND O.orderdate >= '20010101')
  AND EXISTS
  (SELECT * FROM dbo.Orders AS O
   WHERE O.shipperid = S.shipperid);
