USE [PLT_AI]
GO

CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_Radioactive](	
		 	@profileId INT
)
AS
/***********************************************************************************
 
    Updated By    : Vinoth D
    Updated On    : 22-Aug-2023
    Type          : Store Procedure 
    Object Name   : [sp_Profile_Select_Section_Radioactive]
	Ticket		  : 67291
 
  
     Procedure to get Radioactive profile details
                                                    
    Execution Statement    
	
	EXEC  [dbo].[sp_Profile_Select_Section_Radioactive] 893442

	Updated By		: Karuppiah
	Updated On		: 10th Dec 2024
	Type			: Stored Procedure
	Ticket   		: Titan-US134197,US132686,US134198,US127722
	Change			: Const_id added.
 
*************************************************************************************/
BEGIN
		SELECT
		uranium_thorium_flag,
		radium_226_flag,
		radium_228_flag,
		lead_210_flag,
		potassium_40_flag,
		exempt_byproduct_material_flag,
		special_nuclear_material_flag,
		accelerator_flag,
		generated_in_particle_accelerator_flag,
		approved_for_disposal_flag,
		approved_by_nrc_flag,
		approved_for_alternate_disposal_flag,
		nrc_exempted_flag,
		released_from_radiological_control_flag,
		DOD_non_licensed_disposal_flag,
		USEI_WAC_table_C1_flag,
		USEI_WAC_table_C2_flag,
		USEI_WAC_table_C3_flag,
		USEI_WAC_table_C4a_flag,
		USEI_WAC_table_C4b_flag,
		USEI_WAC_table_C4c_flag,
		waste_type,
		GETDATE() AS signing_date,
		uranium_concentration,
		modified_by,
		date_modified,
		uranium_source_material,  
    (SELECT profile_id, line_id, item_name, total_number_in_shipment, radionuclide_contained,      
    ISNULL(convert(varchar(10),activity),'') AS activity  
      ,[disposal_site_tsdf_code]  
      ,[cited_regulatory_exemption]  
      ,[added_by]  
      ,[date_added]  
      ,[modified_by]  
      ,[date_modified]   
      FROM ProfileRadioactiveExempt as ProfileRadioactiveExempt    
      WHERE  ProfileRadioactiveExempt.profile_id = @profileId    
      FOR XML AUTO,TYPE,ROOT ('RadioactiveExempt'), ELEMENTS),    
       (SELECT profile_id, line_id, radionuclide,  ISNULL(convert(varchar(10),concentration),'') AS concentration, CONST_ID as const_id, added_by, date_added, modified_by, date_modified    
      FROM ProfileRadioactiveUSEI as ProfileRadioactiveUSEI    
      WHERE  ProfileRadioactiveUSEI.profile_Id = @profileId    
      FOR XML AUTO,TYPE,ROOT ('RadioactiveUSEI'), ELEMENTS)   
		FROM  ProfileRadioactive WHERE profile_Id = @profileId 

	    FOR XML RAW ('Radioactive'), ROOT ('ProfileModel'), ELEMENTS XSINIL
END

	
GO
	
	GRANT EXEC ON [dbo].[sp_Profile_Select_Section_Radioactive] TO COR_USER;

GO
