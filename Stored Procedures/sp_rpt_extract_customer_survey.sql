
CREATE PROCEDURE sp_rpt_extract_customer_survey
	@copc_list			varchar(max),	-- Comma Separated Company List
	@date_from 			datetime, 
	@date_to 			datetime 
AS

/* ***********************************************************
Procedure    : sp_rpt_extract_customer_survey
Database     : PLT_AI
Created      : Jan 15 2009 - Jonathan Broome
Description  : Returns Customer Survey information for the web site

Examples:
	sp_rpt_extract_customer_survey '2,3,12,14,15,17,18,21,22,23,24,25,26,27,28,29,32', '12/1/2012 00:00', '12/8/2012 23:59' -- 0:17s 838 rows.
	sp_rpt_extract_customer_survey '14', '7/1/2008 00:00', '7/8/2008 23:59' -- 0:10s, 60 rows.
--BEFORE
	sp_rpt_extract_customer_survey 'All', '7/1/2015 00:00', '7/7/2015 23:59' -- 0:16s, 625 rows.
	sp_rpt_extract_customer_survey 'All', '5/1/2016 00:00', '5/31/2016 23:59' -- 3:36s, 19087 rows.
--AFTER
	sp_rpt_extract_customer_survey 'All', '7/1/2015 00:00', '7/7/2015 23:59' -- 0:23s, 831 rows.
	sp_rpt_extract_customer_survey 'All', '5/1/2016 00:00', '5/31/2016 23:59' -- 2:10s, 28056 rows.
History:
	
	2/22/2008 - JPB - converted [field names] to field_names
		converted table names to friendlier names
		added JDB validation to the SP

	--/--/200- - JPB - Initial Development
	
	04/27/2004 - JPB - Directed select into #custSurveyOutput temp table so rows without contacts
		can attempt to get a non-primary contact inserted before returning results.
		
	08/05/2004 - JDB - Added profit_ctr_id join to WasteCode table.
	
	12/30/2004 - SCC - Changed Ticket references (ticket_id and Billing) and new Contact views
	
	03/15/2006 - RG - Removed join to WasteCode on profit_ctr_id
	
	09/05/2006 - JPB - Changed 'Non-Primary Contact' to 'Other' to avoid string truncation error
	
	05/11/2007 - JPB - Converted for Central Invoicing project: CustomerXCompany references removed, etc.
	
	12/22/2008 - CMA - Changed INNER JOIN to LEFT OUTER JOIN on tbl generator per GEM:2224. 
		Changed header, reformatted
		
	01/15/2009 - JPB - Revised to run off PLT_AI, not each #'d database.
		Added @copc_list input
		Added (nolock) directives to selects
		Renamed from sp_web_cust_survey_export to sp_rpt_extract_customer_survey to match other extracts

	01/17/2013 - JPB - Added contact email and various AE/NAM fields to output
	01/18/2016 - JPB - GEM:35372 - 
		Better way, coming soonÖ:
		The company (now profit center) filter will allow running each/any profit center.
		Include receipts invoiced within date range in profit centers requested.
		1.	Receipts donÆt have a receipt-specific contact.
		2.	Include the ReceiptÆs billing project contacts (if any û theyÆre optional). 
				Contact Type will be ôProjectö
		3.	If no contacts included with this receipt yet, Include the customerÆs primary contact.  
				Contact Type will be ôPrimaryö
		4.	If no contacts included with this receipt yet, Include all customer contacts. 
				Contact Type will be ôAnyö
		Include work orders invoiced within date range in profit centers requested.
		1.	Work Orders have a work order-specific contact.  Contact Type will be ôWork Orderö
		2.	If no contacts included with this work order yet, Include the Work OrderÆs billing 
				project contacts (if any). Contact Type will be ôProjectö
		3.	If no contacts included with this work order yet, Include the customerÆs primary 
				contact.  Contact Type will be ôPrimaryö
		4.	If no contacts included with this work order yet, Include all customer contacts. 
				Contact Type will be ôAnyö

		Each of the contacts mentioned above will be listed separately.  Since the object of the 
		Gemini request was to view missing contacts where the current report masks that info, each 
		Contact Type will be listed for every receipt and work order, and cases without that data 
		will just have 1 row with the missing contact type and blank contact fields, except 
		Receipts: The report wonÆt have a blank ôReceiptö Contact Typeû Receipts donÆt have 
		them, no sense listing a blank for it.

		The ôIf no contacts included with this.. yetö bit means that if a ôbetterö (more 
		item-specific) contact has been found already, the report wonÆt bother finding additional 
		contacts: these are not the droids youÆre looking for.  The old version replaced the blanks 
		with someone else, so you couldnÆt tell they were missingà the new one will show where 
		they were missing, but once it finds someone, it wonÆt bother to keep looking for 
		less-specific people to include.

		The new version will also standardize on the fields Boise is sending, so the two can be 
		combined without having to re-arrange columns.  This eliminates fields from our old 
		version like waste code description, approval code (will be a blank field), etc.  This 
		should cut down on duplication in the output, complexity for someone to review, etc.
	
	10/21/2016 - PRK/JPB - GEM:37949 - Widened the acceptable types of resource classes 
	
*********************************************************** */	
	
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)	

