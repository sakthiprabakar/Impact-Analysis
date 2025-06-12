CREATE PROCEDURE sp_customer_billing_addr 
	@debug int
AS
/****************
01/08/07 SCC Created

sp_customer_billing_addr 1
******************/
CREATE TABLE #tmp (
	customer_id int NULL, 
	customer_code varchar(8) NULL,
	addr2_orig varchar(40) NULL,
	addr2_new varchar(40) NULL,
	addr3_orig varchar(40) NULL,
	addr3_new varchar(40) NULL,
	addr4_orig varchar(40) NULL,
	addr4_new varchar(40) NULL,
	addr5_orig varchar(40) NULL,
	addr5_new varchar(40) NULL,
	addr6_orig varchar(40) NULL,
	addr6_new varchar(40) NULL,
	city varchar(40) NULL, 
	state varchar(40) NULL, 
	zip_code varchar(15) NULL, 
	country varchar(40) NULL
)
-- Get the addresses in E01
INSERT #tmp 
SELECT 
customer_id,
customer_code,
LTRIM(RTRIM(addr2)),
LTRIM(RTRIM(addr2)),
LTRIM(RTRIM(addr3)),
LTRIM(RTRIM(addr3)),
LTRIM(RTRIM(addr4)),
LTRIM(RTRIM(addr4)),
LTRIM(RTRIM(addr5)),
LTRIM(RTRIM(addr5)),
LTRIM(RTRIM(addr6)),
LTRIM(RTRIM(addr6)),
LTRIM(RTRIM(city)), 
LTRIM(RTRIM(state)), 
LTRIM(RTRIM(postal_code)), 
LTRIM(RTRIM(country))
FROM armaster

