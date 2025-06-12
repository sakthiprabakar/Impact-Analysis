CREATE PROCEDURE sp_web_scan_document_names (
	@company_id			int,
	@profit_ctr_id		int,
	@document_source	varchar(30),
	@document_id		int,
	@document_key		varchar(15) = ''
)
AS
BEGIN
/* ======================================================
 Description: 
 Parameters :
 Returns    : names and number of pages of all documents related to the input company/profit_center/source/id combination.
 Requires   : Databases: plt_image Servers: (ntsql1dev, ntsql1test, ntsql1)

 Modified    Author            Notes
 ----------  ----------------  -----------------------
 06/19/2006  Jonathan Broome   Initial Development
 06/19/2006  Chris Allen       re; GID 4337
                               - joins on and returns ScanDocumentType.document_name_label
                               - formatted header and section
                               - Note: This particular assignment dealt w/ Receipt ONLY section
 09/19/2008	Jonathan Broome	GEM:8914
				- Added type_id as a returned field from the Approval and Workorder queries
				- It was already returned in the Receipt query via the 6/19/08 change.
				- file_type2 on the Receipt query wasn't used in code. Removed it.
				- Rewrote Where clauses so most specific clause is first (faster that way)
				- Converted the company_id and profit_ctr_id clauses in the Approval version
				  so they don't use coalesce anymore, because it's possible for there to be a scan record
				  for a profile where profit_ctr_id is null, and coalesce (@profit_ctr_id, scan.profit_ctr_id)
				  won't find those at all.  Oy, the things you learn through testing.

	Testing
		sp_web_scan_document_names  2, 21, 'receipt', 285720
		sp_web_scan_document_names null, null, 'approval', 238340
		
		... these next statements test the next logical step when showing images,
		... just to help make sure the data returned from the tests above work.
		sp_web_scan_document_retrieve NULL, NULL, 'approval', 238340, null, 'DOC1719654_MSDS 266893.pdf'
		sp_web_scan_document_retrieve 2, 21, 'receipt', 285720, null, 'MI8888881', 1
		sp_web_scan_document_retrieve 2, 21, 'receipt', 285720, null, 'MI8888881', 3

 04/10/2009 Rich Grenwick	Added workorder_and_receipts document source.  
		This will retrieve BOTH work order and receipt documents associated to that work order

 05/22/2009 Rich Grenwick	Fixing duplicate document issue in GEM-12611
		Removed image_id (not used), made the result sets return DISTINCT records
		Made procedure use document_type rather than document_name_label
		
 03/02/2010 Jonathan Broome Added Merchandise document source
		This will retrieve merchandise documents associated with input merchandise_id
		(company_id, profit_ctr_id not required... or wanted)
		
====================================================== */

  ------------------------------------------------------
  -- Approvals ONLY
  ------------------------------------------------------
	if @document_source = 'approval'
		SELECT DISTINCT
			scan.document_name, COUNT(scan.image_id) AS pages, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id,
			@company_id as company_id,
			@profit_ctr_id as profit_ctr_id
		FROM scan 
			INNER JOIN ScanDocumentType AS SDT ON Scan.type_id = SDT.type_id      
		WHERE scan.profile_id = @document_id
			AND ((@company_id is not null AND scan.company_id = @company_id) OR (@company_id is null))
			AND ((@profit_ctr_id is not null AND scan.profit_ctr_id = @profit_ctr_id) OR (@profit_ctr_id is null))
			AND scan.document_source = 'approval'
			AND scan.view_on_web = 'T'
			AND scan.status = 'A'
		GROUP BY scan.document_name, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id
		ORDER BY scan.document_name
  ------------------------------------------------------

			
  ------------------------------------------------------
  -- Receipts ONLY
  ------------------------------------------------------
	IF @document_source = 'receipt'
		SELECT DISTINCT 
			scan.document_name, COUNT(scan.image_id) AS pages, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id,
			@company_id as company_id,
			@profit_ctr_id as profit_ctr_id
		FROM scan 	
			INNER JOIN ScanDocumentType AS SDT ON Scan.type_id = SDT.type_id      
		WHERE scan.receipt_id = @document_id
			AND scan.company_id = @company_id
			AND scan.profit_ctr_id = @profit_ctr_id
			AND scan.document_source = 'receipt'
			AND scan.view_on_web = 'T'
			AND scan.status = 'A'
		GROUP BY scan.document_name, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id
		ORDER BY scan.document_name
  ------------------------------------------------------
			
  ------------------------------------------------------
  -- Workorders ONLY
  ------------------------------------------------------
	IF @document_source = 'workorder'
		SELECT DISTINCT 
			scan.document_name, COUNT(scan.image_id) AS pages, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id,
			@company_id as company_id,
			@profit_ctr_id as profit_ctr_id
		FROM scan 
			INNER JOIN ScanDocumentType AS SDT ON Scan.type_id = SDT.type_id      
		WHERE scan.workorder_id = @document_id
			AND scan.company_id = @company_id
			AND scan.profit_ctr_id = @profit_ctr_id
			AND scan.document_source = 'workorder'
			AND scan.view_on_web = 'T'
			AND scan.status = 'A'
		GROUP BY scan.document_name, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id
		ORDER BY scan.document_name
  ------------------------------------------------------

  ------------------------------------------------------
  -- Workorders and Receipts
  ------------------------------------------------------

