
CREATE PROCEDURE sp_reports_invoices
	@debug				int, 		-- 0 or 1 for no debug/debug mode
	@database_list		varchar(max),	-- Comma Separated Company List
	@customer_id_list	varchar(max),	-- Customer ID List
	@invoice_code		varchar(max),	-- Invoice ID
	@manifest			varchar(max),	-- Manifest list
	@purchase_order		varchar(max),	-- Purchase Order list
	@start_date			varchar(20),	-- Start Date of range
	@end_date			varchar(20),	-- End Date of range
	@contact_id			varchar(100)	-- Contact_id
AS
/* ***************************************************************************************************
sp_reports_invoices:

Returns the data for Invoices.

LOAD TO PLT_AI* on NTSQL1


exec sp_reports_invoices 6, '', '', '1234444444444 , 4444444445', '', '', '', '', ''
exec sp_reports_invoices 100, '', '', '', 'asdfasdfasdfasdfasdfasdfasdf', '', '', '', ''

sp_reports_invoices 0, ' 2|21, 3|1, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '16006', '', '', '', '1/1/05', '1/31/15', ''
sp_reports_invoices 1, ', 2|21, 3|1, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0', '003340', '20105246,120048630', '', '', '1/1/2005', '3/31/2005', ''
sp_reports_invoices 1, '2|21, 14|0, 23|0', '3340', '', '', '', '1/1/2005', '1/31/2005', '1624'
sp_reports_invoices 0, '21|0', '', '210019155', '', '', '', '', ''
sp_reports_invoices 0, '', '6029', '', '', '', '', '', ''
sp_reports_invoices 0, '', '', '', 'MI9299774, MI8974128, MI9299773', '', '', '', ''
sp_reports_invoices 0, '', '', '', '', 'RAU2006, 167641, 180657', '', '', ''
sp_reports_invoices 1, '', '', '', '', '', '', '', ''



05/24/2005 JPB Created
01/09/2006 JDB	Modified to use plt_rpt database
02/22/2006 JPB  Modified to include all view-on-web+active profitcenters for each
   company chosen (was skipping profitcenters that appeared like companies)
2/22/2006 - JPB
	switched from:
		AND CONVERT(varchar(4), ih.company_id) + ''|'' + CONVERT(varchar(4), id.profit_ctr_id) IN (SELECT CONVERT(varchar(4), company_id) + ''|'' + CONVERT(varchar(4), profit_ctr_id) FROM #tmp_database)
	to:
		AND CONVERT(varchar(4), id.company_id) + ''|'' + CONVERT(varchar(4), id.profit_ctr_id) IN (SELECT distinct CONVERT(varchar(4), t.company_id) + ''|'' + CONVERT(varchar(4), px.profit_ctr_id) FROM #tmp_database t inner join ProfitCenter px on t.company_id 
= px.company_id and px.view_on_web <> ''F'' and px.status = ''A'') 
		
	Because the #tmp_database table won't contain all the profitcenters that should report under invoicing.
	EQ Invoices by company, which includes all profit centers, but #tmp_database will only include profitcenters whose
	view_on_web flag = 'C' - not the ones that normally appear as separate companies on the website, whose view_on_web
	flag = 'P'.

05/06/06    rg modifed for b2bxcontact
04/06/2007 JPB	Modified to conform to Central Invoicing changes (removed company/profit center select)
05/06/2006 rg	Modifed for b2bxcontact
08/16/2007 JPB	Modified to join between InvoiceHeader and InvoiceDetail using the link field, not profit_ctr_id and invoice_code
10/03/2007 JPB  Modified to remove NTSQL* references

Central Invoicing:
	JPB Modified to add manifest and purchase_order options for searching.
	JPB Removed 'mode' references (ntsql1/server code)

01/21/2008 JPB	Modified to include Invoice Total in results.
	Also modified to make sure Billing is checked.
	
03/28/2013	JPB	Converted text fields to vachar(max)
	Added handling for over-size values given for fields
	Added extra associate screening to avoid huge searches
09/03/2014	JPB	GEM-27244 - Invoices should only be visible once posted to JDE financial system.
				Invoices created pre-JDE should always be visible.	


*************************************************************************************************** */

DECLARE	@sql 	varchar(8000)

	IF datalength(@invoice_code) +
		datalength(@manifest) + 
		datalength(@purchase_order) +
		len(@start_date) +
		len(@end_date) +
		datalength(@customer_id_list) = 0 RETURN

SET NOCOUNT ON

