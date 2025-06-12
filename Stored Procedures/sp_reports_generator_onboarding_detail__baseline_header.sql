
create proc sp_reports_generator_onboarding_detail__baseline_header (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_generator_onboarding_detail__baseline_header

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_generator_onboarding_detail__baseline_header 168770
**************************************************************************** */

declare @baseline_id int = 1

	select 
		gbh.baseline_id, gbh.generator_id, gbh.baseline_name, gbh.date_entry_complete, gbh.date_approved, gbh.internal_approved_by, gbh.external_approved_by
	from GeneratorBaselineHeader gbh 
	where gbh.generator_id = @generator_id
		and gbh.baseline_id = @baseline_id
		and gbh.view_on_web = 'T'
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__baseline_header] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__baseline_header] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__baseline_header] TO [EQAI]
    AS [dbo];

