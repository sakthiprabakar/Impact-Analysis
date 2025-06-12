
create proc sp_reports_generator_baseline_master (
	@ReportType				varchar(max)		= '|ALL|'
	, @customer_id_list		varchar(max)		= '-1'
	, @generator_id_list	varchar(max)		= '-1'
	, @site_type_list		varchar(max)		= ''
	, @generator_state_list	varchar(max)		= ''
	, @generator_country_list	varchar(max)		= ''
	, @contact_id			int					= 0
)
as
/* ****************************************************************************
sp_reports_generator_baseline_master

sp_helptext sp_reports_generator_baseline_master

Returns multiple recordsets depending on @query_type for use in the Onboarding Progress report
This started out as a copy of sp_reports_GE_generator_onboarding_summary - same inputs/filter logic.
As sp_reports_generator_baseline_master, all it has to do is return generator_id.


exec sp_reports_generator_baseline_master
	@ReportType				= 'detail'	--'All'
	, @customer_id_list		= '18459'
	, @generator_id_list	= null
	, @site_type_list	= 'GE Transportation' -- 'GE Additive, GE Aviation, GE Capital, GE Digital, GE Energy Connections, GE Healthcare, GE Lighting, GE Oil & Gas, GE Transportation'
	, @generator_state_list	= null
	, @generator_country_list	= null
	, @contact_id		= -1 -- associates

	EXEC sp_reports_generator_criteria_master
	@customer_id_list		= null
	, @generator_id_list	= null
	, @site_type_list	= 'GE Transportation'
	, @generator_state_list	= null
	, @generator_country_list	= null
	, @contact_id		= -1


SELECT  * FROM  generator where generator_id in (117871, 169151)
117871, 169151)

SELECT TOP 10 * FROM Message order by message_id desc

@Customer_id_list: -1  @generator_id_list_i: 117871  @site_type_list_i: GE Additive, GE Aviation, GE Capital, GE Digital, GE Energy Connections, GE Healthcare, GE Lighting, GE Oil & Gas, GE Transportation  @generator_state_list_i:   @generator_country_list_i:   @contact_id_i: -1  ----------------------------  Output:  117871

**************************************************************************** */
-- Input setup:

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE
		@genCount 		INT = 0
		, @customer_id_list_i		varchar(max)	= @customer_id_list
		, @generator_id_list_i	varchar(max)		= @generator_id_list
		, @site_type_list_i		varchar(max)		= @site_type_list
		, @generator_state_list_i	varchar(max)		= @generator_state_list
		, @generator_country_list_i	varchar(max)	= @generator_country_list
		, @contact_id_i			int					= @contact_id


if 1=0 begin
	declare @dbgInfo varchar(max) = ''
	set @dbgInfo = @dbgInfo + '@Customer_id_list: ' + @customer_id_list_i + '
'
	set @dbgInfo = @dbgInfo + '@generator_id_list_i: ' + @generator_id_list_i + '
'
	set @dbgInfo = @dbgInfo + '@site_type_list_i: ' + @site_type_list_i + '
'
	set @dbgInfo = @dbgInfo + '@generator_state_list_i: ' + @generator_state_list_i + '
'
	set @dbgInfo = @dbgInfo + '@generator_country_list_i: ' + @generator_country_list_i + '
'
	set @dbgInfo = @dbgInfo + '@contact_id_i: ' + convert(Varchar(20), @contact_id_i) + '
'

	set @dbgInfo = @dbgInfo + '----------------------------
'

end	

-- Handle text inputs into temp tables
	CREATE TABLE #Generator (generator_id int)
	INSERT #Generator 
	EXEC sp_reports_generator_criteria_master
	@customer_id_list		= @customer_id_list_i
	, @generator_id_list	= @generator_id_list_i
	, @site_type_list	= @site_Type_list_i
	, @generator_state_list	= @generator_state_list_i
	, @generator_country_list	= @generator_country_list_i
	, @contact_id		= @contact_id_i

-- Setup is finished.  On to work:

	select distinct
		g.generator_id
		, @ReportType as ReportType
		, @contact_id as contact_id
	from #generator g
	join GeneratorBaselineHeader gbh 
		on g.generator_id = gbh.generator_id
		and gbh.view_on_web = 'T'
	join generatorbaselinedetail gbd on gbh.baseline_id = gbd.baseline_id
		and gbh.generator_id = gbd.generator_id
	join generatorbaselinepricing gbp
		on gbh.baseline_id = gbp.baseline_id
		and gbd.line_id = gbp.line_id
		and gbp.year = 0

if 1=0 begin

	select @dbgInfo = @dbgInfo + 'Output: ' + isnull(substring(
		(select ', ' + convert(varchar(20), generator_id)
		from #generator for xml path('')), 2, 200000), '(no output)') 

	declare @n int
	exec @n = sp_message_insert 'sp_reports_generator_baseline_master params', @dbgInfo, '', 'JONATHAN', '', NULL, NULL, NULL
	exec sp_messageAddress_insert @n, 'FROM', 'jonathan.broome@usecology.com', 'Jonathan Broome', NULL, NULL, NULL, NULL
	exec sp_messageAddress_insert @n, 'TO', 'jonathan.broome@usecology.com', 'Jonathan Broome', NULL, NULL, NULL, NULL

end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_baseline_master] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_baseline_master] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_baseline_master] TO [EQAI]
    AS [dbo];

