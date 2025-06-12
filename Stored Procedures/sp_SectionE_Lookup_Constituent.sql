
-- =============================================
-- Author:		Prabhu
-- Create date: 17-Dec-2018
-- Description:	This procedure is used to searchtext for Constituent i.e searchkey value is loaded for SectionE Constituent

-- EXEC [dbo].[sp_SectionE_Lookup_Constituent] '5'

-- =============================================
CREATE PROCEDURE [dbo].[sp_SectionE_Lookup_Constituent]
 
@searchText varchar(200)=''
AS


/* ******************************************************************

procedure to get Constituent based on Search Text

inputs 
	
  searchText

Returns

	const_desc
	const_type
	CAS_code
	TRI
	DHS
	VOC
	HAP
	const_alpha-desc
	vapor_pressure
	molecular_weight
	density
	diluent_flag
	diluent_ppm
	TRI_category
	DES_flag
	LDR_id
	DDVOC
	www_metal
	generic_flag
	generic_unit
	generic_concentration
	CAAVOC
	HL
	FM25D
	FM305
	univ_treatment-std_nww
	univ_treatment-std_nww_unit
	air_permit_restricted
	threshold_value
	reportable_nuclide
	PCB_flag


Samples:
 EXEC [dbo].[sp_SectionE_Lookup_Constituent] ''

****************************************************************** */

BEGIN
--IF(@searchText!='')
--BEGIN
 
    -- Constituent #
   SELECT (SELECT DISTINCT uhc_flag as uhc, * FROM dbo.Constituents WITH(NOLOCK) 
	-- or const_id LIKE '%'+@searchText+'%'
    WHERE (const_desc not like '%DO NOT USE%') and  (ISNULL(@searchText,'') = '' or const_desc LIKE '%'+@searchText+'%' or CAS_code like '%'+@searchText+'%' )
    ORDER BY const_id, const_desc  FOR JSON PATH, ROOT('Constituents'))AS Constituents 
    
     
--END

 
END

GO

	GRANT EXEC ON [dbo].[sp_SectionE_Lookup_Constituent] TO COR_USER;

GO

