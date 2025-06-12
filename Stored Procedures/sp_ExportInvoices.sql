USE [PLT_AI]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_ExportInvoices] @as_userid VARCHAR(30)  
 ,@as_dbtype VARCHAR(4)  
 ,@adt_today DATETIME  
 ,@ai_debug INT = 0  
 ,@as_invoicecode_from VARCHAR(16) OUTPUT  
 ,@as_invoicecode_to VARCHAR(16) OUTPUT  
AS  
/*******************************************************************************************  
This SP is called from w_invoice_processing.  It is called to export invoices to the    
financial system.  Since the user can export multiple invoices that do not necessarily  
fit into a neat range of values, a temp table #InvoiceRecordsToExport will be created to pass  
applicable invoice_id and revision_id to this procedure.    
  
This sp is loaded to Plt_AI.  
  
04/23/2007 WAC Created  
08/07/2007 WAC Modified invoice number scheme to be: 1iiiiiiirrccpp (14 digits)   
   Where:  iiiiiii = zero filled invoice number (ewnumber.num_type=2001)  
    rr = zero filled invoice revision   
    cc = zero filled company id  
    pp = zero filled profit ctr id  
08/15/2007 WAC  total_amt_due is now set to 0 for company level invoices.  total_amt_paid was  
  alreay being set to the invoice amount as all company level invoices are posted  
  as paid in full.  
08/30/2007 WAC Modified to no longer post the same invoice to two companies - management and  
  company that generated the invoice.  In addition, the company invoices are no   
  longer posted as paid in full.  
09/12/2007 WAC InvoiceRunRequest records are created with a request_status of 'X' instead of 'Q'.  
  When an invoice amount ends up being negative trans_type will be changed from   
  2031 to 2032 and the signs of the invoice and detail amounts will be changed to  
  make the invoice a credit memo since Epicor doesn't like negative invoices.  
10/03/2007 WAC Changed EQAI table prefix to EQ.  Added db_type to EQDatabase lookup.  
10/08/2007 WAC Update temp table #InvoiceRecordsToExport with invoice_code for calling script  
  to use.  Incorporated NTSQLFINANCE when appropriate for Epicor table references.  
  Converted many SQL exec strings to SQL statements in the process.  
12/06/2007 WAC Rev 2+ invoices will be sent to Epicor with the max adjustment date as the invoice  
  date.  This will give the user the ability to specify the applied date of the   
  adjusted invoice instead of using the original date of the invoice.  
12/18/2007 WAC Applied_date has been added to the InvoiceHeader table and will now be passed to   
  Epicor as the applied date for the invoice, debit memo, and credit memo.  
01/07/2008 WAC GL transactions that were just exported to Epicor are now summarized by company,  
  gl_account and reference code and stuffed into temp table #InvoiceGLAcctsExported  
  that was created outside the scope of this procedure (at the same time that  
  #InvoiceRecordsToExport was created).  
  CREATE TABLE #InvoiceGLAcctsExported( company_id int, gl_account_code varchar(32) null,  
   reference_code varchar(32) null, amount float null )  
01/23/2012 JDB Update sp_ExportInvoices to populate #billsum01 with reserve account   
  02411-XX-XX-100 if date of adjusted transaction is in a prior year.  
01/31/2012 JDB Fixed bug in calculation of the reserve account GL account.  It should use  
  the company and profit center from the billingsummary record.  
02/02/2012 JDB Fixed bug that would always apply adjustments to revision 01 of the invoice.  
  It will now find the lowest revision in that company to apply to (from artrx, or arinpchg),  
  and if it can't find that, it will set apply_to_num = doc_ctrl_num for invoices, and  
  apply_to_num = '' for credits.  
03/16/2012 JDB Modified the way that we get the company_id and profit_ctr_id  
  from BillingSummary.  Since we recently started storing the receipt_id in this table,  
  we incorrectly kept using the distribution information to store in BillinSummary's  
  company_id and profit_ctr_id fields.  This table should store the receipt/WO's real  
  company_id and profit_ctr_id, but if the revenue is distributed to another facility,  
  that will just be evident by checking the gl_account_code.  
05/23/2012 JDB After getting several errors while posting revision 2+ invoices (not credits)  
  about the "master invoice could not be found", it is clear that the correct  
  thing to do is to blank out the apply_to_num field, for both credits and  
  debits, if there is no lower revision already in the company/profit center.  This  
  is a slight adjustment to the changes made on 2/2/12.  
11/07/2012 JDB Changed the way that the prior year reserve GL account is retrieved, to use  
  the Product table.  New system products with a product_code of 'RESERVEACCOUNT' were  
  added to store the reserve GL account for each profit center. (Gemini 21284)  
11/09/2012 JDB Changed the SP to use a transaction, and added error checking for each  
  insert and update.  This should prevent two users from getting the same invoice  
  number.  Gemini 22988.  
  Also added an ORDER BY clause to the insert into #invhdr so that invoices would  
  be numbered according to customer name, customer ID, and invoice ID.  
01/29/2013 JDB Added a new prior_year column to the #billsum01_byreceipt table so that we  
  can distinguish new records from old ones that have been invoiced in a prior year.  
  Then, when we use #billsum01_byreceipt to populate #billsum01, we can use the correct  
  company and profit center fields.  If it's from a prior year, we can't use the GL  
  Account's segments because the reserve account is used, and it is always profit center 0.  
  This, in turn, causes the join later on (where it sets the trx_ctrl_num from  
  #invhdr01) to fail because the company and profit center don't match.  In summary,  
  1. Use the GL account's company/profit center segment for regular invoices.  
  2. Use the BillingSummary's company/profit center for adjustments to prior year invoices.  
02/05/2013 JDB   
  1. Added updates to the #billsum01_byreceipt.company_id and #billsum01_byreceipt.profit_ctr_id because  
   without them, the company and profit center stays at whatever came from BillingSummary.  This presents   
   a problem for adjustments to prior-year invoices that are from a company that is different from the   
   transaction's company/profit center. If we do not update these two fields, the code later in this SP   
   that updates #billsum01.trx_ctrl_num by joining to #invhdr01 will fail because they won't match in this   
   specific case.  Then the trx_ctrl_num is left blank, and the adjustment won't export, or it just doesn't   
   create a detail record at all.  
  2. Changed the join from #billsum01_byreceipt to Product to use the segments of the GL account instead of the   
   BillingSummary company and profit center. The reason this needed to change was that for adjustments to   
   prior-year invoices that are from a company and/or profit center that is different from the transaction's   
   company/profit center (example:  a receipt in 02-00 that has a product that distributes revenue to 03-02),   
   the previous join (commented out below) would return the resereve GL account for company 02 instead of 03.  
03/06/2013 JDB Modified to export invoices and adjustments to JDE tables JDEInvoicePayItem and JDEInvoiceGL.  
04/18/2013 JDB Modified sort order for inserts into JDEInvoicePayItem and JDEInvoiceGL.  
04/23/2013 JDB Modified to send even $0-summed transactions to JDEInvoicePayItem and JDEInvoiceGL.  
05/01/2013 JDB Changed to populate receipt_matching_ref_1_VJRMR1 with empty string.  
05/03/2013 JDB Changed to populate reference_1_VNR1 with 'R##' for all invoices and adjustments.  
05/24/2013 RWB Changed to populate vender_invoice_number_VNVINV with either receipt line manifest #, or min manifest # for workorder.  
06/05/2013 JDB Added @adt_today parameter so that it could be used to populate BillingAudit records.  
    Modified to populate BillingAudit table if there are invalid JDE GL Accounts in any invoices. This will   
     also prevent the export from continuing.  
    Also changed the procedure to get the next invoice number from the Sequence table on Plt_AI,   
     instead of Epicor's ewnumber table.  
06/25/2013 RWB Fixed bug when left outer joining Billing table to populate JDEInvoiceGL (referenced idb.trans_source instead of b.trans_source)  
07/19/2013 JDB Commented out the line that calculates the sum of Billing.cash_received, because we are no longer exporting the cash received to Epicor.  
    Since JDE cannot accept any payments that are applied to the invoice (at the time of invoicing),  
    we are not going to export the payment information to Epicor either.  
09/30/2013 JDB Modified to use the next invoice number from the F0002 table on JDE databases.  Uses the JDE.EQFinance.dbo.JDENextNumber_F0002 view.  
11/12/2013 JDB Changed to populate the JDE Business Unit field (JDEInvoicePayItem.JDE_BU_VJMCU) with the business unit from the  
     UDC 55/BU table.  
    Also added validation, so that if the JDE Business Unit doesn't exist in the UDC 55/BU table, the invoice/adjustment export  
     will halt with an error.  
12/19/2013 RWB Fixed bug with transaction management...any error that occurred after commit or rollback of ExportJDE transaction  
     left records inserted into JDEInvoiceGL and JDEInvoicePayItem tables. Moved commit and rollback for that to END_OF_PROC.  
01/09/2014 JDB Moved the creation and population of the #InvoiceBillingDetail_AdjustmentData table up in the procedure so that we can check  
     it for invalid JDE GL account and business unit information.  Before, it was set up after the checks, and invalid GL accounts  
     were getting added to the JDEInvoiceGL table for adjustments that removed a transaction that contained invalid GL accounts.  
01/16/2014 JDB Commented out Epicor export code, and changed the updates to EQAI data at the end of the procedure to use the temp tables from  
     JDE instead of Epicor.  
02/24/2014 RWB Validation of JDE GL Accounts was joining on JDE.EQFinance.dbo.JDEGLAccountMaster_F0901 and JDE.EQFinance.dbo.JDEUserDefinedCodeValues_F0005  
    with a COLLATE, which took exponentially more time. Populated data into temps tables at the beginning of procedure and modified validation  
    to check against those instead.  
03/19/2014 JDB Update to GL account validation:  It was reported that for new invoices created as a result of  
    an adjusted transaction that was removed from an invoice originally created in a previous year,   
    then added onto its own invoice in the current year, the JDE GL account was not using the   
    reserve account.  The new #MinInvoiceDate temp table and the joins below were added to make sure  
    of two things:  
     1. The correct balance sheet reserve account is used if the transaction was originally invoiced  
      in a prior year.  
     2. The validation here should not check against the real (non-balance sheet reserve account)  
      account, but instead use the balance sheet reserve account.  
01/15/2016 RWB Fixed bug that was generating a false error. When populating the minimum invoice date in the #MinInvoiceDate table, obsolete previews should be ignored.  
    Also corrected a bug, changed min_invoice_year column to an int instead of datetimes for correct comparison of DATEPART's return type.  
04/12/2016 RWB Prior change to determine minimum invoice date was not 100% correct. Modified to look for minimum date where status is 'I' or 'O'. A preview should  
    always post to the current year's GL  
07/27/2016 AM   Added code for AX GL account  
08/09/2016 RWB Named transactions were being committed when begin tran was not called, resulting in error. Removed multiple named transaction, replaced with single.  
    Also noticed that reads block, set transaction isolation level  
03/23/2017 AM   Removed #InvoiceBillingDetail_AdjustmentData temp table join from AX revision > 1.  
04/14/2017 AM   EQAI-43064 - Modified PURCHORDERFORMNUM field logic for AX.  
05/03/2017 RWB GEM:43421 - When a prior year invoice posts to reserve account, join to ProfitCenterAging instead of ProfitCenter  
07/14/2017 AM   GEM:44271  AX Invoice Export - Handle voided invoices-- if the current sttus is V then insert previous version values to line table   
07/17/2017 AM   GEM:44274  Invoice Processing - Preview Export tab error  
01/30/2018 MPM GEM 47949 - Modified to insert InvoiceHeader.currency_code into the AXInvoiceHeader and AXInvoiceLine tables.  
05/16/2018 RWB GEM:50673 - The final queries to populate AXInvoiceLine adjustment records were ignoring indexes, taking up to an hour for large invoice revisions  
06/06/2018 RWB GEM:51147 - Move population of temp table from JDE, but actually comment out references to JDE since JDE Test was deleted  
07/08/2019 JPB Cust_name: 40->75 / Generator_Name: 40->75  
10/2/2019   DevOps:12477 - AM Added d365 logic  
12/11/2019  DevOPs:12961 - Modified code not to call fnValidateFinancialDimension.  
10/13/2022 AGC DevOps 50101 - added allow_multiple_projects_one_invoice flag.  
03/18/2024 KS DevOps 77764 - This is a performance updated done by updating the indexing and to the procedure by cleaning up the formatting   
        and ordering of the JOIN s including updates to the CURSOR s to make them forward only and read only with the FAST_FORWARD setting.  
09/05/2024 KS Rally DE35381 - Commented out the existing code to fetch and update invoice_Code from sequence table.   
10/10/2024 KS Rally US126366 - Pulling ECOL_D365Integration.dbo.CustomerSync.d365_payment_term to update axinvoiceheader.payment.  
01/28/2025 SG Rally#US141630 - [CHANGE] - Invoice Revision Export - Do not include attachments  
  
-- Testing:  
SELECT * FROM FinanceSyncControl  
DROP TABLE #InvoiceGLAcctsExported  
CREATE TABLE #InvoiceGLAcctsExported ( company_id int, gl_account_code varchar(32) null, reference_code varchar(32) null, amount float null )  
DROP TABLE #InvoiceRecordsToExport  
CREATE TABLE #InvoiceRecordsToExport ( invoice_id int, revision_id int, invoice_code varchar(16) NULL )  
INSERT INTO #InvoiceRecordsToExport (invoice_id, revision_id ) VALUES ( 983316, 1 )  
DECLARE @as_invoicecode_from varchar(16),  
  @as_invoicecode_to varchar(16),  
  @adt_today datetime  
SET XACT_ABORT ON  
DELETE JDEInvoicePayItem WHERE invoice_id IN (983316) AND revision_id = 1  
DELETE JDEInvoiceGL WHERE invoice_id IN (983316) AND revision_id = 1  
DELETE Plt_Image..InvoiceRunRequest WHERE invoice_id IN (983316) AND revision_id = 1  
SET @adt_today = GETDATE()  
EXEC sp_ExportInvoices 'JASON_B', 'DEV', @adt_today, 1, @as_invoicecode_from, @as_invoicecode_to  
PRINT '@as_invoicecode_from = ' + @as_invoicecode_from  
PRINT '@as_invoicecode_to = ' + @as_invoicecode_to  
  
SELECT * FROM InvoiceHeader WHERE invoice_id IN ( 983316 )  
SELECT b.customer_id, b.invoice_id, b.invoice_code, SUM(bd.extended_amt) FROM Billing b JOIN BillingDetail bd ON bd.billing_uid = b.billing_uid  
 WHERE b.invoice_id IN (983316)  
 GROUP BY b.customer_id, b.invoice_id, b.invoice_code  
--SELECT * FROM InvoiceDetail WHERE invoice_id IN ( 983316 )  
SELECT * FROM InvoiceBillingDetail WHERE invoice_id IN ( 983316 )  
SELECT * FROM JDEInvoicePayItem WHERE invoice_id IN ( 983316 )  
SELECT * FROM JDEInvoiceGL WHERE invoice_id IN ( 983316 )  
  
EXEC sp_ExportInvoices 'anitha_m', 'DEV', '6/17/2016', 1, 1183181, 1183181  
  
DROP TABLE #InvoiceRecordsToExport  
CREATE TABLE #InvoiceRecordsToExport ( invoice_id int, revision_id int, invoice_code varchar(16) NULL )  
INSERT INTO #InvoiceRecordsToExport (invoice_id, revision_id ) VALUES (1220992,1)   
EXEC sp_ExportInvoices 'anitha_m', 'TEST', '01/15/2017', 1, 'Preview_1220992', 'Preview_1220992'  
select * from invoiceheader where invoice_code = 'Preview_1220992'  
EXEC sp_ExportInvoices 'anitha_m', 'DEV', '11/8/2016', 1, '238333', '238333'  
EXEC sp_ExportInvoices 'anitha_m', 'DEV', '9/10/2016', 1, 'Preview_1194649', 'Preview_1194649'  
  
DROP TABLE #InvoiceRecordsToExport  
CREATE TABLE #InvoiceRecordsToExport ( invoice_id int, revision_id int, invoice_code varchar(16) NULL )  
INSERT INTO #InvoiceRecordsToExport (invoice_id, revision_id ) VALUES (1220868,2)   
EXEC sp_ExportInvoices 'anitha_m', 'TEST', '01/16/2017', 1, '300236', '300236'  
  
select * from invoiceheader where invoice_id = 1194258  
********************************************************************************************/  
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  
  
