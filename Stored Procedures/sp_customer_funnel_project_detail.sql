create procedure sp_customer_funnel_project_detail
	@Customer_ID	int,
	@Project_Name	varchar(50)
AS
	declare @strsql varchar(8000)
	declare @tmpProject_Name varchar(100)
	set @tmpProject_Name = replace(@Project_Name, '''', '''''')

	select @strsql = '
		declare @eq_company_profit_ctr varchar(8000)
		select @eq_company_profit_ctr = coalesce(@eq_company_profit_ctr + '', '', '''', '''') + convert(varchar(3),x.company_id) + ''_'' +  convert(varchar(3), x.profit_ctr_id)
		from FunnelXCompany x
		inner join CustomerFunnel c on (x.funnel_id = c.funnel_id and c.customer_id = ' + convert(varchar(10), @Customer_ID) + ' and c.project_name = ''' + @tmpProject_Name + ''')
		where c.customer_id = ' + convert(varchar(10), @Customer_ID) + ' and c.project_name = ''' + @tmpProject_Name + '''
		order by x.company_id, x.profit_ctr_id
		declare @status_date datetime
		select top 1 @status_date = status_date from FunnelDates where funnel_id = (select funnel_id from CustomerFunnel c where c.customer_id = ' + convert(varchar(10), @Customer_ID) + ' and c.project_name = ''' + @tmpProject_Name + ''') order by status_date desc
		select @eq_company_profit_ctr as eq_company_profit_ctr, @status_date as status_date, * from CustomerFunnel c
		where c.customer_id = ' + convert(varchar(10), @Customer_ID) + ' and c.project_name = ''' + @tmpProject_Name + '''
	'
	--print @strsql
	exec(@strsql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_project_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_project_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_project_detail] TO [EQAI]
    AS [dbo];

