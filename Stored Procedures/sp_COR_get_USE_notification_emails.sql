-- drop proc sp_COR_get_USE_notification_emails
go

create proc sp_COR_get_USE_notification_emails (
	@form_id		int = null
	, @revision_id	int = null
	, @profile_id	int = null
)
as
/* ***************************************************************************
sp_COR_get_USE_notification_emails

	DO Ticket 9411 logic

History:
4/7/2020 JPB	Created


Samples

	-- customer_id set on form, so get billing project customer service person
	select top 100 * from formwcr order by signing_date desc
	exec sp_COR_get_USE_notification_emails	504654,1 

	-- null customer_id on form, so you probably get defaults.
	select top 100 * from formwcr where customer_id is null order by signing_date desc
	exec sp_COR_get_USE_notification_emails	513142,1 
	
	
	exec sp_COR_get_USE_notification_emails	513685,1

*************************************************************************** */


declare	@i_form_id			int = @form_id
	, @i_revision_id		int = @revision_id
	, @i_profile_id			int = @profile_id
	, @i_customer_service_email	varchar(200) = 'customer.service@usecology.com'
	, @i_customer_id		int

declare @out table (
	email		varchar(200)
)

if @i_profile_id is not null begin
	select @i_customer_id = customer_id from profile where profile_id = @i_profile_id

	insert @out (email)
	select /* cb.customer_service_id, uxc.user_code, u.user_name, */ u.email
	from customerbilling cb 
	left outer join UsersXEQContact uxc 
		on uxc.EQcontact_type = 'CSR' and uxc.type_id = cb.customer_service_id
	left outer join users u
		on u.user_code = uxc.user_code
		and u.group_id <> 0
	where 
		cb.customer_id = @i_customer_id 
		and cb.billing_project_id = 0
		and @i_customer_id is not null

	if not exists (select * from @out)		
	insert @out (email) values (@i_customer_service_email)

end
else if @i_form_id is not null begin

	insert @out
	select email
	from FormWCRAssignments
	where form_id = @i_form_id
	and revision_id = @i_revision_id

end

if not exists (select * from @out)		
insert @out (email) values (@i_customer_service_email)

select * from @out

return 0
go
	
grant execute on sp_COR_get_USE_notification_emails to eqai
go
grant execute on sp_COR_get_USE_notification_emails to eqweb
go
grant execute on sp_COR_get_USE_notification_emails to cor_user
go
