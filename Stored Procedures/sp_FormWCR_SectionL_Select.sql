USE [PLT_AI]
GO

CREATE PROCEDURE [dbo].[sp_FormWCR_SectionL_Select]
	-- Add the parameters for the stored procedure here
	  @formId int = 0,
	 @revisionId INT
AS


/* ******************************************************************

	Updated By		: Vinoth D
	Updated On		: 02-12-2022
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionL_Select]


	Procedure to select Section L USE Facility

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionL_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionL_Select] 480096, 1

***********************************************************************/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
--DECLARE @section_status CHAR(1);

--SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND revision_id = @revisionId AND section='SL' 



	SELECT  routing_facility, approval_code,
	--(SELECT routing_facility From FormWCR where form_id = @formId and revision_id = @revisionId) as  routing_facility,
	(SELECT FormXUSEFacility.*,(SELECT wcr_facility_name  FROM  ProfitCenter  WHERE  profit_ctr_id =FormXUSEFacility.profit_ctr_id AND company_id = FormXUSEFacility.company_id)  AS profit_ctr_name
	
	 FROM FormXUSEFacility 
	
	 WHERE  form_id = @formId and revision_id = @revisionId
	 FOR XML AUTO,TYPE,ROOT ('FacilityList'), ELEMENTS)
    from FormWCR 
	where form_id = @formId and revision_id = @revisionId
	FOR XML RAW ('SectionL'), ROOT ('ProfileModel'), ELEMENTS
END


GO

GRANT EXECUTE ON [dbo].[sp_FormWCR_SectionL_Select] TO COR_USER;

GO