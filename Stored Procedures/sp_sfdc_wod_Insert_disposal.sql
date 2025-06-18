USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_wod_Insert_disposal]    Script Date: 5/7/2025 7:19:13 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER     PROCEDURE [dbo].[sp_sfdc_wod_Insert_disposal] 
                        @workorder_id_ret int, 
                        @newsequence_id int,                        
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
						@currency_code char(3),
						@old_billunitcode varchar(4),
						@salesforce_invoice_csid varchar(18), 
						@bill_rate int,
						@response varchar(2000) OUTPUT

/*  
Description: 

Disposal Line insert (This procedure called from sp_sfdc_wod_Insert)
Created By Venu -- 18/Oct/2024
Rally # US129733  - New Design To handle the workorder in Single JSON
Rally # US133505/TA477732 -- Excluded cost and extended cost from salesforce for disposal method Indirect[I].
Rally # DE36664 To capture the Audit Entry - Nagaraj
Rally#  DE36836, Updated price_source value for the Indirect disposal line when the update manifest trigerred from salesdforce.
Rally#  DE36909 Insert/update workorderdetailunit entry for the respective billunit only
Rally#  US136682 01/08/2025 Insert Transporter record duing new manifest creation
Rally # US138836 -- If the bill_rate is zero then Bill_rate value will be updated in workorderdetail.
Rally # DE37646  -- Replaced tsdf_approval_id with profile_id in one of the update workorderdetail where clause.
Rally# DE37711 -- Added @manifest in the where clause in the workorderdetail update query
Rally# DE38851 -- Added (@manifest) in the where clause in the workorderdetail update query
*/

AS
DECLARE                            
@ll_cnt_manifest int,
@source_system varchar(50),
@BROKER_FLAG char(1),
@key_value varchar(2000),
@flag char(1),
@billing_flag char(1) = 'T',
@ll_cnt_wdunit int = 0,
@indirect_cost money,
@transporter_sequence_id int,
@default_transporter_code varchar(15)
 
