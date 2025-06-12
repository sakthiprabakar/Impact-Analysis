
create proc sp_reports_ge_generator_timeline_detail (
	@debug				int					= 0
	, @customer_id		int					= -1
	, @generator_id		int					= -1
	, @site_type_list	varchar(max)		= ''
	, @generator_state_list	varchar(max)	= ''
	, @start_date		datetime			= '1/1/1980'
	, @end_date			datetime			= '12/31/2100'
	, @contact_id		int					= 0 -- -1 for associates
)
AS
/* ************************************************************************************ 
WEB-45010  Generator - Onboarding Report

Please add a report to allow for GE to see the onboarding process for their locations.  This report 
should display the site information and what status in the process the generator location is currently at.

This report should be able to be ran by any of the following:

* viewed for all generators for the user's access, sorted by site type
* viewed for a single site type
* viewed for a single generator
* ran by generators in a single state or set of states
 

The output of this report would list the location and the major timeline tasks and the start and end dates.

Generator Information:
Name, address, city state, zip, EPA ID, generator_id, site type, site code

Timeline information: only tasks that have task_external_view set to T
task id, task description, actual start & end, calculation of total days, calculation of business days

SELECT * FROM generatortimelinedetail

sp_reports_ge_generator_timeline_detail 
	@debug				= 0
	, @customer_id		= -1
	, @generator_id		=  117871 --= test data
	, @site_type_list	= ''
	, @generator_state_list	= ''
	, @start_date		= '1/1/1980'
	, @end_date			= '12/31/2100'
	, @contact_id		= -1 -- -1 for associates

SELECT site_type, * FROM generator where generator_id = 117871
SELECT * FROM GeneratorSiteType where generator_site_type like 'GE%'
-- GAH!  GE Transporation  vs GE Transpor_T_ation
--			Generator			GeneratorSiteType
************************************************************************************ */

-- Input setup:

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE
		@genCount 		INT = 0,
		@getdate 		DATETIME = getdate(),
		@timer_start	datetime = getdate(),
		@last_step		datetime = getdate()

-- end date fix:
	if @end_date is not null and datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Handle text inputs into temp tables
	CREATE TABLE #SiteType (generator_site_type varchar(40))
	INSERT #SiteType SELECT row from dbo.fn_SplitXsvText(',', 1, @site_type_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #State (abbr varchar(2))
	INSERT #State SELECT row from dbo.fn_SplitXsvText(',', 1, @generator_state_list) WHERE ISNULL(row, '') <> ''

-- figure out if this user has inherent access to customers
	CREATE TABLE #generator (generator_id int)
	
	IF @contact_id > 0
	BEGIN
		insert #generator
		select cg.generator_id
		from CustomerGenerator cg
		inner join ContactXRef cxr on cg.customer_id = cxr.customer_id
		Where cxr.contact_id = @contact_id
		AND cxr.status = 'A' and cxr.web_access = 'A'
		union
		select cxr.generator_id
		from ContactXRef cxr
		Where cxr.contact_id = @contact_id
		AND cxr.status = 'A' and cxr.web_access = 'A' 
		
		select @genCount = count(*) from #generator
	END

	IF @contact_id = -1 -- Associates:
	BEGIN
		if not (@customer_id = -1 and @generator_id = -1 and @site_type_list = '') 
		begin
			insert #generator
			select cg.generator_id
			from CustomerGenerator cg
			Where cg.customer_id = @customer_id
			union
			select g.generator_id
			from Generator g
			Where generator_id = @generator_id
			union
			select g.generator_id
			from Generator g
			Where site_type in (select generator_site_type from #SiteType)
		
			set @genCount = @@rowcount
		end
	END

    IF @debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)

-- abort if there's nothing possible to see
	if @genCount + 
		(select count(*) from #SiteType) +
		(select count(*) from #State)
		= 0 RETURN

	IF @genCount <= 0
		RETURN

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Setup' as last_step_desc
	set @last_step = getdate()

	if (select count(*) from #SiteType) > 0 and (@customer_id = -1 and @generator_id = -1)
		delete from #generator
		WHERE generator_id not in (
			select g1.generator_id from #generator g1
			join generator g2 on g1.generator_id = g2.generator_id
			where g2.site_type in (select generator_site_type FROM #SiteType)
		)
	
	if (select count(*) from #State) > 0 and (@customer_id = -1 and @generator_id = -1)
		delete from #generator
		WHERE generator_id not in (
			select g1.generator_id from #generator g1
			join generator g2 on g1.generator_id = g2.generator_id
			where g2.generator_state in (select abbr FROM #State)
		)

	if (@generator_id <> -1)
		delete from #generator
		where generator_id <> @generator_id

-- Setup is finished.  On to work:
	select 
	g.Generator_ID
	, G.Generator_Name
	, G.EPA_ID Generator_EPA_ID
	, G.Site_Code Generator_Site_Code
	, G.Generator_Address_1
	, G.Generator_Address_2
	, G.Generator_Address_3
	, G.Generator_City
	, G.Generator_State
	, G.Generator_Zip_Code
	, G.Generator_Phone
	, G.Site_Classification Generator_Site_Classification
	, G.Sub_Business_Segment Generator_Sub_Business_Segment
	, H.Generator_ID Header_Generator_ID
	, H.Timeline_ID Header_Timeline_ID
	, H.Description Header_Description 
	, H.Source_Template_ID Header_Source_Template_ID 
	, H.Source_Template_ID_Version Header_Source_Template_ID_Version 
	, H.Added_By Header_Added_By 
	, H.Date_Added Header_Date_Added 
	, H.Modified_By Header_Modified_By
	, H.Date_Modified Header_Date_Modified
	, D.Generator_ID Detail_Generator_ID
	, D.Timeline_ID Detail_Timeline_ID
	, D.Task_ID Detail_Task_ID
	, D.Task_Short_Desc Detail_Task_Short_Desc
	, D.Task_Text Detail_Task_Text
	, D.Expected_Task_Duration_In_Days Detail_Expected_Task_Duration_In_Days
	, D.Parent_Task_ID Detail_Parent_Task_ID
	, D.Task_Required Detail_Task_Required
	, D.Task_Target_Start Detail_Task_Target_Start
	, D.Task_Target_End Detail_Task_Target_End
	, D.Task_Actual_Start Detail_Task_Actual_Start
	, D.Task_Actual_End Detail_Task_Actual_End
	, D.Task_External_View Detail_Task_External_View
	, D.Assigned_To Detail_Assigned_To
	, D.Assigned_To_Generator Detail_Assigned_To_Generator
	, D.Sort_Order Detail_Sort_Order
	, D.Task_From_Template Detail_Task_From_Template
	, D.Task_Notes Detail_Task_Notes
	, D.Added_By Detail_Added_By
	, D.Date_Added Detail_Date_Added
	, D.Modified_By Detail_Modified_By
	, D.Date_Modified Detail_Date_Modified
	, D.Responsible_Party Detail_Responsible_Party
	, D.Overall_Percentage Detail_Overall_Percentage
	from generatortimelineheader h
	join generatortimelinedetail d
		on h.generator_id = d.generator_id
		and h.timeline_id = d.timeline_id
	join #generator filter
		on h.generator_id = filter.generator_id
	join generator g 
		on filter.generator_id = g.generator_id
	where 1=1
	-- and h.generator_id = 117871
	and d.task_external_view = 'Y' 
	order by h.timeline_id, d.sort_order


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_ge_generator_timeline_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_ge_generator_timeline_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_ge_generator_timeline_detail] TO [EQAI]
    AS [dbo];

