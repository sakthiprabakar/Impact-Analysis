
CREATE PROC sp_lib_waste_code_list
AS
/* ****************************************************************************
sp_lib_waste_code_list

Expects a table #lib_wastecode (waste_code_uid int)
Fills it with the known LIB (Liquid Industrial Byproduct) waste codes

This SP is a place-holder for a someday better way to do this, but for now
we're hard coding them here, which will fill a table used as source data
for reports generated in other related sps.

History:

03/31/2016 JPB	Created - GEM:36752

Sample:
	Create table #lib_wastecode (waste_code_uid int)
	exec sp_lib_waste_code_list
	select * from #lib_wastecode

**************************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

insert #lib_wastecode
SELECT waste_code_uid FROM wastecode (nolock)
where waste_code in (
	'007L',
	'014L',
	'017L',
	'019L',
	'021L',
	'022L',
	'026L',
	'029L',
	'030L',
	'031L',
	'032L',
	'033L',
	'034L',
	'035L',
	'036L'
) 
-- Not checking status here - check it elsewhere, as needed by that report/use
-- and status = 'A'

set nocount on


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_lib_waste_code_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_lib_waste_code_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_lib_waste_code_list] TO [EQAI]
    AS [dbo];

