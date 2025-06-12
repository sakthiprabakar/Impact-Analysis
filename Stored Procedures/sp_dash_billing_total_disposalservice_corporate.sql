
CREATE PROCEDURE sp_dash_billing_total_disposalservice_corporate (
    @StartDate  datetime,
    @EndDate    datetime,
    @user_code  varchar(100) = NULL, -- for associates
    @contact_id int = NULL, -- for customers
    @permission_id int = NULL
)
AS
/************************************************************
Procedure    : sp_dash_billing_total_disposalservice_corporate
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the total amount invoiced per disposal service across all companies
    between @StartDate AND @EndDate

10/1/2009 - JPB Created 
09/20/2010 - JPB Added Tons, Gallons columns to output.
01/14/2011 - SK	 Data Conversion- Changed to fetch Total Amt from BillingDetail instead of Billing
01/19/2011 - SK  Changed to include in the total amt, insurance & energy amts as well
				eg: Select * from Billing where receipt_id = 764770 AND line_id = 1 AND price_id = 1 
					 AND company_id = 21 AND profit_ctr_id = 0
					Select extended_amt, billing_type from BillingDetail where receipt_id = 764770
					 AND line_id = 1 AND price_id = 1 AND company_id = 21 AND profit_ctr_id = 0

sp_dash_billing_total_disposalservice_corporate 
    @StartDate='2010-06-01 00:00:00',
    @EndDate='2010-06-05 23:59:59',
    @user_code='JONATHAN',
    @contact_id=-1,
    @permission_id = 84
    
************************************************************/
Declare @billing_total table(
	company_id			int
,	profit_ctr_id		int
,	receipt_id			int
,	line_id				int
,	price_id			int
,	total				money
)

IF @user_code = ''
    set @user_code = NULL
    
IF @contact_id = -1
    set @contact_id = NULL
    
Declare @debug int = 0
declare @TimeStart datetime = getdate()

DECLARE @tbl ContainerWeightCalculationTable

--IF @debug > 0
--	SELECT 'start', DATEDIFF(millisecond, @TimeStart, getdate())

DECLARE @container_details ContainerWeightCalculationTable

INSERT INTO @container_details 
SELECT  
	DISTINCT
	r.receipt_id,
	r.company_id,
	r.profit_ctr_id,
	r.line_id,
	c.container_id,
	cd.sequence_id,
	@EndDate, 
	cd.disposal_date,
	c.container_type,
	c.container_size,
	ISNULL(c.container_weight, 0),
	cd.container_percent,
	r.line_weight,
	r.quantity,
	r.bulk_flag
FROM
        BILLING b WITH(NOLOCK) 
        INNER JOIN Receipt r WITH(NOLOCK) ON b.receipt_id = r.receipt_id
		AND b.company_id = r.company_id
		AND b.profit_ctr_id = r.profit_ctr_id
		AND b.line_id = r.line_id
		INNER JOIN Container c ON
			r.receipt_id = c.receipt_id
			AND r.company_id = c.company_id
			AND r.profit_ctr_id = c.profit_ctr_id
			AND r.line_id = c.line_id
		INNER JOIN ContainerDestination cd WITH(NOLOCK) 
			ON cd.receipt_id = c.receipt_id
			AND cd.company_id = c.company_id
			AND cd.profit_ctr_id = c.profit_ctr_id
			AND cd.container_id = c.container_id
			AND cd.line_id = c.line_id
        INNER JOIN PROFITCENTER pr WITH(NOLOCK) 
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        --INNER JOIN PROFILE p  WITH(NOLOCK) 
        --    ON b.profile_id = p.profile_id
        INNER JOIN PROFILEQUOTEAPPROVAL pqa WITH(NOLOCK)  
            ON b.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id 
            AND b.profit_ctr_id = pqa.profit_ctr_id
        LEFT OUTER JOIN DISPOSALSERVICE d  WITH(NOLOCK) 
            ON pqa.disposal_service_id = d.disposal_service_id
        --left outer join billunit bu  WITH(NOLOCK) 
        --     on b.bill_unit_code = bu.bill_unit_code
    WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
        -- AND b.company_id = 3 AND b.profit_ctr_id = 1 -- AND b.receipt_id = 1185353
        -- AND b.company_id = 12 and b.profit_ctr_id = 1
        -- AND b.company_id = 21 and b.profit_ctr_id = 0 -- AND b.receipt_id = 759739
        -- AND b.company_id = 27 and b.profit_ctr_id = 0
        -- AND b.company_id = 21 and b.profit_ctr_id = 1
	--ORDER BY b.company_id,
 --       b.profit_ctr_id,
 --       b.receipt_id, 
 --       b.line_id,
 --       cd.container_id,
 --       cd.sequence_id	

