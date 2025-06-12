
CREATE PROCEDURE [dbo].[sp_FormWCR_SectionH_Select]
     @formId int = 0,
	 @revisionId INT
AS



/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 25th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionH_Select]


	Procedure to select Section H related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionH_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionH_Select] 512841, 1
***********************************************************************/

BEGIN

DECLARE @section_status CHAR(1);

SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND revision_id = @revisionId AND section='SH' 



	SELECT  ISNULL(specific_technology_requested,'') AS specific_technology_requested ,
	ISNULL(requested_technology,'') AS requested_technology ,
	ISNULL(thermal_process_flag,'') AS thermal_process_flag ,
	ISNULL(other_restrictions_requested,'') AS  other_restrictions_requested ,
	ISNULL(signing_name,'') AS signing_name ,
	ISNULL(signing_title,'') AS signing_title ,
	ISNULL(signing_company,'') AS signing_company ,
	ISNULL(signed_on_behalf_of,'') AS signed_on_behalf_of ,
	ISNULL(signing_date,'') AS signing_date, 
	@section_status AS IsCompleted,
	(SELECT FormXUSEFacility.*,(
	SELECT Top 1  upc.name as  profit_ctr_name
		FROM ProfitCenter pc
		-- JOIN tsdf ts on pc.company_id=ts.eq_company and ts.eq_profit_ctr = pc.profit_ctr_id and ts.TSDF_Status='A'
		join USE_Profitcenter upc on pc.company_id = upc.company_id and pc.profit_ctr_id = upc.profit_ctr_id
		WHERE status = 'A' AND
		waste_receipt_flag = 'T' 
		and upc.company_id=FormXUSEFacility.company_id and upc.profit_ctr_id=FormXUSEFacility.profit_ctr_id) AS profit_ctr_name
	-- SELECT p.wcr_facility_name  FROM  ProfitCenter p WHERE  p.profit_ctr_id =FormXUSEFacility.profit_ctr_id AND p.company_id = FormXUSEFacility.company_id)  AS profit_ctr_name
	
	 FROM FormXUSEFacility 
	
	 WHERE  FormXUSEFacility.form_id = @formId and FormXUSEFacility.revision_id = @revisionId
	 FOR XML AUTO,TYPE,ROOT ('FacilityList'), ELEMENTS)
    from FormWCR 
	where form_id = @formId and revision_id = @revisionId
	FOR XML RAW ('SectionH'), ROOT ('ProfileModel'), ELEMENTS

END

GO

	GRANT EXEC ON [dbo].[sp_FormWCR_SectionH_Select] TO COR_USER;

GO