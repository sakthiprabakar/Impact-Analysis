--USE ECOL_D365Integration

/****** Object:  StoredProcedure [dbo].[sp_get_all_ax_customers]    Script Date: 9/18/2019 12:32:03 PM ******/

 --devops 12416 AESOP:  Customer pop-up list OE   note this needs to be run ECOL_D365Integration database
 USE [ECOL_D365Integration]
GO


alter  procedure [dbo].[sp_get_all_ax_customers]
       @first_letter nvarchar(10)
as

SELECT c.d365_accountnum  ax_customer_id
       ,  c.d365_accountnum  AS ax_invoice_customer_id
       , c.cust_name AS cust_name
       , c.physical_address_1 AS cust_addr1
       , c.physical_address_2   AS cust_addr2
       , c.physical_address_3 AS cust_addr3
       , c.physical_address_4 AS cust_addr4
       , c.physical_city AS cust_city
       , c.physical_state AS cust_state
       , c.physical_zip_code  AS cust_zip_code
       , c.physical_country AS cust_country
       , c.billing_name AS bill_to_cust_name
       , c.billing_address_1 AS   bill_to_addr1
       , c.billing_address_2 AS bill_to_addr2
       , c.billing_address_3 AS bill_to_addr3
       , c.billing_address_4 AS bill_to_addr4
       , c.billing_city AS  bill_to_city
       , c.billing_state   AS bill_to_state
       , c.billing_zip_code AS bill_to_zip_code
       , c.billing_country  AS bill_to_country
       , c.phone as cust_phone
       , c.fax as cust_fax
       , ROUND(c.credit_max, 2) AS credit_limit
       , c.line_of_business_id AS cust_naics_code
       , CASE WHEN c.cust_group = 'IC' THEN 'T' ELSE 'F' END AS eq_flag
       --, c.cust_group AS customer_type
          , c.company_chain_id AS customer_type
       , ISNULL(c.url, '') AS customer_website
FROM  CustomerSync c
where  c.cust_name like  @first_letter + '%'




return 0




 

--create procedure sp_get_all_ax_customers
--	@first_letter nvarchar(10)
--as
--declare @sql varchar(max)

---- rb Needs to initially be created in AX_TRAIN because the datawindow was connecting there
--create table #physical_address (
--	ax_customer_id nvarchar(20) not null,
--	street nvarchar(250) null,
--	city nvarchar(60) null,
--	state nvarchar(10) null,
--	zipcode nvarchar(10) null,
--	countryregionid nvarchar(10) null
--)

--create table #billing_address (
--	ax_customer_id nvarchar(20) not null,
--	description nvarchar(250) null,
--	street nvarchar(250) null,
--	city nvarchar(60) null,
--	state nvarchar(10) null,
--	zipcode nvarchar(10) null,
--	countryregionid nvarchar(10) null
--)

--set @sql = '
--insert #physical_address
--select c.accountnum,
--		lpa.street,
--		lpa.city,
--		lpa.state,
--		lpa.zipcode,
--		lpa.countryregionid
--from custtable c
--join dirpartylocation dpl
--	on dpl.party = c.party
--	and dpl.ISPOSTALADDRESS = 1
--join logisticslocation ll
--	on ll.recid = dpl.location
--	and ll.partition = dpl.partition
--join logisticspostaladdress lpa
--	on lpa.location = ll.recid
--	and lpa.partition = ll.partition
--join dirpartylocationrole dlr
--	on dlr.partylocation = dpl.recid
--join logisticslocationrole llr
--	on llr.recid = dlr.locationrole
--    and llr.name = ''Business''
--join dirpartytable dp
--	on dp.recid = c.party
--	and dp.name like ''' + @first_letter + '%''
--where c.blocked = 0
--and c.dataareaid = ''USA''
--and lpa.validfrom = (select max(validfrom) from logisticspostaladdress where location = lpa.location and partition = lpa.partition)'
--/*
--group by c.accountnum,
--		lpa.street,
--		lpa.city,
--		lpa.state,
--		lpa.zipcode,
--		lpa.countryregionid,
--		lpa.validfrom
--having lpa.validfrom = max(lpa.validfrom)'
--*/

--execute(@sql)

--set @sql = '
--insert #billing_address
--select c.accountnum,
--		ll.description,
--		lpa.street,
--		lpa.city,
--		lpa.state,
--		lpa.zipcode,
--		lpa.countryregionid
--from custtable c
--join dirpartylocation dpl
--	on dpl.party = c.party
--	and dpl.ISPOSTALADDRESS = 1
--join logisticslocation ll
--	on ll.recid = dpl.location
--	and ll.partition = dpl.partition
--join logisticspostaladdress lpa
--	on lpa.location = ll.recid
--	and lpa.partition = ll.partition
--join dirpartylocationrole dlr
--	on dlr.partylocation = dpl.recid
--join logisticslocationrole llr
--	on llr.recid = dlr.locationrole
--    and llr.name = ''Invoice''
--join DirPartyTable dp
--	on dp.recid = c.party
--	and dp.name like ''' + @first_letter + '%''
--where c.blocked = 0
--and c.dataareaid = ''USA''
--and lpa.validfrom = (select max(validfrom) from logisticspostaladdress where location = lpa.location and partition = lpa.partition)'
--/*
--group by c.accountnum,
--		ll.description,
--		lpa.street,
--		lpa.city,
--		lpa.state,
--		lpa.zipcode,
--		lpa.countryregionid,
--		lpa.validfrom
--having lpa.validfrom = max(lpa.validfrom)'
--*/

