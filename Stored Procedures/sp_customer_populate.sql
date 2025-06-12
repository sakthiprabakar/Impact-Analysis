CREATE PROCEDURE sp_customer_populate 
	@debug int, 
	@line_number int, 
	@update_table int
AS
/****************

Test Cmd Line:  sp_customer_populate 1, 2, 0

01/08/07 SCC Created
******************/
CREATE TABLE #tmp (
	customer_id varchar(12) NULL, 
	address_orig varchar(40) NULL, 
	address varchar(40) NULL,
	address_next_line varchar(40) NULL, 
	city varchar(40) NULL, 
	state varchar(2) NULL, 
	zip_code varchar(15) NULL, 
	comma_pos int NULL, 
	state_pos int NULL, 
	zip_pos int NULL, 
	michigan_pos int NULL, 
	ohio_pos int NULL
)

-- Setup Address line to process
if @line_number = 2
	insert #tmp select customer_id, NULLIF(ltrim(rtrim(bill_to_addr2)),''), NULLIF(ltrim(rtrim(bill_to_addr2)),''), 
		NULLIF(ltrim(rtrim(bill_to_addr3)),''), NULLIF(ltrim(rtrim(bill_to_city)),''), NULLIF(ltrim(rtrim(bill_to_state)),''), 
		NULLIF(ltrim(rtrim(bill_to_zip_code)),''), 0,0,0,0,0 FROM Customer
if @line_number = 3
	insert #tmp select customer_id, NULLIF(ltrim(rtrim(bill_to_addr3)),''), NULLIF(ltrim(rtrim(bill_to_addr3)),''), 
		NULLIF(ltrim(rtrim(bill_to_addr4)),''), NULLIF(ltrim(rtrim(bill_to_city)),''), NULLIF(ltrim(rtrim(bill_to_state)),''), 
		NULLIF(ltrim(rtrim(bill_to_zip_code)),''), 0,0,0,0,0 FROM Customer
if @line_number = 4
	insert #tmp select customer_id, NULLIF(ltrim(rtrim(bill_to_addr4)),''), NULLIF(ltrim(rtrim(bill_to_addr4)),''), 
		NULLIF(ltrim(rtrim(bill_to_addr5)),''), NULLIF(ltrim(rtrim(bill_to_city)),''), NULLIF(ltrim(rtrim(bill_to_state)),''), 
		NULLIF(ltrim(rtrim(bill_to_zip_code)),''), 0,0,0,0,0 FROM Customer
if @line_number = 5
	insert #tmp select customer_id, NULLIF(ltrim(rtrim(bill_to_addr5)),''), NULLIF(ltrim(rtrim(bill_to_addr5)),''), 
		NULL as address_next_line, NULLIF(ltrim(rtrim(bill_to_city)),''), NULLIF(ltrim(rtrim(bill_to_state)),''), 
		NULLIF(ltrim(rtrim(bill_to_zip_code)),''), 0,0,0,0,0 FROM Customer

-- ************************************************************************
-- PREPROCESS ADDRESS LINES TO REPLACE CITY STATE AND ZIP *
-- ************************************************************************
UPDATE #TMP SET address = REPLACE(address, '.', '')
UPDATE #TMP SET city = 'KING OF PRUSSIA', address = REPLACE(address, 'KING OF PRUSIA', ' ')
	WHERE address like '%KING OF PRUSIA%'
UPDATE #TMP SET city = 'KING OF PRUSSIA', address = REPLACE(address, 'KING OF PRUSSA', ' ')
	WHERE address like '%KING OF PRUSSA%'
UPDATE #TMP SET city = 'KING OF PRUSSIA', address = REPLACE(address, 'KING OF PRUSSIA', ' ')
	WHERE address like '%KING OF PRUSSIA%'
UPDATE #TMP SET city = 'FON DU LAC', address = REPLACE(address, 'FON DU LAC', ' ')
	WHERE address like '%FON DU LAC%'
UPDATE #TMP SET city = 'HAVRE DE GRACE', address = REPLACE(address, 'HAVRE DE GRACE', ' ')
	WHERE address like '%HAVRE DE GRACE%'
UPDATE #TMP SET city = 'SOUTH EL MONTE', address = REPLACE(address, 'SOUTH EL MONTE', ' ')
	WHERE address like '%SOUTH EL MONTE%'
UPDATE #TMP SET city = 'SANTA FE SPRINGS', address = REPLACE(address, 'SANTA FE SPRINGS', ' ')
	WHERE address like '%SANTA FE SPRINGS%'
UPDATE #TMP SET city = 'EAST ST LOUIS', address = REPLACE(address, 'EAST ST LOUIS', ' ')
	WHERE address like '%EAST ST LOUIS%'
UPDATE #TMP SET city = 'LAKE IN THE HILLS', address = REPLACE(address, 'LAKE IN THE HILLS', ' ')
	WHERE address like '%LAKE IN THE HILLS%'
UPDATE #TMP SET city = 'VILLAGE OF DEXTER', address = REPLACE(address, 'VILLAGE OF DEXTER', ' ')
	WHERE address like '%VILLAGE OF DEXTER%'
