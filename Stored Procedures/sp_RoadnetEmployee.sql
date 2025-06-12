
Create Proc sp_RoadnetEmployee
as
/* ****************************************************************
sp_RoadnetEmployee

Renders data from RoadnetEmployee as flatfile

sp_columns RoadnetEmployee

**************************************************************** */

select
	left(isnull([Employee ID], '') + space(15), 15)
	+ left(isnull(convert(varchar(3), [Employee Type]), '') + space(3), 3)
	+ left(isnull(convert(varchar(35), [First Name]), '') + space(35), 35)
	+ left(isnull(convert(varchar(35), [Middle Name]), '') + space(35), 35)
	+ left(isnull(convert(varchar(35), [Last Name]), '') + space(35), 35)
from RoadnetEmployee


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEmployee] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEmployee] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEmployee] TO [EQAI]
    AS [dbo];

