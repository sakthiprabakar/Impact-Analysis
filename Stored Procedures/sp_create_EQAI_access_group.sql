CREATE PROCEDURE sp_create_EQAI_access_group 
	@group_desc				varchar(40),
	@group_id_to_copy		int
AS
/**********************************************************************
Loads to:	Plt_AI

This SP creates a new Groups record on Plt_AI, and copies the
access from an existing group to the new Group record just created.

NOTE:  This SP runs only on one server at a time.  You may need to
run this on Test (or Dev) if the user will need to log in to test.

01/04/2011 JDB	Created

select max(group_id) from groups 
select * from groups order by group_id DESC
select * from groups order by group_desc
select * from users where group_id = 1032
select * from users where user_code = 'bill_mo'
select * from users where user_code = 'john_dan'
select * from groups WHERE group_id IN (1021)
select * from Access WHERE group_id IN (2088, 2143)
select * from groups WHERE group_desc LIKE '%stephenm%'

select * from users where user_code IN ('stephenm')
select * from users where group_id IN (1021)
select generator, * from Access where group_id IN (2153)
UPDATE Access SET generator = 'A' where group_id IN (2153)

sp_create_EQAI_access_group 'ANTHONYG Group', 2006
sp_create_EQAI_access_group 'Lab - EQ Augusta', 1073
sp_create_EQAI_access_group 'CYNDI_R Group', 1021				--3/23/11 JDB
sp_create_EQAI_access_group 'STEPHENM Group', 2125				--3/24/11 JDB

sp_create_EQAI_access_group 'EQIS Receiving INDY + Generator', 2016
go
**********************************************************************/
DECLARE	@new_group_id	int

-- Get next group ID
SELECT @new_group_id = MAX(group_id) + 1 FROM Groups
	
-- Insert new group_id and name
INSERT INTO groups VALUES ( @new_group_id, @group_desc )

PRINT 'New Group:'
SELECT * FROM groups WHERE group_id = @new_group_id

-- Insert existing Access records into a temp table
SELECT *
INTO #tmp_access
FROM Access
WHERE group_id = @group_id_to_copy

-- Update the group_id to be the new one
UPDATE #tmp_access SET group_id = @new_group_id
WHERE group_id = @group_id_to_copy

-- Final insert back into the Access table
INSERT INTO Access
SELECT * FROM #tmp_access WHERE group_id = @new_group_id


DROP TABLE #tmp_access

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_create_EQAI_access_group] TO [EQAI]
    AS [dbo];

