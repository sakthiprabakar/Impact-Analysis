ALTER PROCEDURE dbo.sp_benzene_insert_update
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************
	Updated By		: SenthilKumar
	Updated On		: 26th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_benzene_insert_update]
	
   Updated By   : Ranjini C
   Updated On   : 08-AUGUST-2024
   Ticket       : 93217
   Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
	Procedure to insert update PCB supplementry forms

	--Updated by Blair Christensen for Titan 05/21/2025
inputs @Data, @form_id, @revision_id
Samples:
 EXEC [sp_benzene_insert_update] @Data,@formId,@revisionId
 EXEC [sp_benzene_insert_update] '<Benzene>
--<benzene_range_from>1.0</benzene_range_from>
--<benzene_range_to>3.0</benzene_range_to>
--<classified_as_landfill_leachate>T</classified_as_landfill_leachate>
--<classified_as_process_wastewater_stream>T</classified_as_process_wastewater_stream>
--<classified_as_product_tank_drawdown>T</classified_as_product_tank_drawdown>
--<created_by>Local</created_by>
--<generator_epa_id>1</generator_epa_id>
--<flow_weighted_annual_average_benzene>2.0</flow_weighted_annual_average_benzene>
--<form_id>427534</form_id>
--<gen_process>fdsfds</gen_process>
--<generator_name>tested</generator_name>
--<is_process_unit_turnaround>T</is_process_unit_turnaround>
--<locked>U</locked>
--<modified_by>localtest</modified_by>
--<revision_id>1</revision_id>
--<signing_date>2018-12-12 00:00:00</signing_date>
--<signing_name>local signing_name</signing_name>
--<signing_title>local signing_title</signing_title>
--<tab_gte_10_megagram>T</tab_gte_10_megagram>
--<tab_gte_1_and_lt_10_megagram>T</tab_gte_1_and_lt_10_megagram>
--<tab_lt_1_megagram>T</tab_lt_1_megagram>
--<type_of_facility>T</type_of_facility>
--<waste_common_name>waste common</waste_common_name>
--<wcr_id>427534</wcr_id>
--<wcr_rev_id>1</wcr_rev_id>
--</Benzene>', 427534 ,1
***********************************************************************/
BEGIN
	IF NOT EXISTS (SELECT 1 FROM dbo.FormBenzene WHERE wcr_id = @form_id and wcr_rev_id = @revision_id)
		BEGIN
			DECLARE @newForm_id INTEGER
				  , @newrev_id INTEGER = 1
				  , @FormWCR_uid INTEGER;

			EXEC @newForm_id = sp_sequence_next 'form.form_id';

			IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id AND revision_id = @revision_id)
				BEGIN
					SELECT @FormWCR_uid = formWCR_uid
					  FROM dbo.FormWCR
					 WHERE form_id = @form_id
					   AND revision_id = @revision_id;
				END
			ELSE
				BEGIN
					SET @FormWCR_uid = NULL;
				END

			INSERT INTO dbo.FormBenzene (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id, locked
				 , type_of_facility
				 , tab_lt_1_megagram
				 , tab_gte_1_and_lt_10_megagram
				 , tab_gte_10_megagram
				 , benzene_onsite_mgmt
				 , flow_weighted_annual_average_benzene
				 , avg_h20_gr_10
				 , is_process_unit_turnaround
				 , benzene_range_from
				 , benzene_range_to
				 , classified_as_process_wastewater_stream
				 , classified_as_landfill_leachate
				 , classified_as_product_tank_drawdown
				 , originating_generator_name
				 , originating_generator_epa_id
				 , created_by, date_created, modified_by, date_modified
				 )
			SELECT @newForm_id as form_id, @newrev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @form_id as wcr_id, @revision_id as wcr_rev_id, 'U' as locked
				 , p.v.value('type_of_facility[1]', 'CHAR(1)') as type_of_facility
				 , p.v.value('tab_lt_1_megagram[1]', 'CHAR(1)') as tab_lt_1_megagram
				 , p.v.value('tab_gte_1_and_lt_10_megagram[1]', 'CHAR(1)') as tab_gte_1_and_lt_10_megagram
				 , p.v.value('tab_gte_10_megagram[1]', 'CHAR(1)') as tab_gte_10_megagram
				 , p.v.value('benzene_onsite_mgmt[1]', 'CHAR(1)') as benzene_onsite_mgmt
				 , p.v.value('flow_weighted_annual_average_benzene[1][not(@xsi:nil = "true")]', 'FLOAT') as flow_weighted_annual_average_benzene
				 , p.v.value('avg_h20_gr_10[1]', 'CHAR(1)') as avg_h20_gr_10
				 , p.v.value('is_process_unit_turnaround[1]', 'CHAR(1)') as is_process_unit_turnaround
				 , p.v.value('benzene_range_from[1][not(@xsi:nil = "true")]', 'FLOAT') as benzene_range_from
				 , p.v.value('benzene_range_to[1][not(@xsi:nil = "true")]', 'FLOAT') as benzene_range_to
				 , p.v.value('classified_as_process_wastewater_stream[1]', 'CHAR(1)') as classified_as_process_wastewater_stream
				 , p.v.value('classified_as_landfill_leachate[1]', 'CHAR(1)') as classified_as_landfill_leachate
				 , p.v.value('classified_as_product_tank_drawdown[1]', 'CHAR(1)') as classified_as_product_tank_drawdown
				 , p.v.value('originating_generator_name[1]', 'VARCHAR(60)') as originating_generator_name
				 , p.v.value('originating_generator_epa_id[1]', 'VARCHAR(60)') as originating_generator_epa_id
				 , @web_userid as created_by, GETDATE() as date_created, @web_userid as modified_by, GETDATE() as date_modified
			  FROM @Data.nodes('Benzene')p(v);
		END
	ELSE
		BEGIN
			UPDATE dbo.FormBenzene
			   SET locked = 'U'
			     , type_of_facility = p.v.value('type_of_facility[1]', 'CHAR(1)')
				 , tab_lt_1_megagram = p.v.value('tab_lt_1_megagram[1]', 'CHAR(1)')
				 , tab_gte_1_and_lt_10_megagram = p.v.value('tab_gte_1_and_lt_10_megagram[1]', 'CHAR(1)')
				 , tab_gte_10_megagram = p.v.value('tab_gte_10_megagram[1]', 'CHAR(1)')
				 , benzene_onsite_mgmt = p.v.value('benzene_onsite_mgmt[1]', 'CHAR(1)')
				 , flow_weighted_annual_average_benzene = p.v.value('flow_weighted_annual_average_benzene[1]', 'FLOAT')
				 , avg_h20_gr_10 = p.v.value('avg_h20_gr_10[1]', 'CHAR(1)')
				 , is_process_unit_turnaround = p.v.value('is_process_unit_turnaround[1]', 'CHAR(1)')
				 , benzene_range_from = p.v.value('benzene_range_from[1]', 'FLOAT')
				 , benzene_range_to = p.v.value('benzene_range_to[1]', 'FLOAT')
				 , classified_as_process_wastewater_stream = p.v.value('classified_as_process_wastewater_stream[1]', 'CHAR(1)')
				 , classified_as_landfill_leachate = p.v.value('classified_as_landfill_leachate[1]', 'CHAR(1)')
				 , classified_as_product_tank_drawdown = p.v.value('classified_as_product_tank_drawdown[1]', 'CHAR(1)')
				 , originating_generator_name = p.v.value('originating_generator_name[1]', 'VARCHAR(60)')
				 , originating_generator_epa_id = p.v.value('originating_generator_epa_id[1]', 'VARCHAR(60)')
				 , date_modified = GETDATE(), modified_by = @web_userid
			  FROM @Data.nodes('Benzene')p(v)
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id = @revision_id;
		END
END
GO

GRANT EXEC ON [dbo].[sp_benzene_insert_update] TO COR_USER;
GO

