

CREATE Procedure sp_web_scan_document_retrieve (
	@company_id			int,
	@profit_ctr_id		int,
	@document_source	varchar(30),
	@document_id		int,
	@document_key		varchar(15),
	@document_name		varchar(50),
	@type_id int = -1 -- -1 means this field will not be included in the select filter; i.e., all type_id's will be returned
)
AS
BEGIN
/* ======================================================
 Description: 
 Parameters :
 Returns    : all scan fields for all documents related to the input company/profit_center/source/id combination.
 Requires   : Databases: plt_image Servers: (ntsql1dev, ntsql1test, ntsql1)

 Modified    Author            Notes
 ----------  ----------------  -----------------------
 06/19/2006  Jonathan Broome   Initial Development
 06/19/2006  Chris Allen       re; GID 4337
                               - accepts as parameter, and filters by, type_id
                               - formatted header and section
                               - Note: This particular assignment dealt w/ Receipt ONLY section
                               Testing
                                -- 349124, MI9035418 --should yield 1 image as of 08/05/08
                                -- 362460, MI9035480 --should yield 1 image as of 08/05/08
                                -- 432793, 000022450VES --should yield 2 images as of 08/05/08
                                -- 440153, 000084463JJK --should yield 2 images as of 08/05/08
                                -- 441167, 000001758MWI --should yield 3 images as of 08/05/08
                                -- 435062, 000125043VES --should yield 3 images as of 08/05/08
                                -- 438784, 000133110VES --should yield 3 images as of 08/05/08
                                -- 436918, 000255199JJK --should yield 4 images as of 08/05/08
                                -- 438333, 000255279JJK --should yield 4 images as of 08/05/08
                                -- 440143, 001601825FLE --should yield 6 images as of 08/05/08
                                -- 417836, 001730038JJK --should yield 8 images as of 08/05/08
                                --EXEC sp_web_scan_document_retrieve 2, 21, 'receipt', '436918', 'null', '000255199JJK'
                                --EXEC sp_web_scan_document_retrieve 2, 21, 'receipt', '436918', 'null', '000255199JJK', '-1'
                                --EXEC sp_web_scan_document_retrieve 2, 21, 'receipt', '436918', 'null', '000255199JJK', '0'
                                --EXEC sp_web_scan_document_retrieve 2, 21, 'receipt', '436918', 'null', '000255199JJK', '1'
                                --EXEC sp_web_scan_document_retrieve 2, 21, 'receipt', '436918', 'null', '000255199JJK', '29'
 09/18/2008	Jonathan Broome	GEM:  8914
			Rewrite: Placed most-specific where clause items first (faster that way)
			Added @type_id to where clauses, rewrote Receipt version to work without EXEC.
			Converted the company_id and profit_ctr_id clauses in the Approval version
			  so they don't use coalesce anymore, because it's possible for there to be a scan record
			  for a profile where profit_ctr_id is null, and coalesce (@profit_ctr_id, scan.profit_ctr_id)
			  won't find those at all.  Oy, the things you learn through testing.

                                
====================================================== */

  ------------------------------------------------------
  -- Approvals ONLY
  ------------------------------------------------------
	if @document_source = 'approval'
		SELECT s.*, sd.document_type, sd.document_name_label
		FROM scan s
		inner join scandocumenttype sd on s.type_id = sd.type_id
		WHERE s.profile_id = @document_id
			AND ((@company_id is not null AND s.company_id = @company_id) OR (@company_id is null))
			AND ((@profit_ctr_id is not null AND s.profit_ctr_id = @profit_ctr_id) OR (@profit_ctr_id is null))
			AND s.document_source = 'approval'
			AND s.document_name = @document_name
			AND s.view_on_web = 'T'
			AND s.status = 'A'
			AND ((@type_id <> -1 AND s.type_id = @type_id) OR (@type_id = -1))
		ORDER BY s.document_name, s.page_number
  ------------------------------------------------------
			

  ------------------------------------------------------
  -- Receipts ONLY
  ------------------------------------------------------
	IF @document_source = 'receipt'
		SELECT s.*, sd.document_type, sd.document_name_label
		FROM scan s
		inner join scandocumenttype sd on s.type_id = sd.type_id
		WHERE s.receipt_id = @document_id
			AND s.company_id = @company_id
			AND s.profit_ctr_id = @profit_ctr_id
			AND s.document_source = 'receipt'
			AND s.document_name = @document_name
			AND s.view_on_web = 'T'
			AND s.status = 'A'
			AND ((@type_id <> -1 AND s.type_id = @type_id) OR (@type_id = -1))
		ORDER BY s.document_name, s.page_number 
  ------------------------------------------------------


  ------------------------------------------------------
  -- Workorders ONLY
  ------------------------------------------------------
	if @document_source = 'workorder'
		SELECT s.*, sd.document_type, sd.document_name_label
		FROM scan s
		inner join scandocumenttype sd on s.type_id = sd.type_id
		WHERE s.workorder_id = @document_id
			AND s.company_id = @company_id
			AND s.profit_ctr_id = @profit_ctr_id
			AND s.document_source = 'workorder'
			AND s.document_name = @document_name
			AND s.view_on_web = 'T'
			AND s.status = 'A'
			AND ((@type_id <> -1 and s.type_id = @type_id) or (@type_id = -1))
		ORDER BY s.document_name, s.page_number
  ------------------------------------------------------


END --CREATE PROCEDURE dbo.sp_web_scan_document_retrieve


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_scan_document_retrieve] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_scan_document_retrieve] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_web_scan_document_retrieve] TO [EQAI]
    AS [dbo];

