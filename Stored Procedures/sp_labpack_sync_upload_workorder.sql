GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_upload_workorder 
GO
USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_labpack_sync_upload_workorder]    Script Date: 1/4/2024 10:05:18 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE  PROCEDURE [dbo].[sp_labpack_sync_upload_workorder]
	-- Add the parameters for the stored procedure here
	@Data XML,
	@Message nvarchar(100) Output
AS
-- =============================================
-- Author:		Senthil Kumar
-- Create date: 28-04-2020
-- Description:	To upload labpack workorder
-- 04/01/2024 Ranjini- DevOps 73073 Added Inventoryid to order #tempinventory table.
/*
declare @Message nvarchar(100)
exec sp_labpack_sync_upload_workorder '<?xml version="1.0"?><WorkOrderHeaderInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><tcl_id>247999</tcl_id><trip_sequence_id>1</trip_sequence_id><workorder_id>5782100</workorder_id><company_id>14</company_id><profit_ctr_id>17</profit_ctr_id><date_act_arrive>05-20-2020 02:00:00</date_act_arrive><date_act_depart>05-20-2020 03:00:00</date_act_depart><consolidated_pickup_flag>F</consolidated_pickup_flag><waste_flag>T</waste_flag><decline_id>3</decline_id><tsu_id>466968</tsu_id><manifest>12</manifest><manifest_state> H</manifest_state><transporter_sequence_id>1</transporter_sequence_id><transporter_code>USEDSC</transporter_code><uploadLabours><UploadLabour><resource_class_code>DRIVER</resource_class_code><chemist_name>Chemist</chemist_name></UploadLabour></uploadLabours><uploadSupplies><UploadSupply><resource_class_code>BAGVERM</resource_class_code><supply_desc>Bags, Vermiculite</supply_desc></UploadSupply></uploadSupplies><labpackContainers><LabpackContainer><profile_id>-76178001</profile_id><approval_code>LP-1234</approval_code><approval_desc>(2.1)  CP-I-02 aerosol(s), Incineration</approval_desc><customer_id>13880</customer_id><generator_id>169983</generator_id><bill_unit_code>CYB</bill_unit_code><DOT_shipping_name>UN2810 Waste Toxic, liquids, organic, n.o.s. (aerosol cans,(-)-1,2-bis[(2r,5r)-2,5-diethylphospholano]benzene,(-)-1,2-bis[(2r,5r)-2,5-dimethylphospholano]benzene), 6.1 PG II, RQ (D001,D003), test</DOT_shipping_name><ERG_number>153</ERG_number><hazmat>T</hazmat><subsidiary_haz_mat_class /><manifest_dot_sp_number>test</manifest_dot_sp_number><package_group>II</package_group><reportable_quantity_flag>T</reportable_quantity_flag><RQ_reason>D001,D003</RQ_reason><UN_NA_flag>UN</UN_NA_flag><UN_NA_number>2810</UN_NA_number><waste_code_uid>472</waste_code_uid><waste_code>D001</waste_code><tsdf_approval_id>0</tsdf_approval_id><tsdf_code>MICHIGANDISPO</tsdf_code><billing_sequence_id>0</billing_sequence_id><bill_rate>0</bill_rate><profile_company_id>0</profile_company_id><profile_profit_ctr_id>0</profile_profit_ctr_id><waste_stream>-76165001</waste_stream><description>(2.1)  CP-I-02 aerosol(s), Incineration</description><management_code>H040</management_code><hazmat_class>6.1</hazmat_class><manifest>12</manifest><manifest_page_num>1</manifest_page_num><manifest_line>1</manifest_line><container_count>1</container_count><container_code>CY</container_code><sequence_id>-1</sequence_id><sub_sequence_id>0</sub_sequence_id><item_type_ind>LP</item_type_ind><month>5</month><year>2020</year><pounds>0</pounds><ounces>0</ounces><merchandise_id>0</merchandise_id><merchandise_quantity>0</merchandise_quantity><manual_entry_desc>1.1XCYB,LP-1234</manual_entry_desc><form_group>0</form_group><percentage>0</percentage><dosage_type_id>0</dosage_type_id><parent_sub_sequence_id>0</parent_sub_sequence_id><const_id>0</const_id><const_percent>0</const_percent><size>CYB</size><quantity>123</quantity><manifest_flag>F</manifest_flag><billing_flag>T</billing_flag><profileConstituents><ProfileConstituent><tsu_id>0</tsu_id><profile_id>-76178001</profile_id><tsdf_approval_id>0</tsdf_approval_id><const_id>2647</const_id><concentration>0</concentration></ProfileConstituent><ProfileConstituent><tsu_id>0</tsu_id><profile_id>-76178001</profile_id><tsdf_approval_id>0</tsdf_approval_id><const_id>2649</const_id><concentration>0</concentration></ProfileConstituent></profileConstituents><profileWasteCodes><ProfileWasteCode><tsu_id>0</tsu_id><profile_id>-76178001</profile_id><tsdf_approval_id>0</tsdf_approval_id><waste_code_uid>472</waste_code_uid><waste_code>D001</waste_code><primary_flag>T</primary_flag><sequence_id>1</sequence_id><sequence_flag>A</sequence_flag></ProfileWasteCode><ProfileWasteCode><tsu_id>0</tsu_id><profile_id>-76178001</profile_id><tsdf_approval_id>0</tsdf_approval_id><waste_code_uid>474</waste_code_uid><waste_code>D003</waste_code><primary_flag>F</primary_flag><sequence_id>2</sequence_id></ProfileWasteCode><ProfileWasteCode><tsu_id>0</tsu_id><profile_id>-76178001</profile_id><tsdf_approval_id>0</tsdf_approval_id><waste_code_uid>476</waste_code_uid><waste_code>D005</waste_code><primary_flag>F</primary_flag><sequence_id>3</sequence_id></ProfileWasteCode></profileWasteCodes><workorderWasteCodes><WorkorderWasteCode><tsu_id>0</tsu_id><workorder_id>0</workorder_id><company_id>0</company_id><profit_ctr_id>0</profit_ctr_id><waste_code_uid>472</waste_code_uid><waste_code>D001</waste_code><workorder_sequence_id>-1</workorder_sequence_id><sequence_id>1</sequence_id></WorkorderWasteCode><WorkorderWasteCode><tsu_id>0</tsu_id><workorder_id>0</workorder_id><company_id>0</company_id><profit_ctr_id>0</profit_ctr_id><waste_code_uid>474</waste_code_uid><waste_code>D003</waste_code><workorder_sequence_id>-1</workorder_sequence_id><sequence_id>2</sequence_id></WorkorderWasteCode><WorkorderWasteCode><tsu_id>0</tsu_id><workorder_id>0</workorder_id><company_id>0</company_id><profit_ctr_id>0</profit_ctr_id><waste_code_uid>476</waste_code_uid><waste_code>D005</waste_code><workorder_sequence_id>-1</workorder_sequence_id><sequence_id>3</sequence_id></WorkorderWasteCode></workorderWasteCodes></LabpackContainer></labpackContainers></WorkOrderHeaderInfo>',@Message out
select @Message
*/
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN /* Variable declaration */
		DECLARE 	
		@trip_connect_log_id		int,
		@trip_sequence_id			int,
		@workorder_id				int,
		@company_id					int,
		@profit_ctr_id				int,
		@date_act_arrive			datetime,
		@date_act_depart			datetime,
		@consolidated_pickup_flag	char(1)='F',
		@pickup_contact				varchar(40) =NULL,
		@pickup_contact_title		varchar(40)=NULL,
		@waste_flag					char(1),
		@decline_id					int,

		--sp_labpack_sync_upload_workordermanifest
		@manifest					varchar(15),
		@manifest_state				char(2),
		@generator_sign_name		varchar(40),
		@generator_sign_date		datetime,
		
		--sp_labpack_sync_upload_workordertransporter
		@trip_sync_upload_id		int,
		@transporter_code			varchar(15),
		@transporter_sign_name		varchar(40),
		@transporter_sign_date		datetime,

		--sp_labpack_sync_upload_workorderdetail
		@tsdf_code					varchar(15),

		--sp_labpack_sync_upload_labour
		@resource_class_code		varchar(10),
		@chemist_name				varchar(10),
		@labour_quantity			float,

		--sp_labpack_sync_upload_supply
		@supply_desc				varchar(10),
		@quantity_billable			float,

		--sp_labpack_sync_upload_workordertransporter
		@transporter_sequence_id	int =1,
		@transporter_license_nbr	varchar(20)=NULL,

		--sp_labpack_sync_upload_profile
		@profile_id					int,
		@approval_code				varchar(15),
		@approval_desc				varchar(50),
		@customer_id				int,
		@generator_id				int,
		@bill_unit_code				varchar(4),
		@consistency				varchar(50),
		@DOT_shipping_name			varchar(255),
		@ERG_number					int,
		@ERG_suffix					char(2),
		@hazmat						char(1),
		@hazmat_class				varchar(15),
		@subsidiary_haz_mat_class	varchar(15),
		@manifest_dot_sp_number		varchar(20),
		@package_group				varchar(3),
		@reportable_quantity_flag	char(1),
		@RQ_reason					varchar(50),
		@UN_NA_flag					char(2),
		@UN_NA_number				int,
		@waste_code_uid				int,
		@waste_code					varchar(4),
		@DOT_waste_flag				char(1),
		@DOT_shipping_desc_additional varchar(255),
		@process_code_uid			int,
		@created_from_template_profile_id	int,


		--sp_labpack_sync_upload_profileconstituent
		@const_id					int,
		@concentration				float,
		@unit						varchar(10),
		@UHC						char(1),

		--sp_labpack_sync_upload_profilewastecode
		@primary_flag				char(1),
		@sequence_id				int,
		@sequence_flag				char(1),
		@waste_sequence_flag		char(1),

		--sp_labpack_sync_upload_workorderdetail
		@billing_sequence_id		int,
		@bill_rate					int,
		@profile_company_id			int,
		@profile_profit_ctr_id		int,
		@tsdf_approval_id			int,
		@waste_stream				varchar(10),
		@tsdf_approval_code			varchar(40),
		@description				varchar(100),
		@management_code			varchar(4),
		@manifest_page_num			int,
		@manifest_line				int,
		@container_count			float,
		@container_code				varchar(15),

		--sp_labpack_sync_upload_workorderdetailitem
		@sub_sequence_id			int,
		@item_type_ind				varchar(2),
		@month						int,
		@year						int,
		@pounds						float,
		@ounces						float,
		@merchandise_id				int,
		@merchandise_quantity		int,
		@merchandise_code_type		char(1),
		@merchandise_code			varchar(15),
		@manual_entry_desc			varchar(60),
		@note						varchar(255),
		@form_group					int,
		@contents					varchar(20),
		@percentage					int,
		@DEA_schedule				varchar(2),
		@dea_form_222_number		varchar(9),
		@dosage_type_id				int,
		@parent_sub_sequence_id		int,
		@const_percent				int,
		@const_uhc					char(1),

		--sp_labpack_sync_upload_workorderdetailunit
		@size						varchar(4),
		@quantity					float,
		@manifest_flag				char(1),
		@billing_flag				char(1),
	
		--sp_labpack_sync_upload_workorderwastecode
		@workorder_sequence_id		int,
		@isUploadSuccess			int,

		--sp_labpack_sync_upload_profileldrsubcategory
		@ldr_subcategory_id			int,

		--sp_labpack_sync_upload_note_profile
		@subject					varchar(50),
		@note_segment_1				varchar(8000),
		@note_segment_2				varchar(8000) = null,
		@note_segment_3				varchar(8000) = null,
		@note_segment_4				varchar(8000) = null,
		@tsdf_company_id			int,
		@tsdf_profit_ctr_id			int,

		--sp_labpack_sync_upload_LabPackJobSheet
	    @job_notes                   varchar(255),
	    @truck_id                    varchar(50),
	    @HHW_name                    varchar(25),
	    @otherinfo_text              varchar(max),
	    @auth_name                   varchar(100),
	    @is_change_auth_enabled      int,

		--sp_labpack_sync_upload_LabPackJobSheetXComments
		@jobsheet_comment_uid         int,
	    @jobsheet_uid                 int,
	    @comment                      varchar(max),

		--sp_labpack_sync_upload_LabPackJobSheetXLabor
	    @dispatch_time                time(6),
	    @onsite_time                  time(6),
		@jobfinish_time               time(6),
		@est_return_time              time(6),
		@user_id                      varchar(10),

	   --sp_labpack_sync_upload_LabPackLabel
	    @label_type                   char(1),
		@Sequence_ids                 int,
		@output_sequence_id           int,
	    

		--sp_labpack_sync_upload_LabPackLabelXInventory
		@label_uid                    int,
	    @notes                        varchar(255),
	    @epa_rcra_codes               varchar(max),
	    @phase                        varchar(50),
	    @inventoryconstituent_name    varchar(max),
		@Sequenceid                   int,
		@Inventoryid                 int

	END

	BEGIN /* Assign values from json */
		SELECT
		--sp_labpack_sync_upload_begin
		@trip_connect_log_id =p.v.value('tcl_id[1]','int'),
		@trip_sequence_id= p.v.value('trip_sequence_id[1]','int'),
		@workorder_id= p.v.value('workorder_id[1]','int'),
		@company_id=p.v.value('company_id[1]','int'),
		@profit_ctr_id=p.v.value('profit_ctr_id[1]','int'),
		@date_act_arrive=p.v.value('date_act_arrive[1]','DATETIME'),
		@date_act_depart=p.v.value('date_act_depart[1]','DATETIME'),
		@waste_flag=p.v.value('waste_flag[1]','char(1)'),
		@decline_id=p.v.value('decline_id[1]','int'),

		--sp_labpack_sync_upload_workordermanifest
		@manifest=p.v.value('manifest[1]','varchar(15)'),
		@manifest_state=p.v.value('manifest_state[1]','char(2)'),
		@generator_sign_name=p.v.value('generator_sign_name[1]','varchar(15)'),
		@generator_sign_date=p.v.value('generator_sign_date[1]','DATETIME'),
		
		--sp_labpack_sync_upload_workordertransporter
		@trip_sync_upload_id=p.v.value('tsu_id[1]','int'),
		@transporter_code=p.v.value('transporter_code[1]','varchar(15)'),
		@transporter_sign_name=p.v.value('transporter_sign_name[1]','varchar(15)'),
		@transporter_sign_date=p.v.value('transporter_sign_date[1]','DATETIME'),

		--sp_labpack_sync_upload_workorderdetail
		@tsdf_code=p.v.value('@tsdf_code[1]','varchar(15)'),
		@user_id = p.v.value('user_id[1]', 'varchar(10)')
		
		From @Data.nodes('WorkOrderHeaderInfo')p(v)
	END

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
BEGIN TRY
 
 BEGIN /* Temp Waste Code */
	IF OBJECT_ID('tempdb..#tempwastecode') is not null DROP TABLE #tempwastecode
	SELECT waste_code_uid,waste_code,waste_code_origin INTO #tempwastecode
	FROM wastecode WHERE waste_code_uid IN(
	SELECT  X.Y.value('waste_code_uid[1]','INT') FROM  
	@data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/profileWasteCodes/ProfileWasteCode') AS X(Y))
END

 BEGIN /* Temp inventory */
	IF OBJECT_ID('tempdb..#tempinventory') is not null DROP TABLE #tempinventory
	SELECT 
	
	X.Y.value('inventoryconstituent_name[1]', 'varchar(max)') AS inventoryconstituent_name,
	X.Y.value ('notes[1]', 'varchar(255)') AS notes ,
	X.Y.value('epa_rcra_codes[1]', 'varchar(max)') AS epa_rcra_codes,
	X.Y.value('quantity[1]', 'int') AS quantity,
	X.Y.value('size[1]', 'varchar(50)') AS size,
	X.Y.value('phase[1]', 'varchar(50)') AS phase,
	X.Y.value('Sequence_ID[1]', 'int') AS Sequenceid,
	X.Y.value('Inventory_id[1]', 'int') AS Inventoryid 
	
	INTO #tempinventory
	FROM  
	@data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/labpackLabelXInventories/LabpackLabelXInventory') AS X(Y)
	Select * from #tempinventory
END

BEGIN /* Multiple Manifest */
	DECLARE curMultiManifest CURSOR FOR
		SELECT
			tab.col.value('manifest[1]','varchar(15)') as manifest
			,tab.col.value('manifest_state[1]','varchar(2)') as manifest_state
			,tab.col.value('transporter_sequence_id[1]','INT') as transporter_sequence_id
			,tab.col.value('transporter_code[1]','varchar(15)') as transporter_code
		FROM @Data.nodes('WorkOrderHeaderInfo/multipleManifests/MultipleManifest') AS tab(col)

	OPEN curMultiManifest FETCH NEXT FROM curMultiManifest 
		INTO @manifest,@manifest_state,@transporter_sequence_id,@transporter_code
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC dbo.sp_labpack_sync_upload_workordermanifest
			@trip_sync_upload_id,@workorder_id,@company_id,@profit_ctr_id,@manifest,
			@manifest_state,@generator_sign_name,@generator_sign_date--,'T'

			EXEC dbo.sp_labpack_sync_upload_workordertransporter
			@trip_sync_upload_id,@workorder_id,@company_id,@profit_ctr_id,@manifest,@transporter_sequence_id,
			@transporter_code,@transporter_sign_name,@transporter_sign_date,@transporter_license_nbr

			FETCH NEXT FROM curMultiManifest
			INTO  @manifest,@manifest_state,@transporter_sequence_id,@transporter_code
		END
	CLOSE curMultiManifest;
	DEALLOCATE curMultiManifest;
END




BEGIN /* Profile Insert */
	DECLARE curProfile CURSOR FOR
		SELECT
			 tab.col.value('profile_id[1]','INT') as profile_id
			,tab.col.value('tsdf_approval_id[1]','INT') as tsdf_approval_id
			,tab.col.value('approval_code[1]','varchar(15)') as approval_code
			,tab.col.value('approval_desc[1]','varchar(15)') as approval_desc
			,tab.col.value('customer_id[1]','INT') as customer_id
			,tab.col.value('generator_id[1]','INT') as generator_id
			,tab.col.value('bill_unit_code[1]','varchar(4)') as bill_unit_code
			,tab.col.value('consistency[1]','varchar(50)') as consistency
			,tab.col.value('DOT_shipping_name[1]','varchar(255)') as DOT_shipping_name
			,tab.col.value('ERG_number[1]','INT') as ERG_number
			,tab.col.value('ERG_suffix[1]','char(2)') as ERG_suffix
			,tab.col.value('hazmat[1]','char(1)') as hazmat
			,tab.col.value('hazmat_class[1]','varchar(15)') as hazmat_class
			,tab.col.value('subsidiary_haz_mat_class[1]','varchar(15)') as subsidiary_haz_mat_class
			,tab.col.value('manifest_dot_sp_number[1]','varchar(20)') as manifest_dot_sp_number
			,tab.col.value('package_group[1]','varchar(3)') as package_group
			,tab.col.value('reportable_quantity_flag[1]','varchar(1)') as reportable_quantity_flag
			,tab.col.value('RQ_reason[1]','varchar(50)') as RQ_reason
			,tab.col.value('UN_NA_flag[1]','char(2)') as UN_NA_flag
			,tab.col.value('UN_NA_number[1]','INT') as UN_NA_number
			,tab.col.value('tsdf_code[1]','varchar(15)') as tsdf_code
			,tab.col.value('DOT_waste_flag[1]','char(1)') as DOT_waste_flag
			,tab.col.value('DOT_shipping_desc_additional[1]','varchar(255)') as DOT_shipping_desc_additional
			,tab.col.value('process_code_uid[1]','INT') as process_code_uid
			,tab.col.value('created_from_template_profile_id[1]','INT') as created_from_template_profile_id

			 -- Workorderdetail
			,tab.col.value('sequence_id[1]','INT') as sequence_id
			,tab.col.value('billing_sequence_id[1]','INT') as billing_sequence_id
			,tab.col.value('bill_rate[1]','INT') as bill_rate
			,tab.col.value('waste_stream[1]','varchar(10)') as waste_stream
			,tab.col.value('description[1]','varchar(100)') as description
			,tab.col.value('management_code[1]','varchar(4)') as management_code
			,tab.col.value('manifest[1]','varchar(15)') as manifest
			,tab.col.value('manifest_page_num[1]','INT') as manifest_page_num
			,tab.col.value('manifest_line[1]','INT') as manifest_line
			,tab.col.value('container_count[1]','INT') as container_count
			,tab.col.value('container_code[1]','varchar(15)') as container_code

			-- Workorderdetailitem
			,tab.col.value('sub_sequence_id[1]','INT') as sub_sequence_id
			,tab.col.value('item_type_ind[1]','varchar(2)') as item_type_ind
			,tab.col.value('month[1]','INT') as month
			,tab.col.value('year[1]','INT') as year
			,tab.col.value('pounds[1]','float') as pounds
			,tab.col.value('manual_entry_desc[1]','varchar(60)') as manual_entry_desc

			-- Workorderdetailunit
			,tab.col.value('size[1]','varchar(4)') as size
			,tab.col.value('quantity[1]','float') as quantity
			,tab.col.value('manifest_flag[1]','char(1)') as manifest_flag
			,tab.col.value('billing_flag[1]','char(1)') as billing_flag
			
			-- upload_note_profile
			,tab.col.value('subject[1]','varchar(50)') as subject
			,tab.col.value('note_segment_1[1]','varchar(8000)') as note_segment_1
			,tab.col.value('note_segment_2[1]','varchar(8000)') as note_segment_2
			,tab.col.value('note_segment_3[1]','varchar(8000)') as note_segment_3
			,tab.col.value('note_segment_4[1]','varchar(8000)') as note_segment_4

			,tab.col.value('tsdf_company_id[1]','INT') as tsdf_company_id
			,tab.col.value('tsdf_profit_ctr_id[1]','INT') as tsdf_profit_ctr_id

		FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer') AS tab(col)
	OPEN curProfile FETCH NEXT FROM curProfile
		INTO @profile_id,@tsdf_approval_id,@approval_code,@approval_desc,@customer_id, @generator_id,
		@bill_unit_code,@consistency,@DOT_shipping_name,@ERG_number,@ERG_suffix,@hazmat,@hazmat_class,
		@subsidiary_haz_mat_class,@manifest_dot_sp_number,@package_group,@reportable_quantity_flag,
		@RQ_reason,@UN_NA_flag,@UN_NA_number,@tsdf_code,@DOT_waste_flag,@DOT_shipping_desc_additional,
		@process_code_uid,@created_from_template_profile_id,
		--Workorderdetail	
		@sequence_id,@billing_sequence_id,@bill_rate,@waste_stream,@description,@management_code,@manifest,
		@manifest_page_num,@manifest_line,@container_count,@container_code,@sub_sequence_id,@item_type_ind, 
		@month,@year,@pounds,@manual_entry_desc,@size,@quantity,@manifest_flag,@billing_flag,
		--upload_note_profile
		@subject,@note_segment_1,@note_segment_2,@note_segment_3,@note_segment_4,@tsdf_company_id,
		@tsdf_profit_ctr_id
		WHILE @@FETCH_STATUS = 0
		BEGIN

			BEGIN /* Upload profile */
				IF(@profile_id<0)
				BEGIN
					EXEC dbo.sp_labpack_sync_upload_profile
					@trip_sync_upload_id,@profile_id,@tsdf_company_id,@tsdf_profit_ctr_id,@approval_code,
					@approval_desc,@customer_id, @generator_id,@bill_unit_code,@consistency,
					@DOT_shipping_name,@ERG_number,@ERG_suffix,@hazmat,@hazmat_class,
					@subsidiary_haz_mat_class,@manifest_dot_sp_number,@package_group,
					@reportable_quantity_flag,@RQ_reason,NULL,@UN_NA_flag,@UN_NA_number,NULL,NULL,
					@DOT_waste_flag,@DOT_shipping_desc_additional,@process_code_uid,
					@created_from_template_profile_id
					
					BEGIN  /* Profile Units */
						EXEC dbo.sp_labpack_sync_upload_profileunit @trip_sync_upload_id,@profile_id,
						@company_id,@profit_ctr_id,@bill_unit_code
					END
				END
				ELSE IF(@tsdf_approval_id<0)
				BEGIN
					EXEC dbo.sp_labpack_sync_upload_tsdfapproval
					@trip_sync_upload_id,@tsdf_approval_id,@company_id,@profit_ctr_id,@tsdf_code,
					@approval_code,@approval_desc,@customer_id,@generator_id,@bill_unit_code,@consistency,
					@DOT_shipping_name,@ERG_number,@ERG_suffix,@hazmat,@hazmat_class,
					@subsidiary_haz_mat_class,@management_code,@manifest_dot_sp_number,@package_group,
					@reportable_quantity_flag,@RQ_reason,@UN_NA_flag,@UN_NA_number,NULL,NULL,
					@DOT_waste_flag,@DOT_shipping_desc_additional,@process_code_uid,
					@created_from_template_profile_id

					BEGIN /* TSDFApproval Units */
						EXEC dbo.sp_labpack_sync_upload_tsdfapprovalunit @trip_sync_upload_id,
						@tsdf_approval_id,@company_id,@profit_ctr_id,@bill_unit_code
					END
				END
			END

			BEGIN /* Profile Notes */
				IF(@profile_id<0 OR @profile_id>0)
				BEGIN
					EXEC dbo.sp_labpack_sync_upload_note_profile @profile_id,@company_id,@profit_ctr_id,
					@customer_id,@generator_id,@subject,@note_segment_1,@note_segment_2,@note_segment_3,
					@note_segment_4
				END
				ELSE IF(@tsdf_approval_id<0 OR @tsdf_approval_id>0 )
				BEGIN
					EXEC dbo.sp_labpack_sync_upload_note_tsdfapproval @tsdf_approval_id,
					@subject,@note_segment_1,@note_segment_2, @note_segment_3,@note_segment_4
				END
			END

			BEGIN /* Workorderdetail */
				SET @tsdf_approval_id=IIF(@tsdf_approval_id=0,NULL,@tsdf_approval_id)
				SET @profile_id=IIF(@profile_id=0,NULL,@profile_id)
				EXEC dbo.sp_labpack_sync_upload_workorderdetail
				@trip_sync_upload_id,@workorder_id,@company_id,@profit_ctr_id,@sequence_id,@tsdf_code,
				@profile_id,@tsdf_approval_id,@waste_stream,@approval_code,@description,
				@reportable_quantity_flag,@RQ_reason,@DOT_shipping_name,@management_code,@hazmat,
				@hazmat_class,@subsidiary_haz_mat_class,@UN_NA_flag,@UN_NA_number,@package_group,
				@ERG_number,@ERG_suffix,@manifest_dot_sp_number,@manifest,@manifest_page_num,@manifest_line,
				@container_count,@container_code,@DOT_waste_flag,@DOT_shipping_desc_additional				
			END 
			
			BEGIN /* Workorderdetailitem */
				EXEC dbo.sp_labpack_sync_upload_workorderdetailitem
				@trip_sync_upload_id,@workorder_id,@company_id,@profit_ctr_id,@sequence_id,@sub_sequence_id,
				@item_type_ind,@month,@year,@pounds,NULL,NULL,NULL,NULL,NULL,@manual_entry_desc
			END 

			BEGIN /* Workorderdetailunit */
				EXEC dbo.sp_labpack_sync_upload_workorderdetailunit
				@trip_sync_upload_id,@workorder_id,@company_id,@profit_ctr_id,@sequence_id,@bill_unit_code,
				@quantity,@manifest_flag,@billing_flag
			END

			FETCH NEXT FROM curProfile
			INTO @profile_id,@tsdf_approval_id,@approval_code,@approval_desc,@customer_id, @generator_id,
			@bill_unit_code,@consistency,@DOT_shipping_name,@ERG_number,@ERG_suffix,@hazmat,@hazmat_class,
			@subsidiary_haz_mat_class,@manifest_dot_sp_number,@package_group,@reportable_quantity_flag,
			@RQ_reason,@UN_NA_flag,@UN_NA_number,@tsdf_code,@DOT_waste_flag,@DOT_shipping_desc_additional,
			@process_code_uid,@created_from_template_profile_id,
			--Workorderdetail
			@sequence_id,@billing_sequence_id,@bill_rate,@waste_stream,@description,@management_code,
			@manifest,@manifest_page_num,@manifest_line,@container_count,@container_code,@sub_sequence_id,
			@item_type_ind, @month,@year,@pounds,@manual_entry_desc,@size,@quantity,@manifest_flag,@billing_flag,
			--upload_note_profile
			@subject,@note_segment_1,@note_segment_2,@note_segment_3,@note_segment_4,@tsdf_company_id,
			@tsdf_profit_ctr_id
		END
	CLOSE curProfile;
	DEALLOCATE curProfile;
END
	
BEGIN /* Profile Constitunets */
	DECLARE curProfileConstitunets CURSOR FOR
		SELECT
			 tab.col.value('profile_id[1]','INT') as profile_id
			,tab.col.value('tsdf_approval_id[1]','INT') as tsdf_approval_id
			,tab.col.value('const_id[1]','INT') as const_id
			,tab.col.value('concentration[1]','float') as concentration
			,tab.col.value('unit[1]','varchar(10)') as unit
			,tab.col.value('UHC[1]','char(1)') as UHC
		FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/profileConstituents/ProfileConstituent') AS tab(col)

	OPEN curProfileConstitunets FETCH NEXT FROM curProfileConstitunets 
		INTO @profile_id,@tsdf_approval_id,@const_id,@concentration,@unit,@UHC
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF(@profile_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_profileconstituent
				@trip_sync_upload_id, @profile_id,@const_id,@concentration,@unit,@UHC
			END
			ELSE IF(@tsdf_approval_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_tsdfapprovalconstituent
				@trip_sync_upload_id, @tsdf_approval_id,@company_id,@profit_ctr_id,@const_id,
				@concentration,@unit,@UHC
			END
			FETCH NEXT FROM curProfileConstitunets
			INTO  @profile_id,@tsdf_approval_id,@const_id,@concentration,@unit,@UHC
		END
	CLOSE curProfileConstitunets;
	DEALLOCATE curProfileConstitunets;
END

BEGIN /* Profile LDR */
	DECLARE curProfileSubCategory CURSOR FOR
		SELECT
			 tab.col.value('profile_id[1]','INT') as profile_id
			,tab.col.value('tsdf_approval_id[1]','INT') as tsdf_approval_id
			,tab.col.value('ldr_subcategory_id[1]','INT') as ldr_subcategory_id
		FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/profileLdrSubCategories/ProfileLdrSubCategory') AS tab(col)

	OPEN curProfileSubCategory FETCH NEXT FROM curProfileSubCategory 
		INTO @profile_id,@tsdf_approval_id,@ldr_subcategory_id
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF(@profile_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_profileldrsubcategory
				@trip_sync_upload_id, @profile_id,@ldr_subcategory_id
			END
			ELSE IF(@tsdf_approval_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_tsdfapprovalldrsubcategory
				@trip_sync_upload_id, @tsdf_approval_id,@ldr_subcategory_id
			END
			FETCH NEXT FROM curProfileSubCategory
			INTO  @profile_id,@tsdf_approval_id,@ldr_subcategory_id
		END
	CLOSE curProfileSubCategory;
	DEALLOCATE curProfileSubCategory;
END

BEGIN /* Profile Waste Code */

	DECLARE curProfileWasteCode CURSOR FOR
		SELECT
			 tab.col.value('profile_id[1]','INT') as profile_id
			,tab.col.value('tsdf_approval_id[1]','INT') as tsdf_approval_id
			,tab.col.value('waste_code_uid[1]','INT') as waste_code_uid
			,tab.col.value('waste_code[1]','varchar(4)') as waste_code
			,tab.col.value('primary_flag[1]','varchar(10)') as primary_flag
			,tab.col.value('sequence_id[1]','INT') as sequence_id
			,tab.col.value('sequence_flag[1]','char(1)') as sequence_flag
		FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/profileWasteCodes/ProfileWasteCode') AS tab(col)

	OPEN curProfileWasteCode FETCH NEXT FROM curProfileWasteCode 
		INTO @profile_id,@tsdf_approval_id,@waste_code_uid,@waste_code,@primary_flag,@sequence_id,
		@sequence_flag
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @waste_sequence_flag= CASE WHEN waste_code_origin='F' THEN waste_code_origin
			WHEN waste_code_origin='S' THEN 'B'
			ELSE 'A'
			END
			FROM #tempwastecode WHERE waste_code_uid=@waste_code_uid
			IF(@profile_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_profilewastecode
				@trip_sync_upload_id, @profile_id,@waste_code_uid,@waste_code,@primary_flag,@sequence_id,
				@waste_sequence_flag
			END
			ELSE IF(@tsdf_approval_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_tsdfapprovalwastecode
				@trip_sync_upload_id, @tsdf_approval_id,@company_id,@profit_ctr_id,@waste_code_uid,
				@waste_code,@primary_flag,@sequence_id,@waste_sequence_flag
			END
			FETCH NEXT FROM curProfileWasteCode
			INTO  @profile_id,@tsdf_approval_id,@waste_code_uid,@waste_code,@primary_flag,@sequence_id,
			@sequence_flag
		END
	CLOSE curProfileWasteCode;
	DEALLOCATE curProfileWasteCode;
END

BEGIN /* Profile Unit */

	DECLARE curProfileUnit CURSOR FOR
		SELECT
			 tab.col.value('profile_id[1]','INT') as profile_id
			,tab.col.value('tsdf_approval_id[1]','INT') as tsdf_approval_id
			,tab.col.value('bill_unit_code[1]','varchar(4)') as bill_unit_code
			,tab.col.value('tsdf_company_id[1]','INT') as tsdf_company_id
			,tab.col.value('tsdf_profit_ctr_id[1]','INT') as tsdf_profit_ctr_id
		FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/profileUnits/ProfileUnit') AS tab(col)

	OPEN curProfileUnit FETCH NEXT FROM curProfileUnit 
		INTO @profile_id,@tsdf_approval_id,@bill_unit_code,@tsdf_company_id,@tsdf_profit_ctr_id	
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF(@profile_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_profileunit
				@trip_sync_upload_id, @profile_id,@tsdf_company_id,@tsdf_profit_ctr_id,@bill_unit_code
			END
			ELSE IF(@tsdf_approval_id<0)
			BEGIN
				EXEC dbo.sp_labpack_sync_upload_tsdfapprovalunit
				@trip_sync_upload_id, @tsdf_approval_id,@company_id,@profit_ctr_id,@bill_unit_code
			END
			FETCH NEXT FROM curProfileUnit
			INTO  @profile_id,@tsdf_approval_id,@bill_unit_code,@tsdf_company_id,@tsdf_profit_ctr_id
		END
	CLOSE curProfileUnit;
	DEALLOCATE curProfileUnit;
END

BEGIN /* Workorder waste code */
	DECLARE curWorkOrderWasteCode CURSOR FOR
		SELECT
			 tab.col.value('workorder_sequence_id[1]','INT') as workorder_sequence_id
			,tab.col.value('waste_code_uid[1]','INT') as waste_code_uid
			,tab.col.value('waste_code[1]','varchar(4)') as waste_code
			,tab.col.value('sequence_id[1]','INT') as sequence_id
		FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/workorderWasteCodes/WorkorderWasteCode') AS tab(col)

	OPEN curWorkOrderWasteCode FETCH NEXT FROM curWorkOrderWasteCode 
		INTO @workorder_sequence_id,@waste_code_uid, @waste_code,@sequence_id
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC sp_labpack_sync_upload_workorderwastecode
			@trip_sync_upload_id, @workorder_id,@company_id,@profit_ctr_id,@workorder_sequence_id,
			@waste_code_uid, @waste_code,@sequence_id
			FETCH NEXT FROM curWorkOrderWasteCode
			INTO  @workorder_sequence_id,@waste_code_uid, @waste_code,@sequence_id
		END
	CLOSE curWorkOrderWasteCode;
	DEALLOCATE curWorkOrderWasteCode;
END

BEGIN /* Labour */
	DECLARE curLabour CURSOR FOR
		SELECT
			tab.col.value('resource_class_code[1]','varchar(10)') as resource_class_code
			,tab.col.value('chemist_name[1]','varchar(10)') as chemist_name
			,tab.col.value('labour_quantity[1]','float') as labour_quantity
		FROM @Data.nodes('WorkOrderHeaderInfo/uploadLabours/UploadLabour') AS tab(col)
	OPEN curLabour FETCH NEXT FROM curLabour 
		INTO @resource_class_code,@chemist_name,@labour_quantity
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC dbo.sp_labpack_sync_upload_labour
			@trip_sync_upload_id, @workorder_id,@company_id,@profit_ctr_id,@resource_class_code,
			@chemist_name,@labour_quantity
			FETCH NEXT FROM curLabour
			INTO  @resource_class_code,@chemist_name,@labour_quantity
		END
	CLOSE curLabour;
	DEALLOCATE curLabour;
END

BEGIN /* Other Supply */
	DECLARE curSupply CURSOR FOR
		SELECT
			tab.col.value('resource_class_code[1]','varchar(10)') as resource_class_code
			,tab.col.value('supply_desc[1]','varchar(10)') as supply_desc
			,tab.col.value('quantity[1]','INT') as quantity
			,tab.col.value('quantity_billable[1]','INT') as quantity_billable
		FROM @Data.nodes('WorkOrderHeaderInfo/uploadSupplies/UploadSupply') AS tab(col)
	OPEN curSupply FETCH NEXT FROM curSupply 
		INTO @resource_class_code,@supply_desc,@quantity,@quantity_billable
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC dbo.sp_labpack_sync_upload_supply
			@trip_sync_upload_id, @workorder_id,@company_id,@profit_ctr_id,@resource_class_code,@supply_desc,
			@quantity,@quantity_billable
			FETCH NEXT FROM curSupply
			INTO  @resource_class_code,@supply_desc,@quantity,@quantity_billable
		END
	CLOSE curSupply;
	DEALLOCATE curSupply;
END

BEGIN /* Workorder Detail Units*/
	DECLARE curWorkOrderDetailUnit CURSOR FOR
		SELECT
			tab.col.value('quantity[1]','float') as quantity
			,tab.col.value('manifest_flag[1]','char(1)') as manifest_flag
			,tab.col.value('billing_flag[1]','char(1)') as billing_flag
			,tab.col.value('bill_unit_code[1]','varchar(4)') as bill_unit_code
			,tab.col.value('sequence_id[1]','INT') as sequence_id
		FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/workorderDetailUnits/WorkorderDetailUnit') AS tab(col)
	OPEN curWorkOrderDetailUnit FETCH NEXT FROM curWorkOrderDetailUnit 
		INTO @quantity,@manifest_flag, @billing_flag,@bill_unit_code,@sequence_id
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC dbo.sp_labpack_sync_upload_workorderdetailunit
				@trip_sync_upload_id,@workorder_id,@company_id,@profit_ctr_id,@sequence_id,@bill_unit_code,
				@quantity,@manifest_flag,@billing_flag
			FETCH NEXT FROM curWorkOrderDetailUnit
			INTO  @quantity,@manifest_flag, @billing_flag,@bill_unit_code,@sequence_id
		END
	CLOSE curWorkOrderDetailUnit;
	DEALLOCATE curWorkOrderDetailUnit;
END
-- labPackJobSheet
BEGIN
    DECLARE curlabPackJobSheet CURSOR FOR
        SELECT
            tab.col.value('(job_notes)[1]', 'varchar(255)') AS job_notes,
            tab.col.value('(truck_id)[1]', 'varchar(50)') AS truck_id,
            tab.col.value('(HHW_name)[1]', 'varchar(25)') AS HHW_name,
            tab.col.value('(otherinfo_text)[1]', 'varchar(max)') AS otherinfo_text,
            tab.col.value('(auth_name)[1]', 'varchar(100)') AS auth_name,
            tab.col.value('(is_change_auth_enabled)[1]', 'int') AS is_change_auth_enabled
        FROM @Data.nodes('WorkOrderHeaderInfo/labPackJobSheets/LabPackJobSheet') AS tab(col)
    OPEN curlabPackJobSheet
    FETCH NEXT FROM curlabPackJobSheet
    INTO @job_notes, @truck_id, @HHW_name, @otherinfo_text, @auth_name, @is_change_auth_enabled
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC @jobsheet_uid = dbo.sp_labpack_sync_upload_LabPackJobSheet
            @workorder_id, @company_id, @profit_ctr_id, @job_notes,
            @truck_id, @HHW_name, @otherinfo_text, @auth_name,
            @is_change_auth_enabled, @user_id
        FETCH NEXT FROM curlabPackJobSheet
        INTO @job_notes, @truck_id, @HHW_name, @otherinfo_text, @auth_name, @is_change_auth_enabled
    END
    CLOSE curlabPackJobSheet;
    DEALLOCATE curlabPackJobSheet;
END

-- LabPackJobSheetXComments
BEGIN
    DECLARE curLabPackJobSheetXComments CURSOR FOR
        SELECT
            tab.col.value('comment[1]', 'varchar(max)') AS comment
        FROM @Data.nodes('WorkOrderHeaderInfo/labPackJobSheetComments/LabPackJobSheetXComment') AS tab(col)
    OPEN curLabPackJobSheetXComments
    FETCH NEXT FROM curLabPackJobSheetXComments
    INTO @comment
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.sp_labpack_sync_upload_LabPackJobSheetXComments
            @jobsheet_uid, @comment, @user_id 
        FETCH NEXT FROM curLabPackJobSheetXComments
        INTO @comment
    END
    CLOSE curLabPackJobSheetXComments;
    DEALLOCATE curLabPackJobSheetXComments;
END

-- LabPackJobSheetXLabor
BEGIN
    DECLARE curLabPackJobSheetXLabor CURSOR FOR
        SELECT
            tab.col.value('(resource_class_code)[1]', 'varchar(10)') AS resource_class_code,
            tab.col.value('(chemist_name)[1]', 'varchar(255)') AS chemist_name,
            tab.col.value('(dispatch_time)[1]', 'time') AS dispatch_time,
            tab.col.value('(onsite_time)[1]', 'time') AS onsite_time,
            tab.col.value('(jobfinish_time)[1]', 'time') AS jobfinish_time,
            tab.col.value('(est_return_time)[1]', 'time') AS est_return_time
        FROM @Data.nodes('WorkOrderHeaderInfo/labPackJobSheetLabors/LabPackJobSheetXLabor') AS tab(col)
    OPEN curLabPackJobSheetXLabor
    FETCH NEXT FROM curLabPackJobSheetXLabor
    INTO @resource_class_code, @chemist_name, @dispatch_time, @onsite_time, @jobfinish_time, @est_return_time
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC dbo.sp_labpack_sync_upload_LabPackJobSheetXLabor
            @jobsheet_uid, @resource_class_code, @chemist_name, @dispatch_time, @onsite_time,
            @jobfinish_time, @est_return_time, @user_id
        FETCH NEXT FROM curLabPackJobSheetXLabor
        INTO @resource_class_code, @chemist_name, @dispatch_time, @onsite_time, @jobfinish_time, @est_return_time
    END
    CLOSE curLabPackJobSheetXLabor;
    DEALLOCATE curLabPackJobSheetXLabor;
END

-- LabPackLabel
BEGIN
    DECLARE curLabPackLabel CURSOR FOR
        SELECT
            tab.col.value('(TSDF_code)[1]', 'varchar(15)') AS TSDF_code,
            tab.col.value('(label_type)[1]', 'char(1)') AS label_type,
            tab.col.value('(sequence_ID)[1]', 'int') AS Sequence_ids
        FROM @Data.nodes('WorkOrderHeaderInfo/labpackContainers/LabpackContainer/labPackLabels/LabPackLabel') AS tab(col)
    OPEN curLabPackLabel
    FETCH NEXT FROM curLabPackLabel
    INTO @TSDF_code, @label_type, @sequence_id
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC @label_uid = dbo.sp_labpack_sync_upload_LabPackLabel
            @workorder_id, @company_id, @profit_ctr_id, @TSDF_code, @label_type, @sequence_id, @user_id
        BEGIN
            DECLARE curLabpackLabelXInventory CURSOR FOR
                SELECT inventoryconstituent_name, notes, epa_rcra_codes, quantity, size, phase
                FROM #tempinventory WHERE Sequenceid = @sequence_id order by Inventoryid
				Select * from #tempinventory
            OPEN curLabpackLabelXInventory
            FETCH NEXT FROM curLabpackLabelXInventory
            INTO @inventoryconstituent_name, @notes, @epa_rcra_codes, @quantity, @size, @phase
            WHILE @@FETCH_STATUS = 0
            BEGIN
                EXEC dbo.sp_labpack_sync_upload_LabPackLabelXInventory
                    @label_uid, @notes, @epa_rcra_codes, @quantity, @size, @phase, @inventoryconstituent_name, @user_id
                FETCH NEXT FROM curLabpackLabelXInventory
                INTO @inventoryconstituent_name, @notes, @epa_rcra_codes, @quantity, @size, @phase
            END
            CLOSE curLabpackLabelXInventory;
            DEALLOCATE curLabpackLabelXInventory;
        END
        FETCH NEXT FROM curLabPackLabel
        INTO @TSDF_code, @label_type, @sequence_id
    END
    CLOSE curLabPackLabel;
    DEALLOCATE curLabPackLabel;
END
EXEC sp_labpack_sync_upload_end @trip_sync_upload_id

IF EXISTS(SELECT * FROM tripsyncupload WHERE trip_sync_upload_id=@trip_sync_upload_id AND processed_flag='T')
BEGIN
	SET @Message ='WorkOrder uploaded successfully'
END
ELSE
BEGIN
	SET @Message ='Error in WorkOrder uploaded'	
END

END TRY
	BEGIN CATCH
	SET @Message =ERROR_MESSAGE() +ERROR_PROCEDURE()
	END CATCH
END
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_workorder] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_workorder] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_workorder] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_workorder] TO EQAI;
GO
