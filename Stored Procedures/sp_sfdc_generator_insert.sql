USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_generator_insert]    Script Date: 5/20/2024 4:20:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[sp_sfdc_generator_insert]
(   @salesforce_site_csid varchar(18),
	@EPA_ID varchar(12),
	@generator_id int,
	@status char(1),		
	@generator_name varchar(75),	
	@generator_address_1 varchar(85),
	@generator_address_2 varchar(40)=null,
	@generator_address_3 varchar(40)=null,
	@generator_address_4 varchar(40)=null,
	@generator_address_5 varchar(40)=null,
	@generator_city varchar(40),	
	@generator_state varchar(2),	
	@generator_zip_code varchar(15),
	@generator_county int,
	@generator_country varchar(3),	
	@generator_phone varchar(10),	
	@generator_fax varchar(10)=null,
	@gen_mail_name varchar(75),
	@gen_mail_addr1 varchar(85),	
	@gen_mail_addr2 varchar(40)=null,
	@gen_mail_addr3 varchar(40)=null,
	@gen_mail_addr4 varchar(40)=null,
	@gen_mail_addr5 varchar(40)=null,
	@gen_mail_city varchar(40),
	@gen_mail_state char(2),
	@gen_mail_zip_code varchar(15),	
	@gen_mail_country varchar(3),	
	@NAICS_code int,
	@user_code varchar(10),
	@generator_result varchar(200) OUTPUT 
	)

/*

Description: 

API call will be made from salesforce team to Insert the Generator record in EQAI.

Revision History:

DevOps# 68929 -- 18/7/2023  Nagaraj M   Created
Devops# 70054 -- 8/9/2023 Venu Modified for genertor Integration from workorderquoteheader SP
Devops# 76705 -- 01/09/2024 Venu Modified the procedire - implement the salesforce site csid field as parameter
Devops# 76683 -- site location flag set as 'T'. If generator created via salesforce integaration then flag should be 'T'
Devops# 77458 -- 01/31/2024 Venu - Modified for the erorr handling messgae text change
Devops# 81419 -- 03/19/2024 Venu Populate the user_code to added_by and modified_by fields
Devops# 83351 -- 04/12/2024 Venu insert the generatorsalestax table entry
Devops# 83356 -- 04/15/2024 Nagaraj M Added @generator_county,generator_county field values to insert into the generator table.
Devops# 87927 -- 05/20/2024 Venu Modified the error handling.
Declare @LL_RET INT;
Declare @response varchar(200);
Exec @LL_RET = dbo.sp_sfdc_generator_insert
@EPA_ID = 'CRMTEST5678',
@generator_id='',
@status = 'A',
@generator_name = 'CRMTESTINSERTGENERATOR',
@generator_address_1 = '123 MAIN ST',
@generator_address_2 = null,
@generator_address_3 = null,
@generator_address_4 = null,
@generator_address_5 = null,
@generator_city = 'ROCHESTER',
@generator_state = 'MI',
@generator_zip_code = '48307',
@generator_country = 'USA',
@generator_phone = '2485551212',
@generator_fax = null,
@gen_mail_name = 'GENERATOR NAME',
@gen_mail_addr1 = '123 MAIN ST',
@gen_mail_addr2 = 'Test',
@gen_mail_addr3 = null,
@gen_mail_addr4 = null,
@gen_mail_addr5 = null,
@gen_mail_city = 'ROCHESTER',
@gen_mail_state = 'MI',
@gen_mail_zip_code = '48307',
@gen_mail_country = 'USA',
@NAICS_code = 111110,
@Generator_result =@response output
SELECT 'RETURN' = @LL_RET
SELECT @RESPONSE
*/
AS
declare 
	@eq_flag char(1) ='F',
	@outbound_restricted CHAR(1)='F',
	@manifest_waste_code_split_flag CHAR(1) ='T',
	@generator_knowledge_acceptable_flag CHAR(1) ='T',
	@foreign_generator_flag CHAR(1) = 'F',
	@mail_initial_manifest_flag CHAR(1) ='F',
	@mail_state_manifest_flag CHAR(1)='F',
	@industrial_flag CHAR(1)='F',
	@site_location_flag CHAR(1)='T',
	@Key_value nvarchar(max),
	@source_system varchar(500)='Sales Force',
	@ll_count_rec int,
	@ls_config_value char(1)='F',
	@flag char(1)='I',
	@sales_tax_id int,
	@ll_rec_cnt int
