CREATE PROCEDURE [dbo].[sp_Profile_Quote_Approval_Docusign]
       @profileid int,
       @printed_date datetime,
       @po_number varchar(20)
AS
/* **********************************************************************************
sp_Profile_Quote_Approval_Docusign

Update ProfileQuoteApproval when price confirmation sent to Docusign

sp_Profile_Quote_Approval_Docusign
       @profile_id   = 412605,
       @printed_date = '04/21/2020',
       @po_number = null

********************************************************************************** */
BEGIN

       DECLARE @sign_name varchar(40),
               @po_num varchar(20)

       IF LTRIM(RTRIM(@po_number)) > '' SET @po_num = LTRIM(RTRIM(@po_number))

       SELECT @sign_name = contact_name
       FROM FormCC
       WHERE profile_id = @profileid
       AND date_modified = (select max(date_modified) from FormCC where profile_id = @profileid)

       UPDATE ProfileQuoteApproval
       SET confirm_update_date = GETDATE(),--@printed_date,
              confirm_update_by = 'DocuSign',
              confirm_author = @sign_name,
              purchase_order = isnull(@po_num,purchase_order)
       WHERE profile_id = @profileid
       AND status = 'A'

END

go

	grant execute on sp_Profile_Quote_Approval_Docusign to eqweb, eqai, COR_USER

go