
Create Procedure sp_reports_profile_approval_detail (
    @profile_id 			int
)
AS
/************************************************************
Procedure    : sp_reports_profile_approval_detail
Database     : PLT_AI*
Created      : Fri Nov 10 11:01:35 EST 2006 - Jonathan Broome
Filename     : L:\Apps\SQL\EQAI\PLT_AI\sp_reports_profile_approval_detail.sql
Description  : Returns information about profile approval time for a single profile id.

2/14/2008 - JPB - Wrap comparisons to manual_bypass_tracking_flag with IsNull(,'F')
1/15/2016 - JPB	Modified minutes counting to handle null time_out values

Requires	: fn_approval_code_list

sp_reports_profile_approval_detail 224693
************************************************************/
	SET ANSI_WARNINGS OFF

	-- Profile Info
	select p.profile_id,
		p.customer_id,
		c.cust_name,
		p.generator_id,
		g.generator_name,
		g.epa_id,
		p.approval_desc,
		sum (
			case when pl.bypass_tracking_flag = 'F' then
				case when pt.business_minutes is not null then pt.business_minutes 
					ELSE
						/* 2016-01-11 - JPB:    dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))  */
						case when pt.tracking_status = 'COMP' then 
							dbo.fn_business_minutes(pt.time_in, Coalesce(pt.time_out, pt.time_in, getdate())) 
						else
							dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
						end
					END
			else
				0
			end) as eq_minutes,
		sum (
			case when pl.bypass_tracking_flag = 'T' then
				case when pt.business_minutes is not null then pt.business_minutes 
					ELSE
						/* 2016-01-11 - JPB:    dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))  */
						case when pt.tracking_status = 'COMP' then 
							dbo.fn_business_minutes(pt.time_in, Coalesce(pt.time_out, pt.time_in, getdate())) 
						else
							dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
						end
					END
			else
				0
			end) as cust_minutes,
		sum (case when pt.business_minutes is not null then pt.business_minutes 
					ELSE
						/* 2016-01-11 - JPB:    dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))  */
						case when pt.tracking_status = 'COMP' then 
							dbo.fn_business_minutes(pt.time_in, Coalesce(pt.time_out, pt.time_in, getdate())) 
						else
							dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
						end
					END
			) as all_minutes
	from
		profile p
		left outer join profilequoteapproval pqa on p.profile_id = pqa.profile_id
		left outer join profiletracking pt on p.profile_id = pt.profile_id and p.profile_tracking_id = pt.tracking_id
		left outer join profilelookup pl on pt.tracking_status = pl.code and pl.type='TrackingStatus'
		left outer join customer c on p.customer_id = c.customer_id
		left outer join generator g on p.generator_id = g.generator_id
	where p.profile_id = @profile_id
	group by  
		p.profile_id,
		p.customer_id,
		c.cust_name,
		p.generator_id,
		g.generator_name,
		g.epa_id,
		p.approval_desc
	
		
	-- Treatment info
	select pt.treatment_id, 
		t.treatment_desc 
	from profiletreatment pt 
		inner join treatment t on pt.treatment_id = t.treatment_id
	where pt.profile_id = @profile_id
	order by pt.primary_flag desc, 
		t.treatment_desc
	
	
	-- Approval info
	select pqa.company_id, 
		pqa.profit_ctr_id,
		pqa.approval_code
	from profilequoteapproval pqa
	where pqa.profile_id = @profile_id
		and pqa.status = 'A'
	order by pqa.company_id,
		pqa.profit_ctr_id,
		pqa.approval_code
	
	-- ProfileTracking info
	select
		pt.tracking_id,
		pt.profile_id,
		pt.time_in,
		pt.time_out,
		pt.comment,
		isnull(pt.manual_bypass_tracking_flag, 'F') as manual_bypass_tracking_flag,
		pt.manual_bypass_tracking_reason,
		pt.manual_bypass_tracking_by,
		case when pt.business_minutes is not null then 
			pt.business_minutes 
		ELSE
			/* 2016-01-11 - JPB:    dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))  */
			case when pt.tracking_status = 'COMP' then 
				dbo.fn_business_minutes(pt.time_in, Coalesce(pt.time_out, pt.time_in, getdate())) 
			else
				dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
			end
		END as business_minutes,
		pl.description,
		pl.bypass_tracking_flag,
		d.department_description,
		u.user_name
	from profiletracking pt 
		left outer join profilelookup pl on pt.tracking_status = pl.code and pl.type='TrackingStatus'
		left outer join department d on pt.department_id = d.department_id
		left outer join users u on pt.eq_contact = u.user_code
	where pt.profile_id = @profile_id
	and pt.tracking_id <= (isnull((select min(tracking_id) from profiletracking where profile_id = pt.profile_id and tracking_status = 'COMP'), pt.tracking_id))
	order by
		pt.profile_id,
		pt.tracking_id,
		pt.time_in

	SET ANSI_WARNINGS ON
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profile_approval_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profile_approval_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_profile_approval_detail] TO [EQAI]
    AS [dbo];

