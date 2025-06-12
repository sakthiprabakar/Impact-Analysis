CREATE PROC [dbo].[sp_OppRevenueGoal_select] 
    @territory_code VARCHAR(5) = NULL,
    @company_id int = NULL,
    @profit_ctr_id int = NULL,
    @region_id int = null,
    @nam_id int = null,
    @goal_type varchar(20) = NULL,
    @goal_month DATETIME = NULL
AS 
begin
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

declare @sql varchar(max) = 'SELECT * FROM   [dbo].[OppRevenueGoal] WHERE 1=1 '

IF @territory_code is not null
	set @sql = @sql + 'AND territory_code = ''' + @territory_code + ''' '
	
IF @company_id is not null
	set @sql = @sql + 'AND company_id = ''' + cast(@company_id as varchar(10))+ ''' and profit_ctr_id =  ''' + cast(@profit_ctr_id as varchar(10)) + ''' '
	
IF @region_id is not null
	set @sql = @sql + 'AND region_id = ''' + cast(@region_id  as varchar(10)) + ''' '
	
IF @nam_id is not null
	set @sql = @sql + 'AND nam_id = ''' + cast(@nam_id  as varchar(10)) + ''' '
	
IF @goal_month is not null
	set @sql = @sql + 'AND goal_month = ''' + cast(@goal_month  as varchar(20))+ ''' '
	
IF @goal_type is not null
	set @sql = @sql + 'AND goal_type = ''' + @goal_type + ''' '					

print @sql
exec(@sql)

end
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_select] TO [EQAI]
    AS [dbo];

