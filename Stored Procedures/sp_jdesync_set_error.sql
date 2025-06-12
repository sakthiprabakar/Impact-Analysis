
--create procedure sp_jdesync_set_error
--	@JDEChangeLog_uid int,
--	@error_msg varchar(max),
--	@notification_sent char(1)
--as
--/***************************************************************
--Loads to:	Plt_AI


--03/14/2013 RB	Created - marks JDEChangeLog record as resulting in error

--****************************************************************/

--declare @err int,
--	@sync_id int,
--	@attempt_count int,
--	@max_attempts int,
--	@status char(1)

--set @max_attempts = 3

--select @sync_id = jcl.JDESync_uid,
--		@status = js.status,
--		@attempt_count = isnull(js.attempt_count,0)
--from JDEChangeLog jcl
--left outer join JDESync js
--	on jcl.JDESync_uid = js.JDESync_uid
--where jcl.JDEChangeLog_uid = @JDEChangeLog_uid

--begin transaction

--if @attempt_count >= @max_attempts
--	set @status = 'E'

--update JDESync
--set status = @status,
--	error_description = @error_msg,
--	notificaiton_sent_date = case when ISNULL(@notification_sent,'F') = 'T' then GETDATE() else CONVERT(datetime,null) end,
--	date_modified = GETDATE()
--from JDESync js
--join JDEChangeLog jcl
--	on js.JDESync_uid = jcl.JDESync_uid
--	and jcl.JDEChangeLog_uid = @JDEChangeLog_uid

--select @err = @@ERROR
--if @err <> 0
--begin
--	rollback transaction
--	return -1
--end
		
--update JDEChangeLog
--set status = @status,
--	modified_by = case when type = 'IN' then 'InvSync' else 'CustSync' end,
--	date_modified = GETDATE()
--where JDEChangeLog_uid = @JDEChangeLog_uid

--select @err = @@ERROR
--if @err <> 0
--begin
--	rollback transaction
--	return -1
--end

--commit transaction
--return 0

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jdesync_set_error] TO [EQAI_LINKED_SERVER]
--    AS [dbo];

