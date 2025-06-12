
CREATE PROCEDURE sp_rpt_waste_received_from_generators
	@company_id			int
,	@date_from			datetime
,	@date_to			datetime
,	@waste_code_from	varchar(4)
,	@waste_code_to		varchar(4)
AS
/**************************************************************************************
This procedure runs for Waste Received from Generators Report
PB Object(s):	r_waste_rec

08/10/2011 SK	Created
11/20/2015 AM   GEM:25565 -Added trans_type 'D', Result should return only desposal lines.

sp_rpt_waste_received_from_generators 15, '06/01/2011', '06/15/2011', '0', 'ZZZZ'
**************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT 
	Billing.approval_code
,	Billing.generator_id
,	Billing.bill_unit_code
,	Billing.billing_date
,	Billing.quantity
,	Billing.company_id
,	Generator.EPA_ID
,	Generator.generator_name
FROM Billing
LEFT OUTER JOIN Generator ON Billing.generator_id = Generator.generator_id
WHERE Billing.company_id = @company_id
	AND Billing.billing_date BETWEEN @date_from AND @date_to
	AND Billing.waste_code BETWEEN @waste_code_from AND @waste_code_to
	AND Billing.status_code <> 'V'
    AND Billing.trans_type = 'D' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_waste_received_from_generators] TO [EQAI]
    AS [dbo];