set transaction isolation level read uncommitted

BEGIN
begin transaction
	    Select @source_system = 'sp_sfdc_generator_insert:: ' + @source_system  
		select @Generator_result ='Generator Integration Successful'	

	    SELECT
		@key_value = 'salesforce_site_csid; ' + isnull(@salesforce_site_csid, '') +
		             ' EPA_ID; ' + isnull(@EPA_ID, '') +
					 ' generator_id;' + isnull(STR(@generator_id) ,'')+	
					 ' status;' + isnull(@status,'') +
					 ' generator_name;' + isnull(@generator_name,'') +
					 ' generator_address_1;' + isnull(@generator_address_1,'') +
					 ' generator_address_2;' + isnull(@generator_address_2,'') +
					 ' generator_address_3;' +  ISNULL(@generator_address_3,'') +
					 ' generator_address_4;' + ISNULL(@generator_address_4,'') +
					 ' generator_address_5;' + ISNULL(@generator_address_5,'') +
					 ' generator_city;' + ISNULL(@generator_city,'') +
					 ' generator_state;' + ISNULL(@generator_state,'') +
					 ' generator_zip_code;' + ISNULL(@generator_zip_code,'') +
					 ' generator_county;' + ISNULL(STR(@generator_county),'') +
					 ' generator_phone;' + ISNULL(@generator_phone,'') +
					 ' generator_fax;' + ISNULL(@generator_fax,'') +
					 ' gen_mail_name;' + ISNULL(@gen_mail_name,'') +
					 ' gen_mail_addr1;' + ISNULL(@gen_mail_addr1,'') +
					 ' gen_mail_addr2;' + ISNULL(@gen_mail_addr1,'') +
					 ' gen_mail_addr3;' + ISNULL(@gen_mail_addr1,'') +
					 ' gen_mail_addr4;' + ISNULL(@gen_mail_addr1,'') +
					 ' gen_mail_addr5;' + ISNULL(@gen_mail_addr1,'') +
					 ' gen_mail_city;' + ISNULL(@gen_mail_city,'') +	 
					 ' gen_mail_state;' + ISNULL(@gen_mail_state,'') +
					 ' gen_mail_zip_code;' + ISNULL(@gen_mail_zip_code,'') +
					 ' gen_mail_country;' + ISNULL(@gen_mail_country,'') +
					 ' NAICS_code;' + TRIM(STR(ISNULL(@NAICS_code,''))) +
					 ' user_code;' + ISNULL(@user_code,'') 
					 
   If @generator_state = 'NY'
   Begin

   select @ll_rec_cnt = count(*) from Zipcodes zc 
				  join salestax st 
  				  on zc.county_code = st.sales_tax_county_code
				  where zc.zipcode = @generator_zip_code
	   If @ll_rec_cnt > 0 
	   Begin

	   select Distinct @sales_tax_id=  sales_tax_id
							   from Zipcodes zc 
							   join salestax st 
  							   on zc.county_code = st.sales_tax_county_code
							   where zc.zipcode = @generator_zip_code
							   
	    Insert into GeneratorSalesTax
					(generator_id,
					sales_tax_id,
					tax_flag,
					sales_tax_exempt_id,
					added_by,
					date_added,
					modified_by,
					date_modified)
					Select
					@generator_id,
					@sales_tax_id,
					'T',
					Null,
					@user_code,
					getdate(),
					@user_code,
					getdate()		

					if @@error <> 0
					begin
					rollback transaction
					Set @Generator_result = 'Error: Integration failed due to the following reason; could not insert into GeneratorSalesTax (NY) table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
					Set @flag = 'E' 
   					INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   																SELECT
   																@key_value,
   																@source_system,
    															'Insert',
    															@Generator_result,
    															GETDATE(),
   																@user_code
						return -1
					end
	   End
	   If @ll_rec_cnt = 0 
	   Begin	   
	   Set @Generator_result = 'Salestax details not exist for the recevied Zipcode'	
	   Set @flag = 'E' 
	   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
							   SELECT 
							   @key_value, 
							   @source_system, 
							   'Insert', 
							   @Generator_result,
								GETDATE(), 
								@user_code 

		Commit Transaction	
	        
			Return -1
	   End
   End
   If @generator_state = 'CT'
   Begin

    select @ll_rec_cnt = count(*) from salestax st where st.sales_tax_state = 'CT'

	If @ll_rec_cnt > 0 
	Begin
	 select Distinct @sales_tax_id=  sales_tax_id from salestax st where st.sales_tax_state = 'CT'

	 Insert into GeneratorSalesTax
					(generator_id,
					sales_tax_id,
					tax_flag,
					sales_tax_exempt_id,
					added_by,
					date_added,
					modified_by,
					date_modified)
					Select
					@generator_id,
					@sales_tax_id,
					'T',
					Null,
					@user_code,
					getdate(),
					@user_code,
					getdate()		

					if @@error <> 0
					begin
					rollback transaction
					Set @Generator_result = 'Error: Integration failed due to the following reason; could not insert into GeneratorSalesTax (CT) table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
					Set @flag = 'E' 
   					INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   																SELECT
   																@key_value,
   																@source_system,
    															'Insert',
    															@Generator_result,
    															GETDATE(),
   																@user_code
						return -1
					end

	   End
	   If @ll_rec_cnt = 0 
	   Begin
	   Set @Generator_result = 'Salestax details not exist for the generator state CT'
	   Set @flag = 'E' 
	   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
							   SELECT 
							   @key_value, 
							   @source_system, 
							   'Insert', 
							   @Generator_result,
								GETDATE(), 
								@user_code 			
	        Commit Transaction
			Return -1
	   End

	End
	    
  IF @flag <> 'E' 
	Begin
		  Insert Generator (
							generator_id,
							EPA_ID, 
							status, 
							generator_name, 
							generator_address_1, 
							generator_address_2, 
							generator_address_3, 
							generator_address_4, 
							generator_address_5, 
							generator_city, 
							generator_state,
							generator_zip_code,
							generator_county,
							generator_country, 
							generator_phone, 
							generator_fax, 
							gen_mail_name,
							gen_mail_addr1, 
							gen_mail_addr2, 
							gen_mail_addr3, 
							gen_mail_addr4, 
							gen_mail_addr5, 
							gen_mail_city, 
							gen_mail_state, 
							gen_mail_zip_code, 
							gen_mail_country,
							NAICS_code,
							eq_flag, 
							outbound_restricted,
							manifest_waste_code_split_flag,
							generator_knowledge_acceptable_flag,
							foreign_generator_flag,
							mail_initial_manifest_flag,
							mail_state_manifest_flag,
							industrial_flag, 
							site_location_flag, 
							salesforce_site_csid,
							added_by,
							date_added,
							modified_by,
							date_modified)
							values (
							@generator_id,
							@EPA_ID,
							@status,
							@generator_name,
							@generator_address_1,
							@generator_address_2,
							@generator_address_3,
							@generator_address_4,
							@generator_address_5,
							@generator_city,
							@generator_state,
							@generator_zip_code,
							@generator_county,
							@generator_country,
							@generator_phone,
							@generator_fax,
							@gen_mail_name,
							@gen_mail_addr1,
							@gen_mail_addr2,
							@gen_mail_addr3,
							@gen_mail_addr4,
							@gen_mail_addr5,
							@gen_mail_city,
							@gen_mail_state,
							@gen_mail_zip_code,
							@gen_mail_country,
							@NAICS_code,
							@eq_flag,
							@outbound_restricted,
							@manifest_waste_code_split_flag,
							@generator_knowledge_acceptable_flag,
							@foreign_generator_flag,
							@mail_initial_manifest_flag,
							@mail_state_manifest_flag,
							@industrial_flag,
							@site_location_flag,
							@salesforce_site_csid,
							@user_code,
							GETDATE(),
							@user_code,
							GETDATE())


							if @@error <> 0
							begin
							rollback transaction
							SELECT @Generator_result = 'Error: Integration failed due to the following reason; could not insert into Generator table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
   									INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   																		SELECT
   																		@key_value,
   																		@source_system,
    																	'Insert',
    																	@Generator_result,
    																	GETDATE(),
   																		@user_code
								return -1
							end       
				
		End
--------------------
--COMMIT TRANSACTION
	--------------------
commit transaction

If @flag='E'
Begin   
   Return -1
End
If @flag='I'
Begin   
   Return 0
End
Return 0
End

Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generator_insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generator_insert] TO COR_USER

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generator_insert] TO svc_CORAppUser

GO
