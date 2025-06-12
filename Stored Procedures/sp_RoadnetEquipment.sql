
Create Proc sp_RoadnetEquipment
as
/* ****************************************************************
sp_RoadnetEquipment

Renders data from RoadnetEquipment as flatfile

sp_columns RoadnetEquipment

**************************************************************** */

select
	left(isnull([Equipment ID], '') + space(20), 20)
	+ left(isnull(convert(varchar(10), [Equipment Type]), '') + space(10), 10)
	+ left(isnull(convert(varchar(255), [Equipment Description]), '') + space(255), 255)
from RoadnetEquipment


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEquipment] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEquipment] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEquipment] TO [EQAI]
    AS [dbo];

