# Inside T-SQL Querying Resources

Complete reference materials from **"Inside Microsoft SQL Server 2005: T-SQL Querying"** by Itzik Ben-Gan (Microsoft Press, 2006).

## Contents

### Core Chapters

| Chapter | Topic |
|---------|-------|
| **01** | Logical Query Processing |
| **02** | Physical Query Processing |
| **03** | Query Tuning |
| **04** | Subqueries, Table Expressions and Ranking Functions |
| **05** | Joins and Set Operations |
| **06** | Aggregating and Pivoting Data |
| **07** | TOP and APPLY |
| **08** | Data Modification |
| **09** | Graphs, Trees, Hierarchies and Recursive Queries |

### Supplementary Materials

- **Appendix A - Logic Puzzles.sql**: Logic puzzle problems with SQL solutions
- **instnwnd.sql**: Northwind database installation script
- **instpubs.sql**: Pubs database installation script

## How to Use

1. **Setup Databases**: Run `instnwnd.sql` and `instpubs.sql` to prepare sample databases
2. **Study by Chapter**: Each chapter file contains:
   - Explanatory comments from the book
   - Sample queries with annotations
   - Data definition language (DDL) for test tables
   - Executable examples
3. **Practice**: Modify queries and experiment with different approaches
4. **Reference**: Use files as lookup material for specific T-SQL concepts

## Key Topics Covered

### Fundamentals
- Logical query processing order
- Physical execution plans and optimization
- Index usage and query tuning strategies

### Advanced Querying
- Subqueries and correlated subqueries
- Common Table Expressions (CTEs)
- Derived tables and inline table-valued functions
- Ranking functions (ROW_NUMBER, RANK, DENSE_RANK, NTILE)

### Set Operations
- UNION, UNION ALL, INTERSECT, EXCEPT
- Join types and performance considerations

### Data Aggregation
- GROUP BY and HAVING clauses
- Window functions and aggregation
- PIVOT and UNPIVOT for data transformation

### Advanced Features
- TOP clause with ordering
- APPLY operator (CROSS APPLY, OUTER APPLY)
- Recursive Common Table Expressions (CTEs)
- Hierarchical data structures

### Data Modification
- INSERT, UPDATE, DELETE strategies
- Transactions and error handling
- Data integrity considerations

## Prerequisites

- Microsoft SQL Server 2005 or later
- Basic understanding of SQL and relational databases
- Sample databases (Northwind and/or Pubs)

## Notes

- All scripts use T-SQL syntax specific to SQL Server
- File encoding and formatting should be compatible with SQL Server Management Studio (SSMS)
- Execute scripts with appropriate database context using `USE` statements
- Some examples may require specific user permissions or database settings

## About the Author of the book being referred to 

Itzik Ben-Gan is a renowned T-SQL expert and Microsoft MVP. This textbook is considered one of the most comprehensive references for advanced T-SQL querying techniques.
