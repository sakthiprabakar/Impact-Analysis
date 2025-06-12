
create proc sp_TerminatedCustomerReport (
	@start_date		datetime,
	@end_date		datetime,
	@user_code		varchar(40) = null,-- HUB site security passes a value here, we don't need to use it though.
	@user_id		int = null,	-- same
	@contact_id		int = null,	-- same
	@permission_id	int = null	-- same
)
as
/* **********************************************************************************************
sp_TerminatedCustomerReport

	Lists customer accounts terminated in a date range.

Sample:

	sp_TerminatedCustomerReport	'1/1/2016', '8/24/2016'
	
History:

	8/24/2016 - Paul Kalinka scripted this.  JPB made it into an SP.  GEM:39189

********************************************************************************************** */

	-- Make sure end-date is inclusive (i.e. add 23:59 to the end if needed)
	if datepart(hh, @end_date) = 0 set @end_date= @end_date + 0.99999
		

	select 
		c.Customer_ID, 
		case c.Cust_Status when 'I' then 'Inactive (I)' when 'A' then 'Active (A)' else c.Cust_Status end Cust_Status, 
		c.Terms_Code, 
		c.Cust_Name, 
		ca.Column_Name, 
		ca.Before_Value, 
		ca.After_Value, 
		ca.Modified_By, 
		ca.Date_Modified, 
		cb.Region_ID, 
		cb.Collections_ID, 
		u2.user_name as 'Collector', 
		bs.Business_Segment_Code, 
		cbt.Customer_Billing_Territory_Code, 
		u.user_name as 'Segment AE'
	from customeraudit ca 
		join customer c on ca.customer_id = c.customer_id
		join customerbilling cb on ca.customer_id = cb.customer_id
		join customerbillingterritory cbt on ca.customer_id = cbt.customer_id and cbt.billing_project_id = 0
		join businesssegment bs on cbt.businesssegment_uid = bs.businesssegment_uid
		left outer join UsersXEQContact ux on cbt.customer_billing_territory_code = ux.territory_code and ux.EQcontact_type = 'AE'
		left outer join usersxeqcontact ux2 on cb.collections_id = ux2.type_id and ux2.EQcontact_type = 'Collections'
		left outer join users u on ux.user_code = u.user_code
		left outer join users u2 on ux2.user_code = u2.user_code

	where 
		ca.date_modified >= @start_date 
		and ca.date_modified <= @end_date 
		and cb.billing_project_id = 0
		and cbt.customer_billing_territory_status = 'A'
		and (c.cust_status = 'I' OR c.terms_code = 'NOADMIT')
		and (
				(ca.column_name = 'cust_status' and ca.after_value = 'I') OR (ca.column_name = 'terms_code' and ca.after_value = 'NOADMIT')
			)
		
	order by ca.date_modified desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_TerminatedCustomerReport] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_TerminatedCustomerReport] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_TerminatedCustomerReport] TO [EQAI]
    AS [dbo];

