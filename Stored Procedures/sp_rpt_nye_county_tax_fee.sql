CREATE OR ALTER PROCEDURE sp_rpt_nye_county_tax_fee
(
	@company_id			INT,
    @profit_center_id	INT,
    @receipt_date_from	DATETIME,
    @receipt_date_to	DATETIME,
    @customer_id_from	INT,
    @customer_id_to		INT
)
AS
/***************************************************************************************  
PB Object : r_nye_county_tax_fee

1/16/2024 Prakash US116930 Initial version. 
1/31/2024 Abul US140068  Report improvements.    
sp_rpt_nye_county_tax_fee 21, 0, 2024-08-20 00:00:00.000, 2024-08-20 00:00:00.000, 1, 99999
****************************************************************************************/ 
DECLARE
@pound_ton_conversion		DECIMAL(10,5),  
@manifest_Hazardous_fee		DECIMAL(8,2),
@manifest_nonHazardous_fee	DECIMAL(8,2)

BEGIN

	SET @pound_ton_conversion		= 0.0005
	SET @manifest_Hazardous_fee		= 1.32  
	SET @manifest_nonHazardous_fee	= 0.60 

	SELECT
		CONCAT(Receipt.company_id, '-', Receipt.profit_ctr_id) AS facility,
		ISNULL (Receipt.time_in, '') AS time_in,  
		CONVERT(Varchar(15), ISNULL (Receipt.receipt_id, '')) + '-' + CONVERT(Varchar(10), Receipt.line_id) AS receipt_id,  
		ProfitCenter.profit_ctr_name,
		ISNULL(Receipt.manifest_form_type, '') AS haz_flag, 
		ISNULL(Receipt.line_weight, 0)*@pound_ton_conversion AS received_weight,
		CASE	--fee
			WHEN ISNULL(Receipt.manifest_form_type, '') = 'H' THEN	@manifest_Hazardous_fee         
			WHEN ISNULL(Receipt.manifest_form_type, '') = 'N' THEN	@manifest_nonHazardous_fee   
		ELSE  0  END AS fee,     
		CASE	--truck_fee
			WHEN ISNULL(Receipt.manifest_form_type, '') = 'H' THEN 
					(ISNULL(Receipt.line_weight, 0)*@pound_ton_conversion) * @manifest_Hazardous_fee        
			WHEN ISNULL(Receipt.manifest_form_type, '') = 'N' THEN 
					(ISNULL(Receipt.line_weight, 0)*@pound_ton_conversion) * @manifest_nonHazardous_fee  
		ELSE 0 END AS truck_fee 
	FROM	Receipt JOIN ProfitCenter ON Receipt.company_id = ProfitCenter.company_id
			AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id
	WHERE  (Receipt.company_id = @company_id) 
			AND	(Receipt.profit_ctr_id = @profit_center_id) 
			AND	(Receipt.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to )
			AND	(Receipt.customer_id  BETWEEN @customer_id_from  AND @customer_id_to) 
			AND	(Receipt.trans_type NOT IN ('S'))
	ORDER BY haz_flag DESC, time_in DESC
END
GO

GRANT EXECUTE 
	ON [dbo].[sp_rpt_nye_county_tax_fee] TO [EQAI]
GO
