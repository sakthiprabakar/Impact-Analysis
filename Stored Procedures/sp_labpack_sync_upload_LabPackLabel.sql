GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_upload_LabPackLabel 
GO
create procedure [dbo].[sp_labpack_sync_upload_LabPackLabel]
	@workorder_id [int],
	@company_id [int],
	@profit_ctr_id [int],
	@TSDF_code [varchar](15),
	@label_type [char](1),
	@sequence_id [int],
	@user [varchar](10)
as
/*
	09/20/2023	rwb	Created
*/
declare @id int, @err int

insert dbo.LabPackLabel (
	[workorder_id],
	[company_id],
	[profit_ctr_id],
	[TSDF_code],
	[label_type],
	[sequence_id],
	[created_by],
	[date_added],
	[modified_by],
	[date_modified]
)
values (
	@workorder_id,
	@company_id,
	@profit_ctr_id,
	@TSDF_code,
	@label_type,
	@sequence_id,
	@user,
	getdate(),
	@user,
	getdate()
)

select @err = @@ERROR, @id = @@IDENTITY

--Check for error
if @err <> 0
begin
	raiserror('ERROR: Insert into LabPackLabel failed.',18,-1) with seterror
	return -1
end

--Return new key
select @id as label_uid
return @id
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabel] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabel] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabel] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabel] TO EQAI;
GO

