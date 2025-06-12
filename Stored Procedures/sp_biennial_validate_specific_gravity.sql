
CREATE PROCEDURE sp_biennial_validate_specific_gravity
	@biennial_id int,
	@debug		int = 0
AS

/******************************************************************************
sp_biennial_validate_specific_gravity

History:
	2/7/2018	JPB	Created per Jim Conn - specific_gravity outside of 0-5 is unusual

Example:
	sp_biennial_validate_specific_gravity 2034;
	SELECT  * FROM  EQ_Extract..BiennialReportSourceDataValidation WHERE biennial_id = 2034 and validation_message not like '%Bol type%'
	select * FROM  EQ_Extract..BiennialReportSourceDataValidation WHERE biennial_id = 2034 and validation_message like '%EPA ID%'
	delete FROM  EQ_Extract..BiennialReportSourceDataValidation WHERE biennial_id = 2034 and validation_message like '%EPA ID%'

	exec sp_biennial_validate 2034


******************************************************************************/
BEGIN

	declare @newline varchar(5) = char(13)+char(10)

if @debug > 0 select getdate(), 'sp_biennial_validate_specific_gravity: started'	

	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation (validation_message, rowid, biennial_id)
	-- declare @biennial_id int = 2279
	SELECT DISTINCT 'Possible bad specific gravity value: ' + convert(Varchar(20), pl.specific_gravity) + ' on profile id  ' + convert(Varchar(20), pl.profile_id)
	, 1, @biennial_id
	from eq_extract..BiennialReportSourceData s 
	join Receipt r on s.receipt_id = r.receipt_id and s.line_id = r.line_id and s.company_id = r.company_id and s.profit_ctr_id = r.profit_ctr_id
	join ProfileLab pl on r.profile_id = pl.profile_id and pl.type = 'A'
	WHERE s.biennial_id = @biennial_id
	and isnull(pl.specific_gravity, 0) not between 0 and 5
	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_specific_gravity] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_specific_gravity] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_specific_gravity] TO [EQAI]
    AS [dbo];

