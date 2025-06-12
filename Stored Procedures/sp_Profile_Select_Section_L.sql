CREATE PROCEDURE sp_Profile_Select_Section_L
	@profile_id INT 
AS

/* ******************************************************************

	Updated By		: Senthil Kumar
	Updated On		: 19th Sep 2019
	Type			: Stored Procedure
	Object Name		: [sp_Profile_Select_Section_L]


	Procedure to select Section L USE Facility

inputs 
	
	@profile_id


Samples:
 EXEC [sp_Profile_Select_Section_L] @profile_id
 EXEC [sp_Profile_Select_Section_L] 480096

***********************************************************************/
BEGIN
	SELECT  
	(SELECT TOP 1 convert(varchar(4), company_id) + '|' + convert(varchar(4), profit_ctr_id)  
	 from ProfileQuoteApproval WHERE primary_facility_flag = 'T' AND status = 'A' and profile_id = @profile_id) as  routing_facility,
	(SELECT ProfileUSEFacility.*,(SELECT wcr_facility_name  FROM  ProfitCenter  WHERE  profit_ctr_id =ProfileUSEFacility.profit_ctr_id AND company_id = ProfileUSEFacility.company_id)  AS profit_ctr_name
	 FROM ProfileUSEFacility 
	 WHERE  profile_id = @profile_id
	 FOR XML AUTO,TYPE,ROOT ('FacilityList'), ELEMENTS)
	FOR XML RAW ('SectionL'), ROOT ('ProfileModel'), ELEMENTS
END
GO


GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_L] TO COR_USER;

GO