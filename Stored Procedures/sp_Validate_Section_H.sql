
CREATE PROCEDURE  [dbo].[sp_Validate_Section_H]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@Revision_ID int
AS



/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 4th Mar 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_H]


	Procedure to validate Section H required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [sp_Validate_Section_H] @form_id,@revision_ID
 EXEC [sp_Validate_Section_H] 459257, 1

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;
	--DECLARE @Revision_ID INTEGER;

	DECLARE @FormStatusFlag varchar(1) = 'Y'


	SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID 
	--SELECT * INTO #tempFormXWasteCode FROM FormXWasteCode  WHERE form_id=@formid and revision_id=@Revision_ID 

	-- 1. Is a specific facility or treatment technology requested?
	IF(EXISTS(SELECT * FROM #tempFormWCR WHERE ISNULL(specific_technology_requested,'')='' OR specific_technology_requested='T'))
	BEGIN
		DECLARE @specific_technology_requested CHAR(1),
		@requested_technology VARCHAR(255)
		SELECT @specific_technology_requested=specific_technology_requested,@requested_technology=requested_technology FROM #tempFormWCR
		--If 'T' then user must enter the requested technology.  
		IF(@specific_technology_requested='T' AND ISNULL(@requested_technology,'')='' AND 
		(SELECT count(*) from FormXUSEFacility Where form_id = @formid and revision_id = @Revision_ID) <= 0)
		BEGIN
			SET @FormStatusFlag = 'P'
		END
	END

	--3. Thermal Processing
	IF(EXISTS(SELECT * FROM #tempFormWCR WHERE ISNULL(thermal_process_flag,'')='' ))
	BEGIN
		SET @FormStatusFlag = 'P'
	END
	--OR ISNULL(signing_date,'') ='')
	-- 5. Knowledge is from
	IF(EXISTS(SELECT * FROM #tempFormWCR WHERE ISNULL(signing_name,'') ='' OR ISNULL(signing_title,'') ='' OR ISNULL(signing_company,'') =''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND SECTION ='SH'))
	BEGIN
		INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'SH',@FormStatusFlag,getdate(),1,getdate(),1,1)
	END
	ELSE 
	BEGIN
		UPDATE FormSectionStatus SET section_status = @FormStatusFlag WHERE FORM_ID = @formid AND SECTION = 'SH'
	END

	DROP TABLE #tempFormWCR 
	--DROP TABLE #tempFormXWasteCode 
	
END

GO

	GRANT EXEC ON [dbo].[sp_Validate_Section_H] TO COR_USER;

GO