
create proc sp_reports_GE_generator_onboarding_detail__baseline_detail (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_detail__baseline_detail

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_GE_generator_onboarding_detail__baseline_detail 168770
**************************************************************************** */

declare @baseline_id int = 1

	-----baseline detail with pricing
	select 
		gbh.baseline_id, gbh.generator_id, gbh.baseline_name, 
		gbd.view_on_web, gbd.sequence_id, gbd.prior_vendor, gbd.baseline_group_id, gbg.baseline_group_desc, gbd.plant_description, 
		gbd.disposal_service_description, 
		gbd.description_notes, 
		gbd.disposal_quantity, gbd.disposal_unit, gbp.disposal_unit_cost, round((gbd.disposal_quantity * gbp.disposal_unit_cost), 2) as 'Disposal Total',
		gbd.trans_quantity, gbd.trans_unit, gbp.trans_unit_cost, round((gbd.trans_quantity * gbp.trans_unit_cost), 2) as 'Trans Total',
		gbp.trans_fuel_surcharge_annual_cost,
		gbd.services_quantity, gbd.services_unit, gbp.services_unit_cost, round((gbd.services_quantity * gbp.services_unit_cost), 2) as 'Services Total',
		gbd.services_description, 
		gbd.note, 
		gbd.assumptions 
	from GeneratorBaselineHeader gbh 
		join generatorbaselinedetail gbd on gbh.baseline_id = gbd.baseline_id
			and gbh.generator_id = gbd.generator_id
		join generatorbaselinepricing gbp
			on gbh.baseline_id = gbp.baseline_id
			and gbd.line_id = gbp.line_id
			and gbp.year = 0
		left outer join generatorbaselinegroup gbg
			on gbd.baseline_group_id = gbg.baseline_group_id
	where gbh.generator_id = @generator_id
		and gbh.baseline_id = @baseline_id
		and gbh.view_on_web = 'T'
	order by gbg.baseline_group_id, gbd.sequence_id
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__baseline_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__baseline_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__baseline_detail] TO [EQAI]
    AS [dbo];

