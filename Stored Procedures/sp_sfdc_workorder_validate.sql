USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorder_validate]    Script Date: 5/29/2025 4:25:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER       procedure [dbo].[sp_sfdc_workorder_validate]
               @response varchar(4000) output
as
/*  
Description: 

Workorder header and detail Line Validation (This procedure called from sp_sfdc_workorder_insert)
Created By Venu -- 18/Oct/2024
Rally # US129733  - New Design To handle the workorder in Single JSON
Rally # US134603  - Added Profile id for disposal line
Rally # US136352  - Added Manifest_state in validation
US#131404  - 01/09/2025 Venu added logic and removed the generator validation, since new generator should create when workorder created
DE38852 --14/April/2025 -- Nagaraj M -- Added  cust_status ='A' to check only the active d365 customer ids.
DE39418  --05/29/2025 -- Nagaraj M -- Added cust_status='A' in the #sf_header where clause
*/
declare
               @company_id int,
               @profit_ctr_id int,
               @d365_customer_id varchar(10),
               @profit_ctr_status char,
               @customer_status char,
               @project_code varchar(15),
               @salesforce_invoice_CSID varchar(18),
               @salesforce_site_csid varchar(18),
               @workorder_type_id int,
               @employee_id varchar(20),
               @generator_id int,
               @as_site_changed char(1),
               @billing_project_id int,
               @customer_id int,                        
               @salesforce_invoice_line_id varchar(25),
               @resource_type Varchar(1),
               @as_woh_disposal_flag char(1),
               @as_so_disposal_flag char(1),
               @salesforce_so_csid varchar(18),
               @resource_class_code varchar(20),
               @salesforce_resourceclass_CSID varchar(18),
               @bill_unit_code varchar(4),
               @resource_company_id int,
               @TSDF_code varchar(15),
               @sales_tax_line_flag char(1),
               @salesforce_bundle_id varchar(10),
               @manifest varchar(15),
               @TSDF_approval_code varchar(40),
               @salesforce_resource_CSID varchar(18),
               @price money,
               @count int,
               @detail_count int,
               @resource_class_cnt_hdr int,
               @resource_class_cnt_dtl int,
               @wod_line_cnt int,
               @manifest_check_first int,
               @manifest_check_last int,
               @ll_tsdf_approval_cnt int,
               @eq_company int,
               @eq_profit_ctr int,
               @eq_flag char(1),
               @workorder_id int,
               @wod_line_cnt_diff_wo int,
               @header_response varchar(2000)='',
               @detail_response varchar(4000)='',
               @salesforce_invoice_CSID_hdr varchar(18)=Null,
               @hdr_count int =0,
               @wod_line_cnt_req int,
               @old_billunitcode varchar(4),
    @AsMapDisposalLine char(1),
               @ll_cnt_manifest int =0,
               @profile_id int, --nagaraj m
               @workorder_id_ret int,
               @tsdf_approval_id int,
               @ll_cnt_wdunit int=0,
               @count_1 int,
               @sfs_workorderquoteheader_uid int,
               @manifest_state char(1)
               --@EQ_COMPANY int,
               --@EQ_PROFIT_CTR int

set @response = ''
set @header_response=''

--pull values into variables  -- Header

Select @hdr_count=count(*) from #sf_header

If @hdr_count > 0
Begin

select
               @company_id = h.companyid,
               @profit_ctr_id = h.ProfitCenterId,
               @profit_ctr_status = isnull(pc.status,'I'),
               @d365_customer_id = h.d365customerid,
               @Project_code=h.ProjectCode,
               @salesforce_invoice_CSID=h.SalesforceInvoiceCSID,
               @salesforce_site_csid=h.SalesforceSiteCSID,
               @workorder_type_id=h.WorkOrderTypeId,
               @employee_id=h.employee_id,
               @generator_id=h.GeneratorId,
               @as_site_changed=h.AsSiteChanged,
               @billing_project_id=h.BillingProjectId,
               @customer_id=c.customer_id,
               @as_so_disposal_flag=isnull(h.AsSoDisposalFlag,'F'), 
               @salesforce_so_csid=h.SalesforceSoCsid
from #sf_header h
left outer join ProfitCenter pc
               on pc.company_id = h.companyid
               and pc.profit_ctr_id = h.ProfitCenterId
left outer join Customer c
               on c.ax_customer_id = h.d365customerid
			   and c.cust_status='A'

Set @salesforce_invoice_CSID_hdr=@salesforce_invoice_CSID

/*****************   Common Validation ************************************* - Start*/
--company_id
if @company_id is null
               set @response = @response + 'Company ID cannot be null' + char(13) + char(10)

else if not exists (select 1 from Company where company_id = @company_id)
               set @response = @response + 'Company ID ' + convert(varchar(2),@company_id) + ' does not exist in the EQAI Company table' + char(13) + char(10)
               

--profit_ctr_id
if @company_id is null
               set @response = @response + 'Profit Center ID cannot be null.' + char(13) + char(10)

else if not exists (select 1 from ProfitCenter where company_id = @company_id and profit_ctr_id = @profit_ctr_id)
               set @response = @response + 'Profit Center ID ' + convert(varchar(2),@profit_ctr_id) + ' is not valid for Company ID '+ convert(varchar(2),@company_id) + char(13) + char(10)

else if @profit_ctr_status <> 'A'
               set @response = @response + 'Company / Profit Center ' + right('0' + convert(varchar(2),@company_id),2) + '-' + right('0' + convert(varchar(2),@profit_ctr_id),2)
                                                                                                                        + ' is not active' + char(13) + char(10)


