
CREATE PROCEDURE  [dbo].[sp_Validate_IllinoisDisposal]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_user_id NVARCHAR(150)
AS



/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_IllinoisDisposal]


	Procedure to validate Illinois Disposal Supplement form required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID
	@web_user_id

Samples:
 EXEC [sp_Validate_IllinoisDisposal] @form_id,@revision_ID, @web_user_id
 EXEC [sp_Validate_IllinoisDisposal]  519610, 1, 'iceman'

****************************************************************** */

BEGIN


	DECLARE @FormStatusFlag varchar(1) = 'Y'


	--SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID 
	SELECT * INTO #tempFormIllinoisDisposal FROM FormIllinoisDisposal WHERE wcr_id=@formid and wcr_rev_id=@revision_ID
	
	-- 25. Insecticides:
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(incecticides_flag,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- 26. Pesticides:
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(pesticides_flag,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- 27. Herbicides:
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(herbicides_flag,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- 28. Household Waste:
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(household_waste_flag,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END
	
	-- 29. Carcinogen:
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(carcinogen_flag,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END
	
	-- 30. Other: 
	--IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(other_flag,'')=''))
	--BEGIN
	--	SET @FormStatusFlag = 'P'
	--END

	-- 30. Other: (If yes, Describe) 
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(other_flag,'')='T' AND ISNULL(other_specify,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- 31. Does the waste contain >10 ppm but less than 250 ppm CN or 500 ppm sulfide?
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(sulfide_10_250_flag,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D004 -Arsenic
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d004_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D005 -Barium
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d005_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D006 -Cadmium
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d006_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D007 -Chromium	
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d007_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	--D008 -Lead
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d008_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D009 -Mercury
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d009_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D010 -Selenium
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d010_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D011 -Silver
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d011_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D012 -Endrin
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d012_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D013 -Lindane
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d013_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D014 -Methoxychlor
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d014_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D015 -Toxaphene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d015_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D016 -2,4-D(2,4-Dichloro phenoxyacetic acid)
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d016_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D017 -2,4,5-TP Silvex
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d017_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D018 -Benzene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d018_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D019 -Carbon Tetrachloride
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d019_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D020 -Chlordane
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d020_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D021 -Chlorobenzene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d021_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D022 -Chloroform
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d022_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D023 -o-Cresol
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d023_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D024 -m-Cresol
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d024_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D025 -p-Cresol
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d025_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D026 -Cresol
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d026_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D027 -1,4-Dichlorobenzene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d027_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D028 -1,2-Dichloroethane
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d028_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D029 -1,1-Dichloroethylene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d029_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D030 -2,4-Dinitrolouene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d030_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D031 -Heptachlor (& epoxide)
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d031_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D032 -Hexachlorobenzene	
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d032_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D033 -Hexachlorobutadiene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d033_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D034 -Hexachloroethane
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d034_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D035 -Methyl ethyl ketone
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d035_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D036 -Nitrobenzene	
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d036_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D037 -Pentachlorophenol
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d037_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D038 -Pyridine
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d038_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D039 -Tetrachloroethylene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d039_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	
	-- D040 -Trichloroethylene
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d040_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D041 -2,4,5-Trichlorophenol
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d041_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- D042 -2,4,6-Trichlorophenol
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d042_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END
	
	--D043 -Vinyl Chloride
	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(d043_above_PQL,'')=''))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE generator_certification_flag <> 'T'))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(sulfide_10_250_flag,'')='T' and certify_flag <> 'T'))
	BEGIN
		SET @FormStatusFlag = 'P'
	END

	-- Update the form status in FormSectionStatus table
	print 'called'
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID AND SECTION ='ID'))
	BEGIN
		INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'ID',@FormStatusFlag,getdate(),@web_user_id,getdate(),@web_user_id,1)
	END
	ELSE 
	BEGIN
		UPDATE FormSectionStatus SET section_status = @FormStatusFlag,date_modified=getdate(),modified_by=@web_user_id WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'ID'
	END

	--DROP TABLE #tempFormWCR 
	DROP TABLE #tempFormIllinoisDisposal
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_IllinoisDisposal] TO COR_USER;
GO



