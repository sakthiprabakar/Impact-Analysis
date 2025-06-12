USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorderdetail_Insert_disposal]    Script Date: 10/14/2024 3:35:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_sfdc_workorderdetail_Insert_disposal] 
                        @workorder_id_ret int, 
                        @newsequence_id int,
                        @sfs_workorderheader_uid int,
                        @manifest varchar(15) null,         
                        @manifest_flag Char(1) ='T',
                        @manifest_state Char(2) ='H',
                        @eq_flag char(1),
                        @tsdf_approval_id int,
                        @profile_id int,
                        @customer_id int,
                        @extended_price money null,
                        @extended_cost money null,
                        @quantity float null,                                                                                  
                        @cost money null,
						@price money null, 
                        @bill_unit_code varchar(4) null,                                                                                          
                        @company_id int,                                                       
                        @profit_ctr_ID int, 
						@eq_company int,
						@eq_profit_ctr int,                                                                                    
                        @as_map_disposal_line char(1),
                        @as_woh_disposal_flag char(1),  
						@user_code varchar(10),
						@price_source varchar(40),
						/*@generator_sign_date datetime,
                        @generator_sign_,*/
						@response varchar(2000) OUTPUT

/*  
Description: 

Disposal Line insert (This procedure called from sp_sfdc_workorderdetail_Insert)
Created By Venu & Nagaraj -- 19/Sep/2024
Rally # US126358 & 126371
DE35884 -- Commented the extended_price value.
*/

AS
DECLARE                            
@ll_cnt_manifest int,
@source_system varchar(50),
@BROKER_FLAG char(1),
@key_value varchar(2000),
@flag char(1),
@billing_flag char(1) = 'T'

BEGIN                                 

	Set @source_system = 'sp_sfdc_workorderdetail_disposal: Salesforce'
	Set @Response='Disposal Integration Successful'




		Set @key_value = 'workorder_id;' + cast((convert(int,@workorder_id_ret)) as varchar(20)) +				
							' newsequence_id;' + cast((convert(int,@newsequence_id)) as varchar(20)) + 
							' sfs_workorderheader_uid;' + cast((convert(int,@sfs_workorderheader_uid)) as varchar(20)) + 
							' manifest;' + isnull(@manifest,'') +
							' manifest_flag;' + isnull(@manifest_flag,'') +
							' manifest_state;' + isnull(@manifest_state,'') +
							' eq_flag;' + isnull(@eq_flag,'') +							
							' extended_price;' + cast((convert(int,@extEnded_price)) as varchar(20)) + 
							' extended_cost;' + cast((convert(int,@extEnded_cost)) as varchar(20)) + 
							' tsdf_approval_id;' + cast((convert(int,@tsdf_approval_id)) as varchar(20)) + 
							' profile_id;' + cast((convert(int,@profile_id)) as varchar(20)) + 
							' customer_id;' + cast((convert(int,@customer_id)) as varchar(20)) + 
							' quantity;' + cast((convert(float,@quantity)) as varchar(20))+ 	
							' cost;' + cast((convert(int,@cost)) as varchar(20))+ 
							' price;' + cast((convert(int,@price)) as varchar(20)) + 
							' bill_unit_code;' + isnull(@bill_unit_code ,'') + 							
							' company id;' + cast((convert(int,@company_id)) as varchar(20)) + 							
							' profit_ctr_id;' + cast((convert(int,@profit_ctr_id)) as varchar(20))+								
							' eq_company ;' + cast((convert(int,@eq_company)) as varchar(20)) + 
							' eq_profit_ctr ;' + cast((convert(int,@eq_profit_ctr)) as varchar(20)) +
							' as_map_disposal_line;' + isnull(@as_map_disposal_line,'') +
							' as_woh_disposal_flag; ' + isnull(@as_woh_disposal_flag ,'') +
							' price_source; ' + isnull(@price_source ,'') +
							' user_code; ' + isnull(@user_code ,'') 