UPDATE #TMP SET city = 'INDIANAPOLIS', address = REPLACE(address, 'INDIANAPOLIS', ' ')
	WHERE address like '%INDIANAPOLIS%'
UPDATE #TMP SET state = 'ON', address = REPLACE(address, 'ONTARIO', ' ')
	WHERE address like '%ONTARIO%'
UPDATE #TMP SET address = REPLACE(address, ' ARKANSAS', ' AR ')
UPDATE #TMP SET address = REPLACE(address, ' GEORGIA', ' GA ')
UPDATE #TMP SET address = REPLACE(address, ' MICHIGAN', ' MI')
UPDATE #TMP SET address = REPLACE(address, ' MICH', ' MI')
UPDATE #TMP SET address = REPLACE(address, ' ILLINOIS', ' IL')
UPDATE #TMP SET address = REPLACE(address, ' ILLINIOS', ' IL')
UPDATE #TMP SET address = REPLACE(address, ' INDIANA', ' IN')
UPDATE #TMP SET address = REPLACE(address, ' NEVADA', ' NV')
UPDATE #TMP SET address = REPLACE(address, ' OREGON', ' OR')
UPDATE #TMP SET address = REPLACE(address, ' IN,', ', IN')
UPDATE #TMP SET address = REPLACE(address, ' KENTUCKY', ' KY')
UPDATE #TMP SET address = REPLACE(address, ' TENNESSEE', ' TN')
UPDATE #TMP SET address = REPLACE(address, ' TEXAS', ' TX')
UPDATE #TMP SET address = REPLACE(address, ' WEST VIRGINIA', ' WV')
UPDATE #TMP SET address = REPLACE(address, ' WVA ', ' WV ')
UPDATE #TMP SET address = REPLACE(address, ' OHIO', ' OH')
UPDATE #TMP SET address = REPLACE(address, ' OH,', ', OH')
UPDATE #TMP SET address = REPLACE(address, ' CT,', ', CT')
UPDATE #TMP SET address = REPLACE(address, ' NJ,', ', NJ')
UPDATE #TMP SET address = REPLACE(address, ' GA,', ', GA')
UPDATE #TMP SET address = REPLACE(address, ' NY,', ', NY')
UPDATE #TMP SET address = REPLACE(address, ' PA,', ', PA')
UPDATE #TMP SET address = REPLACE(address, ' WA,', ', WA')
UPDATE #TMP SET address = REPLACE(address, ' TN,', ', TN')
UPDATE #TMP SET address = REPLACE(address, ' DC,', ', DC')
UPDATE #TMP SET address = REPLACE(address, ' MI,', ', MI')
UPDATE #TMP SET address = REPLACE(address, ' MD,', ', MD')
UPDATE #TMP SET address = REPLACE(address, ' MA,', ', MA')
UPDATE #TMP SET address = REPLACE(address, ' ON,', ', ON')
UPDATE #TMP SET address = REPLACE(address, ' ONT ', ' ON ')
UPDATE #TMP SET address = REPLACE(address, IsNull(zip_code, 'junk12345'), ' ')
UPDATE #TMP SET address = REPLACE(address, IsNull(city, 'junk12345'), ' ')
UPDATE #TMP SET address = Substring(address, 1, datalength(address) - 1) WHERE Substring(address, datalength(address), 1) = ','

-- ************************************************************************
-- FIND AN EMBEDDED ZIP CODE.  Easiest thing to find
-- ************************************************************************
update #tmp SET zip_pos = 0
update #tmp set zip_pos = patindex('% [0-9][0-9][0-9][0-9][0-9]%',address)
	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
update #tmp set zip_code = substring(address, zip_pos+1, datalength(address) - (zip_pos)),
	address = REPLACE(address, substring(address, zip_pos+1, datalength(address) - (zip_pos)), ' ')  
	where zip_pos > 0 and IsNull(zip_code,'') = '' and (datalength(address) - (zip_pos) <= 15)

-- ************************************************************************
-- FIND AN EMBEDDED ZIP CODE +4
-- ************************************************************************
update #tmp SET zip_pos = 0
update #tmp set zip_pos = patindex('% [0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]%',address)
	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
update #tmp set zip_code = substring(address, zip_pos+1, 10),
	address = REPLACE(address, substring(address, zip_pos+1, 10), ' ')  
	where zip_pos > 0 and IsNull(zip_code,'') = '' 

-- *********************************************************************
-- FIND DATA ON NON FORMATTED LINES *
-- *********************************************************************
update #tmp set comma_pos = 0, state_pos = 0, michigan_pos = 0, ohio_pos = 0
-- Try to find a state abbrev with a space before it
update #tmp set state_pos = patindex('% [A-Z][A-Z] %',address)
	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- Try to find a state abbrev with a comma before it
update #tmp set state_pos = patindex('%,[A-Z][A-Z] %',address)
	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
if @debug = 1 select * from #tmp where customer_id = 'AIRCRAFT'
-- Find the city in the line
update #tmp set city = substring(address, 1, state_pos - 1), 
	address = REPLACE(address,substring(address, 1, state_pos - 1), ' ') 
	where state_pos > 0 and IsNull(city,'') = '' 