--IF @debug > 0
--	SELECT 'after table created', DATEDIFF(millisecond, @TimeStart, getdate())

DECLARE @weight_results ContainerWeightCalculationOutput
INSERT @weight_results exec sp_calculate_container_weight @container_details, 'invoice', @StartDate

--IF @debug > 0
--	SELECT 'after proc finished', DATEDIFF(millisecond, @TimeStart, getdate())       

--IF @debug > 0
--	SELECT 'after #container_detail insert', DATEDIFF(millisecond, @TimeStart, getdate())


-- pre-sum the weight totals
SELECT cd.receipt_id,
       cd.company_id,
       cd.profit_ctr_id,
       cd.line_id,
       Sum(cd.container_weight_pounds)    AS total_pounds,
       Sum(cd.container_weight_gallons) total_gallons
INTO   #weight_totals
FROM   @weight_results cd
GROUP BY cd.receipt_id,
       cd.company_id,
       cd.profit_ctr_id,
       cd.line_id
       
create NONCLUSTERED index idx_wt_totals_tmp on #weight_totals(receipt_id, company_id, profit_ctr_id, line_id)	          

--IF @debug > 0
--	SELECT 'after #weight_total insert', DATEDIFF(millisecond, @TimeStart, getdate())

--SELECT * FROM #weight_totals

--SELECT DATEPART(YYYY, b.invoice_date) AS invoice_year, 
--        DATEPART(M, b.invoice_date) AS invoice_month, 
--        ISNULL(d.disposal_service_desc, 'Undefined') AS disposal_service, 
--        SUM(details.total_pounds),
--        SUM(details.total_gallons),
--        SUM(total_extended_amt) AS total 


