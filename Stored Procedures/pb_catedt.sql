/****** Object:  Stored Procedure dbo.pb_catedt    Script Date: 9/24/2000 4:20:32 PM ******/
create procedure dbo.pb_catedt as 
select pbe_name, pbe_edit, pbe_type, pbe_cntr, pbe_work, pbe_seqn, pbe_flag 
from dbo.pbcatedt order by pbe_name, pbe_seqn
