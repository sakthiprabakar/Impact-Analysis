
create proc sp_reports_generator_actionregister_master (
	@ReportType				varchar(max)		= '|ALL|'
	, @StatusList			varchar(max)		= '|ALL|'
	, @customer_id_list		varchar(max)		= '-1'
	, @generator_id_list	varchar(max)		= '-1'
	, @site_type_list		varchar(max)		= ''
	, @generator_state_list	varchar(max)		= ''
	, @generator_country_list	varchar(max)		= ''
	, @contact_id			int					= 0
)
as
/* ****************************************************************************
sp_reports_generator_actionregister_master

Returns multiple recordsets depending on @query_type for use in the Onboarding Progress report
This started out as a copy of sp_reports_GE_generator_onboarding_summary - same inputs/filter logic.
As sp_reports_GE_generator_criteria_master, all it has to do is return generator_id.


exec sp_reports_generator_actionregister_master
	@ReportType				= 'ALL'	--'All'
	, @StatusList			= 'ALL'
	, @customer_id_list		= '-1'
	, @generator_id_list	= '169152'
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
		, Replace('|'+Replace(Replace(@ReportType, ',', '|'), ' ', '')+'|', '||', '|') as ReportType
		, Replace('|'+Replace(Replace(@StatusList, ',', '|'), ' ', '')+'|', '||', '|') as StatusList
	from #generator g
	inner join ActionRegister ar
		on g.generator_id = ar.generator_id
		and ar.action_type_id = case 
			when @ReportType like '%ALL%' then ar.action_type_id
			when @ReportType like '%SCAR%' then 3
			when @ReportType like '%UN%' then 4
			when @ReportType like '%LL%' and @ReportType not like '%ALL%' then 5
			when @ReportType like '%INC%' then 6
			when @ReportType like '%IMP%' then 7
		else 99999 end
		and ar.status = case
			when @StatusList like '%ALL%' then ar.status
			when @StatusList like '%A%' and @StatusList not like '%ALL%' then 'A'
			when @StatusList like '%C%' then 'C'
			when @StatusList like '%O%' then 'O'
			when @StatusList like '%V%' then 'V'
		else '!' end
		and ar.status <> 'V'
		and ar.view_on_web = 'T'
					

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_actionregister_master] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_actionregister_master] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_actionregister_master] TO [EQAI]
    AS [dbo];

