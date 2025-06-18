USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_wod_Insert]    Script Date: 5/7/2025 7:39:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO


CREATE OR ALTER       PROCEDURE [dbo].[sp_sfdc_wod_Insert] @response varchar(4000) OUTPUT  
AS  
  
/*    
Description:   
  
Workorder detail Line insert (This procedure called from sp_sfdc_workorder_insert)  
Created By Venu -- 18/Oct/2024  
Rally # US129733  - New Design To handle the workorder in Single JSON  
Rally #US133849/TA479509 -- Mapped pricesource when the  parameter AsMapDisposalLine is indirect.  
Rally # DE36664 -- Added Salesforce invoice csid parameter to the workorderdisposalinsert records  
Rally # DE36390  - Added logic to sync the sequence id consistent in Workoderdetail and workorderdetailunit table  
Rally # US134603  - Added Profile id for disposal line  
Rally # US136352  - Added Manifest_state in parameter
Rally # US126965 / TA492085 -- Modified the manifest_handling_code, ERG_NUMBER, ERG_SUFFIX values to the @Profile_manifest_handling_code,@Profile_ERG_number,@Profile_ERG_suffix.
Rally # US136383  - Modified the bill_rate logic
Rally # US135227 -- updation of user_code as Tracking_contact for existing workordertracking row.
Rally # US138836 -- Added bill_rate parameter in the sp_sfdc_wod_Insert_disposal stored procedure call.
Rally# DE38851 -- Added (@manifest) in the where clause in the workorderdetailunit select query and declared onetime @manifest=trim(manifest)
US#151982  - 04/29/2025 Removed company condition to derive cost qty
*/  
  
DECLARE     
  @workorder_ID_ret int,  
  @newsequence_id int,  
  @currency_code char(3) = 'USD',  
  @group_instance_id int =0,    
  @resource_assigned varchar(10),  
  @ll_count_rec int,    
  @priced_flag smallint = 1,  
  @cost_class varchar(10)=Null,    
  @user_code varchar(10)='N/A',   
  @resource_uid int,  
  @cost_quantity float,  
  @manifest_state char(1),    
  @manifest_flag char(1)='T',  
  @EQ_FLAG char(1),  
  @profile_id int,  
  @profile_company_id int,  
  @profile_prft_ctr_id int,  
  @tsdf_approval_id int,   
  @ll_tsdf_approval_cnt int,  
  @eq_profit_ctr int,  
  @eq_company int,  
  @customer_id int,  
  @ll_ret_disposal int,   
  @Profile_DOT_shipping_name varchar(255),   
  @Profile_manifest_hand_instruct Varchar(1000),  
  @TreatmentDetail_management_code char(4),   
  @Profile_reportable_quantity_flag char(1),   
  @Profile_RQ_reason varchar(50),  
  @Profile_hazmat char(1),   
  @Profile_subsidiary_haz_mat_class varchar(15),   
  @Profile_UN_NA_flag char(2),  
  @Profile_package_group varchar(3),   
  @Profile_manifest_handling_code varchar(15),   
  @Profile_manifest_wt_vol_unit varchar(15),   
  @Profile_UN_NA_number int,   
  @Profile_ERG_number int,   
  @Profile_ERG_suffix char(2),  
  @profile_manifest_dot_sp_number varchar(20),  
  @Generator_EPA_ID varchar(15),  
  @Profile_manifest_container_code varchar(15),  
  @Profile_hazmat_class VARCHAR(15),  
  @TSDFApproval_waste_stream varchar(10),  
  @TSDFApprovalPrice_bill_rate float,  
  @Profile_manifest_waste_desc varchar(50),   
  @manifest_line int,   
  @disposal_response varchar(2000),  
  @manifest varchar(15),  
 @salesforce_bundle_id varchar(10),  
 @resource_type char(1),        
 @description varchar(100),  
 @TSDF_code varchar(15),        
 @extended_price money,  
 @extended_cost money,  
 @salesforce_invoice_line_id varchar(25),  
 @salesforce_task_name varchar(80) ,  
 @bill_rate float ,    
 @price_source varchar(40) ,  
 @print_on_invoice_flag char(1) ,  
 @quantity_used float ,  
 @quantity float ,  
 @resource_class_code varchar(20) ,  
 @salesforce_resource_CSID varchar(18) ,  
 @salesforce_resourceclass_CSID varchar(18) ,  
 @cost money ,  
 @bill_unit_code varchar(4) ,   
 @billing_sequence_id decimal(10,3),  
 @company_id int,        
 @date_service datetime ,         
 @prevailing_wage_code varchar(20) ,   
 @price money ,  
 @price_class varchar(10) ,        
 @profit_ctr_ID int,               
 @salesforce_invoice_csid varchar(18) ,             
 @source_system varchar(100)='Sales Force',  
 @employee_id varchar(20),  
 @sales_tax_line_flag char(1)='F',  
 @description_2 varchar(100) ,  
 @resource_company_id int ,  
 @generator_sign_date datetime ,  
 @generator_sign_name VARCHAR(255) ,  
 @TSDF_approval_code varchar(40),  
 @as_map_disposal_line char(1)='I',  
 @salesforce_so_csid varchar(18),  
 @as_woh_disposal_flag char(1)='F',    
 @start_date datetime ,  
 @end_date datetime ,  
 @index int=0,  
 @det_count int=0,   
 @workorder_id_sf_send int,  
 @ll_wo_cnt int,  
 @ls_map_disposal_to_diff_workorder char(1),  
 @ll_cnt_wdunit int=0,  
 @ll_cnt_manifest int=0,  
 @old_billunitcode varchar(4),  
    @AsMapDisposalLine char(1),  
 @ll_cnt_wod int  
    
   
  
  
  
