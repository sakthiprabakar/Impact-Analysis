
create proc sp_reports_GE_generator_baseline_report (
	@customer_id		varchar(max)		= '-1'
	, @generator_id		varchar(max)		= '-1'
	, @site_type_list	varchar(max)		= ''
	, @generator_state_list	varchar(max)	= ''
	, @generator_country_list	varchar(max)	= ''
	, @contact_id		int = 0
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_summary

Returns multiple recordsets depending on @query_type for use in the Onboarding Progress report

Query Type		Returns
-----------------------
percent_done	1 row, 1 field: The percentage of onboarding tasks done


select * from generator g where g.generator_state = 'TX' and g.generator_city = 'Fort Worth'
and g.generator_name like '%general%'

select site_type, * from generator where site_type is not null and site_type like 'GE %'
--3 options
--generator_id
--117871
--168770
--169109

	@generator_id		int	= 168770 

sp_reports_GE_generator_onboarding_summary @site_type_list='GE Aviation,GE Healthcare,GE Oil & Gas,GE Power,GE Transportation, GE Transportation', @contact_id=-1

select * from GeneratorSiteType

---  Onboarding percentage calculation for all site types
select g.site_type, g.generator_id, g.generator_name, g.generator_city, g.generator_state, g.generator_country, sum(gtd.overall_percentage) from generatortimelineheader gth 
join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
join generator g 
	on gth.generator_id = g.generator_id
where 
--gth.generator_id = 168770--@generator_id
g.site_type in ( select generator_site_type from generatorsitetype where generator_site_type like 'GE %' )
and gtd.parent_task_id is null
and gtd.task_external_view = 'Y'
and gtd.task_actual_end is not null
group by g.generator_id, g.site_type, g.generator_name, g.generator_city, g.generator_state, g.generator_country
order by g.site_type

168770

SELECT * FROM GeneratorBaselineHeader

SELECT * FROM GeneratorBaselineDetail

exec sp_reports_GE_generator_baseline_report
	@customer_id		= -1
	, @generator_id	= -1
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
		
	CREATE TABLE #generator (generator_id int)

	declare -- This amounts to parameter spoofing too, to avoid bad cached execution plans:
	@Icustomer_id		varchar(max)		= @customer_id
	, @Igenerator_id	varchar(max)		= @generator_id
	, @Isite_type_list	varchar(max)		= @site_type_list
	, @Igenerator_state_list	varchar(max)	= @generator_state_list
	, @Igenerator_country_list	varchar(max)	= @generator_country_list
	, @Icontact_id		int = @contact_id

	insert #Generator
	exec sp_reports_GE_generator_criteria_master
		@customer_id_list		= @Icustomer_id
		, @generator_id_list	= @Igenerator_id
		, @site_type_list	= @Isite_type_list
		, @generator_state_list	= @Igenerator_state_list
		, @generator_country_list	= @Igenerator_country_list
		, @contact_id		= @Icontact_id

-- SELECT * FROM #generator

/*




-----Generator contact information
select 
	g.generator_name, 
	g.epa_id, 
	g.generator_id, 
	isnull(g.generator_address_1, ''), 
	isnull(g.generator_address_2,  ''), 
	isnull(g.generator_address_3,  ''), 
	isnull(g.generator_address_4,  ''), 
	isnull(g.generator_address_5,  ''), 
	g.generator_city, 
	g.generator_state, 
	g.generator_zip_code, 
	g.generator_country, 
	isnull(g.generator_phone, ''), 
	gt.generator_type
--	,* 
into #contact
from generator g 
	join #generator filter on g.generator_id = filter.generator_id
	join generatortype gt on g.generator_type_id = gt.generator_type_id
--where g.generator_id = @generator_id
order by g.generator_id
*/

-- select * from generator where added_by = 'SA' and date_added >= '9/12/2017' and date_added <= '9/13/2017'

/*
-----baseline header
select 
	gbh.baseline_id, gbh.generator_id, gbh.baseline_name, gbh.date_entry_complete, gbh.date_approved, gbh.external_approved_by
into #header
from GeneratorBaselineHeader gbh 
join #generator filter on gbh.generator_id = filter.generator_id
where 1=1 --gbh.generator_id = 169151--@generator_id
	and gbh.baseline_id = 3--@baseline_id
	and gbh.view_on_web = 'T'
ORDER BY gbh.generator_id, gbh.baseline_id,



create table #generator (generator_id int)
insert #generator values (169109), (169208), (169209), (169224), (169225);
*/

-----baseline detail with pricing
select 
	gbh.Baseline_Id, Gbh.Generator_Id, Gbh.Baseline_Name, Gbh.Date_Entry_Complete, Gbh.Date_Approved, Gbh.External_Approved_By,
	gbd.View_On_Web, Gbd.Sequence_Id, Gbd.Prior_Vendor, Gbd.Baseline_Group_Id, Gbg.Baseline_Group_Desc, Gbd.Plant_Description, 
	gbd.Disposal_Service_Description, 
	gbd.Description_Notes, 
	gbd.Disposal_Quantity, Gbd.Disposal_Unit, Gbp.Disposal_Unit_Cost, Round((isnull(gbd.Disposal_Quantity, 0) * isnull(Gbp.Disposal_Unit_Cost, 0)), 2) As 'Disposal Total',
	gbd.Trans_Quantity, Gbd.Trans_Unit, Gbp.Trans_Unit_Cost, Round((isnull(gbd.Trans_Quantity, 0) * isnull(Gbp.Trans_Unit_Cost, 0)), 2) As 'Trans Total',
	gbp.Trans_Fuel_Surcharge_Annual_Cost,
	gbd.Services_Quantity, Gbd.Services_Unit, Gbp.Services_Unit_Cost, Round((isnull(gbd.Services_Quantity, 0) * isnull(Gbp.Services_Unit_Cost, 0)), 2) As 'Services Total',
	gbd.Services_Description, 
	gbd.Note, 
	gbd.Assumptions 
		,
		g.generator_name, 
		dbo.fn_format_epa_id(g.epa_id) epa_id, 
		g.generator_id, 
		isnull(g.generator_address_1, '') generator_address_1, 
		isnull(g.generator_address_2,  '') generator_address_2, 
		isnull(g.generator_address_3,  '') generator_address_3, 
		isnull(g.generator_address_4,  '') generator_address_4, 
		isnull(g.generator_address_5,  '') generator_address_5, 
		g.generator_city, 
		g.generator_state, 
		g.generator_zip_code, 
		g.generator_country, 
		isnull(g.generator_phone, '') generator_phone, 
		gt.generator_type,
		g.site_type

-- select *
from GeneratorBaselineHeader gbh 
	join #generator filter on gbh.generator_id = filter.generator_id
	join generator g on gbh.generator_id = g.generator_id
		left join generatortype gt on g.generator_type_id = gt.generator_type_id
	join generatorbaselinedetail gbd on gbh.baseline_id = gbd.baseline_id
		and gbh.generator_id = gbd.generator_id
	join generatorbaselinepricing gbp
		on gbh.baseline_id = gbp.baseline_id
		and gbd.line_id = gbp.line_id
		and gbp.year = 0
	left outer join generatorbaselinegroup gbg
		on gbd.baseline_group_id = gbg.baseline_group_id
where 1=1 -- gbh.generator_id = 169151--@generator_id

-- there are no baseline_id = 3 cases.  There are some baseline = 2 cases though.
	-- and gbh.baseline_id = 2 -- 3--@baseline_id
	
	
	--and gbh.view_on_web = 'T'
order by gbh.generator_id, gbh.baseline_id, gbg.baseline_group_id, gbd.plant_description, gbd.sequence_id



--(  isnull(round((gbd.disposal_quantity * gbp.disposal_unit_cost), 2), 0) + isnull(round((gbd.trans_quantity * gbp.trans_unit_cost), 2), 0) + isnull(gbp.trans_fuel_surcharge_annual_cost, 0) + isnull(round((gbd.services_quantity * gbp.services_unit_cost), 2), 0)) as 'Baseline Total'

-----baseline detail summed for the entire baseline
-----baseline detail summed for the baseline group
-----baseline detail summed for the baseline group and plant description


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_baseline_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_baseline_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_baseline_report] TO [EQAI]
    AS [dbo];

