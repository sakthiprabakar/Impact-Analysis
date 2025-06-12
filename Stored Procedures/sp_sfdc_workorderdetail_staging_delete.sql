CREATE OR ALTER      PROCEDURE [dbo].[sp_sfdc_workorderdetail_staging_delete] 
                      	@salesforce_invoice_csid varchar(18),
						@response varchar(200) OUTPUT
						


/*  
Description: 

Delete the already existing SFSWORKORDERDETAILLINES and inserting  all the detail lines.

Revision History:

DevOps# DE35912 Nagaraj M -- Deleting the existing SFSWORKORDERDETAILLINES for any error occurs and re-inserting all the lines.

Declare @response varchar(100)
Exec sp_sfdc_workorderdetail_staging_delete
@salesforce_invoice_csid='SF_SOINV03_001',
@response=@response output
print @response

*/

AS
DECLARE 	 	
	 @ll_ret_detail int = 0,	
	 @ll_ret_manifest int = 0,
	 @ll_ret_detailunit int = 0,
	 @sfs_workorderheader_uid int
	 
Begin

	select @sfs_workorderheader_uid = max(sfs_workorderheader_uid) from SFSWorkOrderHeader where salesforce_invoice_CSID=@salesforce_invoice_csid

	select @ll_ret_detail= count(*) from 
	SFSWorkOrderDetail where sfs_workorderheader_uid = @sfs_workorderheader_uid

	select @ll_ret_manifest= count(*) from 
	SFSWorkorderManifest where sfs_workorderheader_uid = @sfs_workorderheader_uid

	select @ll_ret_detailunit= count(*) from 
	SFSWorkOrderDetailUnit where sfs_workorderheader_uid = @sfs_workorderheader_uid

	if @ll_ret_detail>=1
	Begin
	delete from SFSWorkOrderDetail where sfs_workorderheader_uid = @sfs_workorderheader_uid
	End
	if @ll_ret_manifest>=1
	Begin
	delete from SFSWorkorderManifest where sfs_workorderheader_uid = @sfs_workorderheader_uid
	End
	if @ll_ret_detailunit>=1
	Begin
	delete from SFSWorkOrderDetailUnit where sfs_workorderheader_uid = @sfs_workorderheader_uid
	End

	if @ll_ret_detail >=1  or @ll_ret_manifest>=1 or @ll_ret_manifest>=1
	BEGIN
	select @response = 'Deleted Workorderdetail records: ' + STR(isnull(@ll_ret_detail,'0')) + ' ,Deleted Workordermanifest records: ' + STR(ISNULL(@ll_ret_manifest,'0')) +
						 ' ,Deleted Workordermanifest records: ' + STR(ISNULL(@ll_ret_detailunit,'0'))
	END
End

return 0


GO
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderdetail_staging_delete] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderdetail_staging_delete] TO svc_CORAppUser
 
Go
