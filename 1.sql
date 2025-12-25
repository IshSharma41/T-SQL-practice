use AdventureWorks2022
GO

select T.name as table_name, T.object_id as Table_Obj_ID, S.schema_id as schema_id, S.name as schema_name 
from sys.tables T inner join sys.schemas S 
    on  T.schema_id= S.schema_id
order by S.schema_id ASC