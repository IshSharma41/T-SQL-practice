----------------------------------------------------------------------
-- Inside Microsoft SQL Server 2005: T-SQL Querying (MSPress, 2006)
-- Appendix A - Logic Puzzles
-- Copyright Itzik Ben-Gan, 2006
-- All Rights Reserved
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Puzzle 13: Monty Hall Problem
----------------------------------------------------------------------

-- Simulating the "Monty Hall Problem" in T-SQL (2005)
--   A description of the problem can be found at
--   http://math.ucsd.edu/~crypto/Monty/montybg.html)
WITH T0 AS
(
  SELECT
    -- prize_door is door 1, 2, or 3 with equal probability
    1 + ABS(BINARY_CHECKSUM(NEWID())) % 3 AS prize_door
  FROM dbo.Nums
  WHERE n <= 100000 -- number of trials
  -- use any handy table that is not too small
),
T1 AS
(
  SELECT
    prize_door,
    -- your_door is door 1, 2, or 3 with equal probability
    1 + ABS(BINARY_CHECKSUM(NEWID())) % 3 AS your_door
  FROM T0
),
T2 AS
(
  SELECT
  -- The host opens a door you did not choose,
  -- and which he knows is not the prize door.
  -- If he has two choices, each is equally likely.
    prize_door,
    your_door,
    CASE
      WHEN prize_door <> your_door THEN 6 - prize_door - your_door
      ELSE SUBSTRING(
                REPLACE('123',RIGHT(your_door, 1), ''),
                1 + ABS(BINARY_CHECKSUM(NEWID())) % 2,
                1)
    END AS open_door
  FROM T1
),
T3 AS
(
  SELECT
    prize_door,
    your_door,
    open_door,
    -- The "other door" is the still-closed door
    -- you did not originally choose.
    6 - your_door - open_door AS other_door
  FROM T2
),
T4 AS
(
  SELECT
    COUNT(CASE WHEN prize_door = your_door
                 THEN 'Don''t Switch' END) AS staying_wins,
    COUNT(CASE WHEN prize_door = other_door
                 THEN 'Do Switch!'    END) AS switching_wins,
    COUNT(*)                               AS trials
  FROM T3
)
SELECT
  trials,
  CAST(100.0 * staying_wins / trials
       AS DECIMAL(5,2)) AS staying_winsPercent,
  CAST(100.0 * switching_wins / trials
       AS DECIMAL(5,2)) as switching_winsPercent
FROM T4;

----------------------------------------------------------------------
-- Puzzle 17: Self-Replicating Code (Quine)
----------------------------------------------------------------------

-- Solution 1
PRINT REPLACE(SPACE(1)+CHAR(39)+SPACE(1)+CHAR(39)+CHAR(41),SPACE(1),'PRINT REPLACE(SPACE(1)+CHAR(39)+SPACE(1)+CHAR(39)+CHAR(41),SPACE(1),')

-- Solution 2
PRINT REPLACE(0x2027202729,0X20,'PRINT REPLACE(0x2027202729,0x20,')
