
CREATE PROCEDURE sp_biennial_validate_weight_entered
	@biennial_id int
AS

/*
	Usage: sp_biennial_validate_form_code 42;	
	
use eq_extract
sp_help BiennialReportSourceData
create index idx_biennial_id on BiennialReportSourceData (biennial_id)	
use plt_ai	
*/
BEGIN

	declare @newline varchar(5) = char(13)+char(10)
	
	/* Get missing gal & yard entries */
	if exists (select 1 from EQ_Extract..BiennialReportSourceData where biennial_id = @biennial_id
		and company_id = 26)
		INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
		 SELECT 'Error: 26-00 Validation: Both gal_haz_actual and yard_haz_actual are empty'
		 , src.*
			FROM EQ_Extract..BiennialReportSourceData src
			WHERE ISNULL(src.yard_haz_actual, 0) = 0
			AND ISNULL(src.gal_haz_actual, 0) = 0
			AND ISNULL(src.lbs_haz_estimated, 0) = 0
			AND src.Company_id = 26
			AND biennial_id = @biennial_id

	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_weight_entered] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_weight_entered] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_weight_entered] TO [EQAI]
    AS [dbo];

