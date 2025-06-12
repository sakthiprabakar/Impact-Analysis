
create procedure sp_gl_validate_account
	@gl_account_code varchar(32),
	@gl_seg_1 varchar(5) OUTPUT,
	@company varchar(2) OUTPUT,
	@profit_ctr varchar(2) OUTPUT,
	@gl_seg_4 varchar(3) OUTPUT,
	@err varchar(255) OUTPUT
as
/****************************************
 *
 * created in NTSQL1.Plt_ai
 *
 * 01/24/2012 rb - Created
 * 
 ****************************************/

-- strip leading and trailing spaces, remove dashes, replace embedded spaces with zeroes
select @err = null,
		@gl_account_code = ISNULL(REPLACE(REPLACE(LTRIM(RTRIM(@gl_account_code)),'-',''),' ','0'),'')

-- if not exactly 12 characters in length, error
if DATALENGTH(@gl_account_code) <> 12
begin
	select @err = 'GL Account Code ' + @gl_account_code + ' is not 12 digits in length.'
	return -1
end

-- validate embedded gl_seg_1
if ISNUMERIC(substring(@gl_account_code,1,5)) < 1
	select @err = case when @err is null then '' else @err + ', ' end + 'Natural (' + substring(@gl_account_code,1,5) + ')'

-- validate embedded company code
if ISNUMERIC(substring(@gl_account_code,6,2)) < 1
	select @err = case when @err is null then '' else @err + ', ' end + 'Company (' + substring(@gl_account_code,6,2) + ')'

-- validate embedded profit_ctr code
if ISNUMERIC(substring(@gl_account_code,8,2)) < 1
	select @err = case when @err is null then '' else @err + ', ' end + 'Profit Ctr (' + substring(@gl_account_code,8,2) + ')'

-- validate embedded gl_seg_4
if ISNUMERIC(substring(@gl_account_code,10,3)) < 1
	select @err = case when @err is null then '' else @err + ', ' end + 'Department (' + substring(@gl_account_code,10,3) + ')'

-- if error
if @err is not null
begin
	select @err = 'GL Account Code ' + @gl_account_code + ' contains invalid segment(s): ' + @err + '.'
	return -1
end
	
-- extract gl_seg_1, company_id, profit_ctr_id, and gl_seg_4
select @gl_seg_1	= LEFT(@gl_account_code,5),
		@company	= substring(@gl_account_code,6,2),
		@profit_ctr	= substring(@gl_account_code,8,2),
		@gl_seg_4	= RIGHT(@gl_account_code,3),
		@err		= null

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gl_validate_account] TO PUBLIC
    AS [dbo];

