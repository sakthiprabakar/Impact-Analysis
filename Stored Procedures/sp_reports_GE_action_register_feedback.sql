
create proc sp_reports_GE_action_register_feedback (
	@generator_id		int = null
	, @notes			nvarchar(500) = null
	, @start_date		datetime = null
	, @end_date			datetime = null
	, @financial_impact	money = null
	, @contact_name		nvarchar(500) = null
	, @app				varchar(10) = 'Web' -- or 'MIM'?
)
as
/* ****************************************************************************
sp_reports_GE_action_register_feedback

procedure for web site inserts into the generator action register as dictated
by GE contract reqs.

sp_reports_GE_action_register_feedback
	@generator_id = 168770
	, @notes = 'Sample Notes'
	, @start_date = '9/20/2017'
	, @end_date = '9/20/2017'
	, @financial_impact = 3.50
	, @contact_name = 'Dem Aliens'
	, @app = 'Web'
	
	

SELECT * FROM ActionRegister

**************************************************************************** */

declare @_id int

exec @_id = sp_sequence_next 'ActionRegister.action_register_id'

-- select @_id

Insert ActionRegister
(
action_register_id,
generator_id,
action_type_id,
subject,
notes,
description,
site_contacts,
status,
void_reason,
voided_by,
date_voided,
priority,
escalated_flag,
escalated_to_whom,
date_escalated,
tracking_id,
view_on_web,
site_need_CI_category_id,
site_need_date_raised,
site_need_target_completion_date,
site_need_actual_completion_date,
site_visit_date,
site_visit_target_completion_date,
site_visit_actual_completion_date,
site_visit_next_USE_travel_date,
site_visit_client_contact,
site_visit_site_contact,
scar_start_date,
scar_target_completion_date,
scar_actual_completion_date,
scar_vendor_name,
nonconformance_start_date,
nonconformance_end_date,
nonconformance_root_cause,
lesson_learned_start_date,
incident_start_date,
incident_end_date,
incident_resolution_date,
incident_resolution,
incident_type_id,
incident_estimated_financial_impact,
incident_source,
improvement_type,
improvement_acceptance_status,
improvement_date_raised,
improvement_target_completion_date,
improvement_date_implemented,
improvement_CI_category_id,
improvement_estimated_annual_financial_impact,
improvement_percentage,
improvement_reason_for_denial,
improvement_estimated_waste_volume_impacted,
improvement_estimated_waste_volume_unit,
added_by,
date_added,
modified_by,
date_modified
)
VALUES
(
@_id /* action_register_id */,
@generator_id /* generator_id */,
6 /* action_type_id */,
@app + ' feedback' /* subject */,
@notes /* notes */ ,
null /* description */ ,
@contact_name /* site_contacts */ ,
'O' /* status */ ,
NULL /* void_reason */ ,
NULL /* voided_by */ ,
NULL /* date_voided */ ,
'R' /* priority */ ,
NULL /* escalated_flag */ ,
NULL /* escalated_to_whom */ ,
NULL /* date_escalated */ ,
NULL /* tracking_id */ ,
'T' /* view_on_web */ ,
NULL /* site_need_CI_category_id */ ,
NULL /* site_need_date_raised */ ,
NULL /* site_need_target_completion_date */ ,
NULL /* site_need_actual_completion_date */ ,
NULL /* site_visit_date */ ,
NULL /* site_visit_target_completion_date */ ,
NULL /* site_visit_actual_completion_date */ ,
NULL /* site_visit_neXT_Use_travel_date */ ,
NULL /* site_visit_client_contact */ ,
NULL /* site_visit_site_contact */ ,
NULL /* scar_start_date */ ,
NULL /* scar_target_completion_date */ ,
NULL /* scar_actual_completion_date */ ,
NULL /* scar_vendor_name */ ,
NULL /* nonconformance_start_date */ ,
NULL /* nonconformance_end_date */ ,
NULL /* nonconformance_root_cause */ ,
NULL /* lesson_learned_start_date */ ,
@start_date /* incident_start_date */ ,
@end_date /* incident_end_date */ ,
NULL /* incident_resolution_date */ ,
NULL /* incident_resolution */ ,
5 /* incident_type_id */ ,
@financial_impact /* incident_estimated_financial_impact */ ,
'I' /* incident_source */ ,
NULL /* improvement_type */ ,
NULL /* improvement_acceptance_status */ ,
NULL /* improvement_date_raised */ ,
NULL /* improvement_target_completion_date */ ,
NULL /* improvement_date_implemented */ ,
NULL /* improvemeNT_ci_category_id */ ,
NULL /* improvement_estimated_annual_financial_impac */ ,
NULL /* improvement_percentage */ ,
NULL /* improvement_reason_for_denial */ ,
NULL /* improvement_estimated_waste_volume_impacted */ ,
NULL /* improvement_estimated_waste_volume_unit */ ,
@app /* added_by */ ,
getdate() /* date_added */ ,
@app /* modified_by */ ,
getdate() /* date_modified */ 
)

