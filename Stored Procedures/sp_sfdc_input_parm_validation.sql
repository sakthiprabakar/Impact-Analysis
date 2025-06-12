USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_input_parm_validation]    Script Date: 1/9/2025 8:24:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

--US#129733

ALTER PROCEDURE [dbo].[sp_sfdc_input_parm_validation] 
@executed_from varchar(200),
@input_parm_name varchar(100),
@input_parm_value varchar(1200),
@company_id int,
@profit_ctr_id int,
@response varchar(1000) OUTPUT,
@as_so_disposal_flag char(1) = 'F'

/*  
Description: To Validate the inputs which are received from Salesforce for Integration.
Devops#76450,76451,76452,76453 01/02/2024  Venu R   Created 
Devops#76740 salesforce_contract_number integrity issue in workorderheader insert, checking integrity only for the sp_sfdc_customerbilling_insert.
Devops# 77331 01/19/2024 Venu Modified the Procedure - replaced the input salesforce invoice csid instead workorder id 
Devops# 77458,77454 --01/31/2024 Venu - Modified for the erorr handling message text change
Devops# 79827 -- 03/05/2024 Venu - Modified - change the logic for Generator site csid logic implementation
Devops# 81419 -- 03/19/2024 Venu Populate the user_code to added_by and modified_by fields, hence handled the validation
DevOps# 79114 -- 04/04/2024 -- Added validation for salesforce_jobbillingproject_csid.
Devops# 83901&83903 04/08/2024 -- removed profit center condition in resource table only based on the company level
Devops# 84925 -- 04/26/2024 Venu  new resource creation logic build.
Devops# 85439  Nagaraj modfied for handle the job billing validation
Devops# 83361 - 04/29/2024 Rob - Populate Salesforce staging tables instead of actual EQAI tables (for fully transactional integration)
Devops# 87465 Nagaraj M Commented the salesforce_contract_number code as part of the decomissioning of "sp_sfdc_customerbilling_Insert".
Devops# 83361 - 05/16/2024 Rob - For MVP, remove validation of TSDF code. It will be important when the Disposal tab is integrated
Devops# 87468  fix deployment script review comments by Venu
Devops# 88090  Added validation for territory code for the stored procedure sp_sfdc_Jobbillingproject_Insert
Devops# 88089  05/21/2024 modified Venu to validate invoice csid during job billing
Devops#89138  -- 06/01/2024 Venu modified for Update Case Sensitivity for CSID on Generator Lookup
Devops#89039  - 06/03/2024 salesforce so quote validation added .
US#116037,116038,117392 - 06/18/2024 Validations added for contact integaration & Generator audit validation.
Task#437121 - Added resouce company in validation required field list.
US#118337 - 07/29/2024 Rob - It is now possible that an insert into WorkOrderHeader is part of the transaction
US#117943 - 08/02/2025 Nagaraj M- Added validation for sp_sfdc_profile_approval_info_for_lookup
DE35502 Added TSDF validation 
US#129733  - 11/13/2024 Venu Added the workorderheader validation during attachement call fi the billing pacakage submiited using single JSON
US#131404  - 01/09/2025 Venu added logic and removed the generator validation, since new generator should create when workorder created

This validation procedure called from 
sp_sfdc_workorderquoteheader_Insert
sp_sfdc_workorderquotedetail_Insert
sp_sfdc_workorderheader_Insert
sp_sfdc_workorderdetail_Insert
sp_sfdc_workorder_attachment_insert
sp_sfdc_customerbilling_insert
sp_sfdc_Jobbillingproject_Insert
*/
AS
BEGIN
DECLARE 
@ll_cnt_rec int
BEGIN TRY

    If @input_parm_name = 'company_id'
    Begin
	    If @input_parm_value is null or @input_parm_value='' 
	    Begin
	      Set @Response= 'Company id cannot be null'   
		  Return -1
        End	   
	Select @ll_cnt_rec = count(*) from  Company where company_id=@input_parm_value 
	    If @ll_cnt_rec = 0 
		Begin
			Set @Response= 'Company ID:'+isnull(@input_parm_value,'N/A')+' not exists in EQAI company table'      
			Return -1
		End
    End 
	
    If @input_parm_name = 'profit_ctr_id'
    Begin
        If @input_parm_value is null or @input_parm_value='' 
	    Begin
	      Set @Response= 'Profit center id cannot be null'   
		  Return -1
        End	   
	Select @ll_cnt_rec = count(*) from profitcenter where profit_ctr_id=@input_parm_value and company_id=@company_id and status='A'
		If @ll_cnt_rec = 0 
		Begin
			Set @Response= 'Profit center id:'+isnull(@input_parm_value,'N/A')+' not exists in EQAI profitcenter table or not mapped to the respective company ID:'+isnull(str(@company_id),'N/A')      
			Return -1
	    End
    End
	
    If @input_parm_name = 'd365customer_id'   
  	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'D365 customer id cannot be null'   
		  Return -1
		End

		Select @ll_cnt_rec = count(*)  FROM customer WHERE ax_customer_id=@input_parm_value and cust_status='A'
		If @ll_cnt_rec = 0 
		Begin
		 Set @Response= 'D365customer id:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI customer table or not an active status'      
		 Return -1
        End
		If @ll_cnt_rec > 1 
		Begin
		 Set @Response= 'D365customer id:'+isnull(@input_parm_value,'N/A')+ ' having more than one customer in EQAI customer table'      
		 Return -1
        End 
	End

    If @input_parm_name = 'project_code'  --SO Quote id
	Begin
	    If @input_parm_value is null or @input_parm_value='' 
		Begin
		    Set @Response= 'Project code cannot be null'   
			Return -1
		End
        If @executed_from = 'sp_sfdc_workorderquoteheader_insert'
		Begin
            Select @ll_cnt_rec = count(*) From WorkOrderQuoteHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and project_code = @input_parm_value 
		    If @ll_cnt_rec > 0 
			Begin
				Set @Response='Project code:'+isnull(@input_parm_value,'N/A')+ ' already exists in workorderquoteheader table'
				Return -1
			End			
		End
        If @executed_from = 'sp_sfdc_workorderquotedetail_Insert'
		Begin
			Select @ll_cnt_rec = count(*) From SFSWorkOrderQuoteHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and project_code = @input_parm_value 
			If @ll_cnt_rec = 0
			Begin
			 Set @Response='Project code:'+isnull(@input_parm_value,'N/A')+ ' not exists in workorderquoteheader table'
			 Return -1
		    End    
            --already covered above when checking to see if exists in real table, the staging table could contain multiple attempts
		    --If @ll_cnt_rec > 1
		    --Begin
		     --Set @Response='Project code:'+isnull(@input_parm_value,'N/A')+ ' having more than one row in workorderquoteheader table for the same company'+isnull(str(@company_id),'N/A')+ ' and profit center:'+isnull(str(@profit_ctr_id),'N/A')
			 --Return -1
		    --End 
	    End 
        If @executed_from = 'sp_sfdc_workorderheader_Insert'
		Begin
            if (coalesce(@as_so_disposal_flag,'F') = 'T')
			    Select @ll_cnt_rec = count(*) From SFSWorkOrderQuoteHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and project_code = @input_parm_value 
            else
			    Select @ll_cnt_rec = count(*) From WorkOrderQuoteHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and project_code = @input_parm_value 

			If @ll_cnt_rec = 0
			Begin
			 Set @Response='Project code:'+isnull(@input_parm_value,'N/A')+ ' not exists in workorderquoteheader table'
			 Return -1
		    End    
		    If @ll_cnt_rec > 1 and coalesce(@as_so_disposal_flag,'F') <> 'T'
		    Begin
		     Set @Response='Project code:'+isnull(@input_parm_value,'N/A')+ ' having more than one row in workorderquoteheader table for the same company'+isnull(str(@company_id),'N/A')+ ' and profit center:'+isnull(str(@profit_ctr_id),'N/A')
			 Return -1
		    End 
	    End 
    End

    If @input_parm_name = 'generator_id'
	Begin
	    /*If @executed_from = 'sp_sfdc_workorderheader_Insert'
		Begin
			If @input_parm_value is null or @input_parm_value='' 
			Begin
			  Set @Response= 'Generator id cannot be null.'   
			  Return -1
			End
		End */

	    If (@input_parm_value IS NOT NULL and @input_parm_value <> '')
		Begin
		Select @ll_cnt_rec = count(*) from generator WHERE generator_id= @input_parm_value and status='A'
			If @ll_cnt_rec = 0 
			Begin
			 Set @Response= 'Generator id:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI generator table or not an active status'      
			 Return -1
			End
		End   
	End 

    If @input_parm_name = 'salesforce_so_quote_line_id' 
	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce so quote line id cannot be null'   
		  Return -1
		End
	   End 
	   
    If @input_parm_name = 'resource_type'
	Begin
	   If @input_parm_value is null or @input_parm_value='' 
		Begin
			Set @Response= 'Resource type cannot be null'   
			Return -1
		End
	Select @ll_cnt_rec = count(*) from resourcetype WHERE resource_type= @input_parm_value
		If @ll_cnt_rec = 0 
		Begin
		  Set @Response= 'Resource type:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI resourcetype table'      
		  Return -1
		End
	End 
	
    If @input_parm_name = 'resource_class_code' or @input_parm_name = '@resource_item_code'
	Begin
	    If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Resource class code cannot be null'   
		  Return -1
		End
	End 

    If @input_parm_name = 'salesforce_resource_CSID'  
	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce resource csid cannot be null'   
		  Return -1
		End
		If @executed_from <>  'sp_sfdc_resource_Insert'
		Begin
			--rb-04-02-2024 Select @ll_cnt_rec = count(*) from resource WHERE salesforce_resource_csid= @input_parm_value and company_id=@Company_id and  default_profit_ctr_id=@profit_ctr_id
			Select @ll_cnt_rec = count(*) from resource WHERE salesforce_resource_csid= @input_parm_value and company_id=@Company_id
			If @ll_cnt_rec = 0 
			Begin
			  --rb-04-02-2024 Set @Response= 'Salesforce resource csid:'+isnull(@input_parm_value,'N/A')+ ' not exist in EQAI resource table for the company'+isnull(str(@company_id),'N/A')+ ' and profit center:'+isnull(str(@profit_ctr_id),'N/A')     
			  Set @Response= 'Salesforce resource csid:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI resource table for the company'+isnull(str(@company_id),'N/A')    
			  Return -1
			End 
			If @ll_cnt_rec > 1 
			Begin
			  --rb-04-02-2024 Set @Response= 'Salesforce resource csid:'+isnull(@input_parm_value,'N/A')+ ' having more than one row in EQAI resource tablefor the company'+isnull(str(@company_id),'N/A')+ ' and profit center:'+isnull(str(@profit_ctr_id),'N/A')     
			  Set @Response= 'Salesforce resource csid:'+isnull(@input_parm_value,'N/A')+ ' having more than one row in EQAI resource table for the company'+isnull(str(@company_id),'N/A')    
			  Return -1
			End 
		End

		If @executed_from = 'sp_sfdc_resource_Insert'
		Begin
			--rb-04-02-2024 Select @ll_cnt_rec = count(*) from resource WHERE salesforce_resource_csid= @input_parm_value and company_id=@Company_id and  default_profit_ctr_id=@profit_ctr_id
			Select @ll_cnt_rec = count(*) from resource WHERE salesforce_resource_csid= @input_parm_value and company_id=@Company_id and resource_type='E'
			If @ll_cnt_rec > = 1 
			Begin
			  --rb-04-02-2024 Set @Response= 'Salesforce resource csid:'+isnull(@input_parm_value,'N/A')+ ' not exist in EQAI resource table for the company'+isnull(str(@company_id),'N/A')+ ' and profit center:'+isnull(str(@profit_ctr_id),'N/A')     
			  Set @Response= 'Salesforce resource csid:'+isnull(@input_parm_value,'N/A')+ ' is already exists in EQAI resource table for the company  '+isnull(str(@company_id),'N/A')  + 'and equipment resource type'   
			  Return -1
			End 			
		End
	End

	If @input_parm_name = 'salesforce_resourceclass_CSID'  
	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce resourceclass csid cannot be null'   
		  Return -1
		End

		Select @ll_cnt_rec = count(*) from resourceclassheader WHERE salesforce_resourceclass_csid= @input_parm_value 
	    If @ll_cnt_rec = 0 
		Begin
		  Set @Response= 'Salesforce resource class csid:' +isnull(@input_parm_value,'N/A')+ ' not exists in EQAI resourceclassheader table'      
		  Return -1
		End 		
    End
	
    If @input_parm_name = 'bill_unit_code' 
	Begin
	Select @ll_cnt_rec = count(*) from billunit WHERE bill_unit_code= @input_parm_value
		 If @ll_cnt_rec = 0 
		    Begin
			  Set @Response= 'Bill unit code:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI billunit table'      
			  Return -1
		    End
	End 

    If @input_parm_name = 'currency_code' 
	Begin
	Select @ll_cnt_rec = count(*) from Currency WHERE currency_code= @input_parm_value
		If @ll_cnt_rec = 0 
		Begin
		 Set @Response= 'Currency code:' +isnull(@input_parm_value,'N/A')+ ' not exists in EQAI currency table'      
		 Return -1
		End
	End 

   If @input_parm_name = 'salesforce_invoice_CSID' 
	Begin
	    If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce invoice csid cannot be null'   
		  Return -1
		End
        If @executed_from = 'sp_sfdc_workorderheader_Insert'
		Begin
		Select @ll_cnt_rec = count(*) From WorkOrderHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and salesforce_invoice_CSID = @input_parm_value 
		  If @ll_cnt_rec > 0 
		  Begin
		   Set @Response='Salesforce invoice csid:'+isnull(@input_parm_value,'N/A')+ ' already exists in workorderheader table'
		   Return -1
		  End  
	    End
        If @executed_from = 'sp_sfdc_workorderdetail_Insert'  or @executed_from ='sp_sfdc_workorder_attachment_insert'
		Begin
		  Select @ll_cnt_rec = count(*) From SFSWorkOrderHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and salesforce_invoice_CSID = @input_parm_value 
		  If @ll_cnt_rec = 0
		  Begin
		    If @executed_from ='sp_sfdc_workorder_attachment_insert'  /*This block is used,since billing package submmited from single JSON*/
			Begin
			  Select @ll_cnt_rec = count(*) From WorkOrderHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and salesforce_invoice_CSID = @input_parm_value 
			End
			If @ll_cnt_rec = 0
			Begin
		    Set @Response='Salesforce invoice csid:'+isnull(@input_parm_value,'N/A')+ ' not exists in workorderheader table'
			Return -1
			End
		  End 