Set @response = 'WorkorderDetail Integration Successful'  
  
Select @det_count = count(*) from #sf_detail  


Begin Try  
Declare wod_line CURSOR fast_forward for  
          Select  
          Manifest,  
          SalesforceBundleId,  
          ResourceType,  
          Description,  
          TSDFCode,  
          ExtendedPrice,  
          ExtendedCost,  
          SalesforceInvoiceLineId,  
          SfTaskName,  
          BillRate,  
          PriceSource,  
          PrintOnInvoiceFlag,  
          QuantityUsed,  
          Quantity,  
          ResourceClassCode,  
          SalesforceResourceCsId,  
          SalesforceResourceClassCSID,  
          Cost,  
          BillUnitCode          ,  
          BillingSequenceId,  
          CompanyId,  
          DateService,  
          PrevailingWageCode,  
          Price,  
          PriceClass,  
          ProfitCenterId,  
          SalesforceInvoiceCsid,  
          Employee_Id,  
          SalesTaxLineFlag,  
          Description2,  
          ResourceCompanyId,  
          GeneratorSignDate,  
          GeneratorSignName,  
          TsdfApprovalCode,  
          AsMapDisposalLine,  
          SalesforceSoCsid,  
          AsWohDisposalFlag,  
          start_date,  
          end_date,  
          workorder_id,  
          old_billunitcode,  
          Profileid,  
          Manifest_state  
          From #sf_detail  
Open wod_line   
fetch next from wod_line into  @manifest,  
          @salesforce_bundle_id,  
          @resource_type,  
          @description,  
          @TSDF_code,  
          @extended_price,  
          @extended_cost,  
          @salesforce_invoice_line_id,  
          @salesforce_task_name,  
          @bill_rate,  
          @price_source,  
          @print_on_invoice_flag,  
          @quantity_used,  
          @quantity,  
          @resource_class_code,  
          @salesforce_resource_CSID,  
          @salesforce_resourceclass_CSID,  
          @cost,  
          @bill_unit_code,  
          @billing_sequence_id,  
          @company_id,  
          @date_service,  
          @prevailing_wage_code,  
          @price,  
          @price_class,  
          @profit_ctr_ID,  
          @salesforce_invoice_csid,  
          @employee_id,  
          @sales_tax_line_flag,  
          @description_2,  
          @resource_company_id,  
          @generator_sign_date,  
          @generator_sign_name,  
          @TSDF_approval_code,  
          @as_map_disposal_line,  
          @salesforce_so_csid,  
          @as_woh_disposal_flag,  
          @start_date,  
          @end_date,  
          @workorder_id_sf_send,  
          @old_billunitcode,  
          @profile_id,  
          @manifest_state  
          
            
  