if @@rowcount > 0 begin

	declare @generator_name	varchar(40)
		, @generator_city	varchar(40)
		, @generator_state	varchar(2)
		, @i_subject		varchar(255)
		, @i_message		varchar(max)
		, @i_html			varchar(max)
		, @i_created_by		varchar(10)
		, @i_message_source	VARCHAR(30) = 'USEcology.com'
		, @cr varchar(2)	= CHAR(10) + CHAR(13)
		, @this_recipient_email varchar(100) = ''
		, @this_recipient_name	varchar(100) = ''
		

	select @generator_name = generator_name
		, @generator_city = generator_city
		, @generator_state = generator_state
	from Generator
	WHERE generator_id = @generator_id

select @i_html = 'New GE Action Register Feedback has been received.<br/><br/>
Date: ' + convert(varchar(20), getdate(), 121) + '<br/><br/>
Name: ' + @contact_name + '<br/><br/>
Generator: ' + isnull(@generator_name, '') + ' - ' + isnull(@generator_city + ', ' + @generator_state, '') + ' (' + convert(varchar(20), @generator_id) + ')<br/><br/>
Notes:<br/>--------------------<br/>' + @notes + '<br/><br/>--------------------<br/>
Start Date: ' + convert(varchar(10), @start_date, 101) + '<br/>
End Date: ' + convert(varchar(10), @end_date, 101) + '<br/><br/>
Financial Impact: ' + convert(varchar(20), @financial_impact) + '<br/><br/>'

select @i_message = replace(@i_html, '<br/>', @cr)	
	
	select @i_subject = 'GE Feedback: ' + isnull(@generator_name, '') + ' - ' + isnull(@generator_city + ', ' + @generator_state, '')
		, @i_created_by		= @app
		, @i_message_source	= @app
	

			declare @out_message_id int

			exec @out_message_id = sp_message_insert
				 @subject			= @i_subject
				,@message			= @i_message
				,@html				= @i_html
				,@created_by		= @i_created_by
				,@message_source	= @i_message_source
				,@date_to_send		= NULL
				,@message_type_id	= NULL
				
			exec sp_messageAddress_insert
				 @message_id	= @out_message_id
				,@address_type	= 'TO'
				,@email			= 'GE@USEcology.com'
				,@name			= 'GE@USEcology.com'
				,@company		= 'USEcology'
				,@department	= NULL
				,@fax			= NULL
				,@phone			= NULL

			exec sp_messageAddress_insert
				 @message_id	= @out_message_id
				,@address_type	= 'FROM'
				,@email			= 'IT.Services@usecology.com'
				,@name			= 'IT Services Mailbox'
				,@company		= 'EQ'
				,@department	= NULL
				,@fax			= NULL
				,@phone			= NULL

end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_action_register_feedback] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_action_register_feedback] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_action_register_feedback] TO [EQAI]
    AS [dbo];

