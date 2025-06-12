
CREATE PROCEDURE sp_biennial_validate_pound_conversion
	@biennial_id int
AS

/*********************************************************************
sp_biennial_validate_pound_conversion 100;	

History:
	02/08/2012 JPB	Removed Enviroware section
	
*********************************************************************/
BEGIN

	declare @newline varchar(5) = char(13) + char(10)
	
	---- create the validation table if it doesnt exist
	--if object_id('tempdb..#validation_table') IS NULL
	--	SELECT cast(null as varchar(max)) as validation_message, *
	--	INTO #validation_table
	--	FROM EQ_Extract..BiennialReportSourceData src
	--	WHERE src.biennial_id = @biennial_id
	
	--INSERT INTO EQ_Extract..BiennialReportSourceDataValidation
	--	SELECT cast(null as varchar(max)) as validation_message, *
	--	FROM EQ_Extract..BiennialReportSourceData src
	--	WHERE src.biennial_id = @biennial_id
			
	/* Handle Enviroware generated items */
/*	
	INSERT INTO EQ_Extract..BiennialReportSourceDataValidation
		SELECT 'No Bill Unit and/or pound conversion for ENVIROWARE; manifest_line.container_size = ' + cast(ml.CONTAINER_SIZE as varchar(20)) + ', manifest_line.container_type = ' + ml.CONTAINER_TYPE
		,src.*
	FROM EQ_Extract..BiennialReportSourceData src
		JOIN Envirite.dbo.manifest_line ml ON src.enviroware_manifest_document = ml.DOCUMENT
			and src.enviroware_manifest_document_line = ml.DOCUMENT_LINE
		JOIN Envirite.dbo.ENVIRITE_BillUnitXref unit_xref ON ml.CONTAINER_SIZE = unit_xref.envirite_container_size
			AND ml.CONTAINER_TYPE = unit_xref.envirite_um
		WHERE unit_xref.bill_unit_code IS NULL
		AND src.biennial_id = @biennial_id
		and src.data_source = 'ENVIROWARE'
*/		
	
	/* Handle the EQAI generated items */
	INSERT EQ_Extract..BiennialReportSourceDataValidation
		SELECT 'No LBS Conversion for ' + BillUnit.bill_unit_code
		,src.*	
	FROM   Receipt Receipt
		INNER JOIN EQ_Extract.dbo.BiennialReportSourceData src ON src.receipt_id = Receipt.receipt_id
			AND src.line_id = Receipt.line_id
			AND src.Company_id = Receipt.company_id
			AND src.profit_ctr_id = Receipt.profit_ctr_id
			AND src.data_source = 'EQAI'
       INNER JOIN ReceiptPrice ReceiptPrice
         ON Receipt.company_id = ReceiptPrice.company_id
            AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
            AND Receipt.receipt_id = ReceiptPrice.receipt_id
            AND Receipt.line_id = ReceiptPrice.line_id
       INNER JOIN BillUnit BillUnit
         ON ReceiptPrice.bill_unit_code = BillUnit.bill_unit_code
  WHERE src.biennial_id = @biennial_id
  AND  BillUnit.pound_conv IS NULL
  
  
  --SELECT * 
  --FROM   Receipt Receipt
		--INNER JOIN EQ_Extract.dbo.BiennialReportSourceData src ON src.receipt_id = Receipt.receipt_id
		--	AND src.line_id = Receipt.line_id
		--	AND src.Company_id = Receipt.company_id
		--	AND src.profit_ctr_id = Receipt.profit_ctr_id
		--	AND src.data_source = 'EQAI'
  --     INNER JOIN ReceiptPrice ReceiptPrice
  --       ON Receipt.company_id = ReceiptPrice.company_id
  --          AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
  --          AND Receipt.receipt_id = ReceiptPrice.receipt_id
  --          AND Receipt.line_id = ReceiptPrice.line_id
  --     --INNER JOIN ContainerDestination ContainerDestination
  --     --  ON Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id
  --     --     AND Receipt.receipt_id = ContainerDestination.receipt_id
  --     --     AND Receipt.line_id = ContainerDestination.line_id
  --     --INNER JOIN Treatment Treatment
  --     --  ON ContainerDestination.treatment_id = Treatment.treatment_id
  --     --     AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
  --     --INNER JOIN Generator Generator
  --     --  ON Receipt.generator_id = Generator.generator_id
  --     --INNER JOIN Transporter Transporter
  --     --  ON Receipt.hauler = Transporter.Transporter_code
  --     INNER JOIN BillUnit BillUnit
  --       ON ReceiptPrice.bill_unit_code = BillUnit.bill_unit_code
  --WHERE src.biennial_id = @biennial_id
  --AND  BillUnit.pound_conv IS NULL
  
	
  --SELECT * FROM EQ_Extract.dbo.BiennialReportSourceDataValidation where biennial_id = 100
  --DELETE FROM EQ_Extract..BiennialReportSourceDataValidation where biennial_id = 100
	--DELETE FROM #validation_table where validation_message is null
  
	--SELECT * FROM #validation_table 

	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_pound_conversion] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_pound_conversion] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_pound_conversion] TO [EQAI]
    AS [dbo];