--d365_customer_id
if @d365_customer_id is null
               set @response = @response + 'D365 Customer ID cannot be null.' + char(13) + char(10)
else
begin
               select @count = count(*)
               from Customer
               where ax_customer_id = @d365_customer_id and cust_status='A'

               if @count = 0
                              set @response = @response + 'D365 Customer ' + @d365_customer_id + ' does not exist in the EQAI Customer table' + char(13) + char(10)

               else if @count > 1
                              set @response = @response + 'More than one customer in the EQAI Customer table is mapped to D365 Customer ID ' + @d365_customer_id + char(13) + char(10)
end

--employee_id

If @employee_id is null
  set @response = @response + 'Employee id cannot be null.' + char(13) + char(10)
else
begin
  Select @count = count(*)  FROM users  WHERE employee_id  =@employee_id 
   if @count = 0
               set @response = @response + 'Employee_id ' + @employee_id + ' does not exist in the EQAI Users table' + char(13) + char(10)
   else if @count > 1
     Set @Response=  @response + 'Employee ID:'+@employee_id+' exists in EQAI Users table more than one'  + char(13) + char(10)    
end

/*****************   Common Validation ************************************* - End*/

/*****************   Workorderheader Validation ************************************* - Satrt*/

--Project_code

if @Project_code is null
               set @response = @response + 'Project code cannot be null.' + char(13) + char(10)
else
begin
   Select @count = count(*) 
   From WorkOrderQuoteHeader 
   Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and project_code = @Project_code  

   If @count=0
   Begin
    select @sfs_workorderquoteheader_uid = max([sfs_workorderquoteheader_uid])
                                 from SFSWorkOrderQuoteHeader
                                 where company_id = @company_id and profit_ctr_id = @profit_ctr_id and project_code = @Project_code

                    Select @count = count(*) 
                    From sfsWorkOrderQuoteHeader 
                    Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and project_code = @Project_code and sfs_workorderquoteheader_uid=@sfs_workorderquoteheader_uid
   End  


   if @count = 0   
                              set @response = @response + 'project code ' + @Project_code + ' does not exist in the EQAI workorderquoteheader or sfsworkorderquoteheader table' + char(13) + char(10)
   
   Else if @count > 1
   
                              set @response = @response + 'More than one project code linked in EQAI workorderquoteheader or sfsworkorderquoteheader  table for the project code ' + @Project_code +' company '+ str(@company_id) +' Profit center '+str(@profit_ctr_id) + char(13) + char(10)
   
end

--salesforce_invoice_CSID

if @salesforce_invoice_CSID is null
               set @response = @response + 'Salesforce invoice csid cannot be null.' + char(13) + char(10)
else
begin
    If (@salesforce_so_csid <> @salesforce_invoice_CSID) or @as_so_disposal_flag <> 'T'
               Begin
               Select @count = count(*) From WorkOrderHeader  with(nolock) Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and salesforce_invoice_CSID = @salesforce_invoice_CSID 
               If @count > 0
                  set @response = @response + 'Salesforce invoice csid ' + @salesforce_invoice_CSID + ' already exists in workorderheader table' + char(13) + char(10)
    End
end


--salesforce_so_CSID  (Validation not Required)


--salesforce_site_csid
If @salesforce_site_csid is null and @generator_id is null
Begin
  set @response = @response + 'Salesforce site csid and Generator id both cannot be null.' + char(13) + char(10)
End
/*begin
    If @salesforce_site_csid is not null and @as_site_changed <> 'T'
               Begin
               select @count = count(*) from generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS= @salesforce_site_csid and status='A'        
               if @count = 0
                              set @response = @response + 'salesforce site csid ' + @salesforce_site_csid + ' does not exist in the EQAI Generator table' + char(13) + char(10)
    End 
end */

If @salesforce_site_csid is not null and (@generator_id is not null and @generator_id <> '' and @generator_id <> 0 )
Begin
select @count = count(*) from generator Where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and generator_id=@generator_id and status='A'
if @count = 0
                              set @response = @Response + 'received generator id:' +str(@generator_id)+ ' and salesforce site csid:' + @salesforce_site_csid +' not exists in EQAI generator table;' + char(13) + char(10)
end

--Generator_id

If  (@salesforce_site_csid is null or @salesforce_site_csid='') and (@generator_id is not null and @generator_id <> '' and @generator_id <> 0 )
Begin
select @count = count(*) from generator where Generator_id =@generator_id and status='A'           
               if @count = 0
                              set @response = @response + 'Generator id ' + @generator_id + ' does not exist in the EQAI Generator table' + char(13) + char(10)
End

--as_site_changed
/*If (@as_site_changed='T') and (@salesforce_site_csid is null or @salesforce_site_csid ='')
Begin
  Set @Response = @Response +'Site changed flag recevied as True , but salesforce site csid is empty ' + char(13) + char(10)
End */


--workorder_type_id
If @workorder_type_id is null
  set @response = @response + 'workorder type id cannot be null.' + char(13) + char(10)
else
begin
  Select @count = count(*)  FROM WorkOrderTypeHeader   WHERE workorder_type_id =@workorder_type_id 
   if @count = 0
               set @response = @response + 'workorder type id ' + str(@workorder_type_id) + ' does not exist in the EQAI WorkOrderTypeHeader table' + char(13) + char(10)
end



