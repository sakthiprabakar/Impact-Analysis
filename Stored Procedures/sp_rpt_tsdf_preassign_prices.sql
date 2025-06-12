

CREATE PROCEDURE sp_rpt_tsdf_preassign_prices
	@company_id		int
,	@profit_ctr_id	int 
,	@location		varchar(15)
,	@tsdf_approval	varchar(40)
AS
/***************************************************************************************

10/25/2007  rg  created to support d_rpt_tsdf__preassign_prices
                This report identifies tsdf approvals and the profile approvals that are
                 preassigned to it.  It also shows the prices for comparison.
10/29/07    rg  revised report to use the tsdf and/or the tsdfapproval 
11/23/2010	SK	Added Company_ID as input arg & joins to company_id, reformatted and modified
				to run on Plt_AI, moved to Plt_AI
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_rpt_tsdf_preassign_prices 21, 0, 'CRI','CRI-EQ-24'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE 
	@tsdf_approval_id		int,
    @price_list				varchar(1200),
    @profile_profile_id		int, 
    @profile_profit_ctr_id	int, 
    @profile_company_id		int,
    @ob_tsdf_approval_id	int

IF @tsdf_approval = 'ALL'
BEGIN
	SET @ob_tsdf_approval_id = 0
END
ELSE
BEGIN
	SELECT @ob_tsdf_approval_id = ta.tsdf_approval_id FROM tsdfapproval ta
    WHERE ta.tsdf_approval_code = @tsdf_approval
		AND ta.profit_ctr_id = @profit_ctr_id
        AND ta.company_id    = @company_id
END

IF @location = 'ALL'
BEGIN
	SELECT @location = ta.tsdf_code FROM tsdfapproval ta
    WHERE ta.tsdf_approval_id = @ob_tsdf_approval_id
END

CREATE TABLE #summary ( 
	profile_id				int				null
,	company_id				int				null
,	profit_ctr_id			int				null
,	approval_code			varchar(20)		null
,	location				varchar(20)		null
,	treatment_id			int				null
,	customer_id				int				null
,	generator_id			int				null
,	cust_name				varchar(75)		null
,	territory_code			varchar(10)		null
,	generator_name			varchar(75)		null
,	generator_epa_id		varchar(20)		null
,	ob_tsdf_approval_id		int				null
,	ib_bill_unit_list		varchar(1200)	null
,	tsdf_name				varchar(50)		null
,	tsdf_approval_code		varchar(40)		null
,	ob_bill_unit_list		varchar(1200)	null
,	ib_approval_expire_date datetime		null
,	company_name			varchar(35)		null
,	profit_ctr_name			varchar(50)		null
)

INSERT #summary
SELECT
	pqa.profile_id
,	pqa.company_id
,	Pqa.profit_ctr_id
,	pqa.approval_code
,	pqa.location
,	pqa.treatment_id
,	p.customer_id
,	p.generator_id
,	c.cust_name
,	cb.territory_code
,	g.generator_name
,	g.epa_id
,	pqa.ob_tsdf_approval_id
,	null
,	tsdf.tsdf_name
,	ta.tsdf_approval_code
,	null
,	p.ap_expiration_date
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM ProfileQuoteApproval pqa
INNER JOIN Company
	ON Company.company_id = pqa.company_id
INNER JOIN ProfitCenter
	ON ProfitCenter.company_ID = pqa.company_id
	AND ProfitCenter.profit_ctr_ID = pqa.profit_ctr_id
INNER JOIN Profile p 
	ON p.profile_id = pqa.profile_id 
	AND p.curr_status_code = 'A'
INNER JOIN ProfileQuoteDetail pqd 
	ON pqd.profile_id = pqa.profile_id
    AND pqd.company_id = pqa.company_id
    AND pqd.profit_ctr_id = pqa.profit_ctr_id
INNER JOIN tsdf 
	ON tsdf.tsdf_code = pqa.location
INNER JOIN customer c 
	ON c.customer_id = p.customer_id
INNER JOIN CustomerBilling cb
	ON cb.customer_id = c.customer_ID
	AND cb.billing_project_id = 0
INNER JOIN generator g 
	ON g.generator_id = p.generator_id
INNER JOIN tsdfapproval ta 
	ON ta.tsdf_approval_id = pqa.ob_tsdf_approval_id
INNER JOIN tsdfapprovalprice tap 
	ON tap.tsdf_approval_id = ta .tsdf_approval_id
WHERE pqa.location = @location
	AND pqa.profit_ctr_id = @profit_ctr_id
	AND pqa.company_id = @company_id
	AND (pqa.ob_tsdf_approval_id = @ob_tsdf_approval_id or @ob_tsdf_approval_id = 0)
       
-- get prices for tsdfapproval
-- declare cursor 
DECLARE grp CURSOR FOR 
SELECT DISTINCT ob_tsdf_approval_id FROM #summary

OPEN grp
FETCH grp INTO @tsdf_approval_id 

WHILE @@fetch_status = 0
BEGIN
	SELECT @price_list = COALESCE( @price_list + ', ', '') + ( isnull(tp.bill_unit_code,'') + ' - $' + (convert(varchar(20), isnull(tp.price,0))) +  ' cost: $' + (convert(varchar(20), isnull(tp.cost,0))))  
	FROM tsdfapprovalprice tp 
	WHERE tp.tsdf_approval_id = @tsdf_approval_id
	 AND  tp.record_type = 'D'

	UPDATE #summary
    SET ob_bill_unit_list = @price_list
    WHERE ob_tsdf_approval_id = @tsdf_approval_id
    
	SET @price_list = ''
	FETCH grp INTO @tsdf_approval_id
END

CLOSE grp
DEALLOCATE grp

-- get prices for inbound
SET @price_list = ''

DECLARE grp2 cursor for 
SELECT DISTINCT profile_id,profit_ctr_id, company_id FROM #summary

OPEN grp2
FETCH grp2 INTO @profile_profile_id, @profile_profit_ctr_id, @profile_company_id

WHILE @@fetch_status = 0
BEGIN
    SELECT @price_list = COALESCE( @price_list + ', ', '') + ( isnull(pqd.bill_unit_code,'') + ' - $' + (convert(varchar(20), isnull(pqd.price,0))) )  
    FROM profilequotedetail pqd 
	WHERE pqd.profile_id = @profile_profile_id
     AND  pqd.profit_ctr_id = @profile_profit_ctr_id
     AND  pqd.company_id    = @profile_company_id
     AND  pqd.record_type = 'D'

	UPDATE #summary
    SET ib_bill_unit_list = @price_list
    WHERE profile_id   = @profile_profile_id
     AND profit_ctr_id = @profile_profit_ctr_id
     AND  company_id    = @profile_company_id
 
    SET @price_list = ''
    FETCH grp2 INTO @profile_profile_id, @profile_profit_ctr_id, @profile_company_id
END

CLOSE grp2
DEALLOCATE grp2

-- trim up lists
UPDATE #summary
SET ob_bill_unit_list = right(ob_bill_unit_list , (len(ob_bill_unit_list ) - 1))
WHERE charindex(',',ob_bill_unit_list ) = 1

UPDATE #summary
SET ob_bill_unit_list = left(ob_bill_unit_list , (len(ob_bill_unit_list ) - 2))
WHERE right(ob_bill_unit_list ,2) = ', '

UPDATE #summary
SET ib_bill_unit_list = right(ib_bill_unit_list , (len(ib_bill_unit_list ) - 1))
WHERE charindex(',',ib_bill_unit_list ) = 1

UPDATE #summary
SET ib_bill_unit_list = left(ib_bill_unit_list , (len(ib_bill_unit_list ) - 2))
WHERE right(ib_bill_unit_list ,2) = ', '

SELECT * FROM #summary


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_tsdf_preassign_prices] TO [EQAI]
    AS [dbo];