if @debug = 1 select * from #tmp where customer_id = 'AIRCRAFT'
-- City and comma
update #tmp set comma_pos = patindex('%,%', address) WHERE IsNull(address,'') <> ''
update #tmp set city = substring(address, 1, comma_pos - 1),
	address = REPLACE(address,substring(address, 1, comma_pos - 1), ' ') 
	where comma_pos > 0 and IsNull(city,'') = ''
if @debug = 1 select * from #tmp where customer_id = 'AIRCRAFT'
-- Get the new state pos
update #tmp set comma_pos = 0, state_pos = 0, michigan_pos = 0, ohio_pos = 0
-- Find a state abbrev with a space before it
update #tmp set state_pos = patindex('% [A-Z][A-Z] %',address)
	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- Find a state abbrev with a comma before it
update #tmp set state_pos = patindex('%,[A-Z][A-Z] %',address)
	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- Replace the state
update #tmp set state = substring(address, state_pos+1, 2),
	address = REPLACE(address,substring(address, state_pos+1, 2), '  ') 
	where state_pos > 0 and IsNull(state,'') = ''
-- Update the zip for Ontario
update #tmp set zip_code = ltrim(substring(address, state_pos+4, datalength(address) - (state_pos+3))),
	address = REPLACE(address,ltrim(substring(address, state_pos+4, datalength(address) - (state_pos+3))), ' ') 
	where state_pos > 0 and IsNull(zip_code,'') = '' and state = 'ON'

-- *********************************************************************
-- FIND ZIP CODE AT THE BEGINNING OF THE LINE *
-- *********************************************************************
update #tmp set zip_pos = 0
update #tmp set zip_pos = patindex('[0-9][0-9][0-9][0-9][0-9]',address)
	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
update #tmp set zip_code = substring(address,1,5), address = NULL where zip_pos > 0 and IsNull(zip_code,'') = ''

-- *********************************************************************
-- FIND ZIP CODE +4 AT THE BEGINNING OF THE LINE *
-- *********************************************************************
update #tmp set zip_pos = 0
update #tmp set zip_pos = patindex('[0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]',address)
	where IsNull(address,'') <> '' and IsNull(zip_code,'') = '' and IsNull(address_next_line,'') = ''
update #tmp set zip_code = substring(address,1,5), address = NULL where zip_pos > 0 and IsNull(zip_code,'') = ''

-- *********************************************************************
-- FIND DATA THAT HAS BEEN UNDECTABLE, SO FAR *
-- *********************************************************************
update #tmp set state_pos = 0
-- Look for a 2 character state reference at the end of the line - address line 2
update #tmp set state_pos = patindex('% [A-Z][A-Z]',address)
	where IsNull(address,'') <> '' and IsNull(address_next_line,'') = '' 
-- Find the city in the line where the state was found
update #tmp set city = substring(address, 1, state_pos - 1),
	address = REPLACE(address,substring(address, 1, state_pos - 1), ' ')  
	where state_pos > 0 and IsNull(city,'') = '' 
-- Now update the state
update #tmp set state = substring(address, state_pos+1, 2),
	address = REPLACE(address, substring(address, state_pos+1, 2), '  ')  
	where state_pos > 0 and IsNull(state,'') = ''

-- Update for everything processed so far
update #tmp set city = replace(city, ',','') where IsNull(city, '') <> ''
update #tmp set address = replace(address, ',',' ') where IsNull(address, '') <> ''
update #tmp set address = REPLACE(address, ' ' + IsNull(' ' + state, 'junk12345'), '   ')
update #tmp set address = ltrim(rtrim(address)), city = ltrim(rtrim(city)), state = ltrim(rtrim(state)), zip_code = ltrim(rtrim(zip_code))

-- If a state reference is left in the field, assign to state
update #tmp set state_pos = 0
update #tmp set state_pos = patindex('[A-Z][A-Z]', address) WHERE IsNull(address_next_line,'') = '' and datalength(ltrim(rtrim(address))) = 2
update #tmp set state = address, address = NULL where state_pos > 0

if @debug = 1 print 'Successfully extracted city, state, and zip for these Customers'
if @debug = 1 select customer_id, address_orig, IsNull(address,'') as address, city, state, zip_code, address_next_line from #tmp where IsNull(address,'') = ''


-- *********************************
-- UPDATE THE REAL Customer TABLE *
-- *********************************
if @update_table = 1
begin

	if @line_number = 2
		UPDATE Customer SET bill_to_addr2 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
	if @line_number = 3
		UPDATE Customer SET bill_to_addr3 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
	if @line_number = 4
		UPDATE Customer SET bill_to_addr4 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
	if @line_number = 5
		UPDATE Customer SET bill_to_addr5 = NULLIF(address,''), bill_to_city = NULLIF(city,''), 
			bill_to_state = NULLIF(state,''), bill_to_zip_code = NULLIF(zip_code,'')
		FROM #tmp WHERE #tmp.customer_id = Customer.customer_id
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_populate] TO [EQAI]
    AS [dbo];

