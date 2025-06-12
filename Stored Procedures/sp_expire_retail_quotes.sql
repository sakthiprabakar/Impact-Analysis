
CREATE  PROCEDURE sp_expire_retail_quotes 
	
AS
/***************************************************************
Loads to:	Plt_AI

04/01/2008 KAM	Created

sp_expire_retail_quotes
****************************************************************/

Update ProductQuote set status = 'E' where end_date < GetDate()


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_expire_retail_quotes] TO [EQAI]
    AS [dbo];

