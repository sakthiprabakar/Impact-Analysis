
Create Proc sp_RoadnetDriver
as
/* ****************************************************************
sp_RoadnetDriver

Renders data from RoadnetDriver as flatfile
**************************************************************** */

select
	left(isnull([Driver ID], '') + space(15), 15)
	+ left(isnull(convert(varchar(15), [Non-Help Regular Rate]), '') + space(15), 15)
	+ left(isnull(convert(varchar(11), [Non-Help Overtime Rate]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Non-Help Minimum Time]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Non-Help Overtime Begin]), '') + space(11), 11)
from RoadnetDriver


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetDriver] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetDriver] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetDriver] TO [EQAI]
    AS [dbo];

