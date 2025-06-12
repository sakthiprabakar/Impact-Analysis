USE [PLT_AI]
GO
/***********************************************************************************************/
DROP PROCEDURE IF EXISTS [sp_FormEcoflo_insert_update]
GO
CREATE PROCEDURE [dbo].[sp_FormEcoflo_insert_update] 
	   @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)

AS
/*********************************************************************************** 
    Updated By    : Nallaperumal C
    Updated On    : 15-october-2023
    Type          : Store Procedure 
    Object Name   : [sp_FormEcoflo_insert_update]
	Ticket		  : 73641	
	Updated By   : Ranjini C
    Updated On   : 08-AUGUST-2024
    Ticket       : 93217
	Updated By   : Sathiyamoorthi M
    Updated On   : 31-Jan-2025
    Ticket       : DE37742
    Decription   : This procedure is used to assign web_userid to created_by and modified_by columns.                                                     
    Execution Statement    	
	EXEC  [dbo].[sp_FormEcoflo_insert_update]  @Data, @form_id, @revision_id 
*************************************************************************************/
--declare       @Data XML='<FuelsBlending>
--        <viscosity_value>100</viscosity_value>
--        <total_solids_low>10</total_solids_low>
--        <total_solids_high>20</total_solids_high>
--        <total_solids_description>Low to High</total_solids_description>
--        <fluorine_low>0.5</fluorine_low>
--        <fluorine_high>0.8</fluorine_high>
--        <chlorine_low>0.1</chlorine_low>
--        <chlorine_high>0.2</chlorine_high>
--        <bromine_low>0.05</bromine_low>
--        <bromine_high>0.1</bromine_high>
--        <iodine_low>0.02</iodine_low>
--        <iodine_high>0.04</iodine_high>
--        <created_by>UserA</created_by>
--        <modified_by>UserA</modified_by>
--        <total_solids_flag>F</total_solids_flag>
--        <organic_halogens_flag></organic_halogens_flag>
--        <fluorine_low_flag>F</fluorine_low_flag>
--        <fluorine_high_flag>T</fluorine_high_flag>
--        <chlorine_low_flag></chlorine_low_flag>
--        <chlorine_high_flag>T</chlorine_high_flag>
--        <bromine_low_flag>F</bromine_low_flag>
--        <bromine_high_flag></bromine_high_flag>
--        <iodine_low_flag>F</iodine_low_flag>
--        <iodine_high_flag>F</iodine_high_flag>
--    </FuelsBlending>',
--@form_id int=461587,
--@revision_id int=1
	BEGIN
		DECLARE @newForm_id INT 
   		DECLARE @newrev_id INT  = 1
		IF(NOT EXISTS(SELECT form_id FROM FormEcoflo WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id))			
			BEGIN				
				EXEC @newForm_id = sp_sequence_next 'form.form_id'
				  INSERT INTO FormEcoflo(
					form_id,
					revision_id,
					wcr_id,
					wcr_rev_id,
					viscosity_value,
					total_solids_low,
					total_solids_high,
					total_solids_description,
					fluorine_low,
					fluorine_high,
					chlorine_low,
					chlorine_high,
					bromine_low,
					bromine_high,
					iodine_low,
					iodine_high,
					created_by,
					modified_by,
					date_created,
					date_modified,
					total_solids_flag,
					organic_halogens_flag,
					fluorine_low_flag,
					fluorine_high_flag,
					chlorine_low_flag,
					chlorine_high_flag,
					bromine_low_flag,
					bromine_high_flag,
					iodine_low_flag,
					iodine_high_flag)
					SELECT 
						form_id=@newForm_id,
						revision_id=@newrev_id,
						wcr_id = @form_id,
						wcr_rev_id = @revision_id,
						viscosity_value = p.v.value('viscosity_value[1]','int'),
						total_solids_low = p.v.value('total_solids_low[1]','varchar(5)'),
						total_solids_high = p.v.value('total_solids_high[1]','varchar(5)'),
						total_solids_description = p.v.value('total_solids_description[1]','varchar(100)'),
						fluorine_low = p.v.value('fluorine_low[1]','decimal(38,20)'),
						fluorine_high = p.v.value('fluorine_high[1]','decimal(38,20)'),
						chlorine_low = p.v.value('chlorine_low[1]','decimal(38,20)'),
						chlorine_high = p.v.value('chlorine_high[1]','decimal(38,20)'),
						bromine_low = p.v.value('bromine_low[1]','decimal(38,20)'),
						bromine_high = p.v.value('bromine_high[1]','decimal(38,20)'),
						iodine_low = p.v.value('iodine_low[1]','decimal(38,20)'),
						iodine_high = p.v.value('iodine_high[1]','decimal(38,20)'),
						created_by = @web_userid,
						modified_by = @web_userid,
						date_created = GETDATE(),
						date_modified = GETDATE(),
						total_solids_flag = p.v.value('total_solids_flag[1]','char(1)'),
						organic_halogens_flag = p.v.value('organic_halogens_flag[1]','char(1)'),
						fluorine_low_flag = p.v.value('fluorine_low_flag[1]','char(1)'),
						fluorine_high_flag = p.v.value('fluorine_high_flag[1]','char(1)'),
						chlorine_low_flag = p.v.value('chlorine_low_flag[1]','char(1)'),
						chlorine_high_flag = p.v.value('chlorine_high_flag[1]','char(1)'),
						bromine_low_flag = p.v.value('bromine_low_flag[1]','char(1)'),
						bromine_high_flag = p.v.value('bromine_high_flag[1]','char(1)'),
						iodine_low_flag = p.v.value('iodine_low_flag[1]','char(1)'),
						iodine_high_flag = p.v.value('iodine_high_flag[1]','char(1)')
				   FROM
				       @Data.nodes('FuelsBlending')p(v)				  
			END
		ELSE
			BEGIN
				UPDATE FormEcoflo
				SET
					viscosity_value = p.v.value('viscosity_value[1]','int'),
					total_solids_low = p.v.value('total_solids_low[1]','varchar(5)'),
					total_solids_high = p.v.value('total_solids_high[1]','varchar(5)'),
					total_solids_description = p.v.value('total_solids_description[1]','varchar(100)'),
					fluorine_low = p.v.value('fluorine_low[1]','decimal(38,20)'),
					fluorine_high = p.v.value('fluorine_high[1]','decimal(38,20)'),
					chlorine_low = p.v.value('chlorine_low[1]','decimal(38,20)'),
					chlorine_high = p.v.value('chlorine_high[1]','decimal(38,20)'),
					bromine_low = p.v.value('bromine_low[1]','decimal(38,20)'),
					bromine_high = p.v.value('bromine_high[1]','decimal(38,20)'),
					iodine_low = p.v.value('iodine_low[1]','decimal(38,20)'),
					iodine_high = p.v.value('iodine_high[1]','decimal(38,20)'),
					created_by = @web_userid,
					modified_by = @web_userid,
					--date_created = GETDATE(),
					date_modified = GETDATE(),
					total_solids_flag = p.v.value('total_solids_flag[1]','char(1)'),
					organic_halogens_flag = p.v.value('organic_halogens_flag[1]','char(1)'),
					fluorine_low_flag = p.v.value('fluorine_low_flag[1]','char(1)'),
					fluorine_high_flag = p.v.value('fluorine_high_flag[1]','char(1)'),
					chlorine_low_flag = p.v.value('chlorine_low_flag[1]','char(1)'),
					chlorine_high_flag = p.v.value('chlorine_high_flag[1]','char(1)'),
					bromine_low_flag = p.v.value('bromine_low_flag[1]','char(1)'),
					bromine_high_flag = p.v.value('bromine_high_flag[1]','char(1)'),
					iodine_low_flag = p.v.value('iodine_low_flag[1]','char(1)'),
					iodine_high_flag = p.v.value('iodine_high_flag[1]','char(1)')
				FROM
					@Data.nodes('FuelsBlending')p(v) WHERE  wcr_id= @form_id and wcr_rev_id =  @revision_id
			END
	END	
	GO
	GRANT EXEC ON [dbo].[sp_FormEcoflo_insert_update] TO COR_USER;
	GO	
/******************************************************************************************************************************/