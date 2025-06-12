USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Sfdc_sitechange_generatoraudit]    Script Date: 1/9/2025 8:49:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure [dbo].[sp_Sfdc_sitechange_generatoraudit]
						@generator_id int,
						@salesforce_site_CSID varchar(18),
						@gen_status char(1)=null,		
						@generator_name varchar(75)=null,	
						@generator_address_1 varchar(85),
						@generator_address_2 varchar(40)=null,
						@generator_address_3 varchar(40)=null,
						@generator_address_4 varchar(40)=null,
						@generator_address_5 varchar(40)=null,
						@generator_city varchar(40)=null,	
						@generator_state varchar(2)=null,	
						@generator_zip_code varchar(15)=null,
						@generator_county int,
						@generator_country varchar(3)=null,	
						@generator_phone varchar(10)=null,	
						@generator_fax varchar(10)=null,
						@gen_mail_name varchar(75)=null,
						@gen_mail_addr1 varchar(85)=null,	
						@gen_mail_addr2 varchar(40)=null,
						@gen_mail_addr3 varchar(40)=null,
						@gen_mail_addr4 varchar(40)=null,
						@gen_mail_addr5 varchar(40)=null,
						@gen_mail_city varchar(40)=null,
						@gen_mail_state char(2)=null,
						@gen_mail_zip_code varchar(15)=null,	
						@gen_mail_country varchar(3)=null,							
						@NAICS_code int=null,
						@user_code varchar(10)=null

/*
Description: 

Whenever generator records modified in generator table, Generator Audit records will be inserted for the respective generator id in the GeneratorAudit.

Revision History:

Rally#US117391 : Nagaraj M Intial Creation
US#DE34626  -- 07/18/2024 Nagaraj added logic to capture the audit
US#120475  -- 07/24/2024 Handled the empty string during comparision
US#131404  - 01/09/2025 Venu added generator id in where class update script

EXEC dbo.sp_Sfdc_generatoraudit_update
@generator_id =358423,
@salesforce_site_CSID='a1VW4000000bpoLMAQ',
@gen_status='A',
@generator_name = 'TEST HOUSE2',
@generator_address_1 = '25000 CLUBHOUSE DR3',
@generator_address_2= '',
@generator_address_3='',
@generator_address_4='',
@generator_address_5='',
@generator_city = 'MIDDLETOWN',
@generator_state='',    
@generator_zip_code='07748-1305',  
--@generator_county=99,
@generator_country='USA',
@generator_phone= '7327708029',    
@generator_FAX= '', 
@gen_mail_name = '',
@gen_mail_addr1 = '25000 CLUBHOUSE DR2',
@gen_mail_addr2 = '',
@gen_mail_addr3 = '',
@gen_mail_addr4 = '',
@gen_mail_addr5 = '',
@gen_mail_city = 'ROCHESTER',
@gen_mail_state = 'MI',
@gen_mail_zip_code = '48307',
@gen_mail_country = 'USA',
@NAICS_code = 111110,
@user_code='NAGARAJM'

*/
AS
Begin

declare 
@gen_status_old char(1),
@generator_name_old varchar(75),	
@generator_address_1_old varchar(85),
@generator_address_2_old  varchar(40)=null,
@generator_address_3_old  varchar(40)=null,
@generator_address_4_old  varchar(40)=null,
@generator_address_5_old  varchar(40)=null,
@generator_city_old  varchar(40),	
@generator_state_old  varchar(2),	
@generator_zip_code_old  varchar(15),
@generator_county_old  int,
@generator_country_old varchar(3),	
@generator_phone_old varchar(10),	
@generator_fax_old varchar(10)=null,
@gen_mail_name_old varchar(75),
@gen_mail_addr1_old varchar(85),	
@gen_mail_addr2_old varchar(40)=null,
@gen_mail_addr3_old varchar(40)=null,
@gen_mail_addr4_old varchar(40)=null,
@gen_mail_addr5_old varchar(40)=null,
@gen_mail_city_old varchar(40)=null,
@gen_mail_state_old char(2)=null,
@gen_mail_zip_code_old varchar(15)=null,	
@gen_mail_country_old varchar(3)=null,
@NAICS_code_old int =null,
@gen_old varchar(100)=null,
@gen_new varchar(100)=null,
@column_name varchar(100)=null,
@key_value nvarchar(4000)=null,
@source_system varchar(100)='Sales Force',
@audit_reference varchar(100)=null

set @audit_reference= 'generator_id: ' +TRIM(STR(@generator_id))

