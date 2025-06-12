GO
DROP PROCEDURE IF EXISTS sp_labpack_sync_upload_LabPackLabelXInventory 
GO
create procedure [dbo].[sp_labpack_sync_upload_LabPackLabelXInventory]
	@label_uid [int],
	@notes [varchar](255),
	@epa_rcra_codes [varchar](max),
	@quantity [int],
	@size [varchar](50),
	@phase [varchar](50),
	@inventoryconstituent_name [varchar](max),
	@user [varchar](10)
as
/*
	09/20/2023	rwb	Created
*/
declare @id int, @err int

insert dbo.LabPackLabelXInventory (
	[label_uid],
	[notes],
	[epa_rcra_codes],
	[quantity],
	[size],
	[phase],
	[inventoryconstituent_name],
	[created_by],
	[date_added],
	[modified_by],
	[date_modified]
)
values (
	@label_uid,
	@notes,
	@epa_rcra_codes,
	@quantity,
	@size,
	@phase,
	@inventoryconstituent_name,
	@user,
	getdate(),
	@user,
	getdate()
)

select @err = @@ERROR, @id = @@IDENTITY

--Check for error
if @err <> 0
begin
	raiserror('ERROR: Insert into LabPackLabelXInventory failed.',18,-1) with seterror
	return -1
end

--Return new key
select @id as label_Xinventory_uid
return 0
GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabelXInventory] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabelXInventory] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabelXInventory] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_upload_LabPackLabelXInventory] TO EQAI;
GO