--		  If @ll_cnt_rec > 1
--		  Begin
--		    Set @Response='Salesforce invoice csid:'+isnull(@input_parm_value,'N/A')+ ' mapped to more than one workorder for the same company:'+isnull(str(@company_id),'N/A')+ ' and profit center:'+isnull(str(@profit_ctr_id),'N/A')+ ' in workorderheader table'
--			Return -1
--		  End
	    End  

		If @executed_from = 'sp_sfdc_Jobbillingproject_Insert'
		Begin
		Select @ll_cnt_rec = count(*) From WorkOrderHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and salesforce_invoice_CSID = @input_parm_value 
		  If @ll_cnt_rec = 0 
		  Begin
		   Set @Response='Salesforce invoice csid:'+isnull(@input_parm_value,'N/A')+ ' not exists in workorderheader table'
		   Return -1
		  End  
	    End

    End
	
   	If @input_parm_name = 'workorder_type_id' 
	Begin
	    If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Workorder type id cannot be null'   
		  Return -1
		End
    Select @ll_cnt_rec = count(*)  FROM WorkOrderTypeHeader   WHERE workorder_type_id =@input_parm_value
		If @ll_cnt_rec = 0 
		Begin
		 Set @Response= 'Workorder type id:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI WorkOrderTypeHeader table'      
		 Return -1
        End
	End  
	
    If @input_parm_name = 'billing_project_id' 
	   Begin
	   If @input_parm_value is null or @input_parm_value='' 
	   Begin
		Set @Response= 'Billing project id cannot be null'   
		Return -1
	   End
	End 

	If @input_parm_name = 'salesforce_invoice_line_id'  
	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		 Set @Response= 'Salesforce invoice line id cannot be null'   
		 Return -1
		End
	End 
	
	-- 05/16/2024 rb Temporarily comment out for MVP  (Comment removed)
	If @input_parm_name = 'TSDF_code'  
	Begin

	If @input_parm_value is null or @input_parm_value='' 
		Begin
		 Set @Response= 'TSDF code cannot be null'   
		 Return -1
		End

	Select @ll_cnt_rec = count(*)  FROM tsdf   WHERE tsdf_code =@input_parm_value and tsdf_status='A'
		If @ll_cnt_rec = 0 
	    Begin
		 Set @Response= 'Tsdf code:'+isnull(@input_parm_value,'N/A')+ ' not exist in EQAI tsdf table or not an active status'      
		 Return -1
        End
	End 
	

	If @input_parm_name = 'region_id'   
  	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'region id cannot be null'   
		  Return -1
		End

	Select @ll_cnt_rec = count(*)  FROM region WHERE region_id=@input_parm_value
		If @ll_cnt_rec = 0 
		Begin
		 Set @Response= 'Region id:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI region table'      
		 Return -1
        End
	End