select @generator_address_1_old=generator_address_1,
@generator_address_2_old=generator_address_2,
@generator_address_3_old=generator_address_3,
@generator_address_4_old=generator_address_4,
@generator_address_5_old=generator_address_5,
@generator_city_old=generator_city,
@generator_state_old=generator_state,
@generator_zip_code_old=generator_zip_code,
@generator_county_old=generator_county,
@generator_country_old=generator_country,
@generator_phone_old=generator_phone,
@generator_fax_old=generator_fax,
@gen_mail_name_old=gen_mail_name,
@gen_mail_addr1_old=gen_mail_addr1,
@gen_mail_addr2_old=gen_mail_addr2,
@gen_mail_addr3_old=gen_mail_addr3,
@gen_mail_addr4_old=gen_mail_addr4,
@gen_mail_addr5_old=gen_mail_addr5,
@gen_mail_city_old=gen_mail_city,
@gen_mail_state_old=gen_mail_state,
@gen_mail_zip_code_old=gen_mail_zip_code,
@gen_mail_country_old=gen_mail_country,
@NAICS_code_old=NAICS_code,
@generator_name_old=generator_name,
@gen_status_old=status
from generator
where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid
	


								Set @key_value =	
								' generator_name;' + isnull(@generator_name, '') + 
								' generator_address_1;' + isnull(@generator_address_1, '') + 
								' generator_address_2;' + isnull(@generator_address_2,'') + 
								' generator_address_3;' +  isnull(@generator_address_3,'') + 
								' generator_address_4;' + isnull(@generator_address_4,'') + 
								' generator_address_5;' + isnull(@generator_address_5,'') + 
								' generator_phone;' + isnull(@generator_phone,'') + 
								' generator_city;' + isnull(@generator_city,'') + 
								' generator_state;' + isnull(@generator_state,'') + 
								' generator_zip_code;' + isnull(@generator_zip_code,'') + 
								' generator_country;' + isnull(@generator_country,'') +
								' generator_county;' + isnull(STR(@generator_county),'') +
								' generator_fax;' + isnull(@generator_fax,'') +  
								' gen_mail_name;' + isnull(@gen_mail_name, '') + 
								' gen_mail_addr1;' + isnull(@gen_mail_addr1, '') + 
								' gen_mail_addr2;' + isnull(@gen_mail_addr2,'') + 
								' gen_mail_addr3;' +  isnull(@gen_mail_addr3,'') + 
								' gen_mail_addr4;' + isnull(@gen_mail_addr4,'') + 
								' gen_mail_addr5;' + isnull(@gen_mail_addr5,'') + 
								' gen_mail_city;' + isnull(@gen_mail_city,'') + 
								' gen_mail_state;' + isnull(@gen_mail_state,'') + 
								' gen_mail_zip_code;' + isnull(@gen_mail_zip_code,'') + 
								' gen_mail_country;' + isnull(@gen_mail_country,'') + 					 
								' NAICS_code;' + isnull(STR(@NAICS_code), '') +
								' status:' + isnull(@gen_status,'') +
								' generator_id;' + isnull(STR(@generator_id),'') 
								
								

Select @source_system = 'sp_Sfdc_sitechange_generatoraudit: ' + @source_system

Create table #temp_salesforce_generator_fields (column_name varchar(100),generator_old_value varchar(100),generator_new_value varchar(100))  /*To determine the validation requried field*/

