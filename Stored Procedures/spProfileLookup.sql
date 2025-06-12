
-- =============================================
-- Author:		<SUNDAR>
-- Create date: <14Nov2018>
-- Description:	<Profile Section Drop down binding Master values>
-- EXEC [spProfileLookup] 'e'

-- =============================================
CREATE PROCEDURE [dbo].[spProfileLookup]

@section varchar(3)=''
AS
BEGIN

--SECTION B	
IF(@section ='B')
BEGIN 

--Source Code, Form Code
	SELECT
	   (SELECT EPA_source_code, [description] FROM dbo.EPASourceCode WITH(NOLOCK) ORDER BY 
	EPA_source_code  FOR XML PATH(''), TYPE) AS 'SourceCode',
	   (SELECT A.EPA_form_code, B.[description] FROM dbo.EPAFormCode A WITH(NOLOCK) INNER JOIN 
	dbo.EPAFormCodeDescription B WITH(NOLOCK) ON A.EPA_form_code = B.epa_form_code ORDER BY A.EPA_form_code  FOR XML PATH(''), TYPE) AS 'Formcode'
		FOR XML PATH(''), ROOT('SectionB') 
END

ELSE IF(@section ='C')
BEGIN

	SELECT
	 (SELECT manifest_code, manifest_desc FROM ManifestCodeLookup WITH(NOLOCK) WHERE manifest_item = 'hazmat_class' ORDER BY manifest_code FOR XML PATH(''), TYPE) AS 'HazardClass',
	  (SELECT manifest_code FROM dbo.ManifestCodeLookup WHERE manifest_item = 'erg' ORDER BY manifest_code FOR XML PATH(''), TYPE) AS 'ERG',
	   (SELECT bill_unit_code, bill_unit_desc FROM BillUnit WHERE container_flag = 'T' AND disposal_flag = 'T' FOR XML PATH(''), TYPE) AS 'ContainerSize',
	   (SELECT bill_unit_code, bill_unit_desc FROM BillUnit WHERE disposal_flag = 'T' FOR XML PATH(''), TYPE) AS 'Units'
		FOR XML PATH(''), ROOT('SectionC') 

END
ELSE IF(@section ='D')
BEGIN
--Color
	SELECT(SELECT * FROM Color   FOR XML PATH(''), TYPE) AS 'Color' FOR XML PATH(''), ROOT('SectionD') 
	
END
ELSE IF(@section ='E')
BEGIN

SELECT *  INTO #tmp FROM dbo.WasteCode WITH(NOLOCK)

--Pennsylvania Residual Waste Codes, State Waste Codes, RCRA Waste Codes
	SELECT
	 (SELECT waste_code_uid, [state], display_name AS waste_code, waste_code_desc, 'state' AS specifier  FROM #tmp WHERE [status] = 'A' 
	AND waste_code_origin = 'S' AND [state] = 'PA' ORDER BY [state], display_name FOR XML PATH(''), TYPE) AS 'PennsylvaniaResidualWasteCodes',
	   (SELECT waste_code_uid, [state], display_name AS waste_code, waste_code_desc, 'state' AS specifier 
	FROM #tmp WHERE [status] = 'A' AND waste_code_origin = 'S'  ORDER BY [state], display_name FOR XML PATH(''), TYPE) AS 'StateWasteCodes',
	   (SELECT waste_code_uid, display_name AS waste_code, waste_code_desc, (CASE waste_type_code WHEN 'L' THEN 'rcra_listed' WHEN 'C' 
	THEN 'rcra_characteristic' ELSE 'ERROR' END) AS specifier FROM #tmp WHERE [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 
	'T' AND waste_type_code IN ('L', 'C') ORDER BY display_name FOR XML PATH(''), TYPE) AS 'RCRAWasteCodes'
		FOR XML PATH(''), ROOT('SectionE') 


	DROP TABLE #tmp
END
ELSE IF(@section ='H')
BEGIN

--Requested US Ecology Facility
	SELECT (SELECT company_id, profit_ctr_id, profit_ctr_name FROM ProfitCenter  WITH(NOLOCK)  WHERE status = 'A' AND waste_receipt_flag = 'T'
	FOR XML RAW ('USEcologyFacility'), ROOT ('SectionH'), ELEMENTS)  AS  USEcologyFacility
END
ELSE
BEGIN

--Generator NAICS Code
	SELECT (SELECT * FROM dbo.NAICSCode WITH(NOLOCK) FOR XML RAW ('Generator_NAICS_Code'), ROOT ('SectionA'), ELEMENTS)  AS  Generator_NAICS_Code

END


END
