
--create procedure sp_jdesync_invoice_get_next
--	@start_id int = null
--as
--/***************************************************************
--Loads to:	Plt_AI


--03/20/2013 RB	Created - gets next invoice sync operation

--****************************************************************/
--declare @id int,
--		@type varchar(2),
--		@jde_batch_number varchar(15),
--		@invoice_id int,
--		@revision_id int,
--		@user varchar(10),
--		@cmd varchar(255),
--		@sql varchar(max),
--		@sync_id varchar(10),
--		@job_name varchar(10),
--		@attempt_count int,
--		@max_attempts int,
--		@initial_trancount int,
--		@err int

--SET NOCOUNT ON

--create table #r (
--	sequence_id int not null identity,
--	action varchar(max) not null,
--	param1 varchar(max) null,
--	param2 varchar(max) null,
--	param3 varchar(max) null
--)

---- set default constants
--set @max_attempts = 3
--set @initial_trancount = @@TRANCOUNT

---- query for minimum invoice_id to process
--BEGINNING_OF_PROC:
--select @id = min(JDEChangeLog_uid)
--from JDEChangeLog
--where JDEChangeLog_uid >= isnull(@start_id,1)
--and type in ('IN','FA')
--and status in ('I', 'P')

--if ISNULL(@id,0) = 0
--	return 0

---- build JDE Batch Number
--set @jde_batch_number = 'IN' + right(replicate('0',12) + convert(varchar(13),@id),13)

---- get related data
--select @type = jcl.type,
--		@sync_id = jcl.JDESync_uid,
--		@invoice_id = jcl.invoice_id,
--		@revision_id = jcl.revision_id,
--		@attempt_count = isnull(js.attempt_count,0),
--		@user = jcl.added_by
--from JDEChangeLog jcl
--left outer join JDESync js
--	on jcl.JDESync_uid = js.JDESync_uid
--where jcl.JDEChangeLog_uid = @id


---- BEGIN TRANSACTION
--begin transaction

---- if max attempt count exceeded, put the record on hold
--if @attempt_count >= @max_attempts
--begin
--	update JDESync
--	set status = 'H',
--		date_modified = GETDATE()
--	where JDESync_uid = @sync_id
	
--	select @err = @@ERROR

--	if @err <> 0
--	begin
--		insert #r (action, param1) values ('WRITELOG', 'Update to JDESync failed with error code ' + CONVERT(varchar(10),@err))
--		goto END_OF_PROC
--	end

--	update JDEChangeLog
--	set status = 'H',
--		date_modified = GETDATE(),
--		modified_by = 'CustSync'
--	where JDEChangeLog_uid = @id
	
--	select @err = @@ERROR

--	if @err <> 0
--	begin
--		insert #r (action, param1) values ('WRITELOG', 'Update to JDEChangeLog failed with error code ' + CONVERT(varchar(10),@err))
--		goto END_OF_PROC
--	end

--	--start over
--	commit transaction
	
--	goto BEGINNING_OF_PROC
--end

---- update status to In Process (if first time processed, insert a JDESync record)
--if @sync_id is null
--begin
--	insert JDESync (type, status, invoice_id, revision_id, attempt_count, date_added, date_modified)
--	values (@type, 'I', @invoice_id, @revision_id, 1, GETDATE(), GETDATE())

--	select @err = @@ERROR,
--			@sync_id = @@IDENTITY

--	if @err <> 0
--	begin
--		insert #r (action, param1) values ('WRITELOG', 'Insert into JDESync failed with error code ' + CONVERT(varchar(10),@err))
--		goto END_OF_PROC
--	end
	
--	update JDEChangeLog
--	set JDESync_uid = @sync_id,
--		date_modified = GETDATE()
--	where JDEChangeLog_uid = @id

--	select @err = @@ERROR

--	if @err <> 0
--	begin
--		insert #r (action, param1) values ('WRITELOG', 'Update to JDEChangeLog failed with error code ' + CONVERT(varchar(10),@err))
--		goto END_OF_PROC
--	end
--end
--else
--begin
--	update JDESync
--	set attempt_count = isnull(attempt_count,0) + 1
--	where JDESync_uid = @sync_id

--	select @err = @@ERROR

--	if @err <> 0
--	begin
--		insert #r (action, param1) values ('WRITELOG', 'Update to JDESync failed with error code ' + CONVERT(varchar(10),@err))
--		goto END_OF_PROC
--	end
--end

--update JDEChangeLog
--set status = 'I',
--	date_modified = GETDATE(),
--	modified_by = 'CustSync'
--where JDEChangeLog_uid >= @id
--and type = @type
--and invoice_id = @invoice_id
--and ISNULL(revision_id,0) = ISNULL(@revision_id,0)

--select @err = @@ERROR

--if @err <> 0
--begin
--	insert #r (action, param1) values ('WRITELOG', 'Update to JDEChangeLog failed with error code ' + CONVERT(varchar(10),@err))
--	goto END_OF_PROC
--end

---- Invoice post
--if @type = 'IN'
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Invoice ' + CONVERT(varchar(10),@invoice_id) + '-' + CONVERT(varchar(10),@revision_id) + ', JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	set @sql = 'exec sp_create_jde_invoice ''' + @jde_batch_number + ''''
--			+ ', ' + CONVERT(varchar(8),@invoice_id)
--			+ ', ' + CONVERT(varchar(8),@revision_id)
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)


--	set @job_name = 'R03B11Z1A'
--	insert #r (action, param1, param2, param3)
--	values ('RUNUBEXML', @job_name, right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R03B11Z1A (@jde_batch_number))
--end

---- Flash Accrual
--else if @type = 'FA'
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Flash Accrual ' + ', JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- TEMPORARILY using invoice_id for flash_accrual_id, should be added to JDEChangeLog table
--	set @sql = 'exec sp_jde_submit_flash_accrual ''' + @jde_batch_number + ''', ''' + @user + ''', ' + CONVERT(varchar(10),@invoice_id)
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'Plt_ai', @sql)

--	set @job_name = 'R09110Z'
--	insert #r (action, param1, param2, param3)
--	values ('RUNUBEXML', @job_name, right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R09110Z (@jde_batch_number))
--end

---- generate SQL to update this status
--set @sql = 'exec sp_jdesync_set_complete ' + convert(varchar(10),@id) + ', ''<JOBID>'''
--insert #r (action, param1, param2) values ('SQLUPDATE', 'Plt_ai', @sql)

---- if all was successful, log it
--insert #r (action, param1) values ('WRITELOG', 'Invoice sync successfully completed JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

---- commit
--commit transaction

---- return results
--END_OF_PROC:
--if @@TRANCOUNT > @initial_trancount
--	rollback transaction

--SET NOCOUNT OFF

--select convert(varchar(10),@id) as jdechangelog_uid,
--		action,
--		param1,
--		param2,
--		param3
--from #r
--order by sequence_id

--drop table #r

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jdesync_invoice_get_next] TO [EQAI_LINKED_SERVER]
--    AS [dbo];

