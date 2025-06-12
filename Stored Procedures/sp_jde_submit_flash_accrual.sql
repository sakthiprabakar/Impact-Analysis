
--create procedure sp_jde_submit_flash_accrual
--	@jde_batch_number varchar(15),
--	@user varchar(10),
--	@flash_accrual_id int
--as

--declare @line_id int,
--		@line_id_s varchar(10),
--		@gl_date date,
--		@gl_account varchar(29),
--		@exists int,
--		@is_postable int,
--		@jde_company varchar(4),
--		@line_amount numeric(10,2),
--		@rc int,
--		@error_msg varchar(max),

--		@VNEDTN nchar(22) = '000001', --EDI - Transaction Number
--		@document_company varchar(5) = '02100',
--		@document_type varchar(2) = 'JE',
--		@explanation varchar(40)

---- initialize @line_id
--set @line_id = 0
--set @gl_date = convert(date,getdate()) --actually, last day of month?
--set @explanation = 'Accrual as of ' + convert(varchar(10),@gl_date)

---- validate accounts (both GL and AR accounts)
---- GL
--declare c_val_gl cursor forward_only read_only for
--select distinct jde_gl_account_code
--from EQ_Extract..FlashAccrualReport (nolock)
--where flash_accrual_id = @flash_accrual_id
--and isnull(exclude_flag,0) = 0

--open c_val_gl
--fetch c_val_gl into @gl_account

--while @@FETCH_STATUS = 0
--begin
--	exec sp_jde_validate_account @gl_account, @exists output, @is_postable output

--	if isnull(@exists,0) <> 1
--		set @error_msg = isnull(@error_msg,'') + 'GL Account ' + @gl_account + ' does not exist in JDE.' + char(13) + char(10)

--	else if isnull(@is_postable,0) <> 1
--		set @error_msg = isnull(@error_msg,'') + 'GL Account ' + @gl_account + ' exists in JDE, but is not postable.' + char(13) + char(10)

--	fetch c_val_gl into @gl_account
--end

--close c_val_gl
--deallocate c_val_gl

---- AR
--declare c_val_ar cursor forward_only read_only for
--select distinct left(jde_gl_account_code,2)
--from EQ_Extract..FlashAccrualReport (nolock)
--where flash_accrual_id = @flash_accrual_id
--and isnull(exclude_flag,0) = 0

--open c_val_ar
--fetch c_val_ar into @jde_company

--while @@FETCH_STATUS = 0
--begin
--	set @gl_account = REPLICATE(' ',8) + @jde_company + '00-12300'

--	exec sp_jde_validate_account @gl_account, @exists output, @is_postable output

--	if isnull(@exists,0) <> 1
--		set @error_msg = isnull(@error_msg,'') + 'GL Account ' + @gl_account + ' does not exist in JDE.' + char(13) + char(10)

--	else if isnull(@is_postable,0) <> 1
--		set @error_msg = isnull(@error_msg,'') + 'GL Account ' + @gl_account + ' exists in JDE, but is not postable.' + char(13) + char(10)

--	fetch c_val_ar into @jde_company
--end

--close c_val_ar
--deallocate c_val_ar


---- if any accounts invalid, report error
--if ISNULL(@error_msg,'') <> ''
--begin
--	set @error_msg = 'Accrual not posted due to the following errors:' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + @error_msg
--	raiserror(@error_msg,16,1)
--	return -1
--end

---- generate accrual lines for GL
--declare c_gl cursor forward_only read_only for
--select jde_gl_account_code, sum(extended_amt)
--from EQ_Extract..FlashAccrualReport (nolock)
--where flash_accrual_id = @flash_accrual_id
--and isnull(exclude_flag,0) = 0
--group by jde_gl_account_code
--order by jde_gl_account_code

--open c_gl
--fetch c_gl into @gl_account, @line_amount

--while @@FETCH_STATUS = 0
--begin
--	set @line_id = @line_id + 1000
--	set @line_id_s = convert(varchar(10),@line_id)

--	exec @rc = JDE.EQFinance.dbo.sp_add_jde_je_line
--		@user, --EDI - User ID
--		@jde_batch_number, --EDI - Batch Number
--		@VNEDTN, --EDI - Transaction Number
--		@line_id_s, --EDI - Line Number
--		@document_company,
--		@document_type,
--		@gl_date,
--		'', --Subledger
--		'', --Subledger Type
--		@gl_account,
--		@line_amount,
--		@explanation, --Explanation
--		'', --Remark/ Explanation
--		'', --Reference 1
--		'', --Reference 2
--		'', --Reference 3
--		'R' --Reversing entry

--	if @@ERROR <> 0 or @rc < 0
--	begin
--		close c_gl
--		deallocate c_gl
--		raiserror('sp_jde_submit_flash_accrual: Error while adding GL entries',16,1)
--		return -1
--	end

--	fetch c_gl into @gl_account, @line_amount
--end

--close c_gl
--deallocate c_gl

---- generate accrual lines for AR
--declare c_ar cursor forward_only read_only for
--select left(jde_gl_account_code,2), sum(extended_amt) * -1.0
--from EQ_Extract..FlashAccrualReport (nolock)
--where flash_accrual_id = @flash_accrual_id
--and isnull(exclude_flag,0) = 0
--group by left(jde_gl_account_code,2)
--order by left(jde_gl_account_code,2)

--open c_ar
--fetch c_ar into @jde_company, @line_amount

--while @@FETCH_STATUS = 0
--begin
--	set @line_id = @line_id + 1000
--	set @line_id_s = convert(varchar(10),@line_id)

--	set @gl_account = REPLICATE(' ',8) + @jde_company + '00-12300'
	
--	exec @rc = JDE.EQFinance.dbo.sp_add_jde_je_line
--		@user, --EDI - User ID
--		@jde_batch_number, --EDI - Batch Number
--		@VNEDTN, --EDI - Transaction Number
--		@line_id_s, --EDI - Line Number
--		@document_company,
--		@document_type,
--		@gl_date,
--		'', --Subledger
--		'', --Subledger Type
--		@gl_account,
--		@line_amount,
--		@explanation, --Explanation
--		'', --Remark/ Explanation
--		'', --Reference 1
--		'', --Reference 2
--		'', --Reference 3
--		'R' --Reversing entry

--	if @@ERROR <> 0 or @rc < 0
--	begin
--		close c_ar
--		deallocate c_ar
--		raiserror('sp_jde_submit_flash_accrual: Error while adding AR entries',16,1)
--		return -1
--	end

--	fetch c_ar into @jde_company, @line_amount
--end

--close c_ar
--deallocate c_ar

---- update Accural log in Plt_ai EQ_Extract
--update EQ_Extract..FlashAccrualLog
--set date_posted_to_jde = getdate()
--where flash_accrual_id = @flash_accrual_id

--if @@ERROR <> 0 or @rc < 0
--begin
--	close c_ar
--	deallocate c_ar
--	raiserror('sp_jde_submit_flash_accrual: Error updating EQ_Extract..FlashAccrualLog',16,1)
--	return -1
--end


--return 0

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jde_submit_flash_accrual] TO [EQAI_LINKED_SERVER]
--    AS [dbo];


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jde_submit_flash_accrual] TO [EQAI]
--    AS [dbo];

