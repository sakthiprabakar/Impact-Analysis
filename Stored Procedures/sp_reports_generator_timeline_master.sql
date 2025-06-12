
create proc sp_reports_generator_timeline_master (
	 @customer_id_list		varchar(max)		= '-1'
	, @generator_id_list	varchar(max)		= '-1'
	, @site_type_list		varchar(max)		= ''
	, @generator_state_list	varchar(max)		= ''
	, @generator_country_list	varchar(max)		= ''
	, @contact_id			int					= 0
)
as
/* ****************************************************************************
sp_reports_generator_timeline_master

Returns multiple recordsets depending on @query_type for use in the Onboarding Progress report
This started out as a copy of sp_reports_GE_generator_onboarding_summary - same inputs/filter logic.
As sp_reports_generator_timeline_master, all it has to do is return generator_id.


exec sp_reports_generator_timeline_master
	@customer_id_list		= '-1'
	, @generator_id_list	= '-1'
	, @site_type_list	= 'GE Additive, GE Aviation, GE Capital, GE Digital, GE Energy Connections, GE Healthcare, GE Lighting, GE Oil & Gas'
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
	from #generator g
	join generatortimelineheader gth 
		on gth.generator_id = g.generator_id
	join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
	where gth.generator_id = g.generator_id
	and gtd.parent_task_id is null
	and gtd.task_external_view = 'Y'



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_timeline_master] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_timeline_master] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_timeline_master] TO [EQAI]
    AS [dbo];

