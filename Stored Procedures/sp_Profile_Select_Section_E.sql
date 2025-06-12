CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_E]
     @profileId int 
AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_E]

	Description	: 
                  Procedure to get Section E profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_E] 652046

*************************************************************************************/
BEGIN
	SELECT  ISNULL(p.texas_waste_material_type,0) AS texas_waste_material_type ,
	 ISNULL(p.texas_state_waste_code,'')  AS texas_state_waste_code ,
	 ISNULL(p.PA_residual_waste_flag,0)  AS PA_residual_waste_flag ,
	 ISNULL(p.rcra_exempt_flag,'') AS rcra_exempt_flag ,
	 ISNULL(p.rcra_exempt_reason,'') AS rcra_exempt_reason  ,
	 ISNULL(pl.cyanide_plating,'') AS cyanide_plating ,
	 ISNULL(pl.info_basis_analysis,0) AS info_basis_analysis ,
	 ISNULL(pl.info_basis_msds,0) AS info_basis_msds,
	 ISNULL(pl.info_basis_knowledge,0) AS info_basis_knowledge  ,
	 CASE WHEN p.RCRA_Waste_Code_Flag = 'F' THEN 'T' WHEN p.RCRA_Waste_Code_Flag = 'T' THEN 'F' ELSE '' END as RCRA_waste_code_flag,
	 CASE WHEN pl.state_waste_code_flag = 'F' THEN 'T' WHEN pl.state_waste_code_flag = 'T' THEN 'F' ELSE '' END as state_waste_code_flag,
	 --ISNULL(p.RCRA_waste_code_flag, '') as RCRA_waste_code_flag,
	 -- ISNULL(pl.state_waste_code_flag, '') as state_waste_code_flag,
	--ISNULL((Select waste_code_uid from ProfileWasteCode where profile_id = @profileId  ),0) AS PRWC, -- and specifier = 'primary'
	--ISNULL((Select waste_code_uid from ProfileWasteCode where profile_id = @profileId  ),0) AS SWC, -- and specifier = 'state'
	--ISNULL((Select waste_code_uid from ProfileWasteCode where profile_id = @profileId ),0) AS RCRA, --and specifier = 'rcra_listed'
	 (SELECT waste_code_uid, [state], display_name AS waste_code, (CAST(display_name as NVARCHAR(10)) + '-'+ waste_code_desc) as waste_code_desc, 'PA' AS specifier FROM dbo.WasteCode WasteCodes
	 WHERE 	WasteCodes.waste_code_uid IN (SELECT P.waste_code_uid from profilewastecode P where p.profile_id = @profileId) AND [status] = 'A' AND waste_code_origin = 'S' AND [state] = 'PA' ORDER BY [state], display_name --and specifier = 'PA'
	 FOR XML AUTO,TYPE,ROOT ('Pennsylvania_Residual'), ELEMENTS),

	 (SELECT  waste_code_uid, [state], ([state]+'-'+CAST(display_name as NVARCHAR(10))) AS waste_code, ([state]+'-'+CAST(display_name as NVARCHAR(10)) + '-'+ waste_code_desc) as waste_code_desc, 'state' AS specifier,haz_flag FROM dbo.WasteCode WasteCodes  
	 WHERE [status] = 'A' AND WasteCodes.waste_code_uid IN (SELECT P.waste_code_uid from profilewastecode P where p.profile_id = @profileId AND P.waste_code <> 'NONE') AND waste_code_origin = 'S'  AND [state] <> 'TX' AND [state] <> 'PA'  ORDER BY [state], display_name --and specifier = 'state'
	 FOR XML AUTO,TYPE,ROOT ('StateWasteCodes'), ELEMENTS),

	 (SELECT waste_code_uid, display_name AS waste_code, waste_code_desc, (CASE waste_type_code WHEN 'L' THEN 'rcra_listed' WHEN 'C' THEN 'rcra_characteristic' ELSE 'ERROR' END) AS specifier FROM dbo.WasteCode WasteCodes 
	 WHERE WasteCodes.waste_code_uid IN (SELECT P.waste_code_uid from profilewastecode P where p.profile_id = @profileId AND P.waste_code <> 'NONE' ) AND [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C') ORDER BY display_name --and specifier = 'rcra_listed'
	 FOR XML AUTO,TYPE,ROOT ('RCRACodes'), ELEMENTS),

	 (SELECT waste_code_uid,[state], display_name AS waste_code, waste_code_desc, 'TX' AS specifier FROM dbo.WasteCode WasteCodes 
	 WHERE WasteCodes.waste_code_uid IN (SELECT P.waste_code_uid from profilewastecode P where p.profile_id = @profileId AND P.waste_code <> 'NONE' and P.Texas_primary_flag = 'T') AND [status] = 'A' AND [state] = 'TX' ORDER BY display_name --and specifier = 'TX'
	 FOR XML AUTO,TYPE,ROOT ('TexasStateWasteCodes'), ELEMENTS),
	 
	(SELECT (select const_desc from constituents where const_id = ChemicalComposition.const_id) as const_desc,
	CASE WHEN ChemicalComposition.TCLP_flag = 'TCLP' THEN 'T' WHEN ChemicalComposition.TCLP_flag = 'Totals' THEN 'F' ELSE 
	ISNULL(ChemicalComposition.TCLP_flag, '') END as TCLP_or_totals,
	--ISNULL(CAST(CAST(ChemicalComposition.typical_concentration  AS FLOAT) AS  varchar(20)),'')as typical_concentration,
	--ISNULL(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.typical_concentration ),'0',' ')),' ','0') as varchar),'')as typical_concentration,
	ISNULL(REVERSE(SUBSTRING(REVERSE(SUBSTRING(
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.typical_concentration ),'0',' ')),' ','0') as varchar), PATINDEX('%[^.]%', 
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.typical_concentration ),'0',' ')),' ','0') as varchar)),99999)), 
								PATINDEX('%[^.]%', REVERSE(SUBSTRING(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.typical_concentration ),'0',' ')),' ','0') as varchar), 
								PATINDEX('%[^.]%', cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.typical_concentration ),'0',' ')),' ','0') as varchar)),99999))),99999)),'')as typical_concentration,
	--ISNULL(CAST(CAST(ChemicalComposition.min_concentration  AS FLOAT) AS varchar(20)),'')as min_concentration,
	--ISNULL(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.min_concentration ),'0',' ')),' ','0') as varchar),'')as min_concentration,
	
	ISNULL(REVERSE(SUBSTRING(REVERSE(SUBSTRING(
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.min_concentration ),'0',' ')),' ','0') as varchar), PATINDEX('%[^.]%', 
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.min_concentration ),'0',' ')),' ','0') as varchar)),99999)), 
								PATINDEX('%[^.]%', REVERSE(SUBSTRING(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.min_concentration ),'0',' ')),' ','0') as varchar), 
								PATINDEX('%[^.]%', cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.min_concentration  ),'0',' ')),' ','0') as varchar)),99999))),99999)),'')as min_concentration,
	--ISNULL(CAST(CAST(ChemicalComposition.concentration  AS FLOAT) AS  varchar(20)),'')as max_concentration,	
	--ISNULL(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.concentration ),'0',' ')),' ','0') as varchar),'')as max_concentration,
	ISNULL(REVERSE(SUBSTRING(REVERSE(SUBSTRING(
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.concentration),'0',' ')),' ','0') as varchar), PATINDEX('%[^.]%', 
												cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.concentration ),'0',' ')),' ','0') as varchar)),99999)), 
								PATINDEX('%[^.]%', REVERSE(SUBSTRING(cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.concentration ),'0',' ')),' ','0') as varchar), 
								PATINDEX('%[^.]%', cast(Replace(RTRIM(Replace(Convert(DECIMAL(18,8),ChemicalComposition.concentration ),'0',' ')),' ','0') as varchar)),99999))),99999)),'')as max_concentration,

	ISNULL(ChemicalComposition.profile_id,'')profile_id,	
	ISNULL(ChemicalComposition.const_id,'')const_id,	
	ISNULL(ChemicalComposition.unit,'')unit,	
	ISNULL(ChemicalComposition.UHC,'')uhc,	
	-- ISNULL((select  Constituent.UHC_Flag from plt_ai..constituents Constituent where Constituent.const_id=ChemicalComposition.const_id),'')uhc,
	ISNULL(ChemicalComposition.added_by,'')added_by,	
	ISNULL(ChemicalComposition.date_added,'')date_added,	
	ISNULL(ChemicalComposition.modified_by,'')modified_by,	
	ISNULL(ChemicalComposition.date_modified,'')date_modified,	
	ISNULL(ChemicalComposition.rowguid,'')rowguid,	
	--ISNULL(ChemicalComposition.typical_concentration, '') as typical_concentration, *
	ISNULL(exceeds_LDR,'') AS exceeds_LDR,
	cor_lock_flag As cor_lock_flag
	 FROM ProfileConstituent as ChemicalComposition 
	 WHERE profile_id = @profileId
	 FOR XML AUTO,TYPE,ROOT ('ChemicalComposition'), ELEMENTS)
    from Profile AS p
    Join ProfileLab as pl ON p.profile_id = pl.profile_id
    where p.profile_id =  @profileId  AND pl.[type] = 'A'
    FOR XML RAW ('SectionE'), ROOT ('ProfileModel'), ELEMENTS
	

	--SELECT TOP 1 * FROM PROFILE
 --   SELECT TOP 1 * FROM ProfileLab
 -- select top 1 * from ProfileConstituent ORDER BY profile_id DESC
  -- select top 1 * from ProfileWasteCode
--SELECT_SECTIONF

END

GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_E] TO COR_USER;

GO