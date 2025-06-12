
--CREATE PROCEDURE sp_jdesync_customer_get_next
--	@start_id int = null
--AS
--/***************************************************************
--Loads to:	Plt_AI


--03/14/2013 RB	Created - gets next customer sync operation
--01/25/2017 RB	Added wells fargo lockbox implementation

--****************************************************************/

--declare @id int,
--		@jde_bookmaster_count int,
--		@jde_batch_number varchar(15),
--		@type varchar(2),
--		@customer_id int,
--		@contact_id int,
--		@user varchar(10),
--		@cmd varchar(255),
--		@sql varchar(max),
--		@jde_customer_id int,
--		@sync_id varchar(10),
--		@job_name varchar(10),
--		@attempt_count int,
--		@max_attempts int,
--		@initial_trancount int,
--		@run_ube_R011110Z int,
--		@err int,
--		@last_jde_to_eqai_customer_note_sync datetime,
--		@jde_note_sync_interval int,
--		@lockbox_file_check_interval int,
--		@lockbox_file_last_check datetime,
--		@lockbox_file_source_path varchar(255),
--		@lockbox_file_archive_path varchar(255),
--		@lockbox_file_unprocessed_path varchar(255),
--		@lockbox_file_check_command varchar(255),
--		@lockbox_file_check_pattern varchar(255),
--		@file_path varchar(255),
--		@wells_lockbox_file_source_path varchar(255),
--		@wells_lockbox_file_archive_path varchar(255),
--		@wells_lockbox_file_unprocessed_path varchar(255),
--		@wells_lockbox_file_check_pattern varchar(255)


--SET NOCOUNT ON

--create table #r (
--	sequence_id int not null identity,
--	action varchar(max) not null,
--	param1 varchar(max) null,
--	param2 varchar(max) null,
--	param3 varchar(max) null
--)

---- set default constants
--set @initial_trancount = @@TRANCOUNT

--select @max_attempts = ISNULL(convert(int,value),1)
--from JDESyncParameter (nolock)
--where name = 'max_attempts'

--select @last_jde_to_eqai_customer_note_sync = ISNULL(CONVERT(datetime,value),getdate())
--from JDESyncParameter (nolock)
--where name = 'customer_note_last_jde_to_eqai_sync'

--select @jde_note_sync_interval = ISNULL(CONVERT(int,value),300)
--from JDESyncParameter (nolock)
--where name = 'customer_note_jde_to_eqai_sync_interval'

--select @lockbox_file_check_interval = ISNULL(CONVERT(int,value),3600)
--from JDESyncParameter (nolock)
--where name = 'lockbox_file_check_interval'

--select @lockbox_file_last_check = ISNULL(CONVERT(datetime,value),getdate())
--from JDESyncParameter (nolock)
--where name = 'lockbox_file_last_check'

--select @lockbox_file_source_path = ISNULL(value,'')
--from JDESyncParameter (nolock)
--where name = 'lockbox_file_source_path'

--select @lockbox_file_check_command = ISNULL(value,'')
--from JDESyncParameter (nolock)
--where name = 'lockbox_file_check_command'

--select @lockbox_file_check_pattern = ISNULL(value,'')
--from JDESyncParameter (nolock)
--where name = 'lockbox_file_check_pattern'

--select @wells_lockbox_file_source_path = ISNULL(value,'')
--from JDESyncParameter (nolock)
--where name = 'wells_lockbox_file_source_path'

--select @wells_lockbox_file_archive_path = ISNULL(value,'')
--from JDESyncParameter (nolock)
--where name = 'wells_lockbox_file_archive_path'

--select @wells_lockbox_file_unprocessed_path = ISNULL(value,'')
--from JDESyncParameter (nolock)
--where name = 'wells_lockbox_file_unprocessed_path'

--select @wells_lockbox_file_check_pattern = ISNULL(value,'')
--from JDESyncParameter (nolock)
--where name = 'wells_lockbox_file_check_pattern'