DECLARE @sync_invoice_epicor TINYINT  
 ,@sync_invoice_jde TINYINT  
 ,@sync_invoice_ax TINYINT  
 ,@date_today DATETIME  
 ,@EDI_transaction_action CHAR(1)  
 ,@EDI_transaction_type CHAR(1)  
 ,@EDI_process_status CHAR(1)  
 ,@doc_type_inv CHAR(2)  
 ,@doc_type_adj CHAR(2)  
 ,@account_mode_gl CHAR(1)  
 ,@mode CHAR(1)  
 ,@currency_code VARCHAR(3)  
 ,@transaction_originator_inv VARCHAR(10)  
 ,@transaction_originator_adj VARCHAR(10)  
 ,@docctrlnum INT  
 ,@docctrlmask VARCHAR(25)  
 ,@jde_gl_account_separator CHAR(1)  
 ,@subledger_type CHAR(1)  
 ,@ledger_type VARCHAR(2)  
 ,@invoice_id_adj INT  
 ,@revision_id_adj INT  
 ,@count_adjustments INT  
 ,@invalid_gl_count INT  
 ,@invalid_JDE_BU_count INT  
 ,@error_value INT  
 ,@error_msg VARCHAR(8000)  
 ,@invoice_code INT  
 ,@invoice_count INT  
 ,@doc_type_ax CHAR(1)  
 ,@ax_invoice_id INT  
 ,@ax_header_uid INT  
 ,@servicecall VARCHAR(255)  
 ,@ax_web_service VARCHAR(max) --NOTE: [dbo].[Configuration] table [config_value] column is MAX  
 ,@invoice_status CHAR(1)  
 ,@d365_go_live_flag VARCHAR(15)  
 ,@count INT  
 ,@d365_invoice_id INT  
 ,@d365_revision_id INT  
 ,@invoice_multiple_projects VARCHAR(15)  
  
-- Initialize variables  
SELECT @date_today = @adt_today  
  
SET @EDI_transaction_action = 'A'  
SET @EDI_transaction_type = 'I'  
SET @EDI_process_status = '0'  
SET @doc_type_inv = 'RI' -- 'RI' for Invoice  
SET @doc_type_adj = 'RA' -- 'RA' for Adjustment  
SET @account_mode_gl = '2'  
SET @mode = 'D' -- 'D' for Domestic, 'F' for Foreign  
SET @currency_code = 'USD'  
SET @transaction_originator_inv = 'EQAI-IV'  
SET @transaction_originator_adj = 'EQAI-AD'  
SET @jde_gl_account_separator = '-' -- It's a hyphen for now, but could be a period if they change their minds  
SET @subledger_type = 'A'  
SET @ledger_type = 'AA'  
SET @invalid_gl_count = 0  
SET @invalid_JDE_BU_count = 0  
SET @error_value = 0  
SET @doc_type_ax = 'R'  
  
-- Create a table that will be used to select trx_ctrl data into  
DROP TABLE IF EXISTS #trx_data;  
CREATE TABLE #trx_data (  
 next_num INT NULL  
 ,mask CHAR(16) NULL  
 )  
  
DROP TABLE IF EXISTS #tmp_invoice_code;  
CREATE TABLE #tmp_invoice_code (  
 invoice_id INT  
 ,revision_id INT  
 ,invoice_code VARCHAR(16)  
 ,invoice_code_int INT  
 ,cust_name VARCHAR(75)  
 ,customer_id INT  
 )  
  
DROP TABLE IF EXISTS #InvoiceBillingDetail_AdjustmentData;  
CREATE TABLE #InvoiceBillingDetail_AdjustmentData (  
 orig_billing_uid INT  
 ,orig_billingdetail_uid INT  
 ,orig_ref_billingdetail_uid INT  
 ,invoice_id INT  
 ,revision_id INT  
 ,billingtype_uid INT  
 ,billing_type VARCHAR(10)  
 ,company_id INT  
 ,profit_ctr_id INT  
 ,receipt_id INT  
 ,line_id INT  
 ,price_id INT  
 ,trans_source CHAR(1)  
 ,trans_type CHAR(1)  
 ,product_id INT  
 ,dist_company_id INT  
 ,dist_profit_ctr_id INT  
 ,sales_tax_id INT  
 ,applied_percent DECIMAL(18, 6)  
 ,extended_amt DECIMAL(18, 6)  
 ,JDE_BU VARCHAR(7)  
 ,JDE_object VARCHAR(5)  
 ,min_invoice_date DATETIME  
 ,applied_date DATETIME  
 ,AX_account VARCHAR(250)   
 )  
  
-----------------------------------------------------------------------------------------  
-- Populate the #trx_data table with the next invoice number from Epicor, and the mask  
-- that goes with it.  
-----------------------------------------------------------------------------------------  
-- We'll do this with two passes of the work file.  
-- Pass 1: Stuff the integer portion of the doc control number into the table  
-- Pass 2: Add the mask (prefix) to the doc control number to make the "real" doc control number  
-- NOTE: We only need to get a new ewnumber for revision 1 invoices. Revision <> 1 invoices already have  
-- an invoice_code/doc_ctrl_num  
--IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' Lookup NTSQLFINANCE.e01.dbo.ewnumber WHERE num_type = 2001'  
DELETE  
FROM #trx_data -- start with an empty table  
  
--INSERT INTO #trx_data SELECT next_num, mask  
-- FROM NTSQLFINANCE.e01.dbo.ewnumber  
-- WHERE num_type = 2001  
-----------------------------------------------------------------------------------------  
-- Use Sequence table for next invoice number. 6/5/2013 JDB  
-- Uncommented below code for AX - 11/4/2016 AM  
-- NOTE: We only need to get a new invoice number for revision 1 invoices.  
-- Revision <> 1 invoices already have an invoice_code.  
-----------------------------------------------------------------------------------------  
/*IF @ai_debug = 1  
 PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Lookup Sequence.next_value WHERE name = ''Invoice.invoice_code'''  
  
INSERT INTO #trx_data  
SELECT next_value  
 ,NULL  
FROM dbo.Sequence  
WHERE name = 'Invoice.invoice_code'  
  
SELECT @error_value = @@ERROR  
  
IF @error_value <> 0  
BEGIN  
 -- Raise an error and return  
 SET @error_msg = 'Error inserting into #trx_data for next invoice number from Sequence table.'  
  
 RAISERROR (  
   @error_msg  
   ,16  
   ,1  
   )  
  
 RETURN ISNULL(@error_value, 0)  
END*/  
  
-----------------------------------------------------------------------------------------  
-- Use JDE's F0002 table for next invoice number. 9/30/2013 JDB  
-- NOTE: We only need to get a new invoice number for revision 1 invoices.  
-- Revision <> 1 invoices already have an invoice_code.  
-----------------------------------------------------------------------------------------  
SELECT @invoice_count = COUNT(DISTINCT invoice_id)  
FROM #InvoiceRecordsToExport AS irte  
WHERE revision_id = 1  
  
---------------------------------------------------------------  
-- Do we export invoices/adjustments to Epicor?  
---------------------------------------------------------------  
SELECT @sync_invoice_epicor = sync  
FROM dbo.FinanceSyncControl  
WHERE module = 'Invoice'  
 AND financial_system = 'Epicor'  
  
---------------------------------------------------------------  
-- Do we export invoices/adjustments to JDE?  
---------------------------------------------------------------  
SELECT @sync_invoice_jde = sync  
FROM dbo.FinanceSyncControl  
WHERE module = 'Invoice'  
 AND financial_system = 'JDE'  
  
---------------------------------------------------------------  
-- Do we export invoices/adjustments to AX?  
---------------------------------------------------------------  
SELECT @sync_invoice_ax = sync  
FROM dbo.FinanceSyncControl  
WHERE module = 'Invoice'  
 AND financial_system = 'AX'  
  
SELECT @ax_web_service = config_value  
FROM dbo.Configuration  
WHERE config_key = 'ax_web_service'  
  
-- begin single transaction here, before checks against each system  
BEGIN TRANSACTION TRAN1  
  
--DevOps-12477 - D365  
SELECT @d365_go_live_flag = dbo.fn_get_D365_live()  
  
--DevOps 50101  
SELECT @invoice_multiple_projects = dbo.fn_get_invoice_multiple_projects()  
  
IF (@d365_go_live_flag = '1')  
 AND (@invoice_multiple_projects = 'F')  
BEGIN  
 DECLARE d365_Cursor CURSOR FAST_FORWARD  
 FOR  
 SELECT invoice_id  
  ,revision_id  
 FROM #InvoiceRecordsToExport  
 WHERE revision_id >= 1  
  
 OPEN d365_Cursor  
  
 -- prime the pump  
 FETCH NEXT  
 FROM d365_Cursor  
 INTO @d365_invoice_id  
  ,@d365_revision_id  
  
 -- loop through all companies for this exporting session to get appropriate trx_ctrl_num loaded  
 WHILE @@FETCH_STATUS = 0  
 BEGIN  
  SELECT @count = count(DISTINCT ibd.AX_Dimension_5_Part_1 + CASE   
     WHEN isnull(ibd.AX_Dimension_5_Part_2, '') = ''  
      THEN ''  
     ELSE '.' + ibd.AX_Dimension_5_Part_2  
     END)  
  FROM dbo.InvoiceBillingDetail AS ibd  
  JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = ibd.invoice_id  
   AND ih.revision_id = ibd.revision_id  
  WHERE ibd.invoice_id = @d365_invoice_id  
   AND ibd.revision_id = @d365_revision_id  
   AND isnull(ibd.AX_Dimension_5_Part_1, '') <> ''  
  
  IF @count > 1  
  BEGIN  
   SET @error_msg = 'Project is not the same on Invoice' + Convert(VARCHAR(15), @d365_invoice_id) + ' for every receipt/workorder.'  
   SET @error_value = - 1  
  
   CLOSE d365_Cursor  
  
   DEALLOCATE d365_Cursor  
  
   GOTO END_OF_PROC  
  END  
  
  -- get next adjustment  
  FETCH NEXT  
  FROM d365_Cursor  
  INTO @d365_invoice_id  
   ,@d365_revision_id  
 END -- WHILE @@FETCH_STATUS = 0  
  
 CLOSE d365_Cursor  
  
 DEALLOCATE d365_Cursor  
END  
  
