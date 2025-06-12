
CREATE PROCEDURE sp_biennial_validate_form_code
	@biennial_id int
AS

/*
	Usage: sp_biennial_validate_form_code 116	
	
2014-01-09	JPB		Added additional validation to cover outbound receipts. Previously this only handled inbound	
	
*/

BEGIN

	declare @newline varchar(5) = char(13)+char(10)
		
	/* Get missing epa_form_codes */
	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
	 SELECT 'Empty epa_form_code for profile_id ' + cast(p.profile_id as varchar(20))
	 , src.*
		FROM EQ_Extract..BiennialReportSourceData src
		left outer join ProfileQuoteApproval pqa ON src.approval_code = pqa.approval_code
			and src.company_id = pqa.company_id
			and src.profit_ctr_id = pqa.profit_ctr_id
			and src.biennial_id = @biennial_id
		left outer join Profile p ON pqa.profile_id = p.profile_id
	WHERE src.biennial_id = @biennial_id
	AND ISNULL(p.epa_form_code,'') = ''
	UNION
	 SELECT 'Empty TSDFApproval.epa_form_code for outbound TSDF approval: ' + ISNULL(cast(src.approval_code as varchar(20)), '(empty)')
	 , src.*
		FROM EQ_Extract..BiennialReportSourceData src
		LEFT JOIN tsdfapproval tsdfapproval ON src.approval_code = tsdfapproval.tsdf_approval_code
		AND src.company_id = tsdfapproval.company_id
		and src.profit_ctr_id = tsdfapproval.profit_ctr_id
	WHERE src.biennial_id = @biennial_id
	AND ISNULL(src.epa_form_code, '') = ''
	and src.trans_mode = 'O'
	 		
	
END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_form_code] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_form_code] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_form_code] TO [EQAI]
    AS [dbo];

