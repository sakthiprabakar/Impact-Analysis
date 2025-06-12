USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_generator_info_for_lookup]    Script Date: 2/3/2025 2:41:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

ALTER   PROC [dbo].[sp_sfdc_generator_info_for_lookup] 
(
					@epa_id varchar(12), 
					@generator_name varchar(75),
					@generator_address_1 varchar(85), 
					@generator_city varchar(40),
					@generator_zip_code varchar(15),
					@generator_state varchar(2),
					@OUTPUT VARCHAR(500) OUTPUT
) 
AS 
/*************************************************************************************************************
Description: 

EQAI Generator info for salesforce.

Revision History:

Devops 67333 -- Nagaraj M -- Initial Creation
Devops 67333 -- Nagaraj M -- Added the output parameter for the not valid scenario's
Devops 72044 -- Nagaraj M -- Removed the SOUNDEX function in the where clause of generator name.
Devops 71943 -- 08/29/2023 Nagaraj M Added generator_address_1 column for the resultant output,
and concatenated the all the address also.
Devops 72044 -- 09/07/2023 Nagaraj M -- Added order by for generator_name
Devops 77458 --01/31/2024 Venu - Modified for the erorr handling messgae text change
Rally #DE37105 --Nagaraj M -- Added generator_country in the sql query
Rally #US138825 -- Nagaraj M -- Added site_location_flag in the sql.

use plt_ai
go
Declare @response varchar(100)
exec dbo.sp_sfdc_generator_info_for_lookup 
@epa_id = '',
@generator_name = 'UNIVERSITY OF IOWA',
@generator_address_1 = '',
@generator_city = '',
@generator_zip_code ='',
@generator_state ='',
@output =@response output
print @response

***************************************************************************************************************/
DECLARE 
	@key_value nvarchar (4000),
	@ll_count_rec int,
	@EPA_ID_Y_N CHAR(1),
	@intAlpha INT,
	@strAlphaNumeric VARCHAR(100),
	@source_system varchar(500),
	--@output varchar(500),
	@ls_config_value char(1)='F'
BEGIN 
Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
IF @ls_config_value is null or @ls_config_value=''
    Select @ls_config_value='F'
