-- drop proc if exists sp_COR_NAM_retail_contact
go

create proc sp_COR_NAM_retail_contact (
    @web_userid		varchar(100)
  , @customer_id_list varchar(max)=''
)
as
/* ****************************************************************************
sp_COR_NAM_retail_contact

Initial Creation - AM 10/23/2008 Devops:3491 - Retail Dashboard - US Ecology Contact Information

exec sp_COR_NAM_retail_contact 'nyswyn100','15551'
exec sp_COR_NAM_retail_contact 'court_c', '601113'
exec sp_COR_NAM_retail_contact 'zachery.wright'
exec sp_COR_NAM_retail_contact '',''

SELECT  *  FROM    users where user_code like 'amy_k%'

SELECT  * FROM    CustomerXUsers
SELECT  * FROM    customer WHERE customer_id = 602956


select web_userid , * from contact where contact_id = 185547
select * from ContactCORCustomerBucket where contact_id = 185547
select * from customer where customer_id = 15551   and LTRIM(RTRIM(cust_category)) = 'Retail'
select b.contact_id, cb.nam_id , cb.* from customerbilling cb
join contactcorCustomerbucket b on cb.customer_id = b.customer_id
WHERE b.contact_id in (185547, 123967)
where nam_id in (select type_id from usersxeqcontact where eqcontact_type = 'NAS' )
select * from usersxeqcontact where eqcontact_type = 'NAS' 

**************************************************************************** */
declare
		@i_web_userid	varchar(100)	= isnull(@web_userid, '')
	  , @i_customer_id_list	 varchar(max)= isnull(@customer_id_list, '')

declare @customer table (
customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

select
	'National Retail Contact Center' as Name
	, '' as contact_type	
	, '' as Services_Provided
	, '' as Email
	, '8669003762' as Office_Phone
	, '' as Cell_Phone
	, 0 as _order
union
SELECT  
	u.user_name as Name
	, ect.description as contact_type
	, cxu.services_provided_desc
	, isnull(cxu.email, u.email) as Email
	, isnull(cxu.office_phone, u.phone) as Office_Phone
	, isnull(cxu.cell_phone, u.cell_phone) as Cell_Phone
	, cxu.contact_order as _order

FROM  ContactCORCustomerBucket x (nolock) 
join CORContact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid 
join Customer cust (nolock) on x.customer_id = cust.customer_id
     and isnull(cust.retail_customer_flag, 'F') = 'T'
join CustomerXUsers cxu (nolock) on cust.customer_id = cxu.customer_id
	and status = 'A'
join Users u (nolock) on cxu.user_code = u.user_code and u.group_id <> 0
LEFT JOIN EQContactType ect on cxu.contact_type = ect.eqcontact_type

WHERE 
(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				x.customer_id in (select customer_id from @customer)
			)
		)
ORDER BY _order

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_NAM_retail_contact] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_NAM_retail_contact] TO [COR_USER]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_NAM_retail_contact] TO [EQAI]
    AS [dbo];

