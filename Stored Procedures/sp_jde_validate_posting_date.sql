
CREATE PROCEDURE sp_jde_validate_posting_date
	@gl_date datetime = null
AS
/***************************************************************
Loads to:	Plt_AI

Checks that a date is valid for posting in JDE

07/29/2013 RB	Created
07/08/2014 RB	June 2014 was split into 2 periods (06/01-06/17 is period 6, 06/18-06/30 is period 7)
****************************************************************/
DECLARE @open_posting_year int,
		@open_posting_period_gl int,
		@open_posting_period_ar int,
		@gl_period1 varchar(7),
		@gl_period2 varchar(7),
		@ar_period1 varchar(7),
		@ar_period2 varchar(7),
		@msg varchar(255)

if @gl_date is null
	set @gl_date = GETDATE()

SELECT @open_posting_year = CONVERT(int, ROUND(date_fiscal_year_begins_CCDFYJ/1000,0)-100) + 2000,
	@open_posting_period_gl = current_period_CCPNC,
	@open_posting_period_ar = ar_period_number_CCARPN
FROM JDE.EQFinance.dbo.JDECompanyConstants_F0010
WHERE company_CCCO='01100'

-- rb 07/08/2014 Kludge for 2014...it would be good to reference F0008 table for actual date ranges, but for
--		now, adjust for the June split. This code assumed periods were actual month values and compared
--		the @gl_date month to them. If period is greater than 6, subtract one for the comparison
if @open_posting_year = 2014
begin
	if @open_posting_period_gl > 6
		set @open_posting_period_gl = @open_posting_period_gl - 1

	if @open_posting_period_ar > 6
		set @open_posting_period_ar = @open_posting_period_ar - 1
end
-- rb 07/08/2014 end kludge

set @gl_period1 = CONVERT(varchar(4),@open_posting_year) + '-' + CONVERT(varchar(2),@open_posting_period_gl)
set @ar_period1 = CONVERT(varchar(4),@open_posting_year) + '-' + CONVERT(varchar(2),@open_posting_period_ar)

if @open_posting_period_gl = 12
	set @gl_period2 = CONVERT(varchar(4),@open_posting_year+1) + '-1'
else
	set @gl_period2 = CONVERT(varchar(4),@open_posting_year) + '-' + CONVERT(varchar(2),@open_posting_period_gl+1)

if @open_posting_period_ar = 12
	set @ar_period2 = CONVERT(varchar(4),@open_posting_year+1) + '-1'
else
	set @ar_period2 = CONVERT(varchar(4),@open_posting_year) + '-' + CONVERT(varchar(2),@open_posting_period_ar+1)

if CONVERT(varchar(4),datepart(yy,@gl_date)) + '-' + CONVERT(varchar(4),datepart(mm,@gl_date)) not in (@gl_period1, @gl_period2)
	or CONVERT(varchar(4),datepart(yy,@gl_date)) + '-' + CONVERT(varchar(4),datepart(mm,@gl_date)) not in (@ar_period1, @ar_period2)
begin
	select @msg = 'ERROR: The posting date of ' + CONVERT(varchar(10),@gl_date,101) + ' is not within the currently open period in JDE.'
	raiserror(@msg,16,1)
	return -1
end

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_jde_validate_posting_date] TO [EQAI]
    AS [dbo];

