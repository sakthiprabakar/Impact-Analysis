USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_rpt_customer_shipment_details]    Script Date: 8/28/2023 12:50:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   Procedure [dbo].[sp_rpt_customer_shipment_details]
	@company_id		INT,
	@profit_ctr_id 	INT,
	@cust_id_from	INT,
	@cust_id_to		INT
AS
/****** Object:  StoredProcedure [dbo].[sp_rpt_customer_shipment_details]    Script Date: 8/25/2023 ******/

/***************************************************************************************
8/25/2023 Subhrajyoti	created on Plt_AI

PB Object : r_rpt_customer_shipment_details

sp_rpt_customer_shipment_details 14, 4, 1, 999999
****************************************************************************************/

DECLARE
@old_receipt_start_date DATETIME,
@old_receipt_end_date DATETIME, 
@new_receipt_start_date DATETIME,
@new_receipt_end_date DATETIME


SET @old_receipt_start_date = DATEADD(YEAR, -3, GETDATE()) 
SET @old_receipt_end_date = DATEADD(MONTH, -6, GETDATE())
SET @new_receipt_start_date = DATEADD(MONTH, -6, GETDATE())
SET @new_receipt_end_date = GETDATE()

SELECT DISTINCT
	   r.company_id,
	   co.company_name,
	   r.profit_ctr_id,
	   p.profit_ctr_name,
	   r.customer_id,
       c.cust_name,
	   r.generator_id,
	   g.generator_name,
	   r.receipt_id AS "Previous Receipt Id(s)",
	   r.receipt_date AS "Previous receipt date(s)",
	   r.manifest  AS "Previous manifest number(s)"
FROM Receipt r 
JOIN Customer c ON r.customer_id = c.customer_id
JOIN company co ON r.company_id = co.company_id
JOIN ProfitCenter p ON r.company_id = p.company_id AND r.profit_ctr_id = p.profit_ctr_id  
LEFT OUTER JOIN Generator g ON r.generator_id = g.generator_id 
WHERE(@company_id = 0 OR r.company_id = @company_id )
AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
AND r.customer_id BETWEEN @cust_id_from AND @cust_id_to
AND r.receipt_date BETWEEN @old_receipt_start_date AND @old_receipt_end_date
AND NOT EXISTS (SELECT 1 
				FROM Receipt
				WHERE customer_id = r.customer_id
				AND (@company_id = 0 OR r.company_id = @company_id )
				AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id) 
				AND receipt_date BETWEEN @new_receipt_start_date AND @new_receipt_end_date
				AND r.trans_mode = 'I'
				AND r.receipt_status NOT IN ('V','R'))
AND r.trans_mode = 'I'
AND r.receipt_status NOT IN ('V','R')
AND ISNULL(c.cust_status,'I') = 'A'

GO

GRANT EXECUTE
ON OBJECT::[dbo].[sp_rpt_customer_shipment_details] TO [EQAI];

GO