-- Find the country
-- Line 6
UPDATE #tmp
SET country = SUBSTRING(C.country_name, 1, 40)
FROM Country C
WHERE IsNull(CHARINDEX(C.country_name , #tmp.addr6_orig),0) <> 0
AND IsNull(#tmp.country,'') = ''
-- Line 5
UPDATE #tmp
SET country = SUBSTRING(C.country_name, 1, 40)
FROM Country C
WHERE IsNull(CHARINDEX(C.country_name , #tmp.addr5_orig),0) <> 0
AND IsNull(#tmp.country,'') = ''
-- Line 4
UPDATE #tmp
SET country = SUBSTRING(C.country_name, 1, 40)
FROM Country C
WHERE IsNull(CHARINDEX(C.country_name , #tmp.addr4_orig),0) <> 0
AND IsNull(#tmp.country,'') = ''
-- Line 3
UPDATE #tmp
SET country = SUBSTRING(C.country_name, 1, 40)
FROM Country C
WHERE IsNull(CHARINDEX(C.country_name , #tmp.addr3_orig),0) <> 0
AND IsNull(#tmp.country,'') = ''
-- Line 2
UPDATE #tmp
SET country = SUBSTRING(C.country_name, 1, 40)
FROM Country C
WHERE IsNull(CHARINDEX(C.country_name , #tmp.addr2_orig),0) <> 0
AND IsNull(#tmp.country,'') = ''

-- Blank out the country
-- UPDATE #tmp SET addr6_orig = REPLACE(addr6_orig, country, '')
-- UPDATE #tmp SET addr5_orig = REPLACE(addr5_orig, country, '')
-- UPDATE #tmp SET addr4_orig = REPLACE(addr4_orig, country, '')
-- UPDATE #tmp SET addr3_orig = REPLACE(addr3_orig, country, '')
-- UPDATE #tmp SET addr2_orig = REPLACE(addr2_orig, country, '')

-- IF @debug = 1 print 'selecting after country'
-- IF @debug = 1 select * from #tmp where IsNull(#tmp.country,'') <> ''

-- Find the state
-- Line 6
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.state_name , #tmp.addr6_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 5
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.state_name , #tmp.addr5_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 4
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.state_name , #tmp.addr4_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 3
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.state_name , #tmp.addr3_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 2
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.state_name , #tmp.addr2_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Blank out the state
-- UPDATE #tmp SET addr6_orig = REPLACE(addr6_orig, S.state_name, '') From StateAbbreviation S WHERE state = S.abbr
-- UPDATE #tmp SET addr5_orig = REPLACE(addr5_orig, S.state_name, '') From StateAbbreviation S WHERE state = S.abbr
-- UPDATE #tmp SET addr4_orig = REPLACE(addr4_orig, S.state_name, '') From StateAbbreviation S WHERE state = S.abbr
-- UPDATE #tmp SET addr3_orig = REPLACE(addr3_orig, S.state_name, '') From StateAbbreviation S WHERE state = S.abbr
-- UPDATE #tmp SET addr2_orig = REPLACE(addr2_orig, S.state_name, '') From StateAbbreviation S WHERE state = S.abbr
-- Line 6
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.abbr , #tmp.addr6_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 5
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.abbr , #tmp.addr5_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 4
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.abbr , #tmp.addr4_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 3
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.abbr , #tmp.addr3_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''
-- Line 2
UPDATE #tmp
SET state = SUBSTRING(S.abbr, 1, 40)
FROM StateAbbreviation S
WHERE IsNull(CHARINDEX(S.abbr , #tmp.addr2_orig),0) <> 0
AND IsNull(#tmp.state,'') = ''

-- Blank out the state abbr
-- UPDATE #tmp SET addr6_orig = REPLACE(addr6_orig, state, '')
-- UPDATE #tmp SET addr5_orig = REPLACE(addr5_orig, state, '')
-- UPDATE #tmp SET addr4_orig = REPLACE(addr4_orig, state, '')
-- UPDATE #tmp SET addr3_orig = REPLACE(addr3_orig, state, '')
-- UPDATE #tmp SET addr2_orig = REPLACE(addr2_orig, state, '')
-- 
-- IF @debug = 1 print 'selecting after state'
-- IF @debug = 1 select * from #tmp where IsNull(#tmp.state,'') <> ''

-- Find the zip
-- Line 6
UPDATE #tmp
SET zip_code = SUBSTRING(#tmp.addr6_orig, patindex('% [0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]%',#tmp.addr6_orig), 10)
WHERE IsNull(patindex('% [0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]%',#tmp.addr6_orig),0) > 0
AND IsNull(#tmp.zip_code,'') = ''
UPDATE #tmp
SET zip_code = SUBSTRING(#tmp.addr6_orig, patindex('% [0-9][0-9][0-9][0-9][0-9]]%',#tmp.addr6_orig), 10)
WHERE IsNull(patindex('% [0-9][0-9][0-9][0-9][0-9]%',#tmp.addr6_orig),0) > 0
AND IsNull(#tmp.zip_code,'') = ''

IF @debug = 1 print 'selecting after zip'
IF @debug = 1 select * from #tmp where IsNull(#tmp.zip_code,'') <> ''

-- update #tmp set zip_pos = patindex('% [0-9][0-9][0-9][0-9][0-9]%',address)
-- 	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
-- update #tmp set zip_code = substring(address, zip_pos+1, datalength(address) - (zip_pos)),
-- 	address = REPLACE(address, substring(address, zip_pos+1, datalength(address) - (zip_pos)), ' ')  
-- 	where zip_pos > 0 and IsNull(zip_code,'') = '' and (datalength(address) - (zip_pos) <= 15)
-- 
-- -- ************************************************************************
-- -- FIND AN EMBEDDED ZIP CODE +4
-- -- ************************************************************************
-- update #tmp SET zip_pos = 0

-- -- ************************************************************************
-- -- FIND AN EMBEDDED ZIP CODE.  Easiest thing to find
-- -- ************************************************************************
-- update #tmp SET zip_pos = 0
-- update #tmp set zip_pos = patindex('% [0-9][0-9][0-9][0-9][0-9]%',address)
-- 	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
-- update #tmp set zip_code = substring(address, zip_pos+1, datalength(address) - (zip_pos)),
-- 	address = REPLACE(address, substring(address, zip_pos+1, datalength(address) - (zip_pos)), ' ')  
-- 	where zip_pos > 0 and IsNull(zip_code,'') = '' and (datalength(address) - (zip_pos) <= 15)
-- 
-- -- ************************************************************************
-- -- FIND AN EMBEDDED ZIP CODE +4
-- -- ************************************************************************
-- update #tmp SET zip_pos = 0
-- update #tmp set zip_pos = patindex('% [0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]%',address)
-- 	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
-- update #tmp set zip_code = substring(address, zip_pos+1, 10),
-- 	address = REPLACE(address, substring(address, zip_pos+1, 10), ' ')  
-- 	where zip_pos > 0 and IsNull(zip_code,'') = '' 
-- 
-- -- *********************************************************************
-- -- FIND DATA ON NON FORMATTED LINES *
-- -- *********************************************************************
-- update #tmp set comma_pos = 0, state_pos = 0, michigan_pos = 0, ohio_pos = 0
-- -- Try to find a state abbrev with a space before it
-- update #tmp set state_pos = patindex('% [A-Z][A-Z] %',address)
-- 	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- -- Try to find a state abbrev with a comma before it
-- update #tmp set state_pos = patindex('%,[A-Z][A-Z] %',address)
-- 	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- if @debug = 1 select * from #tmp where customer_id = 'AIRCRAFT'
-- -- Find the city in the line
-- update #tmp set city = substring(address, 1, state_pos - 1), 
-- 	address = REPLACE(address,substring(address, 1, state_pos - 1), ' ') 
-- 	where state_pos > 0 and IsNull(city,'') = '' 
-- if @debug = 1 select * from #tmp where customer_id = 'AIRCRAFT'
-- -- City and comma
-- update #tmp set comma_pos = patindex('%,%', address) WHERE IsNull(address,'') <> ''
-- update #tmp set city = substring(address, 1, comma_pos - 1),
-- 	address = REPLACE(address,substring(address, 1, comma_pos - 1), ' ') 
-- 	where comma_pos > 0 and IsNull(city,'') = ''
-- if @debug = 1 select * from #tmp where customer_id = 'AIRCRAFT'
-- -- Get the new state pos
-- update #tmp set comma_pos = 0, state_pos = 0, michigan_pos = 0, ohio_pos = 0
-- -- Find a state abbrev with a space before it
-- update #tmp set state_pos = patindex('% [A-Z][A-Z] %',address)
-- 	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- -- Find a state abbrev with a comma before it
-- update #tmp set state_pos = patindex('%,[A-Z][A-Z] %',address)
-- 	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- -- Replace the state
-- update #tmp set state = substring(address, state_pos+1, 2),
-- 	address = REPLACE(address,substring(address, state_pos+1, 2), '  ') 
-- 	where state_pos > 0 and IsNull(state,'') = ''
-- -- Update the zip for Ontario
-- update #tmp set zip_code = ltrim(substring(address, state_pos+4, datalength(address) - (state_pos+3))),
-- 	address = REPLACE(address,ltrim(substring(address, state_pos+4, datalength(address) - (state_pos+3))), ' ') 
-- 	where state_pos > 0 and IsNull(zip_code,'') = '' and state = 'ON'
-- 
-- -- *********************************************************************
-- -- FIND ZIP CODE AT THE BEGINNING OF THE LINE *
-- -- *********************************************************************
-- update #tmp set zip_pos = 0
-- update #tmp set zip_pos = patindex('[0-9][0-9][0-9][0-9][0-9]',address)
-- 	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
-- update #tmp set zip_code = substring(address,1,5), address = NULL where zip_pos > 0 and IsNull(zip_code,'') = ''
-- 
-- -- *********************************************************************
-- -- FIND ZIP CODE +4 AT THE BEGINNING OF THE LINE *
-- -- *********************************************************************
-- update #tmp set zip_pos = 0
-- update #tmp set zip_pos = patindex('[0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]',address)
-- 	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
-- update #tmp set zip_code = substring(address,1,5), address = NULL where zip_pos > 0 and IsNull(zip_code,'') = ''
-- 
-- -- *********************************************************************
-- -- FIND DATA THAT HAS BEEN UNDECTABLE, SO FAR *
-- -- *********************************************************************
-- update #tmp set state_pos = 0
-- -- Look for a 2 character state reference at the end of the line - address line 2
-- update #tmp set state_pos = patindex('% [A-Z][A-Z]',address)
-- 	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- -- Find the city in the line where the state was found
-- update #tmp set city = substring(address, 1, state_pos - 1),
-- 	address = REPLACE(address,substring(address, 1, state_pos - 1), ' ')  
-- 	where state_pos > 0 and IsNull(city,'') = '' 
-- -- Now update the state
-- update #tmp set state = substring(address, state_pos+1, 2),
-- 	address = REPLACE(address, substring(address, state_pos+1, 2), '  ')  
-- 	where state_pos > 0 and IsNull(state,'') = ''
-- 
-- -- Update for everything processed so far
-- update #tmp set city = replace(city, ',','') where IsNull(city, '') <> ''
-- update #tmp set address = replace(address, ',',' ') where IsNull(address, '') <> ''
-- update #tmp set address = REPLACE(address, ' ' + IsNull(' ' + state, 'junk12345'), '   ')
-- update #tmp set address = ltrim(rtrim(address)), city = ltrim(rtrim(city)), state = ltrim(rtrim(state)), zip_code = ltrim(rtrim(zip_code))
-- 
-- -- If a state reference is left in the field, assign to state
-- update #tmp set state_pos = 0
-- update #tmp set state_pos = patindex('[A-Z][A-Z]', address) WHERE IsNull(address_next_line,'') = '' and datalength(ltrim(rtrim(address))) = 2
-- update #tmp set state = address, address = NULL where state_pos > 0
-- 
-- if @debug = 1 print 'Successfully extracted city, state, and zip for these Customers'
-- if @debug = 1 select customer_id, address_orig, IsNull(address,'') as address, city, state, zip_code, address_next_line from #tmp where IsNull(address,'') = ''
-- 
-- 
-- -- *********************************
-- -- UPDATE THE REAL Customer TABLE *
-- -- *********************************
-- if @update_table = 1
-- begin
-- 
-- 	if @line_number = 2
-- 		UPDATE Customer SET bill_to_addr2 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
-- 			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
-- 		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
-- 	if @line_number = 3
-- 		UPDATE Customer SET bill_to_addr3 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
-- 			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
-- 		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
-- 	if @line_number = 4
-- 		UPDATE Customer SET bill_to_addr4 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
-- 			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
-- 		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
-- 	if @line_number = 5
-- 		UPDATE Customer SET bill_to_addr5 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
-- 			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
-- 		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
-- end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_billing_addr] TO [EQAI]
    AS [dbo];

