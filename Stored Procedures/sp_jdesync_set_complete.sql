
--create procedure sp_jdesync_set_complete
--	@JDEChangeLog_uid int,
--	@batch_id varchar(10) = null
--as
--/***************************************************************
--Loads to:	Plt_AI


--03/14/2013 RB	Created - marks JDEChangeLog record as successfully completed

--****************************************************************/

--declare @err int,
--	@type varchar(2),
--	@customer_id int,
--	@contact_id int,
--	@invoice_id int,
--	@revision_id int

--begin transaction

--update JDESync
--set status = 'C',
--	batch_id = case when @batch_id = '' then convert(int,null) else convert(int,@batch_id) end,
--	date_modified = GETDATE()
--from JDESync js
--join JDEChangeLog jcl
--	on js.JDESync_uid = jcl.JDESync_uid
--	and jcl.JDEChangeLog_uid = @JDEChangeLog_uid

--select @err = @@ERROR
--if @err <> 0
--begin
--	rollback transaction
--	raiserror('ERROR: sp_jdesync_set_complete: Update to JDESync table failed',16,1)
--	return -1
--end

--select @type = type,
--	@customer_id = customer_id,
--	@contact_id = contact_id,
--	@invoice_id = invoice_id,
--	@revision_id = revision_id
--from JDEChangeLog (nolock)
--where JDEChangeLog_uid = @JDEChangeLog_uid


--update JDEChangeLog
--set status = 'C',
--	modified_by = case when type in ('IN','FA') then 'InvSync' else 'CustSync' end,
--	date_modified = GETDATE()
--where JDEChangeLog_uid >= @JDEChangeLog_uid
--and type = @type
--and isnull(customer_id,0) = isnull(@customer_id,0)
--and isnull(contact_id,0) = isnull(@contact_id,0)
--and isnull(invoice_id,0) = isnull(@invoice_id,0)
--and isnull(revision_id,0) = isnull(@revision_id,0)
--and status in ('I','P')

--select @err = @@ERROR
--if @err <> 0
--begin
--	rollback transaction
--	raiserror('ERROR: sp_jdesync_set_complete: Update to JDEChangeLog table failed',16,1)
--	return -1
--end

--commit transaction
--return 0

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jdesync_set_complete] TO [EQAI_LINKED_SERVER]
--    AS [dbo];

