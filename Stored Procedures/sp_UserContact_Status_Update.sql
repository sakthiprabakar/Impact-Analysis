
CREATE PROCEDURE [dbo].[sp_UserContact_Status_Update]
    @web_userid varchar(60),
	@status varchar(5)
AS

-- =============================================
-- Author:		<Author,,Sathick>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================

/*
 

  Updated By       : Sathick
  Updated On date  : 22-02-2019
  Decription       : Update User Contact status Active or Inactive 
  Type             : Stored Procedure
  Object Name      : [sp_UserContact_Status_Update]

*/
BEGIN
     IF(EXISTS(SELECT * FROM [plt_ai].[dbo].Contact WHERE web_userid = @web_userid ))
	  BEGIN
	   Update [plt_ai].[dbo].Contact Set Contact_status = @status where web_userid = @web_userid
	   SELECT 'Contact status update successfully'
	  END
	 ELSE
	  BEGIN 
	   SELECT 'Invalid User Id'
	  END
END

GO

GRANT EXECUTE ON [dbo].[sp_UserContact_Status_Update] TO COR_USER;

GO