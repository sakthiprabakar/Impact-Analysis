
CREATE PROCEDURE sp_rpt_naics_revenue_validation
		@date_from			datetime	-- recognized revenue date range start
    ,	@date_to			datetime	-- recognized revenue date range end
AS
/*********************************************************************************************
sp_rpt_naics_revenue_validation

	ôSIC NAICS Revenue Validationö 

Sample:
	EXEC dbo.sp_rpt_naics_revenue_validation
                @date_from      = '12/1/2014'
                , @date_to      = '12/31/2014'


History:

	03/30/2015	JPB	Created


*********************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if datepart(hh, @date_to) = 0 set @date_to = @date_to + 0.99999

select distinct 
	'Customer' as record_type
	, c.customer_id
	, c.cust_name
	, null as epa_id
	, c.cust_sic_code as SIC
	, c.cust_naics_code as NAICS
	, c.cust_addr1
	, c.cust_addr2
	, c.cust_city
	, c.cust_state
	, c.cust_zip_code
	, c.date_added
FROM RecognizedRevenue RW
JOIN Customer C (nolock)
	ON c.customer_id = RW.customer_id
WHERE 
	RW.revenue_recognized_date between @date_from and @date_to
	and (isnull(c.cust_naics_code, '') = ''
		or isnull(c.cust_sic_code, '') = ''
	)
union all
select distinct 
	'Generator' as record_type
	, g.generator_id
	, g.generator_name
	, g.epa_id
	, g.sic_code as SIC
	, g.naics_code as NAICS
	, g.generator_address_1
	, g.generator_address_2
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.date_added
FROM RecognizedRevenue RW
JOIN Generator G (nolock)
	ON g.generator_id = RW.generator_id
WHERE 
	RW.revenue_recognized_date between @date_from and @date_to
	and (isnull(g.naics_code, '') = ''
		or isnull(g.sic_code, '') = ''
	)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_naics_revenue_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_naics_revenue_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_naics_revenue_validation] TO [EQAI]
    AS [dbo];

