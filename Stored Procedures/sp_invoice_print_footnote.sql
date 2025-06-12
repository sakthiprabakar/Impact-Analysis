CREATE PROCEDURE sp_invoice_print_footnote (
	@invoice_id	int,
	@revision_id	int )
AS
/***************************************************************
Loads to:	Plt_AI

05/08/2007 RG	Created
10/12/2007 WAC	Added an INT field to the result set that will indicate the count of companies
		that was retrieved and returned in the list.
05/28/2010 JDB	Changed to use newly added field Company.dba_name instead of company_name.
06/18/2015 RB   set transaction isolation level read uncommitted
06/06/2018 AM   Added currency code to result set.

sp_invoice_print_footnote 1351025,1 
sp_invoice_print_footnote 1351027,1
****************************************************************/

set transaction isolation level read uncommitted

CREATE TABLE #companies (
	company_id	int		NULL,
	co_name		varchar(50)	NULL ,	
    currency_code varchar(3) NULL )
    
DECLARE @companies	varchar(4000),
        @co_name	varchar(50),
        @cnt		int,
        @last		int,
	    @company_cnt	int,
		@currency_code varchar(3)
		
INSERT #companies
SELECT DISTINCT InvoiceDetail.company_id,
	Company.dba_name,
	InvoiceHeader.currency_code 
FROM InvoiceDetail
INNER JOIN Company ON InvoiceDetail.company_id = Company.company_id
AND InvoiceDetail.invoice_id = @invoice_id
AND InvoiceDetail.revision_id = @revision_id
INNER JOIN InvoiceHeader ON InvoiceDetail.invoice_id = InvoiceHeader.invoice_id
AND InvoiceDetail.revision_id = InvoiceHeader.revision_id

SELECT @company_cnt = COUNT(*) FROM #companies

-- declare cursor 
DECLARE grp CURSOR FOR SELECT co_name, currency_code FROM #companies
OPEN grp

FETCH grp INTO @co_name ,@currency_code
SELECT @cnt = 0

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @cnt = @cnt + 1
	IF @cnt = 1 
	BEGIN 
		SELECT @companies = @co_name
		
	END
	ELSE
	BEGIN
		SELECT @companies = @companies + '; ' + @co_name
	END 
	FETCH grp INTO @co_name, @currency_code
END

CLOSE grp
DEALLOCATE grp

IF @cnt > 1 
BEGIN 
-- 	SELECT @companies = LEFT(@companies,(len(@companies) - 1))
        SELECT @companies = REVERSE(@companies)
        SELECT @last =  CHARINDEX(';',@companies,1)
        SELECT @companies = STUFF(@companies,@last,1,REVERSE(' and'))
        SELECT @companies = REVERSE(@companies)
END
     
SELECT @companies AS company_list,
@company_cnt AS company_cnt,
@currency_code AS currency_code

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_footnote] TO [EQAI]
    AS [dbo];

