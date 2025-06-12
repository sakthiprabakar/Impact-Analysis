-- drop proc sp_COR_Generator_Details
go

CREATE proc [dbo].[sp_COR_Generator_Details] (
	
	  @generator_id			int = null
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
)
as
/* ******************************************************************
sp_COR_Generator_Details

inputs 
	
	Web User ID
	Generator Name

Returns

	Generator Name
	Generator Address Lines
	City
	State
	Zip
	Country
	Contact?
	Phone?
	Email?

Samples:
exec sp_COR_GeneratorSearch 'sam', null
exec sp_COR_GeneratorSearch 'nyswyn100',null,'sam','all',0,'City',1,2000

exec sp_COR_Generator_Details 176746
****************************************************************** */

--declare 
--	@web_userid		varchar(100)='nyswyn100'
--	, @generator_id			int = 176746

-- Avoid query plan caching:
declare
	 @i_generator_id		int = @generator_id
if @i_generator_id is null set @i_generator_id = -1

declare @foo table (Generator_id int,
_rowNumber int)



select
	g.Generator_id
	, g.generator_name
	, g.epa_id
	, g.generator_address_1
	, g.generator_address_2
	, g.generator_address_3
	, g.generator_address_4
	, g.generator_address_5
	, generator_phone
	, g.generator_state
	, g.generator_country
	, g.generator_city
	, g.generator_zip_code
	, gen_mail_addr1
	, gen_mail_addr2
	, gen_mail_addr3
	, gen_mail_addr4
	, gen_mail_addr5
	, gen_mail_city
	, gen_mail_state
	, gen_mail_zip_code
	, gen_mail_country
	,generator_type_id as generator_type_ID
	, NAICS_code,
	 (Select top 1 CAST(g.NAICS_code as NVARCHAR(15)) + '-' +[description] from  NAICSCode WHERE NAICS_code = g.NAICS_code) as description
	, state_id
	,emergency_phone_number as Emergency_Contact,
	CONCAT(ISNULL(gen_mail_addr1+', ',''),ISNULL(gen_mail_addr2+', ',''),ISNULL(gen_mail_addr3+', ',''),ISNULL(gen_mail_addr4+', ',''),ISNULL(gen_mail_addr5+', ','')
	) as Mailing_Address,
	'' as Contact_Information
	,'' as Customer_Certification
	,'' as Billing_Customer
	,'' as RCRA_Benzene_Status
	,'' as Attachment
	,'' as Profiles
	, ( select substring(
		(
		select ', ' + isnull(sdt.document_type + ': ', '') + coalesce(s.document_name, 'Document')+ '|'+coalesce(convert(varchar(3),s.page_number),'1') + '|'+ coalesce(s.file_type, '') + '|' + convert(Varchar(10), s.image_id)
		FROM plt_image..scan s (nolock)
		join plt_image..ScanDocumentType sdt (nolock) on s.type_id = sdt.type_id
		WHERE s.generator_id = g.generator_id
		and s.document_source = 'generator'
		and s.status = 'A'
		and s.view_on_web = 'T' 
		/*and s.type_id in (select type_id from plt_image..scandocumenttype where document_type = 'manifest')*/
		order by coalesce(s.document_name, 'Document'), s.page_number, s.image_id
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
	)  images
	
from Generator g 

WHERE generator_id=@generator_id
--order by g.generator_name

return 0

GO

grant execute on sp_cor_generator_details to eqweb, cor_user, eqai
go

