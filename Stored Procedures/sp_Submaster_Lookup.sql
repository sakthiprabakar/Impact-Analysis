
CREATE PROCEDURE [dbo].[sp_Submaster_Lookup]

@section varchar(3)=''
AS
/* ******************************************************************

	Updated By		: Meenachi Sundar
	Updated On		: 14th Nov 2018
	Type			: Stored Procedure
	Object Name		: [sp_Submaster_Lookup]


	Procedure is used to Profile Section Drop down binding Master values i.e for the sectionA to sectionH bind the dropdown values

inputs 
	
	@section



Samples:
 EXEC sp_Submaster_Lookup @section
 EXEC [sp_Submaster_Lookup] 'CR'

****************************************************************** */

BEGIN

--declare @section varchar(3)='B'
--SECTION B	
IF(@section ='B')
BEGIN 
declare @xml xml;
--Source Code, Form Code
	SELECT @xml = ( SELECT
	   (SELECT EPA_source_code,EPA_source_code+ ' '+ [description] [description] FROM dbo.EPASourceCode WITH(NOLOCK) ORDER BY 
	EPA_source_code  FOR XML PATH('SourceCode'), TYPE) ,
	   (SELECT A.EPA_form_code,A.EPA_form_code + ' '+ B.[description] [description] FROM dbo.EPAFormCode A WITH(NOLOCK) INNER JOIN 
	dbo.EPAFormCodeDescription B WITH(NOLOCK) ON A.EPA_form_code = B.epa_form_code ORDER BY A.EPA_form_code  FOR XML PATH('FormCode'), TYPE) 
		FOR XML PATH(''), ROOT('SectionB') ) 
		SELECT @xml AS SECTION
END

ELSE IF(@section ='C')
BEGIN

	SELECT(SELECT
	 (SELECT manifest_code, manifest_desc FROM ManifestCodeLookup WITH(NOLOCK) WHERE manifest_item = 'hazmat_class' AND  manifest_code != '' and manifest_code IS NOT NULL ORDER BY manifest_code FOR XML PATH('HazardClass'), TYPE) ,
	  (SELECT manifest_code, manifest_desc FROM dbo.ManifestCodeLookup WHERE manifest_item = 'erg' AND  manifest_code != '' and manifest_code IS NOT NULL ORDER BY manifest_code FOR XML PATH('ERGs'), TYPE) ,
	   (SELECT bill_unit_code, bill_unit_desc FROM BillUnit WHERE container_flag = 'T' AND disposal_flag = 'T' FOR XML PATH('ContainerSize'), TYPE) ,
	   (SELECT bill_unit_code, bill_unit_desc FROM BillUnit WHERE disposal_flag = 'T' AND bill_unit_code NOT IN ('CASE', 'CNT','SPEC','WASH') AND manifest_unit IS NOT NULL FOR XML PATH('Units'), TYPE) 
		--FOR XML PATH(''), ROOT('SectionC') )  AS  SECTION
		FOR XML Path('SectionC')
  --, ROOT('SectionC')   
  )AS  SECTION  

END
ELSE IF(@section ='D')
BEGIN
--Color
	SELECT(SELECT(SELECT * FROM Color WHERE  color != '' and color IS NOT NULL ORDER BY color  FOR XML PATH(''), TYPE) AS 'Color' FOR XML PATH(''), ROOT('SectionD'))   AS  SECTION
	
END
ELSE IF(@section ='E')  
BEGIN  
  
--SELECT *  INTO #tmp FROM dbo.WasteCode WITH(NOLOCK)  
  
--Pennsylvania Residual Waste Codes, State Waste Codes, RCRA Waste Codes  
 --SELECT(SELECT  
 -- (SELECT waste_code_uid, [state], display_name AS waste_code, waste_code_desc, 'state' AS specifier  FROM #tmp WHERE [status] = 'A'   
 --AND waste_code_origin = 'S' AND [state] = 'PA' ORDER BY [state], display_name FOR XML PATH(''), TYPE) AS 'PennsylvaniaResidualWasteCodes',  
 --   (SELECT waste_code_uid, [state], display_name AS waste_code, waste_code_desc, 'state' AS specifier   
 --FROM #tmp WHERE [status] = 'A' AND waste_code_origin = 'S'  ORDER BY [state], display_name FOR XML PATH(''), TYPE) AS 'StateWasteCodes',  
 --   (SELECT waste_code_uid, display_name AS waste_code, waste_code_desc, (CASE waste_type_code WHEN 'L' THEN 'rcra_listed' WHEN 'C'   
 --THEN 'rcra_characteristic' ELSE 'ERROR' END) AS specifier FROM #tmp WHERE [status] = 'A' AND waste_code_origin = 'F' AND haz_flag =   
 --'T' AND waste_type_code IN ('L', 'C') ORDER BY display_name FOR XML PATH(''), TYPE) AS 'RCRAWasteCodes'  
 -- FOR XML PATH(''), ROOT('SectionE') )  AS  SECTION  
  
  
-- DROP TABLE #tmp  
SELECT (SELECT constituent_unit, case when constituent_unit = '%' then 'percentage(%)' else constituent_unit end unit_description FROM dbo.ConstituentUnit Order By unit_description Asc  FOR XML PATH('Units'), ROOT('SectionE'))  AS  SECTION  
--SELECT * FROM 

END  
ELSE IF(@section ='H')
BEGIN

--Requested US Ecology Facility
	SELECT (SELECT company_id, profit_ctr_id, profit_ctr_name FROM ProfitCenter  WITH(NOLOCK)  WHERE status = 'A' AND waste_receipt_flag = 'T'
	FOR XML RAW ('USEcologyFacility'), ROOT ('SectionH'), ELEMENTS)  AS  SECTION
END
ELSE IF(@section ='DA')  
BEGIN  
--Requested US Ecology Facility  
 SELECT (
 SELECT  *  FROM    plt_image..ScanDocumentType where type_code like 'COR%' ORDER BY document_type ASC
 --SELECT * from [plt_image].[dbo].[ScanDocumentType]  WITH(NOLOCK)  WHERE scan_type ='approval' ORDER BY document_type ASC
 --FOR XML PATH('SourceCode'), TYPE)
  FOR XML PATH('DocumentSource'), ROOT ('Document'), Elements) AS  SECTION  
END
ELSE IF(@section = 'GK')
BEGIN
Select (
	Select *  from PPECode FOR XML RAW ('PPECode'), ROOT ('GeneratorKnowledge'), ELEMENTS)  AS  SECTION
END
ELSE IF(@section = 'CR')
BEGIN
Select (
	SELECT * FROM plt_ai..CylinderType FOR XML RAW ('Size'), ROOT ('Cylinder'), ELEMENTS)  AS  SECTION	
END
ELSE
BEGIN

--Generator NAICS Code
	SELECT (SELECT * FROM dbo.NAICSCode WITH(NOLOCK) FOR XML RAW ('Generator_NAICS_Code'), ROOT ('SectionA'), ELEMENTS)  AS  SECTION

END

END


GO

	GRANT EXEC ON [dbo].[sp_Submaster_Lookup] TO COR_USER;

GO