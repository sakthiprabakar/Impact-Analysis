
GO
DROP PROC IF EXISTS sp_Profile_Select_Section
GO

CREATE PROCEDURE [dbo].[sp_Profile_Select_Section]
     @profileid INT,
	 @section VARCHAR(3),
	 @TSDFType VARCHAR(10)=''
AS

/***********************************************************************************

	Updated BY		: Monish V
	Updated On	: 23rd NOv 2022
	Ticket		: 58692
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section]

	Description	: 
      Procedure to get profile section details (Section A- H and Supplementary ) for given profile id and specifed section name (i.e: A) 
				

	Input		:
				@profileid
				@section
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section] 648216, 'DA'

*************************************************************************************/
BEGIN
	IF  @section = 'A'
		BEGIN
			EXEC sp_Profile_Select_Section_A @profileid
		END
	ELSE IF @section = 'B'
	    BEGIN
			EXEC sp_Profile_Select_Section_B @profileid
		END
	ELSE IF @section = 'C'
	    BEGIN
			EXEC sp_Profile_Select_Section_C @profileid
		END
	ELSE IF @section = 'D'
	    BEGIN
			EXEC sp_Profile_Select_Section_D @profileid
		END
	ELSE IF @section = 'E'
	    BEGIN
			EXEC sp_Profile_Select_Section_E @profileid
		END
	ELSE IF @section = 'F'
	    BEGIN
			EXEC sp_Profile_Select_Section_F @profileid
		END
	ELSE IF @section = 'G'
	    BEGIN
			EXEC sp_Profile_Select_Section_G @profileid
		END
	ELSE IF @section = 'H'
		BEGIN
			EXEC sp_Profile_Select_Section_H @profileid
		END
	ELSE IF @section = 'PB'
	    BEGIN
			EXEC sp_Profile_Select_Section_pcb  @profileid
		END
	ELSE IF @section = 'LR'
	    BEGIN
			EXEC sp_Profile_Select_Section_ldr @profileid
		END
	ELSE IF @section = 'BZ'
	    BEGIN
			EXEC sp_Profile_Select_Section_benzene @profileid
		END
     ELSE IF @section = 'ID'
	    BEGIN
	     EXEC sp_Profile_Select_Section_IllinoisDisposal @profileid
	   END
    -- ELSE IF @section = 'PL'
	   -- BEGIN
			--  EXEC sp_FormWCR_Select_Section_pharmaceutical @formId, @revisionid
	   --END
	ELSE IF @section = 'UL'
	    BEGIN 
			EXEC sp_Profile_Select_Section_usedOil @profileid
		END
	ELSE IF @section = 'WI'
	    BEGIN
			EXEC sp_Profile_Select_Section_wasteImport @profileid
		END
	ELSE IF @section = 'CN'
	    BEGIN
			EXEC sp_Profile_Select_Section_certification @profileid
		END
	ELSE IF @section = 'TR'
	    BEGIN
			EXEC sp_Profile_Select_Section_thermal @profileid
		END
	ELSE IF @section = 'DS'
	    BEGIN
			EXEC sp_Profile_Select_Section_Debris @profileid
		END
	ELSE IF @section = 'CR'
	    BEGIN
			EXEC sp_Profile_Select_Section_Cylinder  @profileid
		END
	ELSE IF @section = 'RA'
		BEGIN
			EXEC sp_Profile_Select_Section_Radioactive @profileid
		END
	ELSE IF @section = 'SL' -- USE Facility Tab
		BEGIN
			EXEC sp_Profile_Select_Section_L @profileid
		END
	ELSE IF @section = 'DA' -- USE Facility Tab
		BEGIN
			EXEC sp_COR_Profile_Document_Select @profileid,@TSDFType
		END
	ELSE IF @section = 'GK' -- Generator Knowledge supplement
		BEGIN
			EXEC sp_Profile_Select_GeneratorKnowledge @profileid
		END
	ELSE IF @section = 'FB'  ---Fuel Blending
		BEGIN
			EXEC  sp_ProfileEcoflo_select @profileId
		END
	   
END

GO
	GRANT EXEC ON [dbo].[sp_Profile_Select_Section] TO COR_USER;
GO