End
BEGIN
If @ls_config_value='T'
BEGIN
	BEGIN TRY 
			SELECT @key_Value = 'EPA ID; ' + trim(ISNULL(@epa_id,'')) + 
			' generator_name; ' + trim(ISNULL(@generator_name,'')) +
			' generator_address_1; ' + trim(ISNULL(@generator_address_1,'')) + 
			' generator_city; ' + trim(ISNULL(@generator_city,'')) + 
			' generator_zip_code; ' + trim(ISNULL(@generator_zip_code,'')) + 
			' generator_state; ' + trim(ISNULL(@generator_state,'')) 
     
	SELECT  @ll_count_rec = COUNT(*) FROM generator 
			WHERE EPA_ID = @epa_id
			AND @epa_id <>' '
			AND LEN(@EPA_ID) = 12
			AND status='A'


	BEGIN
		IF @ll_count_rec >=1  SELECT @EPA_ID_Y_N = 'Y'
		IF @ll_count_rec = 0 SELECT @EPA_ID_Y_N = 'N'
	END

	IF (
		(@epa_id ='' or len(@EPA_ID) < 12 OR @ll_count_rec = 0 or len(@EPA_ID) > 12) 
		AND @generator_name ='' 
		AND @generator_address_1 ='' 
		AND @generator_city ='' 
		AND @generator_zip_code =''
		AND	@generator_state =''
		)
	
	BEGIN
		SELECT @OUTPUT = 'Error: Integration failed due to the following reason EPA ID:'+isnull(@epa_id,'N/A')+ ' is not valid or not exists , provide any of the other parameters to search.'
		SELECT @source_system = 'sp_sfdc_generator_info_for_lookup::Salesforce'

	INSERT INTO Plt_AI_Audit..
		Source_Error_Log (
		input_params,
		source_system_details, 
		action,
		Error_description,
		log_date, 
		Added_by
		) 
		SELECT 
		@key_value, 
		@source_system, 
		'Select', 
		@OUTPUT, 
		GETDATE(), 
		SUBSTRING(USER_NAME(),1,40) 
		
		SELECT @OUTPUT AS OUTPUT
		SELECT @EPA_ID_Y_N = 'O'
	END

	IF @EPA_ID_Y_N = 'Y' 
	BEGIN 
		SELECT 
		site_location_flag as [Site Location],
		generator_name as [Name],
		isnull(generator_address_1,'') + isnull(generator_address_2,'') + isnull(generator_address_3,'') + isnull(generator_address_4,'') + isnull(generator_address_5,'')  as [Street Address],
		generator_city as [City],
		generator_state as [State],
		generator_zip_code as [Zip], 
		EPA_ID as [EPA ID],
		generator_phone AS [Business Phone],
		NAICS_code AS [NAICS ID],
		generator_id [EQAI generator ID],
		generator_country as [Site Country]
		FROM 
		generator 
		WHERE EPA_ID = @epa_id and status='A'
	END 
	/*If (@generator_address_1 is not null or @generator_address_1 <>'')
		BEGIN
		SET @intAlpha = PATINDEX('%[^0-9]%', @generator_address_1)
		WHILE @intAlpha > 0
		BEGIN
		SET @generator_address_1 = STUFF(@generator_address_1, @intAlpha, 1, '' )
		SET @intAlpha = PATINDEX('%[^0-9]%', @generator_address_1 )
		END
	END*/
	IF @EPA_ID_Y_N = 'N' 
	BEGIN
	SELECT 
		site_location_flag as [Site Location],
		generator_name as [Name],
		isnull(generator_address_1,'') + isnull(generator_address_2,'') + isnull(generator_address_3,'') + isnull(generator_address_4,'') + isnull(generator_address_5,'')  as [Street Address],
		generator_city as [City],
		generator_state as [State],
		generator_zip_code as [Zip], 
		EPA_ID as [EPA ID],
		generator_phone AS [Business Phone],
		NAICS_code AS [NAICS ID],
		generator_id [EQAI generator ID],
		generator_country as [Site Country]
		FROM
		generator 
		WHERE
		1=1
		AND
		Status='A' AND
		/*SOUNDEX(generator_name) LIKE
 		CASE WHEN (@generator_name) <>'' THEN '%' + SOUNDEX(@generator_name) + '%' 
		ELSE SOUNDEX(generator_name)*/
		generator_name LIKE
 		CASE WHEN (@generator_name) <>'' THEN '%' + (@generator_name) + '%' 
		ELSE (generator_name)
		END 
		AND
		(generator_address_1 LIKE 
		CASE WHEN @generator_address_1 <>'' THEN '%' + (@generator_address_1)  + '%'
		ELSE generator_address_1
		END 
		OR
		generator_address_2 LIKE 
		CASE WHEN @generator_address_1 <>'' THEN '%' + (@generator_address_1)  + '%'
		ELSE generator_address_2
		END
		OR
		generator_address_3  LIKE 
		CASE WHEN @generator_address_1 <>'' THEN '%' + (@generator_address_1)  + '%'
		ELSE generator_address_3
		END 
		OR
		generator_address_4 LIKE 
		CASE WHEN @generator_address_1 <>'' THEN '%' + (@generator_address_1)  + '%'
		ELSE generator_address_4
		END 
		OR
		generator_address_5 LIKE 
		CASE WHEN @generator_address_1 <>'' THEN '%' + (@generator_address_1)  + '%'
		ELSE generator_address_5
		END )
		AND 
		generator_zip_code LIKE 
		CASE WHEN @generator_zip_code <>'' THEN '%' + substring(@generator_zip_code,1,5) + '%' 
		ELSE generator_zip_code
		END 
		AND 
		generator_state LIKE
		CASE WHEN @generator_state <>'' THEN '%' + trim(upper(@generator_state)) + '%' 
		ELSE generator_state
		END 
		AND 
		generator_city LIKE
		CASE WHEN @generator_city <>'' THEN '%' + trim(upper(@generator_city)) + '%'
		ELSE generator_city
		END
		order by generator_name asc
		
	END 
END TRY 
	BEGIN CATCH			
				INSERT INTO Plt_AI_Audit..
				Source_Error_Log 
				(
				input_params,
				source_system_details, 
				action,
				Error_description,
				log_date, 
				Added_by
				) 
				SELECT 
				@key_value, 
				@source_system, 
				'Select', 
				 ERROR_MESSAGE(), 
				 GETDATE(), 
				 SUBSTRING(USER_NAME(),1,40) 
				 
				 SELECT @OUTPUT ='Select Error; Please check Source_Error_Log table' 
				 SELECT @OUTPUT AS OUTPUT
END CATCH 
END
If @ls_config_value='F'
Begin
   Print 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
   Return -1
End
End


GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generator_info_for_lookup] TO EQAI  

Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generator_info_for_lookup] TO COR_USER

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_generator_info_for_lookup] TO svc_CORAppUser

GO
