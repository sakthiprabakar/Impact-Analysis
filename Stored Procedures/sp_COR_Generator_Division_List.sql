USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS sp_COR_Generator_Division_List
GO 

CREATE  PROCEDURE sp_COR_Generator_Division_List
    @web_userid			varchar(100),
	@customer_id_list varchar(max)='', 
    @generator_id_list varchar(max)=''
AS
/* ****************************************************************
sp_COR_Generator_Division_List
 
sp_COR_Generator_Division_List @web_userid = 'nyswyn100'
 
**************************************************************** */
-- avoid query plan caching:

declare
    @i_web_userid			varchar(100) = isnull(@web_userid,''),
    @i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')


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
	, NAICS_description	varchar(275)
	, state_id	varchar(40)
	, emergency_phone_number varchar(40)
	, emergency_contract_number varchar(40)
	, generator_division varchar(40)
	, generator_district varchar(50)
	, generator_region_code varchar(40)
	, generator_status varchar(10)
	, [Internal reason Do Not Display] varchar(100)
	,_rowNumber int
)


insert @out
exec sp_COR_GeneratorSearch
	@web_userid		= @i_web_userid
	, @generator_id_list = @i_generator_id_list
	, @include_various	= 0 -- whether the Various generator (id 0) should be returned (default yes)
	, @include_inactive	= 1 -- whether inactive generators (status = I) should be returned (default yes)
	, @page			= 1
	, @perpage		= 9999999
	, @excel_output	= 1
	, @customer_id_list = @i_customer_id_list
	
select distinct Generator_Division from @out 
WHERE isnull(Generator_Division,'') <> ''
order by Generator_Division

RETURN 0

 
GO

GRANT EXECUTE ON sp_COR_Generator_Division_List TO COR_USER;

GO
