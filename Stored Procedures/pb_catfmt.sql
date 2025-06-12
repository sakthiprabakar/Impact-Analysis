/****** Object:  Stored Procedure dbo.pb_catfmt    Script Date: 9/24/2000 4:20:32 PM ******/
create procedure dbo.pb_catfmt as 
select pbf_name, pbf_frmt, pbf_type, pbf_cntr 
from dbo.pbcatfmt
