USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_billing_project_lookup]    Script Date: 8/28/2024 8:06:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

Create Proc [dbo].[sp_sfdc_billing_project_lookup] 
				   	@d365customer_id varchar(20) null,
					@salesforce_site_csid varchar(18) null,
					@company_id int null,
					@profit_ctr_id int,
					@response varchar(8000) OUTPUT
					
 
AS 
/*************************************************************************************************************
Description: 

EQAI profile approval info for salesforce.

Revision History:

US#114205 -- Nagaraj M -- Initial Creation


use plt_ai
go
Declare @response varchar(1000)
exec dbo.sp_sfdc_billing_project_lookup
@salesforce_site_csid ='US117943',
@d365customer_id='C309704',
@company_id=21,
@profit_ctr_id=0,
@response =@response output
print @response



***************************************************************************************************************/
DECLARE 
	@key_value varchar (200),
	@ls_config_value char(1)='F',
	@generator_id int,
	@customer_id int,
	@fee varchar(10),
	@validation_req_field varchar(100),
    @validation_req_field_value varchar(500),
	@validation_response varchar(1000),	 
	@ll_validation_ret int,	
	@ll_count int,
	@flag char(1)='I',
	@source_system varchar(100)='sp_sfdc_billing_project_lookup'
Begin 
	Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag_phase3'
	IF @ls_config_value is null or @ls_config_value=''
	Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
