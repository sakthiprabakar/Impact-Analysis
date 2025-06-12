
Create Proc sp_RoadnetEquipmentType
as
/* ****************************************************************
sp_RoadnetEquipmentType

Renders data from RoadnetEquipmentType as flatfile

sp_columns RoadnetEquipmentType

**************************************************************** */

select
	left(isnull([Equipment Type ID], '') + space(15), 15)
	+ left(isnull(convert(varchar(255), [Description]), '') + space(255), 255)
	+ left(isnull(convert(varchar(11), [Height]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Weight]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Fixed Cost]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Variable Cost]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Total of Size 1]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Total of Size 2]), '') + space(11), 11)
	+ left(isnull(convert(varchar(11), [Total of Size 3]), '') + space(11), 11)
from RoadnetEquipmentType


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEquipmentType] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEquipmentType] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RoadnetEquipmentType] TO [EQAI]
    AS [dbo];

