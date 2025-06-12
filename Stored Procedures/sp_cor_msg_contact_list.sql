-- drop proc sp_cor_msg_contact_list 
go

create proc sp_cor_msg_contact_list  (
	@web_userid		varchar(100)
	, @customer_id_list varchar(max)=''
    , @generator_id_list varchar(max)=''
)
as
/* ****************************************************************************
sp_cor_msg_contact_list 

6.3.3. COR2 MSG Dashboard à Account Contacts Box

6.3.3.1. For MSG customers, display the entire support team.

6.3.3.2. This should be a distinct list of the Operations Managers from the logged 
	in users’ customer list, the distinct list of Project Managers from the customer 
	and generators for the logged in users’ access and the distinct list of Program 
	Managers from the logged in users’ access.

6.3.3.2.1. Join to the Users table where the employee has valid system access (not 
	set to the 0 access group)

6.3.3.2.2. For each person, this would include their Name, Email, Photo, and Phone.

6.3.3.3. If any category does not have any users return from the search, don’t show 
	the label. For example, if the search results in no Operations Manager, then 
	don’t show the label for “Operations Manager”

6.3.3.4. If all categories for Operations Manager, Project Manager and Program Manager 
	do not have any users return from the search, don’t show the Account Contacts box at all.

sp_cor_msg_contact_list 
	@web_userid = 'jennifer.chopp'
	, @customer_id_list = '600273'

SELECT  *  FROM    customer where msg_customer_flag = 'T'
SELECT  *  FROM    MSGManagerType
SELECT  *  FROM    CustomerXMSGManager
SELECT  *  FROM    users where group_id = 1099
sp_columns CustomerXMSGManager

insert CustomerXMSGManager
select 15622, 'OPERATIONS', 'A', 'NYSWYN_J', 'SA', getdate(), 'SA', getdate()
union
select 15622, 'PROJECT', 'A', 'PAUL_K', 'SA', getdate(), 'SA', getdate()
union
select 15622, 'PROGRAM', 'A', 'JONATHAN', 'SA', getdate(), 'SA', getdate()
union
select 15622, 'PROGRAM', 'A', 'ZACHERY', 'SA', getdate(), 'SA', getdate()

**************************************************************************** */

/*
declare
	@web_userid varchar(100) = 'nyswyn100'
	, @customer_id_list varchar(max) = ''
	, @generator_id_list varchar(max) = '' -- '169109, 168770, 169225, 183049' 
*/


declare @i_contact_id	int
	, @i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_customer_id_list	varchar(max)	= isnull(@customer_id_list, '')
	, @i_generator_id_list	varchar(max)	= isnull(@generator_id_list, '')
	
select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null


-- Distinct list of Operations Managers, Project Managers and Program Managers from customer:
select distinct
	m.manager_desc
	, u.user_name
	, nullif(ltrim(rtrim(u.phone)), '') phone
	, lower(u.email) as email
from ContactCORCustomerBucket b
join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag ='T'
join CustomerXMSGManager x on b.customer_id = x.customer_id and x.status = 'A'
join MSGManagerType m on x.manager_type = m.manager_type
join Users u on x.user_code = u.user_code and u.group_id <> 0
where b.contact_id = @i_contact_id
and (
	@i_customer_id_list = ''
	or
	(
		b.customer_id in (select customer_id from @customer)
	)
)
and m.manager_desc in ('Operations Manager', 'Project Manager', 'Program Manager')
union
-- Distinct list of Project Managers from generators:
select distinct
	m.manager_desc
	, u.user_name
	, nullif(ltrim(rtrim(u.phone)), '') phone
	, lower(u.email) as email
from ContactCORGeneratorBucket b
join generator c on b.generator_id = c.generator_id and c.msg_generator_flag ='T'
join generatorXMSGManager x on b.generator_id = x.generator_id and x.status = 'A'
join MSGManagerType m on x.manager_type = m.manager_type
join Users u on x.user_code = u.user_code and u.group_id <> 0
where b.contact_id = @i_contact_id and b.direct_flag = 'D'
and (
	@i_generator_id_list = ''
	or
	(
		b.generator_id in (select generator_id from @generator)
	)
)
and m.manager_desc in ('Project Manager', 'Program Manager')
order by manager_desc, user_name


GO

GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_msg_contact_list  TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_msg_contact_list  TO [COR_USER]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_msg_contact_list  TO [EQAI]
    AS [dbo];

	