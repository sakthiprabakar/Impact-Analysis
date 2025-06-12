
CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_ldr](
	
		 @profileId INT
		
)
AS

/***********************************************************************************

	Author		: Prabhu
	Updated On	: 4-Jan-2019
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_ldr]

	Description	: 
                  Procedure to get LDR profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_ldr] 648216

*************************************************************************************/

BEGIN
				
	--SELECT  
	--	ISNULL( LDR.ldr_req_flag,'') AS ldr_notification_frequency,
	--	ISNULL(GETDATE(),'') AS signing_date

	--	FROM  ProfileQuoteApproval AS LDR 

	--Where profile_Id = @profileId 

	--	FOR XML RAW ('LDR'), ROOT ('ProfileModel'), ELEMENTS

	declare @generator_epd_id nvarchar(15), @generator_name nvarchar(100)

	select top 1 @generator_epd_id = EPA_ID, @generator_name = generator_name from generator

SELECT         
		@profileId as profile_id,
		ISNULL(p.generator_id,'') as  generator_id,
		--COALESCE(ldr.wcr_id,@form_id) as wcr_id,
		--COALESCE(ldr.wcr_rev_id,@revision_id) as wcr_rev_id,
		ISNULL(@generator_name,'') as  generator_name,
		--ISNULL(@generator_epd_id,'') as  generator_epa_id,
		--ISNULL(ldr.manifest_doc_no,'') as  manifest_doc_no,
		ISNULL(lab.ldr_notification_frequency ,'') as  ldr_notification_frequency,
		ISNULL(p.waste_managed_id ,'') as  waste_managed_id,
		-- ldr.rowguid as  rowguid,
		--  ISNULL(ldr.status ,'') as  status,			
		-- ISNULL(ldr.locked ,'') as  locked,
		--ISNULL(p.date_created ,'') as  date_created,
		--ISNULL(p.date_modified ,'') as  date_modified,
		--ISNULL(p.created_by ,'') as  created_by,
		--ISNULL(p.modified_by ,'') as  modified_by,
		--ISNULL(p.signing_title ,'') as  signing_title,
		--ISNULL(p.signing_date ,'') as  signing_date,
		ISNULL(p.waste_water_flag ,'') as  waste_water_flag,
		ISNULL(lab.more_than_50_pct_debris ,'') as  more_than_50_pct_debris,
		--ISNULL(p.signing_name ,'') as  signing_name,
		--ISNULL(fwcr.signing_date ,'') as  signing_date,
		ISNULL(pqa.approval_code,'') as  approval_code,
		--ISNULL(ldrD.manifest_line_item,'') as  manifest_line_item,
		ISNULL(p.constituents_requiring_treatment_flag,'') as  constituents_requiring_treatment_flag,
		--@section_status AS IsCompleted,
		(SELECT *
		FROM profilewastecode as WasteCode
		WHERE  WasteCode.profile_id = @profileId
		FOR XML AUTO,TYPE,ROOT ('WasteCode'), ELEMENTS),
		(SELECT ldr_subcategory_id,(SELECT short_desc FROM LDRSubcategory l where l.subcategory_id = ldr_subcategory_id) as short_desc
		FROM ProfileLDRSubcategory as LDRSubcategory
		WHERE  LDRSubcategory.profile_id = @profileId-- and revision_id = @revision_id
		FOR XML AUTO,TYPE,ROOT ('LDRSubcategory'), ELEMENTS),
		(SELECT *
		FROM ProfileConstituent as Constituent
		WHERE  Constituent.profile_id = @profileId AND Constituent.UHC='T' -- and revision_id = @revision_id
		FOR XML AUTO,TYPE,ROOT ('Constituent'), ELEMENTS),
		(SELECT (SELECT TOP 1 const_desc from Constituents where const_id = Constituent.const_id) const_desc, *
		FROM ProfileConstituent as Constituent
		WHERE  Constituent.profile_id = @profileId 					
		AND Constituent.requiring_treatment_flag='T' 
		--AND Constituent.Specifier='LDR-WO'
		FOR XML AUTO,TYPE,ROOT ('ExceedConstituent'), ELEMENTS)


	FROM profile AS  p
	LEFT JOIN ProfileLab lab on lab.profile_id = p.profile_id and lab.type = 'A'
	LEFT JOIN ProfileQuoteApproval pqa on pqa.profile_id = p.profile_id
	Where p.profile_id = @profileId	
	FOR XML RAW ('LDR'), ROOT ('ProfileModel'), ELEMENTS
	
END
			
 GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_ldr] TO COR_USER;

GO