BEGIN                               

	
	Set @Response='Disposal Integration Successful'
						

	Select @ll_cnt_manifest=COUNT(*) FROM  WorkorderManifest with(nolock) WHERE
																WORKORDER_ID=@workorder_id_ret
																AND MANIFEST=@MANIFEST
																and company_id=@company_id
																and profit_ctr_ID=@profit_ctr_ID        


	If @ll_cnt_manifest=0 
		Begin
		insert into WorkorderManifest
		(workorder_id,
		company_id,
		profit_ctr_ID,
		manifest,
		manifest_flag,
		manifest_state,
		eq_flag,		
		added_by,
		date_added,
		modified_by,
		date_modified)
		select 		
		@workorder_id_ret,
		@company_id,
		@profit_ctr_id,
		upper(@manifest),
		@manifest_flag,
		' ' + @manifest_state,
		@eq_flag,		
		@user_code,
		getdate(),
		@user_code,
		getdate()
                            
				
		if @@error <> 0                                                                                          
		Begin                                   
			Set @Response = 'Error: Integration failed due to the following reason; could not insert into workordermanifest table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
			Return -1
		end

		select @default_transporter_code=default_transporter from ProfitCenter where company_id=@company_id and profit_ctr_ID=@profit_ctr_ID

		If @default_transporter_code is null or @default_transporter_code=''
		Begin
		Set @default_transporter_code='BLANK'
		End

		Select @transporter_sequence_id= isnull(max(transporter_sequence_id),0) + 1 from workordertransporter Where workorder_id=@workorder_id_ret and
		                                                                                                  company_id=@company_id and
																										  profit_ctr_ID = @profit_ctr_ID and
																										  upper(manifest)=upper(@manifest)

		Insert into workordertransporter
					(workorder_id,
					 company_id,
					 profit_ctr_ID,
					 manifest,
					 transporter_sequence_id,
					 transporter_code,
					 transporter_sign_name,		
					 transporter_sign_date,
					 transporter_license_nbr,
					 added_by,
					 date_added,
					 modified_by,
					 date_modified)
					 select 		
					 @workorder_id_ret,
					 @company_id,
					 @profit_ctr_id,
					 upper(@manifest),
					 @transporter_sequence_id,
					 @default_transporter_code,
					 Null,
					 Null,
					 Null,
					 @user_code,
					 getdate(),
					 @user_code,
					 getdate()

         if @@error <> 0                                                                                          
		Begin                                   
			Set @Response = 'Error: Integration failed due to the following reason; could not insert into workordertransporter table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
			Return -1
		end


	End
                                                            
                                                                                                                                       
	If @ll_cnt_manifest > 0
	Begin
	
			update WorkorderManifest set 
			manifest_state= ' ' + @manifest_state,
			manifest_flag=@manifest_flag,
			modified_by=@user_code,
			date_modified=getdate()			
			where
			manifest=@manifest and
			company_id=@company_id and
			profit_Ctr_id=@profit_Ctr_id and
			(ISNULL(NULLIF(manifest_state, 'NA'), '') <> ISNULL(NULLIF(@manifest_state, 'NA'), '') or
			ISNULL(NULLIF(manifest_flag, 'NA'), '') <> ISNULL(NULLIF(@manifest_flag, 'NA'), '')) and
			WORKORDER_ID=@workorder_id_ret 
	End
		 
		
	If @as_map_disposal_line='I'  
	Begin

	    /*Added By Nagaraj - Start*/
		If @eq_flag='T'
		Begin	
	     
			select @indirect_cost=	
			ISNULL(ProfileQuoteDetail.price, 0)+ISNULL(ProfileQuoteDetail.surcharge_price, 0)
			FROM Profile
			INNER JOIN ProfileQuoteDetail 
			ON Profile.profile_id = ProfileQuoteDetail.profile_id
			WHERE Profile.profile_id = @PROFILE_ID
			AND ProfileQuoteDetail.company_id = @EQ_COMPANY
			AND ProfileQuoteDetail.profit_ctr_id = @EQ_PROFIT_CTR
			AND ProfileQuoteDetail.record_type = 'D'
			AND ProfileQuoteDetail.BILL_UNIT_CODE=@bill_unit_code		 
		End
	



		If @eq_flag='F'
		Begin	
	     
			select @indirect_cost=TSDFApprovalPrice.cost
			FROM TSDFApproval
			INNER JOIN TSDFApprovalPrice 
			ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id
			WHERE TSDFApproval.TSDF_approval_id = @tsdf_approval_id
			AND TSDFApproval.customer_id = @customer_id
			AND TSDFApproval.company_id = @company_id
			AND TSDFApproval.profit_ctr_id = @profit_ctr_id
			AND TSDFApprovalPrice.record_type = 'D'
			AND TSDFApprovalPrice.bill_unit_code=@bill_unit_code
            
		End
		/*Added By Nagaraj - Ends*/

	    If @eq_flag='T' and @ll_cnt_manifest > 0 
	    Begin	
	      Select @ll_cnt_wdunit=count(*) from WorkorderDetailunit wdu with(nolock)
		                            INNER JOIN workorderdetail wd ON  
									wd.profile_id=@profile_id
									and wd.workorder_ID=@workorder_id_ret
									and wd.company_id=@company_id
									--and wd.sequence_id <> @newsequence_id
									and wd.profit_ctr_ID=@profit_ctr_ID
									and wd.workorder_ID=wdu.workorder_ID
									and wd.company_id=wdu.company_id
									and wd.profit_ctr_ID=wdu.profit_ctr_ID
									and wd.sequence_id=wdu.sequence_id
									and wdu.bill_unit_code=@old_billunitcode   
									and wd.manifest=@manifest
	   
       
        End  

		If @eq_flag='F' and @ll_cnt_manifest > 0
	    Begin			
	      Select @ll_cnt_wdunit=count(*) from WorkorderDetailunit wdu with(nolock)
		                            INNER JOIN workorderdetail wd ON  
									wd.TSDF_approval_id=@TSDF_approval_id
									and wd.workorder_ID=@workorder_id_ret
									and wd.company_id=@company_id
									--and wd.sequence_id <> @newsequence_id
									and wd.profit_ctr_ID=@profit_ctr_ID
									and wd.workorder_ID=wdu.workorder_ID
									and wd.company_id=wdu.company_id
									and wd.profit_ctr_ID=wdu.profit_ctr_ID
									and wd.sequence_id=wdu.sequence_id
									and wdu.bill_unit_code=@old_billunitcode
									and wd.manifest=@manifest
        End  
	   

        If @ll_cnt_wdunit=0
		Begin		
			insert into WorkorderDetailUnit
			(workorder_id,
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
			billing_flag,
			currency_code)
			select	
			@workorder_id_ret,
			@company_id,
			@profit_ctr_id,
			@newsequence_id,
			@manifest_flag,
			@bill_unit_code,
			@bill_unit_code,
			@quantity,
			@indirect_cost,
			@price,
			@quantity*@indirect_cost,
			@quantity*@price,
			@user_code,
			getdate(),
			@user_code,
			getdate(),
			@price_source,
			@billing_flag,
			@currency_code
                                                                                                                        
			if @@error <> 0                                                                                          
			begin     			
			Set @Response = 'Error: Integration failed due to the following reason; could not insert into workorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
			return -1
			end
		End

		if @ll_cnt_wdunit > 0 and @eq_flag='T' 		
		 Begin
		 
		  update  wdu set 
				wdu.bill_unit_code=@bill_unit_code,
				wdu.size=@bill_unit_code,
				wdu.quantity=@Quantity,
				wdu.cost=@indirect_cost, 
				wdu.price=@price,
				wdu.extended_cost=@quantity*@indirect_cost,
				wdu.extended_price=@quantity*@price,
				wdu.modified_by=@user_code,
				wdu.date_modified=getdate(),
				wdu.price_source=@price_source
				From WorkOrderDetailUnit wdu 					
					    INNER JOIN workorderdetail wd ON  
						wd.profile_id=@profile_id
					and wd.workorder_ID=@workorder_id_ret
					and wd.company_id=@company_id
					--and wd.sequence_id <> @newsequence_id
					and wd.profit_ctr_ID=@profit_ctr_ID
					and wd.workorder_ID=wdu.workorder_ID
					and wd.company_id=wdu.company_id
					and wd.profit_ctr_ID=wdu.profit_ctr_ID
					and wd.sequence_id=wdu.sequence_id
					and wdu.bill_unit_code=@old_billunitcode
					and wd.manifest=@manifest
		
		if @bill_rate=0
			begin
				update workorderdetail set bill_rate = @bill_Rate
				where company_id = @company_id and profit_Ctr_id=@profit_Ctr_id and profile_id=@profile_id and workorder_ID=@workorder_id_ret and manifest=@manifest
			End	
		End

         if @ll_cnt_wdunit > 0 and @eq_flag='F' 		
		 Begin
		 
		  update  wdu set 
				wdu.bill_unit_code=@bill_unit_code,
				wdu.size=@bill_unit_code,
				wdu.quantity=@Quantity,
				wdu.cost=@indirect_cost, 
				wdu.price=@price,
				wdu.extended_cost=@quantity*@indirect_cost,
				wdu.extended_price=@quantity*@price,
				wdu.modified_by=@user_code,
				wdu.date_modified=getdate(),
				wdu.price_source=@price_source
				From WorkOrderDetailUnit wdu 					
					 INNER JOIN workorderdetail wd ON  
					wd.TSDF_approval_id=@TSDF_approval_id
					and wd.workorder_ID=@workorder_id_ret
					and wd.company_id=@company_id
					--and wd.sequence_id <> @newsequence_id
					and wd.profit_ctr_ID=@profit_ctr_ID
					and wd.workorder_ID=wdu.workorder_ID
					and wd.company_id=wdu.company_id
					and wd.profit_ctr_ID=wdu.profit_ctr_ID
					and wd.sequence_id=wdu.sequence_id
					and wdu.bill_unit_code=@old_billunitcode
					and wd.manifest=@manifest

			
		if @bill_rate=0
			begin
				update workorderdetail set bill_rate = @bill_Rate
				where company_id = @company_id and profit_Ctr_id=@profit_Ctr_id and TSDF_approval_id=@TSDF_approval_id and workorder_ID=@workorder_id_ret and manifest=@manifest
			End	

			end	
			
      End   

	   

	    If @eq_flag='T' and @ll_cnt_manifest > 0 and @as_map_disposal_line='D'
	    Begin	
	      Select @ll_cnt_wdunit=count(*) from WorkorderDetailunit wdu with(nolock)
		                            INNER JOIN workorderdetail wd ON  
									wd.profile_id=@profile_id
									and wd.workorder_ID=@workorder_id_ret
									and wd.company_id=@company_id
									--and wd.sequence_id <> @newsequence_id
									and wd.profit_ctr_ID=@profit_ctr_ID
									and wd.workorder_ID=wdu.workorder_ID
									and wd.company_id=wdu.company_id
									and wd.profit_ctr_ID=wdu.profit_ctr_ID
									and wd.sequence_id=wdu.sequence_id
									and wdu.bill_unit_code=@old_billunitcode
									and wd.manifest=@manifest
       
        End  

		If @eq_flag='F' and @ll_cnt_manifest > 0 and @as_map_disposal_line='D'
	    Begin		
	      Select @ll_cnt_wdunit=count(*) from WorkorderDetailunit wdu with(nolock)
		                            INNER JOIN workorderdetail wd ON  
									wd.TSDF_approval_id=@TSDF_approval_id
									and wd.workorder_ID=@workorder_id_ret
									and wd.company_id=@company_id
									--and wd.sequence_id <> @newsequence_id
									and wd.profit_ctr_ID=@profit_ctr_ID
									and wd.workorder_ID=wdu.workorder_ID
									and wd.company_id=wdu.company_id
									and wd.profit_ctr_ID=wdu.profit_ctr_ID
									and wd.sequence_id=wdu.sequence_id
									and wdu.bill_unit_code=@old_billunitcode
									and wd.manifest=@manifest
        End  
	  
		if @ll_cnt_wdunit > 0 and @as_map_disposal_line='D' and @eq_flag='T' 
	    begin
		
		update  wdu set 
				wdu.quantity=@quantity,
				wdu.modified_by=@user_code,
				wdu.date_modified=getdate()
				From WorkOrderDetailUnit wdu 					
					    INNER JOIN workorderdetail wd ON  
					 wd.profile_id=@profile_id
					and wd.workorder_ID=@workorder_id_ret
					and wd.company_id=@company_id
					--and wd.sequence_id <> @newsequence_id
					and wd.profit_ctr_ID=@profit_ctr_ID
					and wd.workorder_ID=wdu.workorder_ID
					and wd.company_id=wdu.company_id
					and wd.profit_ctr_ID=wdu.profit_ctr_ID
					and wd.sequence_id=wdu.sequence_id
					and wdu.bill_unit_code=@old_billunitcode
					and wd.manifest=@manifest

						
		if @bill_rate=0
			begin
				update workorderdetail set bill_rate = @bill_Rate
				where company_id = @company_id and profit_Ctr_id=@profit_Ctr_id and profile_id=@profile_id and workorder_ID=@workorder_id_ret and manifest=@manifest
			End	
		end	

		if @ll_cnt_wdunit > 0 and @as_map_disposal_line='D' and @eq_flag='F' 
	    begin
		
		update  wdu set 
				wdu.quantity=@quantity,
				wdu.modified_by=@user_code,
				wdu.date_modified=getdate()
				From WorkOrderDetailUnit wdu 					
					    INNER JOIN workorderdetail wd ON  
						wd.TSDF_approval_id=@TSDF_approval_id
					and wd.workorder_ID=@workorder_id_ret
					and wd.company_id=@company_id
					--and wd.sequence_id <> @newsequence_id
					and wd.profit_ctr_ID=@profit_ctr_ID
					and wd.workorder_ID=wdu.workorder_ID
					and wd.company_id=wdu.company_id
					and wd.profit_ctr_ID=wdu.profit_ctr_ID
					and wd.sequence_id=wdu.sequence_id
					and wdu.bill_unit_code=@old_billunitcode
					and wd.manifest=@manifest

		
			
		if @bill_rate=0
			begin
				update workorderdetail set bill_rate = @bill_Rate
				where company_id = @company_id and profit_Ctr_id=@profit_Ctr_id and TSDF_approval_id=@TSDF_approval_id and workorder_ID=@workorder_id_ret and manifest=@manifest
			End	

		end	



		IF  @as_map_disposal_line='D' and @EQ_FLAG='F' and @ll_cnt_wdunit=0
		Begin
			insert into WorkorderDetailUnit
			(cost,
			 Price,
			bill_unit_code,
			size,			
			workorder_id,
			company_id,
			profit_ctr_id,
			sequence_id,
			manifest_flag,
			quantity,
			--extended_cost,
			extended_price, 
			added_by,
			date_added,
			modified_by,
			date_modified,
			price_source,
			billing_flag,
			currency_code
			)
			SELECT TSDFApprovalPrice.cost,
			TSDFApprovalPrice.price, 
			TSDFApprovalPrice.bill_unit_code,
			TSDFApprovalPrice.bill_unit_code,			
			@workorder_id_ret,
			@company_id,
			@profit_ctr_id,
			@newsequence_id,
			@manifest_flag,
			@quantity,
			--@quantity*cost,
			@quantity*price, 
			@user_code,
			getdate(),
			@user_code,
			getdate(),
			@price_source,
			@billing_flag,
			@currency_code
			FROM TSDFApproval
			INNER JOIN TSDFApprovalPrice 
			ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id
			WHERE TSDFApproval.TSDF_approval_id = @tsdf_approval_id
			AND TSDFApproval.customer_id = @customer_id
			AND TSDFApproval.company_id = @company_id
			AND TSDFApproval.profit_ctr_id = @profit_ctr_id
			AND TSDFApprovalPrice.record_type = 'D'
			AND TSDFApprovalPrice.bill_unit_code=@bill_unit_code
                                                                                                                        
			if @@error <> 0                                                                                          
			begin
			
			Set @Response = 'Error: Integration failed due to the following reason; could not insert into workorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
			return -1
			End
		End

		
		IF @as_map_disposal_line= 'D' AND @EQ_FLAG='T' and  @ll_cnt_wdunit=0
		BEGIN		
		SELECT @BROKER_FLAG=broker_flag FROM PROFILE WHERE profile_id = @profile_id
                                                                             
			IF @BROKER_FLAG = 'O'
			BEGIN			
				insert into WorkorderDetailUnit
				(cost,
				price,
				bill_unit_code,
				size,				
				workorder_id,
				company_id,
				profit_ctr_id,
				sequence_id,
				manifest_flag,
				quantity,
				--extended_cost,
				extended_price,
				added_by,
				date_added,
				modified_by,
				date_modified,
				price_source,
				billing_flag,
				currency_code
				)
				select ISNULL(ProfileQuoteDetail.price, 0)+ISNULL(ProfileQuoteDetail.surcharge_price, 0),
				ISNULL(ProfileQuoteDetail.orig_customer_price, 0),
				ProfileQuoteDetail.bill_unit_code,ProfileQuoteDetail.bill_unit_code,				
				@workorder_id_ret,
				@company_id,
				@profit_ctr_id,
				@newsequence_id,
				@manifest_flag,
				@quantity,
				--@quantity*@cost,
				@quantity*@price,
				@user_code,
				getdate(),
				@user_code,
				getdate(),
				@price_source,
				@billing_flag,
				@currency_code
				FROM Profile
				INNER JOIN ProfileQuoteDetail 
				ON Profile.profile_id = ProfileQuoteDetail.profile_id
				WHERE Profile.profile_id = @PROFILE_ID
				AND Profile.orig_customer_id = @CUSTOMER_ID
				AND ProfileQuoteDetail.company_id = @EQ_COMPANY
				AND ProfileQuoteDetail.profit_ctr_id = @EQ_PROFIT_CTR
				AND ProfileQuoteDetail.record_type = 'D'
                AND ProfileQuoteDetail.bill_unit_code=@bill_unit_code
				
				if @@error <> 0                                                                                        
				begin				   
					Set @Response = 'Error: Integration failed due to the following reason; could not insert into workorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
					return -1
				end
			End
			IF @BROKER_FLAG <> 'O' 
			BEGIN			
				insert into WorkorderDetailUnit
				(cost,
				price,
				bill_unit_code,
				size,		
				workorder_id,
				company_id,
				profit_ctr_id,
				sequence_id,
				manifest_flag,
				quantity,
				--extended_cost,
				extended_price,
				added_by,
				date_added,
				modified_by,
				date_modified,
				price_source,
				billing_flag,
				currency_code
				)
				select ISNULL(ProfileQuoteDetail.price, 0)+ISNULL(ProfileQuoteDetail.surcharge_price, 0),
				0,
				ProfileQuoteDetail.bill_unit_code,ProfileQuoteDetail.bill_unit_code,				
				@workorder_id_ret,
				@company_id,
				@profit_ctr_id,
				@newsequence_id,
				@manifest_flag,
				@quantity,
				--@quantity*@cost,
				@quantity*@price,
				@user_code,
				getdate(),
				@user_code,
				getdate(),
				@price_source,
				@billing_flag,
				@currency_code
				FROM Profile
				INNER JOIN ProfileQuoteDetail 
				ON Profile.profile_id = ProfileQuoteDetail.profile_id
				WHERE Profile.profile_id = @PROFILE_ID
			--	AND Profile.orig_customer_id = @CUSTOMER_ID
				AND ProfileQuoteDetail.company_id = @EQ_COMPANY
				AND ProfileQuoteDetail.profit_ctr_id = @EQ_PROFIT_CTR
				AND ProfileQuoteDetail.record_type = 'D'
				AND ProfileQuoteDetail.bill_unit_code=@bill_unit_code

				if @@error <> 0                                                                                        
				begin				
				Set @Response = 'Error: Integration failed due to the following reason; could not insert into workorderdetailunit table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
				 return -1
				End
			End
		End
		
				insert into workorderaudit(
                                                   company_id,
												   profit_ctr_id,
												   workorder_id,
												   resource_type,
												   sequence_id,
												   table_name,
												   column_name,
												   before_value,
												   after_value,
												   audit_reference,
												   modified_by,
												   date_modified)
											       Select
                                                    @company_id,
													@profit_ctr_id,
													@workorder_id_ret,
													'',
													0,
													'WorkorderDetail',
													'ALL',
													'(no record)',
													'(new record added)',
													'Work Order updated via Advanced Disposal integration from Salesforce. Salesforce Billing Package ' +isnull(@salesforce_invoice_csid,''),
													@user_code,
													getdate()


								if @@error <> 0 						
								begin								
								 Set @Response = 'Error: Integration failed due to the following reason; could not update SFSworkorderaudit table;' + isnull(ERROR_MESSAGE(),'')
   								 return -1
								end



End
Return 0

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_wod_Insert_disposal] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_wod_Insert_disposal] TO svc_CORAppUser

GO
