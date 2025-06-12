/****** Object:  Stored Procedure dbo.pb_catvld    Script Date: 9/24/2000 4:20:32 PM ******/
create procedure dbo.pb_catvld as 
select pbv_name, pbv_vald, pbv_type, pbv_cntr, pbv_msg 
from dbo.pbcatvld
