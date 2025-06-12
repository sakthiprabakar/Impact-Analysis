USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorder_insert]    Script Date: 2/3/2025 2:44:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER    procedure [dbo].[sp_sfdc_workorder_insert]
	@json nvarchar(max),@response varchar(4000) output
As
/*  
Description: 

Workorder Integaration Call from Salesforce. This Store procedue used in API and the API invoked by Salesforce team.
Created By Venu -- 18/Oct/2024
Rally # US129733  - New Design To handle the workorder in Single JSON
Rally # US136352  - Added Manifest_state in parameter
Rally # US139387  - Note fields added into JSON
*/
declare
	@validation_response varchar(4000),
	@header_response  varchar(4000),
	@detail_response  varchar(4000),
	@workorder_id_ret int,
	@ll_ret_hdr int,
	@ll_ret_dtl int,
	@ll_hdr_cnt int,
	@ll_dtl_cnt int,
	@salesforce_invoice_csid varchar(18),
	@company_id int,
	@profit_ctr_id int,
	@Employee_Id varchar(20),
	@user_code varchar(10),
	@json_detail nvarchar(max),
	@json_header nvarchar(max),
	@note_id int,
	@ls_config_value char(1),
	@note_sub Varchar(50)
		

set @response = ''
set @validation_response = ''
set @header_response = ''
set @detail_response = ''
set nocount on

select @ls_config_value = config_value from configuration where config_key='CRM_Golive_flag_phase3'

if coalesce(@ls_config_value,'') = ''
   set @ls_config_value='F'

If @ls_config_value='T'
Begin
set transaction isolation level read uncommitted

----------------------
--parse @json argument into #sf_header and #sf_detail temp tables

--Header
drop table if exists #sf_header


select Header.*
into #sf_header
from OPENJSON(@json) with (
    Header nvarchar(max) as json
)
as SF_JSON
cross apply openjson(SF_JSON.Header)
with (
    D365CustomerId varchar(20),
    SalesforceInvoiceCSID Varchar(18),
    PurchaseOrder Varchar(20),
    ProjectCode varchar(15),
    AXDimension5Part1 varchar(20),
    CompanyId int,
    EndDate datetime,
    GeneratorId int,
    SalesforceSiteCSID varchar(18),
    ProfitCenterId int,
    StartDate datetime,
    WorkOrderTypeId int,
    description varchar(255),
    ProjectName varchar(40),
    ContactId int,  --Not recevied from JSON
    employee_id varchar(20),
    Invoicecomment_1 varchar(80),
    GeneratorName varchar(75),
    GeneratorAddress1 varchar(85),
    GeneratorAddress2 varchar(40), --Not recevied from JSON
    GeneratorAddress3 varchar(40), --Not recevied from JSON
    GeneratorAddress4 varchar(40), --Not recevied from JSON
    GeneratorAddress5 varchar(40), --Not recevied from JSON
    GeneratorCity varchar(40),
    GeneratorState varchar(2),
    GeneratorZipCode varchar(15),
    GeneratorCountry varchar(3),
    GeneratorPhone varchar(10),
    GeneratorFax varchar(10),
    GenMailName varchar(75),
    GenMailAddress1 varchar(85),
    GenMailAddress2 varchar(40), --Not recevied from JSON
    GenMailAddress3 varchar(40), --Not recevied from JSON
    GenMailAddress4 varchar(40), --Not recevied from JSON
    GenMailAddress5 varchar(40), --Not recevied from JSON
    GenMailCity varchar(40),
    GenMailState varchar(2),
    GenMailZipCode varchar(15),
    GenMailCountry varchar(3),
    NAICScode int,
    GeneratorStatus char(1),
    AsSiteChanged char(1),
    AsSoDisposalFlag char(1),
	BillingProjectId int,
	SalesforceSoCsid	varchar(18),
	note_account_executive varchar(18),
	note_billing_instructions varchar(max),
	note_approved varchar(6),
	note_approved_amount Decimal (16,2),
	note_contact varchar(18),
	note_contract_name varchar(1300),
	note_surcharge_pct  Decimal (18),
	note_surcharge_type varchar(255),
	note_corrected_customer_PO_no varchar(35),
	note_country varchar(3),
	note_instructions varchar(max),
	note_Payment_Date Datetime,
	note_ic varchar(1300),
	note_internal_comments varchar(max),
	note_invoice_note varchar(255),
	note_lastmodified varchar(203),
	note_owner varchar(18), 
	note_payment_term varchar(18),
	note_remit_to varchar(1300),
	note_Amount Decimal (16,2),
	note_rental_invoice varchar(6),
	note_sales_quote varchar(1300),
	note_salesperson varchar(18),
	note_service_days Decimal(16,2),
	note_subsidiary_company varchar(18),	
	note_tax_area  varchar(18) ,  
	note_tax_liable varchar(6),
	note_rental_order  varchar(18),
	note_SalesInvoiceNumber varchar(80),	
	note_surcharge_amount Decimal (16,2),
	note_surcharge_amt_Incl_tax Decimal (16,2),
	Work_Order_Status_Submitted_Flag varchar(30),
	SalesforceContractNumber varchar(30),
	quote_id varchar(18),
	other_submit_required_flag varchar(10),
	invoice_tax DEcimal (16,2),
	cust_discount Decimal (16,2),
	currency_code varchar(18),
	confirm_author varchar(203),
	Bill_to_Contact varchar(203)
	) as Header

