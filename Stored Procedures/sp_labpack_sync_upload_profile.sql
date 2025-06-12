create or alter procedure [dbo].[sp_labpack_sync_upload_profile]
	@trip_sync_upload_id	int,
	@profile_id				int,
	@company_id				int,
	@profit_ctr_id			int,
	@approval_code			varchar(15),
	@approval_desc			varchar(50),
	@customer_id			int,
	@generator_id			int,
	@bill_unit_code			varchar(4),
	@consistency			varchar(50),
	@DOT_shipping_name		varchar(255),
	@ERG_number				int,
	@ERG_suffix				char(2),
	@hazmat					char(1),
	@hazmat_class			varchar(15),
	@subsidiary_haz_mat_class varchar(15),
	@manifest_dot_sp_number	varchar(20),
	@package_group			varchar(3),
	@reportable_quantity_flag char(1),
	@RQ_reason				varchar(50),
	@RQ_threshold			float,
	@UN_NA_flag				char(2),
	@UN_NA_number			int,
	@waste_code_uid			int,
	@waste_code				varchar(4),
	@DOT_waste_flag			char(1),
	@DOT_shipping_desc_additional varchar(255),
	@process_code_uid		int,
	@created_from_template_profile_id	int
as
/***************************************************************************************
 this procedure records a connection from lab pack field device to upload profile

 loads to Plt_ai
 
 12/17/2019 - rwb created
 12/11/2020 - rwb added @DOT_waste_flag and @DOT_shipping_desc_additional arguments
 06/17/2021 - rwb added @created_from_template_profile_id argument
 05/23/2022 - rwb ADO 42189 - default insert into Profile.inactive_flag as 'F'
 07/05/2023 - rwb ADO 67728 - new profiles created from templates should be uploaded with Approved status
 02/06/2024 - rwb SN INC1212535 - when profiles are created from a template, pull more fields from template

 NOTE:
 If more than one bill unit needs to be added, create a separate proc like for waste codes

exec sp_labpack_sync_upload_profile
 	@trip_sync_upload_id	= 310816,
	@profile_id				= -12345,
	@company_id				= 27,
	@profit_ctr_id			= 0,
	@approval_code			= 'LP-1234567',
	@approval_desc			= 'RBTEST',
	@customer_id			= 15622,
	@generator_id			= 189119,

	@bill_unit_code			= 'LBS',
	@consistency			= 'RBTEST',
	@DOT_shipping_name		= 'RBTEST',
	@ERG_number				= 1,
	@ERG_suffix				= 'RB',
	@hazmat					= 'H',
	@hazmat_class			= 'RBTEST',
	@subsidiary_haz_mat_class = 'RBTEST',
	@manifest_dot_sp_number	= 'RBTEST',
	@package_group			= 'RB',
	@reportable_quantity_flag = 'T',
	@RQ_reason				= 'RBTEST',
	@RQ_threshold			= 100,
	@UN_NA_flag				= 'UN',
	@UN_NA_number			= 1234,
	@waste_code_uid			= 1,
	@waste_code				= 'NONE',
	@DOT_waste_flag			= 'T',
	@DOT_shipping_desc_additional = 'RBTEST',
	@process_code_uid		= 1,
	@created_from_template_profile_id = 736808

****************************************************************************************/

-- add a check to ensure @profile_id < 0... profiles can only be inserted
declare @sql_sequence_id	int,
		@sql				varchar(6000),
		@user				varchar(10),
		@err				int,
		@msg				varchar(255)

set @user = 'LP'

