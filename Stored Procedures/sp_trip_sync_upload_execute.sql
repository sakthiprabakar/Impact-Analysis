create or alter [dbo].[sp_trip_sync_upload_execute]  
 @trip_connect_log_id int,  
 @trip_sync_upload_id int  
as  
/***************************************************************************************  
 this procedure executes an upload of sql batches from the client  
  
 loads to Plt_ai  
   
 03/05/2010 - rb created  
 03/19/2010 - rb return sql to field device that updates negative workorderdetail.sequence_IDs  
 05/04/2010 - rb extra check to see if a stop has already been uploaded and processed  
 01/12/2012 - rb For GL Standardization / Profit Center renumbering, don't allow  
              uploads from versions earlier than 2.28  
 08/13/2012 - rb Lab Pack - support adding new Profiles/TSDFApprovals, WasteCodes and Consts.  
 04/26/2013 - rb Waste code conversion, added waste_code_uid, need to upgrade to 3.06  
 09/19/2013 - rb Cannot upload if earlier than version 3.08 (Waste Code Phase II)  
 01/30/2014 - rb Default new column ProfileQuoteDetail.show_cust_flag to 'T'  
 10/23/2017 - mm Added ActionRegister table.  
 01/23/2020 - rb Now that this is called by Smarter Sorting, removed old check against MIM version  
 06/11/2020 - rb Now that this is called by Lab Pack, added updates for LDR Subcategory negative IDs  
 01/12/2021 - rb For Lab Pack, LPx now uploads Notes, added updates for Note negative IDs  
 02/12/2024 - rb For Lab Pack profiles created from templates, update ProfileComposition and ProfileContainerSize  
 03/11/2024 - rb (12/04/2023 in TEST) For Lab Pack, need to update negative sequence_ids in the LabPackLabel table
 08/26/2024 Dipankar 94525 Added logic to create Profile Fee Detail and related Audit records
  
****************************************************************************************/  
begin
	declare  @update_user varchar(10),  
			 @update_dt datetime,  
			 @sequence_id int,  
			 @sql_statement_count int,  
			 @sql varchar(6000),  
			 @total_statements int,  
			 @count int,  
			 @err int,  
			 @msg varchar(255),  
			 @sql_update_neg_ids varchar(4096),  
			 @sql_return varchar(4096),  
			 @workorder_id int,  
			 @company_id int,  
			 @profit_ctr_id int,  
			 @wod_sequence_id int,  
			 @wod_max_seq int,  
			 @trip_id int,  
			 @trip_sequence_id int,  
			 @s_version varchar(10),  
			 @dot int,  
			 @version numeric(6,2),  
			-- labpack  
			 @tsdf_code varchar(15),  
			 @eq_flag char(1),  
			 @app_id int,  
			 @new_app_id int,  
			 @quote_id int,  
			 @new_quote_id int,
			 @exemption_reason_uid int,
			 @exemption_reason varchar(50),
			 @apply_flag char(1),
			 @exemption_approved_by	varchar(10),
			 @exemption_approved_by_name varchar(40),
			 @audit_reference varchar(30)
  
	set nocount on  
  
	create table #sql (sql varchar(4096) not null)  
  
	/***  
	-- rb 01/12/2012 For company / profit center renumbering, uploading SQL is not allowed  
	select @s_version = tcca.client_app_version  
	from TripConnectLog tcl, TripConnectClientApp tcca  
	where tcl.trip_connect_log_id = @trip_connect_log_id  
	and tcl.trip_client_app_id = tcca.trip_client_app_id  
  
	select @dot = CHARINDEX('.',@s_version)  
	if @dot < 1  
		select @version = CONVERT(int,@s_version)  
	else  
		select @version = convert(numeric(6,2),SUBSTRING(@s_version,1,@dot-1)) +  
			(CONVERT(numeric(6,2),SUBSTRING(@s_version,@dot+1,datalength(@s_version))) / 100)  
  
	if @version < 3.08  
	begin  
		insert #sql  
		select 'ERROR: In order to upload your data, you must be running Version 3.08 of the MIM software'  
		+ ' or higher (you currently have version ' + convert(varchar(10),@version) + '). Please'  
		+ ' shut down and reboot the MIM to get the latest version.'  
		goto RETURN_RESULTS  
	end  
	***/  
  
	-- don't process more than once  
	if exists (select 1 from TripSyncUpload  
		where trip_sync_upload_id = @trip_sync_upload_id  
		and isnull(processed_flag,'F') = 'T')  
	begin  
		insert #sql  
		select 'ERROR: sp_trip_sync_upload_execute - trip_sync_upload_id ' +  
		convert(varchar(20),@trip_sync_upload_id) + ' has already been processed.'  
		goto RETURN_RESULTS  
	end  
  
	-- rb 05/04/2010  
	-- see if the stop has been processed, and if so just pass back statement to update that is already was  
	select @trip_id = trip_id  
	from TripConnectLog  
	where trip_connect_log_id = @trip_connect_log_id  
  
	select @trip_sequence_id = trip_sequence_id  
	from TripSyncUpload  
	where trip_sync_upload_id = @trip_sync_upload_id  
  
	if exists (select 1 from TripConnectLog tcl, TripSyncUpload tsu  
		where tcl.trip_id = @trip_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and tsu.trip_sequence_id = @trip_sequence_id  
		and tsu.processed_flag = 'T')  
	begin  
		insert #sql  
		select 'update TripFieldUpload set uploaded_flag=''T'', last_upload_date=getdate() where trip_id=' +  
		convert(varchar(20),@trip_id) + ' and trip_sequence_id=' +  
		convert(varchar(20),@trip_sequence_id)  
		goto RETURN_RESULTS  
	end  
	-- rb 05/03/2010 end  
  
	-- default return sql as unsuccessful  
	select @sql_return = 'update TripFieldUpload set uploaded_flag=''F'' where trip_id=' +  
		convert(varchar(20),tcl.trip_id) + ' and trip_sequence_id=' +  
		convert(varchar(20),tsu.trip_sequence_id)  
	from TripSyncUpload tsu, TripConnectLog tcl  
	where tsu.trip_sync_upload_id = @trip_sync_upload_id  
	and tsu.trip_connect_log_id = tcl.trip_connect_log_id  
  
	-- don't process if Unloading or Complete  
	if exists (select 1 from TripHeader th, TripConnectLog tcl  
		where th.trip_status in ('C','U')  
		and th.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id)  
	begin  
		select @msg = '   Error: Updates can not be processed if the trip status is ''Unloading'' or ''Completed''.'  
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
		insert #sql  
		select ltrim(@msg)  
		goto RETURN_RESULTS  
	end  
  
	-- initialize updated_by variables  
	select @update_user = 'TCID' + convert(varchar(6),@trip_connect_log_id),  
		@update_dt = convert(datetime,convert(varchar(20),getdate(),120))  
  
	-- validate that the batch is complete  
	select @total_statements = sql_statement_count  
	from TripSyncUpload  
	where trip_sync_upload_id = @trip_sync_upload_id  
  
	select @count = sum(sql_statement_count)  
	from TripSyncUploadSQL  
	where trip_sync_upload_id = @trip_sync_upload_id  
  
	if @total_statements <> @count  
	begin  
		select @msg = '   Error: The number of SQL statements to process (' + convert(varchar(20),@total_statements)  
		+ ') does not equal the count specified from the device (' + convert(varchar(20),@count) + ')'  
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
		insert #sql  
		select ltrim(@msg)  
		goto RETURN_RESULTS  
	end  
  
	-- get the max sequence_id from WorkOrderDetail  
	-- 11/13/2012 check for null, Lab Packs trips could be sent out with no approvals  
	select @wod_max_seq = isnull(max(wod.sequence_id),0)  
	from WorkOrderDetail wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
	where wod.workorder_id = woh.workorder_id  
	and wod.company_id = woh.company_id  
	and wod.profit_ctr_id = woh.profit_ctr_id  
	and wod.resource_type = 'D'  
	and woh.trip_id = tcl.trip_id  
	and tcl.trip_connect_log_id = @trip_connect_log_id  
	and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
	and woh.trip_sequence_id = tsu.trip_sequence_id  
	and tsu.trip_sync_upload_id = @trip_sync_upload_id  
  
  
	-- BEGIN TRANSACTION  
	begin transaction  
  
	-- loop through sql batches  
	declare c_loop cursor for  
	select sequence_id, sql  
	from TripSyncUploadSQL  
	where trip_sync_upload_id = @trip_sync_upload_id  
	order by sequence_id  
	for read only  
  
	open c_loop  
	fetch c_loop into @sequence_id, @sql  
  
	while @@FETCH_STATUS = 0  
	begin  
  
		-- execute SQL batch, record error code and rows processed  
		execute (@sql)  
		select @err = @@ERROR  
  
		if @err <> 0  
		begin  
		rollback transaction  
		select @msg = '   Error #' + convert(varchar(20),@err) + ' in sp_trip_sync_upload_execute for SQL sequence_id ' + convert(varchar(20),@sequence_id)  
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
		insert #sql  
		select ltrim(@msg)  
		goto CLOSE_CURSOR  
		end  
  
		-- fetch next sql batch  
		fetch c_loop into @sequence_id, @sql  
	end  
  
	-- 08/13/2012 adjust negative Profile ids  
	if exists (select 1 from WorkOrderDetail wod, TSDF t, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.tsdf_code = t.tsdf_code  
		and isnull(t.eq_flag,'F') = 'T'  
		and wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and wod.resource_type = 'D'  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.profile_id < 0)  
	begin  
		-- generate SQL to update client IDs  
		declare c_loop_neg_profile_ids cursor for  
		select distinct wod.profile_id, wod.workorder_id, wod.company_id, wod.profit_ctr_id  
		from WorkOrderDetail wod, TSDF t, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.tsdf_code = t.tsdf_code  
		and isnull(t.eq_flag,'F') = 'T'  
		and wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and wod.resource_type = 'D'  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.profile_id < 0  
		for read only  
  
		open c_loop_neg_profile_ids  
		fetch c_loop_neg_profile_ids into @app_id, @workorder_id, @company_id, @profit_ctr_id  
  
		while @@FETCH_STATUS = 0  
		begin  
		-- rb can't call stored proc, silent flag is not implemented to bypass the select  
		--exec @new_app_id = sp_sequence_next 'Profile.profile_id', 0  
		select @new_app_id = next_value from Sequence where name = 'Profile.profile_id'  
		update plt_ai.dbo.sequence set next_value = next_value + 1 where name = 'Profile.profile_id'  
  
		if @new_app_id is null or @new_app_id < 1 or (@new_app_id + 1) <> (select next_value from plt_ai.dbo.sequence where name = 'Profile.profile_id')  
		begin  
		rollback transaction  
		close c_loop_neg_profile_ids  
		deallocate c_loop_neg_profile_ids  
		select @msg = '   Error in sp_trip_sync_upload_execute: allocating new Profile.profile_id failed'  
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
		insert #sql  
		select ltrim(@msg)  
		goto CLOSE_CURSOR  
		end  
  
		/* select @sql_update_neg_ids = isnull(@sql_update_neg_ids,'') + ' update profile'  
		+ ' set profile_id=' + convert(varchar(20),@new_app_id)  
		+ ' where profile_id=' + convert(varchar(20),@app_id)  
		+ ' update profilequoteapproval'  
		+ ' set profile_id=' + convert(varchar(20),@new_app_id)  
		+ ' where profile_id=' + convert(varchar(20),@app_id)  
		+ ' update profilequotedetail'  
		+ ' set profile_id=' + convert(varchar(20),@new_app_id)  
		+ ' where profile_id=' + convert(varchar(20),@app_id)  
		+ ' update profileconstituent'  
		+ ' set profile_id=' + convert(varchar(20),@new_app_id)  
		+ ' where profile_id=' + convert(varchar(20),@app_id)  
		+ ' update profilewastecode'  
		+ ' set profile_id=' + convert(varchar(20),@new_app_id)  
		+ ' where profile_id=' + convert(varchar(20),@app_id)  
		+ 'update workorderdetail'  
		+ ' set profile_id=' + convert(varchar(20),@new_app_id)  
		+ ' where workorder_id=' + convert(varchar(20),@workorder_id)  
		+ ' and company_id=' + convert(varchar(20),@company_id)  
		+ ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)  
		+ ' and resource_type = ''D'''  
		+ ' and profile_id = ' + convert(varchar(20),@app_id)  
	*/  
  
		-- update tables  
		update Profile  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
		rollback transaction  
		close c_loop_neg_profile_ids  
		deallocate c_loop_neg_profile_ids  
		select @msg = '   Error in sp_trip_sync_upload_execute: updating negative Profile.profile_id failed'  
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
		insert #sql select ltrim(@msg)  
		goto CLOSE_CURSOR  
		end  

		IF EXISTS (SELECT 1 FROM ProfileFeeDetail WHERE profile_id = @app_id)
		BEGIN
			UPDATE ProfileFeeDetail
			SET profile_id = @new_app_id
			WHERE profile_id = @app_id	
			
			IF @@ERROR <> 0  
			BEGIN  
				ROLLBACK TRANSACTION
				CLOSE c_loop_neg_profile_ids  
				DEALLOCATE c_loop_neg_profile_ids  
				SELECT @msg = '   Error in sp_trip_sync_upload_execute: updating ProfileFeeDetail.profile_id failed'  
				EXEC sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
				INSERT #sql SELECT ltrim(@msg)  
				GOTO CLOSE_CURSOR  
			END 
		END
		ELSE
		BEGIN
			SET @exemption_reason = 'LabPack Profile'
			SET @apply_flag = 'F'
			SET @audit_reference = 'Created by LPx'

			SELECT @exemption_reason_uid = exemption_reason_uid
			FROM ProfileFeeExemptionReason
			WHERE exemption_reason = @exemption_reason
		
			SELECT @exemption_approved_by = config_value 
			FROM Configuration
			WHERE Upper(config_key) = 'PROFILE_FEE_EXEMPTION_APPROVER' 

			SELECT @exemption_approved_by_name = user_name 
			FROM Users
			WHERE user_code = @exemption_approved_by 

			INSERT ProfileFeeDetail
			(profile_id, apply_flag, exemption_reason_uid, exemption_approved_by, date_exempted, added_by, date_added, modified_by, date_modified)
			VALUES 
			(@new_app_id, @apply_flag, @exemption_reason_uid, @exemption_approved_by, CONVERT(VARCHAR(10), @update_dt, 101), 'LP', @update_dt, 'LP', @update_dt)
			
			IF @@ERROR <> 0  
			BEGIN  
				ROLLBACK TRANSACTION
				CLOSE c_loop_neg_profile_ids  
				DEALLOCATE c_loop_neg_profile_ids  
				SELECT @msg = '   Error in sp_trip_sync_upload_execute: inserting ProfileFeeDetail failed'  
				EXEC sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
				INSERT #sql SELECT ltrim(@msg)  
				GOTO CLOSE_CURSOR  
			END;
		
			WITH AuditColumns AS (SELECT 'apply_flag' name UNION SELECT 'date_exempted' UNION SELECT 'exemption_approved_by' UNION SELECT 'exemption_reason_uid')
			INSERT INTO ProfileAudit (profile_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
			SELECT @new_app_id,
			'ProfileFeeDetail',
			AuditColumns.name,
			'(inserted)',
			CASE AuditColumns.name WHEN 'apply_flag' THEN  @apply_flag 
										WHEN 'date_exempted' THEN CONVERT(VARCHAR(10), @update_dt,101) 
		 								WHEN 'exemption_approved_by' THEN @exemption_approved_by_name
										WHEN 'exemption_reason_uid' THEN @exemption_reason
										ELSE NULL END,
			@audit_reference,
			'LP',
			@update_dt
			FROM AuditColumns

			IF @@ERROR <> 0  
			BEGIN  
				ROLLBACK TRANSACTION
				CLOSE c_loop_neg_profile_ids  
				DEALLOCATE c_loop_neg_profile_ids  
				SELECT @msg = '   Error in sp_trip_sync_upload_execute: inserting ProfileAudit for ProfileFeeDetail failed'  
				EXEC sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
				INSERT #sql SELECT ltrim(@msg)  
				GOTO CLOSE_CURSOR  
			END 
		END
  
		update ProfileTracking  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileTracking.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileLab  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileLab.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileQuoteHeader  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileQuoteHeader.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileQuoteApproval  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileQuoteApproval.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileQuoteDetail  
		set profile_id = @new_app_id,  
		show_cust_flag = isnull(show_cust_flag,'T')  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileQuoteDetail.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileConstituent  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileConstituent.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileWasteCode  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileWasteCode.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileLDRSubcategory  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileLDRSubcategory.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileComposition  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileComposition.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileContainerSize  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileContainerSize.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update Note  
		set profile_id = @new_app_id  
		where profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative Note.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		-- rb can't call stored proc, silent flag is not implemented to bypass the select  
		--exec @new_quote_id = sp_sequence_next 'QuoteHeader.quote_id', 0  
		select @new_quote_id = next_value from Sequence where name = 'QuoteHeader.quote_id'  
		update plt_ai.dbo.sequence set next_value = next_value + 1 where name = 'QuoteHeader.quote_id'  
  
		if @new_quote_id is null or @new_quote_id < 1 or (@new_quote_id + 1) <> (select next_value from plt_ai.dbo.sequence where name = 'QuoteHeader.quote_id')  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: allocating new QuoteHeader.quote_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileQuoteHeader  
		set quote_id = @new_quote_id  
		where profile_id = @new_app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileQuoteHeader.quote_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileQuoteDetail  
		set quote_id = @new_quote_id  
		where profile_id = @new_app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileQuoteDetail.quote_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update ProfileQuoteApproval  
		set quote_id = @new_quote_id  
		where profile_id = @new_app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ProfileQuoteApproval.quote_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update Profile  
		set quote_id = @new_quote_id  
		where profile_id = @new_app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative Profile.quote_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update WorkOrderDetail  
		set profile_id = @new_app_id  
		where workorder_id = @workorder_id  
		and company_id = @company_id  
		and profit_ctr_id = @profit_ctr_id  
		and resource_type = 'D'  
		and profile_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_profile_ids  
			deallocate c_loop_neg_profile_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative WorkOrderDetail.profile_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		fetch c_loop_neg_profile_ids into @app_id, @workorder_id, @company_id, @profit_ctr_id  
		end  
  
		close c_loop_neg_profile_ids  
		deallocate c_loop_neg_profile_ids  
	end  
  
	-- 08/14/2012 adjust negative TSDFApproval ids  
	if exists (select 1 from WorkOrderDetail wod, TSDF t, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.tsdf_code = t.tsdf_code  
		and isnull(t.eq_flag,'F') = 'F'  
		and wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and wod.resource_type = 'D'  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.TSDF_approval_id < 0)  
	begin  
		-- generate SQL to update client IDs  
		declare c_loop_neg_tsdfapp_ids cursor for  
			select distinct wod.tsdf_approval_id, wod.workorder_id, wod.company_id, wod.profit_ctr_id  
			from WorkOrderDetail wod, TSDF t, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
			where wod.tsdf_code = t.tsdf_code  
			and isnull(t.eq_flag,'F') = 'F'  
			and wod.workorder_id = woh.workorder_id  
			and wod.company_id = woh.company_id  
			and wod.profit_ctr_id = woh.profit_ctr_id  
			and wod.resource_type = 'D'  
			and woh.trip_id = tcl.trip_id  
			and tcl.trip_connect_log_id = @trip_connect_log_id  
			and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
			and woh.trip_sequence_id = tsu.trip_sequence_id  
			and tsu.trip_sync_upload_id = @trip_sync_upload_id  
			and isnull(wod.TSDF_approval_id,0) < 0  
			for read only  
  
		open c_loop_neg_tsdfapp_ids  
		fetch c_loop_neg_tsdfapp_ids into @app_id, @workorder_id, @company_id, @profit_ctr_id  
  
		while @@FETCH_STATUS = 0  
		begin  
		-- rb can't call stored proc, silent flag is not implemented to bypass the select  
		--exec @new_app_id = sp_sequence_next 'TSDFApproval.TSDF_approval_id', 0  
		select @new_app_id = next_value from Sequence where name = 'TSDFApproval.TSDF_approval_id'  
		update plt_ai.dbo.sequence set next_value = next_value + 1 where name = 'TSDFApproval.TSDF_approval_id'  
  
		if @new_app_id is null or @new_app_id < 1 or (@new_app_id + 1) <> (select next_value from plt_ai.dbo.sequence where name = 'TSDFApproval.TSDF_approval_id')  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: allocating new TSDFApproval.TSDF_approval_id failed'  
			insert #sql values (ltrim(@msg))  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			goto CLOSE_CURSOR  
		end  
  
		/*select @sql_update_neg_ids = isnull(@sql_update_neg_ids,'') + ' update tsdfapproval'  
		+ ' set tsdf_approval_id=' + convert(varchar(20),@new_app_id)  
		+ ' where tsdf_approval_id=' + convert(varchar(20),@app_id)  
		+ ' update tsdfapprovalprice'  
		+ ' set tsdf_approval_id=' + convert(varchar(20),@new_app_id)  
		+ ' where tsdf_approval_id=' + convert(varchar(20),@app_id)  
		+ ' update tsdfapprovalconstituent'  
		+ ' set tsdf_approval_id=' + convert(varchar(20),@new_app_id)  
		+ ' where tsdf_approval_id=' + convert(varchar(20),@app_id)  
		+ ' update tsdfapprovalwastecode'  
		+ ' set tsdf_approval_id=' + convert(varchar(20),@new_app_id)  
		+ ' where tsdf_approval_id=' + convert(varchar(20),@app_id)  
		+ 'update workorderdetail'  
		+ ' set tsdf_approval_id=' + convert(varchar(20),@new_app_id)  
		+ ' where workorder_id=' + convert(varchar(20),@workorder_id)  
		+ ' and company_id=' + convert(varchar(20),@company_id)  
		+ ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)  
		+ ' and sequence_id=' + convert(varchar(20),@wod_sequence_id)  
		+ ' and resource_type = ''D'''  
		+ ' and tsdf_approval_id = ' + convert(varchar(20),@app_id)  
	*/  
  
		-- update tables  
		update TSDFApproval  
		set tsdf_approval_id = @new_app_id  
		where tsdf_approval_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative TSDFApproval.TSDF_approval_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update TSDFApprovalPrice  
		set tsdf_approval_id = @new_app_id  
		where tsdf_approval_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative TSDFApprovalPrice.TSDF_approval_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR	
		end  
  
		update TSDFApprovalConstituent  
		set tsdf_approval_id = @new_app_id  
		where tsdf_approval_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative TSDFApprovalConstituent.TSDF_approval_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update TSDFApprovalWasteCode  
		set tsdf_approval_id = @new_app_id  
		where tsdf_approval_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative TSDFApprovalWasteCode.TSDF_approval_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update TSDFApprovalLDRSubcategory  
		set tsdf_approval_id = @new_app_id  
		where tsdf_approval_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative TSDFApprovalLDRSubcategory.tsdf_approval_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update Note  
		set tsdf_approval_id = @new_app_id  
		where tsdf_approval_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative Note.tsdf_approval_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update WorkOrderDetail  
		set TSDF_approval_id = @new_app_id  
		where workorder_id = @workorder_id  
		and company_id = @company_id  
		and profit_ctr_id = @profit_ctr_id  
		and resource_type = 'D'  
		and TSDF_approval_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_tsdfapp_ids  
			deallocate c_loop_neg_tsdfapp_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative WorkOrderDetail.TSDF_approval_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		fetch c_loop_neg_tsdfapp_ids into @app_id, @workorder_id, @company_id, @profit_ctr_id  
		end  
  
		close c_loop_neg_tsdfapp_ids  
		deallocate c_loop_neg_tsdfapp_ids  
	end  
  
	-- adjust negative WorkOrderDetail sequence ids  
	if exists (select 1 from WorkOrderDetail wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and wod.resource_type = 'D'  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.sequence_id < 0)  
	begin  
	/*  
		-- rb 03/19/2010 generate SQL to update client IDs  
		declare c_loop_neg_seq_ids cursor for  
		select wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id  
		from WorkOrderDetail wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and wod.resource_type = 'D'  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.sequence_id < 0  
		for read only  
  
		open c_loop_neg_seq_ids  
		fetch c_loop_neg_seq_ids into @workorder_id, @company_id, @profit_ctr_id, @wod_sequence_id  
  
		while @@FETCH_STATUS = 0  
		begin  
		select @sql_update_neg_ids = isnull(@sql_update_neg_ids,'') + 'update workorderdetail'  
		+ ' set sequence_id=' + convert(varchar(20),@wod_max_seq + abs(@wod_sequence_id))  
		+ ' where workorder_id=' + convert(varchar(20),@workorder_id)  
		+ ' and company_id=' + convert(varchar(20),@company_id)  
		+ ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)  
		+ ' and sequence_id=' + convert(varchar(20),@wod_sequence_id)  
		+ ' and resource_type=''D'''  
		+ 'update workorderdetailcc'  
		+ ' set sequence_id=' + convert(varchar(20),@wod_max_seq + abs(@wod_sequence_id))  
		+ ' where workorder_id=' + convert(varchar(20),@workorder_id)  
		+ ' and company_id=' + convert(varchar(20),@company_id)  
		+ ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)  
		+ ' and sequence_id=' + convert(varchar(20),@wod_sequence_id)  
		+ 'update workorderdetailitem'  
		+ ' set sequence_id=' + convert(varchar(20),@wod_max_seq + abs(@wod_sequence_id))  
		+ ' where workorder_id=' + convert(varchar(20),@workorder_id)  
		+ ' and company_id=' + convert(varchar(20),@company_id)  
		+ ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)  
		+ ' and sequence_id=' + convert(varchar(20),@wod_sequence_id)  
		+ 'update workorderdetailunit'  
		+ ' set sequence_id=' + convert(varchar(20),@wod_max_seq + abs(@wod_sequence_id))  
		+ ' where workorder_id=' + convert(varchar(20),@workorder_id)  
		+ ' and company_id=' + convert(varchar(20),@company_id)  
		+ ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)  
		+ ' and sequence_id=' + convert(varchar(20),@wod_sequence_id)  
		+ 'update workorderwastecode'  
		+ ' set workorder_sequence_id=' + convert(varchar(20),@wod_max_seq + abs(@wod_sequence_id))  
		+ ' where workorder_id=' + convert(varchar(20),@workorder_id)  
		+ ' and company_id=' + convert(varchar(20),@company_id)  
		+ ' and profit_ctr_id=' + convert(varchar(20),@profit_ctr_id)  
		+ ' and workorder_sequence_id=' + convert(varchar(20),@wod_sequence_id)  
  
		fetch c_loop_neg_seq_ids into @workorder_id, @company_id, @profit_ctr_id, @wod_sequence_id  
		end  
  
		close c_loop_neg_seq_ids  
		deallocate c_loop_neg_seq_ids  
	*/  
  
		-- update tables  
		update WorkOrderDetail  
		set sequence_id = @wod_max_seq + abs(sequence_id),  
		billing_sequence_id = @wod_max_seq + abs(sequence_id)  
		from WorkOrderDetail wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.sequence_id < 0  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neq_seq_ids  
			deallocate c_loop_neq_seq_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative WorkOrderDetail.sequence_ids failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update WorkOrderDetailCC  
		set sequence_id = @wod_max_seq + abs(sequence_id)  
		from WorkOrderDetailCC wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.sequence_id < 0  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neq_seq_ids  
			deallocate c_loop_neq_seq_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative WorkOrderDetailCC.sequence_ids failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update WorkOrderDetailItem  
		set sequence_id = @wod_max_seq + abs(sequence_id)  
		from WorkOrderDetailItem wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.sequence_id < 0  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neq_seq_ids  
			deallocate c_loop_neq_seq_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative WorkOrderDetailItem.sequence_ids failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update WorkOrderDetailUnit  
		set sequence_id = @wod_max_seq + abs(sequence_id)  
		from WorkOrderDetailUnit wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.sequence_id < 0  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neq_seq_ids  
			deallocate c_loop_neq_seq_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative WorkOrderDetailUnit.sequence_ids failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		update WorkOrderWasteCode  
		set workorder_sequence_id = @wod_max_seq + abs(workorder_sequence_id)  
		from WorkOrderWasteCode wod, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where wod.workorder_id = woh.workorder_id  
		and wod.company_id = woh.company_id  
		and wod.profit_ctr_id = woh.profit_ctr_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and wod.workorder_sequence_id < 0  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neq_seq_ids  
			deallocate c_loop_neq_seq_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative WorkOrderWasteCode.workorder_sequence_ids failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		--12/04/2023 LabPackLabel  
		update LabPackLabel  
		set sequence_id = @wod_max_seq + abs(sequence_id)  
		from LabPackLabel lpl, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where lpl.workorder_id = woh.workorder_id  
		and lpl.company_id = woh.company_id  
		and lpl.profit_ctr_id = woh.profit_ctr_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and lpl.sequence_id < 0  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative LabPackLabel.sequence_ids failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
	end  
  
	-- 10/23/2017 - Adjust negative ActionRegister ids  
	if exists (select 1 from ActionRegister ar, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where ar.generator_id = woh.generator_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and ar.action_register_id < 0)  
	begin  
		-- generate SQL to update action register IDs  
		declare c_loop_neg_ar_ids cursor for  
		select distinct ar.action_register_id  
		from ActionRegister ar, WorkOrderHeader woh, TripConnectLog tcl, TripSyncUpload tsu  
		where ar.generator_id = woh.generator_id  
		and woh.trip_id = tcl.trip_id  
		and tcl.trip_connect_log_id = @trip_connect_log_id  
		and tcl.trip_connect_log_id = tsu.trip_connect_log_id  
		and woh.trip_sequence_id = tsu.trip_sequence_id  
		and tsu.trip_sync_upload_id = @trip_sync_upload_id  
		and ar.action_register_id < 0  
		for read only  
  
		open c_loop_neg_ar_ids  
		fetch c_loop_neg_ar_ids into @app_id  
  
		while @@FETCH_STATUS = 0  
		begin  
		select @new_app_id = next_value from Sequence where name = 'ActionRegister.action_register_id'  
		update plt_ai.dbo.sequence set next_value = next_value + 1 where name = 'ActionRegister.action_register_id'  
  
		if @new_app_id is null or @new_app_id < 1 or (@new_app_id + 1) <> (select next_value from plt_ai.dbo.sequence where name = 'ActionRegister.action_register_id')  
		begin  
			rollback transaction  
			close c_loop_neg_ar_ids  
			deallocate c_loop_neg_ar_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: allocating new ActionRegister.action_register_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql  
			select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		-- update table  
		update ActionRegister  
		set action_register_id = @new_app_id  
		where action_register_id = @app_id  
  
		if @@error <> 0  
		begin  
			rollback transaction  
			close c_loop_neg_ar_ids  
			deallocate c_loop_neg_ar_ids  
			select @msg = '   Error in sp_trip_sync_upload_execute: updating negative ActionRegister.action_register_id failed'  
			exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
			insert #sql select ltrim(@msg)  
			goto CLOSE_CURSOR  
		end  
  
		fetch c_loop_neg_ar_ids into @app_id  
		end  
  
		close c_loop_neg_ar_ids  
		deallocate c_loop_neg_ar_ids  
	end  
  
	-- record that this stop has been processed  
	update TripSyncUpload  
	set processed_flag = 'T',  
	date_modified = getdate()  
	where trip_sync_upload_id = @trip_sync_upload_id  
  
	select @err = @@ERROR  
	if @err <> 0  
	begin  
		rollback transaction  
		select @msg = '   Error #' + convert(varchar(20),@err) + ' in sp_trip_sync_upload_execute, updating processed_flag for TripSyncUpload'  
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
		insert #sql select ltrim(@msg)  
		goto CLOSE_CURSOR  
	end  
  
	update TripSyncUploadSQL  
	set date_modified = getdate()  
	where trip_sync_upload_id = @trip_sync_upload_id  
  
	select @err = @@ERROR  
	if @err <> 0  
	begin  
		rollback transaction  
		select @msg = '   Error #' + convert(varchar(20),@err) + ' in sp_trip_sync_upload_execute, updating date_modified for TripSyncUploadSQL'  
		exec sp_trip_sync_add_connect_detail @trip_connect_log_id, @msg, @update_dt  
		insert #sql select ltrim(@msg)  
		goto CLOSE_CURSOR  
	end  
  
  
	-- COMMIT  
	commit transaction  
  
	-- tell device that stop was processed  
	insert #sql select  
	/*select @sql_return =*/ 'update TripFieldUpload set uploaded_flag=''T'', last_upload_date=getdate() where trip_id=' +  
		convert(varchar(20),tcl.trip_id) + ' and trip_sequence_id=' +  
		convert(varchar(20),tsu.trip_sequence_id)  
	from TripSyncUpload tsu, TripConnectLog tcl  
	where tsu.trip_sync_upload_id = @trip_sync_upload_id  
	and tsu.trip_connect_log_id = tcl.trip_connect_log_id  
  
  
	CLOSE_CURSOR:  
	close c_loop  
	deallocate c_loop  
  
  
	RETURN_RESULTS:  
	set nocount off  
	--select @sql_return + isnull(' ' + @sql_update_neg_ids,'') as sql  
	select sql as sql from #sql  
	drop table #sql  
	return 0
end
go

GRANT EXECUTE ON [dbo].[sp_trip_sync_upload_execute] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_trip_sync_upload_execute] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_trip_sync_upload_execute] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_trip_sync_upload_execute] TO EQAI;
GO