-- Export the invoices/adjustments to AX  
IF @sync_invoice_ax = 1  
BEGIN  
 IF @ai_debug = 1  
  PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Exporting invoice(s)/adjustment(s) to AX...'  
  
 SET @invalid_gl_count = 0  
  
 -----------------------------------------------------------------------------  
 -- Store preivew invoice information in a temp table in order to populate  
 -- the real invoice number (from JDE Next Number F0002 table - used to come  
 -- from Epicor ewnumber, then the Sequence table in Plt_AI.)  
 -----------------------------------------------------------------------------  
 -- IF OBJECT_ID('tempdb..#tmp_invoice_code') IS NOT NULL  
 --DROP TABLE #tmp_invoice_code  
 --CREATE TABLE #tmp_invoice_code(invoice_id int,revision_id int,invoice_code varchar(16),invoice_code_int int,cust_name varchar(75),customer_id int)  
 ----------------------------------------------------------------  
 -- Create temporary table to store the Adjustment data  
 ----------------------------------------------------------------  
 --INSERT INTO #tmp_invoice_code_ax  
 SELECT irte.invoice_id  
  ,irte.revision_id  
  ,irte.invoice_code  
  ,0 AS invoice_code_int  
  ,ih.cust_name  
  ,ih.customer_id  
  ,ih.[Status]  
 INTO #tmp_invoice_code_ax  
 FROM #InvoiceRecordsToExport AS irte  
 JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = irte.invoice_id  
  AND ih.revision_id = irte.revision_id  
 --ORDER BY ih.cust_name --NOTE: would not affect data commented out for performance  
 -- ,ih.customer_id  
 -- ,irte.invoice_code  
   
 IF @ai_debug = 1  
  PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Lookup Sequence.next_value WHERE name = ''Invoice.invoice_code'''  
   
 BEGIN TRANSACTION TRAN2  
  INSERT INTO #trx_data  
  SELECT next_value  
   ,NULL  
  FROM dbo.Sequence  
  WHERE name = 'Invoice.invoice_code'  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Raise an error and return  
   SET @error_msg = 'Error inserting into #trx_data for next invoice number from Sequence table.'  
  
   RAISERROR (  
     @error_msg  
     ,16  
     ,1  
     )  
  
   RETURN ISNULL(@error_value, 0)  
  END  
   
  UPDATE Sequence  
  SET next_value = next_value + (SELECT COUNT(1) FROM #InvoiceRecordsToExport)  
  WHERE name = 'Invoice.invoice_code'  
  
  SELECT @error_value = @@ERROR  
  
  IF @ai_debug = 1  
   PRINT ' after @invoice_code = ' + CONVERT(VARCHAR(20), @invoice_code)  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating Sequence for next invoice number.'  
   ROLLBACK TRANSACTION TRAN2  
   GOTO END_OF_PROC  
  END  
  ELSE  
  BEGIN  
   COMMIT TRANSACTION TRAN2  
  END  
  
 SELECT @count_adjustments = COUNT(*)  
 FROM #tmp_invoice_code_ax  
 WHERE revision_id > 1  
  
 -----------------------------------------------------------------------------------------------------------------------  
 -- Now, if there are adjustments in our list, we need to check that any JDE GL accounts that are being credited  
 -- from the previous revision are valid, too. First, loop through the adjusted invoices and execute the  
 -- sp_ExportInvoicesAdjustmentData procedure for each one, which populates the #InvoiceBillingDetail_AdjustmentData  
 -- table with the proper JDE GL accounts and difference in amounts between this revision and the previous one.  
 -----------------------------------------------------------------------------------------------------------------------  
 IF @ai_debug = 1  
  PRINT 'SELECT * FROM #InvoiceBillingDetail_AdjustmentData (before deleting from jde)'  
  
 IF @ai_debug = 1  
  SELECT *  
  FROM #InvoiceBillingDetail_AdjustmentData  
  
 IF @ai_debug = 1  
  PRINT '@count_adjustments from #tmp_invoice_code_ax '  
  
 IF @ai_debug = 1  
  SELECT *  
  FROM #tmp_invoice_code_ax  
  
 IF @count_adjustments > 0  
 BEGIN  
  --IF OBJECT_ID('tempdb..#InvoiceBillingDetail_AdjustmentData') IS NOT NULL  
  -- DROP TABLE #InvoiceBillingDetail_AdjustmentData  
  ----------------------------------------------------------------  
  -- Create temporary table to store the Adjustment data  
  ----------------------------------------------------------------  
  DELETE #InvoiceBillingDetail_AdjustmentData  
  
  IF @ai_debug = 1  
   PRINT 'SELECT * FROM #InvoiceBillingDetail_AdjustmentData (after deleting from jde)'  
  
  IF @ai_debug = 1  
   SELECT *  
   FROM #InvoiceBillingDetail_AdjustmentData  
  
  INSERT INTO #InvoiceBillingDetail_AdjustmentData  
  SELECT orig_billing_uid  
   ,orig_billingdetail_uid  
   ,orig_ref_billingdetail_uid  
   ,invoice_id  
   ,revision_id  
   ,billingtype_uid  
   ,billing_type  
   ,company_id  
   ,profit_ctr_id  
   ,receipt_id  
   ,line_id  
   ,price_id  
   ,trans_source  
   ,trans_type  
   ,product_id  
   ,dist_company_id  
   ,dist_profit_ctr_id  
   ,sales_tax_id  
   ,applied_percent  
   ,extended_amt  
   ,JDE_BU AS JDE_BU  
   ,JDE_object AS JDE_object  
   ,CONVERT(DATETIME, NULL) AS min_invoice_date  
   ,CONVERT(DATETIME, NULL) AS applied_date  
   ,CASE len(rtrim(AX_Dimension_5_Part_2))  
    WHEN 0  
     THEN AX_MainAccount + '-' + AX_Dimension_1 + '-' + AX_Dimension_2 + '-' + AX_Dimension_3 + '-' + AX_Dimension_4 + '-' + AX_Dimension_6 + '-' + AX_Dimension_5_Part_1  
    ELSE AX_MainAccount + '-' + AX_Dimension_1 + '-' + AX_Dimension_2 + '-' + AX_Dimension_3 + '-' + AX_Dimension_4 + '-' + AX_Dimension_6 + '-' + AX_Dimension_5_Part_1 + '.' + AX_Dimension_5_Part_2  
    END AS AX_ACCOUNT  
  FROM dbo.InvoiceBillingDetail  
  WHERE 0 = 1 --TODO: Wouldn't this prevent the query from returning data?  
  
  -- For the Adjustments, loop through and execute the sp_ExportInvoicesAdjustmentData procedure  
  -- in order to get the difference between this revision and the prior one.  
  DECLARE Adjustment_Cursor_1_AX CURSOR FAST_FORWARD  
  FOR  
  SELECT invoice_id  
   ,revision_id  
  FROM #tmp_invoice_code_ax  
  WHERE revision_id > 1  
  
  OPEN Adjustment_Cursor_1_AX  
  
  -- prime the pump  
  FETCH NEXT  
  FROM Adjustment_Cursor_1_AX  
  INTO @invoice_id_adj  
   ,@revision_id_adj  
  
  -- loop through all companies for this exporting session to get appropriate trx_ctrl_num loaded  
  WHILE @@FETCH_STATUS = 0  
  BEGIN  
   -- Execute sp_ExportInvoicesAdjustmentData to calculate differences between this revision and the prior one.  
   EXEC sp_ExportInvoicesAdjustmentData @invoice_id_adj  
    ,@revision_id_adj  
    ,@ai_debug  
  
   -- get next adjustment  
   FETCH NEXT  
   FROM Adjustment_Cursor_1_AX  
   INTO @invoice_id_adj  
    ,@revision_id_adj  
  END -- WHILE @@FETCH_STATUS = 0  
  
  CLOSE Adjustment_Cursor_1_AX  
  
  DEALLOCATE Adjustment_Cursor_1_AX  
 END -- IF @count_adjustments > 0  
  
 -----------------------------------------------------------------------------  
 -- Store the earliest invoice date (if any) for each transaction in a temp  
 -- table in order to calculate the appropriate GL account.  
 -----------------------------------------------------------------------------  
 DROP TABLE  
  
 IF EXISTS #MinInvoiceDateAX;  
  CREATE TABLE #MinInvoiceDateAX (  
   company_id INT NOT NULL  
   ,profit_ctr_id INT NULL  
   ,receipt_id INT NULL  
   ,trans_source VARCHAR(50) NULL  
   ,min_invoice_date DATETIME NULL  
   ,min_invoice_year INT NULL  
   )  
  
 INSERT INTO #MinInvoiceDateAX (  
  company_id  
  ,profit_ctr_id  
  ,receipt_id  
  ,trans_source  
  ,min_invoice_date  
  ,min_invoice_year  
  )  
 SELECT DISTINCT ibd.company_id  
  ,ibd.profit_ctr_id  
  ,ibd.receipt_id  
  ,ibd.trans_source  
  ,min_invoice_date = (  
   SELECT MIN(ihmin.invoice_date)  
   FROM dbo.InvoiceHeader AS ihmin  
   JOIN dbo.InvoiceDetail AS idmin ON idmin.invoice_id = ihmin.invoice_id  
    AND idmin.revision_id = ihmin.revision_id  
   WHERE idmin.company_id = ibd.company_id  
    AND idmin.profit_ctr_id = ibd.profit_ctr_id  
    AND idmin.receipt_id = ibd.receipt_id  
    AND idmin.trans_source = ibd.trans_source  
    AND ihmin.STATUS IN (  
     'I'  
     ,'O'  
     )  
   )  
  ,CONVERT(INT, NULL) AS min_invoice_year  
 --INTO #MinInvoiceDateAX  
 FROM #InvoiceRecordsToExport AS irte  
 JOIN dbo.InvoiceBillingDetail AS ibd ON ibd.invoice_id = irte.invoice_id  
  AND ibd.revision_id = irte.revision_id  
 JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = irte.invoice_id  
  AND ih.revision_id = irte.revision_id  
  
 UPDATE #MinInvoiceDateAX  
 SET min_invoice_year = DATEPART(year, min_invoice_date)  
  
 -- rb don't validate AX dimensions  
 DROP TABLE  
  
 IF EXISTS #acc;  
  CREATE TABLE #acc (  
   AX_MainAccount VARCHAR(50) NULL  
   ,AX_Dimension_1 VARCHAR(50) NULL  
   ,AX_Dimension_2 VARCHAR(50) NULL  
   ,AX_Dimension_3 VARCHAR(50) NULL  
   ,AX_Dimension_4 VARCHAR(50) NULL  
   ,AX_Dimension_6 VARCHAR(50) NULL  
   ,AX_Dimension_5_part_1 VARCHAR(50) NULL  
   ,AX_Dimension_5_part_2 VARCHAR(50) NULL  
   ,STATUS VARCHAR(8000) NULL  
   )  
  
 INSERT INTO #acc (  
  AX_MainAccount  
  ,AX_Dimension_1  
  ,AX_Dimension_2  
  ,AX_Dimension_3  
  ,AX_Dimension_4  
  ,AX_Dimension_6  
  ,AX_Dimension_5_part_1  
  ,AX_Dimension_5_part_2  
  ,STATUS  
  )  
 SELECT DISTINCT ibd.AX_MainAccount  
  ,ibd.AX_Dimension_1  
  ,ibd.AX_Dimension_2  
  ,ibd.AX_Dimension_3  
  ,ibd.AX_Dimension_4  
  ,ibd.AX_Dimension_6  
  ,ibd.AX_Dimension_5_part_1  
  ,ibd.AX_Dimension_5_part_2  
  ,convert(VARCHAR(8000), NULL) AS STATUS --TODO: was MAX can I get this even smaller 100?  
  --INTO #acc  
 FROM #tmp_invoice_code_ax AS tic  
 JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = tic.invoice_id  
  AND ih.revision_id = tic.revision_id  
 JOIN dbo.InvoiceBillingDetail AS ibd ON ibd.invoice_id = ih.invoice_id  
  AND ibd.revision_id = ih.revision_id  
  
 UPDATE #acc  
 SET STATUS = 'Valid' /*dbo.fnValidateFinancialDimension (@ax_web_service,AX_MainAccount,AX_Dimension_1,AX_Dimension_2,AX_Dimension_3,AX_Dimension_4,AX_Dimension_6,  
 AX_Dimension_5_part_1,AX_Dimension_5_part_2 )*/  
  
 INSERT INTO dbo.BillingAudit (  
  audit_id  
  ,company_id  
  ,profit_ctr_id  
  ,receipt_id  
  ,line_id  
  ,price_id  
  ,billing_summary_id  
  ,transaction_code  
  ,table_name  
  ,column_name  
  ,before_value  
  ,after_value  
  ,date_modified  
  ,modified_by  
  ,audit_reference  
  ,trans_source  
  )  
 SELECT DISTINCT (  
   SELECT MAX(audit_id) + 1  
   FROM dbo.BillingAudit  
   ) AS audit_id  
  ,ibd.company_id  
  ,ibd.profit_ctr_id  
  ,ibd.receipt_id  
  ,ibd.line_id  
  ,ibd.price_id  
  ,0 AS billing_summary_id  
  ,'E' AS transaction_code  
  ,'InvoiceBillingDetail' AS table_name  
  ,'AX' AS column_name  
  ,ibd.billing_type AS before_value  
  ,(ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1 + '.' + ibd.AX_Dimension_5_Part_2) AS after_value  
  ,@date_today AS date_modified  
  ,@as_userid AS modified_by  
  ,'Invoice Export Failed. Invalid AX GL Account. Customer: ' + ih.cust_name + ' (' + CONVERT(VARCHAR(10), ih.customer_id) + '). Invoice ID: ' + CONVERT(VARCHAR(10), ibd.invoice_id) + '-' + CONVERT(VARCHAR(10), ibd.revision_id) AS audit_reference  
  ,ibd.trans_source  
 FROM #tmp_invoice_code_ax AS tic  
 JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = tic.invoice_id  
  AND ih.revision_id = tic.revision_id  
 JOIN dbo.InvoiceBillingDetail AS ibd ON ibd.invoice_id = ih.invoice_id  
  AND ibd.revision_id = ih.revision_id  
 JOIN #acc AS a ON ibd.AX_MainAccount = a.AX_MainAccount  
  AND ibd.AX_Dimension_1 = a.AX_Dimension_1  
  AND ibd.AX_Dimension_2 = a.AX_Dimension_2  
  AND ibd.AX_Dimension_3 = a.AX_Dimension_3  
  AND ibd.AX_Dimension_4 = a.AX_Dimension_4  
  AND ibd.AX_Dimension_6 = a.AX_Dimension_6  
  AND ibd.AX_Dimension_5_Part_1 = a.AX_Dimension_5_Part_1  
  AND ibd.AX_Dimension_5_Part_2 = a.AX_Dimension_5_Part_2  
 LEFT OUTER JOIN #MinInvoiceDateAX AS mid ON mid.company_id = ibd.company_id  
  AND mid.profit_ctr_id = ibd.profit_ctr_id  
  AND mid.receipt_id = ibd.receipt_id  
  AND mid.trans_source = ibd.trans_source  
 WHERE 1 = 1  
  AND tic.revision_id = 1  
  AND UPPER(a.STATUS) <> 'VALID'  
  
 --AND UPPER(dbo.fnValidateFinancialDimension(ibd.AX_MainAccount,ibd.AX_Dimension_1,ibd.AX_Dimension_2,ibd.AX_Dimension_3,ibd.AX_Dimension_4,ibd.AX_Dimension_6,  
 -- ibd.AX_Dimension_5_part_1,ibd.AX_Dimension_5_part_2 ) ) <> 'VALID'  
 SELECT @error_value = @@ERROR  
  ,@invalid_gl_count = @invalid_gl_count + @@ROWCOUNT  
  
 IF @error_value <> 0  
 BEGIN  
  -- Raise an error and return  
  SET @error_msg = 'Error inserting record into BillingAudit for invalid/missing AX GL account(s).'  
  
  GOTO END_OF_PROC  
 END  
  
 --IF @ai_debug = 1 PRINT ' @@ anitha error value = ' + CONVERT(varchar(20), @invalid_gl_count)  
 --IF @ai_debug = 1 PRINT ' @@ anitha @invalid_gl_count = ' + CONVERT(varchar(20), @invalid_gl_count)  
 --IF @ai_debug = 1 select * from BillingAudit where date_modified between '7/16/2017' AND '7/18/2017'  
 -- AM FEB 20 2017 - Validate Adjustments  
 IF @count_adjustments > 0  
 BEGIN  
  DROP TABLE  
  
  IF EXISTS #accadj;  
   CREATE TABLE #accadj (  
    AX_MainAccount VARCHAR(50) NULL  
    ,AX_Dimension_1 VARCHAR(50) NULL  
    ,AX_Dimension_2 VARCHAR(50) NULL  
    ,AX_Dimension_3 VARCHAR(50) NULL  
    ,AX_Dimension_4 VARCHAR(50) NULL  
    ,AX_Dimension_6 VARCHAR(50) NULL  
    ,AX_Dimension_5_part_1 VARCHAR(50) NULL  
    ,AX_Dimension_5_part_2 VARCHAR(50) NULL  
    ,STATUS VARCHAR(8000) NULL --WAS MAX should be 100?  
    )  
  
  INSERT INTO #accadj (  
   AX_MainAccount  
   ,AX_Dimension_1  
   ,AX_Dimension_2  
   ,AX_Dimension_3  
   ,AX_Dimension_4  
   ,AX_Dimension_6  
   ,AX_Dimension_5_part_1  
   ,AX_Dimension_5_part_2  
   ,STATUS  
   )  
  SELECT DISTINCT ibd.AX_MainAccount  
   ,ibd.AX_Dimension_1  
   ,ibd.AX_Dimension_2  
   ,ibd.AX_Dimension_3  
   ,ibd.AX_Dimension_4  
   ,ibd.AX_Dimension_6  
   ,ibd.AX_Dimension_5_part_1  
   ,ibd.AX_Dimension_5_part_2  
   ,convert(VARCHAR(8000), NULL) AS STATUS --WAS MAX should be 100?  
   --INTO #accadj  
  FROM #tmp_invoice_code_ax tic  
  JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = tic.invoice_id  
   AND ih.revision_id = tic.revision_id  
  JOIN dbo.InvoiceBillingDetail AS ibd ON ibd.invoice_id = ih.invoice_id  
   AND ibd.revision_id = ih.revision_id  
  
  UPDATE #accadj  
  SET STATUS = 'Valid' /*dbo.fnValidateFinancialDimension (@ax_web_service,AX_MainAccount,AX_Dimension_1,AX_Dimension_2,AX_Dimension_3,AX_Dimension_4,AX_Dimension_6,  
 AX_Dimension_5_part_1,AX_Dimension_5_part_2 ) */  
  WHERE STATUS IS NULL  
  
  INSERT INTO dbo.BillingAudit (  
   audit_id  
   ,company_id  
   ,profit_ctr_id  
   ,receipt_id  
   ,line_id  
   ,price_id  
   ,billing_summary_id  
   ,transaction_code  
   ,table_name  
   ,column_name  
   ,before_value  
   ,after_value  
   ,date_modified  
   ,modified_by  
   ,audit_reference  
   ,trans_source  
   )  
  SELECT DISTINCT (  
    SELECT MAX(audit_id) + 1  
    FROM BillingAudit  
    ) AS audit_id  
   ,ibd.company_id  
   ,ibd.profit_ctr_id  
   ,ibd.receipt_id  
   ,ibd.line_id  
   ,ibd.price_id  
   ,0 AS billing_summary_id  
   ,'E' AS transaction_code  
   ,'InvoiceBillingDetail' AS table_name  
   ,'AX' AS column_name  
   ,ibd.billing_type AS before_value  
   ,(ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1 + '.' + ibd.AX_Dimension_5_Part_2) AS after_value  
   ,@date_today AS date_modified  
   ,@as_userid AS modified_by  
   ,'Invoice Export Failed. Invalid AX GL Account. Customer: ' + ih.cust_name + ' (' + CONVERT(VARCHAR(10), ih.customer_id) + '). Invoice ID: ' + CONVERT(VARCHAR(10), ibd.invoice_id) + '-' + CONVERT(VARCHAR(10), ibd.revision_id) AS audit_reference  
   ,ibd.trans_source  
  FROM #tmp_invoice_code AS tic  
  JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = tic.invoice_id  
   AND ih.revision_id = tic.revision_id  
  JOIN dbo.InvoiceBillingDetail AS ibd ON ibd.invoice_id = ih.invoice_id  
   AND ibd.revision_id = ih.revision_id  
  JOIN #accadj AS a ON ibd.AX_MainAccount = a.AX_MainAccount  
   AND ibd.AX_Dimension_1 = a.AX_Dimension_1  
   AND ibd.AX_Dimension_2 = a.AX_Dimension_2  
   AND ibd.AX_Dimension_3 = a.AX_Dimension_3  
   AND ibd.AX_Dimension_4 = a.AX_Dimension_4  
   AND ibd.AX_Dimension_6 = a.AX_Dimension_6  
   AND ibd.AX_Dimension_5_Part_1 = a.AX_Dimension_5_Part_1  
   AND ibd.AX_Dimension_5_Part_2 = a.AX_Dimension_5_Part_2  
  LEFT OUTER JOIN #MinInvoiceDateAX AS mid ON mid.company_id = ibd.company_id  
   AND mid.profit_ctr_id = ibd.profit_ctr_id  
   AND mid.receipt_id = ibd.receipt_id  
   AND mid.trans_source = ibd.trans_source  
  WHERE 1 = 1  
   AND tic.revision_id > 1  
   AND UPPER(a.STATUS) <> 'VALID'  
  
  SELECT @error_value = @@ERROR  
   ,@invalid_gl_count = @invalid_gl_count + @@ROWCOUNT  
  
  IF @error_value <> 0  
  BEGIN  
   -- Raise an error and return  
   SET @error_msg = 'Error inserting record into BillingAudit for invalid/missing JDE GL account(s).'  
  
   GOTO END_OF_PROC  
  END  
 END  
  
 -- AM end Adjustment validation  
 --rb temp  
 --GEM:44274 AM - Invoice Processing - Preview Export tab error  
 IF @invalid_gl_count > 0  
 BEGIN  
  SET @invalid_gl_count = 0  
  SET @error_msg = ''  
  
  SELECT @as_invoicecode_from = '99999999'  
  
  SELECT @as_invoicecode_to = '99999999'  
  
  GOTO END_OF_PROC  
 END  
  
 IF @invalid_gl_count = 0  
 BEGIN  
  ------------------------------------------------------------------------------------------------------------------------------------------------------  
  -- Populate #tmp_invoice_code_ax table with the real invoice number.  
  ------------------------------------------------------------------------------------------------------------------------------------------------------  
  -- get trx data into local variables  
  SELECT @invoice_code = next_num - 1  
  FROM #trx_data  
  
  IF @ai_debug = 1  
   PRINT ' after select @invoice_code = ' + CONVERT(VARCHAR(20), @invoice_code)  
  
  UPDATE #tmp_invoice_code_ax  
  SET @invoice_code = invoice_code_int = @invoice_code + 1  
  WHERE revision_id = 1  
  
  IF @ai_debug = 1  
   PRINT ' after @invoice_code + 1 WHERE revision_id = 1 @invoice_code = ' + CONVERT(VARCHAR(20), @invoice_code)  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating #tmp_invoice_code_ax for invoice_code_int.'  
  
   GOTO END_OF_PROC  
  END  
  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' SELECT * FROM #tmp_invoice_code_ax'  
  
  IF @ai_debug = 1  
   SELECT *  
   FROM #tmp_invoice_code_ax  
  
  ---- Update Sequence so that the next user doesn't use the same number(s) that we did.  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Update Sequence WHERE name = ''Invoice.invoice_code'''  
  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' @docctrlnum = ' + CONVERT(VARCHAR(20), @docctrlnum)  
  
  IF @ai_debug = 1  
   PRINT ' before @invoice_code + 1 = ' + CONVERT(VARCHAR(20), @invoice_code)  
  
  SET @invoice_code = @invoice_code + 1 -- increment to get next_num  
  
  IF @ai_debug = 1  
   PRINT ' before @invoice_code = ' + CONVERT(VARCHAR(20), @invoice_code)  
  
  /*UPDATE Sequence  
  SET next_value = @invoice_code  
  WHERE name = 'Invoice.invoice_code'  
  
  SELECT @error_value = @@ERROR  
  
  IF @ai_debug = 1  
   PRINT ' after @invoice_code = ' + CONVERT(VARCHAR(20), @invoice_code)  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating Sequence for next invoice number.'  
  
   GOTO END_OF_PROC  
  END*/  
  
  -- Pass 2: Put together the mask and integer portion of the invoice number to get the start of a  
  -- doc_ctrl_num. It is assumed that ewnumber has the proper mask, i.e. "10000000"  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' UPDATE #tmp_invoice_code_ax SET invoice_code WHERE revision_id = 1'  
  
  UPDATE #tmp_invoice_code_ax  
  SET invoice_code = CONVERT(VARCHAR(16), invoice_code_int)  
  WHERE revision_id = 1  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating #tmp_invoice_code_ax for invoice_code (invoices).'  
  
   GOTO END_OF_PROC  
  END  
  
  --IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' SELECT * FROM #tmp_invoice_code'  
  --IF @ai_debug = 1 SELECT * FROM #tmp_invoice_code  
  --NOTE: Revision > 1 will already have a doc_ctrl_num related to the invoice it was created from.  
  -- Pass 3: Update invoice_code for adjustments; it is the same as the revision 1 of the invoice.  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' UPDATE #tmp_invoice_code_ax SET invoice_code WHERE revision_id > 1'  
  
  UPDATE #tmp_invoice_code_ax  
  SET invoice_code = (  
    SELECT ih.invoice_code  
    FROM dbo.InvoiceHeader AS ih  
    WHERE ih.invoice_id = #tmp_invoice_code_ax.invoice_id  
     AND ih.revision_id = 1  
    )  
  WHERE #tmp_invoice_code_ax.revision_id > 1  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating #tmp_invoice_code_ax for invoice_code (adjustments).'  
  
   GOTO END_OF_PROC  
  END  
  
  --IF @ai_debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + ' SELECT * FROM #tmp_invoice_code (after updating invoice_code for Adjustments)'  
  IF @ai_debug = 1  
   SELECT *  
   FROM #tmp_invoice_code_ax  
  
  --IF @ai_debug = 1 PRINT 'Inserting into JDEInvoicePayItem (invoices)'  
  -----------------------------------------------------------------------------------------------------------  
  -- Populate the AXInvoiceGL table with one record per AX GL account per receipt/work order. (invoices)  
  -----------------------------------------------------------------------------------------------------------  
  IF @ai_debug = 1  
   PRINT 'Inserting into AXInvoiceGL (invoices)'  
  
  DECLARE c_ax_invoice CURSOR FAST_FORWARD  
  FOR  
  SELECT DISTINCT invoice_id  
  FROM #tmp_invoice_code_ax  
  
  OPEN c_ax_invoice  
  
  FETCH c_ax_invoice  
  INTO @ax_invoice_id  
  
  WHILE @@FETCH_STATUS = 0  
  BEGIN  
   INSERT dbo.AXInvoiceHeader (  
    invoice_id  
    ,revision_id  
    ,customer_id  
    ,ECOLINVOICEID  
    ,ORDERACCOUNT  
    ,CURRENCYCODE  
    ,INVOICEDATE  
    ,DUEDATE  
    ,DEFAULTDIMENSION  
    ,POSTINGPROFILE  
    ,INVOICEACCOUNT  
    ,PURCHORDERFORMNUM  
    ,CUSTOMERREF  
    ,PAYMENT  
    ,PAYMMODE  
    ,CASHDISCCODE  
    ,ECOLADJUSTMENTID  
    ,ECOLORIGINALINVOICEID  
    ,added_by  
    ,date_added  
    ,modified_by  
    ,date_modified  
    )  
   SELECT tic.invoice_id  
    ,tic.revision_id  
    ,ih.customer_id AS customer_id  
    ,tic.invoice_code AS ECOLINVOICEID  
    ,c.ax_customer_id AS ORDERACCOUNT  
    ,ih.currency_code AS CURRENCYCODE --, 'USD' AS CURRENCYCODE  
    ,ih.invoice_date AS INVOICEDATE  
    ,ih.due_date AS DUEDATE  
    ,'' AS DEFAULTDIMENSION  
    ,'Default' AS POSTINGPROFILE  
    ,c.ax_invoice_customer_id AS INVOICEACCOUNT  
    --, CASE WHEN ih.customer_po = '' THEN 'None'  
    -- ELSE ih.customer_po END AS PURCHORDERFORMNUM  
    ,(  
     SELECT CASE   
       WHEN (  
         SELECT count(DISTINCT isnull(nullif(purchase_order, ''), 'None'))  
         FROM dbo.InvoiceDetail  
         WHERE invoice_id = tic.invoice_id  
          AND revision_id = 1  
         ) > 1  
        THEN 'Multiple'  
       ELSE (  
         SELECT DISTINCT isnull(nullif(purchase_order, ''), 'None')  
         FROM dbo.InvoiceDetail  
         WHERE invoice_id = tic.invoice_id  
          AND revision_id = 1  
         )  
       END  
     ) AS PURCHORDERFORMNUM  
    ,ih.customer_release AS CUSTOMERREF  
    ,CASE   
     WHEN cs.d365_payment_term IS NULL  
      THEN at.AX_payment_term_id   
     ELSE cs.d365_payment_term END AS PAYMENT  
    ,'CHK' AS PAYMMODE  
    ,at.AX_cash_discount_code AS CASHDISCCODE  
    ,NULL AS ECOLADJUSTMENTID  
    ,NULL AS ECOLORIGINALINVOICEID  
    ,@as_userid AS added_by  
    ,@date_today AS date_added  
    ,@as_userid AS modified_by  
    ,@date_today AS date_modified  
   FROM #tmp_invoice_code_ax AS tic  
   JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = tic.invoice_id  
    AND ih.revision_id = tic.revision_id  
   JOIN dbo.Customer AS c ON c.customer_id = ih.customer_id  
   LEFT OUTER JOIN ECOL_D365Integration.dbo.CustomerSync cs ON cs.d365_accountnum = c.ax_customer_id  
   LEFT OUTER JOIN dbo.ARTerms AS at ON at.terms_code = ih.terms_code  
   WHERE tic.invoice_id = @ax_invoice_id  
    AND tic.revision_id = 1  
  
   SELECT @error_value = @@ERROR  
    ,@ax_header_uid = @@IDENTITY  
  
   IF @error_value <> 0  
   BEGIN  
    CLOSE c_ax_invoice  
  
    DEALLOCATE c_ax_invoice  
  
    -- Set message for RAISEERROR and go to the end  
    SET @error_msg = 'Error inserting into AXInvoiceHeader (invoices).'  
  
    GOTO END_OF_PROC  
   END  
  
   INSERT dbo.AXInvoiceLine (  
    axinvoiceheader_uid  
    ,company_id  
    ,profit_ctr_id  
    ,CUSTINVOICELINE_LINENUM  
    ,CUSTINVOICELINE_DESCRIPTION  
    ,CUSTINVOICELINE_QUANTITY  
    ,CUSTINVOICELINE_UNITPRICE  
    ,CUSTINVOICELINE_AMOUNTCUR  
    ,CUSTINVOICELINE_PROJID  
    ,CUSTINVOICELINE_ECOLSOURCESYSTEM  
    ,CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE  
    ,CUSTINVOICELINE_ECOLSOURCECOMPANY  
    ,CUSTINVOICELINE_ECOLSOURCEPROFITCENTER  
    ,CUSTINVOICELINE_ECOLSOURCETRANSACTIONID  
    ,CUSTINVOICELINE_ECOLMANIFEST  
    ,CUSTINVOICELINE_ECOLWASTESTREAM  
    ,CUSTINVOICELINE_LEDGERDIMENSION  
    ,CUSTINVOICELINE_PROJCATEGORYID  
    ,ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE  
    ,ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION  
    ,ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT  
    ,added_by  
    ,date_added  
    ,modified_by  
    ,date_modified  
    ,currency_code  
    )  
   SELECT @ax_header_uid  
    ,id.company_id  
    ,id.profit_ctr_id  
    ,DENSE_RANK() OVER (  
     ORDER BY ibd.company_id  
      ,ibd.profit_ctr_id  
      ,ibd.trans_source  
      ,ibd.receipt_id  
      ,id.line_id  
      ,id.price_id  
     ) AS CUSTINVOICELINE_LINENUM  
    ,id.line_desc_1 AS CUSTINVOICELINE_DESCRIPTION  
    ,id.qty_ordered AS CUSTINVOICELINE_QUANTITY  
    ,CUSTINVOICELINE_UNITPRICE = (  
     SELECT SUM(id2.unit_price)  
     FROM dbo.InvoiceDetail AS id2  
     WHERE ibd.invoice_id = id2.invoice_id  
      AND ibd.revision_id = id2.revision_id  
      AND id.company_id = id2.company_id  
      AND id.profit_ctr_id = id2.profit_ctr_id  
      AND ibd.trans_source = id2.trans_source  
      AND id.receipt_id = id2.receipt_id  
      AND id.line_id = id2.line_id  
      AND id.price_id = id2.price_id  
     )  
    ,CUSTINVOICELINE_AMOUNTCUR = (  
     SELECT SUM(ibd1.extended_amt)  
     FROM dbo.InvoiceBillingDetail AS ibd1  
     WHERE ibd.invoice_id = ibd1.invoice_id  
      AND ibd.revision_id = ibd1.revision_id  
      AND ibd.trans_source = ibd1.trans_source  
      AND id.receipt_id = ibd1.receipt_id  
      AND id.line_id = ibd1.line_id  
      AND id.price_id = ibd1.price_id  
      AND id.company_id = ibd1.company_id  
      AND id.profit_ctr_id = ibd1.profit_ctr_id  
     )  
    ,dbo.fn_get_workorder_AX_dim5_project(ibd.company_id, ibd.profit_ctr_id, ibd.receipt_id) AS CUSTINVOICELINE_PROJID  
    ,'EQAI' AS CUSTINVOICELINE_ECOLSOURCESYSTEM  
    ,CASE ibd.trans_source  
     WHEN 'R'  
      THEN 'Receipt'  
     WHEN 'W'  
      THEN 'Work Order'  
     WHEN 'O'  
      THEN 'Retail Order'  
     ELSE ''  
     END AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE  
    ,ibd.company_id AS CUSTINVOICELINE_ECOLSOURCECOMPANY  
    ,ibd.profit_ctr_id AS CUSTINVOICELINE_ECOLSOURCEPROFITCENTER  
    ,ibd.receipt_id AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONID  
    ,CASE ibd.trans_source  
     WHEN 'R'  
      THEN b.manifest  
     WHEN 'W'  
      THEN dbo.fn_get_workorder_min_manifest(ibd.receipt_id, ibd.company_id, ibd.profit_ctr_id)  
     ELSE ''  
     END AS CUSTINVOICELINE_ECOLMANIFEST  
    ,id.approval_code AS CUSTINVOICELINE_ECOLWASTESTREAM  
    ,99999 AS CUSTINVOICELINE_LEDGERDIMENSION  
    ,CASE   
     WHEN dbo.fn_get_workorder_AX_dim5_project(ibd.company_id, ibd.profit_ctr_id, ibd.receipt_id) <> ''  
      THEN 'FTI IMPORT'  
     ELSE ''  
     END AS CUSTINVOICELINE_PROJCATEGORYID  
    ,ih.applied_date AS ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE -- ih.applied_date  
    ,CASE len(rtrim(ibd.AX_Dimension_5_Part_2))  
     WHEN 0  
      THEN ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1  
     ELSE ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1 + '.' + ibd.AX_Dimension_5_Part_2  
     END AS ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION  
    ,SUM(ibd.extended_amt) AS ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT  
    ,@as_userid AS added_by  
    ,@date_today AS date_added  
    ,@as_userid AS modified_by  
    ,@date_today AS date_modified  
    ,ih.currency_code  
   FROM dbo.AXInvoiceHeader AS aih  
   JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = aih.invoice_id  
    AND ih.revision_id = aih.revision_id  
   JOIN dbo.InvoiceBillingDetail AS ibd ON ibd.invoice_id = ih.invoice_id  
    AND ibd.revision_id = ih.revision_id  
   JOIN dbo.InvoiceDetail AS id ON id.invoice_id = ih.invoice_id  
    AND id.revision_id = ih.revision_id  
    AND id.receipt_id = ibd.receipt_id  
    AND id.line_id = ibd.line_id  
    AND id.price_id = ibd.price_id  
    AND id.company_id = ibd.company_id  
    AND id.profit_ctr_id = ibd.profit_ctr_id  
    AND id.location_code <> 'EQAI-TAX'  
    AND id.location_code <> 'EQAI-SR'  
   JOIN dbo.Customer AS c ON c.customer_id = ih.customer_id  
   LEFT OUTER JOIN dbo.Billing AS b ON id.company_id = b.company_id  
    AND id.profit_ctr_id = b.profit_ctr_id  
    AND id.receipt_id = b.receipt_id  
    AND id.line_id = b.line_id  
    AND id.price_id = b.price_id  
    AND b.trans_source = 'R'  
   LEFT OUTER JOIN dbo.ARTerms AS at ON at.terms_code = ih.terms_code  
   WHERE aih.axinvoiceheader_uid = @ax_header_uid  
   GROUP BY ih.invoice_id  
    ,ih.invoice_code  
    ,ibd.revision_id  
    ,ibd.invoice_id  
    ,ih.invoice_date  
    ,ibd.company_id  
    ,ibd.profit_ctr_id  
    ,ih.customer_id  
    ,c.ax_customer_id  
    ,c.ax_invoice_customer_id  
    ,ibd.trans_source  
    ,ibd.receipt_id  
    ,b.manifest  
    ,ih.applied_date  
    ,ih.due_date  
    ,ih.customer_po  
    ,ih.customer_release  
    ,ih.currency_code  
    ,at.AX_payment_term_id  
    ,id.line_id  
    ,at.AX_cash_discount_code  
    ,id.line_desc_1  
    ,id.qty_ordered  
    ,id.receipt_id  
    ,id.line_id  
    ,id.company_id  
    ,id.profit_ctr_id  
    ,id.unit_price  
    ,id.approval_code  
    ,id.price_id  
    ,ibd.AX_MainAccount  
    ,ibd.AX_Dimension_1  
    ,ibd.AX_Dimension_2  
    ,ibd.AX_Dimension_3  
    ,ibd.AX_Dimension_4  
    ,ibd.AX_Dimension_6  
    ,ibd.AX_Dimension_5_Part_1  
    ,ibd.AX_Dimension_5_Part_2  
   -- ORDER BY ih.customer_id --NOTE: commented out for performance  
    -- ,ibd.company_id  
    -- ,ibd.profit_ctr_id  
    -- ,ibd.trans_source  
    -- ,ibd.receipt_id  
  
   SELECT @error_value = @@ERROR  
  
   IF @error_value <> 0  
   BEGIN  
    CLOSE c_ax_invoice  
  
    DEALLOCATE c_ax_invoice  
  
    -- Set message for RAISEERROR and go to the end  
    SET @error_msg = 'Error inserting into AXInvoiceLine (invoices).'  
  
    GOTO END_OF_PROC  
   END  
  
   FETCH c_ax_invoice  
   INTO @ax_invoice_id  
  END  
  
  CLOSE c_ax_invoice  
  
  DEALLOCATE c_ax_invoice  
 END  
