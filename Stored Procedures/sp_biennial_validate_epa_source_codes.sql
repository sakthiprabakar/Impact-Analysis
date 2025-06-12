-- drop proc sp_biennial_validate_epa_source_codes
go

CREATE PROCEDURE sp_biennial_validate_epa_source_codes
	@biennial_id int
AS

/*
	Usage: sp_biennial_validate_epa_source_codes 116	
*/
BEGIN

		declare @newline varchar(5) = char(13)+char(10)
	
	-- create the validation table if it doesnt exist
	--if object_id('tempdb..#validation_table') IS NULL
	--	SELECT cast(null as varchar(max)) as validation_message, *
	--	INTO #validation_table
	--	FROM EQ_Extract..BiennialReportSourceData src
	--	WHERE src.biennial_id = @biennial_id
	
	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
		(validation_message, rowid, biennial_id, data_source)
	 SELECT DISTINCT 'Empty EPA_source_code in '
		+ case when src.trans_mode = 'I' then 'EQ' else 'TSDF' end
		+ ' Approval: ' + approval_code,
		1, @biennial_id, 'EQAI'
		FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ISNULL(EPA_source_code, '') = ''

	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
		(validation_message, rowid, biennial_id, data_source)
	 SELECT DISTINCT '2019 inactive EPA_source_code (use G62?) in '
		+ case when src.trans_mode = 'I' then 'EQ' else 'TSDF' end
		+ ' Approval: ' + approval_code,
		1, @biennial_id, 'EQAI'
		FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND ISNULL(EPA_source_code, '') in ('G63', 'G64', 'G65', 'G66', 'G67', 'G68', 'G69', 'G70', 'G71', 'G72', 'G73', 'G74', 'G75')

	
	/*
	INSERT INTO EQ_Extract..BiennialReportSourceDataValidation 
		SELECT 'Empty Treatment.management_code for treatment_id: ' + ISNULL(cast(src.treatment_id as varchar(20)), '(empty)')
		, src.*
	FROM EQ_Extract..BiennialReportSourceData src
		WHERE ISNULL((
			SELECT TOP 1 treatment.management_code FROM Treatment treatment 
				WHERE treatment.treatment_id = src.treatment_id
				AND src.biennial_id = @biennial_id
		),'') = ''
	*/	
	--delete from #validation_table where validation_message is null
	
	--SELECT * FROM #validation_table
	
	--/* Handle the EQAI generated items */
	--update #validation_table set validation_message = 'No Management Code for Treatment: ' + cast (Treatment.treatment_id as varchar(50))
	--FROM   Receipt Receipt
	--	INNER JOIN BiennialReportSourceData src ON src.receipt_id = Receipt.receipt_id
	--		AND src.Company_id = Receipt.company_id
	--		AND src.profit_ctr_id = Receipt.profit_ctr_id
	--		AND src.data_source = 'EQAI'
	--		AND src.line_id = Receipt.line_id
 --      INNER JOIN ReceiptPrice ReceiptPrice
 --        ON Receipt.company_id = ReceiptPrice.company_id
 --           AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
 --           AND Receipt.receipt_id = ReceiptPrice.receipt_id
 --           AND Receipt.line_id = ReceiptPrice.line_id
 --      INNER JOIN ContainerDestination ContainerDestination
 --        ON Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id
 --           AND Receipt.receipt_id = ContainerDestination.receipt_id
 --           AND Receipt.line_id = ContainerDestination.line_id
 --      INNER JOIN Treatment Treatment
 --        ON ContainerDestination.treatment_id = Treatment.treatment_id
 --           AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
 --      INNER JOIN Generator Generator
 --        ON Receipt.generator_id = Generator.generator_id
 --      INNER JOIN Transporter Transporter
 --        ON Receipt.hauler = Transporter.Transporter_code
 -- WHERE src.biennial_id = @biennial_id
 -- AND  Treatment.management_code is null
	
	
	
END
GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_epa_source_codes] TO [EQWEB]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_epa_source_codes] TO [COR_USER]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_epa_source_codes] TO [EQAI]
    AS [dbo];
GO
