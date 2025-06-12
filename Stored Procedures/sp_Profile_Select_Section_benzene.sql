CREATE   PROCEDURE [dbo].[sp_Profile_Select_Section_benzene](
	
		 @profileId INT

)
AS
/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_benzene]

	Description	: 
                  Procedure to get benzene profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_benzene] 893442

*************************************************************************************/
SELECT
			ISNULL( Benzene.originating_generator_name,'') AS originating_generator_name,
			ISNULL( Benzene.originating_generator_epa_id,'') AS originating_generator_epa_id,
			ISNULL( Benzene.type_of_facility,'') AS type_of_facility,
			ISNULL( Benzene.tab_lt_1_megagram,'') AS tab_lt_1_megagram,
			ISNULL( Benzene.tab_gte_1_and_lt_10_megagram,'') AS tab_gte_1_and_lt_10_megagram,
			ISNULL( Benzene.tab_gte_10_megagram,'') AS tab_gte_10_megagram,
			ISNULL( Benzene.flow_weighted_annual_average_benzene,'') AS flow_weighted_annual_average_benzene,
			ISNULL( Benzene.is_process_unit_turnaround,'') AS is_process_unit_turnaround,
			ISNULL( Benzene.benzene_range_from,'') AS benzene_range_from,
			ISNULL( Benzene.benzene_range_to,'') AS benzene_range_to,
			ISNULL( Benzene.classified_as_process_wastewater_stream,'') AS classified_as_process_wastewater_stream,
			ISNULL( Benzene.classified_as_landfill_leachate,'') AS classified_as_landfill_leachate,
			ISNULL( Benzene.classified_as_product_tank_drawdown,'') AS classified_as_product_tank_drawdown,
			--ISNULL( Benzene.created_by,'') AS created_by,
			--ISNULL( Benzene.date_created,'') AS date_created,
			ISNULL( Benzene.modified_by,'') AS modified_by,
			ISNULL( Benzene.date_modified,'') AS date_modified,
			ISNULL( PL.benzene_onsite_mgmt,'') AS benzene_onsite_mgmt
			--ISNULL( PL.avg_h20_gt_10,'') AS avg_h20_gr_10

				

	FROM  ProfileBenzene AS Benzene 

	 JOIN  ProfileLab AS PL ON Benzene.profile_Id =PL.profile_Id

	

	WHERE 

		Benzene.profile_Id = @profileId 

	     FOR XML RAW ('benzene'), ROOT ('ProfileModel'), ELEMENTS
			

	  GO

GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_benzene] TO COR_USER;

GO