--execute(@sql)

--set @sql = '
--SELECT c.ACCOUNTNUM AS ax_customer_id
--       , ISNULL(c.INVOICEACCOUNT, '''') AS ax_invoice_customer_id
--       , dp.NAME AS cust_name
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_b.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[1]'', ''nvarchar(250)''), '''') AS cust_addr1
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_b.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[2]'', ''nvarchar(250)''), '''') AS cust_addr2
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_b.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[3]'', ''nvarchar(250)''), '''') AS cust_addr3
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_b.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[4]'', ''nvarchar(250)''), '''') AS cust_addr4
--       , ISNULL(v_b.CITY, '''') AS cust_city
--       , ISNULL(v_b.STATE, '''') AS cust_state
--       , ISNULL(v_b.ZIPCODE, '''') AS cust_zip_code
--       , ISNULL(v_b.COUNTRYREGIONID, '''') AS cust_country
--       , ISNULL(v_i.DESCRIPTION, '''') AS bill_to_cust_name
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_i.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[1]'', ''nvarchar(250)''), '''') AS bill_to_addr1
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_i.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[2]'', ''nvarchar(250)''), '''') AS bill_to_addr2
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_i.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[3]'', ''nvarchar(250)''), '''') AS bill_to_addr3
--       , COALESCE(CAST(''<line>'' + REPLACE(REPLACE(v_i.STREET, ''&'', ''&amp;''), NCHAR(13),''</line><line>'') + ''</line>'' AS xml).value(''/line[4]'', ''nvarchar(250)''), '''') AS bill_to_addr4
--       , ISNULL(v_i.CITY, '''') AS bill_to_city
--       , ISNULL(v_i.STATE, '''') AS bill_to_state
--       , ISNULL(v_i.ZIPCODE, '''') AS bill_to_zip_code
--       , ISNULL(v_i.COUNTRYREGIONID, '''') AS bill_to_country
--       , ISNULL(lea_p.LOCATOR, '''') AS cust_phone
--       , ISNULL(lea_f.LOCATOR, '''') AS cust_fax
--       , ROUND(c.CREDITMAX, 2) AS credit_limit
--       , c.LINEOFBUSINESSID AS cust_naics_code
--       , CASE WHEN c.CUSTGROUP = ''IC'' THEN ''T'' ELSE ''F'' END AS eq_flag
--       , c.COMPANYCHAINID AS customer_type
--       , ISNULL(lea_u.LOCATOR, '''') AS customer_website
--FROM CUSTTABLE c
--JOIN DIRPARTYTABLE dp
--	on dp.RECID = c.PARTY
--	and dp.name like ''' + @first_letter + '%''
--LEFT OUTER JOIN #physical_address v_b
--	on v_b.ax_customer_id = c.accountnum
--LEFT OUTER JOIN #billing_address v_i
--	on v_i.ax_customer_id = c.accountnum
--LEFT OUTER JOIN logisticselectronicaddress lea_p ON lea_p.RECID = dp.PRIMARYCONTACTPHONE
--LEFT OUTER JOIN logisticselectronicaddress lea_f ON lea_f.RECID = dp.PRIMARYCONTACTFAX
--LEFT OUTER JOIN logisticselectronicaddress lea_u ON lea_u.RECID = dp.PRIMARYCONTACTURL
--WHERE c.blocked = 0
--and c.dataareaid = ''USA'''

--execute(@sql)
--return 0
