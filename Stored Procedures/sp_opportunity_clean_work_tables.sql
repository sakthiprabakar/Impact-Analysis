
CREATE PROCEDURE sp_opportunity_clean_work_tables
/*
	This procedure cleans out the temporary "paging" data for various
	search/work tables in Opportunity.  It will remove anything two days and greater ago
*/
as
begin
	declare @midnight_today datetime = cast(convert(varchar(20), getdate(), 101) as datetime)
	declare @midnight_yesterday datetime = dateadd(DAY,-1,@midnight_today)
	
	--select @midnight_today,@midnight_yesterday
	
	-- note search
   if exists (select 1 from work_OppNoteSearch with (nolock) where ins_date < @midnight_yesterday)
	DELETE FROM work_OppNoteSearch WHERE ins_date < @midnight_yesterday
	
	-- opp search
   if exists (select 1 from work_OppSearch with (nolock) where ins_date < @midnight_yesterday)
	DELETE FROM work_OppSearch WHERE ins_date < @midnight_yesterday	
	
	-- contact search
   if exists (select 1 from work_ContactSearch with (nolock) where ins_date < @midnight_yesterday)
	DELETE FROM work_ContactSearch WHERE ins_date < @midnight_yesterday		
	
	-- customer search
   if exists (select 1 from work_CustomerSearch with (nolock) where ins_date < @midnight_yesterday)
	DELETE FROM work_CustomerSearch WHERE ins_date < @midnight_yesterday		

   if exists (select 1 from [$(DB_PLT_AI_Audit)].dbo.work_AuditSearch with (nolock) where MODIFIED_DATE < @midnight_yesterday)
	DELETE FROM [$(DB_PLT_AI_Audit)].dbo.work_AuditSearch WHERE MODIFIED_DATE < @midnight_yesterday	

	select * from company

end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_clean_work_tables] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_clean_work_tables] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_clean_work_tables] TO [EQAI]
    AS [dbo];

