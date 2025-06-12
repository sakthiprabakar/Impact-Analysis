
/***************************************************************************************
Commits or Cancels changes in the Work Hierarchy Tree to the Published Hiearchy Tree

10/1/2003 JPB	Created
Test Cmd Line: spw_parent_mergetreechanges 'ok', 'Jonathan'
****************************************************************************************/
create procedure spw_parent_mergetreechanges
	@mode	varchar(10),
	@modified_by	varchar(10)
AS

	select w.customer_ID into #tmpRows from customertree t, 
		customertreework w
		where t.customer_id = w.customer_id and (t.rgt <> w.rgt 
		or t.lft <> w.lft or w.date_modified <> t.date_modified
		or w.modified_by <> t.modified_by)
		and w.modified_by = @modified_by
	
	if @mode = 'cancel'
	BEGIN
		delete from customertreework where customer_ID in (select customer_ID from #tmpRows)
		insert into customertreework select customer_ID, lft, rgt, date_modified, modified_by from customertree where customer_ID in (select customer_ID from #tmpRows)

	END
	if @mode = 'ok'
	BEGIN
		delete from customertree where customer_ID in (select customer_ID from #tmpRows)
		insert into customertree select customer_ID, lft, rgt, date_modified, modified_by, newid() from customertreework where customer_ID in (select customer_ID from #tmpRows)
	
		declare @thisID int
		declare @parent int
		declare cursor_tmprows cursor for select customer_id from #tmpRows
		open cursor_tmprows
		fetch next from cursor_tmprows into @thisID
		if @@fetch_status = 0
		begin
			exec @parent = sp_parent_get_parent_id @thisID
			update customer set cust_parent_id = @parent where customer_id = @thisID
		end
		close cursor_tmprows
		deallocate cursor_tmprows
	END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_mergetreechanges] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_mergetreechanges] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_mergetreechanges] TO [EQAI]
    AS [dbo];

