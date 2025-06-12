/***************************************************************************************
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table
11/11/2004 MK	Changed generator_code to generator_id
03/15/2006 RG	removed join to wastecode on profit ctr
06/23/2013 AM   Moved to plt_ai db
05/15/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.).
****************************************************************************************/
CREATE PROCEDURE sp_gmexport 
	@company_id		int,
	@receipt_date_from	datetime,
	@receipt_date_to	datetime
AS
DECLARE	@vendor_epaid char(12)

if @company_id = 2
select @vendor_epaid = 'MID000724831'
else
select @vendor_epaid = 'MID048090633'

SELECT
customer_code = CONVERT(varchar(6),billing.customer_id),
gen_id = '',
vendor_epaid = @vendor_epaid,
g.EPA_ID,
billing.manifest,
EPA#1 = '',
EPA#2 = '',
EPA#3 = '',
EPA#4 = '',
EPA#5 = '',
w.haz_flag,
billing.gross_weight,
billing.quantity,
b.gm_bill_unit_code,
b.gm_bill_unit_code,
ConvFact = '',
ProfileId = '',
TransDept = '',
ShipDate = '',
billing.billing_date,
billing.billing_date,
RepDate = GETDATE(),
TreatId = '',
billing.hauler,
STransId = '',
billing.price,
BinBox = '',
Trans1 = '',
Trans2 = '',
TransOther = '',
Treatment = '',
Resycle = '',
Disposal = '',
Disother = '',
Other = '',
Tax = '',
Lab = '',
Decontam = '',
Spill = '',
NonConf = '',
billing.sr_price,
SolidsPr = '',
WaterPr = '',
OilPr = '',
BTUVal = '',
billing.total_extended_amt,
billing.invoice_code,
Comments = ''
FROM billing
LEFT OUTER JOIN wastecode w ON billing.waste_code = w.waste_code 
LEFT OUTER JOIN billunit b ON billing.bill_unit_code = b.bill_unit_code
LEFT OUTER JOIN generator g ON billing.generator_id = g.generator_id
WHERE billing.billing_date BETWEEN @receipt_date_from and @receipt_date_to 


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gmexport] TO [EQAI]
    AS [dbo];

