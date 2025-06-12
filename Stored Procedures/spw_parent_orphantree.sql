
/***************************************************************************************
Moves a subtree to the trunk level (so it has no parent)

10/1/2003 JPB	Created
Test Cmd Line: spw_parent_orphantree 25, 'Jonathan'
****************************************************************************************/
create procedure spw_parent_orphantree
	@my_root int, 
	@modified_by varchar(10)
AS
	DECLARE
	 @origin_lft INT,
	 @origin_rgt INT,
	 @new_parent_rgt INT
	
	SELECT @new_parent_rgt = max(rgt) + 1
	FROM CustomerTreeWork;
	
	SELECT @origin_lft = lft, @origin_rgt = rgt
	FROM CustomerTreeWork
	WHERE customer_id = @my_root;

	UPDATE CustomerTreeWork SET
	lft = lft + CASE
	 WHEN lft BETWEEN @origin_lft AND @origin_rgt THEN
	 @new_parent_rgt - @origin_rgt - 1
	 WHEN lft BETWEEN @origin_rgt + 1 AND @new_parent_rgt - 1 THEN
	 @origin_lft - @origin_rgt - 1
	 ELSE 0 END,
	rgt = rgt + CASE
	 WHEN rgt BETWEEN @origin_lft AND @origin_rgt THEN
	 @new_parent_rgt - @origin_rgt - 1
	 WHEN rgt BETWEEN @origin_rgt + 1 AND @new_parent_rgt - 1 THEN
	 @origin_lft - @origin_rgt - 1
	 ELSE 0 END,
	modified_by = @modified_by,
	date_modified = GETDATE()
	WHERE lft BETWEEN @origin_lft AND @new_parent_rgt
	 OR rgt BETWEEN @origin_lft AND @new_parent_rgt;


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_orphantree] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_orphantree] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_orphantree] TO [EQAI]
    AS [dbo];

