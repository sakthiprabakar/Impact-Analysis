-- drop proc sp_COR_Get_RoutingEmail
go

CREATE PROCEDURE [dbo].[sp_COR_Get_RoutingEmail]
	@web_userid NVARCHAR(100),
	@form_id INT,
	@revision_id INT
AS

/* 
	 Author:		Dineshkumar
	 Create date:	9th October 2019
	 Description:	Routing Email list for the Form

	 Exec [sp_COR_Get_RoutingEmail] 'iceman', 527026 , 1
	 exec sp_COR_get_USE_notification_emails 651594 , 1

	 4/30/2020 Modified by Jonathan Broome to use FormWCRAssignment directly

*/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;



	select 
			w.form_id as FormId, 
			w.revision_id as RevisionId,  
			wcr.waste_common_name,
			contact.Name, 
			contact.first_name,
			contact.last_name,
			customer.cust_name as Customer, 
			customer.customer_ID as customer_id, 
			contact.Contact_id as ContactId, 
			contact.email as Email,
			pc.name as Facility, 
			contact.email as Recipients,
			'user' as [Type]
	FROM    FormWCRAssignments w
	LEFT JOIN formwcr wcr on wcr.form_id = w.form_id and wcr.revision_id = w.revision_id
	LEFT JOIN customer on w.customer_id = customer.customer_id
	LEFT JOIN use_profitcenter pc on w.company_id = pc.company_id and w.profit_ctr_id = pc.profit_ctr_id
	LEFT JOIN contact on web_userid = @web_userid
		and contact.contact_status ='A' and contact.web_access_flag in ('T', 'A')
	where w.form_id = @form_id
	and w.revision_id = @revision_id

	union

	select 
			w.form_id as FormId, 
			w.revision_id as RevisionId,  
			wcr.waste_common_name,

			(u.first_name + ' ' + u.last_name) as Name, 



			u.first_name as first_name,
			u.last_name as last_name,
			customer.cust_name as Customer, 

			customer.customer_ID as customer_id,

			contact.Contact_id as ContactId, 
			w.email as Email,
			pc.name as Facility, 
			isnull(u.email, 'customer.service@usecology.com') as Recipients,
			'CSS' as [Type]
	FROM    FormWCRAssignments w
	LEFT JOIN formwcr wcr on wcr.form_id = w.form_id and wcr.revision_id = w.revision_id
	LEFT JOIN customer on w.customer_id = customer.customer_id
	LEFT JOIN use_profitcenter pc on w.company_id = pc.company_id and w.profit_ctr_id = pc.profit_ctr_id
	LEFT JOIN contact on web_userid = @web_userid

		and contact.contact_status ='A' and contact.web_access_flag in ('T', 'A')
	left join users u on w.user_code = u.user_code
	where w.form_id = @form_id
	and w.revision_id = @revision_id


END



GO
	GRANT EXECUTE ON [dbo].[sp_COR_Get_RoutingEmail] TO COR_USER;
GO

