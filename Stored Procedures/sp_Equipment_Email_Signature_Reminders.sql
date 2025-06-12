
create proc sp_Equipment_Email_Signature_Reminders
as
/* *******************************************************************
sp_Equipment_Email_Signature_Reminders

	Set auto-reminder email for daily harrassment after 3 days.

History:
	2014-05-09	JPB	Created

sp_Equipment_Email_Signature_Reminders

-- scratch...
	drop table #work
	SELECT * FROM EquipmentSetXMessage where equipment_set_id = 1027
	update EquipmentSetXMessage  set date_added = date_added -2 where equipment_set_id = 1027
	
******************************************************************* */

	declare @this_set_id int
	
	select exm.equipment_set_id, u.user_name, u.user_code, min(exm.date_added) as date_first_emailed
	, case when max(exm.date_added) = min(exm.date_added) then null else max(exm.date_added) end as date_last_emailed
	, datediff(d, case when max(exm.date_added) = min(exm.date_added) then min(exm.date_added) else max(exm.date_added) end, GETDATE()) as days_since_last_email
	, 0 as process_flag
	into #Work
	from EquipmentSetXMessage exm
	join EquipmentSet e on exm.equipment_set_id = e.equipment_set_id and e.status <> 'V'
	join users u on e.user_code = u.user_code
	where exm.message_type = 'Signature Required'
	and not exists (
		select 1 from EquipmentSetXMessage exm2
		join EquipmentSet e2 on exm2.equipment_set_id = e2.equipment_set_id and e2.status <> 'V'
		join users u2 on e2.user_code = u2.user_code
		where u2.user_code = u.user_code
		and exm2.message_type = 'Signature Received'
		and exm2.date_added > exm.date_added
		and exm2.equipment_set_id = exm.equipment_set_id
	)
	group by exm.equipment_set_id, u.user_name, u.user_code
	having
	datediff(d, min(exm.date_added), GETDATE()) > 3
	and datediff(d, case when max(exm.date_added) = min(exm.date_added) then min(exm.date_added) else max(exm.date_added) end, GETDATE()) > 1
	order by u.user_name
	
	while exists (select 1 from #Work where process_flag = 0) begin
		select top 1 @this_set_id = equipment_set_id
		from #Work
		where process_flag = 0

		exec sp_Equipment_Email_Signature_Required @equipment_set_id = @this_set_id, @resend_flag = 1
		
		update #Work set process_flag = 1 where equipment_set_id = @this_set_id
	
	end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Reminders] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Reminders] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Reminders] TO [EQAI]
    AS [dbo];