END  
  
IF @error_value = 0  
 AND @invalid_gl_count = 0  
 -- Export the invoices/adjustments to Epicor  
BEGIN  
 -------------------------------------------------------------------------------------------------------------  
 --------------- UPDATE EQAI TABLES ------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- Now that the epicor tables are updated for all companies with the invoice information we  
 -- have some EQAI tables to update:  
 -- EQAI tables: InvoiceHeader, BillingSummary, Billing, AdjustmentDetail, InvoiceRunRequest  
 -- Epicor tables: ARINPTMP, ARINPCHG, ARINPCDT, ARINPAGE, ARINPTAX, ARACTCUS  
 -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
 IF @sync_invoice_jde = 1  
 BEGIN  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating #InvoiceRecordsToExport...'  
  
  UPDATE #InvoiceRecordsToExport  
  SET invoice_code = tic.invoice_code -- replace the "Preview_xxxxx" with actual invoice_code  
  FROM #tmp_invoice_code AS tic  
  WHERE #InvoiceRecordsToExport.invoice_id = tic.invoice_id  
   AND #InvoiceRecordsToExport.revision_id = tic.revision_id  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating #InvoiceRecordsToExport for invoice_code.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating InvoiceHeader...'  
  
  UPDATE dbo.InvoiceHeader --TODO: update to be part of the JOIN  
  SET invoice_code = tic.invoice_code  
   ,-- replace the "Preview_xxxxx"  
   STATUS = CASE   
    WHEN (  
      SELECT Count(*)  
      FROM InvoiceDetail  
      WHERE InvoiceDetail.invoice_id = InvoiceHeader.invoice_id  
       AND InvoiceDetail.revision_id = InvoiceHeader.revision_id  
      ) = 0  
     THEN 'V'  
    ELSE 'Q'  
    END  
   ,-- if no detail lines, has to be a voided invoice, else "Q"ueue for printing  
   date_modified = @date_today  
   ,-- invoice printing will change "Q" to "I"nvoiced  
   modified_by = @as_userid  
   ,date_exported = @date_today  
   ,exported_by = @as_userid  
  FROM #tmp_invoice_code tic  
  WHERE InvoiceHeader.invoice_id = tic.invoice_id  
   AND InvoiceHeader.revision_id = tic.revision_id  
  /*  
  FROM dbo.InvoiceHeader AS ih  
  INNER JOIN #tmp_invoice_code_ax AS tic ON ih.invoice_id = tic.invoice_id  
   AND ih.revision_id = tic.revision_id  
  */  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating InvoiceHeader for invoice_code, status, exported info.'  
  
   GOTO END_OF_PROC  
  END  
  
  --JDB 1/16/14 Changed insert to use the #tmp_invoice_code table instead of #invhdr  
  --Queue up invoice PDF requests  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Insertng into InvoiceRunRequest...'  
  
  INSERT INTO Plt_Image.dbo.InvoiceRunRequest (  
   invoice_id  
   ,revision_id  
   ,date_added  
   ,added_by  
   ,build_attachment  
   ,save_in_db  
   ,request_status  
   )  
  SELECT invoice_id  
   ,revision_id  
   ,@date_today  
   ,@as_userid  
   ,CASE (SELECT 1  
          FROM Customer  
          WHERE Customer.customer_ID = tic.customer_ID  
          AND Customer.retail_customer_flag = 'T'  
          AND tic.revision_id > 1)
	WHEN 1 THEN 'F'
	ELSE 'T'
	END
   ,'T'  
   ,'X' -- Set to 'X' not 'Q' like the past. Invoice manager will turn into a 'Q' when appropriate  
  FROM #tmp_invoice_code tic  
 
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error inserting into Plt_Image..InvoiceRunRequest.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
  -- might have processed a billing record that was voided as part of adjustment processing.  
  -- if indeed the billing record is voided we don't want to mess with the status_code, but  
  -- storing the invoice code for reference purposes, might help for research purposes after the fact.  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating Billing...'  
  
  --TODO: confirm columns parent table status_code = 'V'  
  UPDATE b  
  SET b.invoice_code = tic.invoice_code  
   ,-- replace the "Preview_xxxxx"  
   b.invoice_date = ih.invoice_date  
   ,-- date could have changed from when it was previewed  
   b.invoice_preview_flag = 'F'  
   ,-- no longer being invoice previewed  
   b.status_code = CASE   
    WHEN b.status_code = 'V'  
     THEN b.status_code  
    ELSE 'I'  
    END  
   ,-- if voided, leave voided  
   b.date_modified = @date_today  
   ,b.modified_by = @as_userid  
  FROM #tmp_invoice_code AS tic  
  JOIN dbo.Billing AS b ON b.invoice_id = tic.invoice_id  
  JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = tic.invoice_id  
   AND ih.revision_id = tic.revision_id  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating Billing for invoice_code, invoice_date, status.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating BillingSummary...'  
  
  UPDATE BillingSummary  
  SET STATUS = 'I'  
  FROM #tmp_invoice_code AS tic  
  WHERE BillingSummary.invoice_id = tic.invoice_id  
   AND BillingSummary.revision_id = tic.revision_id  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating BillingSummary for status.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
  -- need to update adjustmentDetail records for non-rev 1 invoices so that the adjustment doesn't  
  -- get processed again  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating AdjustmentDetail...'  
  
  UPDATE AdjustmentDetail  
  SET export_required = 'E' -- "E"xported  
  FROM #tmp_invoice_code AS tic  
  WHERE AdjustmentDetail.invoice_id = tic.invoice_id  
   AND tic.revision_id > 1 -- can't be any adjustments for rev = 1  
   AND AdjustmentDetail.export_required = 'W' -- anything "W"aiting was just exported  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating AdjustmentDetail for export_required.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed to retrieve invoice numbers from #tmp_invoice_code instead of #invhdr  
  -- return the invoice_code range of invoices that were just exported (we know the numbers  
  -- were created in sequential order and all records in this temp table have been processed)  
  -- NOTE: This range doesn't do anybody any good when the user is exporting multiple adjusted  
  -- invoices. Perhaps sometime in the future this should be removed as it is not always  
  -- accurate.  
  SELECT @as_invoicecode_from = MIN(invoice_code)  
  FROM #tmp_invoice_code tic  
  
  SELECT @as_invoicecode_to = MAX(invoice_code)  
  FROM #tmp_invoice_code tic  
  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Exported invoice_code range: ' + IsNull(@as_invoicecode_from, '') + ' - ' + IsNull(@as_invoicecode_to, '')  
  
  --? Does anything else need to be done in the share database??  
  --?Audit Records??  
  -- calling routine should drop #InvoiceRecordsToExport  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Procedure Complete.'  
    -----------------------------------------------------------------  
    -- Commit or Rollback changes here  
    -----------------------------------------------------------------  
 END  
 ELSE IF @sync_invoice_ax = 1  
  AND @sync_invoice_jde <> 1  
 BEGIN  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating #InvoiceRecordsToExport...'  
  
  UPDATE #InvoiceRecordsToExport  
  SET invoice_code = tic.invoice_code -- replace the "Preview_xxxxx" with actual invoice_code  
  FROM #tmp_invoice_code_ax AS tic  
  WHERE #InvoiceRecordsToExport.invoice_id = tic.invoice_id  
   AND #InvoiceRecordsToExport.revision_id = tic.revision_id  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating #InvoiceRecordsToExport for invoice_code.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the ##tmp_invoice_code_ax table instead of #invhdr  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating InvoiceHeader...'  
  
  UPDATE ih  
  SET ih.invoice_code = tic.invoice_code  
   ,-- replace the "Preview_xxxxx"  
   STATUS = CASE   
    WHEN (  
      SELECT Count(*)  
      FROM dbo.InvoiceDetail AS id  
      WHERE id.invoice_id = ih.invoice_id  
       AND id.revision_id = ih.revision_id  
      ) = 0  
     THEN 'V'  
    ELSE 'Q'  
    END  
   ,-- if no detail lines, has to be a voided invoice, else "Q"ueue for printing  
   date_modified = @date_today  
   ,-- invoice printing will change "Q" to "I"nvoiced  
   modified_by = @as_userid  
   ,date_exported = @date_today  
   ,exported_by = @as_userid  
  FROM dbo.InvoiceHeader AS ih  
  INNER JOIN #tmp_invoice_code_ax AS tic ON ih.invoice_id = tic.invoice_id  
   AND ih.revision_id = tic.revision_id  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating InvoiceHeader for invoice_code, status, exported info.'  
  
   GOTO END_OF_PROC  
  END  
  
  --JDB 1/16/14 Changed insert to use the #tmp_invoice_code table instead of #invhdr  
  --Queue up invoice PDF requests  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Insertng into InvoiceRunRequest...'  
  
  INSERT INTO Plt_Image.dbo.InvoiceRunRequest (  
   invoice_id  
   ,revision_id  
   ,date_added  
   ,added_by  
   ,build_attachment  
   ,save_in_db  
   ,request_status  
   )  
  SELECT invoice_id  
   ,revision_id  
   ,@date_today  
   ,@as_userid  
   ,CASE (SELECT 1  
          FROM Customer  
          WHERE Customer.customer_ID = tic.customer_ID  
          AND Customer.retail_customer_flag = 'T'  
          AND tic.revision_id > 1)
	WHEN 1 THEN 'F'
	ELSE 'T'
	END
   ,'T'  
   ,'X' -- Set to 'X' not 'Q' like the past. Invoice manager will turn into a 'Q' when appropriate  
  FROM #tmp_invoice_code_ax AS tic  
 
  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error inserting into Plt_Image..InvoiceRunRequest.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
  -- might have processed a billing record that was voided as part of adjustment processing.  
  -- if indeed the billing record is voided we don't want to mess with the status_code, but  
  -- storing the invoice code for reference purposes, might help for research purposes after the fact.  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating Billing...'  
  
  --TODO: confirm status_code = 'V' is b.status_code = 'V'  
  UPDATE b  
  SET b.invoice_code = tic.invoice_code  
   ,-- replace the "Preview_xxxxx"  
   b.invoice_date = ih.invoice_date  
   ,-- date could have changed from when it was previewed  
   b.invoice_preview_flag = 'F'  
   ,-- no longer being invoice previewed  
   b.status_code = CASE   
    WHEN b.status_code = 'V'  
     THEN b.status_code  
    ELSE 'I'  
    END  
   ,-- if voided, leave voided  
   b.date_modified = @date_today  
   ,b.modified_by = @as_userid  
  FROM #tmp_invoice_code_ax AS tic  
  INNER JOIN dbo.Billing AS b ON b.invoice_id = tic.invoice_id  
  JOIN dbo.InvoiceHeader AS ih ON ih.invoice_id = tic.invoice_id  
   AND ih.revision_id = tic.revision_id  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating Billing for invoice_code, invoice_date, status.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating BillingSummary...'  
  
  UPDATE BillingSummary  
  SET STATUS = 'I'  
  FROM #tmp_invoice_code_ax AS tic  
  WHERE BillingSummary.invoice_id = tic.invoice_id  
   AND BillingSummary.revision_id = tic.revision_id  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating BillingSummary for status.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed update to use the #tmp_invoice_code table instead of #invhdr  
  -- need to update adjustmentDetail records for non-rev 1 invoices so that the adjustment doesn't  
  -- get processed again  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Updating AdjustmentDetail...'  
  
  UPDATE AdjustmentDetail  
  SET export_required = 'E' -- "E"xported  
  FROM #tmp_invoice_code_ax AS tic  
  WHERE AdjustmentDetail.invoice_id = tic.invoice_id  
   AND tic.revision_id > 1 -- can't be any adjustments for rev = 1  
   AND AdjustmentDetail.export_required = 'W' -- anything "W"aiting was just exported  
  
  SELECT @error_value = @@ERROR  
  
  IF @error_value <> 0  
  BEGIN  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error updating AdjustmentDetail for export_required.'  
  
   GOTO END_OF_PROC  
  END  
  
  -- JDB 1/16/14 Changed to retrieve invoice numbers from #tmp_invoice_code instead of #invhdr  
  -- return the invoice_code range of invoices that were just exported (we know the numbers  
  -- were created in sequential order and all records in this temp table have been processed)  
  -- NOTE: This range doesn't do anybody any good when the user is exporting multiple adjusted  
  -- invoices. Perhaps sometime in the future this should be removed as it is not always  
  -- accurate.  
  SELECT @as_invoicecode_from = MIN(invoice_code)  
  FROM #tmp_invoice_code_ax tic  
  
  SELECT @as_invoicecode_to = MAX(invoice_code)  
  FROM #tmp_invoice_code_ax tic  
  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Exported invoice_code range: ' + IsNull(@as_invoicecode_from, '') + ' - ' + IsNull(@as_invoicecode_to, '')  
  
  --? Does anything else need to be done in the share database??  
  --?Audit Records??  
  -- calling routine should drop #InvoiceRecordsToExport  
  IF @ai_debug = 1  
   PRINT CONVERT(VARCHAR(30), GETDATE(), 14) + ' Procedure Complete.'  
    -----------------------------------------------------------------  
    -- Commit or Rollback changes here  
    -----------------------------------------------------------------  
 END  
