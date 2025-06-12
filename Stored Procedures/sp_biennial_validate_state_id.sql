
CREATE PROCEDURE sp_biennial_validate_state_id
	@biennial_id int
AS

/*
	Usage: sp_biennial_validate_state_id 42;	
*/
BEGIN

	declare @newline varchar(5) = char(13)+char(10)
	
	/* Get missing generator.state_id's */
	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
	 SELECT 'Error: 26-00 Validation: Generator state_id missing'
	 , src.*
		FROM EQ_Extract..BiennialReportSourceData src
		WHERE ISNULL(src.generator_state_id, '') = ''
		AND src.Company_id = 26
		AND src.generator_state = 'IL'
		AND src.biennial_id = @biennial_id
		

	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_state_id] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_state_id] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_state_id] TO [EQAI]
    AS [dbo];