Begin
Begin Try

    Select @key_Value =  ' company id;' + isnull(TRIM(STR(@company_id)), '') +
						 ' profit_ctr_id;' + isnull(TRIM(STR(@profit_ctr_id)), '') +
						'  salesforce site csid ; ' + ISNULL(TRIM(@salesforce_site_csid),'') +
						'  d365customer_id ; ' + ISNULL(TRIM(@d365customer_id),'') 
												
						
	Set @response = 'Integration Successful'

	Begin 
			Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
			Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
																 ('company_id',str(@company_id)),
																 ('profit_ctr_id',str(@profit_ctr_id)),
																 ('d365customer_id',@d365customer_id),
																 ('salesforce_site_csid',@salesforce_site_csid)
																

		Declare sf_validation CURSOR for
					select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
					Open sf_validation
						fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
						While @@fetch_status=0
						Begin						   
						   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_billing_project_lookup',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_response output
								If @validation_req_field='d365customer_id' and @ll_validation_ret <> -1
								   Begin
								   select @customer_id=customer_id from Customer where ax_customer_id=@d365customer_id and cust_status='A'
								   End
                              
						   If @ll_validation_ret = -1
						   Begin 
								 If @Response = 'Integration Successful'
								 Begin
									Set @Response ='Error: Integration failed due to the following reason;'
								 End
							 Set @Response = @Response + @validation_response+ ';'
							 Set @flag = 'E'
						   End	
						fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
					   End		
				    Close sf_validation
				    DEALLOCATE sf_validation 	 
					Drop table #temp_salesforce_validation_fields
			
			
			
			 If @flag = 'E'
			   Begin
				   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
													SELECT
													@key_value,
													@source_system,
													'Insert',
													@Response,
													GETDATE(),
													SUBSTRING(USER_NAME(),1,40)
                Return -1								
				End

		select @generator_id=generator_id from Generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A'
		

			CREATE TABLE #CUSTBILLINGPROJECT (Billing_Project_ID int,Billing_Project_Name varchar(40),Status char(20),Purchase_Order varchar(20),Release varchar(20),PO_Description varchar(20),PO_Amount money,
			Start_Date datetime,Expiration_Date datetime,Link_Reqd char(10),ES_Territory varchar(8),ES_AE varchar(40),FIS_Territory varchar(8),FIS_AE varchar(40),Distribution_method  char(1),Contact_Name  varchar(40),
			Contact_Email varchar(60),Fee_Type char(1),Emanifest_Fee money,bp_EIR varchar(10),FEE varchar(10))


		IF @FLAG <>'E'
		BEGIN
			INSERT INTO #CUSTBILLINGPROJECT
			(Billing_Project_ID,Billing_Project_Name,Status,Purchase_Order,Release,PO_Description,PO_Amount,
				Start_Date,Expiration_Date,Link_Reqd,ES_Territory,ES_AE,FIS_Territory,FIS_AE,Distribution_method,Contact_Name,
				Contact_Email,Fee_Type,Emanifest_Fee,BP_EIR,fee)
				SELECT DISTINCT CustomerBilling.billing_project_ID,
					CustomerBilling.project_name, 
					CustomerBilling.status,
					CustomerBillingPO.purchase_order,
					CustomerBillingPO.release,
					CustomerBillingPO.PO_description,
					CustomerBillingPo.po_amt,
					CustomerBillingPO.start_date,
					CustomerBillingPO.expiration_date,
					--CustomerBilling.link_required_flag,
					case when customerBilling.link_required_flag='T' THEN 'Yes' 
					when customerBilling.link_required_flag= 'F' THEN 'No' 
					when customerBilling.link_required_flag='' or customerBilling.link_required_flag=null THEN 'No' 
					ELSE '' END,
					es_cbt.customer_billing_territory_code as es_territory_code,
					ISNULL ( es_sales.user_name, 'None Assigned' ) AS es_ae,
					fis_cbt.customer_billing_territory_code as fis_territory_code,
					ISNULL ( fis_sales.user_name, 'None Assigned' ) AS fis_ae,
					CustomerBilling.distribution_method,
					contact.name,
					contact.email,
					CustomerBillingeManifestFee.emanifest_fee_option,
				case when CustomerBillingeManifestFee.emanifest_fee_option ='A' then (CustomerBillingeManifestFee.emanifest_fee)
				when CustomerBillingeManifestFee.emanifest_fee_option ='E' THEN 0
				else (CustomerBillingeManifestFee.emanifest_fee)
				end as emainfest_fee,
				dbo.fn_get_recovery_fee_flag('EIR', CustomerBilling.customer_id, CustomerBilling.billing_project_id, GETDATE()),
				case when dbo.fn_get_recovery_fee_flag('EIR', CustomerBilling.customer_id, CustomerBilling.billing_project_id, GETDATE())='U' then 'EEC'
				when dbo.fn_get_recovery_fee_flag('EIR', CustomerBilling.customer_id, CustomerBilling.billing_project_id, GETDATE())='' then ''	ELSE 'EIR' END
				FROM CustomerBilling
				LEFT OUTER JOIN CustomerBillingPO 
				ON CustomerBilling.customer_id = CustomerBillingPO.customer_id
				AND CustomerBilling.billing_project_id = CustomerBillingPO.billing_project_id
				AND CustomerBillingPO.status = 'A'
				LEFT OUTER JOIN CustomerBillingXProfitCenter 
				ON CustomerBilling.customer_id = CustomerBillingXProfitCenter.customer_id
				AND CustomerBilling.billing_project_id = CustomerBillingXProfitCenter.billing_project_id
				LEFT OUTER JOIN Generator
				ON CustomerBillingPO.PO_generator_id = Generator.generator_id
				AND CustomerBillingPO.PO_type = 'G'
				JOIN customerbillingterritory es_cbt ON customerbilling.customer_id = es_cbt.customer_id
				AND es_cbt.billing_project_id = customerbilling.billing_project_id
				AND es_cbt.customer_billing_territory_primary_flag = 'T'
				JOIN BusinessSegment es_bs ON es_cbt.businesssegment_uid = es_bs.businesssegment_uid
				AND es_bs.business_segment_code = 'ES'
				JOIN customerbillingterritory fis_cbt ON customerbilling.customer_id = fis_cbt.customer_id
				AND fis_cbt.billing_project_id = customerbilling.billing_project_id
				AND fis_cbt.customer_billing_territory_primary_flag = 'T'
				JOIN BusinessSegment fis_bs ON fis_cbt.businesssegment_uid = fis_bs.businesssegment_uid
				AND fis_bs.business_segment_code = 'FIS'
				LEFT OUTER JOIN usersxeqcontact es_salesx 
				ON  es_cbt.customer_billing_territory_code  = es_salesx.territory_code
				AND es_salesx.eqcontact_type = 'AE'
				LEFT OUTER JOIN users es_sales 
				ON es_salesx.user_code = es_sales.user_code
				LEFT OUTER JOIN usersxeqcontact fis_salesx 
				ON  fis_cbt.customer_billing_territory_code  = fis_salesx.territory_code
				AND fis_salesx.eqcontact_type = 'AE'
				LEFT OUTER JOIN users fis_sales 
				ON fis_salesx.user_code = fis_sales.user_code
				left outer join CustomerBillingeManifestFee
				on CustomerBilling.customer_id = CustomerBillingeManifestFee.customer_id
				left outer join customerbillingxcontact
				on CustomerBillingXContact.customer_id=CustomerBilling.customer_id
				and CustomerBillingXContact.customer_id=@customer_id
				left outer join contact
				on CustomerBillingXContact.contact_id=contact.contact_ID
				and CustomerBillingXContact.customer_id=@customer_id
				AND CONTACT.CONTACT_STATUS='A'
				WHERE CustomerBilling.status = 'A'
				and CustomerBilling.status = 'A' AND CustomerBilling.customer_id = @customer_id
				AND
				(CustomerBilling.all_facilities_flag = 'T' OR (CustomerBilling.all_facilities_flag = 'F'   AND CustomerBillingXProfitCenter.company_id = @company_id   AND CustomerBillingXprofitCenter.profit_ctr_id = @profit_ctr_id )) 
				AND ((ISNULL(CustomerBillingPO.PO_type, 'ZZZ') <> 'G')  OR (CustomerBillingPO.PO_type = 'G' AND Generator.generator_id = @generator_id))
		END	
		
		SELECT @ll_count=COUNT(*) FROM #CUSTBILLINGPROJECT
		if @ll_count =0
		BEGIN
			set @Response = 'No billing project exists for the respective customer id ' + trim(str(@customer_id)) +' and salesforce site csid ' + @salesforce_site_csid  + ' and company_id '+ TRIM(str(@company_id)) + ' and @profit_ctr_id ' + TRIM(str(@profit_ctr_id))
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
														SELECT @key_value,@source_system,'Insert',@Response,GETDATE(),SUBSTRING(USER_NAME(),1,40)
		END
		
		if @ll_count >=1
		BEGIN
			UPDATE #CUSTBILLINGPROJECT SET STATUS= CASE WHEN fee ='EIR' AND BP_EIR='T' THEN 'Apply'
			WHEN FEE ='EIR' AND BP_EIR='F' THEN 'Exempt'
			WHEN FEE ='EIR' AND BP_EIR='P' THEN 'Partial'
			WHEN FEE ='EIR' AND BP_EIR='U' THEN 'N/A'
			WHEN FEE ='EIR' AND BP_EIR='' THEN ''
			WHEN FEE ='EEC' AND BP_EIR='T' THEN 'Apply'
			WHEN FEE ='EEC' AND BP_EIR='F' THEN 'Exempt'
			WHEN FEE ='EEC' AND BP_EIR='U' THEN 'N/A'
			WHEN FEE ='EEC' AND BP_EIR='' THEN ''
			WHEN FEE='' THEN ''
			END
	
			SELECT  DISTINCT Billing_Project_ID as  "Billing Project ID",Billing_Project_Name as "Billing Project Name",Fee,Status,Purchase_Order as "Purchase Order",Release,
			PO_Description as "PO Description",PO_Amount as "PO Amount",Start_Date as "Start Date",Expiration_Date as "Expiration Date",Link_Reqd as "Link Req'd",
			ES_Territory as "ES Territory",ES_AE as "ES AE",FIS_Territory AS "FIS Territory",FIS_AE AS "FIS AE",Distribution_method AS "Distribution method",
			Contact_Name AS "Contact Name",Contact_Email AS "Contact E-mail",Fee_Type AS "Fee Type",Emanifest_Fee AS "E-manifest Fee"
			from #CUSTBILLINGPROJECT
			ORDER  BY Billing_Project_ID ASC
		END
		DROP TABLE #CUSTBILLINGPROJECT
END
END TRY 
	BEGIN CATCH			
		INSERT INTO Plt_AI_Audit..
		Source_Error_Log 
		(input_params,
		source_system_details, 
		action,
		Error_description,
		log_date, 
		Added_by) 
		SELECT 
		@key_value, 
		@source_system, 
		'Select', 
		ERROR_MESSAGE(), 
		GETDATE(), 
		SUBSTRING(USER_NAME(),1,40) 
	END CATCH 
End
If @ls_config_value='F'
Begin
   Print 'SFDC Data Integration Failed,since CRM Go live flag - Phase3 is off. Hence Store procedure will not execute.'
   Return -1
End
End

Go


GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_billing_project_lookup] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_billing_project_lookup] TO svc_CORAppUser

GO