END --IF @error_value <> 0 AND @invalid_gl_count = 0  
  
-- Anitha 07/10/2017 start - EQAI-44271 AX Invoice Export - Handle voided invoices  
--EQAI-44271 AX Invoice Export - Handle voided invoices  
IF @count_adjustments > 0  
 AND @invalid_gl_count = 0  
 AND @sync_invoice_ax = 1  
BEGIN  
 -- For the Adjustments, loop through and execute the sp_ExportInvoicesAdjustmentData procedure  
 -- in order to get the difference between this revision and the prior one.  
 DECLARE Adjustment_Cursor_2_AX CURSOR FAST_FORWARD  
 FOR  
 SELECT ax.invoice_id  
  ,ax.revision_id  
  ,ih.STATUS  
 FROM #tmp_invoice_code_ax AS ax  
 JOIN dbo.InvoiceHeader AS ih ON ax.invoice_id = ih.invoice_id  
  AND ax.revision_id = ih.revision_id  
 WHERE ax.revision_id > 1  
  
 OPEN Adjustment_Cursor_2_AX  
  
 -- prime the pump  
 FETCH NEXT  
 FROM Adjustment_Cursor_2_AX  
 INTO @invoice_id_adj  
  ,@revision_id_adj  
  ,@invoice_status  
  
 -- loop through all companies for this exporting session to get appropriate trx_ctrl_num loaded  
 WHILE @@FETCH_STATUS = 0  
 BEGIN  
  -- Execute sp_ExportInvoicesAdjustmentData to calculate differences between this revision and the prior one.  
  -- 1/8/2014 JDB - We moved this part of the cursor above, so we could validate the JDE GL accounts.  
  --EXEC sp_ExportInvoicesAdjustmentData @invoice_id_adj, @revision_id_adj, @ai_debug  
  --IF @ai_debug = 1 PRINT 'SELECT * FROM #tmp_invoice_code (after sp_ExportInvoicesAdjustmentData)'  
  --IF @ai_debug = 1 SELECT * FROM #tmp_invoice_code  
  --IF @ai_debug = 1 PRINT 'SELECT * FROM #InvoiceBillingDetail_AdjustmentData (after sp_ExportInvoicesAdjustmentData)'  
  --IF @ai_debug = 1 SELECT * FROM #InvoiceBillingDetail_AdjustmentData  
  -------------------------------------------------------------------------------------------------------  
  -- Populate JDEInvoicePayItem with one record per company/profit center (adjustments)  
  -------------------------------------------------------------------------------------------------------  
  IF @ai_debug = 1  
   PRINT 'Inserting into AXInvoiceGL (adjustments)'  
  
  INSERT dbo.AXInvoiceHeader (  
   invoice_id  
   ,revision_id  
   ,customer_id  
   ,ECOLINVOICEID  
   ,ORDERACCOUNT  
   ,CURRENCYCODE  
   ,INVOICEDATE  
   ,DUEDATE  
   ,DEFAULTDIMENSION  
   ,POSTINGPROFILE  
   ,INVOICEACCOUNT  
   ,PURCHORDERFORMNUM  
   ,CUSTOMERREF  
   ,PAYMENT  
   ,PAYMMODE  
   ,CASHDISCCODE  
   ,ECOLADJUSTMENTID  
   ,ECOLORIGINALINVOICEID  
   ,added_by  
   ,date_added  
   ,modified_by  
   ,date_modified  
   )  
  SELECT ih.invoice_id  
   ,ih.revision_id  
   ,ih.customer_id AS customer_id  
   ,CASE   
    WHEN ih.revision_id > 1  
     THEN (ih.invoice_code + @doc_type_ax + Right('00' + Convert(VARCHAR(20), ih.revision_id), 2))  
    ELSE (ih.invoice_code)  
    END AS ECOLINVOICEID  
   ,c.ax_customer_id AS ORDERACCOUNT  
   ,ih.currency_code AS CURRENCYCODE --, 'USD' AS CURRENCYCODE  
   ,ih.invoice_date AS INVOICEDATE  
   ,ih.due_date AS DUEDATE  
   ,'' AS DEFAULTDIMENSION  
   ,'Default' AS POSTINGPROFILE  
   ,c.ax_invoice_customer_id AS INVOICEACCOUNT  
   --, CASE WHEN ih.customer_po = '' THEN 'None'  
   -- ELSE ih.customer_po END AS PURCHORDERFORMNUM  
   ,(  
    SELECT CASE   
      WHEN (  
        SELECT count(DISTINCT isnull(nullif(purchase_order, ''), 'None'))  
        FROM InvoiceDetail  
        WHERE invoice_id = @invoice_id_adj  
         AND revision_id = @revision_id_adj  
        ) > 1  
       THEN 'Multiple'  
      ELSE (  
        SELECT DISTINCT isnull(nullif(purchase_order, ''), 'None')  
        FROM InvoiceDetail  
        WHERE invoice_id = @invoice_id_adj  
         AND revision_id = @revision_id_adj  
        )  
      END  
    ) AS PURCHORDERFORMNUM  
   ,ih.customer_release AS CUSTOMERREF  
   ,CASE   
    WHEN cs.d365_payment_term IS NULL  
     THEN at.AX_payment_term_id   
    ELSE cs.d365_payment_term END AS PAYMENT  
   ,'CHK' AS PAYMMODE  
   ,at.AX_cash_discount_code AS CASHDISCCODE  
   --, (ih.invoice_code + @doc_type_ax + Convert(Varchar(20),ih.revision_id)) AS ECOLADJUSTMENTID  
   ,CASE   
    WHEN ih.revision_id > 1  
     THEN (ih.invoice_code + @doc_type_ax + Right('00' + Convert(VARCHAR(20), ih.revision_id), 2))  
    ELSE (ih.invoice_code)  
    END AS ECOLADJUSTMENTID  
   ,CASE   
    WHEN ih.revision_id = 2  
     THEN (ih.invoice_code)  
    WHEN ih.revision_id > 2  
     THEN (ih.invoice_code + @doc_type_ax + Right('00' + Convert(VARCHAR(20), ih.revision_id - 1), 2))  
    END AS ECOLORIGINALINVOICEID  
   ,@as_userid AS added_by  
   ,@date_today AS date_added  
   ,@as_userid AS modified_by  
   ,@date_today AS date_modified  
  FROM dbo.InvoiceHeader AS ih  
  JOIN dbo.Customer AS c ON c.customer_id = ih.customer_id  
  LEFT OUTER JOIN ECOL_D365Integration.dbo.CustomerSync cs ON cs.d365_accountnum = c.ax_customer_id  
  LEFT OUTER JOIN dbo.ARTerms AS at ON at.terms_code = ih.terms_code  
  WHERE ih.invoice_id = @invoice_id_adj  
   AND ih.revision_id = @revision_id_adj  
  
  SELECT @error_value = @@ERROR  
   ,@ax_header_uid = @@IDENTITY  
  
  IF @error_value <> 0  
  BEGIN  
   CLOSE Adjustment_Cursor_2_AX  
  
   DEALLOCATE Adjustment_Cursor_2_AX  
  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error inserting into AXInvoiceHeader (adjustments).'  
  
   GOTO END_OF_PROC  
  END  
  
  IF @invoice_status = 'V'  
  BEGIN  
   INSERT dbo.AXInvoiceLine (  
    axinvoiceheader_uid  
    ,company_id  
    ,profit_ctr_id  
    ,CUSTINVOICELINE_LINENUM  
    ,CUSTINVOICELINE_DESCRIPTION  
    ,CUSTINVOICELINE_QUANTITY  
    ,CUSTINVOICELINE_UNITPRICE  
    ,CUSTINVOICELINE_AMOUNTCUR  
    ,CUSTINVOICELINE_PROJID  
    ,CUSTINVOICELINE_ECOLSOURCESYSTEM  
    ,CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE  
    ,CUSTINVOICELINE_ECOLSOURCECOMPANY  
    ,CUSTINVOICELINE_ECOLSOURCEPROFITCENTER  
    ,CUSTINVOICELINE_ECOLSOURCETRANSACTIONID  
    ,CUSTINVOICELINE_ECOLMANIFEST  
    ,CUSTINVOICELINE_ECOLWASTESTREAM  
    ,CUSTINVOICELINE_LEDGERDIMENSION  
    ,CUSTINVOICELINE_PROJCATEGORYID  
    ,ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE  
    ,ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION  
    ,ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT  
    ,added_by  
    ,date_added  
    ,modified_by  
    ,date_modified  
    ,currency_code  
    )  
   SELECT @ax_header_uid  
    ,ibd.company_id  
    ,ibd.profit_ctr_id  
    ,DENSE_RANK() OVER (  
     ORDER BY ibd.company_id  
      ,ibd.profit_ctr_id  
      ,ibd.trans_source  
      ,ibd.receipt_id  
      ,ibd.line_id  
      ,ibd.price_id  
     )  
    ,COALESCE(id.line_desc_1, (  
      SELECT id3.line_desc_1  
      FROM dbo.InvoiceDetail AS id3 --WITH (INDEX (idx_receipt_id))  
      WHERE ibd.invoice_id = id3.invoice_id  
       AND id3.revision_id = 1  
       AND ibd.receipt_id = id3.receipt_id  
       AND ibd.line_id = id3.line_id  
       AND ibd.price_id = id3.price_id  
       AND ibd.company_id = id3.company_id  
       AND ibd.profit_ctr_id = id3.profit_ctr_id  
       AND id3.location_code <> 'EQAI-TAX'  
       AND id3.location_code <> 'EQAI-SR'  
      )) AS CUSTINVOICELINE_DESCRIPTION  
    ,id.qty_ordered AS CUSTINVOICELINE_QUANTITY  
    ,CUSTINVOICELINE_UNITPRICE = (  
     SELECT SUM(id2.unit_price)  
     FROM dbo.InvoiceDetail AS id2 --WITH (INDEX (idx_receipt_id))  
     WHERE ibd.invoice_id = id2.invoice_id  
      AND ibd.revision_id = id2.revision_id  
      AND ibd.company_id = id2.company_id  
      AND ibd.profit_ctr_id = id2.profit_ctr_id  
      AND ibd.trans_source = id2.trans_source  
      AND ibd.receipt_id = id2.receipt_id  
      AND ibd.line_id = id2.line_id  
      AND ibd.price_id = id2.price_id  
     )  
    ,0 AS CUSTINVOICELINE_AMOUNTCUR  
    ,dbo.fn_get_workorder_AX_dim5_project(ibd.company_id, ibd.profit_ctr_id, ibd.receipt_id) AS CUSTINVOICELINE_PROJID  
    ,'EQAI' AS CUSTINVOICELINE_ECOLSOURCESYSTEM  
    ,CASE ibd.trans_source  
     WHEN 'R'  
      THEN 'Receipt'  
     WHEN 'W'  
      THEN 'Work Order'  
     WHEN 'O'  
      THEN 'Retail Order'  
     ELSE ''  
     END AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE  
    ,ibd.company_id AS CUSTINVOICELINE_ECOLSOURCECOMPANY  
    ,ibd.profit_ctr_id AS CUSTINVOICELINE_ECOLSOURCEPROFITCENTER  
    ,ibd.receipt_id AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONID  
    ,CASE ibd.trans_source  
     WHEN 'R'  
      THEN b.manifest  
     WHEN 'W'  
      THEN dbo.fn_get_workorder_min_manifest(ibd.receipt_id, ibd.company_id, ibd.profit_ctr_id)  
     ELSE ''  
     END AS CUSTINVOICELINE_ECOLMANIFEST  
    ,id.approval_code AS CUSTINVOICELINE_ECOLWASTESTREAM  
    ,99999 AS CUSTINVOICELINE_LEDGERDIMENSION  
    ,CASE   
     WHEN dbo.fn_get_workorder_AX_dim5_project(ibd.company_id, ibd.profit_ctr_id, ibd.receipt_id) <> ''  
      THEN 'FTI IMPORT'  
     ELSE ''  
     END AS CUSTINVOICELINE_PROJCATEGORYID  
    ,ih.applied_date AS ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE  
    ,CASE len(rtrim(ibd.AX_Dimension_5_Part_2))  
     WHEN 0  
      THEN ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1  
     ELSE ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1 + '.' + ibd.AX_Dimension_5_Part_2  
     END AS ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION  
    ,0 AS ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT  
    ,@as_userid AS added_by  
    ,@date_today AS date_added  
    ,@as_userid AS modified_by  
    ,@date_today AS date_modified  
    ,ih.currency_code  
   FROM dbo.InvoiceHeader AS ih  
   JOIN dbo.InvoiceBillingDetail AS ibd --WITH (INDEX (idx_invoice_revision))  
    ON ibd.invoice_id = ih.invoice_id  
    AND ibd.revision_id = (@revision_id_adj - 1) --ih.revision_id   
   LEFT OUTER JOIN dbo.InvoiceDetail AS id --WITH (INDEX (idx_receipt_id))  
    ON ibd.invoice_id = id.invoice_id  
    AND ibd.revision_id = (@revision_id_adj - 1) -- id.revision_id  
    AND ibd.receipt_id = id.receipt_id  
    AND ibd.line_id = id.line_id  
    AND id.price_id = ibd.price_id  
    AND ibd.company_id = id.company_id  
    AND ibd.profit_ctr_id = id.profit_ctr_id  
    AND id.location_code <> 'EQAI-TAX'  
    AND id.location_code <> 'EQAI-SR'  
   JOIN dbo.Customer AS c ON c.customer_id = ih.customer_id  
   LEFT OUTER JOIN dbo.Billing AS b --WITH (INDEX (idx_Billing))  
    ON id.company_id = b.company_id  
    AND id.profit_ctr_id = b.profit_ctr_id  
    AND id.receipt_id = b.receipt_id  
    AND id.line_id = b.line_id  
    AND id.price_id = b.price_id  
    AND b.trans_source = 'R'  
   LEFT OUTER JOIN dbo.ARTerms AS at ON at.terms_code = ih.terms_code  
   WHERE ih.invoice_id = @invoice_id_adj  
    AND ih.revision_id = (@revision_id_adj)  
   GROUP BY ih.invoice_code  
    ,ih.invoice_id  
    ,ih.revision_id  
    ,ibd.revision_id  
    ,ibd.invoice_id  
    ,ih.invoice_date  
    ,ibd.company_id  
    ,ibd.profit_ctr_id  
    ,ih.customer_id  
    ,c.ax_customer_id  
    ,c.ax_invoice_customer_id  
    ,ibd.trans_source  
    ,ibd.receipt_id  
    ,b.manifest  
    ,ih.applied_date  
    ,ih.due_date  
    ,ih.customer_po  
    ,ih.customer_release  
    ,ih.currency_code  
    ,at.AX_payment_term_id  
    ,ibd.line_id  
    ,at.AX_cash_discount_code  
    ,id.line_desc_1  
    ,ibd.receipt_id  
    ,ibd.line_id  
    ,ibd.company_id  
    ,ibd.profit_ctr_id  
    ,id.qty_ordered  
    ,id.approval_code  
    ,id.unit_price  
    -- ,ibd3.ax_account  
    ,ibd.AX_MainAccount  
    ,ibd.AX_Dimension_1  
    ,ibd.AX_Dimension_2  
    ,ibd.AX_Dimension_3  
    ,ibd.AX_Dimension_4  
    ,ibd.AX_Dimension_6  
    ,ibd.AX_Dimension_5_Part_1  
    ,ibd.AX_Dimension_5_Part_2  
    ,ibd.price_id  
   -- ORDER BY ih.customer_id --NOTE: commented out for performance  
    -- ,ibd.company_id  
    -- ,ibd.profit_ctr_id  
    -- ,ibd.trans_source  
    -- ,ibd.receipt_id  
  
   SELECT @error_value = @@ERROR  
  END  
  ELSE  
  BEGIN  
   INSERT dbo.AXInvoiceLine (  
    axinvoiceheader_uid  
    ,company_id  
    ,profit_ctr_id  
    ,CUSTINVOICELINE_LINENUM  
    ,CUSTINVOICELINE_DESCRIPTION  
    ,CUSTINVOICELINE_QUANTITY  
    ,CUSTINVOICELINE_UNITPRICE  
    ,CUSTINVOICELINE_AMOUNTCUR  
    ,CUSTINVOICELINE_PROJID  
    ,CUSTINVOICELINE_ECOLSOURCESYSTEM  
    ,CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE  
    ,CUSTINVOICELINE_ECOLSOURCECOMPANY  
    ,CUSTINVOICELINE_ECOLSOURCEPROFITCENTER  
    ,CUSTINVOICELINE_ECOLSOURCETRANSACTIONID  
    ,CUSTINVOICELINE_ECOLMANIFEST  
    ,CUSTINVOICELINE_ECOLWASTESTREAM  
    ,CUSTINVOICELINE_LEDGERDIMENSION  
    ,CUSTINVOICELINE_PROJCATEGORYID  
    ,ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE  
    ,ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION  
    ,ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT  
    ,added_by  
    ,date_added  
    ,modified_by  
    ,date_modified  
    ,currency_code  
    )  
   SELECT @ax_header_uid  
    ,ibd.company_id  
    ,ibd.profit_ctr_id  
    ,DENSE_RANK() OVER (  
     ORDER BY ibd.company_id  
      ,ibd.profit_ctr_id  
      ,ibd.trans_source  
      ,ibd.receipt_id  
      ,ibd.line_id  
      ,ibd.price_id  
     )  
    ,COALESCE(id.line_desc_1, (  
      SELECT id3.line_desc_1  
      FROM dbo.InvoiceDetail AS id3  
      WHERE ibd.invoice_id = id3.invoice_id  
       AND id3.revision_id = 1  
       AND ibd.receipt_id = id3.receipt_id  
       AND ibd.line_id = id3.line_id  
       AND ibd.price_id = id3.price_id  
       AND ibd.company_id = id3.company_id  
       AND ibd.profit_ctr_id = id3.profit_ctr_id  
       AND id3.location_code <> 'EQAI-TAX'  
       AND id3.location_code <> 'EQAI-SR'  
      )) AS CUSTINVOICELINE_DESCRIPTION  
    ,id.qty_ordered AS CUSTINVOICELINE_QUANTITY  
    ,CUSTINVOICELINE_UNITPRICE = (  
     SELECT SUM(id2.unit_price)  
     FROM dbo.InvoiceDetail AS id2 --WITH (INDEX (idx_receipt_id))  
     WHERE ibd.invoice_id = id2.invoice_id  
      AND ibd.revision_id = id2.revision_id  
      AND ibd.company_id = id2.company_id  
      AND ibd.profit_ctr_id = id2.profit_ctr_id  
      AND ibd.trans_source = id2.trans_source  
      AND ibd.receipt_id = id2.receipt_id  
      AND ibd.line_id = id2.line_id  
      AND ibd.price_id = id2.price_id  
     )  
    ,CUSTINVOICELINE_AMOUNTCUR = (  
     SELECT SUM(ibd1.extended_amt)  
     FROM dbo.InvoiceBillingDetail AS ibd1 --WITH (INDEX (idx_invoice_revision))  
     WHERE ibd.invoice_id = ibd1.invoice_id  
      AND ibd.revision_id = ibd1.revision_id  
      AND ibd.trans_source = ibd1.trans_source  
      AND ibd.receipt_id = ibd1.receipt_id  
      AND ibd.line_id = ibd1.line_id  
      AND ibd.price_id = ibd1.price_id  
      AND ibd.company_id = ibd1.company_id  
      AND ibd.profit_ctr_id = ibd1.profit_ctr_id  
     )  
    ,dbo.fn_get_workorder_AX_dim5_project(ibd.company_id, ibd.profit_ctr_id, ibd.receipt_id) AS CUSTINVOICELINE_PROJID  
    ,'EQAI' AS CUSTINVOICELINE_ECOLSOURCESYSTEM  
    ,CASE ibd.trans_source  
     WHEN 'R'  
      THEN 'Receipt'  
     WHEN 'W'  
      THEN 'Work Order'  
     WHEN 'O'  
      THEN 'Retail Order'  
     ELSE ''  
     END AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONTYPE  
    ,ibd.company_id AS CUSTINVOICELINE_ECOLSOURCECOMPANY  
    ,ibd.profit_ctr_id AS CUSTINVOICELINE_ECOLSOURCEPROFITCENTER  
    ,ibd.receipt_id AS CUSTINVOICELINE_ECOLSOURCETRANSACTIONID  
    ,CASE ibd.trans_source  
     WHEN 'R'  
      THEN b.manifest  
     WHEN 'W'  
      THEN dbo.fn_get_workorder_min_manifest(ibd.receipt_id, ibd.company_id, ibd.profit_ctr_id)  
     ELSE ''  
     END AS CUSTINVOICELINE_ECOLMANIFEST  
    ,id.approval_code AS CUSTINVOICELINE_ECOLWASTESTREAM  
    ,99999 AS CUSTINVOICELINE_LEDGERDIMENSION  
    ,CASE   
     WHEN dbo.fn_get_workorder_AX_dim5_project(ibd.company_id, ibd.profit_ctr_id, ibd.receipt_id) <> ''  
      THEN 'FTI IMPORT'  
     ELSE ''  
     END AS CUSTINVOICELINE_PROJCATEGORYID  
    ,ih.applied_date AS ACCOUNTINGDISTRIBUTION_ACCOUNTINGDATE  
    ,CASE len(rtrim(ibd.AX_Dimension_5_Part_2))  
     WHEN 0  
      THEN ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1  
     ELSE ibd.AX_MainAccount + '-' + ibd.AX_Dimension_1 + '-' + ibd.AX_Dimension_2 + '-' + ibd.AX_Dimension_3 + '-' + ibd.AX_Dimension_4 + '-' + ibd.AX_Dimension_6 + '-' + ibd.AX_Dimension_5_Part_1 + '.' + ibd.AX_Dimension_5_Part_2  
     END AS ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION  
    ,SUM(ibd.extended_amt) AS ACCOUNTINGDISTRIBUTION_TRANSACTIONCURRENCYAMOUNT  
    ,@as_userid AS added_by  
    ,@date_today AS date_added  
    ,@as_userid AS modified_by  
    ,@date_today AS date_modified  
    ,ih.currency_code  
   FROM dbo.InvoiceHeader AS ih  
   JOIN dbo.InvoiceBillingDetail AS ibd --WITH (INDEX (idx_invoice_revision))  
    ON ibd.invoice_id = ih.invoice_id  
    AND ibd.revision_id = ih.revision_id  
   -- JOIN #InvoiceBillingDetail_AdjustmentData ibd3 ON ibd3.invoice_id = ih.invoice_id  
   --AND ibd3.revision_id = ih.revision_id  
   LEFT OUTER JOIN dbo.InvoiceDetail AS id --WITH (INDEX (idx_receipt_id))  
    ON ibd.invoice_id = id.invoice_id  
    AND ibd.revision_id = id.revision_id  
    AND ibd.receipt_id = id.receipt_id  
    AND ibd.line_id = id.line_id  
    AND id.price_id = ibd.price_id  
    AND ibd.company_id = id.company_id  
    AND ibd.profit_ctr_id = id.profit_ctr_id  
    AND id.location_code <> 'EQAI-TAX'  
    AND id.location_code <> 'EQAI-SR'  
   JOIN dbo.Customer AS c ON c.customer_id = ih.customer_id  
   LEFT OUTER JOIN Billing b --WITH (INDEX (idx_Billing))  
    ON id.company_id = b.company_id  
    AND id.profit_ctr_id = b.profit_ctr_id  
    AND id.receipt_id = b.receipt_id  
    AND id.line_id = b.line_id  
    AND id.price_id = b.price_id  
    AND b.trans_source = 'R'  
   LEFT OUTER JOIN dbo.ARTerms AS at ON at.terms_code = ih.terms_code  
   WHERE ih.invoice_id = @invoice_id_adj  
    AND ih.revision_id = @revision_id_adj  
   GROUP BY ih.invoice_code  
    ,ih.invoice_id  
    ,ih.revision_id  
    ,ibd.revision_id  
    ,ibd.invoice_id  
    ,ih.invoice_date  
    ,ibd.company_id  
    ,ibd.profit_ctr_id  
    ,ih.customer_id  
    ,c.ax_customer_id  
    ,c.ax_invoice_customer_id  
    ,ibd.trans_source  
    ,ibd.receipt_id  
    ,b.manifest  
    ,ih.applied_date  
    ,ih.due_date  
    ,ih.customer_po  
    ,ih.customer_release  
    ,ih.currency_code  
    ,at.AX_payment_term_id  
    ,ibd.line_id  
    ,at.AX_cash_discount_code  
    ,id.line_desc_1  
    ,ibd.receipt_id  
    ,ibd.line_id  
    ,ibd.company_id  
    ,ibd.profit_ctr_id  
    ,id.qty_ordered  
    ,id.approval_code  
    ,id.unit_price  
    -- ,ibd3.ax_account  
    ,ibd.AX_MainAccount  
    ,ibd.AX_Dimension_1  
    ,ibd.AX_Dimension_2  
    ,ibd.AX_Dimension_3  
    ,ibd.AX_Dimension_4  
    ,ibd.AX_Dimension_6  
    ,ibd.AX_Dimension_5_Part_1  
    ,ibd.AX_Dimension_5_Part_2  
    ,ibd.price_id  
   -- ORDER BY ih.customer_id --NOTE: commented out for performance  
    -- ,ibd.company_id  
    -- ,ibd.profit_ctr_id  
    -- ,ibd.trans_source  
    -- ,ibd.receipt_id  
  
   SELECT @error_value = @@ERROR  
  END  
  
  IF @error_value <> 0  
  BEGIN  
   CLOSE Adjustment_Cursor_2_AX  
  
   DEALLOCATE Adjustment_Cursor_2_AX  
  
   -- Set message for RAISEERROR and go to the end  
   SET @error_msg = 'Error inserting into AXInvoiceLine (adjustments).'  
  
   GOTO END_OF_PROC  
  END  
  
  -- get next adjustment  
  FETCH NEXT  
  FROM Adjustment_Cursor_2_AX  
  INTO @invoice_id_adj  
   ,@revision_id_adj  
   ,@invoice_status  
   -- WHILE @@FETCH_STATUS = 0  
 END  
  
 CLOSE Adjustment_Cursor_2_AX  
  
 DEALLOCATE Adjustment_Cursor_2_AX  
  
 DROP TABLE #InvoiceBillingDetail_AdjustmentData  
END -- IF @count_adjustments >  
  
-- Anitha 07/10/2017 end  
------------  
END_OF_PROC:  
  
------------  
IF @error_value <> 0  
 OR @invalid_gl_count <> 0  
BEGIN  
 -- Rollback the transaction  
 --ROLLBACK TRANSACTION ExportInvoices  
 ROLLBACK TRANSACTION TRAN1  
  
 -- Raise an error and return  
 RAISERROR (  
   @error_msg  
   ,16  
   ,1  
   )  
END  
ELSE  
BEGIN  
 --COMMIT TRANSACTION ExportInvoices  
 COMMIT TRANSACTION TRAN1  
END  
  
END_ALL:  
  
RETURN ISNULL(@error_value, 0)  

GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ExportInvoices] TO [EQAI]

GO