/*
SELECT DISTINCT 'new - details', 
	   b.receipt_id,
       b.company_id,
       b.profit_ctr_id,
       b.line_id,
       b.quantity,
       b.bill_unit_code,
       r.bulk_flag,
       bu.pound_conv,
       bu.gal_conv,
       Cast(Isnull(details.total_pounds, 0.00) AS DECIMAL(12, 2)) as pounds,
       Cast(Isnull(details.total_gallons, 0.00) AS DECIMAL(12, 2)) as gallons
--SELECT *       
FROM   BILLING b WITH(NOLOCK)
       INNER JOIN Receipt r
         ON b.receipt_id = r.receipt_id
            AND b.company_id = r.company_id
            AND b.profit_ctr_id = r.profit_ctr_id
            AND b.line_id = r.line_id
       INNER JOIN #weight_totals details WITH(NOLOCK)
         ON details.receipt_id = r.receipt_id
            AND details.company_id = r.company_id
            AND details.profit_ctr_id = r.profit_ctr_id
            AND details.line_id = r.line_id
       INNER JOIN PROFITCENTER pr WITH(NOLOCK)
         ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
       INNER JOIN PROFILE p WITH(NOLOCK)
         ON b.profile_id = p.profile_id
       INNER JOIN PROFILEQUOTEAPPROVAL pqa WITH(NOLOCK)
         ON p.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id
            AND b.profit_ctr_id = pqa.profit_ctr_id
			
       LEFT OUTER JOIN DISPOSALSERVICE d WITH(NOLOCK)
         ON pqa.disposal_service_id = d.disposal_service_id
       INNER JOIN billunit bu WITH(NOLOCK)
         ON b.bill_unit_code = bu.bill_unit_code
WHERE  b.status_code = 'I'
       AND pr.status = 'A'
       AND b.trans_source = 'R'
       AND b.trans_type = 'D'
       AND b.invoice_date BETWEEN @StartDate AND @EndDate
		-- AND b.company_id = 3 AND b.profit_ctr_id = 1 -- AND b.receipt_id = 1185353
		-- AND b.company_id = 12 and b.profit_ctr_id = 1
		-- AND b.company_id = 21 and b.profit_ctr_id = 0 -- AND b.receipt_id = 759739
		-- AND b.company_id = 27 and b.profit_ctr_id = 0
         -- AND b.company_id = 21 and b.profit_ctr_id = 1
ORDER  BY b.receipt_id,
       b.company_id,
       b.profit_ctr_id,
       b.line_id,
--       b.quantity,
--       b.bill_unit_code,
       r.bulk_flag


SELECT DISTINCT 'old - detail',
		b.receipt_id,
       b.company_id,
       b.profit_ctr_id,
       b.line_id,
       b.quantity,
       b.bill_unit_code,
       r.bulk_flag,
       bu.pound_conv,
       bu.gal_conv,
       Cast(Sum(b.quantity * bu.pound_conv) AS DECIMAL(12, 2)) AS pounds,
       Cast(sum((b.quantity * bu.gal_conv)) AS DECIMAL(12, 2)) AS gallons

FROM   BILLING b
       INNER JOIN Receipt r
         ON b.receipt_id = r.receipt_id
            AND b.company_id = r.company_id
            AND b.profit_ctr_id = r.profit_ctr_id
            AND b.line_id = r.line_id
       INNER JOIN PROFITCENTER pr WITH(NOLOCK)
         ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
       INNER JOIN PROFILE p WITH(NOLOCK)
         ON b.profile_id = p.profile_id
       INNER JOIN PROFILEQUOTEAPPROVAL pqa WITH(NOLOCK)
         ON p.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id
            AND b.profit_ctr_id = pqa.profit_ctr_id
       LEFT OUTER JOIN DISPOSALSERVICE d WITH(NOLOCK)
         ON pqa.disposal_service_id = d.disposal_service_id
       LEFT OUTER JOIN billunit bu WITH(NOLOCK)
         ON b.bill_unit_code = bu.bill_unit_code
WHERE  b.status_code = 'I'
       AND pr.status = 'A'
       AND b.trans_source = 'R'
       AND b.trans_type = 'D'
       AND b.invoice_date BETWEEN @StartDate AND @EndDate
       -- AND b.company_id = 3 AND b.profit_ctr_id = 1 -- AND b.receipt_id = 1185353
        --AND b.company_id = 12 and b.profit_ctr_id = 1
         -- AND b.company_id = 21 and b.profit_ctr_id = 0 -- AND b.receipt_id = 759739
         -- AND b.company_id = 27 and b.profit_ctr_id = 0
         -- AND b.company_id = 21 and b.profit_ctr_id = 1
GROUP  BY b.receipt_id,
       b.company_id,
       b.profit_ctr_id,
       b.line_id,
       b.quantity,
       b.bill_unit_code,
       r.bulk_flag,
       bu.pound_conv,
       bu.gal_conv
--HAVING sum((b.quantity * bu.pound_conv))> 0
ORDER  BY b.receipt_id,
       b.company_id,
       b.profit_ctr_id,
       b.line_id,
       b.quantity,
       b.bill_unit_code,
       r.bulk_flag

*/

-- pre-sum the Billing total from BillingDetail
INSERT @billing_total
SELECT
	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id
,	SUM(IsNull(bd.extended_amt,0.000)) AS total
FROM Billing b
LEFT JOIN BillingDetail bd
	ON bd.company_id = b.company_id
	AND bd.profit_ctr_id = b.profit_ctr_id
	AND bd.receipt_id = b.receipt_id
	AND bd.line_id = b.line_id
	AND bd.price_id = b.price_id
	AND bd.trans_type = b.trans_type
	AND bd.trans_source = b.trans_source
	--AND bd.billing_type NOT IN ('Insurance', 'Energy')
WHERE  b.status_code = 'I' 
    AND b.trans_source = 'R' 
    AND b.trans_type = 'D'
    AND b.invoice_date BETWEEN @StartDate AND @EndDate
GROUP BY
	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id

--IF @debug = 1 
--BEGIN
--	PRINT 'Select * from @billing_total'
--	SELECT * from @billing_total
--END

