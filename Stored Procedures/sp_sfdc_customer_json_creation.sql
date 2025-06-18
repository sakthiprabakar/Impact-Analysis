USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_customer_json_creation]    Script Date: 3/24/2025 3:53:12 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER   procedure [dbo].[sp_sfdc_customer_json_creation]
	@customer_id int,@d365_customer_id varchar(20),@sfdc_account_csid varchar(18) ,@response nvarchar(max) output
As
/*  
Description: 
New customer / update customer JSON paylod to send salesforce
Created By Venu -- 12/Feb/2025

US145700  Venu added addtional fields in customerbilling table for JSON

Declare
@response varchar(500)
Begin
Exec [dbo].[sp_sfdc_customer_json_creation] 625121,'C323321','',@response
Print @response
End

*/
declare
@ls_config_value Char(1),
@cnt int,
@Integration_for char(1)
	

select @ls_config_value = config_value from configuration where config_key='CRM_Golive_flag_phase4'

if coalesce(@ls_config_value,'') = ''
   set @ls_config_value='F'

If @ls_config_value='T'
Begin
set transaction isolation level read uncommitted


Select @cnt=count(*) from customer where customer_id=@customer_id and ax_customer_id=@d365_customer_id
If @cnt=0 or @cnt > 1 
Begin
 raiserror('ERROR: attempt to create and populate JSON. Customer not found in the cusotmer table',18,-1) with seterror
 return -1
End

Select Customer.*,CustomerBilling.PO_required_flag,CustomerBilling.mail_to_bill_to_address_flag,CustomerBilling.ebilling_account,customer_billing_territory_code into #cusomter_json  from customer   (nolock)
Left outer JOIN CustomerBilling   (nolock) ON CustomerBilling.customer_id=customer.customer_id and CustomerBilling.billing_project_id=0 
Left outer JOIN CustomerBillingTerritory   (nolock) ON CustomerBillingTerritory.customer_id=customer.customer_id and CustomerBillingTerritory.billing_project_id=0 and CustomerBillingTerritory.businesssegment_uid=1
       where customer.customer_id=@customer_id and 
	         customer.ax_customer_id=@d365_customer_id			
	   
set @response = ( select * from #cusomter_json FOR JSON AUTO, INCLUDE_NULL_VALUES)
Print @response
if @@ERROR <> 0
begin
	raiserror('ERROR: attempt to create and populate JSON',18,-1) with seterror
	return -1
end


End
if @ls_config_value='F'
begin
	Select @Response= 'SFDC Data Integration Failed, since CRM Go live flag phase4 is off. Hence Store procedure will not execute.'
	return -1
end

Return 0



Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customer_json_creation] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customer_json_creation] TO COR_USER
 
GO
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customer_json_creation] TO svc_CORAppUser
 
GO