Insert into  #temp_salesforce_generator_fields (column_name,generator_old_value,generator_new_value) values 
																 ('status',@gen_status_old,@gen_status),
																 ('generator_address_1',@generator_address_1_old,@generator_address_1),
																 ('generator_address_2',@generator_address_2_old,@generator_address_2),
																 ('generator_address_3',@generator_address_3_old,@generator_address_3),
																 ('generator_address_4',@generator_address_4_old,@generator_address_4),
																 ('generator_address_5',@generator_address_5_old,@generator_address_5),
																 ('generator_city',@generator_city_old,@generator_city),
																 ('generator_state',@generator_state_old,@generator_state),
																 ('generator_zip_code',@generator_zip_code_old,@generator_zip_code),
																 ('generator_country',@generator_country_old,@generator_country),
																 ('generator_county',STR(@generator_county_old),STR(@generator_county)),
																 ('generator_phone',@generator_phone_old,@generator_phone),
																 ('generator_fax',@generator_fax_old,@generator_fax),
																 ('gen_mail_name',@gen_mail_name_old,@gen_mail_name),
																 ('gen_mail_addr1',@gen_mail_addr1_old,@gen_mail_addr1),
																 ('gen_mail_addr2',@gen_mail_addr2_old,@gen_mail_addr2),
																 ('gen_mail_addr3',@gen_mail_addr3_old,@gen_mail_addr3),
																 ('gen_mail_addr4',@gen_mail_addr4_old,@gen_mail_addr4),
																 ('gen_mail_addr5',@gen_mail_addr5_old,@gen_mail_addr5),
																 ('gen_mail_city',@gen_mail_city_old,@gen_mail_city),
																 ('gen_mail_state',@gen_mail_state_old,@gen_mail_state),
																 ('gen_mail_zip_code',@gen_mail_zip_code_old,@gen_mail_zip_code),
																 ('gen_mail_country',@gen_mail_country_old,@gen_mail_country),
																 ('NAICS_code',STR(@NAICS_code_old),STR(@NAICS_code)),
																 ('generator_name',@generator_name_old,@generator_name)
													



	Begin
			  UPDATE Generator SET 
			  generator_name=@generator_name ,
			  generator_address_1=@generator_address_1,
			  generator_address_2=@generator_address_2,
			  generator_address_3=@generator_address_3,
			  generator_address_4=@generator_address_4,
			  generator_address_5=@generator_address_5,
			  generator_city=@generator_city,
			  generator_state=@generator_state,
			  generator_zip_code=@generator_zip_code,
			  generator_county=@generator_county,
			  generator_country=@generator_country,
			  generator_phone=@generator_phone,
			  generator_fax=@generator_fax,
			  gen_mail_name=@gen_mail_name,
			  gen_mail_addr1=@gen_mail_addr1,
			  gen_mail_addr2=@gen_mail_addr2,
			  gen_mail_addr3=@gen_mail_addr3,
			  gen_mail_addr4=@gen_mail_addr4,
			  gen_mail_addr5=@gen_mail_addr5,
			  gen_mail_city=@gen_mail_city,
			  gen_mail_state=@gen_mail_state,
			  gen_mail_zip_code=@gen_mail_zip_code,
			  gen_mail_country=@gen_mail_country,
			  NAICS_code=@NAICS_code,
			  modified_by=@user_code,
			  date_modified=getdate(),
			  status=@gen_status
			  where (salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid or generator_id=@generator_id) and
			   ( 
				ISNULL(NULLIF(generator_name, 'NA'), '') <> ISNULL(NULLIF(@generator_name, 'NA'), '') or
				ISNULL(NULLIF(generator_address_1, 'NA'), '') <> ISNULL(NULLIF(@generator_address_1, 'NA'), '') or
				ISNULL(NULLIF(generator_address_2, 'NA'), '') <> ISNULL(NULLIF(@generator_address_2, 'NA'), '') or
				ISNULL(NULLIF(generator_address_3, 'NA'), '') <> ISNULL(NULLIF(@generator_address_3, 'NA'), '') or
				ISNULL(NULLIF(generator_address_4, 'NA'), '') <> ISNULL(NULLIF(@generator_address_4, 'NA'), '') or
				ISNULL(NULLIF(generator_address_5, 'NA'), '') <> ISNULL(NULLIF(@generator_address_5, 'NA'), '') or
				ISNULL(NULLIF(generator_city, 'NA'), '') <> ISNULL(NULLIF(@generator_city, 'NA'), '') or
				ISNULL(NULLIF(generator_state, 'NA'), '') <> ISNULL(NULLIF(@generator_state, 'NA'), '') or
				ISNULL(NULLIF(generator_zip_code, 'NA'), '') <> ISNULL(NULLIF(@generator_zip_code, 'NA'), '') or
				ISNULL(NULLIF(str(generator_county), 'NA'), '') <> ISNULL(NULLIF(str(@generator_county), 'NA'), '') or
				ISNULL(NULLIF(generator_country, 'NA'), '') <> ISNULL(NULLIF(@generator_country, 'NA'), '') or
				ISNULL(NULLIF(generator_phone, 'NA'), '') <> ISNULL(NULLIF(@generator_phone, 'NA'), '') or
				ISNULL(NULLIF(generator_fax, 'NA'), '') <> ISNULL(NULLIF(@generator_fax, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_name, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_name, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_addr1, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_addr1, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_addr2, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_addr2, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_addr3, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_addr3, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_addr4, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_addr4, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_addr5, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_addr5, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_city, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_city, 'NA'), '') or	 
				ISNULL(NULLIF(gen_mail_state, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_state, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_zip_code, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_zip_code, 'NA'), '') or
				ISNULL(NULLIF(gen_mail_country, 'NA'), '') <> ISNULL(NULLIF(@gen_mail_country, 'NA'), '') or
				ISNULL(NULLIF(str(NAICS_code), 'NA'), '') <> ISNULL(NULLIF(str(@NAICS_code), 'NA'), '')
				) 
			
			if @@error <> 0 OR @@rowcount=0				
			Begin				
				return -1
			End  
	End
				
				
	Declare sf_generator_update cursor fast_forward for 
	Select column_name,generator_old_value,generator_new_value  from #temp_salesforce_generator_fields
	Open sf_generator_update
	fetch next from sf_generator_update into @column_name,@gen_old,@gen_new
	While @@fetch_status=0
	Begin	
			
			if ISNULL(NULLIF(@gen_old, 'NA'), '') <> ISNULL(NULLIF(@gen_new, 'NA'), '')
			Begin
		
				INSERT INTO [dbo].GeneratorAudit (generator_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
												   modified_by,date_modified)
												  SELECT  @generator_id,'Generator',@COLUMN_NAME,(@gen_old),(@gen_new),@audit_reference,
														  'Salesforce',
														   @user_code,
														   GETDATE()
				if @@error <> 0 						
				Begin
				  return -2
				End
			End
        
		Fetch next from sf_generator_update into @column_name,@gen_old,@gen_new
	End
	Close sf_generator_update
	DEALLOCATE sf_generator_update 
	Drop table #temp_salesforce_generator_fields
Return 0
End

GO



GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generatoraudit_insert] TO EQAI  

Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generatoraudit_insert] TO COR_USER

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generatoraudit_insert] TO svc_CORAppUser

GO