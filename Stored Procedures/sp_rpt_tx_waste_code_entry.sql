IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_rpt_tx_waste_code_entry')
   DROP PROCEDURE dbo.sp_rpt_tx_waste_code_entry
GO

CREATE  PROCEDURE [dbo].sp_rpt_tx_waste_code_entry
	@date_from			datetime
,	@date_to			datetime
,   @only_added_from_cor char(1)
AS
/**************************************************************************************
This procedure runs for Texas Waste Code Entry Report
PB Object(s):	r_tx_waste_code_entry

Change History:
---------- ---  ----------------------------------------------------------------------
11/19/2019 jcb 	devops #12569/12610  Created
11/25/2019 jcb	devops #12569/12610 repl waste_code with display_name
11/25/2019 jcb  devops #12569/12610 add * or T to limit result for only-added-from-cor 
12/03/2019 jcb  devops #12569/12610 limit to wastecode.state = 'TX'
02/12/2020 jcb  devops #13235 change modified_by from modified_by to internal_note
 
sp_rpt_tx_waste_code_entry  '1991-06-16 00:00:00.000', '2019-11-15 23:59:59.999'  
**************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

select  waste_code_uid,
		state,
		display_name,
		waste_code_desc,
		steers_reportable_flag,
		haz_flag,
		pcb_flag,
		date_added,
		added_by,
		date_modified,
		internal_note as modified_by  
 from wastecode 
where (@only_added_from_cor = '*'
   or  added_from_cor_flag	= @only_added_from_cor)  -- this will be * or T
  and status = 'A'
  and state  = 'TX'									 -- 20191203 jcb 
  and date_added between @date_from AND @date_to 
GO

GRANT EXECUTE ON dbo.sp_rpt_tx_waste_code_entry TO EQAI;
GRANT EXECUTE ON dbo.sp_rpt_tx_waste_code_entry TO COR_USER;
GRANT EXECUTE ON dbo.sp_rpt_tx_waste_code_entry TO EQWEB;
GO

