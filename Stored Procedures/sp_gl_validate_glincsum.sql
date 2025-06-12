
create procedure dbo.sp_gl_validate_glincsum
	@gl_account_code varchar(32),
	@create_flag int,
	@create_legacy_flag int = 0
as
/****************************************
 *
 * created in NTSQL1.Plt_ai
 *
 * 01/20/2012 rb - Created
 *
 ****************************************/
declare @rc int,
		@sql nvarchar(1024),
		@gl_seg_1 varchar(5),
		@company varchar(2),
		@profit_ctr varchar(2),
		@gl_seg_4 varchar(3),
		@glincsum_pattern varchar(12),
		@glincsum_is_account varchar(12),
		@glincsum_re_account varchar(12),
		@err varchar(255),
		@dt datetime,
		@return_results int

 set XACT_ABORT ON
 
-- TO DO: update IS/RE if record exists but accounts are different

if not exists (select 1 from tempdb..sysobjects (nolock) where type = 'U' and name like '#gl_validate%')
begin
	create table #gl_validate (msg_type char(1), msg_text varchar(255), msg_dt datetime default getdate())
	select @return_results = 1
end

-- validate account code and extract segments
exec @rc = dbo.sp_gl_validate_account @gl_account_code,
				@gl_seg_1 OUTPUT, @company OUTPUT, @profit_ctr OUTPUT, @gl_seg_4 OUTPUT, @err OUTPUT
if @rc < 0
begin
	insert #gl_validate (msg_type, msg_text) values ('E', @err)
	goto END_OF_PROC
end

--
-- validate: check for glincsum account pattern and IS / RE accounts
--
select @glincsum_pattern	= '_______' + RIGHT(@gl_account_code,5)
--select @glincsum_is_account	= '40050' + RIGHT(@gl_account_code,7)
--select @glincsum_re_account	= '32210' + SUBSTRING(@gl_account_code,6,2) + '00100'

if isnull(@create_legacy_flag,0) <> 0
begin
	select @sql = N'select @is_acct = is_acct_code, @re_acct = re_acct_code from e'
					+ @company + N'.dbo.glincsum'
					+ N' where account_pattern = ''' + @glincsum_pattern + N''''

	exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@is_acct varchar(12) OUTPUT, @re_acct varchar(12) OUTPUT', @is_acct = @glincsum_is_account OUTPUT, @re_acct = @glincsum_re_account OUTPUT
end

if isnull(@glincsum_is_account,'') = ''
	select @glincsum_is_account = '40050' + RIGHT(@gl_account_code,7)
if isnull(@glincsum_re_account,'') = ''
	select @glincsum_re_account = '32210' + SUBSTRING(@gl_account_code,6,2) + '00100'

--
-- validate: glincsum account pattern record exists with correct IS and RE accounts
--
select @sql = N'if exists (select 1 from e' + @company + N'.dbo.glincsum'
					+ N' where account_pattern = ''' + @glincsum_pattern + N''''
					+ N' and is_acct_code = ''' + @glincsum_is_account + N''''
					+ N' and re_acct_code = ''' + @glincsum_re_account + N''''
					+ N') select @sql_rc = 0 else select @sql_rc = -1'

exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT

if @rc < 0
begin
	--
	-- validate: glincsum account pattern record exists (with incorrect IS and RE accounts)
	--
	select @sql = N' if exists (select 1 from e' + @company + N'.dbo.glincsum'
				+ N' where account_pattern = ''' + @glincsum_pattern + N''') select @sql_rc = -1 else select @sql_rc = 0'

	exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT

	if @rc < 0
	begin
		-- if @create_flag passed, attempt to update the IS/RE accounts
		if ISNULL(@create_flag,0) = 1
		begin
			select @sql = N'update e' + @company + N'.dbo.glincsum'
						+ N' set is_acct_code = ''' + @glincsum_is_account + N''','
						+ N' re_acct_code = ''' + @glincsum_re_account + N''''
						+ N' where account_pattern = ''' + @glincsum_pattern + N''''
						+ N' if (@@error <> 0 or @@rowcount <> 1) select @sql_rc = -1 else select @sql_rc = 0'

			exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT

			if @rc < 0
				insert #gl_validate (msg_type, msg_text)
				values ('E', 'Income Summary record for account pattern ' + @glincsum_pattern
							+ ' exists in Epicor but has incorrect IS/RE accounts, and could not be updated.')
			else
				insert #gl_validate (msg_type, msg_text)
				values ('I', 'Income Summary record for account pattern ' + @glincsum_pattern
							+ ' exists in Epicor but had incorrect IS/RE accounts, but were successfully updated.')
		end

		else
			insert #gl_validate (msg_type, msg_text)
			values ('E', 'Income Summary record exists in Epicor for account pattern '
						+ @glincsum_pattern + ', but the IS and/or RE accounts are not correct.')
	end

	--
	-- if the glincsum account pattern record doesn't exist, attempt to create it if told to
	--
	else if isnull(@create_flag,0) = 1
	begin
		select @sql = N'declare @id int'
					+ N' select @id = isnull(max(sequence_id),0) from e' + @company + N'.dbo.glincsum'
					+ N' insert e' + @company + N'.dbo.glincsum values (null, @id+1, '
					+ N' ''' + @glincsum_pattern + N''', ''_____'', ''__'', ''' + @profit_ctr + N''', '
					+ N' ''' + @gl_seg_4 + N''', ''' + @glincsum_is_account + N''', ''' + @glincsum_re_account + N''')'
					+ N' if (@@error <> 0 or @@rowcount <> 1) select @sql_rc = -1 else select @sql_rc = 0'

		exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT

		if @rc < 0
			insert #gl_validate (msg_type, msg_text)
			values ('E', 'Income Summary record for account pattern ' + @glincsum_pattern
						+ ' does not exist in Epicor, and could not be created.')
		else
			insert #gl_validate (msg_type, msg_text)
			values ('I', 'Income Summary record for account pattern ' + @glincsum_pattern
						+ ' did not exist in Epicor, but was successfully created.')
	end

	else
		insert #gl_validate (msg_type, msg_text)
		values ('E', 'Income Summary record for account pattern ' + @glincsum_pattern
					+ ' does not exist in Epicor.')
end

---
--- make sure the IS and RE accounts exist in GL Chart
---
select @dt = getdate()
insert #gl_validate (msg_type, msg_text)
exec dbo.sp_gl_validate_glchart @glincsum_is_account, @create_flag

update #gl_validate set msg_text = REPLACE(msg_text, 'GL Account', 'IS GL Account')
where msg_dt > @dt

select @dt = getdate()
insert #gl_validate (msg_type, msg_text)
exec dbo.sp_gl_validate_glchart @glincsum_re_account, @create_flag

update #gl_validate set msg_text = REPLACE(msg_text, 'GL Account', 'RE GL Account')
where msg_dt > @dt


END_OF_PROC:
-- return results if not called from other proc
if ISNULL(@return_results,0) = 1
begin
	select msg_type, msg_text from #gl_validate t1
	where not exists (select 1 from #gl_validate t2 where t2.msg_dt < t1.msg_dt and t2.msg_text = t1.msg_text)
	order by msg_dt

	drop table #gl_validate
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gl_validate_glincsum] TO PUBLIC
    AS [dbo];

