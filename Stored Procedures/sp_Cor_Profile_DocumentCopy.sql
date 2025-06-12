CREATE PROCEDURE [dbo].[sp_Cor_Profile_DocumentCopy] 
    @profile_id int , 
    @form_id int,
    @revision_id int,
    @web_userid nvarchar(100)
AS
/* ******************************************************************
  Author       : Gunasekaran M
  Created date : 13-Jan-2021
  Description   : This procedure is used to copy Document file SDS and Lab Analysis
inputs     
    profile_id 
    form_id 
    revision_id
    web_userid
Samples:
exec sp_Cor_Profile_DocumentCopy '660933','543777',1,'renewal','nyswyn100'
****************************************************************** */
BEGIN
DECLARE @CurrentDate datetime 
SET @CurrentDate = (SELECT GETDATE())
INSERT INTO Plt_Image..Scan
   SELECT company_id,
          profit_ctr_id,
		  image_id,
		  (Select type_code from Plt_Image..ScanDocumentType where [type_id] = DocumentAttachment.[type_id]),
		  [type_id],
		  [status],
		  document_name,
		  @CurrentDate,
		  @CurrentDate,
		  @web_userid,
		  @web_userid,
		  date_voided,
		  customer_id,
		  receipt_id,
		  manifest,
		  manifest_flag,
		  approval_code,
		  workorder_id,
		  generator_id,
		  invoice_print_flag,
		  image_resolution,
		  scan_file,
		  [description],
		  @form_id,
		  @revision_id,
		  form_version_id,
		  form_type,
		  file_type,
		  profile_id,
		  page_number,
		  print_in_file,
		  view_on_web,
		  app_source,
		  upload_date,
		  merchandise_id,
		  trip_id,
		  batch_id,
		  TSDF_code,
		  TSDF_approval_id,
		  quote_id,
		  loc_code,
		  man_sys_number,
		  work_order_number FROM Plt_Image..Scan (nolock) DocumentAttachment 
    WHERE 
          DocumentAttachment.profile_id = @profile_id and 
          DocumentAttachment.view_on_web = 'T'
          and DocumentAttachment.[status] = 'A' and 
		  DocumentAttachment.[type_id] in (Select [type_id] from Plt_Image..ScanDocumentType where type_code in ('CORSDS','CORLABANAL'))
 END

GO

	GRANT EXECUTE ON [dbo].[sp_Cor_Profile_DocumentCopy] TO COR_USER;

GO