While @@fetch_status=0  
BEGIN  
      
  
  
    Set @index=@index+1  
   
  
 Set @ll_cnt_wdunit = 0  
 Set @ll_cnt_manifest = 0  
 Set @ll_cnt_wod = 0  
  
 Set @ls_map_disposal_to_diff_workorder='F'  
  If len (@employee_id) > 0   
  Begin  
  EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output   
  End  
  
 --Check if Disposal request id for different workorder  

set @manifest=trim(@manifest)

 If @workorder_id_sf_send is not null and @as_woh_disposal_flag='T'  
 Begin  
   Select @ll_wo_cnt=count(*) from workorderheader with(nolock) where workorder_ID=@workorder_id_sf_send and company_id=@company_id and profit_ctr_ID=@profit_ctr_id and workorder_status = 'N'  
   If  @ll_wo_cnt > 0   
     Set @ls_map_disposal_to_diff_workorder='T'  
 End  
   
 If @sales_tax_line_flag = 'T'   
 Begin  
   Set @salesforce_invoice_line_id =@salesforce_invoice_csid   
    End  
   
 Select @workorder_ID_ret = workorder_id,@customer_id=customer_id from workorderheader with(nolock) where salesforce_invoice_CSID=@salesforce_invoice_csid and company_id=@company_id and profit_ctr_ID=@profit_ctr_ID  
  
 If (@workorder_ID_ret is null or @workorder_ID_ret='') and @as_woh_disposal_flag='T' and @salesforce_so_csid is not null  
 Begin  
   Select @workorder_ID_ret = workorder_id,@customer_id=customer_id from workorderheader with(nolock) where (salesforce_invoice_CSID=@salesforce_invoice_csid or salesforce_invoice_CSID=@salesforce_so_csid) and company_id=@company_id and profit_ctr_ID=@profit_ctr_ID  
 End  
   
  
 If @ls_map_disposal_to_diff_workorder='T'  --Override the Workorder  
 Begin  
  Set @workorder_ID_ret=@workorder_id_sf_send  
 End  
   
 Select @resource_assigned = resource_code,@resource_uid = resource_uid from dbo.resource   
                     where salesforce_resource_csid=@salesforce_resource_csid  
                     and company_id=@resource_company_id   
      
  If @resource_type = 'S' OR @resource_type = 'O'  OR @resource_type = 'D'  
  Begin  
  set @cost_class = @resource_class_code  
  End  
  
  If @resource_type = 'E' OR @resource_type = 'L'  
  Begin  
  select @cost_class = resource_class_code from ResourceXResourceClass  
               where resource_code = @resource_assigned  
               and resource_company_id = @resource_company_id  
               and resource_class_company_id = @resource_company_id                  
               and bill_unit_code = @bill_unit_code  
  End  
  
  IF (@resource_type ='L' OR @resource_type ='E') /*and (@company_id=72 or @company_id=71 or @company_id=63 or @company_id=64)  */ --Commented for US#151982
  Begin  
   Set @cost_quantity= cast(@extEnded_cost as float) / cast (@cost as float)
  End  
  
  Select @newsequence_id =  isnull(max(sequence_id),0) + 1  from WorkOrderdetail with(nolock) where workorder_id=@workorder_ID_ret   
                                                                                         and company_id=@company_id   
                       and profit_ctr_ID=@profit_ctr_ID   
                       and resource_type=@resource_type  
      
  Select @billing_sequence_id =  isnull(max(billing_sequence_id),0) + 1  from WorkOrderdetail with(nolock) where workorder_id=@workorder_ID_ret   
                           and company_id=@company_id   
                           and profit_ctr_ID=@profit_ctr_ID   
                           and resource_type=@resource_type  
 If @resource_type='D' and @as_woh_disposal_flag='T'  
 Begin  
    Select @manifest_line =  isnull(max(MANIFEST_line),0) + 1 from WorkOrderdetail with(nolock) where workorder_id = @workorder_ID_ret   
                         and resource_type=@resource_type  
                         and manifest=@manifest  
       Select @EQ_FLAG=EQ_FLAG,@eq_company=eq_company,@eq_profit_ctr=eq_profit_ctr FROM TSDF WHERE TSDF_CODE=@TSDF_CODE AND TSDF_STATUS='A'  
    If @EQ_FLAG is null or @EQ_FLAG=''  
    Begin  
   Set @EQ_FLAG='F'  
    End  
     
    If @EQ_FLAG='T'  
    Begin  
                     
        select @profile_company_id=company_id,@profile_prft_ctr_id=profit_ctr_id,          
        @price_source=case when @as_map_disposal_line = 'D' THEN @TSDF_approval_code else @price_source END   
                       from profilequoteapproval  where approval_code=@TSDF_approval_code  
                                and company_id=@EQ_COMPANY   
                                and profit_ctr_id=@EQ_PROFIT_CTR   
                                and status='A'  
                                and profile_id=@profile_id   
                                       
  
  
      SELECT @profile_dot_shipping_name=Profile.DOT_shipping_name,   
      @Profile_manifest_hand_instruct=Profile.manifest_hand_instruct,   
      @Profile_manifest_waste_desc=CASE WHEN Profile.manifest_waste_desc IS NULL THEN Profile.approval_desc   
              ELSE Profile.manifest_waste_desc END,  
      @TreatmentDetail_management_code=TreatmentDetail.management_code,   
      @Profile_reportable_quantity_flag=Profile.reportable_quantity_flag,  
      @Profile_RQ_reason=Profile.RQ_reason,  
      @Profile_hazmat=Profile.hazmat,   
      @Profile_hazmat_class=Profile.hazmat_class,   
      @Profile_subsidiary_haz_mat_class=Profile.subsidiary_haz_mat_class,   
      @Profile_UN_NA_flag=Profile.UN_NA_flag,  
      @Profile_package_group=Profile.package_group,   
      @Profile_manifest_handling_code=Profile.manifest_handling_code,   
      @Profile_manifest_wt_vol_unit=Profile.manifest_wt_vol_unit,  
      @Profile_UN_NA_number=Profile.UN_NA_number,   
      @Profile_ERG_number=Profile.ERG_number,   
      @Profile_ERG_suffix=Profile.ERG_suffix,  
      @profile_manifest_dot_sp_number=profile.manifest_dot_sp_number,  
      @description=Profile.approval_desc,  
      @Profile_manifest_container_code=Profile.manifest_container_code  
      FROM Profile (nolock)  
      JOIN ProfileQuoteApproval (nolock) ON Profile.profile_id = ProfileQuoteApproval.profile_id  
      JOIN TreatmentDetail (nolock) ON ProfileQuoteApproval.treatment_id = TreatmentDetail.treatment_id  
      AND ProfileQuoteApproval.company_id = TreatmentDetail.company_id  
      AND ProfileQuoteApproval.profit_ctr_id = TreatmentDetail.profit_ctr_id  
      Join Generator (nolock) on profile.generator_id = generator.generator_id  
      WHERE Profile.profile_id = @PROFILE_ID  
      AND ProfileQuoteApproval.approval_code = @TSDF_approval_code  
      AND ProfileQuoteApproval.company_id = @eq_company  
      AND ProfileQuoteApproval.profit_ctr_id = @eq_profit_ctr  
      AND ProfileQuoteApproval.status='A'  
    End  
  
    If @EQ_FLAG='F'  
    Begin  
  
              select @tsdf_approval_id=@profile_id -- Always tsdf approval id and profile ID are same in the table hence assigning the profile ID the variable  
     select @price_source=CASE WHEN @as_map_disposal_line = 'D' THEN 'TDA - ' + TRIM(STR(@tsdf_approval_id)) else  @price_source END  
                           /*from tsdfapproval   
                                                                                                    where tsdf_code=@tsdf_code  
                             and TSDF_approval_code=@TSDF_approval_code  
                             and company_id=@company_id   
                             and profit_ctr_id=@profit_ctr_ID   
                             and TSDF_approval_status='A'  
                             and tsdf_approval_id=@profile_id --nagaraj m  
                            */  
  
     SELECT @profile_dot_shipping_name=TSDFApproval.DOT_shipping_name,   
     @Profile_manifest_hand_instruct=TSDFApproval.hand_instruct,   
     @Profile_manifest_waste_desc=TSDFApproval.waste_desc,  
     @TreatmentDetail_management_code=TSDFApproval.management_code,  
     @Profile_reportable_quantity_flag=TSDFApproval.reportable_quantity_flag,   
     @Profile_RQ_reason=TSDFApproval.RQ_reason,  
     @Profile_hazmat=TSDFApproval.hazmat,   
     @Profile_hazmat_class=TSDFApproval.hazmat_class,   
     @Profile_subsidiary_haz_mat_class=TSDFApproval.subsidiary_haz_mat_class,   
     @Profile_UN_NA_flag=TSDFApproval.UN_NA_flag,  
     @Profile_package_group=TSDFApproval.package_group,   
     @Profile_manifest_handling_code=TSDFApproval.manifest_handling_code,   
     @Profile_manifest_wt_vol_unit=TSDFApproval.manifest_wt_vol_unit,  
     @Profile_UN_NA_number=TSDFApproval.UN_NA_number,   
     @Profile_ERG_number=TSDFApproval.ERG_number,   
     @Profile_ERG_suffix=TSDFApproval.ERG_suffix,   
     @profile_manifest_dot_sp_number=TSDFApproval.manifest_dot_sp_number,  
     @TSDFApproval_waste_stream=TSDFApproval.waste_stream,  
     @description=TSDFApproval.waste_desc,  
     @TSDFApprovalPrice_bill_rate=TSDFApprovalPrice.bill_rate,  
     @Profile_manifest_container_code=TSDFApproval.manifest_container_code       
     FROM TSDFApproval (nolock)  
     INNER JOIN TSDFApprovalPrice (nolock) ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id  
     AND TSDFApproval.bill_unit_code = TSDFApprovalPrice.bill_unit_code  
     WHERE TSDFApproval.tsdf_approval_id = @tsdf_approval_id  
     and TSDF_approval_code=@TSDF_approval_code  
     and TSDFApproval.TSDF_approval_status='A'  
    End  
    End  
  
 IF @resource_type='D'  
 Begin  
 Select @ll_cnt_manifest=COUNT(*) FROM  WorkorderManifest with(nolock) WHERE  
                WORKORDER_ID=@workorder_id_ret  
                AND MANIFEST=@MANIFEST
                and company_id=@company_id  
                and profit_ctr_ID=@profit_ctr_ID    
  
 If @eq_flag='T'  and @ll_cnt_manifest > 0   
     Begin  
    /*Modified by Venu to fix DE36390 -- Start*/  
       Select @ll_cnt_wdunit=count(*) from WorkorderDetailunit wdu with(nolock)  
                              INNER JOIN workorderdetail wd ON    
         wd.profile_id=@profile_id  
         and wd.workorder_ID=@workorder_id_ret  
         and wd.company_id=@company_id           
         and wd.profit_ctr_ID=@profit_ctr_ID  
         and wd.workorder_ID=wdu.workorder_ID  
         and wd.company_id=wdu.company_id  
         and wd.profit_ctr_ID=wdu.profit_ctr_ID  
         and wd.sequence_id=wdu.sequence_id   
		 and wd.manifest=@manifest --Venu
  
         Select @ll_cnt_wod=count(*) from WorkorderDetail with(nolock)                                
         Where profile_id=@profile_id  
         and workorder_ID=@workorder_id_ret  
         and company_id=@company_id           
         and profit_ctr_ID=@profit_ctr_ID  
         and MANIFEST=@MANIFEST  
               
  
    If @ll_cnt_wod > 0  
    Begin      
     Select @newsequence_id = isnull(max(sequence_id),0), @billing_sequence_id=isnull(max(billing_sequence_id),0)    from WorkorderDetail with(nolock)                                
                                  Where profile_id=@profile_id  
                                  and workorder_ID=@workorder_id_ret  
                                  and company_id=@company_id           
                                  and profit_ctr_ID=@profit_ctr_ID  
                                  and MANIFEST=@MANIFEST
    End   
        
        End    
  
 If @eq_flag='F'  and @ll_cnt_manifest > 0   
     Begin  
    /*Modified by Venu to fix DE36390 -- Start*/  
  
       Select @ll_cnt_wdunit=count(*) from WorkorderDetailunit wdu with(nolock)  
                              INNER JOIN workorderdetail wd ON    
         wd.TSDF_approval_id=@TSDF_approval_id  
         and wd.workorder_ID=@workorder_id_ret  
         and wd.company_id=@company_id           
         and wd.profit_ctr_ID=@profit_ctr_ID  
         and wd.workorder_ID=wdu.workorder_ID  
         and wd.company_id=wdu.company_id  
         and wd.profit_ctr_ID=wdu.profit_ctr_ID  
         and wd.sequence_id=wdu.sequence_id    
		 and wd.manifest=@manifest
  
    Select @ll_cnt_wod=count(*) from WorkorderDetail with(nolock)                                
           Where TSDF_approval_id=@TSDF_approval_id  
           and workorder_ID=@workorder_id_ret  
           and company_id=@company_id           
           and profit_ctr_ID=@profit_ctr_ID  
           and MANIFEST=@MANIFEST  
    If @ll_cnt_wod > 0  
    Begin     
     Select @newsequence_id = isnull(max(sequence_id),0), @billing_sequence_id=isnull(max(billing_sequence_id),0) from WorkorderDetail with(nolock)                                
                                  Where TSDF_approval_id=@TSDF_approval_id  
                                  and workorder_ID=@workorder_id_ret  
                                  and company_id=@company_id           
                                  and profit_ctr_ID=@profit_ctr_ID  
                                  and MANIFEST=@MANIFEST
    End   
  
        End      
    
    End     
  
  
    If  @ll_cnt_wod = 0   
 Begin  
 Insert into dbo.workorderdetail  
      (manifest,  
      salesforce_bundle_id,  
      resource_type,  
      added_by,  
      description,  
      TSDF_code,  
      TSDF_approval_code,  
      modified_by,  
      extEnded_price,  
      extEnded_cost,  
      resource_assigned,  
      salesforce_task_name,  
      bill_rate,  
      price_source,  
      print_on_invoice_flag,  
      quantity_used,  
      quantity,       
      resource_class_code,  
      cost,  
      bill_unit_code,  
      billing_sequence_id,  
      company_id,  
      currency_code,  
      date_added,  
      date_modified,  
      date_service,  
      prevailing_wage_code,       
      price,   
      price_class,  
      profit_ctr_ID,  
      sequence_id,  
      group_instance_id,  
      priced_flag,  
      workorder_id,  
      salesforce_invoice_line_id,  
      cost_class,  
      description_2,  
                        resource_uid,  
      cost_quantity,  
      profile_id,  
      profile_company_id,  
      profile_profit_ctr_id,  
      tsdf_approval_id,  
      dot_shipping_name,  
      manifest_hand_instruct,  
      manifest_waste_desc,  
      management_code,  
      reportable_quantity_flag,  
      RQ_reason,  
      hazmat,  
      hazmat_class,  
      subsidiary_haz_mat_class,  
      UN_NA_flag,  
      package_group,  
      ERG_NUMBER,  
      ERG_SUFFIX,  
      manifest_handling_code,  
      manifest_wt_vol_unit,  
      UN_NA_number,  
      manifest_dot_sp_number,  
      container_code,  
      waste_stream,  
      manifest_page_num,  
      manifest_line  
      )  
      VALUES  
      (  
      CASE WHEN @resource_type='D' THEN NULLIF(upper(@manifest),'')  
      ELSE NULL  
      END,  
      @salesforce_bundle_id,  
      @resource_type,  
      @user_code,  
      @description,  
      CASE WHEN @RESOURCE_TYPE='D' THEN @TSDF_code  
      ELSE NULL  
      END,  
      CASE WHEN @RESOURCE_TYPE='D' THEN @TSDF_approval_code  
      ELSE NULL  
      END,  
      @user_code,  
      CASE WHEN @RESOURCE_TYPE <> 'D'THEN @extEnded_price  
      ELSE NULL   
      END,  
      CASE WHEN @RESOURCE_TYPE <> 'D'THEN @extEnded_cost  
      ELSE NULL   
      END,  
      CASE WHEN @resource_type <>'D' then @resource_assigned  
      ELSE NULL  
      END,  
      @salesforce_task_name,  
      /*case when @resource_type ='D' and @eq_flag='T' then -1  
      when @resource_type ='D' and @eq_flag='F' then 1  
      ELSE @bill_rate 
      END*/ 
	  @bill_rate,  
      CASE WHEN @RESOURCE_TYPE <> 'D'then @price_source  
      ELSE NULL   
      END,      
      @print_on_invoice_flag,  
      CASE WHEN @RESOURCE_TYPE <> 'D'then @quantity_used  
      ELSE NULL   
      END,  
      CASE WHEN @RESOURCE_TYPE <> 'D'then @quantity  
      ELSE NULL   
      END,  
      case when @resource_type ='D' then null  
      else @resource_class_code  
      end,  
      case when @resource_type <> 'D' then @cost  
      else NULL  
      end,  
      case when @resource_type <>'D' then @bill_unit_code  
      else NULL  
      end,  
      @billing_sequence_id,  
      @company_id,  
      @currency_code,  
      getdate(),  
      getdate(),  
      @date_service,       
      @prevailing_wage_code,       
      case when @resource_type <>'D' then @price  
      else NULL  
      end,  
      case when @resource_type <>'D' then @price_class  
      else NULL  
      end,  
      @profit_ctr_ID,  
      @newsequence_id,  
      case when @resource_type ='D' then NULL ELSE @group_instance_id END,       
      @priced_flag,  
      @workorder_id_ret,  
      @salesforce_invoice_line_id,        
      case when @resource_type ='D' then NULL  ELSE @cost_class end,  
      @description_2,  
                        @resource_uid,  
      case when @resource_type <>'D' then @cost_quantity  
      else NULL  
      end,  
      @profile_id,  
      @profile_company_id,  
      @profile_prft_ctr_id,  
      @tsdf_approval_id,  
      @profile_dot_shipping_name,  
      @Profile_manifest_hand_instruct,  
      @Profile_manifest_waste_desc,  
      @TreatmentDetail_management_code,  
      @Profile_reportable_quantity_flag,  
      @Profile_RQ_reason,  
      @Profile_hazmat,  
      @Profile_hazmat_class,  
      @Profile_subsidiary_haz_mat_class,  
      @Profile_UN_NA_flag,  
      @Profile_package_group,  
      @Profile_ERG_number,  
      @Profile_ERG_suffix,  
      @Profile_manifest_handling_code,  
      @Profile_manifest_wt_vol_unit,  
      @Profile_UN_NA_number,  
      @profile_manifest_dot_sp_number,  
      @Profile_manifest_container_code,  
      @TSDFApproval_waste_stream, 
      case when @resource_type ='D' then 1  
      else NULL  
      end,  
      case when @resource_type ='D' then @manifest_line  
      else NULL  
      end  
      )  
        
        
      if @@error <> 0         
      begin        
      Set @Response = 'Error: Integration failed due to the following reason; could not insert into workorderdetail table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')  
          return -1  
      end  
                End  
  
      If  @ll_cnt_wdunit > 0   
      Begin  
       Set @response = @response + char(13) + char(10) + '(Disposal Line updated) for the line ID '+@salesforce_invoice_line_id  
      End  
  
      If @resource_type='D' and @as_woh_disposal_flag='T'  
         begin  
       Exec @ll_ret_disposal=sp_sfdc_wod_Insert_disposal @workorder_id_ret,@newsequence_id,@manifest,@manifest_flag,@manifest_state,@eq_flag,@tsdf_approval_id,@profile_id,@customer_id,  
       @extended_price,@extended_cost,@quantity,@cost,@price,@bill_unit_code,@company_id,@profit_ctr_ID, @eq_company,@eq_profit_ctr,  
       @as_map_disposal_line,@as_woh_disposal_flag,@user_code,@price_source,@currency_code,@old_billunitcode,@salesforce_invoice_csid,@bill_rate,
       @disposal_response  
        
       If @ll_ret_disposal < 0 and @@error <> 0  
        Begin  
         Set @response=@disposal_response  
         Return -1  
                             End  
      end    
        
  
      If @salesforce_so_csid is not null and  @salesforce_so_csid <> '' and @as_woh_disposal_flag='T' and @det_count=@index  
      begin             
        
        update  workorderheader set salesforce_invoice_csid=@salesforce_invoice_csid,start_date=@start_date,end_date=@end_date,  
               date_modified=getdate(),modified_by=@user_code  
               where (salesforce_invoice_csid=@salesforce_so_csid or salesforce_invoice_csid=@salesforce_invoice_csid)  
                       and salesforce_so_csid=@salesforce_so_csid  
                 and workorder_id=@workorder_id_ret                      
                 and company_id=@company_id  
                 and profit_ctr_ID=@profit_ctr_ID --During waste Disposal if SF send mutiple lines then this update will trigger at last line  (This is already taken care in workorderheader SP,however if SF send detail JSON alone then this its required   

			update workordertracking set tracking_contact=@user_code  where workorder_id=@workorder_id_ret and company_id=@company_id  and profit_ctr_ID=@profit_ctr_ID           
         
      End    
  
fetch next from wod_line into          @manifest,  
          @salesforce_bundle_id,  
          @resource_type,  
          @description,  
          @TSDF_code,  
          @extended_price,  
          @extended_cost,  
          @salesforce_invoice_line_id,  
          @salesforce_task_name,  
          @bill_rate,  
          @price_source,  
          @print_on_invoice_flag,  
          @quantity_used,  
          @quantity,  
          @resource_class_code,  
          @salesforce_resource_CSID,  
          @salesforce_resourceclass_CSID,  
          @cost,  
          @bill_unit_code,  
          @billing_sequence_id,  
          @company_id,  
          @date_service,  
          @prevailing_wage_code,  
          @price,  
          @price_class,  
          @profit_ctr_ID,  
          @salesforce_invoice_csid,  
          @employee_id,  
          @sales_tax_line_flag,  
          @description_2,  
          @resource_company_id,  
          @generator_sign_date,  
          @generator_sign_name,  
          @TSDF_approval_code,  
          @as_map_disposal_line,  
          @salesforce_so_csid,  
          @as_woh_disposal_flag,  
          @start_date,  
          @end_date,  
          @workorder_id_sf_send,  
          @old_billunitcode,  
          @profile_id,  
          @manifest_state  
            
  
  
END  
Close wod_line  
DEALLOCATE wod_line    
End Try  
begin catch     
 select @response = 'Work Order Detail Insert failed:' + char(13) + char(10) + isnull(ERROR_MESSAGE(),'NA')  
 Return -1  
end catch   
Return 0  



GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_wod_Insert] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_wod_Insert] TO svc_CORAppUser

GO
