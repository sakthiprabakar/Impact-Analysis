
/***************************************************************************************
Returns xml set of notes belonging to the input usercode

10/1/2003 JPB	Created
Test Cmd Line: spw_mynotes_overdueopen 'jonathan'
****************************************************************************************/
create procedure spw_mynotes_overdueopen
	@usercode varchar(10)
AS
	create table #tmpCounts(reminder_count int, actionitem_count int, salescall_count int, scheduledcall_count int)
	
	insert into #tmpCounts values (0,0,0,0)
	
	update #tmpCounts set reminder_count =
		(select count(*) from customernote
		where status = 'O' 
		and contact_date <= GETDATE()
		and (recipient like '%' + @usercode + '%'
		or cc_list like '%' + @usercode + '%')
		and note_type = 'reminder')
	
	update #tmpCounts set actionitem_count =
		(select count(*) from customernote
		where status = 'O' 
		and contact_date <= GETDATE()
		and (recipient like '%' + @usercode + '%'
		or cc_list like '%' + @usercode + '%')
		and note_type = 'actionitem')
	
	update #tmpCounts set salescall_count =
		(select count(*) from customernote
		where status = 'O' 
		and contact_date <= GETDATE()
		and (recipient like '%' + @usercode + '%'
		or cc_list like '%' + @usercode + '%')
		and note_type = 'salescall')
	
	update #tmpCounts set scheduledcall_count =
		(select count(*) from customernote
		where status = 'O' 
		and contact_date <= GETDATE()
		and (recipient like '%' + @usercode + '%'
		or cc_list like '%' + @usercode + '%')
		and note_type = 'scheduledcall')
	
	select reminder_count, actionitem_count, salescall_count, scheduledcall_count from #tmpCounts counts for xml auto


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_mynotes_overdueopen] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_mynotes_overdueopen] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_mynotes_overdueopen] TO [EQAI]
    AS [dbo];

