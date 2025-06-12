-- drop proc if exists sp_COR_Customer_Billing_Project_list 
go

create proc sp_COR_Customer_Billing_Project_list (
	@web_userid		varchar(100)	-- ignored in this case, we're not limiting to assigned customers.
	, @customer_id	int
)
as
/* ******************************************************************
Customer Billing Project List


sp_COR_Customer_Billing_Project_list @web_userid = '', @customer_id = 888880

****************************************************************** */
BEGIN

select customer_id, billing_project_id, project_name
from CustomerBilling
WHERE customer_id = @customer_id
and status = 'A'
order by (case when retail_flag in ('T', 'A') then 0 else 1 end), billing_project_id


END
GO

GRANT EXECUTE on sp_COR_Customer_Billing_Project_list to eqweb, eqai, COR_USER
GO