IF @document_source = 'workorder_and_receipts'

		/* get the workorder images (based on company/profit center/workorder sent in) */
		SELECT DISTINCT 
			scan.document_name, 
			COUNT(scan.image_id) AS pages, 
			scan.file_type, 
			SDT.type_id, 
			SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id,
			@company_id as company_id,
			@profit_ctr_id as profit_ctr_id
		FROM scan 
			INNER JOIN ScanDocumentType AS SDT ON Scan.type_id = SDT.type_id     
		WHERE scan.workorder_id = @document_id
			AND scan.company_id = @company_id
			AND scan.profit_ctr_id = @profit_ctr_id
			AND scan.document_source = 'workorder'
			AND scan.view_on_web = 'T'
			AND scan.status = 'A'
		GROUP BY scan.document_name, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id

		UNION

		 /* get the receipts related to this work order */
		SELECT DISTINCT 
			scan.document_name, 
			COUNT(scan.image_id) AS pages, 
			scan.file_type, 
			SDT.type_id, 
			SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id,
			bll_small.company_id as company_id, -- company id for the RECEIPT, NOT the workorder
			bll_small.profit_ctr_id as profit_ctr_id -- profit ctr for the RECEIPT, NOT the work order
		FROM scan 
			INNER JOIN ScanDocumentType AS SDT ON Scan.type_id = SDT.type_id
			INNER JOIN (
				SELECT company_id, profit_ctr_id, receipt_id
				FROM BillingLinkLookup bll
				WHERE bll.source_id = @document_id
				AND bll.source_company_id = @company_id  
				AND bll.source_profit_ctr_id = @profit_ctr_id
			) bll_small ON bll_small.receipt_id = scan.receipt_id
							AND bll_small.company_id = scan.company_id
							AND bll_small.profit_ctr_id = scan.profit_ctr_id
		WHERE 
			scan.document_source = 'receipt'
			AND scan.view_on_web = 'T'
			AND scan.status = 'A'
			
		GROUP BY scan.document_name, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.receipt_id,
			scan.workorder_id,
			bll_small.company_id,
			bll_small.profit_ctr_id
		ORDER BY scan.document_name

  ------------------------------------------------------
  -- Merchandise
  ------------------------------------------------------
IF @document_source = 'merchandise'
		SELECT DISTINCT
			scan.document_name, 
			COUNT(scan.image_id) AS pages, 
			scan.file_type, 
			SDT.type_id, 
			SDT.document_type,
			scan.document_source,
			scan.merchandise_id,
			null,
			null as company_id,
			null as profit_ctr_id
		FROM scan 
			INNER JOIN ScanDocumentType AS SDT ON Scan.type_id = SDT.type_id      
		WHERE scan.merchandise_id = @document_id
			AND scan.document_source = 'merchandise'
			AND scan.view_on_web = 'T'
			AND scan.status = 'A'
		GROUP BY scan.document_name, scan.file_type, SDT.type_id, SDT.document_type,
			scan.document_source,
			scan.merchandise_id
		ORDER BY scan.document_name
		
END --CREATE PROCEDURE dbo.sp_web_scan_document_names

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_scan_document_names] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_scan_document_names] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_scan_document_names] TO [EQAI]
    AS [dbo];

