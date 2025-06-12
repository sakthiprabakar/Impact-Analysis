USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_SectionE_State_WasteCode]
GO

-- =============================================
-- Author:		Dinesh
-- Create date: 08-Dec-2018
-- Type: Stored Procedure
-- Object Name : [dbo].[sp_SectionE_State_WasteCode]
-- ===============================================

CREATE PROCEDURE [dbo].[sp_SectionE_State_WasteCode]
@CodeType VARCHAR(3),
@searchText varchar(200)
AS
/* ******************************************************************

procedure to list out the Waste Code based on Waste code Type

i.e) 
   1) If Code Type is 'ST', It list out State Waste Codes
   2) If Code Type is 'RC', It list out RCRA Waste Codes
   3) If Code Type is 'PA', Pennsylvania Residual Waste codes will be list

inputs 
	
    CodeType
	searchText

Returns

	waste_code_uid
	state
	waste_code
	waste_code_desc
	specifier

Samples:

EXEC [dbo].[sp_SectionE_State_WasteCode] 'PA', '703'
EXEC [dbo].[sp_SectionE_State_WasteCode] 'ST', '311'

****************************************************************** */
BEGIN
--IF(@searchText!='')
--BEGIN


--SELECT( SELECT
--	   DISTINCT texas_state_waste_code FROM FormWCR WITH(NOLOCK) 
--	   WHERE texas_state_waste_code LIKE '%'+@searchText+'%')

--END

IF @CodeType = 'ST'
BEGIN
	--SELECT waste_code_uid, display_name AS waste_code, waste_code_desc, (CASE waste_type_code WHEN 'L' THEN 'rcra_listed' WHEN 'C' THEN 'rcra_characteristic' ELSE 'ERROR' END) AS specifier FROM dbo.WasteCode WHERE (waste_code like'%'+@searchText+'%' OR waste_code_desc like'%'+@searchText+'%') AND [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C') ORDER BY display_name
	SELECT  waste_code_uid, [state], ([state]+'-'+CAST(display_name as NVARCHAR(10))) AS waste_code, 
	([state]+'-'+CAST(display_name as NVARCHAR(10)) + '-'+ waste_code_desc) as waste_code_desc, 'state' AS specifier,haz_flag FROM dbo.WasteCode 
	WHERE [status] = 'A' AND (waste_code like'%'+@searchText+'%' OR waste_code_desc like'%'+@searchText+'%') AND waste_code_origin = 'S' AND [state] <> 'TX' AND [state] <> 'PA'  
	and display_name not like '%donotuse%'
	ORDER BY [state], display_name
END
ELSE IF @CodeType = 'RC'
BEGIN
	SELECT waste_code_uid, display_name AS waste_code, (display_name +' - '+ waste_code_desc) as waste_code_desc, 
	(CASE waste_type_code WHEN 'L' THEN 'rcra_listed' WHEN 'C' THEN 'rcra_characteristic' ELSE 'ERROR' END) AS specifier FROM dbo.WasteCode 
	WHERE (waste_code like'%'+@searchText+'%' OR waste_code_desc like'%'+@searchText+'%') AND [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 'T' 
	AND waste_type_code IN ('L', 'C') 
	and display_name not like '%donotuse%'
	ORDER BY display_name
END
ELSE IF @CodeType = 'PA'
BEGIN
	SELECT waste_code_uid, [state], display_name AS waste_code, (CAST(display_name as NVARCHAR(10)) + '-'+ waste_code_desc) as waste_code_desc, 
	'state' AS specifier FROM dbo.WasteCode WHERE (waste_code like '%'+ @searchText +'%' OR waste_code_desc like '%'+ @searchText +'%') AND [status] = 'A' 
	AND waste_code_origin = 'S' AND [state] = 'PA' 
	and display_name not like '%donotuse%'
	ORDER BY [state], display_name
END
ELSE IF @CodeType = 'TX'
BEGIN
	SELECT waste_code_uid, display_name as waste_code, 'TX' as specifier 
	from WasteCode where state ='TX' and (display_name like + '%' + @searchText + '%'  OR  WASTE_code like + '%' + @searchText + '%') AND [status] = 'A' 
	and display_name not like '%donotuse%'
	ORDER BY [state], display_name
END

END


GO

	GRANT EXEC ON [dbo].[sp_SectionE_State_WasteCode] TO COR_USER;

GO





	
	
	
	
	

