
/***************************************************************************************
Moves a hierarchy sub-tree to a new parent

10/1/2003 JPB	Created
Test Cmd Line: spw_parent_movesubtree 25, 10, 'Jonathan'
****************************************************************************************/
create procedure spw_parent_movesubtree 
	@my_root int, 
	@new_parent int,
	@modified_by varchar(10)
AS
	DECLARE
	 @origin_lft INT,
	 @origin_rgt INT,
	 @new_parent_rgt INT
	
	SELECT @new_parent_rgt = rgt
	FROM CustomerTreeWork
	WHERE customer_id = @new_parent;
	
	SELECT @origin_lft = lft, @origin_rgt = rgt
	FROM CustomerTreeWork
	WHERE customer_id = @my_root;
	
	IF @new_parent_rgt < @origin_lft BEGIN
	
	 UPDATE CustomerTreeWork SET
	 lft = lft + CASE
	 WHEN lft BETWEEN @origin_lft AND @origin_rgt THEN
	 @new_parent_rgt - @origin_lft
	 WHEN lft BETWEEN @new_parent_rgt AND @origin_lft - 1 THEN
	 @origin_rgt - @origin_lft + 1
	ELSE 0 END,
	 rgt = rgt + CASE
	 WHEN rgt BETWEEN @origin_lft AND @origin_rgt THEN
	 @new_parent_rgt - @origin_lft
	 WHEN rgt BETWEEN @new_parent_rgt AND @origin_lft - 1 THEN
	 @origin_rgt - @origin_lft + 1
	ELSE 0 END,
	 modified_by = @modified_by,
	 date_modified = GETDATE()
	 WHERE lft BETWEEN @new_parent_rgt AND @origin_rgt
	 OR rgt BETWEEN @new_parent_rgt AND @origin_rgt;
	
	END
	ELSE IF @new_parent_rgt > @origin_rgt BEGIN
	
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
	
	END
	ELSE BEGIN
	 PRINT 'Cannot move a subtree to itself, infinite recursion';
	 RETURN;
	END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_movesubtree] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_movesubtree] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_movesubtree] TO [EQAI]
    AS [dbo];

