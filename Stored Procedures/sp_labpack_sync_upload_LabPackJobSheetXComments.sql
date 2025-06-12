GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_upload_LabPackJobSheetXComments 
GO
create procedure [dbo].[sp_labpack_sync_upload_LabPackJobSheetXComments]
	@jobsheet_uid [int],
	@comment [varchar](max),
	@user [varchar](10)
as
/*
	09/20/2023	rwb	Created
*/
declare @id int, @err int

insert dbo.LabPackJobSheetXComments (
	[jobsheet_uid],
	[comment],
	[created_by],
	[date_added],
	[modified_by],
	[date_modified]
)
values (
	@jobsheet_uid,
	@comment,
	@user,
	getdate(),
	@user,
	getdate()
)

select @err = @@ERROR, @id = @@IDENTITY

--Check for error
if @err <> 0
begin
	raiserror('ERROR: Insert into LabPackJobSheetXComments failed.',18,-1) with seterror
	return -1
end

--Return new key
select @id as jobsheet_comment_uid
return 0
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXComments] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXComments] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXComments] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXComments] TO EQAI;
GO

