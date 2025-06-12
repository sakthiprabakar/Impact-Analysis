/****** Object:  Stored Procedure dbo.pb_catcol    Script Date: 9/24/2000 4:20:32 PM ******/
create procedure dbo.pb_catcol @tblobjid int, @colobjid smallint as 
select pbc_labl, pbc_lpos, pbc_hdr, pbc_hpos,  		 pbc_jtfy, pbc_mask, pbc_case, pbc_hght, pbc_wdth, 
pbc_ptrn, pbc_bmap, pbc_cmnt, pbc_init, pbc_edit 
from dbo.pbcatcol where pbc_tid = @tblobjid and 
pbc_cid = @colobjid 