if @copc_list <> 'All'
begin
	INSERT @tbl_profit_center_filter 
	SELECT company_id, profit_ctr_id 
	FROM (
		SELECT 
			RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @copc_list) 
		where isnull(row, '') <> ''
	) selected_copc 
end		
else
begin
	INSERT @tbl_profit_center_filter
	SELECT company_id
		   ,profit_ctr_id
	FROM   ProfitCenter
end

		

-- declare @date_from datetime = '10/1/2015'; declare @date_to datetime = @date_from + 30
	SELECT DISTINCT 
		Billing.Company_ID
		, Billing.Profit_Ctr_ID
		, pc.Profit_Ctr_Name
		, cbt_es.customer_billing_territory_code as ES_Territory
		, t_ue.user_name as ES_Account_Exec
		, cbt_fis.customer_billing_territory_code as FIS_Territory
		, t_uf.user_name as FIS_Account_Exec
		, Billing.Customer_ID
		, c.cust_name as Customer_Name
		, c.cust_addr1 as Address_1
		, c.cust_addr2 as Address_2
		, c.cust_addr3 as Address_3
		, c.cust_addr4 as Address_4
		, c.cust_addr5 as Address_5
		, c.cust_city as City
		, c.cust_state as [State]
		, c.cust_zip_code as Zip

		, Contacts.qry_order as Contact_Type_Order
		, Contacts.Contact_Type
		, Contacts.Contact
		, Contacts.Contact_Title
		, Contacts.Contact_Phone
		, Contacts.Contact_Email

		, Record_Type = case Billing.trans_source
			when 'R' then 'Receipt'
			when 'W' then 'Work Order'
			when 'O' then 'Order'
			end
		
				/* WHere did this Record_Type field come from?  Boise.  Values:
					Scheduled Load Received
					Unscheduled Load Received
				*/

		, ISNULL(g.generator_name, '') AS Generator_Name
		, ISNULL(g.EPA_ID, '') AS Generator_Code
		, Approval_Code = '' 
		, Billing.Receipt_ID
		, Billing.Manifest
		, Billing.date_delivered AS Start_Date
		, Billing.date_delivered AS End_Date
		, Work_Summary = NULL
	
	INTO #CustSurveyOutput
	FROM Billing (nolock)
	INNER JOIN @tbl_profit_center_filter cl 
		ON Billing.company_id = cl.company_id
	INNER JOIN customer c (nolock) 
		ON  c.customer_id = Billing.customer_id
		AND c.customer_type <> 'IC'
	INNER JOIN receipt r (nolock) 
		ON  Billing.receipt_id = r.receipt_id 
		AND Billing.line_id = r.line_id 
		AND Billing.profit_ctr_id = r.profit_ctr_id
		AND Billing.company_id = r.company_id
		AND r.trans_mode = 'I'
	LEFT OUTER JOIN generator g (nolock)
		ON  Billing.generator_id = g.generator_id
	INNER JOIN profitcenter pc (nolock) 
		ON  Billing.profit_ctr_id = pc.profit_ctr_id
		AND Billing.company_id = pc.company_id 
	LEFT OUTER JOIN contactxref cx (nolock)
		ON  c.customer_id = cx.customer_id
		AND cx.primary_contact = 'T'
	LEFT OUTER JOIN contact cc (nolock)
		ON  cx.contact_id = cc.contact_id
	LEFT OUTER JOIN CustomerBilling CBill (nolock)
		ON billing.customer_id = CBill.customer_id
		AND billing.billing_project_id = CBill.billing_project_id
	LEFT OUTER JOIN CustomerBillingTerritory cbt_es (nolock)
		ON cBill.customer_id = cbt_es.customer_id
		AND cbill.billing_project_id = cbt_es.billing_project_id
		AND cbt_es.businesssegment_uid = 1
		left join UsersXEQContact t_uxe	-- Territory instance of UsersXEQContact join
			on t_uxe.territory_code = cbt_es.customer_billing_territory_code
			and t_uxe.EQcontact_type = 'AE'
		left join Users t_ue		-- Territory instance of Users
			on t_ue.user_code = t_uxe.user_code 
	LEFT OUTER JOIN CustomerBillingTerritory cbt_fis (nolock)
		ON cBill.customer_id = cbt_fis.customer_id
		AND cbill.billing_project_id = cbt_fis.billing_project_id
		AND cbt_fis.businesssegment_uid = 2
		left join UsersXEQContact t_uxf	-- Territory instance of UsersXEQContact join
			on t_uxf.territory_code = cbt_fis.customer_billing_territory_code
			and t_uxf.EQcontact_type = 'AE'
		left join Users t_uf		-- Territory instance of Users
			on t_uf.user_code = t_uxf.user_code 
	OUTER APPLY (
		select * 
		from (
			select top 1 *
			from (
				select top 1 -- Customer Primary Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 1 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.primary_contact = 'T'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- Profile Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 2 as qry_type
				from Contact xc
				join Profile xcp on xc.contact_id = xcp.contact_id
				where xcp.profile_id = r.profile_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- Billing Project Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 3 as qry_type
				from CustomerBillingXContact x
				join Contact xc on x.contact_id = xc.contact_id
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				and x.billing_project_id = Billing.billing_project_id
				-- 19026 rows total
				union
				select top 1 -- ANY Customer Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 4 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 19026 rows total
			) y
			right join (
				select 'Any Customer Contact' as Contact_Type, 4 as qry_order
				union 
				select 'Billing Project Contact' as Contact_Type, 3 as qry_order
				union
				select 'Profile Contact' as Contact_Type, 2 as qry_order
				union 
				select 'Customer Primary Contact' as Contact_Type, 1 as qry_order
			) ytypes on y.qry_type = ytypes.qry_order
			where y.contact is not null
			order by qry_order
		) ydata
		where ydata.contact is not null
		union
		select top 1 * 
		from (
			select top 1 *
			from (
				select top 1 -- Customer Primary Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 1 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.primary_contact = 'T'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- Profile Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 2 as qry_type
				from Contact xc
				join Profile xcp on xc.contact_id = xcp.contact_id
				where xcp.profile_id = r.profile_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- Billing Project Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 3 as qry_type
				from CustomerBillingXContact x
				join Contact xc on x.contact_id = xc.contact_id
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				and x.billing_project_id = Billing.billing_project_id
				-- 19026 rows total
				union
				select top 1 -- ANY Customer Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 4 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 19026 rows total
			) y
			right join (
				select 'Any Customer Contact' as Contact_Type, 4 as qry_order
				union 
				select 'Billing Project Contact' as Contact_Type, 3 as qry_order
				union
				select 'Profile Contact' as Contact_Type, 2 as qry_order
				union
				select 'Customer Primary Contact' as Contact_Type, 1 as qry_order
			) ytypes on y.qry_type = ytypes.qry_order
			order by qry_order
		) ydata
		where ydata.contact is null
	) Contacts
	WHERE 1=1
		AND Billing.invoice_date BETWEEN @date_from AND @date_to
		AND Billing.trans_source = 'R'
		AND Billing.status_code = 'I'
		AND Billing.trans_type <> 'O'