--billing_project_id
If @billing_project_id IS NOT NULL
Begin
               Select @count = count(*) from customerbilling where customer_id=@customer_id and billing_project_id=@billing_project_id and status='A'
               If @count=0
                 Set @Response = @Response +'received Billing project id:' +str(@billing_project_id)+ '  not exists or not an active status in EQAI customerbilling tablefor the customer ' + str(@customer_id) + char(13) + char(10)
End

--@as_so_disposal_flag & @as_salesforce_so_csid

If @as_so_disposal_flag='T' and @salesforce_so_csid is null
Begin
Set @Response = @Response +'Salesforce SO csid required , since disposal flag received as True' + char(13) + char(10)
End

If @as_so_disposal_flag='T' and @salesforce_so_csid is not null
Begin
   Select @count=count(*) from workorderheader where salesforce_so_csid=@salesforce_so_csid and company_id=@company_id and profit_ctr_ID=@profit_ctr_id
   If @count = 0
   Begin
  /* Begin
    If @salesforce_invoice_CSID_hdr <> @salesforce_so_csid
               Begin
                 Set @Response = @Response +'Salesforce SO csid and invoice csid mismatched for the header request, since disposal flag received as True' + char(13) + char(10)
               End
   End */ --Commented since it's blocking if SO created without disposal during T&M if user added Disposal line this msg shouldn't occired.
   Select @count=count(*) from #sf_detail where SalesforceSoCsid <> @salesforce_so_csid 
   If @count > 0
    Set @Response = @Response +'Header and Detail salesforce SO CSID inconsistent.Please check the JSON' + char(13) + char(10) 
   End
End 

If @as_so_disposal_flag='T'
Begin
  Select @count=count(*) from #sf_detail where AsWohDisposalFlag='F'
  If @count > 0
    Set @Response = @Response +'Detail request few lines recevied disposal flag as False. But header recevied as True' + char(13) + char(10) 
End

If @as_so_disposal_flag='F'
Begin
  Select @count=count(*) from #sf_detail where AsWohDisposalFlag='T'
  If @count > 0
    Set @Response = @Response +'Detail request few lines recevied disposal flag as True. But header recevied as False' + char(13) + char(10) 
End

If @salesforce_invoice_CSID is not null and @salesforce_invoice_CSID <> @salesforce_so_CSID
Begin
   Select @count=count(*) from #sf_detail where SalesforceInvoiceCSID <> @salesforce_invoice_CSID 
   If @count > 0
    Set @Response = @Response +'Header and Detail salesforce invoice CSID inconsistent. Please check the JSON ' + char(13) + char(10) 
End

If len(@response) > 0
Begin
   Set @header_response=@response
   Set @response=''
End 

End




/*****************   Workorderheader Validation ************************************* - End*/


/*****************   Workorderdetail Validation ************************************* - Start*/


--pull values into variables  -- Detail

Declare detail_validation CURSOR fast_forward for
select   d.companyid,
                              d.ProfitCenterId,
                              isnull(pc.status,'I'),         
                              d.ResourceType,
                              d.ResourceClassCode,
                              d.SalesforceResourceClassCSID,
                              d.BillUnitCode,        
                              d.SalesforceInvoiceLineId,
                              d.SalesforceInvoiceCSID,           
                              d.employee_id,                
                              isnull(d.AsWohDisposalFlag,'F'),
                              d.SalesforceSoCsid,
                              d.ResourceCompanyId,
                              d.TSDFcode,
                              d.SalesTaxLineFlag,
                              d.SalesforceBundleId,
                              d.manifest,
                              d.TsdfApprovalCode,
                              d.SalesforceResourceCsId ,
                              d.price,
                              d.workorder_id,
                              d.old_billunitcode,
                              isnull(d.AsMapDisposalLine,'I'),
                              d.Profileid ,
                              d.Manifest_state
                              from #sf_detail d
                                                                                                                                         left outer join ProfitCenter pc
                                                                                                                                         on pc.company_id = d.companyid
                                                                                                                                         and pc.profit_ctr_id = d.ProfitCenterId
Open detail_validation
fetch next from detail_validation into  @company_id,
                                                                                                                                                      @profit_ctr_id,
                                                                                                                                                      @profit_ctr_status,
                                                                                                                                                      @resource_type,
                                                                                                                                                      @resource_class_code,
                                                                                                                                                      @salesforce_resourceclass_CSID,
                                                                                                                                                      @bill_unit_code,
                                                                                                                                                      @salesforce_invoice_line_id,
                                                                                                                                                      @salesforce_invoice_CSID,
                                                                                                                                                      @employee_id,
                                                                                                                                                      @as_woh_disposal_flag,
                                                                                                                                                      @salesforce_so_csid,
                                                                                                                                                      @resource_company_id,
                                                                                                                                                      @TSDF_code,
                                                                                                                                                      @sales_tax_line_flag,
                                                                                                                                                      @salesforce_bundle_id,
                                                                                                                                                      @manifest,
                                                                                                                                                      @TSDF_approval_code,
                                                                                                                                                      @salesforce_resource_CSID,
                                                                                                                                                      @Price,
                                                                                                                                                      @workorder_id,
                                                                                                                                                      @old_billunitcode,
                                                                                                                                                      @AsMapDisposalLine,
                                                                                                                                                      @profile_id,
                                                                                                                                                      @manifest_state
