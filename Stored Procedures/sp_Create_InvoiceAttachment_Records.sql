CREATE PROCEDURE sp_Create_InvoiceAttachment_Records
			@as_userid varchar(30), 
			@as_dbtype varchar(4),
			@ai_debug int = 0 
AS
/***********************************************************************
This SP is called from EQAI w_invoice_processing.wf_GeneratePreviewInvoices.  It is called
to generate a records of scanned images that go with an invoice.  These records will be stored in 
the table InvoiceAttachment which will be used by invoice printing to produce the invoice attachment
PDF document.  wf_GeneratePreviewInvoices produces many invoices at a sitting making it impossible
to pass an unknown quantity of invoice and revision IDs to this procedure.  During the invoice 
creation process a temp table #InvoiceAttachDetails will be created and populated as an invoice 
detail record is created.  When all invoices have been created and are about to be committed to 
the database this stored procedure wil be called to generate InvoiceAttachment records for the 
invoice detail lines that have been stored in #InvoiceAttachDetails.

This sp is loaded to Plt_AI.

04/23/2007 WAC	Created
10/03/2007 WAC	Changed tables with EQAI prefix to EQ.  Added db_type to EQDatabase query.
10/08/2007 WAC	Instead of populating InvoiceAttachment directly with a unionized select this procedure 
		now creates and populates a temp table, which will be manipulated as appropriate then
		temp records will be inserted into InvoiceAttachment.  This speeds up the query due to 
		the fact that the scan_type table is not joined but is a sub-select in the where clause.
10/31/2007 WAC	Changed customer select to JOIN to ScanDocumentType instead of using a sub-query.
		The query now executes significantly faster.

To test:
CREATE TABLE #InvoiceAttachDetails ( invoice_id int, revision_id int, customer_id int, 
			trans_source varchar(1), company_id int, profit_ctr_id int, receipt_id int,
			generator_id int null, approval_code varchar(15) null, profile_id int )

INSERT INTO #InvoiceAttachDetails 
SELECT 
H.invoice_id, H.revision_id, H.customer_id, D.trans_source,
D.company_id, D.profit_ctr_id, D.receipt_id, D.generator_id, D.approval_code, B.profile_id
FROM invoiceheader H, invoicedetail D LEFT OUTER JOIN Billing B ON B.company_id = D.company_id
AND B.profit_ctr_id = D.profit_ctr_id AND B.trans_source = D.trans_source AND B.receipt_id = D.receipt_id
AND B.line_id = D.line_id AND B.price_id = D.price_id
WHERE H.invoice_id = D.invoice_id AND H.revision_id = D.revision_id AND
H.invoice_id = 364801 and H.revision_id = 1

EXEC sp_Create_InvoiceAttachment_Records @as_userid = 'Wayne_C', @as_dbtype = 'DEV', @ai_debug = 0
***********************************************************************/

CREATE TABLE #InvoiceAttach (
        invoice_id int Null,
        revision_id int Null,
        company_id int Null,
        profit_ctr_id int Null,
        trans_source varchar(1) Null,
        receipt_id int Null,
        manifest varchar(15) Null,
        approval_code varchar(15) Null,
        generator_id int Null,
        scan_type varchar(30) Null,
        document_type varchar(30) Null,
        document_name varchar(50) Null,
        file_type varchar(10) Null,
        image_id int Null,
	type_id int Null)

SET NOCOUNT ON

INSERT INTO #InvoiceAttach (
        invoice_id,
        revision_id,
        company_id,
        profit_ctr_id,
        trans_source,
        receipt_id,
        manifest,
        approval_code,
        generator_id,
        document_name,
        file_type,
        image_id,
	type_id )

-- receipt
		SELECT DISTINCT 
                        idtl.invoice_id,
                        idtl.revision_id,
                        s.company_id , 
                        s.profit_ctr_id, 
                        idtl.trans_source,
                        s.receipt_id, 
                        s.manifest, 
                        s.approval_code, 
                        s.generator_id,
                        s.document_name,
                        s.file_type,
                        s.image_id,
			s.type_id
		FROM #InvoiceAttachDetails idtl
               INNER JOIN Plt_Image..Scan s ON s.receipt_id = idtl.receipt_id
		  AND s.profit_ctr_id = idtl.profit_ctr_id
                  AND s.company_id = idtl.company_id
		WHERE idtl.trans_source = 'R'
		  AND s.invoice_print_flag = 'T'
		  AND s.status = 'A'
		  AND s.type_id IN ( SELECT sdt.type_id FROM Plt_Image..ScanDocumentType sdt 
					WHERE sdt.scan_type = 'receipt' )

	UNION