-- Parse inputs into temp tables.
	CREATE TABLE #Customer_id_list (customer_id int)
	CREATE INDEX idx1 ON #Customer_id_list (customer_id)
	Insert #Customer_id_list select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @customer_id_list) where isnull(row, '') <> ''

	CREATE TABLE #invoice_code_list (invoice_code varchar(16))
	CREATE INDEX idx2 ON #invoice_code_list (invoice_code)
	Insert #invoice_code_list select row from dbo.fn_SplitXsvText(',', 0, @invoice_code) where isnull(row, '') <> '' and len(isnull(row, '')) <= 16

	CREATE TABLE #Manifest_list (manifest varchar(15))
	CREATE INDEX idx3 ON #Manifest_list (manifest)
	Insert #Manifest_list select row from dbo.fn_SplitXsvText(',', 1, @manifest) where isnull(row, '') <> '' and len(isnull(row, '')) <= 15

	CREATE TABLE #PurchaseOrder_list (po varchar(20))
	CREATE INDEX idx4 ON #PurchaseOrder_list (po)
	Insert #PurchaseOrder_list select row from dbo.fn_SplitXsvText(',', 1, @purchase_order) where isnull(row, '') <> '' and len(isnull(row, '')) <= 20

if @debug > 0 begin
	select '#Customer_id_list', * from #Customer_id_list
	select '#invoice_code_list', * from #invoice_code_list
	select '#Manifest_list', * from #Manifest_list
	select '##PurchaseOrder_list', * from #PurchaseOrder_list
end

-- Extra level of filtering for associates - you can't just run wild here.
IF len(isnull(@contact_id, '')) = 0 AND
	(select count(*) from #customer_id_list) +
	(select count(*) from #invoice_code_list) +
	(select count(*) from #Manifest_list) +
	(select count(*) from #PurchaseOrder_list)
	 = 0 RETURN

if @debug > 10 return

-- Build SQL to execute
	SET @sql = 'SELECT DISTINCT ih.invoice_code,
		ih.invoice_date,
		ih.customer_id,
		ih.cust_name,
		ih.invoice_id,
		ih.revision_id,
		ih.invoice_image_id,
		ih.attachment_image_id,
		ih.total_amt_due,
		ih.due_date
		FROM InvoiceHeader ih 
		INNER JOIN InvoiceDetail id on ih.invoice_id = id.invoice_id and ih.revision_id = id.revision_id 
		WHERE 1=1 '
-- Most specific criteria first:
	IF (select count(*) from #invoice_code_list) > 0
		SET @sql = @sql + ' AND ih.invoice_code IN (select invoice_code from #invoice_code_list) '

	IF (select count(*) from #Manifest_list) > 0
		SET @sql = @sql + ' AND id.manifest IN (select manifest from #manifest_list) '

	IF (select count(*) from #PurchaseOrder_list) > 0
		SET @sql = @sql + ' AND id.purchase_order IN (select po from #purchaseorder_list) '
		
	IF @start_date <> '' 
		SET @sql = @sql + ' AND ih.invoice_date >= ''' + @start_date + ''' '
	
	IF @end_date <> ''
		SET @sql = @sql + ' AND ih.invoice_date <= ''' + @end_date + ''' '
	
	IF (select count(*) from #Customer_id_list) > 0
		SET @sql = @sql + ' AND ih.customer_id IN (select customer_id from #Customer_id_list) '

	IF LEN(@contact_id) > 0
		SET @sql = @sql + ' AND ih.customer_id IN (SELECT DISTINCT customer_id FROM ContactXRef WHERE type = ''C'' and web_access = ''A'' and status = ''A'' AND contact_id = ' + @contact_id + ') '

-- Check Billing Record for old invoices...			
	SET @sql = @sql + ' AND ih.status = ''I'' 
		AND EXISTS (SELECT invoice_code FROM Billing WHERE
		id.company_id = Billing.company_id
		AND id.profit_ctr_id = Billing.profit_ctr_id
		AND id.receipt_id = Billing.receipt_id
		AND id.trans_source = Billing.trans_source
		AND id.line_id = Billing.line_id
		AND id.price_id = Billing.price_id
		AND Billing.invoice_code = ih.invoice_code
		)
	'

-- Check JDEChangeLog table for Completed status of posting...
	SET @sql = @sql + ' AND (
		EXISTS (SELECT 1 FROM JDEChangeLog WHERE
		id.invoice_id = JDEChangeLog.invoice_id
		AND id.revision_id = JDEChangeLog.revision_id
		AND JDEChangeLog.status = ''C''
		)
		OR NOT EXISTS (
		SELECT 1 FROM JDEChangeLog WHERE
		id.invoice_id = JDEChangeLog.invoice_id
		AND id.revision_id = JDEChangeLog.revision_id
		)
		)
	'

-- Order by...			
	SET @sql = @sql + 'ORDER BY ih.cust_name, ih.customer_id, ih.invoice_date, ih.invoice_code '

-- Print when in debug mode
	IF @debug >= 1
	BEGIN
		PRINT @sql
		PRINT ''
	END

-- Execute the SQL
	EXEC(@sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_invoices] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_invoices] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_invoices] TO [EQAI]
    AS [dbo];

