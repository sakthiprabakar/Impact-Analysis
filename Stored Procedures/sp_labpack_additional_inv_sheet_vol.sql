USE PLT_AI
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[sp_rpt_labpack_additional_inv_sheet_vol]
	@company_id			int
,	@profit_ctr_id		int
,	@approval_from		varchar(15)
,	@approval_to		varchar(15)
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object(s):	r_labpack_additional_inv_sheet_vol

08/22/2023 - Dipankar - DevOps 61282 - New Report SP Created

sp_rpt_labpack_additional_inv_sheet_vol  22, 0, 'I201873TPA CBO', 'I201873TPA CBO', 14074, 14074

****************************************************************************************/

BEGIN
	SELECT  p.profile_id, 
			p.customer_id, 
			p.generator_id, 
			p.approval_desc, 
			p.ap_start_date, 
			p.ap_expiration_date, 
			p.modified_by, 
			p.date_modified, 
			pqa.company_id, 
			pqa.profit_ctr_id, 
			pqa.approval_code, 
			pqa.status, 
			p.inactive_flag,
			p.wastetype_id, 
			wt.category, 
			wt.description,
			CAST(NULL AS VARCHAR(8)) AS territory_code,
			CAST(NULL AS DATETIME) AS 'Date Last Document Scanned',
			(SELECT MAX(receipt_id) 
			FROM Receipt r (NOLOCK)
			WHERE r.profile_id	= p.profile_id 
			AND	r.company_id	= pqa.company_id 
			AND	r.profit_ctr_id = pqa.profit_ctr_id 
			AND r.approval_code = pqa.approval_code
			AND	r.trans_mode	= 'I' 
			AND	r.trans_type	= 'D' 
			AND	r.fingerpr_status NOT IN ('V', 'R')) AS 'Last Receipt ID',
			(SELECT MAX(tracking_id) 
			FROM   ProfileTracking 
			WHERE  profile_id = p.profile_id) AS 'Max Tracking Event',
			CAST(NULL AS INT) AS 'Last Receipt Line'
	INTO	#profile_list
	FROM	Profile p (NOLOCK)
	JOIN	ProfileQuoteApproval pqa (NOLOCK) ON	p.profile_id = pqa.profile_id
	JOIN	WasteType wt (NOLOCK) ON p.wastetype_id = wt.wastetype_id
	WHERE	p.labpack_flag = 'T' 
	AND		p.tracking_type = 'A' 
	AND		p.curr_status_code = 'A'
	AND     EXISTS (SELECT 1 
					FROM Receipt r (NOLOCK) 
	                WHERE r.profile_id	= p.profile_id 
					AND r.approval_code = pqa.approval_code
					AND	r.company_id	= pqa.company_id 
					AND	r.profit_ctr_id = pqa.profit_ctr_id 					
					AND	r.trans_mode	= 'I' 
					AND	r.trans_type	= 'D' 
					AND	r.fingerpr_status NOT IN ('V', 'R'))
	AND		(@company_id = 0 OR pqa.company_id = @company_id)	
	AND		(@company_id = 0 OR @profit_ctr_id = -1 OR pqa.profit_ctr_id = @profit_ctr_id)
	AND		p.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND		pqa.approval_code BETWEEN @approval_from AND @approval_to	

	SELECT r.receipt_date, r.receipt_id, r.line_id, r.approval_code, cbt.customer_billing_territory_code AS territory_code
	INTO #receipt
	FROM #profile_list p (NOLOCK)
	JOIN Receipt r (NOLOCK) ON r.receipt_id	= p.[Last Receipt ID]
	AND r.approval_code	= p.approval_code
	AND r.company_id	= p.company_id
	AND r.profit_ctr_id = p.profit_ctr_id
	JOIN CustomerBilling cb ON cb.customer_id = r.customer_id
	AND  cb.billing_project_id = r.billing_project_id
	AND  cb.status = 'A'
	JOIN CustomerBillingTerritory cbt ON cbT.customer_id = cb.customer_id
	AND  cbt.billing_project_id = r.billing_project_id
	JOIN BusinessSegment bs ON cbt.businesssegment_uid = bs.businesssegment_uid
	WHERE cbt.customer_billing_territory_primary_flag = 'T'
	AND bs.business_segment_code = 'ES'
	AND r.line_id = (SELECT MAX(line_id)
					 FROM	Receipt ri
					 WHERE	ri.receipt_id	 = r.receipt_id
					 AND	ri.approval_code = r.approval_code
					 AND	ri.company_id	 = r.company_id
					 AND	ri.profit_ctr_id = r.profit_ctr_id
					 AND	ri.trans_mode	 = 'I' 
					 AND	ri.trans_type	 = 'D' 
					 AND	ri.fingerpr_status NOT IN ('V', 'R'))

	UPDATE	#profile_list 
	SET		[Date Last Document Scanned] = (SELECT	MAX(date_added) 
											FROM	plt_image..Scan s (NOLOCK) 
											JOIN	plt_image..ScanDocumentType sdt (NOLOCK) ON s.type_id = sdt.type_id											
											WHERE	s.profile_id		= #profile_list.profile_id
											AND		sdt.scan_type		= 'approval'
											AND		sdt.document_type	= 'inventory'
											AND		s.date_added > (SELECT TOP 1 r.receipt_date
																	FROM #receipt r
																	WHERE r.receipt_id	= #profile_list.[Last Receipt ID]
																	AND r.approval_code	= #profile_list.approval_code)),
			[Last Receipt Line]			= (SELECT TOP 1 r.line_id
										   FROM #receipt r (NOLOCK) 
										   WHERE r.receipt_id    = #profile_list.[Last Receipt ID]
										   AND   r.approval_code = #profile_list.approval_code),
			territory_code				= (SELECT TOP 1 r.territory_code
										   FROM #receipt r (NOLOCK) 
										   WHERE r.receipt_id	 = #profile_list.[Last Receipt ID]
										   AND  r.approval_code  = #profile_list.approval_code)
			
	SELECT	p.approval_code AS 'Approval Code', 
	        p.profile_id AS 'Profile ID Number',
			p.[Date Last Document Scanned] AS 'Date Last Document Scanned',
			p.territory_code AS 'Territory',
			p.approval_desc AS 'Approval Description',
			pt2.tracking_status AS 'Last Tracking Status', 
			ISNULL(pt2.time_out, pt2.time_in) AS 'Date of Last Tracking Status', 
			pt2.eq_contact AS 'Last Tracking Contact',
			p.description AS 'Waste Type'
	FROM	#profile_list p
	LEFT OUTER JOIN ProfileTracking pt1 ON p.profile_id = pt1.profile_id
	AND		p.[Max Tracking Event] = pt1.tracking_id
	LEFT OUTER JOIN ProfileTracking pt2 ON p.profile_id = pt2.profile_id
	AND	   (p.[Max Tracking Event] - 1) = pt2.tracking_id
	WHERE  p.[Date Last Document Scanned] IS NOT NULL
	ORDER BY p.profile_id, p.approval_code

	DROP TABLE #profile_list
END
GO

GRANT EXECUTE ON sp_rpt_labpack_additional_inv_sheet_vol TO EQAI
GO