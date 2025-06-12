
CREATE PROCEDURE sp_dash_volume_total_disposalservice_corporate (
    @StartDate  datetime,
    @EndDate    datetime,
    @user_code  varchar(100) = NULL, -- for associates
    @contact_id int = NULL, -- for customers
    @permission_id int = NULL
)
AS
/************************************************************
Procedure    : sp_dash_volume_total_disposalservice_corporate
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the total volume per disposal service across all companies
    between @StartDate AND @EndDate

10/1/2009 - JPB Created 
09/20/2010 - JPB Added Tons, Gallons columns to output.

sp_dash_volume_total_disposalservice_corporate 
    @StartDate='2010-07-01 00:00:00',
    @EndDate='2010-07-30 23:59:59',
    @user_code='JONATHAN',
    @contact_id=-1,
    @permission_id = 84
    
************************************************************/

IF @user_code = ''
    set @user_code = NULL
    
IF @contact_id = -1
    set @contact_id = NULL

SELECT 
        DATEPART(YYYY, b.invoice_date) AS invoice_year, 
        DATEPART(M, b.invoice_date) AS invoice_month, 
        ISNULL(d.disposal_service_desc, 'Undefined') AS disposal_service, 
        sum((b.quantity * bu.pound_conv)) /2000 as tons,
        sum((b.quantity * bu.gal_conv)) as gallons
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
    GROUP BY 
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc
    ORDER BY
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        d.disposal_service_desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_volume_total_disposalservice_corporate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_volume_total_disposalservice_corporate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_volume_total_disposalservice_corporate] TO [EQAI]
    AS [dbo];

