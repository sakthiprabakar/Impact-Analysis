USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_RadioActive]    Script Date: 26-11-2021 13:07:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_RadioActive]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_user_id NVARCHAR(150)
AS


/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 5th Mar 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_RadioActive]


	Procedure to validate Radio active required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_user_id


Samples:
 EXEC [sp_Validate_Profile_RadioActive] @profile_id,@web_user_id
 EXEC [sp_Validate_Profile_RadioActive] 502363,'nyswyn100'

****************************************************************** */

BEGIN

	DECLARE @ProfileStatusFlag varchar(1) = 'Y'


	--select uranium_thorium_flag from FormRadioactive where form_id = 460417
 

	--SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@revision_ID 
	SELECT * INTO #tempProfileRadioactive FROM ProfileRadioactive WHERE profile_id = @profile_id
	--select * from #tempFormWCR 
	--select * from #tempFormRadioactive
	-- Source Material (any Uranium and/or Thorium)

	-- ISNULL(uranium_thorium_flag,'')='T' AND
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE ISNULL(uranium_thorium_flag,'')='T' AND (uranium_concentration IS NULL OR uranium_concentration = '' )))
	BEGIN
		print '1'
		SET @ProfileStatusFlag = 'P'
	END

	-- Do you know if the source material is:
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE (ISNULL(uranium_source_material,'')='D' OR ISNULL(uranium_source_material,'')='N' OR ISNULL(uranium_source_material,'')='R') AND ( uranium_concentration IS NULL OR uranium_concentration = '')))
	BEGIN
	     print '2'
		SET @ProfileStatusFlag = 'P'
	END

	-- Radium-226 (Ra-226)
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE ISNULL(radium_226_flag,'')='T' AND (radium_226_concentration IS NULL OR radium_226_concentration = '')))
	BEGIN
	    
		SET @ProfileStatusFlag = 'P'
	END

	-- Radium-228 (Ra-228)
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE ISNULL(radium_228_flag,'')='T' AND (radium_228_concentration IS NULL OR radium_228_concentration = '' )))
	BEGIN
	 
		SET @ProfileStatusFlag = 'P'
	END

	-- Lead-210 (Pb-210)
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE ISNULL(lead_210_flag,'')='T' AND (lead_210_concentration IS NULL OR lead_210_concentration = '')))
	BEGIN
	
		SET @ProfileStatusFlag = 'P'
	END

	-- Potassium-40 (K-40)
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE ISNULL(potassium_40_flag,'')='T' AND (potassium_40_concentration IS NULL OR potassium_40_concentration = '')))
	BEGIN
	 
		SET @ProfileStatusFlag = 'P'
	END

	Declare  @exempt_byproduct_material_flag  CHAR(1),@special_nuclear_material_flag CHAR(1), @accelerator_flag CHAR(1), @generated_in_particle_accelerator_flag char(1)
		
	
	--IF  @exempt_byproduct_material_flag!= 'F' AND @special_nuclear_material_flag != 'F' AND @accelerator_flag != 'F'
	
	--BEGIN	

	--   DECLARE @RadioactiveCount int
	--					       SET @RadioactiveCount = (SELECT  (			 
	--						  (CASE WHEN exempt_byproduct_material_flag IS NULL OR exempt_byproduct_material_flag = ''  THEN 0 ELSE 1 END)
	--						+ (CASE WHEN special_nuclear_material_flag IS NULL OR special_nuclear_material_flag = ''  THEN 0 ELSE 1 END)
	--						+ (CASE WHEN  accelerator_flag IS NULL OR  accelerator_flag  = ''  THEN 0 ELSE 1 END)							
	--													) AS sum_of_radionulls
	--													From #tempFormRadioactive
	--													Where 
	--													wcr_id = @formid and wcr_rev_id =  @revision_ID)	


	--					IF	@RadioactiveCount =0
	--					BEGIN								
	--						 SET @FormStatusFlag = 'P'
	--					END

	--END
	

	

	-- 1. Was the waste generated in a particle accelerator?

	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE ((ISNULL(exempt_byproduct_material_flag,''  )='T' OR ISNULL(special_nuclear_material_flag,'')='T' OR ISNULL(accelerator_flag,'')='T' OR ISNULL(specifically_exempted_flag, '') = 'T') AND ISNULL(generated_in_particle_accelerator_flag,'')='')))
	BEGIN
	 print '7'
		SET @ProfileStatusFlag = 'P'
	END

	-- 1. Is the material approved for disposal in accordance with 20.2008(b) or equivalent Agreement State regulation? 
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE (ISNULL(exempt_byproduct_material_flag,'')='T' OR ISNULL(special_nuclear_material_flag,'')='T' OR ISNULL(accelerator_flag,'')='T'  OR ISNULL(specifically_exempted_flag, '') = 'T') AND ISNULL(approved_for_disposal_flag,'')=''))
	BEGIN
	 print '8'
		SET @ProfileStatusFlag = 'P'
	END

	-- 2. Has the waste been approved by the NRC or an Agreement State for alternative disposal in accordance with 10CFR 20.2002 or an Agreement State equivalent regulation? 
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE (ISNULL(exempt_byproduct_material_flag,'')='T' OR ISNULL(special_nuclear_material_flag,'')='T' OR ISNULL(accelerator_flag,'')='T'  OR ISNULL(specifically_exempted_flag, '') = 'T') AND ISNULL(approved_by_nrc_flag,'')=''))
	BEGIN
	 print '9'
		SET @ProfileStatusFlag = 'P'
	END

	-- 3. Was the material approved for alternate disposal via a decommissioning plan or license amendment? 
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE (ISNULL(exempt_byproduct_material_flag,'')='T' OR ISNULL(special_nuclear_material_flag,'')='T' OR ISNULL(accelerator_flag,'')='T'  OR ISNULL(specifically_exempted_flag, '') = 'T') AND ISNULL(approved_for_alternate_disposal_flag,'')=''))
	BEGIN
	   print '10'
		SET @ProfileStatusFlag = 'P'
	END

	-- 4. Is the material acceptable under USEI Table C.4b as not licensed or regulated by the NRC or Agreement State under the Atomic Energy Act?
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE (ISNULL(exempt_byproduct_material_flag,'')='T' OR ISNULL(special_nuclear_material_flag,'')='T' OR ISNULL(accelerator_flag,'')='T'  OR ISNULL(specifically_exempted_flag, '') = 'T') AND ISNULL(nrc_exempted_flag,'')=''))
	BEGIN
	 print '11'
		SET @ProfileStatusFlag = 'P'
	END

	-- 5. Has the material been “Released from Radiological Control” from a US Department of Energy Site in accordance with a DOE Order 458.1 Authorized Limit? 
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE (ISNULL(exempt_byproduct_material_flag,'')='T' OR ISNULL(special_nuclear_material_flag,'')='T' OR ISNULL(accelerator_flag,'')='T'  OR ISNULL(specifically_exempted_flag, '') = 'T') AND ISNULL(released_from_radiological_control_flag,'')=''))
	BEGIN
	  print '12'
		SET @ProfileStatusFlag = 'P'
	END

	-- 6. Has the material been exempted, released, or otherwise authorized for non-licensed disposal by the US Department of Defense under its AEA Section 91(b) authority? 
	IF(EXISTS(SELECT * FROM #tempProfileRadioactive WHERE (ISNULL(exempt_byproduct_material_flag,'')='T' OR ISNULL(special_nuclear_material_flag,'')='T' OR ISNULL(accelerator_flag,'')='T'  OR ISNULL(specifically_exempted_flag, '') = 'T') AND ISNULL(DOD_non_licensed_disposal_flag,'')=''))
	BEGIN
	  print '13'
		SET @ProfileStatusFlag = 'P'
	END

	print @ProfileStatusFlag

	-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='RA'))
	BEGIN
		INSERT INTO ProfileSectionStatus VALUES (@profile_id,'RA',@ProfileStatusFlag,getdate(),@web_user_id,getdate(),@web_user_id,1)
	END
	ELSE 
	BEGIN
		UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE  profile_id = @profile_id AND SECTION = 'RA'
	END

	--DROP TABLE #tempFormWCR 
	DROP TABLE #tempProfileRadioactive 

END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_RadioActive] TO COR_USER;
GO