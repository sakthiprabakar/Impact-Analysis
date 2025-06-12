
CREATE PROCEDURE [dbo].[sp_benzene_Select](
	
		 @form_id INT,
		 @revision_id	INT
		 --@wcr_id  INT,
         --@wcr_rev_id INT

)
AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_benzene_Select]

	Description	: 
                Procedure to get benzene profile details and status (i.e Clean, partial, completed)
				

	Input		:
				@form_id
				@revision_id
				
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_benzene_Select] 516343,1

*************************************************************************************/
BEGIN
DECLARE @section_status CHAR(1);
	SELECT @section_status=section_status FROM formsectionstatus WHERE form_id=@form_id and section='BZ'

	DECLARE @classified_as_process_wastewater_stream CHAR(1)
	DECLARE @classified_as_landfill_leachate CHAR(1)
	DECLARE @classified_as_product_tank_drawdown CHAR(1)

	DECLARE @classified_None CHAR(1)

	SELECT 
			@classified_as_process_wastewater_stream=classified_as_process_wastewater_stream,
			@classified_as_landfill_leachate=classified_as_landfill_leachate,
			@classified_as_product_tank_drawdown = classified_as_product_tank_drawdown 
		From FormBenzene
		Where wcr_id =  @form_id and wcr_rev_id = @revision_id

     IF @classified_as_process_wastewater_stream = 'F' AND @classified_as_landfill_leachate = 'F' AND @classified_as_product_tank_drawdown = 'F'
	  BEGIN
	   SET @classified_None = 'T'
	  END
	 ELSE
	  BEGIN
	   SET @classified_None = 'F'
	  END

SELECT
			COALESCE(Benzene.wcr_id, @form_id) as wcr_id,
			COALESCE(Benzene.wcr_rev_id, @revision_id) as wcr_rev_id,
			WCR.generator_name, 
            WCR.epa_id  As generator_epa_id,
            WCR.waste_common_name, 
            WCR.gen_process,  
            WCR.signing_name,
            WCR.signing_title,
            WCR.signing_date, 
			Benzene.form_id,
			Benzene.revision_id,
			Benzene.locked,
			Benzene.type_of_facility,
			Benzene.tab_lt_1_megagram,
			Benzene.tab_gte_1_and_lt_10_megagram,
			Benzene.tab_gte_10_megagram,
			Benzene.benzene_onsite_mgmt,
			CAST(Benzene.flow_weighted_annual_average_benzene AS DECIMAL(18,6)) AS flow_weighted_annual_average_benzene,
			Benzene.avg_h20_gr_10,
			Benzene.is_process_unit_turnaround,
			--CONVERT(decimal(18,8), CAST(Benzene.benzene_range_from AS FLOAT)) as benzene_range_from,
			--CONVERT(decimal(18,8), CAST(Benzene.benzene_range_to AS FLOAT)) as benzene_range_to,
			CAST(Benzene.benzene_range_from AS DECIMAL(18,6)) As benzene_range_from,
			CAST(Benzene.benzene_range_to AS DECIMAL(18,6)) AS benzene_range_to,
			Benzene.classified_as_process_wastewater_stream,
			Benzene.classified_as_landfill_leachate,
			Benzene.classified_as_product_tank_drawdown,
			(@classified_None) AS classified_None,
			Benzene.created_by,
			Benzene.date_created,
			Benzene.modified_by,
			Benzene.date_modified,
			Benzene.originating_generator_name,
			Benzene.originating_generator_epa_id
			,@section_status AS IsCompleted
	FROM  FormBenzene AS Benzene 
	 JOIN  FormWCR AS WCR ON Benzene.wcr_id = WCR.form_id AND Benzene.wcr_rev_id = WCR.revision_id

	WHERE 
          WCR.form_id = @form_id and  WCR.revision_id = @revision_id

	  FOR XML RAW ('benzene'), ROOT ('ProfileModel'), ELEMENTS
	  
END
	    
GO

	GRANT EXECUTE ON [dbo].[sp_benzene_Select] TO COR_USER;

GO	

		