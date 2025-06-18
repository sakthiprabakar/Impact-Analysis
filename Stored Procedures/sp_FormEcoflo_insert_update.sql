ALTER PROCEDURE dbo.sp_FormEcoflo_insert_update 
	  @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
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
	--Updated by Blair Christensen for Titan 05/21/2025
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
	DECLARE @newForm_id INTEGER 
		  , @newrev_id INTEGER = 1
		  , @FormWCR_uid INTEGER;

	IF NOT EXISTS (SELECT 1 FROM dbo.FormEcoflo WHERE wcr_id = @form_id and wcr_rev_id =  @revision_id)			
		BEGIN				
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

			INSERT INTO dbo.FormEcoflo (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id
				 , viscosity_value
				 , total_solids_low, total_solids_high, total_solids_description
				 , fluorine_low, fluorine_high, chlorine_low, chlorine_high
				 , bromine_low, bromine_high, iodine_low, iodine_high
				 , created_by, modified_by, date_created, date_modified
				 , total_solids_flag, organic_halogens_flag, fluorine_low_flag, fluorine_high_flag
				 , chlorine_low_flag, chlorine_high_flag, bromine_low_flag, bromine_high_flag
				 , iodine_low_flag, iodine_high_flag
				 )
			SELECT @newForm_id as form_id, @newrev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @form_id as wcr_id, @revision_id as wcr_rev_id
				 , p.v.value('viscosity_value[1]', 'INTEGER') as viscosity_value
				 , p.v.value('total_solids_low[1]', 'VARCHAR(5)') as total_solids_low
				 , p.v.value('total_solids_high[1]', 'VARCHAR(5)') as total_solids_high
				 , p.v.value('total_solids_description[1]', 'VARCHAR(100)') as total_solids_description
				 , p.v.value('fluorine_low[1]', 'DECIMAL(38,20)') as fluorine_low
				 , p.v.value('fluorine_high[1]', 'DECIMAL(38,20)') as fluorine_high
				 , p.v.value('chlorine_low[1]', 'DECIMAL(38,20)') as chlorine_low
				 , p.v.value('chlorine_high[1]', 'DECIMAL(38,20)') as chlorine_high
				 , p.v.value('bromine_low[1]', 'DECIMAL(38,20)') as bromine_low
				 , p.v.value('bromine_high[1]', 'DECIMAL(38,20)') as bromine_high
				 , p.v.value('iodine_low[1]', 'DECIMAL(38,20)') as iodine_low
				 , p.v.value('iodine_high[1]', 'DECIMAL(38,20)') as iodine_high
				 , @web_userid as created_by, @web_userid as modified_by, GETDATE() as date_created, GETDATE() as date_modified
				 , p.v.value('total_solids_flag[1]', 'CHAR(1)') as total_solids_flag
				 , p.v.value('organic_halogens_flag[1]', 'CHAR(1)') as organic_halogens_flag
				 , p.v.value('fluorine_low_flag[1]', 'CHAR(1)') as fluorine_low_flag
				 , p.v.value('fluorine_high_flag[1]', 'CHAR(1)') as fluorine_high_flag
				 , p.v.value('chlorine_low_flag[1]', 'CHAR(1)') as chlorine_low_flag
				 , p.v.value('chlorine_high_flag[1]', 'CHAR(1)') as chlorine_high_flag
				 , p.v.value('bromine_low_flag[1]', 'CHAR(1)') as bromine_low_flag
				 , p.v.value('bromine_high_flag[1]', 'CHAR(1)') as bromine_high_flag
				 , p.v.value('iodine_low_flag[1]', 'CHAR(1)') as iodine_low_flag
				 , p.v.value('iodine_high_flag[1]', 'CHAR(1)') as iodine_high_flag
			  FROM @Data.nodes('FuelsBlending')p(v);
		END
	ELSE
		BEGIN
			UPDATE dbo.FormEcoflo
			   SET viscosity_value = p.v.value('viscosity_value[1]', 'INTEGER')
			     , total_solids_low = p.v.value('total_solids_low[1]', 'VARCHAR(5)')
				 , total_solids_high = p.v.value('total_solids_high[1]', 'VARCHAR(5)')
				 , total_solids_description = p.v.value('total_solids_description[1]', 'VARCHAR(100)')
				 , fluorine_low = p.v.value('fluorine_low[1]', 'DECIMAL(38,20)')
				 , fluorine_high = p.v.value('fluorine_high[1]', 'DECIMAL(38,20)')
				 , chlorine_low = p.v.value('chlorine_low[1]', 'DECIMAL(38,20)')
				 , chlorine_high = p.v.value('chlorine_high[1]', 'DECIMAL(38,20)')
				 , bromine_low = p.v.value('bromine_low[1]', 'DECIMAL(38,20)')
				 , bromine_high = p.v.value('bromine_high[1]', 'DECIMAL(38,20)')
				 , iodine_low = p.v.value('iodine_low[1]', 'DECIMAL(38,20)')
				 , iodine_high = p.v.value('iodine_high[1]', 'DECIMAL(38,20)')
				 , created_by = @web_userid, modified_by = @web_userid, date_modified = GETDATE()
				 , total_solids_flag = p.v.value('total_solids_flag[1]', 'CHAR(1)')
				 , organic_halogens_flag = p.v.value('organic_halogens_flag[1]', 'CHAR(1)')
				 , fluorine_low_flag = p.v.value('fluorine_low_flag[1]', 'CHAR(1)')
				 , fluorine_high_flag = p.v.value('fluorine_high_flag[1]', 'CHAR(1)')
				 , chlorine_low_flag = p.v.value('chlorine_low_flag[1]', 'CHAR(1)')
				 , chlorine_high_flag = p.v.value('chlorine_high_flag[1]', 'CHAR(1)')
				 , bromine_low_flag = p.v.value('bromine_low_flag[1]', 'CHAR(1)')
				 , bromine_high_flag = p.v.value('bromine_high_flag[1]', 'CHAR(1)')
				 , iodine_low_flag = p.v.value('iodine_low_flag[1]', 'CHAR(1)')
				 , iodine_high_flag = p.v.value('iodine_high_flag[1]', 'CHAR(1)')
			  FROM @Data.nodes('FuelsBlending')p(v)
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id =  @revision_id;
		END
END	
GO

GRANT EXEC ON [dbo].[sp_FormEcoflo_insert_update] TO COR_USER;
GO
