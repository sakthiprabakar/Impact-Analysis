
CREATE PROC sp_rpt_container_billing_status_ud (
	@start_date			datetime
	, @end_date			datetime
	, @user_code		varchar(10)
	, @permission_id	int
	, @report_log_id	int		-- Report Log ID for export purposes
)
AS
/* *****************************************************************************************************

sp_rpt_container_billing_status_ud

	A cheap trick to call sp_rpt_container_billing_status with the 'BU' parameter hard-coded

History
	7/30/2014	JPB	Created
	
Sample

-- sp_sequence_next 'reportlog.report_log_id'

	sp_rpt_container_billing_status_ud 
		-- @Report_Type		= 'BU'	-- Or 'UD'.  This is an amalgam of these individual script parameters...
		@start_date		= '7/1/2014'
		, @end_date			= '7/31/2014'
		, @report_log_id	= 271714
		
-- SELECT * FROM plt_export..export where report_log_id = 271714

***************************************************************************************************** */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare
	@start_date_in		datetime	= @start_date
	, @end_date_in		datetime	= @end_date
	, @user_code_in		varchar(10)	= @user_code
	, @permission_id_in	int			= @permission_id
	, @report_log_id_in	int			= @report_log_id


exec sp_rpt_container_billing_status
	@Report_Type	= 'UD'
	, @start_date	= @start_date_in
	, @end_date		= @end_date_in
	, @user_code    = @user_code_in
	, @permission_id = @permission_id_in
	, @report_log_id = @report_log_id_in
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_billing_status_ud] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_billing_status_ud] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_billing_status_ud] TO [EQAI]
    AS [dbo];

