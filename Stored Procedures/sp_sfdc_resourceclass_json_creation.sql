USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_resourceclass_json_creation]    Script Date: 4/29/2025 5:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create OR Alter procedure [dbo].[sp_sfdc_resourceclass_json_creation]
	@resource_class_code varchar(10),@resource_type char(1),@company_id int ,@profit_ctr_id int,@bill_unit_code varchar(4),@response varchar(2500) output
As
/*  
Description: 
New Resource class / update resource class JSON paylod to send salesforce
Created By Venu -- 12/Feb/2025 US149416
US# 153392  - 5/20/2025 Venu R Modified JSON SQL

Declare
@response varchar(500)
Begin
Exec [dbo].[sp_sfdc_resourceclass_json_creation] 'TEST_SYNC','L','71','75','1.5Y',@response
Print @response
End

*/
declare
@ls_config_value Char(1),
@cnt int,
@base_quote_id int 
	

select @ls_config_value = config_value from configuration where config_key='CRM_Golive_flag_Resource_Sync'

if coalesce(@ls_config_value,'') = ''
   set @ls_config_value='F'

If @ls_config_value='T'
Begin
set transaction isolation level read uncommitted

select Distinct @base_quote_id= quote_id FROM WorkorderQuoteHeader 
	WHERE WorkorderQuoteHeader.company_id =@company_id and
	     -- WorkorderQuoteHeader.profit_ctr_id =@profit_ctr_id  and
	      WorkorderQuoteHeader.quote_type = 'B'  

If @base_quote_id is null or @base_quote_id=''
Begin
 raiserror('ERROR: attempt to create and populate JSON. Base quote id not found in workorderquoteheader table',18,-1) with seterror
 return -1
End

Select @cnt=count(*) from resourceclassheader rch
Right outer join resourceclassdetail rcd on rch.resource_class_code=rcd.resource_class_code and rcd.company_id=@company_id and rcd.profit_ctr_id=@profit_ctr_id and rcd.bill_unit_code=@bill_unit_code
Right outer join workorderquotedetail wqd on wqd.quote_id=@base_quote_id and wqd.company_id=@company_id and wqd.profit_ctr_id=@profit_ctr_id and wqd.bill_unit_code=@bill_unit_code and resource_item_code=@resource_class_code and wqd.resource_type=@resource_type
where rch.resource_class_code=@resource_class_code and rch.resource_type=@resource_type

						
If @cnt=0 or @cnt > 1 
Begin
 raiserror('ERROR: attempt to create and populate JSON. Resource class not found or more than one code found in the table',18,-1) with seterror
 return -1
End

Set @Response= (Select ResourceclassHeader.resource_class_code AS 'ResourceclassHeader.resource_class_code',
       ResourceclassHeader.resource_type AS 'ResourceclassHeader.resource_type',
	   ResourceclassHeader.status AS 'ResourceclassHeader.status',
	   ResourceclassHeader.description AS 'ResourceclassHeader.description',
	   ResourceclassHeader.salesforce_resourceclass_csid AS 'ResourceclassHeader.salesforce_resourceclass_csid',
	   (Select ResourceclassDetail.bill_unit_code,ResourceclassDetail.company_id,
	   ResourceclassDetail.profit_ctr_id,
	   ResourceclassDetail.rc_detail_csid,
	   cast(ResourceclassDetail.cost as decimal(16,2)) as cost,
	   --cast(wqd.cost as decimal(16,2)) as cost ,
	   cast(wqd.price as decimal(16,2)) as price   
	   from resourceclassheader ResourceclassHeader (nolock)
	   Right outer JOIN resourceclassdetail ResourceclassDetail   (nolock) ON ResourceclassHeader.resource_class_code=ResourceclassDetail.resource_class_code and 
															   ResourceclassDetail.company_id=@company_id and 
															   ResourceclassDetail.profit_ctr_id=@profit_ctr_id and 
															   ResourceclassDetail.bill_unit_code=@bill_unit_code
	   Right outer join workorderquotedetail wqd (nolock) on wqd.quote_id=@base_quote_id and 
															  wqd.company_id=@company_id and 
															  wqd.profit_ctr_id=@profit_ctr_id and 
															  wqd.bill_unit_code=@bill_unit_code and 
															  resource_item_code=@resource_class_code and 
															  wqd.resource_type=@resource_type
		where ResourceclassHeader.resource_class_code=@resource_class_code and ResourceclassHeader.resource_type=@resource_type
		FOR JSON PATH,INCLUDE_NULL_VALUES) AS ResourceclassDetail
from resourceclassheader ResourceclassHeader (nolock)
Right outer JOIN resourceclassdetail ResourceclassDetail   (nolock) ON ResourceclassHeader.resource_class_code=ResourceclassDetail.resource_class_code and 
                                                       ResourceclassDetail.company_id=@company_id and 
													   ResourceclassDetail.profit_ctr_id=@profit_ctr_id and 
													   ResourceclassDetail.bill_unit_code=@bill_unit_code
Right outer join workorderquotedetail wqd (nolock) on wqd.quote_id=@base_quote_id and 
                                                      wqd.company_id=@company_id and 
													  wqd.profit_ctr_id=@profit_ctr_id and 
													  wqd.bill_unit_code=@bill_unit_code and 
													  resource_item_code=@resource_class_code and 
													  wqd.resource_type=@resource_type
where ResourceclassHeader.resource_class_code=@resource_class_code and ResourceclassHeader.resource_type=@resource_type 
FOR JSON PATH, INCLUDE_NULL_VALUES,  WITHOUT_ARRAY_WRAPPER)





/*Select rch.resource_class_code,rch.resource_type,rch.status,rch.description,rch.salesforce_resourceclass_csid,rcd.bill_unit_code,rcd.company_id,rcd.profit_ctr_id,cast(wqd.cost as decimal(16,2)) as cost ,cast(wqd.price as decimal(16,2)) as price   into #resourceclass_json  from resourceclassheader rch (nolock)
Right outer JOIN resourceclassdetail rcd   (nolock) ON rch.resource_class_code=rcd.resource_class_code and rcd.company_id=@company_id and rcd.profit_ctr_id=@profit_ctr_id and rcd.bill_unit_code=@bill_unit_code
Right outer join workorderquotedetail wqd (nolock) on wqd.quote_id=@base_quote_id and wqd.company_id=@company_id and wqd.profit_ctr_id=@profit_ctr_id and wqd.bill_unit_code=@bill_unit_code and resource_item_code=@resource_class_code and wqd.resource_type=@resource_type
       where rch.resource_class_code=@resource_class_code and rch.resource_type=@resource_type 

set @response = ( select *  from #resourceclass_json  FOR JSON AUTO, INCLUDE_NULL_VALUES)*/
Print @response
if @@ERROR <> 0
begin
	raiserror('ERROR: attempt to create and populate JSON',18,-1) with seterror
	return -1
end


End
if @ls_config_value='F'
begin
	Select @Response= 'SFDC Data Integration Failed, since CRM_Golive_flag_Resource_Sync is off. Hence Store procedure will not execute.'
	return -1
end

Return 0

Go