---- see if it's time to check for JDE notes sync to EQAI
--if DATEDIFF(second,@last_jde_to_eqai_customer_note_sync,GETDATE()) >= @jde_note_sync_interval
--begin
--	set @id = 0
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Check for and sync any JDE customer notes to EQAI')
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', 'exec sp_jdesync_customer_note_jde_to_eqai')
--	insert #r (action, param1) values ('WRITELOG', 'JDE customer notes to EQAI sync completed')

--	goto END_OF_PROC
--end

---- see if it's time to check for Lockbox file
---- update: Only prod will launch the FTP. To accomodate dev, test and prod, generate a "if filexists *.TLDMICA" then insert a LB JDEChangeLog record"
--if @@SERVERNAME = 'NTSQL1' and DATEDIFF(second,@lockbox_file_last_check,GETDATE()) >= @lockbox_file_check_interval
--begin
--	insert #r (action, param1) values ('WRITELOG', 'Run ftp script to check for new Comerica lockbox file(s)')
--	insert #r (action, param1, param2) values ('SHELLCMD', 'F:\JDESyncComericaLockboxSFTPDownload', @lockbox_file_check_command)

--	update JDESyncParameter
--	set value = CONVERT(varchar(20),GETDATE(),120)
--	where name = 'lockbox_file_last_check'

--	if @@ERROR <> 0
--		insert #r (action, param1) values ('WRITELOG', 'ERROR: An error occurred when attempting to update JDESyncParameter.lockbox_file_last_check')
--end

---- query for minimum customer_id to process
--BEGINNING_OF_PROC:
--select @id = min(JDEChangeLog_uid)
--from JDEChangeLog (nolock)
--where JDEChangeLog_uid >= isnull(@start_id,1)
--and type in ('CU', 'CO', 'CM', 'CN', 'CS', 'CT', 'LB', 'RE', 'SP', 'TE', 'WL')
--and status in ('I', 'P')

--if ISNULL(@id,0) = 0
--begin
--	-- when no customers to process, check for a lockbox file, generate upload record if any exist
--	set @id = 0

--	insert #r (action, param1, param2, param3) values ('IF', 'FILEEXISTS', @lockbox_file_source_path, @lockbox_file_check_pattern)
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'Plt_ai', 'insert JDEChangeLog (type, status, added_by, date_added, modified_by, date_modified) values (''LB'', ''P'', ''CustSync'', getdate(), ''CustSync'', getdate())')
--	insert #r (action) values ('IF-END')

--	insert #r (action, param1, param2, param3) values ('IF', 'FILEEXISTS', @wells_lockbox_file_source_path, @wells_lockbox_file_check_pattern)
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'Plt_ai', 'insert JDEChangeLog (type, status, added_by, date_added, modified_by, date_modified) values (''WL'', ''P'', ''CustSync'', getdate(), ''CustSync'', getdate())')
--	insert #r (action) values ('IF-END')

--	insert #r (action, param1) values ('SLEEP', '10000')

--	goto END_OF_PROC
--end

---- build JDE Batch Number
--set @jde_batch_number = 'CU' + right(replicate('0',12) + convert(varchar(13),@id),13)

---- get related data
--select @type = jcl.type,
--		@sync_id = jcl.JDESync_uid,
--		@customer_id = jcl.customer_id,
--		@contact_id = jcl.contact_id,
--		@attempt_count = isnull(js.attempt_count,0),
--		@user = jcl.added_by
--from JDEChangeLog jcl
--left outer join JDESync js
--	on jcl.JDESync_uid = js.JDESync_uid
--where jcl.JDEChangeLog_uid = @id

--set @jde_customer_id = 70000000 + @customer_id

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
--	insert JDESync (type, status, customer_id, contact_id, attempt_count, date_added, date_modified)
--	values (@type, 'I', @customer_id, @contact_id, 1, GETDATE(), GETDATE())

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
--and customer_id = @customer_id
--and status in ('I','P')
--and type = @type

--select @err = @@ERROR

--if @err <> 0
--begin
--	insert #r (action, param1) values ('WRITELOG', 'Update to JDEChangeLog failed with error code ' + CONVERT(varchar(10),@err))
--	goto END_OF_PROC
--end

