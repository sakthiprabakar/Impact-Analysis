
create proc sp_reports_GE_waste_ranking_master (
	@start_date				datetime = NULL	-- Service Start Date
	, @end_date				datetime = NULL	-- Service End Date
	, @group_by				varchar(max) = 'waste stream'
	, @result_count			int = 20
	, @total_field			varchar(max) = 'total_pounds'
	, @customer_id_list		varchar(max)		= '-1'
	, @generator_id_list	varchar(max)		= '-1'
	, @site_type_list		varchar(max)		= ''
	, @generator_state_list	varchar(max)		= ''
	, @generator_country_list	varchar(max)		= ''
	, @contact_id			int					= 0
)
as
/* ****************************************************************************
sp_reports_GE_waste_ranking_master

Returns multiple recordsets depending on @query_type for use in the Onboarding Progress report
This started out as a copy of sp_reports_GE_generator_onboarding_summary - same inputs/filter logic.
As sp_reports_GE_generator_criteria_master, all it has to do is return generator_id.

SELECT * FROM ContactXref WHERE customer_id = 18459
SELECT * FROM WasteSummaryStats WHERE generator_id in ('117871', '168770', '169109', '169151', '169208', '169209', '169224', '169225')


exec sp_reports_GE_waste_ranking_master
	@start_date				= '1/1/2016'	-- Service Start Date
	, @end_date				= '1/1/2020'	-- Service End Date
	, @group_by				= 'waste stream'
	, @result_count			= 20
	, @total_field			= 'total_pounds'
	, @customer_id_list		= '-1'
	, @generator_id_list	= '-1'
	, @site_type_list	= ''
	, @generator_state_list	= ''
	, @generator_country_list	= ''
	, @contact_id		= -1 -- associates

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


-- Handle text inputs into temp tables
	CREATE TABLE #Generator (generator_id int)
	INSERT #Generator 
	EXEC sp_reports_GE_generator_criteria_master
	@customer_id_list		= @customer_id_list_i
	, @generator_id_list	= @generator_id_list_i
	, @site_type_list	= @site_Type_list_i
	, @generator_state_list	= @generator_state_list_i
	, @generator_country_list	= @generator_country_list_i
	, @contact_id		= @contact_id_i

-- Setup is finished.  On to work:

	select distinct
		g.generator_id
		, @start_date	as start_date
		, @end_date		as end_date
		, @group_by		as group_by
		, @result_count	as result_count
		, @total_field	as total_field
	from #generator g
	where g.generator_id is not null
/*	
	inner join WasteSummaryStats ws
		on g.generator_id = ws.generator_id
	WHERE ws.service_date between @start_date and @end_date
*/
					

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_waste_ranking_master] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_waste_ranking_master] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_waste_ranking_master] TO [EQAI]
    AS [dbo];

