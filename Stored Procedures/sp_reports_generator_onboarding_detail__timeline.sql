
create proc sp_reports_generator_onboarding_detail__timeline (
	@generator_id		int,
	@customer_id_list varchar(max)='',  /* Added 2019-07-16 by AA */
    @generator_id_list varchar(max)=''  /* Added 2019-07-16 by AA */
)
as
/* ****************************************************************************
sp_reports_generator_onboarding_detail__timeline

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_generator_onboarding_detail__timeline 168770
**************************************************************************** */

	--Onboarding timeline data
	select gth.description, gth.generator_id, gtd.task_id, gtd.sort_order, gtd.task_short_desc, gtd.task_actual_start, gtd.task_actual_end, gtd.overall_percentage
	 from generatortimelineheader gth 
	join generatortimelinedetail gtd 
	on gth.timeline_id = gtd.timeline_id and gth.generator_id = gtd.generator_id
	where gth.generator_id = @generator_id
	and gtd.parent_task_id is null
	and gtd.task_external_view = 'Y'
	order by gth.timeline_id, gtd.sort_order
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__timeline] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__timeline] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__timeline] TO [EQAI]
    AS [dbo];

