USE PLT_AI
GO
DROP PROCEDURE IF EXISTS [sp_Validate_RadioActive]
GO

CREATE  PROCEDURE  [dbo].[sp_Validate_RadioActive]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_user_id NVARCHAR(150)
AS


/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 5th Mar 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_RadioActive]


	Procedure to validate Radio active required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID
	@web_user_id


Samples:
 EXEC [sp_Validate_RadioActive] @form_id,@revision_ID
 EXEC [sp_Validate_RadioActive] 502363, 1, 'nyswyn100'
 EXEC [sp_Validate_RadioActive] 600747, 1, 'manand84'

 SELECT * FROM FORMSECTIONSTATUS WHERE FORM_ID = 600747

    Updated By		: Sathiyamoorthi
	Updated On		: 10th July 2023
	Type			: Stored Procedure
	Ticket   		: 67291
	Change			: uranium_concentration field also allowed Text (Example) < 550 ppm, > 23 ppm. 

	Updated By		: Karuppiah
	Updated On		: 10th Dec 2024
	Type			: Stored Procedure
	Ticket   		: Titan-US134197,US132686,US134198,US127722
	Change			: RadioActiveUSEI field validation 

****************************************************************** */

BEGIN

	DECLARE @FormStatusFlag varchar(1) = 'Y'
	DECLARE @FailedRAUSEICount int = 0 

	--SELECT uranium_thorium_flag FROM FormRadioactive WHERE form_id = 460417
 

	SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@revision_ID 
	SELECT * INTO #tempFormRadioactive FROM FormRadioactive WHERE wcr_id = @formid and wcr_rev_id =  @revision_ID

	IF(EXISTS(SELECT * FROM #tempFormRadioactive WHERE (uranium_thorium_flag='T' OR uranium_source_material in('D','N','R')) 
	AND (PATINDEX('%[0-9]%', uranium_concentration) = 0 OR ISNULL(uranium_thorium_flag,'')=''))) 
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- Radium-226 (Ra-226)	
	IF(EXISTS(SELECT * FROM #tempFormRadioactive WHERE radium_226_flag='T' AND (isnumeric(radium_226_concentration) = 0)))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- Radium-228 (Ra-228)
	IF(EXISTS(SELECT * FROM #tempFormRadioactive WHERE radium_228_flag='T' 
	AND (isnumeric(radium_228_concentration) = 0)))
	BEGIN	
		SET @FormStatusFlag = 'P'
	END

	-- Lead-210 (Pb-210)
	IF(EXISTS(SELECT * FROM #tempFormRadioactive WHERE lead_210_flag='T' 
	AND (isnumeric(lead_210_concentration) = 0)))
	BEGIN
		SET @FormStatusFlag = 'P'		 
	END

	-- Potassium-40 (K-40)
	IF(EXISTS(SELECT * FROM #tempFormRadioactive WHERE potassium_40_flag='T' 
	AND (isnumeric(potassium_40_concentration) = 0)))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- 1. Was the waste generated in a particle accelerator?
	IF(EXISTS(SELECT * FROM #tempFormRadioactive WHERE ((exempt_byproduct_material_flag='T' 
	OR special_nuclear_material_flag='T' OR accelerator_flag='T' 
	OR specifically_exempted_flag= 'T') AND ISNULL(generated_in_particle_accelerator_flag,'')='')))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- 1. Is the material approved for disposal in accordance with 20.2008(b) or equivalent Agreement State regulation? 
	-- 2. Has the waste been approved by the NRC or an Agreement State for alternative disposal in accordance with 10CFR 20.2002 
	--or an Agreement State equivalent regulation?
	-- 3. Was the material approved for alternate disposal via a decommissioning plan or license amendment? 
	-- 4. Is the material acceptable under USEI Table C.4b AS not licensed or regulated by the NRC or Agreement State 
	--under the Atomic Energy Act?
	-- 5. Has the material been “Released FROM Radiological Control” FROM a US Department of Energy Site in accordance with a 
	--DOE Order 458.1 Authorized Limit? 
	-- 6. Has the material been exempted, released, or otherwise authorized for non-licensed disposal by the US Department 
	--of Defense under its AEA Section 91(b) authority? 
	IF(EXISTS(SELECT * FROM #tempFormRadioactive WHERE (exempt_byproduct_material_flag='T' OR special_nuclear_material_flag='T' OR accelerator_flag='T' OR specifically_exempted_flag= 'T') 
	AND (ISNULL(approved_for_disposal_flag,'')='' OR ISNULL(approved_by_nrc_flag,'')='' OR ISNULL(approved_for_alternate_disposal_flag,'')=''
	OR ISNULL(nrc_exempted_flag,'')='' OR ISNULL(released_from_radiological_control_flag,'')='' OR ISNULL(DOD_non_licensed_disposal_flag,'')='')))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	 ----RadioActiveUSEI Check    
	 SELECT @FailedRAUSEICount = count(1) from #tempFormRadioactive fra    
	 INNER JOIN FormRadioactiveUSEI frau ON fra.form_id = frau.form_id AND fra.revision_id = frau.revision_id    
	  AND fra.wcr_id = @formid    
	  AND frau.revision_id = @revision_ID    
	  AND frau.radionuclide IS NOT NULL     
	  AND frau.radionuclide != ''    
	  AND (frau.concentration IS NULL OR frau.concentration = '');    
	  SELECT @FailedRAUSEICount    
	 IF(@FailedRAUSEICount != 0)    
	 BEGIN    
	  SET @FormStatusFlag = 'P'    
	 END   

	-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='RA'))
	BEGIN
		INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'RA',@FormStatusFlag,getdate(),@web_user_id,getdate(),@web_user_id,1)
	END
	ELSE 
	BEGIN
		UPDATE FormSectionStatus SET section_status = @FormStatusFlag,date_modified=getdate(),modified_by=@web_user_id 
		WHERE  FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'RA'
	END

	DROP TABLE #tempFormWCR 
	DROP TABLE #tempFormRadioactive 

END

GO
GRANT EXEC ON [dbo].[sp_Validate_RadioActive] TO COR_USER;
GO