----
---- TYPE = CU (Customer)
----
--if @type = 'CU'
--begin
--	-- check for existence in JDE to determine whether updating or adding
--	select @jde_bookmaster_count = count(*)
--	from JDE.EQFinance.dbo.JDEAddressBookMaster_F0101
--	where address_number_ABAN8 = convert(varchar(10),@jde_customer_id)

--	-- update JDE
--	if @jde_bookmaster_count > 0 and exists (select 1 from JDE.EQFinance.dbo.JDECustomer_F03012
--									where address_number_AIAN8 = @jde_customer_id)
--	begin
--		insert #r (action, param1) values ('WRITELOG', 'REQUEST: Update customer ' + CONVERT(varchar(10),@customer_id) + ', JDEChangeLog_uid=' + CONVERT(varchar(10),@id))
--		set @sql = 'exec sp_jdesync_customer_update_jde ' + convert(varchar(10),@id)
--		insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--	end
--	-- add to JDE
--	else
--	begin
--		insert #r (action, param1) values ('WRITELOG', 'REQUEST: Add customer ' + CONVERT(varchar(10),@customer_id) + ', JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--		-- generate sql and ube commands for a customer Add
--		if @jde_bookmaster_count < 1
--		begin
--			set @sql = 'exec sp_add_F0101Z2 ''' + @user + ''''
--					+ ', ''' + @jde_batch_number + ''''
--					+ ', ''1'''
--					+ ', ' + CONVERT(varchar(8),@customer_id)
--					+ ', ' + CONVERT(varchar(8),@jde_customer_id)
--			insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)

--			set @job_name = 'R01010Z'
--			insert #r (action, param1, param2, param3)
--			values ('RUNUBEXML', @job_name, right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R01010Z (@jde_batch_number))	
--		end

--		if not exists (select 1 from JDE.EQFinance.dbo.JDECustomer_F03012
--						where address_number_AIAN8 = @jde_customer_id)
--		begin
--			set @sql = 'exec sp_add_F03012Z1 ''' + @user + ''''
--					+ ', ''' + @jde_batch_number + ''''
--					+ ', ''1'''
--					+ ', ' + CONVERT(varchar(8),@customer_id)
--					+ ', ' + CONVERT(varchar(8),@jde_customer_id)
--			insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)

--			set @job_name = 'R03010Z'
--			insert #r (action, param1, param2, param3)
--			values ('RUNUBEXML', @job_name, right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R03010Z (@jde_batch_number))
--		end
--	end