/*
	If @input_parm_name = 'salesforce_contract_number' and  @executed_from = 'sp_sfdc_customerbilling_Insert'
  	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'salesforce contract number cannot be null'   
		  Return -1
		End
   	 
		Select @ll_cnt_rec = count(*)  FROM CustomerBilling WHERE salesforce_contract_number=@input_parm_value
		
		If @ll_cnt_rec > 0 
		Begin
		 Set @Response= 'Salesforce contract number:'+isnull(@input_parm_value,'N/A')+ ' already exists in EQAI CustomerBilling table'
		Return -1
        End
    End
*/	
   
    If @input_parm_name = 'workorder_id'  
	Begin
      /*If @input_parm_value is null or @input_parm_value='' 
	  Begin
		 Set @Response= 'workorder id cannot be null.'   
		 Return -1
		End*/
	 
	select @ll_cnt_rec = count(*) from WorkOrderHeader where workorder_id = @input_parm_value and company_id = @company_id 	and profit_ctr_id = @profit_ctr_id
	    If @ll_cnt_rec = 0 
	    Begin
		 Set @Response= 'Work order id:' +isnull(@input_parm_value,'N/A')+ ' not exists in EQAI workorderheader table for the company'+isnull(str(@company_id),'N/A')+ ' and profit center:'+isnull(str(@profit_ctr_id),'N/A')     
		 Return -1
        End
	End	
	
    If @input_parm_name = 'document_type_id'  
	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
			 Set @Response= 'Document type id cannot be null'   
			 Return -1
		End
		
	select @ll_cnt_rec = count(*) from ScanDocumentType where type_id = @input_parm_value and scan_type = 'workorder' and status='A'
	    If @ll_cnt_rec = 0 
	    Begin
		 Set @Response= 'Document type id:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI ScanDocumentType table or not an active status'      
		 Return -1
        End
    End
	If @input_parm_name = 'salesforce_site_csid'  
	Begin	
	If @input_parm_value is not null and @input_parm_value <> ''  
		Begin
			select @ll_cnt_rec = count(*) from generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS= @input_parm_value and status='A'	
			 If @ll_cnt_rec > 1 
				Begin
				 Set @Response= 'Salesforce site csid:'+isnull(@input_parm_value,'N/A')+ ' exists in EQAI Generator table more than one'      
				 Return -1
				End			 					
		End
	End
	
    If @input_parm_name = 'employee_id'
    Begin
	    If @input_parm_value is null or @input_parm_value='' 
	    Begin
	      Set @Response= 'Employee id cannot be null'   
		  Return -1
        End	   
	Select @ll_cnt_rec = count(*) from  users where employee_id=@input_parm_value 
	    If @ll_cnt_rec = 0 
		Begin
			Set @Response= 'Employee ID:'+isnull(@input_parm_value,'N/A')+' not exists in EQAI Users table'      
			Return -1
		End

		If @ll_cnt_rec > 1 
		Begin
			Set @Response= 'Employee ID:'+isnull(@input_parm_value,'N/A')+' exists in EQAI Users table more than one'      
			Return -1
		End

    End

	If @input_parm_name = 'salesforce_jobbillingproject_csid'
  	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce jobbillingproject csid cannot be null'   
		  Return -1
		End
   	 
		Select @ll_cnt_rec = count(*)  FROM CustomerBilling WHERE salesforce_jobbillingproject_csid=@input_parm_value
		
		If @executed_from <> 'sp_sfdc_jobbilling_closedate_upd'
		Begin
			If @ll_cnt_rec > 0 
			Begin
				Set @Response= 'Salesforce jobbillingproject csid:'+isnull(@input_parm_value,'N/A')+ ' already exists in EQAI CustomerBilling table'
			Return -1
			End
		End
		
		

		If @executed_from = 'sp_sfdc_jobbilling_closedate_upd'
		Begin
			If @ll_cnt_rec = 0 
			Begin
				Set @Response= 'Salesforce jobbillingproject csid:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI CustomerBilling table'
			Return -1
			End
		End
    End

	If @input_parm_name = 'sf_invoice_backup_document'
  	Begin
	    If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce invoice backup document name cannot be null'   
		  Return -1
		End

		Select @ll_cnt_rec = count(*)  FROM sfdc_workorder_documenttype_translate WHERE sf_document_name_label=@input_parm_value

		If @ll_cnt_rec = 0 
		Begin
			Set @Response= 'Salesforce invoice backup document name:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI sfdc_workorder_documenttype_translate table'
		Return -1
		End

	End

	If @input_parm_name = 'customer_billing_territory_code'
  	Begin
	    If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Territory code cannot be null, and please provide valid territory code'   
		  Return -1
		End

		Select @ll_cnt_rec = count(*)  FROM territory WHERE territory_code=@input_parm_value

		If @ll_cnt_rec = 0 
		Begin
			Set @Response= 'Territory code not exists in EQAI territory table, and please provide valid territory code'
		Return -1
		End

	End

	If @input_parm_name = 'salesforce_so_quote_id'
  	Begin
	    If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce SO quote ID cannot be null'   
		  Return -1
		End

		Select @ll_cnt_rec = count(*)  FROM workorderquoteheader WHERE company_id = @company_id and profit_ctr_id = @profit_ctr_id and (project_code=@input_parm_value or salesforce_so_quote_id=@input_parm_value)

		If @ll_cnt_rec = 0 
		Begin
	    Set @Response='Salesforce SO quote ID:'+isnull(@input_parm_value,'N/A')+ ' not exists in workorderquoteheader table'
		Return -1
		End
	End



	If @input_parm_name = 'salesforce_contact_csid'
  	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Salesforce contact csid cannot be null'   
		  Return -1
		End  	 
		
		Select @ll_cnt_rec = count(*)  FROM CONTACTXREF WHERE salesforce_contact_csid=@input_parm_value

		If @executed_from = 'sp_sfdc_contact_insert'
		Begin
		
		   If @ll_cnt_rec > 0 
			Begin
				Set @Response= 'Salesforce contact csid:'+isnull(@input_parm_value,'N/A')+ ' already exists in EQAI CONTACTXREF table'
			Return -1
			End
		End	

		If @executed_from = 'sp_sfdc_contact_update'
		Begin		    
			If @ll_cnt_rec = 0 
			Begin
				Set @Response= 'Salesforce contact csid:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI CONTACTXREF table'
			Return -1
			End
		End
    End
	   	  
    If @input_parm_name = 'email'
	Begin
	If @input_parm_value is null or @input_parm_value='' 
		Begin
		  Set @Response= 'Contact email ID cannot be null'   
		  Return -1
		End 
	End

	If @input_parm_name = 'salesforce_site_csid_upd'
	Begin
		If @input_parm_value is null or @input_parm_value='' 
		Begin
			  Set @Response= 'Salesforce Site CSID cannot be null'   
			  Return -1
		End 
        select @ll_cnt_rec = count(*) from generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS= @input_parm_value and status='A'

		If @executed_from = 'sp_sfdc_workorderheader_Insert' and @ll_cnt_rec=0
		Begin
			Set @Response= 'Salesforce site csid:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI Generator table to update'      
			Return -1
		End
	End
	
	If @input_parm_name = 'resource_company_id'
    Begin
	    If @input_parm_value is null or @input_parm_value='' 
	    Begin
	      Set @Response= 'Resource Company id cannot be null'   
		  Return -1
        End	   
	Select @ll_cnt_rec = count(*) from  Company where company_id=@input_parm_value 
	    If @ll_cnt_rec = 0 
		Begin
			Set @Response= 'Resource Company ID:'+isnull(@input_parm_value,'N/A')+' not exists in EQAI company table'      
			Return -1
		End
    End 

	
	
	If @executed_from = 'sp_sfdc_profile_approval_info_for_lookup'
	Begin
		If @input_parm_name = 'TSDF_CODE'  
		Begin
		If @input_parm_value is null or @input_parm_value='' 
			Begin
			 Set @Response= 'TSDF CODE cannot be null'   
			  Return -1
			End 
			Select @ll_cnt_rec = count(*)  FROM tsdf   WHERE tsdf_code =@input_parm_value and tsdf_status='A'
			If @ll_cnt_rec = 0 
			Begin
				Set @Response= 'Tsdf code:'+isnull(@input_parm_value,'N/A')+ ' not exist in EQAI tsdf table or not an active status'  
				Return -1
			End
		End 
		If @input_parm_name = 'salesforce_site_csid'  
		Begin
			If @input_parm_value is null or @input_parm_value='' 
			Begin
			 Set @Response= 'Salesforce Site CSID cannot be null'   
			  Return -1
			End 
			If @input_parm_value is NOT null and @input_parm_value <> ''  
			Begin
			select @ll_cnt_rec = count(*) from generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS= @input_parm_value and status='A'	
			 If @ll_cnt_rec =0 
				Begin
				 Set @Response= 'Salesforce site csid:'+isnull(@input_parm_value,'N/A')+ ' not exists in EQAI Generator table.'      
				 Return -1
				End			 					
			End
		End
	END 
	

END TRY

BEGIN CATCH
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,
										source_system_details,
										action,
										Error_description,
										log_date,
										Added_by)
								 SELECT
										'Validation Failure - check the parent call json',
										'sp_sfdc_input_parm_validation::Salesforce',
										'Input Parm Validation',
										isnull(str(ERROR_LINE()),' ')+'Line Number failed'+ isnull(ERROR_MESSAGE(),' '),
										GETDATE(),
										SUBSTRING(USER_NAME(), 1, 40)
END CATCH

END

GO



GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_input_parm_validation] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_input_parm_validation] TO svc_CORAppUser

GO