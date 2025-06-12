
CREATE PROCEDURE sp_biennial_validate_management_codes
	@biennial_id int
AS

/*
	Usage: sp_biennial_validate_management_codes 116	
	
2014-01-09	JPB	Added additional validation for management codes on outbound receipts - previously only handled inbound
2014-02-20	JPB	Added the EPA set of acceptable codes so we can flag errors on invalid values.
	
*/
BEGIN

	declare @newline varchar(5) = char(13)+char(10)
	
	create table #valid (management_code varchar(4))
	insert #valid select row from dbo.fn_SplitXSVText(',', 1, 'H010,H020,H039,H050,H061,H040,H070,H081,H100,H110,H120,H121,H122,H129,H131,H132,H134,H135,H141')
															   	
	
	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
	 SELECT DISTINCT 'Invalid Treatment.management_code for treatment_id: ' + ISNULL(cast(src.treatment_id as varchar(20)), isnull(treatment.management_code, '(empty)'))
	 , src.*
		FROM EQ_Extract..BiennialReportSourceData src
		LEFT JOIN treatment treatment ON src.treatment_id = treatment.treatment_id
		AND ISNULL(treatment.management_code, '') = ''
		AND src.biennial_id = @biennial_id
	WHERE treatment.treatment_id = src.treatment_id
	AND src.biennial_id = @biennial_id
	AND ISNULL(treatment.management_code, '') NOT IN (select management_code from #valid)
	and trans_mode = 'I'
UNION
	 SELECT DISTINCT 'Invalid TSDFApproval.management_code for outbound TSDF approval: ' + ISNULL(cast(src.approval_code as varchar(20)), isnull(src.management_code, '(empty)'))
	 , src.*
		FROM EQ_Extract..BiennialReportSourceData src
		LEFT JOIN tsdfapproval tsdfapproval ON src.approval_code = tsdfapproval.tsdf_approval_code
		AND src.company_id = tsdfapproval.company_id
		and src.profit_ctr_id = tsdfapproval.profit_ctr_id
	WHERE src.biennial_id = @biennial_id
	AND ISNULL(src.management_code, '') NOT IN (select management_code from #valid)
	and src.trans_mode = 'O'
	
END
GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_management_codes] TO [EQWEB]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_management_codes] TO [COR_USER]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_management_codes] TO [EQAI]
    AS [dbo];
GO
