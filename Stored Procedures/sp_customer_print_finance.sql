CREATE PROCEDURE sp_customer_print_finance 
	@debug		int, 
	@cust_list	varchar(8000)
AS
/*****************************************************************************
This SP collects customer finance info from the Epicor databases for printing.
Loaded to Plt_AI

PB Object(s):	d_customer_print_finance
		d_customer_print_finance_data
		w_customer_print
SQL Object(s):	None
 
04/18/2002 SCC	Created
02/01/2003 JDB	Changed NTSQL4 to NTSQL5
03/24/2003 JDB	Modified to use company 15
08/13/2003 PD	Modified to use company 17
11/25/2003 JDB	Modified to use company 18, 21, 22, 23, 24
01/24/2006 JDB	Modified to return address 2-6 instead of 1-5 because
		address 1 equals the address name.
05/04/2010 JDB	Added databases 25 through 28.
08/06/2010 JDB	Added database 29.
04/22/2012 JDB	Added database 32.

sp_customer_print_finance 1, '70,185,200'
*****************************************************************************/
DECLARE	@idx		int,
	@cust_id	int,
	@pos		int,
	@tmp_list	varchar(8000)

CREATE TABLE #tmp_cust (
	customer_id int NULL	)

-- Parse the customer list
SELECT @tmp_list = @cust_list
SELECT @pos = CHARINDEX(',', @tmp_list, 1)
WHILE @pos > 0
BEGIN
	SELECT @cust_id = CONVERT(int, SUBSTRING(@tmp_list, 1, @pos - 1))
	IF @debug = 1 PRINT 'cust_id: ' + CONVERT(varchar(10), @cust_id)
	INSERT #tmp_cust VALUES (@cust_id)
	IF @debug = 1 SELECT * FROM #tmp_cust
	SELECT @tmp_list = SUBSTRING(@tmp_list, @pos + 1, DATALENGTH(@tmp_list) - @pos)
	IF @debug = 1 PRINT '@tmp_list: ' + @tmp_list
	SELECT @pos = CHARINDEX(',', @tmp_list, 1)
	IF @debug = 1 PRINT '@pos: ' + CONVERT(varchar(10), @pos)
END
IF @pos = 0
BEGIN
	SELECT @cust_id = CONVERT(int, @tmp_list)
	INSERT #tmp_cust VALUES (@cust_id)
END

IF @debug = 1 
BEGIN
	PRINT 'Selecting from #tmp_cust'
	SELECT * FROM #tmp_cust
	PRINT 'done with table'
END

DELETE FROM CustomerPrint WHERE customer_id IN (SELECT customer_id FROM #tmp_cust)

INSERT CustomerPrint
SELECT	DISTINCT '02' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e02.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )   
UNION ALL
SELECT	DISTINCT '03' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e03.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )   
UNION ALL
SELECT	DISTINCT '12' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e12.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )   
UNION ALL
SELECT  DISTINCT '14' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e14.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )  
UNION ALL
SELECT  DISTINCT '15' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e15.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '17' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e17.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '18' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e18.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '21' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e21.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '22' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e22.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '23' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e23.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '24' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e24.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '25' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e25.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '26' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e26.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '27' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e27.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '28' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e28.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '29' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e29.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
UNION ALL
SELECT  DISTINCT '32' AS company_code,
	#tmp_cust.customer_id,
	AR.address_name ,
        AR.addr2 ,
        AR.addr3 ,
        AR.addr4 ,
        AR.addr5 ,
        AR.addr6 ,
        AR.status_type ,
        AR.attention_name ,
        AR.attention_phone ,
        AR.phone_1 ,
        AR.phone_2 ,
        AR.posting_code ,
        AR.territory_code ,
        AR.salesperson_code ,
        AR.credit_limit 
FROM NTSQLFINANCE.e32.dbo.armaster AR, #tmp_cust
WHERE ( CONVERT(int, AR.customer_code) = #tmp_cust.customer_id )
ORDER BY customer_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_print_finance] TO [EQAI]
    AS [dbo];