set @sql = 'insert Profile ('
+ 'profile_id'
+ ', curr_status_code'
+ ', customer_id'
+ ', generator_id'
+ ', waste_code'
+ ', bill_unit_code'
+ ', quote_id'
+ ', approval_desc'
+ ', ap_start_date'
+ ', ap_expiration_date'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', tracking_type'
+ ', broker_flag'
+ ', bulk_flag'
+ ', OTS_flag'
+ ', transship_flag'
+ ', generic_flag'
+ ', labpack_flag'
+ ', reapproval_allowed'
+ ', document_update_status'
+ ', urgent_flag'
+ ', cert_flag'
+ ', max_loads'
+ ', max_load_start_date'
+ ', reportable_quantity_flag'
+ ', RQ_reason'
+ ', RQ_threshold'
+ ', DOT_shipping_name'
+ ', hazmat'
+ ', hazmat_class'
+ ', subsidiary_haz_mat_class'
+ ', UN_NA_flag'
+ ', UN_NA_number'
+ ', package_group'
+ ', ERG_number'
+ ', ERG_suffix'
+ ', waste_water_flag'
+ ', SPOC_flag'
+ ', profile_tracking_id'
+ ', manifest_dot_sp_number'
+ ', rcra_listed'
+ ', rcra_characteristic'
+ ', waste_code_uid'
+ ', DOT_waste_flag'
+ ', DOT_shipping_desc_additional'
+ ', labpack_template_flag'
+ ', process_code_uid'
+ ', created_from_template_profile_id'
+ ', inactive_flag)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', ''P'''
+ ', ' + coalesce(convert(varchar(20),@customer_id),'null')
+ ', ' + coalesce(convert(varchar(20),@generator_id),'null')
+ ', ' + coalesce('''' + replace(@waste_code, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@bill_unit_code, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@profile_id),'null')
+ ', ' + coalesce('''' + replace(@approval_desc, '''', '''''') + '''','null')
+ ', ' + '''' + convert(varchar(10),getdate(),101) + ''''
+ ', ' + '''' + convert(varchar(10),dateadd(dd,365,getdate()),101) + ''''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''APRC'''
+ ', ''D'''
+ ', ''U'''
+ ', ''F'''
+ ', ''F'''
+ ', ''U'''
+ ', ''T'''
+ ', ''T'''
+ ', ''A'''
+ ', ''F'''
+ ', ''F'''
+ ', 9999'
+ ', ' + '''' + convert(varchar(10),getdate(),101) + ''''
+ ', ' + coalesce('''' + replace(@reportable_quantity_flag, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@RQ_reason, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@RQ_threshold),'null')
+ ', ' + coalesce('''' + replace(@DOT_shipping_name, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@hazmat, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@hazmat_class, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@subsidiary_haz_mat_class, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@UN_NA_flag, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@UN_NA_number),'null')
+ ', ' + coalesce('''' + replace(@package_group, '''', '''''') + '''','null')
+ ', ' + coalesce(convert(varchar(20),@ERG_number),'null')
+ ', ' + coalesce('''' + replace(@ERG_suffix, '''', '''''') + '''','null')
+ ', ''N'''
+ ', ''F'''
+ ', 1'
+ ', ' + coalesce('''' + replace(@manifest_dot_sp_number, '''', '''''') + '''','null')
+ ', ''U'''
+ ', ''U'''
+ ', ' + coalesce(convert(varchar(20),@waste_code_uid),'null')
+ ', ' + coalesce('''' + replace(@DOT_waste_flag, '''', '''''') + '''','null')
+ ', ' + coalesce('''' + replace(@DOT_shipping_desc_additional, '''', '''''') + '''','null')
+ ', ''F'''
+ ', ' + coalesce(convert(varchar(20),@process_code_uid),'null')
+ ', ' + coalesce(convert(varchar(20),@created_from_template_profile_id),'null')
+ ', ''F'')'

select @sql_sequence_id = max(sequence_id) + 1
from TripSyncuploadSQL
where trip_sync_upload_id = @trip_sync_upload_id

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for Profile'
	goto ON_ERROR
end

set @sql ='insert ProfileTracking ('
+ 'profile_id'
+ ', tracking_id'
+ ', profile_curr_status_code'
+ ', tracking_status'
+ ', time_in'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', manual_bypass_tracking_flag'
+ ', rowguid)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', 1'
+ ', ''N'''
+ ', ''NEW'''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''F'''
+ ', newid())'

set @sql_sequence_id = @sql_sequence_id + 1

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for ProfileTracking'
	goto ON_ERROR
end


set @sql = 'insert ProfileLab ('
+ 'profile_id'
+ ', type'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', consistency'
+ ', odor'
+ ', CCVOC'
+ ', DDVOC'
+ ', free_liquid'
+ ', sulfide_gr100'
+ ', cyanide_spot'
+ ', water_react'
+ ', react_NaOH'
+ ', react_HCL'
+ ', react_CKD'
+ ', react_Bleach'
+ ', reacts_box'
+ ', radiation'
+ ', PCB'
+ ', phasing'
+ ', neshap_exempt'
+ ', avg_h20_gr_10'
+ ', state_waste_code_flag'
+ ', cyanide_plating'
+ ', meets_alt_soil_treatment_stds'
+ ', more_than_50_pct_debris'
+ ', underlying_haz_constituents'
+ ', michigan_non_haz'
+ ', used_oil'
+ ', pcb_article_decontaminated'
+ ', pcb_manufacturer'
+ ', pcb_non_lqd_contaminated_media'
+ ', pcb_source_concentration_gr_50'
+ ', processed_into_non_liquid'
+ ', subject_to_mact_neshap'
+ ', handling_issue'
+ ', ccvocgr500'
+ ', ddvohapgr500'
+ ', benzene_neshap'
+ ', benzene_onsite_mgmt'
+ ', tab_gr_10'
+ ', contains_benzene_flag)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', ''L'''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce('''' + replace(@consistency, '''', '''''') + '''','null')
+ ',''U'',0,0,''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'''
+ ',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'''
+ ',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'')'

set @sql_sequence_id = @sql_sequence_id + 1

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for ProfileLab(L)'
	goto ON_ERROR
end

set @sql = 'insert ProfileLab ('
+ 'profile_id'
+ ', type'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified'
+ ', consistency'
+ ', odor'
+ ', CCVOC'
+ ', DDVOC'
+ ', free_liquid'
+ ', sulfide_gr100'
+ ', cyanide_spot'
+ ', water_react'
+ ', react_NaOH'
+ ', react_HCL'
+ ', react_CKD'
+ ', react_Bleach'
+ ', reacts_box'
+ ', radiation'
+ ', PCB'
+ ', phasing'
+ ', neshap_exempt'
+ ', avg_h20_gr_10'
+ ', state_waste_code_flag'
+ ', cyanide_plating'
+ ', meets_alt_soil_treatment_stds'
+ ', more_than_50_pct_debris'
+ ', underlying_haz_constituents'
+ ', michigan_non_haz'
+ ', used_oil'
+ ', pcb_article_decontaminated'
+ ', pcb_manufacturer'
+ ', pcb_non_lqd_contaminated_media'
+ ', pcb_source_concentration_gr_50'
+ ', processed_into_non_liquid'
+ ', subject_to_mact_neshap'
+ ', handling_issue'
+ ', ccvocgr500'
+ ', ddvohapgr500'
+ ', benzene_neshap'
+ ', benzene_onsite_mgmt'
+ ', tab_gr_10'
+ ', contains_benzene_flag)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', ''A'''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ' + coalesce('''' + replace(@consistency, '''', '''''') + '''','null')
+ ',''U'',0,0,''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'''
+ ',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'''
+ ',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'',''U'')'

set @sql_sequence_id = @sql_sequence_id + 1

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for ProfileLab(A)'
	goto ON_ERROR
end

set @sql = 'insert ProfileQuoteHeader ('
+ 'quote_id'
+ ', profile_id'
+ ', quote_revision'
+ ', curr_status_code'
+ ', customer_id'
+ ', quote_type'
+ ', start_date'
+ ', generator_id'
+ ', print_confirm_flag'
+ ', print_gen_flag'
+ ', fax_flag'
+ ', modified_by'
+ ', date_modified'
+ ', rowguid)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', ' + coalesce(convert(varchar(20),@profile_id),'null')
+ ', ''0'''
+ ', ''A'''
+ ', ' + coalesce(convert(varchar(20),@customer_id),'null')
+ ', ''D'''
+ ', getdate()'
+ ', ' + coalesce(convert(varchar(20),@generator_id),'null')
+ ', ''F'''
+ ', ''F'''
+ ', ''F'''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', newid())'

set @sql_sequence_id = @sql_sequence_id + 1

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for ProfileQuoteHeader'
	goto ON_ERROR
end


set @sql = 'insert ProfileQuoteApproval ('
+ 'quote_id'
+ ', profile_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', status'
+ ', primary_facility_flag'
+ ', approval_code'
+ ', confirm_author'
+ ', confirm_update_by'
+ ', confirm_update_date'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', ' + convert(varchar(20),@profile_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ''A'''
+ ', ''T'''
+ ', ' + '''' + replace(@approval_code, '''', '''''') + ''''
+ ', ''Created from LPx Template'''
+ ', ''LPx'''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate())'

set @sql_sequence_id = @sql_sequence_id + 1

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for ProfileQuoteApproval'
	goto ON_ERROR
end


set @sql = 'insert ProfileQuoteDetail ('
+ 'quote_id'
+ ', profile_id'
+ ', company_id'
+ ', profit_ctr_id'
+ ', status'
+ ', sequence_id'
+ ', record_type'
+ ', bill_unit_code'
+ ', bulk_flag'
+ ', added_by'
+ ', date_added'
+ ', modified_by'
+ ', date_modified)'
+ ' values (' + convert(varchar(20),@profile_id)
+ ', ' + convert(varchar(20),@profile_id)
+ ', ' + convert(varchar(20),@company_id)
+ ', ' + convert(varchar(20),@profit_ctr_id)
+ ', ''A'''
+ ', 1'
+ ', ''D'''
+ ', ' + coalesce('''' + replace(@bill_unit_code, '''', '''''') + '''','null')
+ ', ''F'''
+ ', ''' + @user + ''''
+ ', getdate()'
+ ', ''' + @user + ''''
+ ', getdate())'

set @sql_sequence_id = @sql_sequence_id + 1

insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

select @err = @@error
if @err <> 0
begin
	select @msg = '   DB Error ' + convert(varchar(10),@err) +
			' when inserting TripSyncUploadSQL record for ProfileQuoteDetail'
	goto ON_ERROR
end


--for profiles created from templates, pull more data from the template definition
if coalesce(@created_from_template_profile_id,0) > 0
begin
	set @sql = 'update Profile
	set waste_code=t.waste_code,
	bill_unit_code=t.bill_unit_code,
	contact_id=t.contact_id,
	broker_flag=t.broker_flag,
	bulk_flag=t.bulk_flag,
	manifest_wt_vol_unit=t.manifest_wt_vol_unit,
	waste_managed_id=t.waste_managed_id,
	manifest_container_code=t.manifest_container_code,
	SPOC_flag=t.SPOC_flag,
	EQ_contact=t.EQ_contact,
	manifest_waste_desc=t.manifest_waste_desc,
	wastetype_id=t.wastetype_id,
	RCRA_haz_flag=t.RCRA_haz_flag,
	EPA_form_code=t.EPA_form_code,
	EPA_source_code=t.EPA_source_code,
	RQ_threshold=t.RQ_threshold,
	shipping_frequency=t.shipping_frequency,
	gen_process=t.gen_process,
	rcra_listed=t.rcra_listed,
	rcra_characteristic=t.rcra_characteristic,
	pending_profile_available_web=t.pending_profile_available_web,
	pending_profile_available_date=t.pending_profile_available_date,
	waste_code_uid=t.waste_code_uid,
	rcra_exempt_flag=t.rcra_exempt_flag,
	DEA_flag=t.DEA_flag,
	received_date=t.received_date,
	reapproval_batch_bypass=t.reapproval_batch_bypass,
	pharmaceutical_flag=t.pharmaceutical_flag,
	DOT_shipping_desc_additional=t.DOT_shipping_desc_additional,
	DOT_inhalation_haz_flag=t.DOT_inhalation_haz_flag,
	container_type_drums=t.container_type_drums,
	container_type_labpack=''T'',
	texas_waste_material_type=t.texas_waste_material_type,
	texas_state_waste_code=t.texas_state_waste_code,
	PA_residual_waste_flag=t.PA_residual_waste_flag,
	hazardous_secondary_material=t.hazardous_secondary_material,
	hazardous_secondary_material_cert=t.hazardous_secondary_material_cert,
	waste_treated_after_generation=t.waste_treated_after_generation,
	origin_refinery=t.origin_refinery,
	specific_technology_requested=t.specific_technology_requested,
	thermal_process_flag=t.thermal_process_flag,
	DOT_sp_permit_flag=''F'',
	RCRA_waste_code_flag=t.RCRA_waste_code_flag,
	process_code_uid=t.process_code_uid
	from Profile
	join Profile t
		on t.profile_id=' + convert(varchar(20),@created_from_template_profile_id) +
	' where Profile.profile_id=' + convert(varchar(20),@profile_id)

	set @sql = @sql + ' update ProfileQuoteApproval
	set treatment_id=t.treatment_id,
	disposal_service_id=t.disposal_service_id,
	sr_type_code=t.sr_type_code,
	insurance_exempt=t.insurance_exempt,
	ensr_exempt=t.ensr_exempt,
	LDR_req_flag=t.LDR_req_flag,
	location_type=t.location_type,
	location_control=t.location_control,
	fingerprint_type=t.fingerprint_type,
	treatment_process_id=t.treatment_process_id,
	consolidate_containers_flag=t.consolidate_containers_flag,
	bulk_load_sampling_frequency_required_flag=t.bulk_load_sampling_frequency_required_flag,
	loads_until_sample_required=t.loads_until_sample_required,
	state_reviewed_flag = coalesce((select state_profile_review_required_flag from ProfitCenter where company_id=' + convert(varchar(20),@company_id) + ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id) + '),''F''),
	date_state_reviewed = case when (select state_profile_review_required_flag from ProfitCenter where company_id=' + convert(varchar(20),@company_id) + ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id) + ') = ''T'' then convert(date,getdate()) else null end
	from ProfileQuoteApproval
	join ProfileQuoteApproval t
		on t.profile_id=' + convert(varchar(20),@created_from_template_profile_id) +
		' and t.company_id=' + convert(varchar(20),@company_id) +
		' and t.profit_ctr_id=' + convert(varchar(20),@profit_ctr_id) +
	' where ProfileQuoteApproval.profile_id=' + convert(varchar(20),@profile_id) +
	' and ProfileQuoteApproval.company_id=' + convert(varchar(20),@company_id) +
	' and ProfileQuoteApproval.profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)

	set @sql = @sql + ' update ProfileQuoteHeader
	set sr_type_code=t.sr_type_code,
	direct_flag=t.direct_flag,
	job_type=t.job_type,
	waste_code=t.waste_code
	from ProfileQuoteHeader
	join ProfileQuoteHeader t
		on t.profile_id=' + convert(varchar(20),@created_from_template_profile_id) +
	' where ProfileQuoteHeader.profile_id=' + convert(varchar(20),@profile_id)

	set @sql = @sql + ' insert ProfileComposition select ' +
	convert(varchar(20),@profile_id) + ',' +
	'comp_description,comp_from_pct,comp_to_pct,' +
	'''LP'', getdate(), ''LP'', getdate(),' +
	'unit,sequence_id,comp_typical_pct' +
	' from ProfileComposition' +
	' where profile_id=' + convert(varchar(20),@created_from_template_profile_id)

	set @sql = @sql + ' insert ProfileContainerSize (' +
	'profile_id,bill_unit_code,is_bill_unit_table_lookup,added_by,date_added,modified_by,date_modified,quantity) ' +
	'select ' + convert(varchar(20),@profile_id) + ',' +
	'bill_unit_code,is_bill_unit_table_lookup,' +
	'''LP'', getdate(), ''LP'', getdate(),quantity' +
	' from ProfileContainerSize' +
	' where profile_id=' + convert(varchar(20),@created_from_template_profile_id)

	set @sql_sequence_id = @sql_sequence_id + 1

	insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
	values (@trip_sync_upload_id, @sql_sequence_id, @sql, 5, 'F', @user, getdate(), @user, getdate())

	select @err = @@error
	if @err <> 0
	begin
		select @msg = '   DB Error ' + convert(varchar(10),@err) +
				' when updating Profile from template'
		goto ON_ERROR
	end

	set @sql = 'update ProfileLab
	set color=t.color,
	consistency=t.consistency,
	odor=t.odor,
	odor_desc=t.odor_desc,
	CCVOC=t.CCVOC,
	DDVOC=t.DDVOC,
	free_liquid=t.free_liquid,
	density=t.density,
	specific_gravity=t.specific_gravity,
	ignitability=t.ignitability,
	pH_from=t.pH_from,
	pH_to=t.pH_to,
	sulfide_gr100=t.sulfide_gr100,
	sulfide_desc=t.sulfide_desc,
	cyanide_spot=t.cyanide_spot,
	cyanide_desc=t.cyanide_desc,
	water_react=t.water_react,
	water_react_desc=t.water_react_desc,
	react_NaOH=t.react_NaOH,
	NaOH_desc=t.NaOH_desc,
	react_HCL=t.react_HCL,
	HCL_desc=t.HCL_desc,
	react_CKD=t.react_CKD,
	react_CKD_desc=t.react_CKD_desc,
	react_Bleach=t.react_Bleach,
	react_Bleach_desc=t.react_Bleach_desc,
	reacts_box=t.reacts_box,
	radiation=t.radiation,
	PCB=t.PCB,
	BTU_per_lb=t.BTU_per_lb,
	pct_moisture=t.pct_moisture,
	pct_chlorides=t.pct_chlorides,
	pct_halogens=t.pct_halogens,
	pct_solids=t.pct_solids,
	phasing=t.phasing,
	ratio=t.ratio,
	TCE=t.TCE,
	MC=t.MC,
	ppm_halogens=t.ppm_halogens,
	ppm_cod_bod=t.ppm_cod_bod,
	ppm_fog=t.ppm_fog,
	FSCAN=t.FSCAN,
	pct_BSW_oil=t.pct_BSW_oil,
	pct_BSW_water=t.pct_BSW_water,
	pct_BSW_solid=t.pct_BSW_solid,
	pct_BSW_other=t.pct_BSW_other,
	neshap_sic=t.neshap_sic,
	neshap_exempt=t.neshap_exempt,
	benzene=t.benzene,
	benzene_waste_type=t.benzene_waste_type,
	avg_h20_gr_10=t.avg_h20_gr_10,
	solvent_factor=t.solvent_factor,
	microREM=t.microREM,
	geiger_counter=t.geiger_counter,
	normality=t.normality,
	odor_other_desc=t.odor_other_desc,
	waste_contains_spec_hand_none=t.waste_contains_spec_hand_none,
	oily_residue=t.oily_residue,
	metal_fines=t.metal_fines,
	biodegradable_sorbents=t.biodegradable_sorbents,
	dioxins=t.dioxins,
	furans=t.furans,
	biohazard=t.biohazard,
	shock_sensitive_waste=t.shock_sensitive_waste,
	air_reactive=t.air_reactive,
	radioactive_waste=t.radioactive_waste,
	explosives=t.explosives,
	pyrophoric_waste=t.pyrophoric_waste,
	isocyanates=t.isocyanates,
	asbestos_friable=t.asbestos_friable,
	asbestos_non_friable=t.asbestos_non_friable,
	react_cyanide=t.react_cyanide,
	react_sulfide=t.react_sulfide,
	temp_ctrl_org_peroxide=t.temp_ctrl_org_peroxide,
	NORM=t.NORM,
	TENORM=t.TENORM,
	water_reactive=t.water_reactive,
	aluminum=t.aluminum,
	ph_lte_2=t.ph_lte_2,
	ph_gt_2_lt_5=t.ph_gt_2_lt_5,
	ph_gte_5_lte_10=t.ph_gte_5_lte_10,
	ph_gt_10_lt_12_5=t.ph_gt_10_lt_12_5,
	ph_gte_12_5=t.ph_gte_12_5,
	pH_NA=t.pH_NA,
	ignitability_lt_90=t.ignitability_lt_90,
	ignitability_90_139=t.ignitability_90_139,
	ignitability_140_199=t.ignitability_140_199,
	ignitability_gte_200=t.ignitability_gte_200,
	ignitability_NA=t.ignitability_NA,
	state_waste_code_flag=t.state_waste_code_flag,
	cyanide_plating=t.cyanide_plating,
	meets_alt_soil_treatment_stds=t.meets_alt_soil_treatment_stds,
	more_than_50_pct_debris=t.more_than_50_pct_debris,
	debris_dimension_weight=t.debris_dimension_weight,
	underlying_haz_constituents=t.underlying_haz_constituents,
	michigan_non_haz=t.michigan_non_haz,
	universal_recyclable_commodity=t.universal_recyclable_commodity,
	used_oil=t.used_oil,
	halogen_source=t.halogen_source,
	halogen_source_desc=t.halogen_source_desc,
	halogen_source_other=t.halogen_source_other,
	wwa_halogen_gt_1000=t.wwa_halogen_gt_1000,
	pcb_concentration_none=t.pcb_concentration_none,
	pcb_concentration_0_49=t.pcb_concentration_0_49,
	pcb_concentration_50_499=t.pcb_concentration_50_499,
	pcb_concentration_500=t.pcb_concentration_500,
	pcb_article_decontaminated=t.pcb_article_decontaminated,
	pcb_manufacturer=t.pcb_manufacturer,
	pcb_non_lqd_contaminated_media=t.pcb_non_lqd_contaminated_media,
	pcb_source_concentration_gr_50=t.pcb_source_concentration_gr_50,
	processd_into_nonlqd_prior_pcb=t.processd_into_nonlqd_prior_pcb,
	processed_into_non_liquid=t.processed_into_non_liquid,
	benzene_onsite_mgmt_desc=t.benzene_onsite_mgmt_desc,
	subject_to_mact_neshap=t.subject_to_mact_neshap,
	neshap_chem_1=t.neshap_chem_1,
	neshap_chem_2=t.neshap_chem_2,
	neshap_standards_part=t.neshap_standards_part,
	neshap_subpart=t.neshap_subpart,
	handling_issue=t.handling_issue,
	handling_issue_desc=t.handling_issue_desc,
	info_basis_knowledge=t.info_basis_knowledge,
	info_basis_analysis=t.info_basis_analysis,
	info_basis_msds=t.info_basis_msds,
	ccvocgr500=t.ccvocgr500,
	ddvohapgr500=t.ddvohapgr500,
	benzene_neshap=t.benzene_neshap,
	benzene_onsite_mgmt=t.benzene_onsite_mgmt,
	tab_gr_10=t.tab_gr_10,
	benzene_unit=t.benzene_unit,
	contains_benzene_flag=t.contains_benzene_flag,
	tab=t.tab,
	oxidizer_spot=t.oxidizer_spot,
	odor_strength=t.odor_strength,
	odor_type_ammonia=t.odor_type_ammonia,
	odor_type_amines=t.odor_type_amines,
	odor_type_mercaptans=t.odor_type_mercaptans,
	odor_type_sulfur=t.odor_type_sulfur,
	odor_type_organic_acid=t.odor_type_organic_acid,
	odor_type_other=t.odor_type_other,
	liquid_phase=t.liquid_phase,
	paint_filter_solid_flag=t.paint_filter_solid_flag,
	incidental_liquid_flag=t.incidental_liquid_flag,
	ignitability_compare_symbol=t.ignitability_compare_symbol,
	ignitability_compare_temperature=t.ignitability_compare_temperature,
	ignitability_does_not_flash=t.ignitability_does_not_flash,
	ignitability_flammable_solid=t.ignitability_flammable_solid,
	BTU_lt_gt_5000=t.BTU_lt_gt_5000,
	react_sulfide_ppm=t.react_sulfide_ppm,
	react_cyanide_ppm=t.react_cyanide_ppm,
	reactive_other_description=t.reactive_other_description,
	reactive_other=t.reactive_other
	from ProfileLab
	join ProfileLab t
		on t.profile_id=' + convert(varchar(20),@created_from_template_profile_id) +
		' and t.type=''L''
	where ProfileLab.profile_id=' + convert(varchar(20),@profile_id) +
	' and ProfileLab.type=''L'''

	set @sql_sequence_id = @sql_sequence_id + 1

	insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
	values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

	select @err = @@error
	if @err <> 0
	begin
		select @msg = '   DB Error ' + convert(varchar(10),@err) +
				' when updating ProfileLab from template'
		goto ON_ERROR
	end

	set @sql = 'update ProfileLab
	set color=t.color,
	consistency=t.consistency,
	odor=t.odor,
	odor_desc=t.odor_desc,
	CCVOC=t.CCVOC,
	DDVOC=t.DDVOC,
	free_liquid=t.free_liquid,
	density=t.density,
	specific_gravity=t.specific_gravity,
	ignitability=t.ignitability,
	pH_from=t.pH_from,
	pH_to=t.pH_to,
	sulfide_gr100=t.sulfide_gr100,
	sulfide_desc=t.sulfide_desc,
	cyanide_spot=t.cyanide_spot,
	cyanide_desc=t.cyanide_desc,
	water_react=t.water_react,
	water_react_desc=t.water_react_desc,
	react_NaOH=t.react_NaOH,
	NaOH_desc=t.NaOH_desc,
	react_HCL=t.react_HCL,
	HCL_desc=t.HCL_desc,
	react_CKD=t.react_CKD,
	react_CKD_desc=t.react_CKD_desc,
	react_Bleach=t.react_Bleach,
	react_Bleach_desc=t.react_Bleach_desc,
	reacts_box=t.reacts_box,
	radiation=t.radiation,
	PCB=t.PCB,
	BTU_per_lb=t.BTU_per_lb,
	pct_moisture=t.pct_moisture,
	pct_chlorides=t.pct_chlorides,
	pct_halogens=t.pct_halogens,
	pct_solids=t.pct_solids,
	phasing=t.phasing,
	ratio=t.ratio,
	TCE=t.TCE,
	MC=t.MC,
	ppm_halogens=t.ppm_halogens,
	ppm_cod_bod=t.ppm_cod_bod,
	ppm_fog=t.ppm_fog,
	FSCAN=t.FSCAN,
	pct_BSW_oil=t.pct_BSW_oil,
	pct_BSW_water=t.pct_BSW_water,
	pct_BSW_solid=t.pct_BSW_solid,
	pct_BSW_other=t.pct_BSW_other,
	neshap_sic=t.neshap_sic,
	neshap_exempt=t.neshap_exempt,
	benzene=t.benzene,
	benzene_waste_type=t.benzene_waste_type,
	avg_h20_gr_10=t.avg_h20_gr_10,
	solvent_factor=t.solvent_factor,
	microREM=t.microREM,
	geiger_counter=t.geiger_counter,
	normality=t.normality,
	odor_other_desc=t.odor_other_desc,
	waste_contains_spec_hand_none=t.waste_contains_spec_hand_none,
	oily_residue=t.oily_residue,
	metal_fines=t.metal_fines,
	biodegradable_sorbents=t.biodegradable_sorbents,
	dioxins=t.dioxins,
	furans=t.furans,
	biohazard=t.biohazard,
	shock_sensitive_waste=t.shock_sensitive_waste,
	air_reactive=t.air_reactive,
	radioactive_waste=t.radioactive_waste,
	explosives=t.explosives,
	pyrophoric_waste=t.pyrophoric_waste,
	isocyanates=t.isocyanates,
	asbestos_friable=t.asbestos_friable,
	asbestos_non_friable=t.asbestos_non_friable,
	react_cyanide=t.react_cyanide,
	react_sulfide=t.react_sulfide,
	temp_ctrl_org_peroxide=t.temp_ctrl_org_peroxide,
	NORM=t.NORM,
	TENORM=t.TENORM,
	water_reactive=t.water_reactive,
	aluminum=t.aluminum,
	ph_lte_2=t.ph_lte_2,
	ph_gt_2_lt_5=t.ph_gt_2_lt_5,
	ph_gte_5_lte_10=t.ph_gte_5_lte_10,
	ph_gt_10_lt_12_5=t.ph_gt_10_lt_12_5,
	ph_gte_12_5=t.ph_gte_12_5,
	pH_NA=t.pH_NA,
	ignitability_lt_90=t.ignitability_lt_90,
	ignitability_90_139=t.ignitability_90_139,
	ignitability_140_199=t.ignitability_140_199,
	ignitability_gte_200=t.ignitability_gte_200,
	ignitability_NA=t.ignitability_NA,
	state_waste_code_flag=t.state_waste_code_flag,
	cyanide_plating=t.cyanide_plating,
	meets_alt_soil_treatment_stds=t.meets_alt_soil_treatment_stds,
	more_than_50_pct_debris=t.more_than_50_pct_debris,
	debris_dimension_weight=t.debris_dimension_weight,
	underlying_haz_constituents=t.underlying_haz_constituents,
	michigan_non_haz=t.michigan_non_haz,
	universal_recyclable_commodity=t.universal_recyclable_commodity,
	used_oil=t.used_oil,
	halogen_source=t.halogen_source,
	halogen_source_desc=t.halogen_source_desc,
	halogen_source_other=t.halogen_source_other,
	wwa_halogen_gt_1000=t.wwa_halogen_gt_1000,
	pcb_concentration_none=t.pcb_concentration_none,
	pcb_concentration_0_49=t.pcb_concentration_0_49,
	pcb_concentration_50_499=t.pcb_concentration_50_499,
	pcb_concentration_500=t.pcb_concentration_500,
	pcb_article_decontaminated=t.pcb_article_decontaminated,
	pcb_manufacturer=t.pcb_manufacturer,
	pcb_non_lqd_contaminated_media=t.pcb_non_lqd_contaminated_media,
	pcb_source_concentration_gr_50=t.pcb_source_concentration_gr_50,
	processd_into_nonlqd_prior_pcb=t.processd_into_nonlqd_prior_pcb,
	processed_into_non_liquid=t.processed_into_non_liquid,
	benzene_onsite_mgmt_desc=t.benzene_onsite_mgmt_desc,
	subject_to_mact_neshap=t.subject_to_mact_neshap,
	neshap_chem_1=t.neshap_chem_1,
	neshap_chem_2=t.neshap_chem_2,
	neshap_standards_part=t.neshap_standards_part,
	neshap_subpart=t.neshap_subpart,
	handling_issue=t.handling_issue,
	handling_issue_desc=t.handling_issue_desc,
	info_basis_knowledge=t.info_basis_knowledge,
	info_basis_analysis=t.info_basis_analysis,
	info_basis_msds=t.info_basis_msds,
	ccvocgr500=t.ccvocgr500,
	ddvohapgr500=t.ddvohapgr500,
	benzene_neshap=t.benzene_neshap,
	benzene_onsite_mgmt=t.benzene_onsite_mgmt,
	tab_gr_10=t.tab_gr_10,
	benzene_unit=t.benzene_unit,
	contains_benzene_flag=t.contains_benzene_flag,
	tab=t.tab,
	oxidizer_spot=t.oxidizer_spot,
	odor_strength=t.odor_strength,
	odor_type_ammonia=t.odor_type_ammonia,
	odor_type_amines=t.odor_type_amines,
	odor_type_mercaptans=t.odor_type_mercaptans,
	odor_type_sulfur=t.odor_type_sulfur,
	odor_type_organic_acid=t.odor_type_organic_acid,
	odor_type_other=t.odor_type_other,
	liquid_phase=t.liquid_phase,
	paint_filter_solid_flag=t.paint_filter_solid_flag,
	incidental_liquid_flag=t.incidental_liquid_flag,
	ignitability_compare_symbol=t.ignitability_compare_symbol,
	ignitability_compare_temperature=t.ignitability_compare_temperature,
	ignitability_does_not_flash=t.ignitability_does_not_flash,
	ignitability_flammable_solid=t.ignitability_flammable_solid,
	BTU_lt_gt_5000=t.BTU_lt_gt_5000,
	react_sulfide_ppm=t.react_sulfide_ppm,
	react_cyanide_ppm=t.react_cyanide_ppm,
	reactive_other_description=t.reactive_other_description,
	reactive_other=t.reactive_other
	from ProfileLab
	join ProfileLab t
		on t.profile_id=' + convert(varchar(20),@created_from_template_profile_id) +
		' and t.type=''A''
	where ProfileLab.profile_id=' + convert(varchar(20),@profile_id) +
	' and ProfileLab.type=''A'''

	set @sql_sequence_id = @sql_sequence_id + 1

	insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
	values (@trip_sync_upload_id, @sql_sequence_id, @sql, 1, 'F', @user, getdate(), @user, getdate())

	select @err = @@error
	if @err <> 0
	begin
		select @msg = '   DB Error ' + convert(varchar(10),@err) +
				' when updating ProfileLab from template'
		goto ON_ERROR
	end

	set @sql = 'update ProfileLab
	set oxidizer=t.oxidizer,
	organic_peroxide=t.organic_peroxide,
	beryllium_present=t.beryllium_present,
	ammonia_flag=t.ammonia_flag,
	asbestos_flag=t.asbestos_flag,
	asbestos_friable_flag=t.asbestos_friable_flag,
	contains_pcb=t.contains_pcb,
	dioxins_or_furans=t.dioxins_or_furans,
	thermally_unstable=t.thermally_unstable,
	compressed_gas=t.compressed_gas,
	tires=t.tires,
	pcb_concentration_0_9=t.pcb_concentration_0_9,
	pcb_concentration_10_49=t.pcb_concentration_10_49,
	pcb_regulated_for_disposal_under_TSCA=t.pcb_regulated_for_disposal_under_TSCA,
	pcb_article_for_TSCA_landfill=t.pcb_article_for_TSCA_landfill,
	section_F_none_apply_flag=t.section_F_none_apply_flag,
	ldr_notification_frequency=t.ldr_notification_frequency,
	PFAS_Flag=t.PFAS_Flag
	from ProfileLab
	join ProfileLab t
		on t.profile_id=' + convert(varchar(20),@created_from_template_profile_id) +
		' and t.type=''L''
	where ProfileLab.profile_id=' + convert(varchar(20),@profile_id) +
	' and ProfileLab.type=''L'''

	set @sql = @sql + ' update ProfileLab
	set oxidizer=t.oxidizer,
	organic_peroxide=t.organic_peroxide,
	beryllium_present=t.beryllium_present,
	ammonia_flag=t.ammonia_flag,
	asbestos_flag=t.asbestos_flag,
	asbestos_friable_flag=t.asbestos_friable_flag,
	contains_pcb=t.contains_pcb,
	dioxins_or_furans=t.dioxins_or_furans,
	thermally_unstable=t.thermally_unstable,
	compressed_gas=t.compressed_gas,
	tires=t.tires,
	pcb_concentration_0_9=t.pcb_concentration_0_9,
	pcb_concentration_10_49=t.pcb_concentration_10_49,
	pcb_regulated_for_disposal_under_TSCA=t.pcb_regulated_for_disposal_under_TSCA,
	pcb_article_for_TSCA_landfill=t.pcb_article_for_TSCA_landfill,
	section_F_none_apply_flag=t.section_F_none_apply_flag,
	ldr_notification_frequency=t.ldr_notification_frequency,
	PFAS_Flag=t.PFAS_Flag
	from ProfileLab
	join ProfileLab t
		on t.profile_id=' + convert(varchar(20),@created_from_template_profile_id) +
		' and t.type=''A''
	where ProfileLab.profile_id=' + convert(varchar(20),@profile_id) +
	' and ProfileLab.type=''A'''

	set @sql_sequence_id = @sql_sequence_id + 1

	insert TripSyncUploadSQL (trip_sync_upload_id, sequence_id, sql, sql_statement_count, check_rowcount_flag, added_by, date_added, modified_by, date_modified)
	values (@trip_sync_upload_id, @sql_sequence_id, @sql, 2, 'F', @user, getdate(), @user, getdate())

	select @err = @@error
	if @err <> 0
	begin
		select @msg = '   DB Error ' + convert(varchar(10),@err) +
				' when updating ProfileLab from template'
		goto ON_ERROR
	end
end

-- SUCCESS return the ID
return 0

-- FAILURE
ON_ERROR:
raiserror(@msg,18,-1) with seterror
return -1
GO

GRANT EXECUTE ON sp_labpack_sync_upload_profile TO EQAI