if @@ERROR <> 0
begin
	raiserror('ERROR: attempt to create and populate #sf_header',18,-1) with seterror
	return -1
end




--------------------------------
--Details
drop table if exists #sf_detail

select Details.*
into #sf_detail
from OPENJSON(@json) with (
    details nvarchar(max) as json
)
as SF_JSON
cross apply openjson(SF_JSON.details)
with (
Manifest varchar(15),
SalesforceBundleId	varchar(10),
ResourceType	Varchar(1),
Description	varchar(100),
TSDFCode	varchar(15),
ExtendedPrice	money,
ExtendedCost	money,
SalesforceInvoiceLineId	varchar(25),
SfTaskName	varchar(80),
BillRate	numeric(10,4), --float,
PriceSource	varchar(40),
PrintOnInvoiceFlag	char(1),
QuantityUsed	numeric(10,4), --float,
Quantity	numeric(10,4), --float,
ResourceClassCode	varchar(20),
SalesforceResourceCsid	varchar(18),
SalesforceResourceClassCSID	varchar(18),
Cost	money,
BillUnitCode          	varchar(4),
BillingSequenceId	decimal(10,3),
CompanyId	int,
DateService	datetime,
PrevailingWageCode	varchar(20),
Price	money,
PriceClass	varchar(10),
ProfitCenterId	int,
SalesforceInvoiceCSID	varchar(18)	,
employee_id	varchar(20),
SalesTaxLineFlag	char(1),
Description2	varchar(100),
ResourceCompanyId	int,
GeneratorSignDate	datetime,
GeneratorSignName	varchar(255),
tsdfApprovalCode	varchar(40), 
AsMapDisposalLine	char(1),
SalesforceSoCsid	varchar(18),
AsWohDisposalFlag	char(1),
start_date	datetime,
end_date	datetime,
workorder_id int,
old_billunitcode varchar(4),
Profileid int,
Manifest_state char(1),
note_contract_line varchar(18),
note_line_amt_incl_tax Decimal (16,2),
note_tm varchar(18),
note_tmNumber varchar(18),
ResourceAssigned varchar(20))
as Details

if @@ERROR <> 0
begin
	raiserror('ERROR: attempt to create and populate #sf_detail',18,-1) with seterror
	return -1
end


Select @ll_hdr_cnt = count(*) from #sf_header
Select @ll_dtl_cnt = count(*) from #sf_detail


If @ll_hdr_cnt=0 and @ll_dtl_cnt=0
Begin
    raiserror('ERROR: No Record for Integration',18,-1) with seterror
	Set @response ='No Record for Integration'
	return -1
End



--Insert Log Table 
If @ll_hdr_cnt > 0
Begin
	Select @company_id=CompanyId,@profit_ctr_id=ProfitCenterID,@salesforce_invoice_csid=SalesforceInvoiceCSID,@employee_id=Employee_Id from #sf_header
End

If @ll_hdr_cnt = 0 and @ll_dtl_cnt > 0
Begin
	Select Top 1 @company_id=CompanyId,@profit_ctr_id=ProfitCenterID,@salesforce_invoice_csid=SalesforceInvoiceCSID,@employee_id=Employee_Id from #sf_detail
End

If len (@employee_id) > 0 
Begin
	EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output 
End

If @ll_hdr_cnt > 0 Or @ll_dtl_cnt > 0 
BEGIN
	Insert Into sfdc_eqai_log (company_id,profit_ctr_id,salesforce_invoice_csid,added_by,date_added,app_source,json) Values
							(@company_id,@profit_ctr_id,@salesforce_invoice_csid,@user_code,getdate(),'Salesforce',@json)
End   


If @ll_hdr_cnt > 0 Or @ll_dtl_cnt > 0 
BEGIN		
	--validate the data in #sf_header and #sf_detail
	exec dbo.sp_sfdc_workorder_validate @validation_response output
	
	if len(@validation_response) > 0
	begin
	    Set @response=@validation_response
	    Update sfdc_eqai_log set response=@validation_response,status='E' where sfs_req_uid in (Select max(sfs_req_uid) from sfdc_eqai_log)
		raiserror(@validation_response,18,-1) with seterror		
		return -1
	end
END