--order by
--		Billing.Company_ID
--		, Billing.Profit_Ctr_ID
--		, Billing.Receipt_ID
--		, Contacts.qry_order

		
	UNION

	SELECT DISTINCT 
		Billing.Company_ID
		, Billing.Profit_Ctr_ID
		, pc.Profit_Ctr_Name
		, cbt_es.customer_billing_territory_code as ES_Territory
		, t_ue.user_name as ES_Account_Exec
		, cbt_fis.customer_billing_territory_code as FIS_Territory
		, t_uf.user_name as FIS_Account_Exec
		, Billing.Customer_ID
		, c.cust_name as Customer_Name
		, c.cust_addr1 as Address_1
		, c.cust_addr2 as Address_2
		, c.cust_addr3 as Address_3
		, c.cust_addr4 as Address_4
		, c.cust_addr5 as Address_5
		, c.cust_city as City
		, c.cust_state as [State]
		, c.cust_zip_code as Zip

		, Contacts.qry_order as Contact_Type_Order
		, Contacts.Contact_Type
		, Contacts.Contact
		, Contacts.Contact_Title
		, Contacts.Contact_Phone
		, Contacts.Contact_Email

		, Record_Type = case Billing.trans_source
			when 'R' then 'Receipt'
			when 'W' then 'Work Order'
			when 'O' then 'Order'
			end
		
				/* WHere did this Record_Type field come from?  Boise.  Values:
					Scheduled Load Received
					Unscheduled Load Received
				*/

		, ISNULL(g.generator_name, '') AS Generator_Name
		, ISNULL(g.EPA_ID, '') AS Generator_Code
		, Approval_Code = '' 
		, Billing.Receipt_ID
		, Billing.Manifest
		, Billing.date_delivered AS Start_Date
		, Billing.date_delivered AS End_Date
		, Work_Summary = NULL
	
	FROM Billing (nolock)
	INNER JOIN @tbl_profit_center_filter cl 
		ON Billing.company_id = cl.company_id
	INNER JOIN customer c (nolock) 
		ON  c.customer_id = Billing.customer_id
		AND c.customer_type <> 'IC'
	INNER JOIN workorderheader wh (nolock)
		ON  wh.workorder_id = Billing.receipt_id 
		AND wh.profit_ctr_id = Billing.profit_ctr_id
		AND wh.company_id = Billing.company_id 
	INNER JOIN workorderdetail wd (nolock)
		ON  wh.workorder_id = wd.workorder_id 
		AND wh.profit_ctr_id = wd.profit_ctr_id
		AND wh.company_id = wd.company_id 
		AND Billing.workorder_resource_type = wd.resource_type
		AND Billing.workorder_sequence_id = wd.sequence_id
		AND wd.resource_type IN ('E', 'L', 'S', 'D', 'G', 'O')  --added 6/14/16
	LEFT OUTER JOIN generator g (nolock)
		ON  Billing.generator_id = g.generator_id
	INNER JOIN profitcenter pc (nolock) 
		ON  Billing.profit_ctr_id = pc.profit_ctr_id
		AND Billing.company_id = pc.company_id 
	LEFT OUTER JOIN CustomerBilling CBill (nolock)
		ON billing.customer_id = CBill.customer_id
		AND billing.billing_project_id = CBill.billing_project_id
	LEFT OUTER JOIN CustomerBillingTerritory cbt_es (nolock)
		ON cBill.customer_id = cbt_es.customer_id
		AND cbill.billing_project_id = cbt_es.billing_project_id
		AND cbt_es.businesssegment_uid = 1
		left join UsersXEQContact t_uxe	-- Territory instance of UsersXEQContact join
			on t_uxe.territory_code = cbt_es.customer_billing_territory_code
			and t_uxe.EQcontact_type = 'AE'
		left join Users t_ue		-- Territory instance of Users
			on t_ue.user_code = t_uxe.user_code 
	LEFT OUTER JOIN CustomerBillingTerritory cbt_fis (nolock)
		ON cBill.customer_id = cbt_fis.customer_id
		AND cbill.billing_project_id = cbt_fis.billing_project_id
		AND cbt_fis.businesssegment_uid = 2
		left join UsersXEQContact t_uxf	-- Territory instance of UsersXEQContact join
			on t_uxf.territory_code = cbt_fis.customer_billing_territory_code
			and t_uxf.EQcontact_type = 'AE'
		left join Users t_uf		-- Territory instance of Users
			on t_uf.user_code = t_uxf.user_code 
	OUTER APPLY (
		select * 
		from (
			select top 1 *
			from (
				select top 1 -- Work Order Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 1 as qry_type
				from Contact xc 
				where xc.contact_id = wh.contact_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- Billing Project Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 2 as qry_type
				from CustomerBillingXContact x
				join Contact xc on x.contact_id = xc.contact_id
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				and x.billing_project_id = Billing.billing_project_id
				-- 19026 rows total
				union
				select top 1 -- Customer Primary Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 3 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.primary_contact = 'T'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- ANY Customer Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 4 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 19026 rows total
			) y
			right join (
				select 'Any Customer Contact' as Contact_Type, 4 as qry_order
				union 
				select 'Customer Primary Contact' as Contact_Type, 3 as qry_order
				union
				select 'Billing Project Contact' as Contact_Type, 2 as qry_order
				union 
				select 'Work Order Contact' as Contact_Type, 1 as qry_order
			) ytypes on y.qry_type = ytypes.qry_order
			where y.contact is not null
			order by qry_order
		) ydata
		where ydata.contact is not null
		union
		select * 
		from (
			select top 1 *
			from (
				select top 1 -- Work Order Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 1 as qry_type
				from Contact xc 
				where xc.contact_id = wh.contact_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- Billing Project Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 2 as qry_type
				from CustomerBillingXContact x
				join Contact xc on x.contact_id = xc.contact_id
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				and x.billing_project_id = Billing.billing_project_id
				-- 19026 rows total
				union
				select top 1 -- Customer Primary Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 3 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.primary_contact = 'T'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 2548 rows total
				union
				select top 1 -- ANY Customer Contact
					isnull(xc.name, '') as Contact
					, isnull(xc.title, '') as Contact_Title
					, isnull(xc.phone, '') as Contact_Phone
					, isnull(xc.email, '') as Contact_Email
					, 4 as qry_type
				from ContactXref x
				join Contact xc on x.contact_id = xc.contact_id
					and x.type = 'C'
					and x.status = 'A'
				where x.customer_id = Billing.customer_id
					and isnull(xc.email, '') <> ''
				-- 19026 rows total
			) y
			right join (
				select 'Any Customer Contact' as Contact_Type, 4 as qry_order
				union 
				select 'Customer Primary Contact' as Contact_Type, 3 as qry_order
				union
				select 'Billing Project Contact' as Contact_Type, 2 as qry_order
				union 
				select 'Work Order Contact' as Contact_Type, 1 as qry_order
			) ytypes on y.qry_type = ytypes.qry_order
			where y.contact is not null
			order by qry_order
		) ydata
		where ydata.contact is null
	) Contacts
	WHERE 1=1
		AND Billing.invoice_date BETWEEN @date_from AND @date_to
		AND Billing.status_code = 'I' 
		AND Billing.trans_source = 'W'
		AND Billing.workorder_resource_type IN ('E', 'L', 'G', 'S', 'D', 'O')  --added 6/14/16
		AND Billing.trans_type = 'O'

SET NOCOUNT OFF
SELECT distinct * FROM #custSurveyOutput ORDER BY  customer_id, company_id, profit_ctr_id, receipt_id



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_customer_survey] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_customer_survey] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_customer_survey] TO [EQAI]
    AS [dbo];

