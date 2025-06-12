
create proc sp_reports_GE_generator_AAAonboarding_detail__percent_done (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_detail__percent_done

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_GE_generator_AAAonboarding_detail__percent_done 168770
**************************************************************************** */

	---  Onboarding percentage calculation
	select sum(gtd.overall_percentage) percent_done from generatortimelineheader gth 
	join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
	where gth.generator_id = @generator_id
	and gtd.parent_task_id is null
	and gtd.task_external_view = 'Y'
	and gtd.task_actual_end is not null
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_AAAonboarding_detail__percent_done] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_AAAonboarding_detail__percent_done] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_AAAonboarding_detail__percent_done] TO [EQAI]
    AS [dbo];

