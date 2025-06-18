USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_rpt_waste_received_radioactive]    Script Date: 4/2/2025 11:00:59 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE     PROCEDURE [dbo].[sp_rpt_waste_received_radioactive]
	@company_id				INTEGER
,	@profit_ctr_id			INTEGER
,	@date_from				DATETIME
,	@date_to				DATETIME
,	@radioactive_waste_type	CHAR(1)		-- Expected values are:
										--   F (FUSRAP), for the "Radioactive FUSRAP Material Received" report
										--   N (non-FUSRAP), for the "Radioactive non-FUSRAP Material Received" report
										--   E (exempt), for the "Radioactive Exempt Devices and Accelerator Material Received" report
AS
/***************************************************************************
02/11/2025 MPM	Rally US141037/US141039/US142142 - Created for:
				- the "Radioactive FUSRAP Material Received" report
				- the "Radioactive Non-FUSRAP Material Received" report
				- the "‘Radioactive Exempt Devices and Accelerator Material Received" report
				
sp_rpt_waste_received_radioactive 44, 0, '10/1/2024', '12/31/2024', 'F'
sp_rpt_waste_received_radioactive 2, 0, '1/1/2020', '12/31/2024', 'N'
sp_rpt_waste_received_radioactive 44, 0, '1/1/2020', '12/31/2024', 'E'

***************************************************************************/
BEGIN

	CREATE TABLE #tmp (
		company_id							INT				NULL,
		profit_ctr_id						INT				NULL,
		receipt_id							INT				NULL,
		line_id								INT				NULL,
		profile_id							INT				NULL,
		approval_code						VARCHAR(15)		NULL,
		common_name							VARCHAR(50)		NULL,
		receipt_date						DATETIME		NULL,
		manifest							VARCHAR(15)		NULL,
		manifest_page_num					INT				NULL,
		manifest_line						INT				NULL,
		manifest_unit						CHAR(1)			NULL,
		manifest_quantity					FLOAT			NULL,
		manifest_line_weight_pounds			DECIMAL(18, 4)	NULL,
		manifest_line_weight_tons			DECIMAL(18, 4)	NULL,
		manifest_line_volume_cubic_yards	DECIMAL(18, 4)	NULL,
		dose_rate							DECIMAL(10, 2)	NULL
	)

	INSERT INTO #tmp (
		company_id, 
		profit_ctr_id, 
		receipt_id, 
		line_id, 
		profile_id, 
		approval_code, 
		common_name, 
		receipt_date,
		manifest, 
		manifest_page_num, 
		manifest_line, 
		manifest_unit, 
		manifest_quantity, 
		dose_rate)
	SELECT	
		r.company_id,
		r.profit_ctr_id,
		r.receipt_id,
		r.line_id,
		r.profile_id, 
		r.approval_code,
		p.approval_desc,
		r.receipt_date,
		r.manifest,
		r.manifest_page_num,
		r.manifest_line,
		r.manifest_unit,
		r.manifest_quantity,		
		r.activity_derived_from_dose_rate AS does_rate
	FROM Receipt r
	JOIN ProfileRadioactive pr
		ON pr.profile_id = r.profile_id
		AND pr.waste_type = @radioactive_waste_type
	JOIN Profile p
		ON p.profile_id = r.profile_id
	WHERE r.trans_mode = 'I'
	AND r.trans_type = 'D'
	AND r.receipt_status NOT IN ('V', 'R')
	AND r.fingerpr_status NOT IN ('V', 'R')
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	
	-- Calculate manifest_line_weight_pounds
	UPDATE #tmp
		SET manifest_line_weight_pounds = dbo.fn_receipt_weight_line(receipt_id, line_id, profit_ctr_id, company_id)

	-- Update manifest_line_weight_tons and manifest_line_volume_cubic_yards from manifest_line_weight_pounds

	-- Note: the usual BillUnit.pound_conv conversion factor for TONS is used below to convert from pounds to tons.
	-- However, in the discussion section of Rally US141037, Zach Wright instructed me to use a conversion factor of 
	-- 1/1.3 to convert from tons to cubic yards, because that is how it was done in the AESOP versions of these reports.

	UPDATE #tmp
		SET manifest_line_weight_tons = manifest_line_weight_pounds/BillUnit.pound_conv,
			manifest_line_volume_cubic_yards = (manifest_line_weight_pounds/BillUnit.pound_conv)/1.3
		FROM BillUnit
		WHERE bill_unit_code = 'TONS'

	-- Final select statement
	SELECT	
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	profile_id, 
	approval_code,
	common_name,
	receipt_date,
	manifest,
	manifest_page_num,
	manifest_line,
	manifest_unit,
	manifest_quantity,
	manifest_line_weight_pounds,
	manifest_line_weight_tons,
	manifest_line_volume_cubic_yards, 
	dose_rate
	FROM #tmp
	ORDER BY approval_code, receipt_date, receipt_id, line_id
END
GO
