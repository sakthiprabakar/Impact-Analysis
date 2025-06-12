USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_IllinoisDisposal]    Script Date: 26-11-2021 12:52:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE  [dbo].[sp_Validate_Profile_IllinoisDisposal]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_user_id NVARCHAR(150)
AS



/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_IllinoisDisposal]


	Procedure to validate Illinois Disposal Supplement form required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_user_id

Samples:
 EXEC [sp_Validate_Profile_IllinoisDisposal] @profile_id,@web_user_id
 EXEC [sp_Validate_Profile_IllinoisDisposal]  519610,'iceman'

****************************************************************** */

BEGIN


	DECLARE @ProfileStatusFlag varchar(1) = 'Y'


	--SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID 
	SELECT * INTO #tempProfileIllinoisDisposal FROM ProfileIllinoisDisposal WHERE profile_id=@profile_id
	
	-- 25. Insecticides:
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(incecticides_flag,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- 26. Pesticides:
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(pesticides_flag,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- 27. Herbicides:
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(herbicides_flag,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- 28. Household Waste:
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(household_waste_flag,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END
	
	-- 29. Carcinogen:
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(carcinogen_flag,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END
	
	-- 30. Other: 
	--IF(EXISTS(SELECT * FROM #tempFormIllinoisDisposal WHERE ISNULL(other_flag,'')=''))
	--BEGIN
	--	SET @FormStatusFlag = 'P'
	--END

	-- 30. Other: (If yes, Describe) 
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(other_flag,'')='T' AND ISNULL(other_specify,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- 31. Does the waste contain >10 ppm but less than 250 ppm CN or 500 ppm sulfide?
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(sulfide_10_250_flag,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D004 -Arsenic
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d004_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D005 -Barium
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d005_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D006 -Cadmium
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d006_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D007 -Chromium	
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d007_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	--D008 -Lead
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d008_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D009 -Mercury
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d009_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D010 -Selenium
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d010_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D011 -Silver
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d011_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D012 -Endrin
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d012_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D013 -Lindane
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d013_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D014 -Methoxychlor
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d014_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D015 -Toxaphene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d015_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D016 -2,4-D(2,4-Dichloro phenoxyacetic acid)
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d016_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D017 -2,4,5-TP Silvex
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d017_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D018 -Benzene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d018_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D019 -Carbon Tetrachloride
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d019_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D020 -Chlordane
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d020_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D021 -Chlorobenzene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d021_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D022 -Chloroform
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d022_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D023 -o-Cresol
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d023_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D024 -m-Cresol
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d024_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D025 -p-Cresol
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d025_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D026 -Cresol
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d026_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D027 -1,4-Dichlorobenzene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d027_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D028 -1,2-Dichloroethane
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d028_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D029 -1,1-Dichloroethylene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d029_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D030 -2,4-Dinitrolouene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d030_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D031 -Heptachlor (& epoxide)
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d031_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D032 -Hexachlorobenzene	
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d032_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D033 -Hexachlorobutadiene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d033_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D034 -Hexachloroethane
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d034_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D035 -Methyl ethyl ketone
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d035_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D036 -Nitrobenzene	
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d036_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D037 -Pentachlorophenol
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d037_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D038 -Pyridine
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d038_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D039 -Tetrachloroethylene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d039_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	
	-- D040 -Trichloroethylene
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d040_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D041 -2,4,5-Trichlorophenol
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d041_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- D042 -2,4,6-Trichlorophenol
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d042_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END
	
	--D043 -Vinyl Chloride
	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(d043_above_PQL,'')=''))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE generator_certification_flag <> 'T'))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	IF(EXISTS(SELECT * FROM #tempProfileIllinoisDisposal WHERE ISNULL(sulfide_10_250_flag,'')='T' and certify_flag <> 'T'))
	BEGIN
		SET @ProfileStatusFlag = 'P'
	END

	-- Update the form status in FormSectionStatus table
	print 'called'
	IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='ID'))
	BEGIN
		INSERT INTO ProfileSectionStatus VALUES (@profile_id,'ID',@ProfileStatusFlag,getdate(),@web_user_id,getdate(),@web_user_id,1)
	END
	ELSE 
	BEGIN
		UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id =@profile_id AND SECTION = 'ID'
	END

	--DROP TABLE #tempFormWCR 
	DROP TABLE #tempProfileIllinoisDisposal
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_IllinoisDisposal] TO COR_USER;
GO
