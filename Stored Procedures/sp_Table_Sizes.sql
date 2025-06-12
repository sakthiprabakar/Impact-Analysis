-- Get a list of tables and their sizes on disk
CREATE PROCEDURE [dbo].[sp_Table_Sizes]
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;
DECLARE @table_name VARCHAR(500)  
DECLARE @schema_name VARCHAR(500)  
DECLARE @tab1 TABLE( 
        tablename VARCHAR (500) collate database_default 
       ,schemaname VARCHAR(500) collate database_default 
) 

CREATE TABLE #temp_Table ( 
        tablename sysname 
       ,row_count INT 
       ,reserved VARCHAR(50) collate database_default 
       ,data VARCHAR(50) collate database_default 
       ,index_size VARCHAR(50) collate database_default 
       ,unused VARCHAR(50) collate database_default  
) 

DECLARE c1 CURSOR FOR 
SELECT Table_Schema + '.' + Table_Name   
FROM information_schema.tables t1  
WHERE TABLE_TYPE = 'BASE TABLE' 

OPEN c1 
FETCH NEXT FROM c1 INTO @table_name 
WHILE @@FETCH_STATUS = 0  
BEGIN   
        SET @table_name = REPLACE(@table_name, '[','');  
        SET @table_name = REPLACE(@table_name, ']','');  

        -- make sure the object exists before calling sp_spacedused 
        IF EXISTS(SELECT id FROM sysobjects WHERE id = OBJECT_ID(@table_name)) 
        BEGIN 
               INSERT INTO #temp_Table EXEC sp_spaceused @table_name, false; 
        END 

        FETCH NEXT FROM c1 INTO @table_name 
END 
CLOSE c1 
DEALLOCATE c1 

SELECT t1.tablename as [Table]
	, so.create_date as [Create Date]
	, convert(int, t1.row_count) as [Row Count]
	, convert(int, replace(t1.reserved, ' KB', '')) as [Reserved KB]
	, convert(int, replace(t1.data, ' KB', '')) as [Data KB]
	, convert(int, replace(t1.index_size, ' KB', '')) as [Index KB]
	, convert(int, replace(t1.unused, ' KB', '')) as [Unused KB]
FROM #temp_Table t1  
inner join sys.objects so on OBJECT_ID(t1.tablename) = so.object_id
ORDER BY convert(int, replace(t1.reserved, ' KB', '')) desc; 

DROP TABLE #temp_Table
END