SELECT  DATEPART(YYYY, b.invoice_date) AS invoice_year, 
        DATEPART(M, b.invoice_date) AS invoice_month, 
        ISNULL(d.disposal_service_desc, 'Undefined') AS disposal_service, 
        SUM(details.total_pounds) as pounds,
        SUM(details.total_pounds) / 2000 as tons,
        SUM(details.total_gallons) as gallons,
        --SUM(total_extended_amt) AS total 
        SUM(IsNull(bt.total,0)) as total
    FROM
        BILLING b
        INNER JOIN Receipt r ON b.receipt_id = r.receipt_id
			and b.company_id = r.company_id
			and b.profit_ctr_id = r.profit_ctr_id
			and b.line_id = r.line_id
        LEFT JOIN #weight_totals details  WITH(NOLOCK) ON
			details.receipt_id = r.receipt_id
			and details.company_id = r.company_id
			and details.profit_ctr_id = r.profit_ctr_id
			and details.line_id = r.line_id
        INNER JOIN PROFITCENTER pr WITH(NOLOCK) 
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        --INNER JOIN PROFILE p  WITH(NOLOCK) 
        --    ON b.profile_id = p.profile_id
        INNER JOIN PROFILEQUOTEAPPROVAL pqa WITH(NOLOCK)  
            ON b.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id 
            AND b.profit_ctr_id = pqa.profit_ctr_id
        LEFT OUTER JOIN DISPOSALSERVICE d  WITH(NOLOCK) 
            ON pqa.disposal_service_id = d.disposal_service_id
        --left outer join billunit bu 
        --     on b.bill_unit_code = bu.bill_unit_code
        LEFT OUTER JOIN @billing_total bt
			ON bt.company_id = b.company_id
			AND bt.profit_ctr_id = b.profit_ctr_id
			AND bt.receipt_id = b.receipt_id
			AND bt.line_id = b.line_id
			AND bt.price_id = b.price_id
    WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
    GROUP BY 
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc
    ORDER BY
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc

--IF @debug > 0
--	SELECT 'after query insert', DATEDIFF(millisecond, @TimeStart, getdate())

/*
--SELECT  r.receipt_id, r.company_id, r.profit_ctr_id, r.line_id   
SELECT 'new - sum', DATEPART(YYYY, b.invoice_date) AS invoice_year, 
        DATEPART(M, b.invoice_date) AS invoice_month, 
        ISNULL(d.disposal_service_desc, 'Undefined') AS disposal_service, 
        SUM(details.total_pounds) as pounds,
        SUM(details.total_pounds) / 2000 as tons,
        SUM(details.total_gallons) as gallons,
        SUM(total_extended_amt) AS total 
    FROM
        BILLING b
        INNER JOIN Receipt r ON b.receipt_id = r.receipt_id
        and b.company_id = r.company_id
        and b.profit_ctr_id = r.profit_ctr_id
        and b.line_id = r.line_id
        LEFT JOIN #weight_totals details  WITH(NOLOCK) ON
			details.receipt_id = r.receipt_id
			and details.company_id = r.company_id
			and details.profit_ctr_id = r.profit_ctr_id
			and details.line_id = r.line_id
        INNER JOIN PROFITCENTER pr
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        INNER JOIN PROFILE p  WITH(NOLOCK) 
            ON b.profile_id = p.profile_id
        INNER JOIN PROFILEQUOTEAPPROVAL pqa WITH(NOLOCK)  
            ON p.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id 
            AND b.profit_ctr_id = pqa.profit_ctr_id
        LEFT OUTER JOIN DISPOSALSERVICE d  WITH(NOLOCK) 
            ON pqa.disposal_service_id = d.disposal_service_id
        left outer join billunit bu 
             on b.bill_unit_code = bu.bill_unit_code
    WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
        -- AND b.company_id = 3 AND b.profit_ctr_id = 1 -- AND b.receipt_id = 1185353
        --AND b.company_id = 12 and b.profit_ctr_id = 1
         -- AND b.company_id = 21 and b.profit_ctr_id = 0 -- AND b.receipt_id = 759739
         -- AND b.company_id = 27 and b.profit_ctr_id = 0
         -- AND b.company_id = 21 and b.profit_ctr_id = 1
    GROUP BY 
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc    
    ORDER BY
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc

*/

/*
--SELECT b.receipt_id, b.company_id, b.profit_ctr_id, b.line_id   
SELECT 'old - sum', DATEPART(YYYY, b.invoice_date) AS invoice_year, 
        DATEPART(M, b.invoice_date) AS invoice_month, 
        ISNULL(d.disposal_service_desc, 'Undefined') AS disposal_service, 
        sum((b.quantity * bu.pound_conv)) as pounds,
        sum((b.quantity * bu.pound_conv)) /2000 as tons,
        sum((b.quantity * bu.gal_conv)) as gallons,
        SUM(total_extended_amt) AS total 
    FROM
        BILLING b WITH(NOLOCK) 
        INNER JOIN PROFITCENTER pr WITH(NOLOCK) 
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        INNER JOIN PROFILE p  WITH(NOLOCK) 
            ON b.profile_id = p.profile_id
        INNER JOIN PROFILEQUOTEAPPROVAL pqa  WITH(NOLOCK) 
            ON p.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id 
            AND b.profit_ctr_id = pqa.profit_ctr_id
        LEFT OUTER JOIN DISPOSALSERVICE d  WITH(NOLOCK) 
            ON pqa.disposal_service_id = d.disposal_service_id
        left outer join billunit bu  WITH(NOLOCK) 
             on b.bill_unit_code = bu.bill_unit_code
    WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
        -- AND b.company_id = 3 AND b.profit_ctr_id = 1 -- AND b.receipt_id = 1185353
        --AND b.company_id = 12 and b.profit_ctr_id = 1
         -- AND b.company_id = 21 and b.profit_ctr_id = 0 -- AND b.receipt_id = 759739
         -- AND b.company_id = 27 and b.profit_ctr_id = 0
         -- AND b.company_id = 21 and b.profit_ctr_id = 1
    GROUP BY 
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc        
    ORDER BY
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc

*/