----------------------
--all validations passed, create work order records
BEGIN TRANSACTION
BEGIN TRY

        --insert WorkOrderHeader 
		IF @ll_hdr_cnt > 0 
		BEGIN	
			Exec @ll_ret_hdr=sp_sfdc_woh_Insert @header_response output,@workorder_id_ret output

			if @@ERROR <> 0 Or @ll_ret_hdr < 0
			begin
				--set @response = 'ERROR: Insert into WorkOrderHeader failed'
				Set @response = @header_response		
				goto ON_ERROR
			end

			if @ll_ret_hdr >= 0
			begin	
				Set @response = @header_response	
			end
		END

		--insert WorkOrderDetail

		IF @ll_dtl_cnt > 0 
		BEGIN
			Exec @ll_ret_dtl=sp_sfdc_wod_Insert @detail_response output

			if @@ERROR <> 0 Or @ll_ret_dtl < 0
			begin
				--set @response = 'ERROR: Insert into WorkOrderHeader failed'
				Set @response = @detail_response
				goto ON_ERROR
			end

			if @ll_ret_dtl = 0
			begin	
				Set @response = isnull(@response,' ') +char(13) + char(10)+ isnull(@detail_response	,' ')
			end
		END

		--Note Insert for workorderheader 
		If ((@ll_ret_hdr=0 OR @ll_ret_dtl=0) and  @ll_hdr_cnt > 0) 
		Begin
				set @json_header = ( select * from #sf_header FOR JSON PATH)
		        
				If @ll_ret_hdr <> 0 and @ll_ret_dtl=0 and  @ll_hdr_cnt > 0 
				Begin
				 Set @note_sub='Salesforce Update json-workorderheader'
				End

				If @ll_ret_hdr = 0 and  @ll_hdr_cnt > 0 
				Begin
				 Set @note_sub='Salesforce json-workorderheader'
				End


				EXECUTE @note_id = sp_sequence_next 'note.note_id'	
		       
		       
								INSERT INTO [dbo].note (note_id,
														note_source,
														company_id,
														profit_ctr_id,
														note_date,
														subject,
														status,
														note_type,
														note,
														customer_id,
														contact_id,     
														added_by,
														date_added,
														modified_by,
														date_modified,
														app_source,      
														workorder_id,
														salesforce_json_flag)
														SELECT                             
														@note_id,
														'Workorder',
														@company_id,
														@profit_ctr_id,
														GETDATE(),	
														@note_sub,
														--'SALESFORCE JSON',
														'C',
														'JSON',
														@json_header,
														'',
														'',          
														@user_code,
														GETDATE(),
														@user_code,
														GETDATE(),
														'SFDC',							 
														@workorder_id_ret,
														'Y'
						    
									 if @@error <> 0 						
									 begin						
									  Set @Response = 'Error: Integration failed due to the following reason; could not insert into note table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
   									  goto ON_ERROR
									 end 
          
		 End

		--Note Insert for workorderdetail
		If (@ll_ret_dtl=0 and  @ll_dtl_cnt > 0) 
		Begin
				set @json_detail = (select * from #sf_detail FOR JSON PATH)	 
		        
		  
				 EXECUTE @note_id = sp_sequence_next 'note.note_id'
		 
		
								INSERT INTO [dbo].note (note_id,
														note_source,
														company_id,
														profit_ctr_id,
														note_date,
														subject,
														status,
														note_type,
														note,
														customer_id,
														contact_id,     
														added_by,
														date_added,
														modified_by,
														date_modified,
														app_source,      
														workorder_id,
														salesforce_json_flag)
														SELECT                             
														@note_id,
														'Workorder',
														@company_id,
														@profit_ctr_id,
														GETDATE(),												
														'Salesforce json-workorderdetail',												
														--'SALESFORCE JSON',
														'C',
														'JSON',
														@json_detail,
														'',
														'',          
														@user_code,
														GETDATE(),
														@user_code,
														GETDATE(),
														'SFDC',							 
														@workorder_id_ret,
														'Y'
														
						
									 if @@error <> 0 						
									 begin						
									  Set @Response = 'Error: Integration failed due to the following reason; could not insert into note table;' + isnull(ERROR_MESSAGE(),'Please check log table in EQAI')
   									  goto ON_ERROR
									  end 

		 End

END TRY
BEGIN CATCH
 select @response = 'Error(s):' + char(13) + char(10) + isnull(ERROR_MESSAGE(),'NA')
 goto ON_ERROR
END CATCH

----------------------
--SUCCESS
ON_SUCCESS:
commit transaction
Update sfdc_eqai_log set workorder_id = @workorder_id_ret,status='S',response=@response where sfs_req_uid in (Select max(sfs_req_uid) from sfdc_eqai_log)
return 0


----------------------
--ERROR
ON_ERROR:
rollback transaction
raiserror(@response,18,-1) with seterror

--Update the Log Table Over here With JSON
If @workorder_id_ret is null
Begin
Select @workorder_id_ret=workorder_id from WorkorderHeader with(nolock) where salesforce_invoice_CSID=@salesforce_invoice_csid
End
Update sfdc_eqai_log set workorder_id = @workorder_id_ret,response=@response,status='E' where sfs_req_uid in (Select max(sfs_req_uid) from sfdc_eqai_log)

return -1
End

if @ls_config_value='F'
begin
	Select @Response= 'SFDC Data Integration Failed,since CRM Go live flag phase3 off. Hence Store procedure will not execute.'
	return -1
end

Return 0




GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_insert] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_insert] TO svc_CORAppUser

GO
