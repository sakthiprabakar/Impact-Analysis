CREATE PROCEDURE [dbo].[sp_FormWCR_Section_Select]
     @formId int = 0,
	 @revision_Id int,
	 @section nvarchar(3)
AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_FormWCR_Section_Select]

	Description	: 
                Procedure to get selected section details (Section A- H and Supplementary ) for given form id , revision id and specifed section name (i.e: A) 
				

	Input		:
				@form_id
				@revision_id
				@section
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_FormWCR_Section_Select] 893442,1, 'A'

*************************************************************************************/
BEGIN

     IF  @section = 'A'
	   BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionA_Select] @formId, @revision_Id
	   END
     ELSE IF @section = 'B'
	    BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionB_Select] @formId, @revision_Id
	   END
     ELSE IF @section = 'C'
	    BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionC_Select] @formId, @revision_Id
	   END
     ELSE IF @section = 'D'
	    BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionD_Select] @formId, @revision_Id
	   END
     ELSE IF @section = 'E'
	    BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionE_Select] @formId, @revision_Id
	   END
	 ELSE IF @section = 'F'
	    BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionF_Select] @formId, @revision_Id
	   END
     ELSE IF @section = 'G'
	    BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionG_Select] @formId, @revision_Id
	   END
     ELSE IF @section = 'H'
	    BEGIN
	     EXEC [dbo].[sp_FormWCR_SectionH_Select] @formId, @revision_Id
	   END

	 ELSE IF  @section = 'PB'
	   BEGIN
	     EXEC sp_pcb_Select  @formId, @revision_Id
	   END
     ELSE IF @section = 'LR'
	    BEGIN
	     EXEC sp_ldr_Select @formId, @revision_Id
	   END
     ELSE IF @section = 'BZ'
	    BEGIN
	     EXEC sp_benzene_Select @formId, @revision_Id
	   END
     ELSE IF @section = 'ID'
	    BEGIN
	     EXEC sp_IllinoisDisposal_select @formId, @revision_Id
	   END
     ELSE IF @section = 'PL'
	    BEGIN
	     EXEC sp_pharmaceutical_select @formId, @revision_Id
	   END
	 ELSE IF @section = 'UL'
	    BEGIN 
	     EXEC sp_usedOil_select @formId, @revision_Id
	   END
     ELSE IF @section = 'WI'
	    BEGIN
	     EXEC sp_wasteImport_select @formId, @revision_Id
	   END
      ELSE IF @section = 'CN'
	    BEGIN
	     EXEC sp_certification_select @formId, @revision_Id
	   END
	    ELSE IF @section = 'TL'
	    BEGIN
	     EXEC sp_thermal_select @formId, @revision_Id
	   END	
	    ELSE IF @section = 'DS'
	    BEGIN
	     EXEC sp_Debris_select @formId, @revision_Id
	   END
	    ELSE IF @section = 'CR'
	    BEGIN
	     EXEC sp_cylinder_select  @formId, @revision_Id
	   END
	    ELSE IF @section = 'RA'
	    BEGIN
	     EXEC sp_Radioactive_select @formId, @revision_Id
	   END
	   ELSE IF @section = 'DA'
	   BEGIN
		EXEC  sp_Documents_Select @formId, @revision_Id
	   END
	    ELSE IF @section = 'GL'
	   BEGIN
		EXEC sp_GeneratorLocation_select @formId, @revision_Id
	   END
	   ELSE IF @section = 'SL' -- USE Facility Tab
	   BEGIN
		EXEC sp_FormWCR_SectionL_Select @formId, @revision_Id
	   END
	   ELSE IF @section = 'GK' -- USE Facility Tab
	   BEGIN
		EXEC sp_FormWCR_GeneratorKnowledge_Select @formId, @revision_Id
	   END
	   ELSE IF @section = 'FB'
	   BEGIN
	    EXEC  sp_FormEcoflo_select @formId, @revision_Id 
	   END
END

GO
	   GRANT EXECUTE ON [dbo].[sp_FormWCR_Section_Select] TO COR_USER;

GO