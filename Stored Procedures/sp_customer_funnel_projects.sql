
/***************************************************************************************
Retrieves the available Funnel Projects for a Customer

10/08/2003 JPB	Created
Test Cmd Line: sp_customer_funnel_projects 2222
****************************************************************************************/
create procedure sp_customer_funnel_projects
	@Customer_ID	int
AS
	select project_name, 1 as priority, 0 as status_sort, (select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id order by status_date desc) as date_added, 'New' as status from CustomerFunnel f
	where customer_id = @Customer_ID
	and status = 'N'
	union
	select project_name, 2 as priority, s.status_sort, (select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id order by status_date desc) as date_added, status_text as status from CustomerFunnel f inner join FunnelStatus s on f.status = s.status_code
	where customer_id = @Customer_ID
	and status <> 'N' and status <> 'C'
	union
	select project_name, 3 as priority, 0 as status_sort, (select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id order by status_date desc) as date_added, 'Completed' as status from CustomerFunnel f
	where customer_id = @Customer_ID
	and status = 'C'
	order by priority, status_sort, date_added, project_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_projects] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_projects] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_projects] TO [EQAI]
    AS [dbo];

