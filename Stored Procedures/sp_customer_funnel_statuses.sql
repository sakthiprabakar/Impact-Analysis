
/***************************************************************************************
Retrieves the list of possible status codes for a funnel entry

10/08/2003 JPB	Created
Test Cmd Line: sp_customer_funnel_statuses
****************************************************************************************/
create procedure sp_customer_funnel_statuses
AS
	select status_code, status_text from FunnelStatus
	order by status_sort

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_statuses] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_statuses] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_funnel_statuses] TO [EQAI]
    AS [dbo];

