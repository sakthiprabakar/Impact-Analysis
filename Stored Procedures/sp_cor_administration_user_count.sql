USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_cor_administration_user_count]
GO
CREATE PROCEDURE [dbo].[sp_cor_administration_user_count] (
	@web_userid varchar(100)
	, @role		varchar(max) = null
	, @search	varchar(100) = null
	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status', 'Contact Company'
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @customer_id_list varchar(max)=''  /* Added 2019-07-11 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-11 by AA */
    , @active_flag	char(1) = 'A'	/* 'A'ctive users, 'I'nactive users, 'X' all users.   */
	, @search_type nvarchar(100) = ''
	, @search_contact_id int = 0
	, @search_name nvarchar(200) = ''
	, @search_email nvarchar(150) = ''
	, @search_first_name nvarchar(100) = ''
	, @search_last_name nvarchar(100) = ''
	, @search_title nvarchar(150) = ''
	, @search_phone nvarchar(20) = ''
	, @search_fax nvarchar(20) = ''
	, @search_contact_country nvarchar(100) = ''
	, @search_contact_zip_code nvarchar(100) = ''
	, @search_contact_state nvarchar(100) = ''
	, @search_contact_addr1 nvarchar(100) = ''
	, @search_contact_city nvarchar(100) = ''
	, @search_contact_company nvarchar(150) = ''
	, @search_contact_addr2 nvarchar(100) = ''
	, @search_contact_addr3 nvarchar(100) = ''
	, @search_contact_addr4 nvarchar(100) = ''
	, @search_mobile nvarchar(100) = ''
	, @search_web_userid nvarchar(150) = ''
)
as
/* *****************************************************************
sp_cor_administration_user_count 

List the users that the current @web_userid can admin.

sp_cor_administration_user_count 
-- sp_cor_administration_user_list
	@web_userid = 'akalinka'
	, @role = '' -- 'Administration'
	, @search = '' -- 'bram'
	, @sort = 'email'
	, @page = 1
	, @perpage = 99999
	, @active_flag = 'A'
	, @search_first_name = ''
	, @search_last_name = ''
	, @search_contact_zip_code = '00'
	
***************************************************************** */

-- Avoid query plan caching and handle nulls
	declare 
	@i_web_userid	varchar(100) = isnull(@web_userid, '')
	, @i_role		varchar(max) = isnull(@role, '')
	, @i_search		varchar(100) = isnull(@search, '')
	, @i_sort		varchar(20) = isnull(@sort, '')
	, @i_page		bigint = isnull(@page, 1 )
	, @i_perpage	bigint = isnull(@perpage, 20)
	, @i_customer_id_list varchar(max) = isnull(@customer_id_list, '')
	, @i_generator_id_list varchar(max) = isnull(@generator_id_list, '')
	, @i_active_flag char(1) = isnull(@active_flag, 'A')
	, @i_search_type nvarchar(100) = isnull(@search_type, '')
	, @i_search_contact_id int =  isnull(@search_contact_id,0)
	, @i_search_name nvarchar(200) =  isnull(@search_name, '')
	, @i_search_email nvarchar(150) = isnull(@search_email, '')
	, @i_search_first_name nvarchar(100) = isnull(@search_first_name, '')
	, @i_search_last_name nvarchar(100) = isnull(@search_last_name, '')
	, @i_search_title nvarchar(150) = isnull(@search_title, '')
	, @i_search_phone nvarchar(20) = isnull(@search_phone, '')
	, @i_search_fax nvarchar(20) = isnull(@search_fax, '')
	, @i_search_contact_country nvarchar(100) = isnull(@search_contact_country, '')
	, @i_search_contact_zip_code nvarchar(100) = isnull(@search_contact_zip_code, '')
	, @i_search_contact_state nvarchar(100) = isnull(@search_contact_state, '')
	, @i_search_contact_addr1 nvarchar(100) = isnull(@search_contact_addr1, '')
	, @i_search_contact_city nvarchar(100) = isnull(@search_contact_city, '')
	, @i_search_contact_company nvarchar(150) = isnull(@search_contact_company, '')
	, @i_search_contact_addr2 nvarchar(100) = isnull(@search_contact_addr2, '')
	, @i_search_contact_addr3 nvarchar(100) = isnull(@search_contact_addr3, '')
	, @i_search_contact_addr4 nvarchar(100) = isnull(@search_contact_addr4, '')
	, @i_search_mobile nvarchar(100) = isnull(@search_mobile, '')
	, @i_search_web_userid nvarchar(150) = isnull(@search_web_userid, '')


declare @out table (
	type	varchar(40)
	, contact_id	int
	, name			varchar(40)
	, email			varchar(60)
	, first_name	varchar(20)
	, last_name		varchar(20)
	, title			varchar(35)
	, phone			varchar(20)
	, fax			varchar(20)
	, contact_country	varchar(40)
	, contact_zip_code	varchar(15)
	, contact_state	varchar(2)
	, contact_addr1	varchar(40)
	, contact_city	varchar(40)
	, contact_company varchar(75)
	, contact_addr2	varchar(40)
	, contact_addr3	varchar(40)
	, contact_addr4	varchar(40)
	, mobile varchar(10)
	, web_userid		varchar(100)
	, status	char(1)
	, IsInternalUser bit
    , _row int
)




insert @out
exec sp_cor_administration_user_list
	@web_userid = @i_web_userid
	, @role		= @i_role
	, @search	= @i_search
	, @sort		= @i_sort
	, @page		= 1
	, @perpage	= 999999999
	, @customer_id_list = @i_customer_id_list
	, @generator_id_list  = @i_generator_id_list
    , @active_flag = @i_active_flag
	, @search_type = @i_search_type
	, @search_contact_id = @i_search_contact_id
	, @search_name = @i_search_name
	, @search_email = @i_search_email
	, @search_first_name = @i_search_first_name
	, @search_last_name = @i_search_last_name
	, @search_title = @i_search_title
	, @search_phone = @i_search_phone
	, @search_fax = @i_search_fax
	, @search_contact_country = @i_search_contact_country
	, @search_contact_zip_code = @i_search_contact_zip_code
	, @search_contact_state = @i_search_contact_state
	, @search_contact_addr1 = @i_search_contact_addr1
	, @search_contact_city = @i_search_contact_city
	, @search_contact_company = @i_search_contact_company
	, @search_contact_addr2 = @i_search_contact_addr2
	, @search_contact_addr3 = @i_search_contact_addr3
	, @search_contact_addr4 = @i_search_contact_addr4
	, @search_mobile = @i_search_mobile
	, @search_web_userid = @i_search_web_userid


select count(*) from @out

return 0


go

	grant execute on sp_cor_administration_user_count to eqweb, eqai, COR_USER

go

