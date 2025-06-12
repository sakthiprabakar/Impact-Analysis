GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_upload_LabPackJobSheetXLabor 
GO
create procedure [dbo].[sp_labpack_sync_upload_LabPackJobSheetXLabor]
	@jobsheet_uid [int],
	@resource_class_code [varchar](10),
	@chemist_name [varchar](255),
	@dispatch_time [time](6),
	@onsite_time [time](6),
	@jobfinish_time [time](6),
	@est_return_time [time](6),
	@user [varchar](10)
as
/*
	09/20/2023	rwb	Created
*/
declare @id int, @err int

insert dbo.LabPackJobSheetXLabor (
	[jobsheet_uid],
	[resource_class_code],
	[chemist_name],
	[dispatch_time],
	[onsite_time],
	[jobfinish_time],
	[est_return_time],
	[created_by],
	[date_added],
	[modified_by],
	[date_modified]
)
values (
	@jobsheet_uid,
	@resource_class_code,
	@chemist_name,
	@dispatch_time,
	@onsite_time,
	@jobfinish_time,
	@est_return_time,
	@user,
	getdate(),
	@user,
	getdate()
)

select @err = @@ERROR, @id = @@IDENTITY

--Check for error
if @err <> 0
begin
	raiserror('ERROR: Insert into LabPackJobSheetXLabor failed.',18,-1) with seterror
	return -1
end

--Return new key
select @id as jobsheet_labor_uid
return 0
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXLabor] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXLabor] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXLabor] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheetXLabor] TO EQAI;
GO