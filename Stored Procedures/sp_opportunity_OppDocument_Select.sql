
CREATE PROCEDURE [dbo].[sp_opportunity_OppDocument_Select] 
	@image_id INT = NULL,
	@opp_id int = NULL,
	@document_name varchar(255) = NULL,
	@include_file_contents char(1) = 'N'
AS
  SET NOCOUNT ON
  
declare @search_sql varchar(max) = ''
DECLARE @where_sql varchar(max) = ''
declare @order_by_sql varchar(200)
set @search_sql = 'SELECT image_id,
	opp_id ,
	document_name ,
	scan_file ,
	file_type ,
	document_source ,
	status ,
	modified_by ,
	date_modified, 
	added_by,
	date_added, 
	'

if @include_file_contents = 'Y'
	SET @search_sql = @search_sql + ' image_blob '
ELSE
	SET @search_sql = @search_sql + 'NULL as image_blob'
	
SET @search_sql = @search_sql + ' FROM [dbo].[OppDocument] WHERE  status=''A'' '
  
SET @order_by_sql = ' ORDER BY date_modified DESC '

-- add filter criteria
IF @image_id IS NOT NULL
	SET @where_sql = ' AND image_id = ' + cast(@image_id as varchar(20))
	
IF @opp_id IS NOT NULL	
	SET @where_sql = ' AND opp_id = ' + cast(@opp_id as varchar(20))
	
IF @document_name IS NOT NULL	
	SET @where_sql = ' AND file_name = LIKE ''%' + @document_name + '%'' '

declare @sql varchar(max) = @search_sql + @where_sql + @order_by_sql
print @sql
EXEC(@sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Select] TO [EQAI]
    AS [dbo];