--	-- If contacts exist that aren't in JDE, run the ube
--	if (select count(*)
--		from Contact c
--		join ContactXRef x
--			on c.contact_id = x.contact_id
--			and x.customer_id = @customer_id
--			and x.type = 'C'
--			and x.status = 'A'
--		and not exists (select 1 from JDE.EQFinance.dbo.JDEContact_F0111
--					where address_number_WWAN8 = @jde_customer_id
--					and unique_identifier_WWCFRGUID = convert(varchar(10),c.contact_id))) > 0
--	begin
--		set @sql = 'exec sp_add_cust_contacts ''' + @user + ''''
--				+ ', ''' + @jde_batch_number + ''''
--				+ ', ' + CONVERT(varchar(8),@customer_id)
--				+ ', ' + CONVERT(varchar(8),@jde_customer_id)
--		insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)

--		set @run_ube_R011110Z = 1
--	end

--	-- if customer web address doesn't exist, run the UBE
--	if not exists (select 1 from JDE.EQFinance.dbo.JDEAddressBookElectronicAddress_F01151
--				where address_number_EAAN8 = @jde_customer_id
--				and whos_who_line_EAIDLN = 0
--				and electronic_address_EAETP = 'I')
--	begin
--		set @sql = 'exec sp_add_cust_webadd ''' + @user + ''''
--				+ ', ''' + @jde_batch_number + ''''
--				+ ', ' + CONVERT(varchar(8),@customer_id)
--				+ ', ' + CONVERT(varchar(8),@jde_customer_id)
--		insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)

--		set @run_ube_R011110Z = 1
--	end

--	-- if either contacts or web address added, run the required UBE
--	if isnull(@run_ube_R011110Z,0) > 0
--	begin
--		set @job_name = 'R011110Z'
--		insert #r (action, param1, param2, param3)
--		values ('RUNUBEXML', @job_name, right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R011110Z (@jde_batch_number))
--	end
--end

----
---- TYPE = CM (Collections Manager)
----
--else if (@type = 'CM')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Refresh collection managers, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- generate sql for a collections manager refresh
--	set @sql = 'exec sp_refresh_collection_manager ''' + @user + ''''
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

----
---- TYPE = CS (Customer Service Representative)
----
--else if (@type = 'CS')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Refresh customer service representatives, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- generate sql for a collections manager refresh
--	set @sql = 'exec sp_refresh_customer_service_representative ''' + @user + ''''
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

----
---- TYPE = CT (Customer Type)
----
--else if (@type = 'CT')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Refresh customer types, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- generate sql for a customer type refresh
--	set @sql = 'exec sp_refresh_customer_type ''' + @user + ''''
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

----
---- TYPE = LB (Lockbox file check)
----
--else if (@type = 'LB')
--begin
--	select @lockbox_file_archive_path = ISNULL(value,'')
--	from JDESyncParameter (nolock)
--	where name = 'lockbox_file_archive_path'

--	select @lockbox_file_unprocessed_path = ISNULL(value,'')
--	from JDESyncParameter (nolock)
--	where name = 'lockbox_file_unprocessed_path'

--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Check for Lockbox file to process, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	set @file_path = @lockbox_file_source_path
--	if RIGHT(@file_path,1) <> '\'
--		set @file_path = @file_path + '\'
--	set @file_path = @file_path + '<FILE>'

--	-- only run the ftp command if running on PROD
--	insert #r (action, param1, param2) values ('FOREACHFILE', @lockbox_file_source_path, @lockbox_file_check_pattern)
--	insert #r (action, param1, param2, param3) values ('RUNUBEXML', 'R5503B13Z1', right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R5503B13Z1 (@file_path, @lockbox_file_archive_path))
--	insert #r (action, param1) values ('SLEEP', '5000')
--	insert #r (action, param1, param2) values ('IF', 'FILENOTEXIST', @file_path)
--	insert #r (action, param1, param2, param3) values ('RUNUBEXML', 'R03B551', right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R03B551 ('EQ0001', 'COMERICA', '00261737'))
--	insert #r (action) values ('IF-END')
--	insert #r (action, param1, param2) values ('IF', 'FILEEXISTS', @file_path)
--	insert #r (action, param1) values ('WRITELOG', 'The lockbox file ' + @file_path + ' was successfully downloaded, but could not be loaded into JDE')
--	insert #r (action, param1, param2) values ('EMAIL', 'Comerica lockbox file not processed', 'The lockbox file ' + @file_path + ' was successfully downloaded, but could not be loaded into JDE')
--	insert #r (action, param1, param2) values ('MOVEFILE', @file_path, @lockbox_file_unprocessed_path)
--	insert #r (action) values ('IF-END')
--	insert #r (action, param1) values ('WRITELOG', 'Lockbox file <FILE> was successfully processed')
--	insert #r (action) values ('FOREACHFILE-END')
--end

----
---- TYPE = WL (Wells Lockbox file check)
----
--else if (@type = 'WL')
--begin
--	select @wells_lockbox_file_archive_path = ISNULL(value,'')
--	from JDESyncParameter (nolock)
--	where name = 'wells_lockbox_file_archive_path'

--	select @wells_lockbox_file_unprocessed_path = ISNULL(value,'')
--	from JDESyncParameter (nolock)
--	where name = 'wells_lockbox_file_unprocessed_path'

--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Check for Wells Lockbox file to process, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	set @file_path = @wells_lockbox_file_source_path
--	if RIGHT(@file_path,1) <> '\'
--		set @file_path = @file_path + '\'
--	set @file_path = @file_path + '<FILE>'

--	-- only run the ftp command if running on PROD
--	insert #r (action, param1, param2) values ('FOREACHFILE', @wells_lockbox_file_source_path, @wells_lockbox_file_check_pattern)
--	insert #r (action, param1, param2, param3) values ('RUNUBEXML', 'R5603B13Z1', right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R5603B13Z1 (@file_path, @wells_lockbox_file_archive_path))
--	insert #r (action, param1) values ('SLEEP', '5000')
--	insert #r (action, param1, param2) values ('IF', 'FILENOTEXIST', @file_path)
--	insert #r (action, param1, param2, param3) values ('RUNUBEXML', 'R03B551', right(@jde_batch_number,8), dbo.fn_jdesync_get_ubexml_R03B551 ('EQ0002', 'WELLSFARGO', '01093480'))
--	insert #r (action) values ('IF-END')
--	insert #r (action, param1, param2) values ('IF', 'FILEEXISTS', @file_path)
--	insert #r (action, param1) values ('WRITELOG', 'The lockbox file ' + @file_path + ' was successfully downloaded, but could not be loaded into JDE')
--	insert #r (action, param1, param2) values ('EMAIL', 'Wells lockbox file not processed', 'The lockbox file ' + @file_path + ' was successfully downloaded, but could not be loaded into JDE')
--	insert #r (action, param1, param2) values ('MOVEFILE', @file_path, @wells_lockbox_file_unprocessed_path)
--	insert #r (action) values ('IF-END')
--	insert #r (action, param1) values ('WRITELOG', 'Lockbox file <FILE> was successfully processed')
--	insert #r (action) values ('FOREACHFILE-END')
--end

----
---- TYPE = RE (Region)
----
--else if (@type = 'RE')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Refresh regions, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- generate sql for a region refresh
--	set @sql = 'exec sp_refresh_region ''' + @user + ''''
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

----
---- TYPE = SP (Salesperson)
----
--else if (@type = 'SP')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Refresh salespersons, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- generate sql for a salesperson refresh
--	set @sql = 'exec sp_refresh_salesperson ''' + @user + ''''
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

----
---- TYPE = TE (Territory)
----
--else if (@type = 'TE')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Refresh territories, JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- generate sql for a territory refresh
--	set @sql = 'exec sp_refresh_territory ''' + @user + ''''
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

----
---- TYPE = CO (Contact)
----
--else if (@type = 'CO')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Refresh contact contact_id=' + CONVERT(varchar(10),@contact_id) + ', JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

--	-- generate sql for a contact refresh
--	set @sql = 'exec sp_jdesync_contact_update_jde ' + CONVERT(varchar(10),@contact_id)
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

----
---- TYPE = CN (Customer Notes)
----
--else if (@type = 'CN')
--begin
--	insert #r (action, param1) values ('WRITELOG', 'REQUEST: Sync EQAI customer notes to JDE, customer_id=' + CONVERT(varchar(10),@customer_id) + ', JDEChangeLog_uid=' + CONVERT(varchar(10),@id))
--	set @sql = 'exec sp_jdesync_customer_note_eqai_to_jde ' + CONVERT(varchar(10),@customer_id)

--	-- sql for a customer notes refresh
--	insert #r (action, param1, param2) values ('SQLUPDATE', 'EQFinance', @sql)
--end

---- generate SQL to update this status
--set @sql = 'exec sp_jdesync_set_complete ' + convert(varchar(10),@id) + ', ''<JOBID>'''
--insert #r (action, param1, param2) values ('SQLUPDATE', 'Plt_ai', @sql)

---- if all was successful, log it
--insert #r (action, param1) values ('WRITELOG', 'Customer sync successfully completed JDEChangeLog_uid=' + CONVERT(varchar(10),@id))

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
--    ON OBJECT::[dbo].[sp_jdesync_customer_get_next] TO [EQAI_LINKED_SERVER]
--    AS [dbo];

