GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_upload_LabPackJobSheet 
GO

USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_labpack_sync_upload_LabPackJobSheet]    Script Date: 1/12/2024 2:43:36 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



create procedure [dbo].[sp_labpack_sync_upload_LabPackJobSheet]
	@workorder_id [int],
	@company_id [int],
	@profit_ctr_id [int],
	@job_notes [varchar](255),
	@truck_id [varchar](50),
	@HHW_name [varchar](25),
	@otherinfo_text [varchar](max),
	@auth_name [varchar](100),
	@is_change_auth_enabled [int],
	@user [varchar](10)
as
/*
	09/20/2023	rwb	Created
*/
declare @id int, @err int

insert dbo.LabPackJobSheet (
	[workorder_id],
	[company_id],
	[profit_ctr_id],
	[job_notes],
	[truck_id],
	[HHW_name],
	[otherinfo_text],
	[auth_name],
	[is_change_auth_enabled],
	[created_by],
	[date_added],
	[modified_by],
	[date_modified]
)
values (
	@workorder_id,
	@company_id,
	@profit_ctr_id,
	@job_notes,
	@truck_id,
	@HHW_name,
	@otherinfo_text,
	@auth_name,
	@is_change_auth_enabled,
	@user,
	getdate(),
	@user,
	getdate()
)

select @err = @@ERROR, @id = @@IDENTITY

--Check for error
if @err <> 0
begin
	raiserror('ERROR: Insert into LabPackJobSheet failed.',18,-1) with seterror
	return -1
end

--Return new key
select @id as jobsheet_Uid
return @id
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheet] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheet] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheet] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackJobSheet] TO EQAI;
GO


