 -- drop proc [sp_COR_GeneratorSiteTypeList]
 go

CREATE  proc [dbo].[sp_COR_GeneratorSiteTypeList] (
	@web_userid varchar(100)
  , @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
  , @generator_id_list varchar(max)='' /* Added 2019-07-17 by AA */

)
as
/* ******************************************************************
Generator SiteType LIst

10/14/2019 MPM  DevOps 11574: Added logic to filter the result set
				using optional input parameter @generator_id_list.
inputs 
	
	Web User ID

Returns

	Distinct Generator SiteType values available to the user

Samples:
exec sp_COR_GeneratorSiteTypeList 'vscheerer'
exec sp_COR_GeneratorSiteTypeList 'nyswyn100', @customer_id_list  = '15551'
exec sp_COR_GeneratorSiteTypeList 'zachery.wright'
exec sp_COR_GeneratorSiteTypeList 'customer.demo@usecology.com'
exec sp_COR_GeneratorSiteTypeList 'nyswyn125', '', '151057'
exec sp_COR_GeneratorSiteTypeList 'nyswyn125' 

exec sp_COR_GeneratorSearch @web_userid = 'nyswyn100', @include_various = 0, @excel_output = 1

sp_columns generator

SELECT  *  FROM    sysobjects where name like '%SiteType%'

select distinct x.contact_id, c.web_userid, g.site_type from generator g
join ContactCorGeneratorBucket x on g.generator_id = x.generator_id
join contact c on x.contact_id = c.contact_id
WHERE x.contact_id in (select contact_id from contact where web_userid <> 'paul.kalinka@usecology.com')



****************************************************************** */

-- Avoid query plan caching:
declare @i_web_userid		varchar(100) = @web_userid
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')

declare @out table (
	generator_id	int
	, generator_name	varchar(80)
	, epa_id		varchar(20)
	, site_code		varchar(16)
	,generator_address_1	varchar(85)
	,generator_address_2	varchar(85)
	,generator_address_3	varchar(85)
	,generator_address_4	varchar(85)
	,generator_address_5	varchar(85)
	,generator_address varchar(max)
	, generator_phone	varchar(20)
	, generator_state	varchar(2)
	, generator_country	varchar(3)
	, generator_city	varchar(85)
	, generator_zip_code	varchar(85)
	, gen_mail_addr1	varchar(85)
	, gen_mail_addr2	varchar(85)
	, gen_mail_addr3	varchar(85)
	, gen_mail_addr4	varchar(85)
	, gen_mail_addr5	varchar(85)
	, gen_mail_addr		varchar(max)
	, gen_mail_city	varchar(85)
	, gen_mail_state	varchar(85)
	, gen_mail_zip_code	varchar(85)
	, gen_mail_country	varchar(85)
	, generator_type_ID	int
	, generator_type	varchar(20)
	, NAICS_code	int
	, NAICS_description	varchar(255)
	, state_id	varchar(40)
	, emergency_phone_number varchar(40)
	, emergency_contract_number varchar(40)
	, generator_division varchar(40)
	, generator_district varchar(40)
	, generator_region_code varchar(40)
	, generator_status varchar(10)
	, [Internal reason Do Not Display] varchar(100)
	,_rowNumber int
)



insert @out
exec [sp_COR_GeneratorSearch]
	@web_userid		= @i_web_userid
	, @include_various	= 0 -- whether the Various generator (id 0) should be returned (default yes)
	, @customer_id_list = @i_customer_id_list
	, @generator_id_list = @i_generator_id_list
	, @excel_output = 1


select distinct g.site_type from @out o
join generator g (nolock) on o.generator_id = g.generator_id
WHERE g.site_type is not null
order by g.site_type

RETURN 0

GO

GRANT EXECUTE ON [dbo].[sp_COR_GeneratorSiteTypeList] TO COR_USER;

GO

