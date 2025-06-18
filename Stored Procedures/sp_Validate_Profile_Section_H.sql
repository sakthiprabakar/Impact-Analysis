USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Section_H]    Script Date: 25-11-2021 20:57:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_H]
	-- Add the parameters for the stored procedure here
	@profile_id INT
	
AS



/* ******************************************************************

	 Updated By			: Divya Bharathi R  
	 Updated On			: 25th Feb 2025 
	 Type				: Stored Procedure  
	 Object Name		: [sp_Validate_Profile_Section_H]
	 Last Change		: Removed the validation for wcr_sign_name & wcr_sign_company
	 Reference Ticket	: DE37954: UAT Bug: Express Renewal > Express Renewal Window is Not Retrieving Valid Candidates for Renewal
	 Purpose			: Procedure to validate Section H required fields and Update the Status of section

Inputs 	
	@profile_id

Samples:
 EXEC [sp_Validate_Profile_Section_H] @profile_id
 EXEC [sp_Validate_Profile_Section_H] 699442

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;
	--DECLARE @Revision_ID INTEGER;

	DECLARE @ProfileStatusFlag varchar(1) = 'Y'

		
	declare  @rev_id int
	declare @form_id int
	select top 1 @form_id = form_id_wcr from Profile where profile_id = @profile_id
	Select top 1 @rev_id =revision_id from FormWCR where  form_id = @form_id order by revision_id desc

	
	declare @signing_name varchar(40)
	declare @signing_title varchar(40)
	declare @signing_company varchar(40)
	declare @signed_on_behalf_of char(1)
	

	select @signing_name = signing_name,@signing_title= signing_title,
	@signing_company = signing_company,@signed_on_behalf_of = signed_on_behalf_of from FormWCR
	where  form_id = @form_id and  revision_id = @rev_id 


	SELECT * INTO #tempProfile FROM Profile WHERE profile_id=@profile_id 
	--SELECT * INTO #tempFormXWasteCode FROM FormXWasteCode  WHERE form_id=@formid and revision_id=@Revision_ID 

	-- 1. Is a specific facility or treatment technology requested?
	IF(EXISTS(SELECT * FROM #tempProfile WHERE ISNULL(specific_technology_requested,'')='' OR specific_technology_requested='T'))
	BEGIN
		DECLARE @specific_technology_requested CHAR(1),
		@requested_technology VARCHAR(255)
		SELECT @specific_technology_requested=specific_technology_requested,@requested_technology=requested_technology FROM #tempProfile
		--If 'T' then user must enter the requested technology.  
		IF(@specific_technology_requested='T' AND ISNULL(@requested_technology,'')='' AND 
		(SELECT count(*) from ProfileUSEFacility Where profile_id=@profile_id ) <= 0)
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END
	END

	--3. Thermal Processing
	IF(EXISTS(SELECT * FROM #tempProfile WHERE ISNULL(thermal_process_flag,'')='' ))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END
	--OR ISNULL(signing_date,'') ='')
	-- 5. Knowledge is from
	--	IF((ISNULL(@signing_name,'') ='' OR ISNULL(@signing_company,'') = '' OR ISNULL(@signing_title,'') =''))--ISNULL(wcr_signing_title,'') ='' OR )
	--BEGIN
	--	SET @ProfileStatusFlag = 'P'
	--END
	--IF(EXISTS(SELECT * FROM #tempProfile WHERE ISNULL(wcr_sign_name,'') ='' OR ISNULL(wcr_sign_company,'') =''))--ISNULL(wcr_signing_title,'') ='' OR )
	--BEGIN
	--	SET @ProfileStatusFlag = 'P'
	--END

	-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE PROFILE_ID =@profile_id AND SECTION ='SH'))
	BEGIN
		INSERT INTO ProfileSectionStatus VALUES (@profile_id,'SH',@ProfileStatusFlag,getdate(),1,getdate(),1,1)
	END
	ELSE 
	BEGIN
		UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE PROFILE_ID =@profile_id AND SECTION = 'SH'
	END

	DROP TABLE #tempProfile 
	--DROP TABLE #tempFormXWasteCode 
	
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_H] TO COR_USER;
GO

