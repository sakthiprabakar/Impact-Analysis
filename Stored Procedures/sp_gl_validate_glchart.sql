
create procedure sp_gl_validate_glchart
	@gl_account_code varchar(32),
	@create_flag int
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
		@err varchar(255),
		@return_results int

 set XACT_ABORT ON

-- TO DO: check active flag, and update to active?

-- collect error and information messages
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

-- validate that gl_seg_1 and gl_seg_4 have been defined (report both if not defined before returning error message(s)
if not exists (select 1 from NTSQLFinance.EQFinance.dbo.GLSTD_gl_seg1_name where seg1_code = @gl_seg_1)
begin
	select @rc = -1
	insert #gl_validate (msg_type, msg_text) values ('E', 'Natural Segment ' + @gl_seg_1 + ' is not defined in GLSTD_gl_seg1_name')
end
else
begin
	if not exists (select 1 from NTSQLFinance.EQFinance.dbo.GLSTD_gl_seg1_name
					where seg1_code = @gl_seg_1
					and active_from_name_spreadsheet = 'ACTIVE'
					and active_from_glaccount_list = 'ACTIVE')
	begin
		select @rc = -1
		insert #gl_validate (msg_type, msg_text) values ('E', 'Natural Segment ' + @gl_seg_1 + ' exists in GLSTD_gl_seg1_name, but is not ACTIVE')
	end
end

if not exists (select 1 from NTSQLFinance.EQFinance.dbo.GLSTD_gl_seg4_name where seg4_code = @gl_seg_4)
begin
	select @rc = -1
	insert #gl_validate (msg_type, msg_text) values ('E', 'Department Segment ' + @gl_seg_4 + ' is not defined in GLSTD_gl_seg4_name')
end

if @rc < 0
	goto END_OF_PROC


-- check for existence in GLSTD_GL_Account, need to add proper error checking
if not exists (select 1 from NTSQLFinance.EQFinance.dbo.GLSTD_GL_Account where account_code = @gl_account_code)
begin
	if isnull(@create_flag,0) = 1
	begin
		insert NTSQLFinance.EQFinance.dbo.GLSTD_GL_Account
		values (@gl_account_code, @gl_seg_1, @company, @profit_ctr, @gl_seg_4,
				getdate(), 'From EQFinance.dbo.sp_gl_validate_glchart', null)

		if @@error <> 0 or @@rowcount <> 1
			insert #gl_validate (msg_type, msg_text)
			values ('E', 'GL Account Code ' + @gl_account_code + ' did not exist in GLSTD_GL_Account, and could not be created.')
		else
			insert #gl_validate (msg_type, msg_text)
			values ('I', 'GL Account Code ' + @gl_account_code + ' did not exist in GLSTD_GL_Account, but was successfully created.')
	end
	
	else
		insert #gl_validate (msg_type, msg_text)
		values ('E', 'GL Account Code ' + @gl_account_code + ' does not exist in GLSTD_GL_Account.')
end
else
	insert #gl_validate (msg_type, msg_text)
	values ('I', 'GL Account Code ' + @gl_account_code + ' exists in GLSTD_GL_Account.')

--
-- validate: exists in Epicor GL Chart
--
select @sql = N'if exists (select 1 from e' + @company + N'.dbo.glchart'
					+ N' where account_code = ''' + @gl_account_code + N''''
					+ N') select @sql_rc = 0 else select @sql_rc = -1'

exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT

--
-- if it does not exist, create if argument requests to do so, otherwise report error
--
if @rc < 0
begin
	if isnull(@create_flag,0) = 1
	begin
		select @sql = N'if exists (select 1 from e' + @company + N'.dbo.frl_acct_code where acct_code = '''
					+ @gl_account_code + N''') begin delete e' + @company
					+ N'.dbo.frl_acct_code where acct_code = '''
					+ @gl_account_code + N''' select @sql_rc = 1 end else select @sql_rc = 0'

		exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT

		if (@rc > 0)
			insert #gl_validate (msg_type, msg_text)
			values ('I', 'GL Account Code ' + @gl_account_code + ' existed in frl_acct_code and had to be deleted prior to insert.')

		select @sql = N'insert into e' + @company + N'.dbo.glchart select null, ''' + @gl_account_code + N''', ' 
					+ N'''' + LEFT(glseg1.new_name + case when @gl_seg_1 between '40300' and '40340' or @gl_seg_4 between '701' and '799'
														then N' - ' + glseg4.description else N'' END, 40) + N''', '
					+ N'''' + convert(nvarchar(5),glseg1.account_type) + N''', 1, ''' + @gl_seg_1 + N''', ''' + @company + N''', '
					+ N'''' + @profit_ctr + N''', ''' + @gl_seg_4 + N''', 0, glactype.consol_type, 0, 0, 0, ''USD'', 0, ''BUY'', ''BUY'''
					+ N' from e' + @company + '.dbo.glactype glactype where type_code = ' + convert(nvarchar(5),glseg1.account_type)
					+ N' if @@error <> 0 or @@rowcount <> 1 select @sql_rc = -1 else select @sql_rc = 0'
		from NTSQLFinance.EQFinance.dbo.GLSTD_gl_account glaccount
		join NTSQLFinance.EQFinance.dbo.GLSTD_gl_seg1_name glseg1 ON glseg1.seg1_code = glaccount.seg1_code
		join NTSQLFinance.EQFinance.dbo.GLSTD_gl_seg4_name glseg4 ON glseg4.seg4_code = glaccount.seg4_code
		where glaccount.account_code = @gl_account_code

		exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT
		
		if @rc < 0
			insert #gl_validate (msg_type, msg_text)
			values ('E', 'GL Account Code ' + @gl_account_code + ' does not exist in the Epicor GL Chart, and could not be created.')
		else
			insert #gl_validate (msg_type, msg_text)
			values ('I', 'GL Account Code ' + @gl_account_code + ' did not exist in the Epicor GL Chart, but was successfully created.')
	end

	else
		insert #gl_validate (msg_type, msg_text)
		values ('E', 'GL Account Code ' + @gl_account_code + ' does not exist in the Epicor GL Chart.')
end
-- if it exists, check if activated
else
begin
	select @sql = N'if exists (select 1 from e' + @company + N'.dbo.glchart'
						+ N' where account_code = ''' + @gl_account_code + N''''
						+ N' and isnull(inactive_flag,0) = 1'
						+ N') select @sql_rc = -1 else select @sql_rc = 0'

	exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT

	if @rc < 0
	begin
		if isnull(@create_flag,0) = 1
		begin
			select @sql = N'update e' + @company + N'.dbo.glchart set inactive_date=0, inactive_flag=0'
						+ N' where account_code = ''' + @gl_account_code + N''''
						+ N' if @@error <> 0 or @@rowcount <> 1 select @sql_rc = -1 else select @sql_rc = 0'

			exec NTSQLFinance.EQFinance.dbo.sp_executesql @sql, N'@sql_rc int OUTPUT', @sql_rc = @rc OUTPUT
		
			if @rc < 0
				insert #gl_validate (msg_type, msg_text)
				values ('E', 'GL Account Code ' + @gl_account_code + ' is inactive in the Epicor GL Chart, and could not be activated.')
			else
				insert #gl_validate (msg_type, msg_text)
				values ('I', 'GL Account Code ' + @gl_account_code + ' was inactive in the Epicor GL Chart, but was successfully activated.')
		end
		else
			insert #gl_validate (msg_type, msg_text)
			values ('E', 'GL Account Code ' + @gl_account_code + ' exists in the Epicor GL Chart, but is inactive.')
	end
	else
		insert #gl_validate (msg_type, msg_text)
		values ('I', 'GL Account Code ' + @gl_account_code + ' exists in the Epicor GL Chart and is active.')
end

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
    ON OBJECT::[dbo].[sp_gl_validate_glchart] TO PUBLIC
    AS [dbo];