While @@fetch_status=0
                              Begin                                  
                              
                              Set @Response=''
                              /*****************   Common Validation ************************************* - Start*/
                              --company_id
                              if @company_id is null
                                             set @response = @response + 'Company ID cannot be null' + char(13) + char(10)

                              else if not exists (select 1 from Company where company_id = @company_id)
                                             set @response = @response + 'Company ID ' + convert(varchar(2),@company_id) + ' does not exist in the EQAI Company table' + char(13) + char(10)
               

                              --profit_ctr_id
                              if @company_id is null
                                             set @response = @response + 'Profit Center ID cannot be null.' + char(13) + char(10)

                              else if not exists (select 1 from ProfitCenter where company_id = @company_id and profit_ctr_id = @profit_ctr_id)
                                             set @response = @response + 'Profit Center ID ' + convert(varchar(2),@profit_ctr_id) + ' is not valid for Company ID '+ convert(varchar(2),@company_id) + char(13) + char(10)

                              else if @profit_ctr_status <> 'A'
                                             set @response = @response + 'Company / Profit Center ' + right('0' + convert(varchar(2),@company_id),2) + '-' + right('0' + convert(varchar(2),@profit_ctr_id),2)
                                                                                                                                                      + ' is not active' + char(13) + char(10)


                              --d365_customer_id
                              /*if @d365_customer_id is null
                                             set @response = @response + 'D365 Customer ID cannot be null.' + char(13) + char(10)
                              else
                              begin
                                             select @count = count(*)
                                             from Customer
                                             where ax_customer_id = @d365_customer_id

                                             if @count = 0
                                                            set @response = @response + 'D365 Customer ' + @d365_customer_id + ' does not exist in the EQAI Customer table' + char(13) + char(10)

                                             else if @count > 1
                                                            set @response = @response + 'More than one customer in the EQAI Customer table is mapped to D365 Customer ID ' + @d365_customer_id + char(13) + char(10)
                              end */

                              --employee_id

                              If @employee_id is null
                                set @response = @response + 'Employee id cannot be null.' + char(13) + char(10)
                              else
                              begin
                                Select @count = count(*)  FROM users  WHERE employee_id  =@employee_id 
                                 if @count = 0
                                             set @response = @response + 'Employee ID ' +@employee_id + ' does not exist in the EQAI Users table' + char(13) + char(10)
                                 else if @count > 1
                                             Set @Response=  @response + 'Employee ID:'+@employee_id+' exists in EQAI Users table more than one'  + char(13) + char(10)    
                              end

                              /*****************   Common Validation ************************************* - End*/
                                                            
                              If @resource_type is null
                                set @response = @response + 'Resource type cannot be null.' + char(13) + char(10)
                              else
                              begin
                                Select @count = count(*)  FROM resourcetype WHERE resource_type =@resource_type 
                                 if @count = 0
                                             set @response = @response + 'Resource type ' + @resource_type + ' does not exist in the EQAI Resource table' + char(13) + char(10)
                              end

                              If @resource_class_code is null
                              begin
                                set @response = @response + 'Resource class code cannot be null.' + char(13) + char(10)
        end  
        
                              If @sales_tax_line_flag='F' and @resource_type <> 'D'
                              Begin
                                             If @salesforce_resourceclass_CSID is null
                                               set @response = @response + 'Salesforce resource class csid cannot be null.' + char(13) + char(10)
                                             else
                                             begin
                                               Select @count = count(*)  FROM resourceclassheader WHERE salesforce_resourceclass_csid =@salesforce_resourceclass_CSID 
                                                if @count = 0
                                                            set @response = @response + 'Salesforce resource class csid ' + @resource_type + ' does not exist in the EQAI resourceclassheader table' + char(13) + char(10)
                                             end 
                              end

                              If @salesforce_resourceclass_CSID IS NOT NULL and @resource_class_code IS NOT NULL and @resource_type <>'D'
                              Begin
                                
                                select  @resource_class_cnt_hdr= count(*) from resourceclassheader where   resource_class_code=@resource_class_code and 
                                                                                                                                                                                                                                                                                                                            resource_type=@resource_type and 
                                                                                                                                                                                                                                                                                                                            status='A' and 
                                                                                                                                                                                                                                                                                                                            salesforce_resourceclass_csid=@salesforce_resourceclass_csid

          select  @resource_class_cnt_dtl= count(*) from resourceclassdetail where    resource_class_code=@resource_class_code and 
                                                                                                                                                                                                                                                                                                                            company_id=@company_id and 
                                                                                                                                                                                                                                                                                                                            profit_ctr_id = @profit_ctr_id and
                                                                                                                                                                                                                                                                                                                           bill_unit_code=@bill_unit_code and
                                                                                                                                                                                                                                                                                                                            status='A'
                                             If            @resource_class_cnt_hdr = 0 Or @resource_class_cnt_dtl=0 
                                              Begin
                                                set @response = @response + 'Resource class coded ' + @resource_class_code + ' does not exist in the EQAI EQAI resourceclassheader or resourceclassdetail table' + char(13) + char(10)
                                             End
                              end

                              If @salesforce_invoice_line_id is null
                                               set @response = @response + 'Salesforce invoice line id cannot be null.' + char(13) + char(10)                                  
                              Else if @salesforce_invoice_line_id is not null and @sales_tax_line_flag='F'             
                              Begin                                                 
                              Select @wod_line_cnt = count(*) from workorderdetail wd with(nolock)
                                                                                                            Inner Join workorderheader wh ON wh.workorder_id=wd.workorder_id and
                                                                                                                                                                                                                                                wh.company_id=wd.company_id and
                                                                                                                                                                                                                                                wh.profit_ctr_id=wd.profit_ctr_id and
                                                                                                                                                                                                                                                wd.salesforce_invoice_line_id=@salesforce_invoice_line_id and
                                                                                                                                                                                                                                                wd.company_id=@company_id and
                                                                                                                                                                                                                                                wd.profit_ctr_id=@profit_ctr_id and
                                                                                                                                                                                                                                                wh.salesforce_invoice_csid=@salesforce_invoice_CSID 

          Select @wod_line_cnt_req = count(*) from #sf_detail where SalesforceInvoiceLineId=@salesforce_invoice_line_id and
                                                                                                                                                                                                                                                                 companyid=@company_id and
                                                                                                                                                                                                                                                                 ProfitCenterId=@profit_ctr_id

          If @workorder_id is not null and @as_woh_disposal_flag='T'
                                Begin
                                   Select @wod_line_cnt_diff_wo = count(*) from workorderdetail with(nolock)      where workorder_id=@workorder_id and 
                                                                                                                                                                                                                                                                                                              company_id=@company_id and
                                                                                                                                                                                                                                                                                                              profit_ctr_id=@profit_ctr_id and
                                                                                                                                                                                                                                                                                                              salesforce_invoice_line_id=@salesforce_invoice_line_id

                                End
                                                                           
                                If @wod_line_cnt_diff_wo > 0 Or @wod_line_cnt > 0     
                                                Set @Response=  @response + 'Salesforce invoice line ID:'+@salesforce_invoice_line_id+' already exists in EQAI workorderdetail table '  + char(13) + char(10)    
                                
          If @wod_line_cnt_req > 1 
                                   Set @Response=  @response + 'Salesforce invoice line ID:'+@salesforce_invoice_line_id+' duplicate in recevied JSON '  + char(13) + char(10)  
                                              
                              End

                              If @bill_unit_code is not null
                              Begin
                              Select @count = count(*) from billunit WHERE bill_unit_code= @bill_unit_code
                              if @count = 0
                                                            set @response = @response + 'Bill unit code ' + @bill_unit_code + ' does not exist in the EQAI billunit table' + char(13) + char(10)
                              End

                              If @resource_type in ('E', 'L') and @resource_company_id is null
                                 set @response = @response + 'Resource company id cannot be null.' + char(13) + char(10)        
                              Else 
                              If @resource_type in ('E', 'L') and @resource_company_id is not null
                              Begin
                                Select @count = count(*) from  Company where company_id=@resource_company_id
                                If @count=0
                                  set @response = @response + 'Resource company id ' + str(@resource_company_id) + ' does not exist in the EQAI Company table' + char(13) + char(10)
                              End        

                              If @resource_type in ('E', 'L') and @salesforce_resource_csid is null
                              Begin
                                set @response = @response + 'Salesforce resource csid cannot cannot be null.' + char(13) + char(10)
                              End


                              If @resource_company_id  is not null and @salesforce_resource_csid is not null and  @resource_type in ('E', 'L')
                              Begin
                                Select @count=count(*) from dbo.resource where salesforce_resource_csid=@salesforce_resource_csid
                                                                                                                                                                                                                                                and company_id=@resource_company_id 
           If @count=0 or @count > 1
                                    Set @response = @response + 'Resource not exists for the salesforce resource csid '+ @salesforce_resource_csid + ' and resource company id' + str(@resource_company_id) + char(13) + char(10)
                              End


                              If @salesforce_invoice_CSID is null                     
                                 set @response = @response + 'Salesforce invoice CSID cannot be null.' + char(13) + char(10)       
        Else                             
                              If @salesforce_invoice_CSID_hdr <> @salesforce_invoice_CSID and @salesforce_invoice_CSID_hdr is not null and @as_woh_disposal_flag <> 'T' 
                              Begin
                                 set @response = @response + 'Salesforce invoice CSID ' + @salesforce_invoice_CSID + ' does not match with header request,in header we recevied as '+@salesforce_invoice_CSID_hdr + char(13) + char(10)
        End
                              
                              If @salesforce_invoice_CSID is not null             
                              Begin
                                Select @count = count(*) from #sf_detail where @salesforce_invoice_CSID <> @salesforce_invoice_CSID 
                                               If @count > 0 
                                                            Begin 
                                                              set @response = @response + 'Differnt Salesforce invoice csid recvied for the single request.please check detail request' + char(13) + char(10)
                                                            End

                                               If @as_woh_disposal_flag <> 'T'
                                               Begin
                                                            Select @count = count(*) from #sf_header where @salesforce_invoice_CSID = @salesforce_invoice_CSID and companyid=@company_id and profitcenterid=@profit_ctr_id                                                      
                                                            If @count = 0                                                 
                                                             Begin                                                
                                                               Select @count = count(*) from workorderheader where salesforce_invoice_CSID = @salesforce_invoice_CSID and company_id=@company_id and profit_ctr_ID=@profit_ctr_id                                                             
                 End  
                                                            If @count = 0 
                                                            Begin
                                                                set @response = @response + 'Salesforce invoice csid not exists for the header request.please check detail request' + char(13) + char(10)
                End                                                     
                                               End
                              End

       
                              
        /*Else
                              If @salesforce_invoice_CSID is not null
                              Begin
                                Select @count = count(*) From WorkOrderHeader Where company_id = @company_id and profit_ctr_id = @profit_ctr_id and salesforce_invoice_CSID = @salesforce_invoice_CSID
                                If @count=0
                                   set @response = @response + ' salesforce invoice CSID ' + @salesforce_invoice_CSID + ' does not exist in the EQAI WorkOrderHeader table' + char(13) + char(10)
                              End */
       
                   If @sales_tax_line_flag = 'T' and  @resource_type <> 'O'
                              Begin
                                  set @response = @response + 'Sales tax invoice line is not applicable for the resource type: '+@resource_type + char(13) + char(10)
                              End

                              If @sales_tax_line_flag = 'T' and  @salesforce_bundle_id is not null
                              Begin
                                set @response = @response + 'Sales tax invoice line can not set as a parent bundle: '+@salesforce_bundle_id + char(13) + char(10)
                              End

                              If @sales_tax_line_flag = 'T' and @resource_class_code <> 'FEESLSTX'
                              Begin
                                set @response = @response + 'Sales tax invoice line resource class code should:FEESLSTX but received as: '+@resource_class_code + char(13) + char(10)
                              End

                              If @salesforce_bundle_id is not null and @resource_type not in('O','D') --Check the parent bundle
                              Begin
                              
                                 Select @count = count(*) from workorderdetail wd with(nolock)
                                                                                                            Inner Join workorderheader wh ON wh.workorder_id=wd.workorder_id and
                                                                                                                                                                                                                                                wh.company_id=wd.company_id and
                                                                                                                                                                                                                                                wh.profit_ctr_id=wd.profit_ctr_id and                                                                                                                                                                                                                                   
                                                                                                                                                                                                                                                wd.company_id=@company_id and
                                                                                                                                                                                                                                                wd.profit_ctr_id=@profit_ctr_id and
                                                                                                                                                                                                                                                wd.salesforce_bundle_id=@salesforce_bundle_id and
                                                                                                                                                                                                                                                wh.salesforce_invoice_csid=@salesforce_invoice_CSID and
                                                                                                                                                                                                                                                resource_type ='O'
          If @count=0
                                Begin
                                  Select @count = count(*) from #sf_detail where SalesforceBundleId=@salesforce_bundle_id and ResourceType ='O'
                                End

          If @count=0
                                   set @response = @response + 'Bundle ID received as '+@salesforce_bundle_id+ ' So before submitting a child bundle line, the parent bundle line should exists for the resource type OTHER' + char(13) + char(10)
                              End

                              If @salesforce_bundle_id is not null and @resource_type not in('O','D') and @price > 0 --Check the child bundle
                              Begin
                                  set @response = @response + 'Bundle ID received as ' +@salesforce_bundle_id+ ' child bundle Quote line price should not be grater than $0;' + char(13) + char(10)
                              End

                              /*Disposal Line Validation -- Start */
                              
                              IF  @as_woh_disposal_flag='T' and @salesforce_so_csid is not null
                              Begin
                                 select @count=count(*) from workorderheader with(nolock) where  salesforce_so_csid=@salesforce_so_csid and
                                                                                     (salesforce_invoice_csid=@salesforce_so_csid or salesforce_invoice_csid=@salesforce_invoice_csid)
                                                                                    and company_id=@company_id 
                                                                                                                                                                                                                                   and profit_ctr_id=@profit_ctr_id


                                If @count=0
                                Begin
                                  Select @count = count(*) from #sf_header where salesforcesocsid=@salesforce_so_csid 
                                                                                                                                                                                                                                 and (salesforceinvoicecsid=@salesforce_so_csid OR salesforceinvoicecsid=@salesforce_invoice_csid)
                                                                                                                                                                                                                                 and companyid=@company_id 
                                                                                                                                                                                                                                 and ProfitCenterId=@profit_ctr_id
                                End
                                
                                 If @count=0 and @resource_type='D'
                                   set @response = @response + 'Header record not exists for salesforce SO CSID ' + @salesforce_so_csid + 'This is Disposal line,should header records exists to process this detail line' + char(13) + char(10)
           Else If @count=0 and @resource_type <> 'D'
                                   set @response = @response + 'Header record not exists for salesforce SO CSID ' + @salesforce_so_csid + 'This line recevied along with Disaposal,should header records exists to process this detail line' + char(13) + char(10)
                              End  

                              If @as_woh_disposal_flag='T' and @salesforce_so_csid is null
                              Begin
                                             set @response = @response + 'Salesforce SO csid required for Disposal line' + char(13) + char(10)
                              End

                              If (@as_woh_disposal_flag='F' and @workorder_id is not null) or @workorder_id is not null and @resource_type <> 'D'
                              Begin
                                             set @response = @response + 'Workorder id should empty,since Disposal line flag recevied as False' + char(13) + char(10)
                              End
                              

                              IF  @as_woh_disposal_flag='F' and @salesforce_so_csid is not null
                              Begin
                                 set @response = @response + 'Salesforce SO csid should empty,since Disposal line flag recevied as False' + char(13) + char(10)
                              End
         
                               IF @resource_type='D'
                              Begin
                                  
                                  If @manifest_state is null
                                             Begin
                                               set @response = @response + 'Manifest State required for Disposal line' + char(13) + char(10)
                                             End

                                  If  @manifest is null
                                             Begin
                                               set @response = @response + 'Manifest required for Disposal line' + char(13) + char(10)
                                             End

                                             if @profile_id is null
                                             Begin
                                                            set @response = @response + 'Profile id cannot be null,since this is disposal line.' + char(13) + char(10)
                                             end


                                             --To Check the Manifest format
                                             If @manifest_state='H'
                                             Begin
                                             If @manifest is not null
                                             Begin
                                               If len(trim(@manifest)) < 10 or len(trim(@manifest)) > 12
                                                  set @response = @response + ' As per the EQAI standard manifest length should be 10 to 12 for the resource type Disposal' + char(13) + char(10)
              Else if  SUBSTRING(trim(@manifest),1,9) = 'MANIFEST_' and  (len(trim(@manifest)) < 10 or    len(trim(@manifest)) >12 ) 
                                                  set @response = @response + ' Recevied Manifest:' +@manifest+ ' Invalid format for the resource type Disposal' + char(13) + char(10)
              
                                               If SUBSTRING(@MANIFEST,1,9) <> 'MANIFEST_' and len(@manifest) =12      
                                               Begin
                                                  SELECT @manifest_check_first = isnumeric(substring(@manifest,1,9))
                                                            SELECT @manifest_check_last = isnumeric(substring(@manifest,10,12))
                                                            if @manifest_check_first = 0 or @manifest_check_last = 1
                                                                set @response = @response + ' Recevied Manifest:' +@manifest+ ' Invalid format for the resource type Disposal' + char(13) + char(10)
                                               End                                          
                                             End
                                             End
                                             If  @TSDF_code is null
                                                            set @response = @response + 'TSDF code cannot be null.' + char(13) + char(10)          
                                             else 
                                             begin
                                                            Select @count = count(*)  FROM tsdf WHERE tsdf_code =@tsdf_code and tsdf_status='A'
                                                            if @count=0
                                                                           set @response = @response + 'TSDF code ' + str(@resource_company_id) + ' does not exist in the EQAI TSDF table or not an active status' + char(13) + char(10)
                                             end        

                                             If @TSDF_approval_code is null                                          
                                                 set @response = @response + 'TSDF Approval code required for Disposal line' + char(13) + char(10)
             
                                              
                                              If @TSDF_approval_code is not null and @TSDF_code is not null
                                             Begin
                Select @eq_flag=isnull(EQ_FLAG,'F'),@eq_company=eq_company,@eq_profit_ctr=eq_profit_ctr FROM TSDF WHERE TSDF_CODE=@TSDF_CODE AND TSDF_STATUS='A'

                                                            If @eq_flag='T' 
                                                             Begin
                                                               select @ll_tsdf_approval_cnt = count(*) from profilequoteapproval  where approval_code=@TSDF_approval_code
                                                                                                                                                                                                                                                                                             and company_id=@eq_company and profit_ctr_id=@eq_profit_ctr and status='A'
                 End

                if @eq_flag <> 'T'
                                                            Begin
                                                                select @ll_tsdf_approval_cnt=count(*) from tsdfapproval where tsdf_code=@tsdf_code and TSDF_approval_code=@TSDF_approval_code
                                                                                                                                                                                                                                                and company_id=@company_id and profit_ctr_id=@profit_ctr_ID and TSDF_approval_status='A'                                    
                End

                                                            If @ll_tsdf_approval_cnt = 0 and @EQ_FLAG='T'
                                                               set @response = @response + 'TSDF approval code:'+@TSDF_approval_code +' not exists in tsdfapproval for the tsdf code,eq company id and eq profit center id:'+@tsdf_code+', '+str(@eq_company) +' and'+str(@eq_profit_ctr) + char(13) + char(10)
                                                            
                                                            If @ll_tsdf_approval_cnt = 0 and @EQ_FLAG <> 'T'
                                                               set @response = @response + 'TSDF approval code:'+@TSDF_approval_code +' not exists in tsdfapproval for the tsdf code,company id and  profit center id:'+@tsdf_code+', '+str(@company_id) +' and'+str(@profit_ctr_id) + char(13) + char(10)

             End          
                                             
                                              If @workorder_id is not null
                                             Begin
                                               Select @count=count(*) from workorderheader with(nolock) where workorder_ID=@workorder_id and company_id=@company_id and profit_ctr_ID=@profit_ctr_id
                                                If @count=0
                                                  set @response = @response + 'Workorder ID ' + str(@workorder_id) + ' does not exist in the EQAI wokorderheader table' + char(13) + char(10)
                                             End

                              End
                              
                               If @resource_type='D' and @as_woh_disposal_flag='T' and @AsMapDisposalLine='I' and @old_billunitcode is null
                                  set @response = @response + 'Old Bill unit code Required for the dispoosal line indirect method.' + char(13) + char(10)

                  If @resource_type='D' and @as_woh_disposal_flag='T' and @AsMapDisposalLine='I' and @old_billunitcode is not null and @old_billunitcode <> @bill_unit_code
                  Begin
                                 Select @EQ_FLAG=EQ_FLAG,@eq_company=eq_company,@eq_profit_ctr=eq_profit_ctr FROM TSDF WHERE TSDF_CODE=@TSDF_CODE AND TSDF_STATUS='A'

                                     If @EQ_FLAG is null or @EQ_FLAG=''
                                                Begin
                                                                           Set @EQ_FLAG='F'
                                                End
         
                                 Select @ll_cnt_manifest=COUNT(*) FROM  WorkorderManifest wm with(nolock)
                                                                        INNER JOIN workorderheader wh ON                               
                                                                                                                                                                                                    wh.salesforce_invoice_csid=@salesforce_invoice_CSID
                                                                                                                                                                                                                                                AND wm.WORKORDER_ID=wh.workorder_id
                                                                                                                                                                                                                                                AND wm.MANIFEST=TRIM(@MANIFEST)
                                                                                                                                                                                                                                                AND wm.company_id=@company_id
                                                                                                                                                                                                                                                AND wm.profit_ctr_ID=@profit_ctr_ID 
                                                                                                                                                                                                                                                AND wm.company_id=wh.company_id
                                                                                                                                                                                                                                                AND wm.profit_ctr_ID=wh.profit_ctr_ID
                              
                                                            
                                If @eq_flag='T' and @ll_cnt_manifest > 0 
                                Begin  

                                               /*select @profile_id = profile_id from profilequoteapproval  where approval_code=@TSDF_approval_code
                                                                                                                                                                                                                                                                                             and company_id=@EQ_COMPANY 
                                                                                                                                                                                                                                                                                             and profit_ctr_id=@EQ_PROFIT_CTR 
                                                                                                                                                                                                                                                                                             and status='A' 
                                             */
                                               Select @workorder_id_ret = workorder_id from workorderheader with(nolock) where salesforce_invoice_csid=@salesforce_invoice_CSID
                                                                                                                                                                                                                                                                                                            and company_id=@company_id
                                                                                                                                                                                                                                                                                                            and profit_ctr_ID=@profit_ctr_ID   

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
                                                                                                                                                      and wdu.bill_unit_code=@old_billunitcode
                                                                                                                                                      --and wdu.bill_unit_code=@bill_unit_code
       
           End  


                              If @eq_flag='F' and @ll_cnt_manifest > 0 
                               Begin   
                              /*select @tsdf_approval_id=tsdf_approval_id from tsdfapproval 
                                                                                                     where tsdf_code=@tsdf_code
                                                                                                                                                                                                                                                                              and TSDF_approval_code=@TSDF_approval_code
                                                                                                                                                                                                                                                                              and company_id=@company_id 
                                                                                                                                                                                                                                                                              and profit_ctr_id=@profit_ctr_ID 
                                                                                                                                                                                                                                                                              and TSDF_approval_status='A'
                              */
          Select @workorder_id_ret = workorder_id from workorderheader with(nolock) where salesforce_invoice_csid=@salesforce_invoice_CSID
                                                                                                   and company_id=@company_id
                                                                                                                                                                                                                                                             and profit_ctr_ID=@profit_ctr_ID   

                     Select @ll_cnt_wdunit=count(*) from WorkorderDetailunit wdu with(nolock)
                                                          INNER JOIN workorderdetail wd ON  
                                                                                                                                       wd.TSDF_approval_id= @profile_id --@TSDF_approval_id Nagaraj M.
                                                                                                                                       and wd.workorder_ID=@workorder_id_ret
                                                                                                                                       and wd.company_id=@company_id                                                                                                                                       
                                                                                                                                       and wd.profit_ctr_ID=@profit_ctr_ID
                                                                                                                                       and wd.workorder_ID=wdu.workorder_ID
                                                                                                                                       and wd.company_id=wdu.company_id
                                                                                                                                       and wd.profit_ctr_ID=wdu.profit_ctr_ID
                                                                                                                                       and wd.sequence_id=wdu.sequence_id
                                                                                                                                       and wdu.bill_unit_code=@old_billunitcode
       
          End             
                                If @ll_cnt_wdunit > 0 
                                   set @response = @response + 'Recevied request to update the bill unit code '+@bill_unit_code+ ' for the dispoosal line. But same bill unit code already exists.' + char(13) + char(10)
                 End      


                              /*Disposal Line Validation -- End */
                              
                               --set @response =  @response 
                               If len(@Response) > 0
                              Begin
                                  Set @detail_response= @detail_response + char(13) + char(10)+ 'Detail validation error for the Invoice line:' + @salesforce_invoice_line_id + char(13) + char(10) + @response
         End
                              
                               If len(@header_response) > 0 and len(@detail_response) > 0                
                              Begin
                                  Set @Response=  'Header Validation Error'  + char(13) + char(10) + @header_response + char(13) + char(10) + @detail_response
                              End
                              If len(@header_response) > 0 and (len(@detail_response) = 0 or @detail_response='')                   
                               Begin
                                             Set @Response='Header Validation Error'  + char(13) + char(10) + @header_response
         End 
         If len(@detail_response) > 0 and (len(@header_response) = 0 or @header_response='')                               
                               Begin
                                             Set @Response=@detail_response
         End
                              

                              fetch next from detail_validation into  @company_id,
                                                                                                                                                      @profit_ctr_id,
                                                                                                                                                      @profit_ctr_status,
                                                                                                                                                      @resource_type,
                                                                                                                                                      @resource_class_code,
                                                                                                                                                      @salesforce_resourceclass_CSID,
                                                                                                                                                      @bill_unit_code,
                                                                                                                                                      @salesforce_invoice_line_id,
                                                                                                                                                      @salesforce_invoice_CSID,
                                                                                                                                                      @employee_id,
                                                                                                                                                      @as_woh_disposal_flag,
                                                                                                                                                      @salesforce_so_csid,
                                                                                                                                                      @resource_company_id,
                                                                                                                                                      @TSDF_code,
                                                                                                                                                      @sales_tax_line_flag,
                                                                                                                                                      @salesforce_bundle_id,
                                                                                                                                                      @manifest,
                                                                                                                                                      @TSDF_approval_code,
                                                                                                                                                      @salesforce_resource_CSID,
                                                                                                                                                      @Price,
                                                                                                                                                      @workorder_id,
                                                                                                                                                      @old_billunitcode,
                                                                                                                                                      @AsMapDisposalLine,
                                                                                                                                                      @profile_id,
                                                                                                                                                      @manifest_state
                              End                       
Close detail_validation
DEALLOCATE detail_validation 

If len(@header_response) > 0 and (len(@detail_response) = 0 or @detail_response='')                               
Begin
               Set @Response='Header Validation Error'  + char(13) + char(10) + @header_response
End 

/*****************   Workorderdetail Validation ************************************* - End*/


--etc

return 0

GO









GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_validate] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_validate] TO svc_CORAppUser

GO