--							--' generator_sign_date;' + cast((convert(datetime,@generator_sign_date)) as varchar(20)) +	
							--' generator_sign_name;' + isnull(@generator_sign_name,'') +
							
							
							--select @manifest_state
							

	SELECT @ll_cnt_manifest=COUNT(*) FROM  SFSWorkorderManifest WHERE
																WORKORDER_ID=@workorder_id_ret
																AND MANIFEST=TRIM(@MANIFEST)
																and company_id=@company_id
																and profit_ctr_ID=@profit_ctr_ID        


	If @ll_cnt_manifest=0 
		Begin
		insert into SFSWorkorderManifest
		(sfs_workorderheader_uid,
		workorder_id,
		company_id,
		profit_ctr_ID,
		manifest,
		manifest_flag,
		manifest_state,
		eq_flag,
		--generator_sign_date,
		--generator_sign_name,
		added_by,
		date_added,
		modified_by,
		date_modified
		)
		select 
		@sfs_workorderheader_uid,
		@workorder_id_ret,
		@company_id,
		@profit_ctr_id,
		@manifest,
		@manifest_flag,
		' ' + @manifest_state,
		@eq_flag,
		--@generator_sign_date,
		--@generator_sign_name,
		@user_code,
		getdate(),
		@user_code,
		getdate()
                            
				
		if @@error <> 0                                                                                          
		Begin                                   
			Rollback Transaction
			SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkordermanifest table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
			(Input_Params,source_system_details,action,Error_description,log_date,Added_by)
			SELECT
			@key_value,
			@source_system,
			'Insert',
			@Response,
			GETDATE(),
			@user_code
			return -1
		end
	End
                                                            
                                                                                                                                       
	If @ll_cnt_manifest >= 1
	Begin
	
			update SFSWorkorderManifest set 
			manifest_state= ' ' + @manifest_state,
			manifest_flag=@manifest_flag,
			modified_by=@user_code,
			date_modified=getdate()
			--            generator_sign_date=@generator_sign_date,
			--            generator_sign_name=@generator_sign_name
			where
			manifest=trim(@manifest) and
			company_id=@company_id and
			profit_Ctr_id=@profit_Ctr_id and
			(
			ISNULL(NULLIF(manifest_state, 'NA'), '') <> ISNULL(NULLIF(@manifest_state, 'NA'), '') or
			ISNULL(NULLIF(manifest_flag, 'NA'), '') <> ISNULL(NULLIF(@manifest_flag, 'NA'), '') --or
			--ISNULL(NULLIF(generator_sign_date, 'NA'), '') <> ISNULL(NULLIF(@generator_sign_date, 'NA'), '') --or
			--ISNULL(NULLIF(generator_sign_name, 'NA'), '') <> ISNULL(NULLIF(@generator_sign_date, 'NA'), '') 
			) and
			WORKORDER_ID=@workorder_id_ret and 
			sfs_workorderheader_uid=@sfs_workorderheader_uid

	End

	If @as_map_disposal_line='I'  
	Begin
			insert into SFSWorkorderDetailUnit
			(sfs_workorderheader_uid,
			workorder_id,
			company_id,
			profit_ctr_id,
			sequence_id,
			manifest_flag,
			bill_unit_code,
			size,
			quantity,
			cost,
			price,
			extended_cost,
			extended_price,
			added_by,
			date_added,
			modified_by,
			date_modified,
			price_source,
			billing_flag)
			select
			@sfs_workorderheader_uid,
			@workorder_id_ret,
			@company_id,
			@profit_ctr_id,
			@newsequence_id,
			@manifest_flag,
			@bill_unit_code,
			@bill_unit_code,
			@quantity,
			@cost,
			@price,
			@extended_cost,
			@quantity*@price,
			@user_code,
			getdate(),
			@user_code,
			getdate(),
			@price_source,
			@billing_flag
                                                                                                                        
			if @@error <> 0                                                                                          
			begin     
			Rollback Transaction
			SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
																					SELECT
																					@key_value,
																					@source_system,
																					'Insert',
																					@Response,
																					GETDATE(),
																					@user_code
			return -1
			end
		End
                                                                           
		IF  @as_map_disposal_line='D' and @EQ_FLAG='F'
		Begin
			insert into SFSWorkorderDetailUnit
			(cost,
			 Price,
			bill_unit_code,
			size,
			sfs_workorderheader_uid,
			workorder_id,
			company_id,
			profit_ctr_id,
			sequence_id,
			manifest_flag,
			quantity,
			--extended_cost,
			--extended_price,
			added_by,
			date_added,
			modified_by,
			date_modified,
			price_source,
			billing_flag
			)
			SELECT TSDFApprovalPrice.cost,
			TSDFApprovalPrice.price, 
			TSDFApprovalPrice.bill_unit_code,
			TSDFApprovalPrice.bill_unit_code,
			@sfs_workorderheader_uid,
			@workorder_id_ret,
			@company_id,
			@profit_ctr_id,
			@newsequence_id,
			@manifest_flag,
			@quantity,
			--@quantity*cost,
			--@quantity*price,
			@user_code,
			getdate(),
			@user_code,
			getdate(),
			@price_source,
			@billing_flag
			FROM TSDFApproval
			INNER JOIN TSDFApprovalPrice 
			ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id
			WHERE TSDFApproval.TSDF_approval_id = @tsdf_approval_id
			AND TSDFApproval.customer_id = @customer_id
			AND TSDFApproval.company_id = @company_id
			AND TSDFApproval.profit_ctr_id = @profit_ctr_id
			AND TSDFApprovalPrice.record_type = 'D'
                                                                                                                        
			if @@error <> 0                                                                                          
			begin
			rollback transaction                                                                                                                                                                                                                           
			SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
																													SELECT
																													@key_value,
																													@source_system,
																													'Insert',
																													@Response,
																													GETDATE(),
																													@user_code
			return -1
			End
		End

		
		IF @as_map_disposal_line= 'D' AND @EQ_FLAG='T'
		BEGIN
		SELECT @BROKER_FLAG=broker_flag FROM PROFILE WHERE profile_id = @profile_id
                                                                             
			IF @BROKER_FLAG = 'O'
			BEGIN
				insert into SFSWorkorderDetailUnit
				(cost,
				price,
				bill_unit_code,
				size,
				sfs_workorderheader_uid,
				workorder_id,
				company_id,
				profit_ctr_id,
				sequence_id,
				manifest_flag,
				quantity,
				--extended_cost,
				--extended_price,
				added_by,
				date_added,
				modified_by,
				date_modified,
				price_source,
				billing_flag
				)
				select ISNULL(ProfileQuoteDetail.price, 0)+ISNULL(ProfileQuoteDetail.surcharge_price, 0),
				ISNULL(ProfileQuoteDetail.orig_customer_price, 0),
				ProfileQuoteDetail.bill_unit_code,ProfileQuoteDetail.bill_unit_code,
				@sfs_workorderheader_uid,
				@workorder_id_ret,
				@company_id,
				@profit_ctr_id,
				@newsequence_id,
				@manifest_flag,
				@quantity,
				--@quantity*@cost,
				--@quantity*@price,
				@user_code,
				getdate(),
				@user_code,
				getdate(),
				@price_source,
				@billing_flag
				FROM Profile
				INNER JOIN ProfileQuoteDetail 
				ON Profile.profile_id = ProfileQuoteDetail.profile_id
				WHERE Profile.profile_id = @PROFILE_ID
				AND Profile.orig_customer_id = @CUSTOMER_ID
				AND ProfileQuoteDetail.company_id = @EQ_COMPANY
				AND ProfileQuoteDetail.profit_ctr_id = @EQ_PROFIT_CTR
				AND ProfileQuoteDetail.record_type = 'D'
                                                            
				if @@error <> 0                                                                                        
				begin
				rollback transaction                                                                                          
				Set @flag = 'E'    
				SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
																																	SELECT
																																	@key_value,
																																	@source_system,
																																	'Insert',
																																	@Response,
																																	GETDATE(),
																																	@user_code
				return -1
				end
			End
			IF @BROKER_FLAG <> 'O' 
			BEGIN
				insert into SFSWorkorderDetailUnit
				(cost,
				price,
				bill_unit_code,
				size,
				sfs_workorderheader_uid,
				workorder_id,
				company_id,
				profit_ctr_id,
				sequence_id,
				manifest_flag,
				quantity,
				--extended_cost,
				--extended_price,
				added_by,
				date_added,
				modified_by,
				date_modified,
				price_source,
				billing_flag
				)
				select ISNULL(ProfileQuoteDetail.price, 0)+ISNULL(ProfileQuoteDetail.surcharge_price, 0),
				0,
				ProfileQuoteDetail.bill_unit_code,ProfileQuoteDetail.bill_unit_code,
				@sfs_workorderheader_uid,
				@workorder_id_ret,
				@company_id,
				@profit_ctr_id,
				@newsequence_id,
				@manifest_flag,
				@quantity,
				--@quantity*@cost,
				--@quantity*@price,
				@user_code,
				getdate(),
				@user_code,
				getdate(),
				@price_source,
				@billing_flag
				FROM Profile
				INNER JOIN ProfileQuoteDetail 
				ON Profile.profile_id = ProfileQuoteDetail.profile_id
				WHERE Profile.profile_id = @PROFILE_ID
			--	AND Profile.orig_customer_id = @CUSTOMER_ID
				AND ProfileQuoteDetail.company_id = @EQ_COMPANY
				AND ProfileQuoteDetail.profit_ctr_id = @EQ_PROFIT_CTR
				AND ProfileQuoteDetail.record_type = 'D'


				if @@error <> 0                                                                                        
				begin
				rollback transaction                                                                                          
				Set @flag = 'E'    
				SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
																																	SELECT
																																	@key_value,
																																	@source_system,
																																	'Insert',
																																	@Response,
																																	GETDATE(),
																																	@user_code
				return -1
				End
			End
		End
End
Return 0


Go

GRANT EXECUTE ON OBJECT::[dbo].sp_sfdc_workorderdetail_insert_disposal TO EQAI

Go

GRANT EXECUTE ON OBJECT::[dbo].sp_sfdc_workorderdetail_insert_disposal TO svc_CORAppUser

GO