-- workorder
		SELECT DISTINCT 
                        idtl.invoice_id,
                        idtl.revision_id,
                        s.company_id , 
                        s.profit_ctr_id, 
                        idtl.trans_source,
                        s.workorder_id,
                        s.manifest, 
                        s.approval_code, 
                        s.generator_id,
                        s.document_name,
                        s.file_type,
                        s.image_id,
			s.type_id
		FROM #InvoiceAttachDetails idtl 
		INNER JOIN Plt_Image..Scan s ON s.workorder_id = idtl.receipt_id
                  AND s.company_id = idtl.company_id
                  AND s.profit_ctr_id = idtl.profit_ctr_id
		WHERE idtl.trans_source = 'W'
		  AND s.invoice_print_flag = 'T'
		  AND s.status = 'A'
		  AND s.type_id IN ( SELECT sdt.type_id FROM Plt_Image..ScanDocumentType sdt 
					WHERE sdt.scan_type = 'workorder' )

	UNION
-- customer
-- NOTE:  At the time of this writing JOINing ScanDocumentType caused SQL Server to create
--	  a better plan than using a sub-query like all other selects in this union.
		SELECT DISTINCT 
                        idtl.invoice_id,
                        idtl.revision_id,
                        s.company_id , 
                        s.profit_ctr_id, 
                        idtl.trans_source,
                        s.receipt_id, 
                        s.manifest, 
                        s.approval_code, 
                        s.generator_id,
                        s.document_name,
                        s.file_type,
                        s.image_id,
			s.type_id
		FROM #InvoiceAttachDetails idtl 
		INNER JOIN Plt_Image..Scan s ON s.customer_id = idtl.customer_id
		INNER JOIN Plt_Image..ScanDocumentType sdt ON sdt.type_id = s.type_id
		WHERE s.invoice_print_flag = 'T'
		  AND s.status = 'A'
		  AND sdt.scan_type = 'customer'
	UNION
-- generator
		SELECT DISTINCT 
                        idtl.invoice_id,
                        idtl.revision_id,
                        s.company_id , 
                        s.profit_ctr_id, 
                        idtl.trans_source,
                        s.receipt_id, 
                        s.manifest, 
                        s.approval_code, 
                        s.generator_id,
                        s.document_name,
                        s.file_type,
                        s.image_id,
			s.type_id
		FROM #InvoiceAttachDetails idtl 
		INNER JOIN Plt_Image..Scan s ON s.generator_id = idtl.generator_id
		WHERE s.invoice_print_flag = 'T'
		  AND s.status = 'A'
		  AND s.type_id IN ( SELECT sdt.type_id FROM Plt_Image..ScanDocumentType sdt 
					WHERE sdt.scan_type = 'generator' )
		
	UNION
-- approval 
		SELECT DISTINCT 
                        idtl.invoice_id,
                        idtl.revision_id,
                        s.company_id , 
                        s.profit_ctr_id, 
                        idtl.trans_source,
                        s.receipt_id, 
                        s.manifest, 
                        idtl.approval_code, 
                        s.generator_id,
                        s.document_name,
                        s.file_type,
                        s.image_id,
			s.type_id
		FROM #InvoiceAttachDetails idtl 
		INNER JOIN Plt_Image..Scan s ON s.profile_id = idtl.profile_id
		WHERE s.invoice_print_flag = 'T'
		  AND s.status = 'A'
		  AND s.type_id IN ( SELECT sdt.type_id FROM Plt_Image..ScanDocumentType sdt 
					WHERE sdt.scan_type = 'approval' )

		
-- Now update temp records with scan_type and document_type
UPDATE #InvoiceAttach
  SET  scan_type = sdt.scan_type,
	document_type = sdt.document_type
 FROM #InvoiceAttach ia
 JOIN Plt_Image..ScanDocumentType sdt ON sdt.type_id = ia.type_id

-- Now stuff these temp records into InvoiceAttachment
INSERT INTO InvoiceAttachment (
        invoice_id,
        revision_id,
        company_id,
        profit_ctr_id,
        trans_source,
        receipt_id,
        manifest,
        approval_code,
        generator_id,
        scan_type,
        document_type,
        document_name,
        file_type,
        image_id )
	SELECT DISTINCT 
	        invoice_id,
	        revision_id,
	        company_id,
	        profit_ctr_id,
	        trans_source,
	        receipt_id,
	        manifest,
	        approval_code,
	        generator_id,
	        scan_type,
	        document_type,
	        document_name,
	        file_type,
	        image_id
	 FROM #InvoiceAttach
	
--	Don't need the temp table any longer
DROP TABLE #InvoiceAttach


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Create_InvoiceAttachment_Records] TO [EQAI]
    AS [dbo];

