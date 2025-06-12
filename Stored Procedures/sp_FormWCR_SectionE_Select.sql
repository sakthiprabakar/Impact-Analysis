
CREATE PROCEDURE [dbo].[sp_FormWCR_SectionE_Select]
     @formId int = 0,
	 @revisionId Int
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionE_Select]


	Procedure to select Section E related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionE_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionE_Select] 528520, 1

****************************************************************** */

BEGIN

DECLARE @section_status CHAR(1);

SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND section='SE' 

	SELECT ISNULL(texas_waste_material_type,'') AS texas_waste_material_type , 
	ISNULL(texas_state_waste_code,'') AS texas_state_waste_code ,
	ISNULL(PA_residual_waste_flag,'')  AS PA_residual_waste_flag ,
	ISNULL(rcra_exempt_flag,'') AS rcra_exempt_flag ,
	ISNULL(rcra_exempt_reason,'') AS rcra_exempt_reason  ,
	ISNULL(cyanide_plating,'') AS cyanide_plating ,
	ISNULL(info_basis_analysis,'') AS info_basis_analysis ,
	ISNULL(info_basis_msds,'') AS info_basis_msds,
	ISNULL(info_basis_knowledge,'') AS info_basis_knowledge  ,
	@section_status AS IsCompleted,
	 CASE WHEN ISNULL(state_waste_code_flag,'') <>'' THEN state_waste_code_flag ELSE   
	 CASE WHEN ISNULL(state_waste_code_flag,'')='' AND stateWasteCode.wasteCodeCount>0 THEN 'F' ELSE 'T'  END END state_waste_code_flag,
	 CASE WHEN ISNULL(RCRA_waste_code_flag,'')<> '' THEN RCRA_waste_code_flag ELSE   
	 CASE WHEN ISNULL(RCRA_waste_code_flag,'') ='' AND rcrawasteCode.rcrawasteCodeCount>0 THEN 'F' ELSE 'T'  END END RCRA_waste_code_flag,
	--(SELECT *, (SELECT TOP 1 wc.waste_code_desc FROM plt_ai.dbo.WasteCode wc WHERE wc.waste_code = WasteCodes.waste_code ) as  waste_code_desc
	-- FROM FormXWasteCode as WasteCodes
	-- WHERE form_id = @formId and revision_id=@revisionId and specifier = 'PA'
	-- FOR XML AUTO,TYPE,ROOT ('Pennsylvania_Residual'), ELEMENTS),

	(SELECT form_id, revision_id, page_number, line_item, waste_code_uid, 
	(select (CAST(display_name as NVARCHAR(10)))  from dbo.WasteCode wc where wc.waste_code_uid=WasteCodes.waste_code_uid) as waste_code,
	 specifier,
	(SELECT TOP 1 wc.waste_code_desc FROM plt_ai.dbo.WasteCode wc WHERE wc.waste_code = WasteCodes.waste_code ) as  waste_code_desc
	 FROM FormXWasteCode as WasteCodes
	 WHERE form_id = @formId and revision_id=@revisionId and 
	 specifier = 'PA'
	  FOR XML AUTO,TYPE,ROOT ('Pennsylvania_Residual'), ELEMENTS),
	 (SELECT form_id,revision_id,page_number,line_item,waste_code_uid, 
	 (select TOP 1 haz_flag from dbo.WasteCode wc where wc.waste_code_uid=WasteCodes.waste_code_uid) haz_flag, 
	 (select ([state]+'-'+CAST(display_name as NVARCHAR(10))) from dbo.WasteCode wc where wc.waste_code_uid=WasteCodes.waste_code_uid) as waste_code,specifier 
	 FROM FormXWasteCode as WasteCodes
	 WHERE form_id = @formId and revision_id=@revisionId and specifier = 'state' order by waste_code
	 FOR XML AUTO,TYPE,ROOT ('StateWasteCodes'), ELEMENTS),
	  (SELECT distinct top 1 form_id,revision_id,page_number,line_item,waste_code_uid,(select (CAST(display_name as NVARCHAR(10)))  from dbo.WasteCode wc where wc.waste_code_uid=WasteCodes.waste_code_uid) as waste_code,specifier 
	 FROM FormXWasteCode as WasteCodes
	 WHERE form_id = @formId and revision_id=@revisionId and specifier = 'TX'
	 FOR XML AUTO,TYPE,ROOT ('TexasStateWasteCodes'), ELEMENTS),
	  (SELECT *
	 FROM FormXWasteCode as WasteCodes
	 WHERE form_id = @formId and revision_id=@revisionId and (specifier = 'rcra_characteristic' or specifier = 'rcra_listed') order by waste_code
	 FOR XML AUTO,TYPE,ROOT ('RCRACodes'), ELEMENTS),
		(SELECT 
			const_id,
			const_desc,
			--cast(min_concentration as varchar) as min_concentration,
			--cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),min_concentration ),'0',' ')),' ','0') as varchar) as min_concentration,
			REVERSE(SUBSTRING(REVERSE(SUBSTRING(
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),min_concentration ),'0',' ')),' ','0') as varchar), PATINDEX('%[^.]%', 
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),min_concentration ),'0',' ')),' ','0') as varchar)),99999)), 
								PATINDEX('%[^.]%', REVERSE(SUBSTRING(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),min_concentration ),'0',' ')),' ','0') as varchar), 
								PATINDEX('%[^.]%', cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),min_concentration ),'0',' ')),' ','0') as varchar)),99999))),99999)) as min_concentration,
			--CAST(CAST(min_concentration  AS FLOAT) AS bigint)as min_concentration,					
			concentration,
			ISNULL((RTRIM(LTRIM(unit))),'') as unit,
			ISNULL(uhc,'') AS uhc,
			specifier,
			CASE
				WHEN TCLP_or_totals='TCLP' THEN 'T'
				 WHEN TCLP_or_totals='Totals' THEN 'F' END TCLP_or_totals,			
			--cast(typical_concentration as varchar) as typical_concentration,
			-- cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),typical_concentration ),'0',' ')),' ','0') as varchar) as typical_concentration,
			REVERSE(SUBSTRING(REVERSE(SUBSTRING(
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),typical_concentration ),'0',' ')),' ','0') as varchar), PATINDEX('%[^.]%', 
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),typical_concentration ),'0',' ')),' ','0') as varchar)),99999)), 
								PATINDEX('%[^.]%', REVERSE(SUBSTRING(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),typical_concentration ),'0',' ')),' ','0') as varchar), 
								PATINDEX('%[^.]%', cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),typical_concentration ),'0',' ')),' ','0') as varchar)),99999))),99999)) as typical_concentration,

			--cast(max_concentration as varchar) as max_concentration,
			--cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),max_concentration ),'0',' ')),' ','0') as varchar) as max_concentration,

			REVERSE(SUBSTRING(REVERSE(SUBSTRING(
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),max_concentration ),'0',' ')),' ','0') as varchar), PATINDEX('%[^.]%', 
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),max_concentration ),'0',' ')),' ','0') as varchar)),99999)), 
								PATINDEX('%[^.]%', REVERSE(SUBSTRING(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),max_concentration ),'0',' ')),' ','0') as varchar), 
								PATINDEX('%[^.]%', cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),max_concentration ),'0',' ')),' ','0') as varchar)),99999))),99999)) as max_concentration,

			--CAST(CAST(typical_concentration  AS FLOAT) AS bigint)as typical_concentration,			
			--CAST(CAST(max_concentration  AS FLOAT) AS bigint)as max_concentration,			
			ISNULL(exceeds_LDR,'') AS exceeds_LDR,
			cor_lock_flag As cor_lock_flag
	 FROM FormXConstituent as ChemicalComposition 
	 WHERE form_id = @formId and revision_id=@revisionId ORDER by _Order 	
	 FOR XML AUTO,TYPE,ROOT ('ChemicalComposition') , ELEMENTS) 
    from FormWCR 
	OUTER APPLY(SELECT COUNT(*) wasteCodeCount FROM FormXWasteCode as WasteCodes WHERE form_id = @formId and revision_id=@revisionId and specifier = 'state') stateWasteCode
	OUTER APPLY(SELECT COUNT(*) rcrawasteCodeCount FROM FormXWasteCode as WasteCodes WHERE form_id = @formId and revision_id=@revisionId and specifier = 'rcra_characteristic') rcrawasteCode
    where form_id =  @formId and revision_id = @revisionId
    FOR XML RAW ('SectionE'), ROOT ('ProfileModel'), ELEMENTS

END


GO

	GRANT EXEC ON [dbo].[sp_FormWCR_SectionE_Select] TO COR_USER;

GO
	