/*
        
        SELECT b.receipt_id,
               b.company_id,
               b.profit_ctr_id,
               b.line_id,
               b.quantity,
               b.bill_unit_code,
               bu.pound_conv,
               b.quantity * bu.pound_conv,
               bu.bill_unit_code,
               b.quantity,
               bu.pound_conv,
               ( b.quantity * bu.pound_conv )        AS pounds,
               ( b.quantity * bu.pound_conv ) / 2000 AS tons,
               SUM(total_extended_amt)               AS total
        FROM   BILLING b WITH(NOLOCK)
               INNER JOIN PROFITCENTER pr WITH(NOLOCK)
                 ON b.company_id = pr.company_id
                    AND b.profit_ctr_id = pr.profit_ctr_id
               INNER JOIN PROFILE p WITH(NOLOCK)
                 ON b.profile_id = p.profile_id
               INNER JOIN PROFILEQUOTEAPPROVAL pqa WITH(NOLOCK)
                 ON p.profile_id = pqa.profile_id
                    AND b.company_id = pqa.company_id
                    AND b.profit_ctr_id = pqa.profit_ctr_id
               LEFT OUTER JOIN DISPOSALSERVICE d WITH(NOLOCK)
                 ON pqa.disposal_service_id = d.disposal_service_id
               LEFT OUTER JOIN billunit bu WITH(NOLOCK)
                 ON b.bill_unit_code = bu.bill_unit_code
        WHERE  b.status_code = 'I'
               AND pr.status = 'A'
               AND b.trans_source = 'R'
               AND b.trans_type = 'D'
               AND b.invoice_date BETWEEN @StartDate AND @EndDate
               -- AND b.company_id = 3 AND b.profit_ctr_id = 1 -- AND b.receipt_id = 1185353
        GROUP  BY b.receipt_id,
               b.company_id,
               b.profit_ctr_id,
               b.line_id,
               b.quantity,
               b.bill_unit_code,
               bu.pound_conv,
               b.quantity * bu.pound_conv,
               bu.bill_unit_code,
               b.quantity,
               bu.pound_conv,
               ( b.quantity * bu.pound_conv )        ,
               ( b.quantity * bu.pound_conv ) / 2000 
        ORDER  BY b.receipt_id,
               b.company_id,
               b.profit_ctr_id,
               b.line_id,
               b.quantity,
               b.bill_unit_code
              
            */

/*
SELECT 
        DATEPART(YYYY, b.invoice_date) AS invoice_year, 
        DATEPART(M, b.invoice_date) AS invoice_month, 
        ISNULL(d.disposal_service_desc, 'Undefined') AS disposal_service, 
        sum((b.quantity * bu.pound_conv)) /2000 as tons,
        sum((b.quantity * bu.gal_conv)) as gallons,
        SUM(total_extended_amt) AS total 
    FROM
        BILLING b
        INNER JOIN PROFITCENTER pr
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        INNER JOIN PROFILE p 
            ON b.profile_id = p.profile_id
        INNER JOIN PROFILEQUOTEAPPROVAL pqa 
            ON p.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id 
            AND b.profit_ctr_id = pqa.profit_ctr_id
        LEFT OUTER JOIN DISPOSALSERVICE d 
            ON pqa.disposal_service_id = d.disposal_service_id
        left outer join billunit bu 
             on b.bill_unit_code = bu.bill_unit_code
    WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
        AND b.company_id = 2
        AND b.profit_ctr_id = 21
    GROUP BY 
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc
    ORDER BY
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        SUM(total_extended_amt) desc,
        d.disposal_service_desc
*/

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_disposalservice_corporate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_disposalservice_corporate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_disposalservice_corporate] TO [EQAI]
    AS [dbo];

