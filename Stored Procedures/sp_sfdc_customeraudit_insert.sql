USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_customeraudit_insert]    Script Date: 4/29/2024 3:08:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[sp_sfdc_customeraudit_insert]
				@mail_to_bill_to_address_flag char(1),
				@print_wos_with_start_date_flag char(1),
				@customer_id int,
				@billing_project_id int,
				@region_id int,
				@release_required_flag char(1),
				@terms_code varchar(8),
				@distrubation_method_cbilling char(1),
				@all_facilities_flag char(1),
				@break_code_1 char(1),
				@break_code_2 char(1),
				@break_code_3 char(1),
				@consolidate_containers_flag char(1),
				@ebilling_flag char(1),
				@eq_approved_offeror_desc varchar(20),
				@eq_approved_offeror_flag char(1),
				@eq_offeror_bp_override_flag char(1),
				@eq_offeror_effective_dt datetime,
				@insurance_surcharge_flag char(1),
				@internal_review_flag char(1),
				@intervention_desc varchar(255),
				@intervention_required_flag char(1),
				@invoice_flag char(1),
				@invoice_package_content char(1),
				@invoice_package_content_cbilling char(1),
				@invoice_print_attachment_flag char(1) ,
				@link_required_flag char(1),
				@pickup_report_flag char(1),
				@PO_required_flag char(1),
				@print_wos_in_inv_attachment_flag char(1),
				@retail_flag char(1),
				@sort_code_1 char(1),
				@sort_code_2 char(1),
				@sort_code_3 char(1),
				@status char(1),
				@submit_on_hold_flag char(1),
				@trip_stop_rate_default_flag char(1),
				@weight_ticket_required_flag char(1),
				@whca_exempt char(1),
				@user_code varchar(10),
				@date_added datetime,
				@date_modified datetime,
				@record_type char(1),
				@project_name varchar(40),
				@salesforce_contract_number varchar(80),
				@emanifest_fee_option char(1),
				@emanifest_fee money,
				@emanifest_flag char(1),
				@date_effective datetime,
				@use_corporate_rate_EIRRATE char(1),
				@apply_fee_flag char(1),
				@apply_fee_flag_ERF char(1),
				@apply_fee_flag_FRF char(1),
				@trans_source_R char(1),
				@validation_error char(1),
				@print_on_invoice_required_flag_T char(1),
				@Invoice_copy_flag char(1),
				@distribution_method char(1),
				@businesssegment_uid_1 INT,
				@businesssegment_uid_2 int,
				@customer_billing_territory_type char(1),
				@customer_billing_territory_code varchar(8),
				@customer_billing_territory_primary_flag char(1),
				@customer_billing_territory_percent float,
				@customer_billing_territory_status char(1),
				@po_validation char(1),
				@invoice_comment_1 varchar(80),
				@invoice_comment_2 varchar(80),
				@invoice_comment_3 varchar(80),
				@invoice_comment_4 varchar(80),
				@invoice_comment_5 varchar(80),
				@contact_id int

/*

Description: 

Customer audit records will be inserted whenever the insert happen in the customerbilling,customerbillingemanistfee,
CustomerBillingXContact,customerbillingdocument,CustomerBillingERFRate
CustomerBillingEIRRate,CustomerBillingFRFRate,CustomerBillingTerritory through storedprocedure sp_sfdc_customerbilling_Insert

Revision History:

DevOps# 80454 - 04/01/2024  Nagaraj M   Created
DevOps# 84585 - 04/12/2024  Nagaraj M   Added audit reference for the billing_project_id column
Devops# 85363 - 04/23/2024  Nagaraj M   Added the columns invoice_comment_1,invoice_comment_2,invoice_comment_3,invoice_comment_4,invoice_comment_5,@contact_id
										to insert into customeraudit table.
*/				
								
AS
BEGIN
Declare 
	@before_value varchar(100) ='(inserted)',
	@customer_billing_emanifest_fee_uid int,
	@customerbilling_erf_rate_uid INT,
	@customerbilling_frf_rate_uid int,
	@customerbillingeirrate_uid int,
	@customerbillingterritory_uid int,
	@EIR_RATE money =null,
	@audit_reference varchar(100),
	@li_count int = 1,
	@column_value varchar(100),
	@COLUMN_NAME VARCHAR(100),
	@customer_billing_parameter_count int = 93,
	@Key_value varchar(4000),
	@table_name varchar(100),
	@source_system varchar(100),
	@date_modified_getdate datetime=getdate(),
	@ERROR CHAR(1)='N'
	


	BEGIN TRY
	BEGIN
		Select @source_system = 'sp_sfdc_customeraudit_insert'
		WHILE @li_count <=@customer_billing_parameter_count
			BEGIN
			if @li_count=1
			BEGIN
				SELECT @column_value=@mail_to_bill_to_address_flag 
				SELECT @column_name='mail_to_bill_to_address_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =2
			BEGIN
				SELECT @column_value=@print_wos_with_start_date_flag 
				SELECT @column_name='print_wos_with_start_date_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =3
			BEGIN
				SELECT @column_value=@customer_id 
				SELECT @column_name='customer_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			IF @li_count=4
			BEGIN
				SELECT @column_value=@billing_project_id 
				SELECT @column_name='billing_project_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=5
			BEGIN
				SELECT @column_value=@region_id 
				SELECT @column_name='region_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=6
			BEGIN
				SELECT @column_value=@release_required_flag 
				SELECT @column_name='release_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =7
			BEGIN
				SELECT @column_value=@terms_code 
				SELECT @column_name='terms_code'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=8
			BEGIN
				SELECT @column_value=@distrubation_method_cbilling
				SELECT @column_name='distrubation_method_cbilling'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =9
			BEGIN
				SELECT @column_value=@all_facilities_flag
				SELECT @column_name='all_facilities_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=10
			BEGIN
				SELECT @column_value=@break_code_1
				SELECT @column_name='break_code_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =11
				BEGIN
				SELECT @column_value=@break_code_2
				SELECT @column_name='break_code_2'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=12
			BEGIN
				SELECT @column_value=@break_code_3
				SELECT @column_name='break_code_3'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =13
			BEGIN
				SELECT @column_value=@consolidate_containers_flag
				SELECT @column_name='consolidate_containers_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			If @li_count=14
			BEGIN
				SELECT @column_value=@ebilling_flag
				SELECT @column_name='ebilling_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =15
			BEGIN
				SELECT @column_value=@eq_approved_offeror_desc
				SELECT @column_name='eq_approved_offeror_desc'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
				if @li_count=16
			BEGIN
				SELECT @column_value=@eq_approved_offeror_flag
				SELECT @column_name='eq_approved_offeror_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =17
			BEGIN
				SELECT @column_value=@eq_offeror_bp_override_flag
				SELECT @column_name='eq_offeror_bp_override_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=18
			BEGIN
				SELECT @column_value=CONVERT(varchar,@eq_offeror_effective_dt,101)
				SELECT @column_name='eq_offeror_effective_dt'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =19
			BEGIN
				SELECT @column_value=@insurance_surcharge_flag
				SELECT @column_name='insurance_surcharge_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=20
			BEGIN
				SELECT @column_value=@internal_review_flag
				SELECT @column_name='internal_review_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =21
			BEGIN
				SELECT @column_value=@intervention_desc
				SELECT @column_name='intervention_desc'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=22
			BEGIN
				SELECT @column_value=@intervention_required_flag
				SELECT @column_name='intervention_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =23
			BEGIN
				SELECT @column_value=@invoice_flag
				SELECT @column_name='invoice_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=24
			BEGIN
				SELECT @column_value=@invoice_package_content_cbilling
				SELECT @column_name='invoice_package_content'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =25
			BEGIN
				SELECT @column_value=@invoice_print_attachment_flag
				SELECT @column_name='invoice_print_attachment_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=26
			BEGIN
				SELECT @column_value=@link_required_flag
				SELECT @column_name='link_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =27
			BEGIN
				SELECT @column_value=@pickup_report_flag 
				SELECT @column_name='pickup_report_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=28
			BEGIN
				SELECT @column_value=@PO_required_flag
				SELECT @column_name='PO_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =29
			BEGIN
				SELECT @column_value=@print_wos_in_inv_attachment_flag
				SELECT @column_name='print_wos_in_inv_attachment_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=30
			BEGIN
				SELECT @column_value=@retail_flag
				SELECT @column_name='retail_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =31
			BEGIN
				SELECT @column_value=@sort_code_1
				SELECT @column_name='sort_code_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=32
			BEGIN
				SELECT @column_value=@sort_code_2
				SELECT @column_name='sort_code_2'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =33
			BEGIN
				SELECT @column_value=@sort_code_3
				SELECT @column_name='sort_code_3'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=34
			BEGIN
				SELECT @column_value=@status
				SELECT @column_name='status'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =35
			BEGIN
				SELECT @column_value=@submit_on_hold_flag
				SELECT @column_name='submit_on_hold_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=36
			BEGIN
				SELECT @column_value=@trip_stop_rate_default_flag
				SELECT @column_name='trip_stop_rate_default_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =37
			BEGIN
				SELECT @column_value=@weight_ticket_required_flag
				SELECT @column_name='weight_ticket_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=38
			BEGIN
				SELECT @column_value=@whca_exempt
				SELECT @column_name='whca_exempt'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =39
			BEGIN
				SELECT @column_value=@user_code
				SELECT @column_name='added_by'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=40
			BEGIN
				SELECT @column_value=CONVERT(varchar,@date_added,101)
				SELECT @column_name='date_added'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=41
			BEGIN
				SELECT @column_value=CONVERT(varchar,@date_modified,101)
				SELECT @column_name='date_modified'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=42
			BEGIN
				SELECT @column_value=@record_type
				SELECT @column_name='record_type'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =43
			BEGIN
				SELECT @column_value=@project_name
				SELECT @column_name='project_name'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=44
			BEGIN
				SELECT @column_value=@salesforce_contract_number
				SELECT @column_name='salesforce_contract_number'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			--CustomerBillingeManifestFee
			
			BEGIN
				select @customer_billing_emanifest_fee_uid=customer_billing_emanifest_fee_uid
				from CustomerBillingeManifestFee
				where billing_project_id=@billing_project_id
				and customer_id=@customer_id
				
			END
			if @li_count=45
			BEGIN
				SELECT @column_value=@emanifest_fee_option
				SELECT @column_name='emanifest_fee_option'
				select @table_name='CustomerBillingeManifestFee'
				Select @audit_reference = 'customer_billing_emanifest_fee_uid:' 
				+trim(str(@customer_billing_emanifest_fee_uid)) + ' customer_id: ' + 
				trim(str(@customer_id)) +' billing project id: '
				+ trim(str(@billing_project_id))
			END
			if @li_count=46
			BEGIN
				SELECT @column_value=@emanifest_flag
				SELECT @column_name='emanifest_flag'
				select @table_name='CustomerBillingeManifestFee'
				Select @audit_reference = 'customer_billing_emanifest_fee_uid:' 
				+trim(str(@customer_billing_emanifest_fee_uid)) + ' customer_id: ' + 
				trim(str(@customer_id)) +' billing project id: '
				+ trim(str(@billing_project_id))
			END
			if @li_count=47
			BEGIN
				SELECT @column_value=CONVERT(varchar,@date_effective,101)
				SELECT @column_name='date_effective'
				select @table_name='CustomerBillingeManifestFee'
				Select @audit_reference = 'customer_billing_emanifest_fee_uid:' 
				+trim(str(@customer_billing_emanifest_fee_uid)) + ' customer_id: ' + 
				trim(str(@customer_id)) +' billing project id: '
				+ trim(str(@billing_project_id))
			END
				
			select @customerbillingeirrate_uid=customerbillingeirrate_uid
			from CustomerBillingEIRRate
			where billing_project_id=@billing_project_id
			and customer_id=@customer_id
					
			if @li_count=48
			BEGIN
				SELECT @column_value=@use_corporate_rate_EIRRATE
				SELECT @column_name='use_corporate_rate'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END
			if @li_count=49
			BEGIN
				SELECT @column_value=str(@EIR_RATE)
				SELECT @column_name='EIR_RATE'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END
			if @li_count=50
			BEGIN
				SELECT @column_value=CONVERT(varchar,getdate(),101)
				SELECT @column_name='date_effective'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END
			if @li_count=51
			BEGIN
				SELECT @column_value=@apply_fee_flag
				SELECT @column_name='apply_fee_flag'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END
			
			BEGIN
			select @customerbilling_erf_rate_uid=customer_billing_erf_rate_uid
			from CustomerBillingERFRate
			where billing_project_id=@billing_project_id
			and customer_id=@customer_id
			END
				
			--BEGIN
			if @li_count=52
			BEGIN
				SELECT @column_value=CONVERT(varchar,getdate(),101)
				SELECT @column_name='date_effective'
				select @table_name='CustomerBillingERFRate'
				Select @audit_reference = 'customerbilling_erf_rate_uid:' 
										   +trim(str(@customer_billing_emanifest_fee_uid)) 
											+ ' customer_id: ' + trim(str(@customer_id))
											+' billing project id: '
											+ trim(str(@billing_project_id))
											
			
			END
			if @li_count=53
			BEGIN
				SELECT @column_value=@apply_fee_flag_ERF
				SELECT @column_name='apply_fee_flag'
				select @table_name='CustomerBillingERFRate'
				Select @audit_reference = 'customerbilling_erf_rate_uid:' 
										   +trim(str(@customer_billing_emanifest_fee_uid)) 
											+ ' customer_id: ' + trim(str(@customer_id))
											+' billing project id: '
											+ trim(str(@billing_project_id))
				
			END

			BEGIN
				select @customerbilling_frf_rate_uid=customer_billing_frf_rate_uid
				from CustomerBillingfRfRate
				where billing_project_id=@billing_project_id
				and customer_id=@customer_id
			END
				
				--BEGIN
				if @li_count=54
				BEGIN
					SELECT @column_value=CONVERT(varchar,getdate(),101)
					SELECT @column_name='date_effective'
					select @table_name='CustomerBillingFRFRate'
					Select @audit_reference = 'customerbilling_erf_rate_uid:' 
											+ trim(str(@customer_billing_emanifest_fee_uid)) 
											+ ' customer_id: ' + trim(str(@customer_id)) 
											+' billing project id: '
											+ trim(str(@billing_project_id))
			
				END
				if @li_count=55
				BEGIN
					SELECT @column_value=@apply_fee_flag_FRF
					SELECT @column_name='apply_fee_flag'
					SELECT @table_name='CustomerBillingFRFRate'
					Select @audit_reference = 'customerbilling_erf_rate_uid:' 
											+ trim(str(@customer_billing_emanifest_fee_uid)) 
											+ ' customer_id: ' + trim(str(@customer_id)) 
											+' billing project id: '
											+ trim(str(@billing_project_id))
			
				END
				--END	
		
				
				--BEGIN
				if @li_count=56
				BEGIN
					SELECT @column_value=@status
					SELECT @column_name='status'
					select @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' type_id: 1'
				
				END

				if @li_count=57
				BEGIN
					SELECT @column_value=@trans_source_R
					SELECT @column_name='trans_source'
					select @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' type_id: 1'
				
				END
				if @li_count=58
				BEGIN
					SELECT @column_value='1'
					SELECT @column_name='type_id'
					select @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' type_id: 1'
				
				END
				if @li_count=59
				BEGIN
					SELECT @column_value=@validation_error
					SELECT @column_name='validation'
					SELECT @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' type_id: 1'
				
				END
				if @li_count=60
				BEGIN
					SELECT @column_value=@print_on_invoice_required_flag_T
					SELECT @column_name='print_on_invoice_required_flag'
					select @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' type_id: 1'
				
				END
				
				
				if @li_count=61
				BEGIN
					SELECT @column_value='W'
					SELECT @column_name='trans_source'
					select @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: '
											 +trim(str(@customer_id)) 
											+' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 20'
				
				END
				if @li_count=62
				BEGIN
					SELECT @column_value='20'
					SELECT @column_name='type_id'
					SELECT @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: '
											 +trim(str(@customer_id)) 
											+' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 20'
				
				END
				if @li_count=63
				BEGIN
					SELECT @column_value='W'
					SELECT @column_name='validation'
					select @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: '
											 +trim(str(@customer_id)) 
											+' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 20'
				
				END
				if @li_count=64
				BEGIN
					SELECT @column_value='F'
					SELECT @column_name='print_on_invoice_required_flag'
					SELECT @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: '
											 +trim(str(@customer_id)) 
											+' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 20'
				
				END
				
				if @li_count=65
				BEGIN
					SELECT @column_value='W'
					SELECT @column_name='trans_source'
					SELECT @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											 + trim(str(@customer_id)) 
											 +' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 28' 
				END
				if @li_count=66
				BEGIN
					SELECT @column_value='28'
					SELECT @column_name='type_id'
					SELECT @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											 + trim(str(@customer_id)) 
											 +' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 28' 
				END
				if @li_count=67
				BEGIN
					SELECT @column_value='W'
					SELECT @column_name='validation'
					SELECT @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											 + trim(str(@customer_id)) 
											 +' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 28' 
				END
				if @li_count=68
				BEGIN
					SELECT @column_value='F'
					SELECT @column_name='print_on_invoice_required_flag'
					select @table_name='customerbillingdocument'
					Select @audit_reference = 'customer_id: ' 
											 + trim(str(@customer_id)) 
											 +' billing project id: '+ trim(str(@billing_project_id)) 
											+ ' type_id: 28' 
				END
				if @li_count=69
				BEGIN
					SELECT @column_value=0
					SELECT @column_name='contact_id'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END
				if @li_count=70
				BEGIN
					SELECT @column_value=@invoice_copy_flag
					SELECT @column_name='invoice_copy_flag'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END
				if @li_count=71
				BEGIN
					SELECT @column_value=@distribution_method
					SELECT @column_name='distribution_method'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id)) 
				
				END
				if @li_count=72
				BEGIN
					SELECT @column_value=null
					SELECT @column_name='attn_name_flag'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END
				if @li_count=73
				BEGIN
					SELECT @column_value=@invoice_package_content
					SELECT @column_name='invoice_package_content'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END


				-- CustomerBillingTerritory

				BEGIN
					select @customerbillingterritory_uid=customerbillingterritory_uid
					from CustomerBillingTerritory
					where billing_project_id=@billing_project_id
					and customer_id=@customer_id
				END
				
				if @li_count=74
				BEGIN
					SELECT @column_value=cast((convert(int,isnull(@businesssegment_uid_1,''))) as varchar(20))
					SELECT @column_name='businesssegment_uid_1'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=75
				BEGIN
					SELECT @column_value=@customer_billing_territory_type
					SELECT @column_name='customer_billing_territory_type'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=76
				BEGIN
					SELECT @column_value=@customer_billing_territory_code
					SELECT @column_name='customer_billing_territory_code'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=77
				BEGIN
					SELECT @column_value=@customer_billing_territory_primary_flag
					SELECT @column_name='customer_billing_territory_primary_flag'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=78
				BEGIN
					SELECT @column_value=cast((convert(float,isnull(@customer_billing_territory_percent,''))) as varchar(20))
					SELECT @column_name='customer_billing_territory_percent'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=79
				BEGIN
					SELECT @column_value=@customer_billing_territory_status
					SELECT @column_name='customer_billing_territory_status'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END


				if @li_count=80
				BEGIN
					SELECT @column_value=cast((convert(int,isnull(@businesssegment_uid_2,''))) as varchar(20))
					SELECT @column_name='businesssegment_uid_2'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=81
				BEGIN
					SELECT @column_value=@customer_billing_territory_type
					SELECT @column_name='customer_billing_territory_type'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=82
				BEGIN
					SELECT @column_value=@customer_billing_territory_code
					SELECT @column_name='customer_billing_territory_code'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=83
				BEGIN
					SELECT @column_value=@customer_billing_territory_primary_flag
					SELECT @column_name='customer_billing_territory_primary_flag'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=84
				BEGIN
					SELECT @column_value=cast((convert(float,isnull(@customer_billing_territory_percent,''))) as varchar(20))
					SELECT @column_name='customer_billing_territory_percent'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=85
				BEGIN
					SELECT @column_value=@customer_billing_territory_status
					SELECT @column_name='customer_billing_territory_status'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END


			
		
			if @li_count=86
			BEGIN
				SELECT @column_value=@billing_project_id 
				SELECT @column_name='billing_project_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'Billing Project created for ACV import per ' +@user_code
			END

			if @li_count=87
			BEGIN
				SELECT @column_value=@invoice_comment_1 
				SELECT @column_name='invoice_comment_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=88
			BEGIN
				SELECT @column_value=@invoice_comment_2 
				SELECT @column_name='invoice_comment_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=89
			BEGIN
				SELECT @column_value=@invoice_comment_3 
				SELECT @column_name='invoice_comment_3'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=90
			BEGIN
				SELECT @column_value=@invoice_comment_4 
				SELECT @column_name='invoice_comment_4'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=91
			BEGIN
				SELECT @column_value=@invoice_comment_5 
				SELECT @column_name='invoice_comment_5'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=92
			BEGIN
				SELECT @column_value=@po_validation 
				SELECT @column_name='po_validation'
				select @table_name='customerbilling'
					Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END


			if @li_count=93
				BEGIN
					SELECT @column_value=@contact_id
					SELECT @column_name='contact_id'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: '+ str(@contact_id) 
				
				END



			IF @column_value <>''
			--BEGIN TRY
			BEGIN
						INSERT INTO [dbo].CustomerAudit 
							(customer_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
							  modified_by,
							  date_modified
							 )
						SELECT
							  @customer_id,@table_name,@COLUMN_NAME,@before_value,@column_value,@audit_reference,
							  'Salesforce',
							  SUBSTRING(USER_NAME(), 1, 10),
							  @date_modified_getdate
			END
		SET @li_count=@li_count+1
	END
END
END TRY
	BEGIN CATCH
		select @key_value = 'table_name; ' + isnull(@table_name,'') +
						'before_value; ' + isnull(@before_value,'') +
						'column_value;' + isnull(@column_value,'') +
						'COLUMN_NAME ;' + isnull(@COLUMN_NAME,'') +
						'parameter_count;' + isnull(str(@customer_billing_parameter_count),'')

						

		INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
										SELECT 
										@key_value, 
										@source_system, 
										'Insert', 
										ERROR_MESSAGE(), 
										GETDATE(), 
										SUBSTRING(USER_NAME(),1,40) 


SELECT @ERROR ='Y'
RETURN -1
END CATCH 
BEGIN
IF @ERROR ='N'
RETURN 0
END
END


Go


GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customeraudit_insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customeraudit_insert] TO svc_CORAppUser

GO