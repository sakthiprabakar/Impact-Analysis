CREATE PROCEDURE sp_reports_emergency_response_search
	@debug				int, 					-- 0 or 1 for no debug/debug mode
	@manifest_list		varchar(max),	        -- Comma Separated Customer ID List - what customers to include
/*	@approval_code		varchar(max) = null,	-- CSV Approval code list */
	@epa_id_list		varchar(max) = null,	-- CSV list of EPA ID values: SQGs will be ignored. For that, use ...
	@generator_id_list	varchar(max) = null,	-- CSV list of generator id's
/*	@start_date			datetime = null,
	@end_date			datetime = null, */
	@contact_id			varchar(100) = 0			-- Contact_id.  >0 if contact.  -1 if associate.
AS
/****************************************************************************************************
sp_reports_emergency_response_search:

Returns the data for Manifest Lookups

LOAD TO PLT_AI

History:

	11/10/2017 JPB	Created - copied from sp_reports_manifest_lookup

Samples:

SELECT TOP 100 * FROM workordermanifest WHERE manifest not like 'manifest%' 
and manifest in (select manifest from receipt)
order by date_added desc
SELECT distinct TOP 100 manifest, receipt_date FROM receipt WHERE getdate() > receipt_date order by receipt_date desc
SELECT * FROM contactxref WHERE customer_id = 583
SELECT TOP 100 * FROM transporter order by date_added desc
SELECT TOP 100 * FROM generator WHERE date_added > '2/1/2017' order by date_added desc


exec sp_reports_emergency_response_search 0, '010916688FLE', '', '', '-1' 
sp_reports_emergency_response_search
	@debug				= 0,
	@manifest_list		= '654654111JJK    ',
	@epa_id_list		= '',
	@generator_id_list	= '',
	@contact_id			= -1

'0118781', '0118782', '0118868', '012148779JJK', '012148780JJK', '012148781JJK', '012148787JJK', '012148788JJK', '015519917JJK', '015519918JJK', '015924979JJK', '015973947JJK', '015973948JJK', '015973949JJK', '015973950JJK', '016030581JJK', '016106733JJK', '016106734JJK', '016107742JJK', '016107743JJK', '016107744JJK', '016107745JJK', '016107746JJK', '016107747JJK', '016107748JJK', '016107799JJK', '016107800JJK', '016107801JJK', '016107805JJK', '016458789JJK', '016458792JJK', '016458793JJK', '016458797JJK', '016509465JJK', '016523844JJK', '016523845JJK', '016638907JJK', '016667976JJK', '016667977JJK', '016993040JJK', '017051857JJK', '017215076JJK', '017215077JJK', '017218457JJK', '017218458JJK', '017243076JJK', '017436286JJK', '017436289JJK', '017528323JJK', '017528993JJK', '017539994JJK', '017540848JJK', '017540880JJK', '017545690JJK', '017545691JJK', '017608822JJK', '017608953JJK', '017609590JJK', '017836288JJK', '017836292JJK', '017836293JJK', '017849874JJK', '017849875JJK', '017849879JJK', '017855651JJK', '017859247JJK', '017859447JJK', '017859448JJK', '017859498JJK', '017859499JJK', '017859500JJK', '017860606JJK', '017867816JJK', '018038522JJK', '018038691JJK', '018048053JJK', '018048066JJK', '018048078JJK', '018081881JJK', '0200118', '0200119', '0200120', '0200121', '0200122', '0200123', '0200124', '0200125', '10191701', '10191702', '10191703', '10191704', '10191705', '10191706', '10191707', '10191708', '10191709', '10191710', '113318', '121049', '3223400'
SELECT * FROM receipt where receipt_id = 	987598 and company_id = 21
SELECT * FROM receipt where receipt_id = 	1838 and company_id = 32

Inbound|receipt|27|0|63797|Dec 20 2013 10:20AM|Dec 17 2069 12:00AM|
Inbound|receipt|27|0|63834|Dec 20 2013 11:21AM|Dec 17 2013 12:00AM|
Inbound|workorder|15|4|1528000|Dec 11 2013  4:55PM|Dec 17 2013  7:32AM|

Inbound|receipt|27|0|63834|Dec 20 2013 11:21AM|Dec 17 2013 12:00AM|,Inbound|workorder|15|4|1528000|Dec 11 2013  4:55PM|Dec 17 2013  7:32AM|

select * from receipt WHERE receipt_id = 63834 and company_id = 27

SELECT * FROM workorderheader WHERE workorder_id = 21916500 and profit_ctr_id = 6
SELECT * FROM workordermanifest WHERE workorder_id = 21916500 and profit_ctr_id = 6
SELECT * FROM workorderdetail WHERE workorder_id = 21916500 and profit_ctr_id = 6

SELECT * FROM contactxref WHERE  customer_id = 15940

SELECT * FROM receipt WHERE manifest = 'ORD0004951'
SELECT * FROM workordermanifest WHERE manifest = 'ORD0004951'
SELECT * FROM generator	WHERE generator_id = 1
SELECT * FROM receipttransporter WHERE receipt_id = 579 and profit_ctr_id = 9

SELECT * FROM receipt	WHERE receipt_id = 1196597 and company_id = 21
SELECT * FROM workorderheader WHERE workorder_id =	21944802 and company_id = 14

SELECT * FROM generator WHERE generator_id = 35475
****************************************************************************************************/

-- Input setup:

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE
		@icontact_id	INT = CONVERT(INT, @contact_id),
		@getdate 		DATETIME = getdate(),
		@timer_start	datetime = getdate(),
		@last_step		datetime = getdate(),
		@sql			varchar(max) = ''

	set @manifest_list = replace(isnull(@manifest_list, ''), ' ', '')
	-- set @approval_code = replace(isnull(@approval_code, ''), ' ', '')
	set @epa_id_list = replace(isnull(@epa_id_list, ''), ' ', '')
	set @generator_id_list = replace(isnull(@generator_id_list, ''), ' ', '')

-- end date fix:
--	if @end_date is not null and datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999
	
-- Handle text inputs into temp tables
	CREATE TABLE #Manifest_list (manifest VARCHAR(15))
	CREATE INDEX idx1 ON #Manifest_list (manifest)
	INSERT #Manifest_list SELECT row from dbo.fn_SplitXsvText(',', 1, @manifest_list) WHERE ISNULL(row, '') <> '' and isnull(row, '') not like 'manifest_%'

	CREATE TABLE #generator (generator_id int)
	CREATE INDEX idx1 ON #generator (generator_id)
	INSERT #generator SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 1, @generator_id_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #transporter (transporter_code varchar(15))
	CREATE INDEX idx1 ON #transporter (transporter_code)
	-- INSERT #transporter SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 1, @generator_id_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #EPAID (epa_id varchar(12))
	CREATE INDEX idx1 ON #EPAID (epa_id)
	INSERT #EPAID SELECT row from dbo.fn_SplitXsvText(',', 1, @epa_id_list) WHERE ISNULL(row, '') <> ''

	if exists (select top 1 1 from #epaid) begin
		delete from #EPAID WHERE epa_id like '%SQG'
		insert #generator
		select g.generator_id from generator g join #epaid e on g.epa_id = e.epa_id
		insert #transporter
		select t.transporter_code from transporter t join #epaid e on t.transporter_epa_id = e.epa_id
		-- now #EPAID is irrelevant, because it has been transferred to entities we care about, which have IDs.
		-- or infuriating "codes".
	end

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Setup' as last_step_desc
	set @last_step = getdate()

-- Setup is finished.  On to work:
	
-- abort if there's nothing possible to see
	if (select count(*) from #Manifest_list) +
		(select count(*) from #generator) +
		(select count(*) from #transporter) -- ???  This could be a lot, and not terribly relevant.  Meh.  Include to start, remove if a butt.
		= 0 RETURN

	-- #Source table to hold info about the rows that contain the manifest info.
	create table #source (company_id int, profit_ctr_id int, document_source varchar(20), receipt_id int)
	
	if @icontact_id >= 0 begin
	
		-- Receipt:
		if (select count(*) from #manifest_list) > 0
			insert #source
			select r.company_id, r.profit_ctr_id, 'receipt', r.receipt_id
			from receipt r (nolock)
			WHERE r.manifest in (select manifest from #manifest_list)
			and r.receipt_status not in ('V')
			and exists (
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.customer_id  = r.customer_id
				union
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'G' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.generator_id = r.generator_id 
				union
				select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cg.generator_id = r.generator_id
			) 
			
		if (select count(*) from #generator) > 0
			insert #source
			select r.company_id, r.profit_ctr_id, 'receipt', r.receipt_id
			from receipt r (nolock)
			WHERE r.generator_id in (select generator_id from #generator)
			and r.receipt_status not in ('V')
			and exists (
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.customer_id  = r.customer_id
				union
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'G' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.generator_id = r.generator_id 
				union
				select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cg.generator_id = r.generator_id
			) 
	
		if (select count(*) from #transporter) > 0
			insert #source
			select rt.company_id, rt.profit_ctr_id, 'receipt', rt.receipt_id
			from receipttransporter rt (nolock)
			join receipt r on rt.receipt_id = r.receipt_id and rt.company_id = r.company_id and rt.profit_ctr_id = r.profit_ctr_id
			WHERE rt.transporter_code in (select transporter_code from #transporter)
			and r.receipt_status not in ('V')
			and exists (
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.customer_id  = r.customer_id
				union
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'G' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.generator_id = r.generator_id 
				union
				select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cg.generator_id = r.generator_id
			) 


		-- Work Order:
		if (select count(*) from #manifest_list) > 0
			insert #source
			select wom.company_id, wom.profit_ctr_id, 'workorder', wom.workorder_id
			from workordermanifest wom (nolock)
			join workorderheader w on wom.workorder_id = w.workorder_id and wom.company_id = w.company_id and wom.profit_ctr_id = w.profit_ctr_id
			WHERE wom.manifest in (select manifest from #manifest_list)
			and w.workorder_status not in ('V')
			and exists (
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.customer_id  = w.customer_id
				union
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'G' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.generator_id = w.generator_id 
				union
				select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cg.generator_id = w.generator_id
			) 
	
		if (select count(*) from #generator) > 0
			insert #source
			select w.company_id, w.profit_ctr_id, 'workorder', w.workorder_id
			from workorderheader w (nolock)
			WHERE w.generator_id in (select generator_id from #generator)
			and w.workorder_status not in ('V')
			and exists (
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.customer_id  = w.customer_id
				union
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'G' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.generator_id = w.generator_id 
				union
				select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cg.generator_id = w.generator_id
			) 
	
		if (select count(*) from #transporter) > 0
			insert #source
			select wom.company_id, wom.profit_ctr_id, 'workorder', wom.workorder_id
			from WorkOrderTransporter wom (nolock)
			join workorderheader w on wom.workorder_id = w.workorder_id and wom.company_id = w.company_id and wom.profit_ctr_id = w.profit_ctr_id
			WHERE wom.transporter_code in (select transporter_code from #transporter)
			and w.workorder_status not in ('V')
			and exists (
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.customer_id  = w.customer_id
				union
				select 1 from contactxref cxr (nolock) where cxr.contact_id = @icontact_id and cxr.type = 'G' and cxr.status = 'A' and cxr.web_access = 'A'
				and cxr.generator_id = w.generator_id 
				union
				select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = @icontact_id and cxr.type = 'C' and cxr.status = 'A' and cxr.web_access = 'A'
				and cg.generator_id = w.generator_id
			) 

	end
	
	if @icontact_id = -1 begin
	
		-- Receipt:
		if (select count(*) from #manifest_list) > 0
			insert #source
			select r.company_id, r.profit_ctr_id, 'receipt', r.receipt_id
			from receipt r (nolock)
			WHERE r.manifest in (select manifest from #manifest_list)
			and r.receipt_status not in ('V')
			
		if (select count(*) from #generator) > 0
			insert #source
			select r.company_id, r.profit_ctr_id, 'receipt', r.receipt_id
			from receipt r (nolock)
			WHERE r.generator_id in (select generator_id from #generator)
			and r.receipt_status not in ('V')

		if (select count(*) from #transporter) > 0
			insert #source
			select rt.company_id, rt.profit_ctr_id, 'receipt', rt.receipt_id
			from receipttransporter rt (nolock)
			inner join receipt r on rt.receipt_id = r.receipt_id and rt.company_id = r.company_id and rt.profit_ctr_id = r.profit_ctr_id
			WHERE rt.transporter_code in (select transporter_code from #transporter)
			and r.receipt_status not in ('V')


		-- Work Order:
		if (select count(*) from #manifest_list) > 0
			insert #source
			select wom.company_id, wom.profit_ctr_id, 'workorder', wom.workorder_id
			from workordermanifest wom (nolock)
			join workorderheader w on wom.workorder_id = w.workorder_id and wom.company_id = w.company_id and wom.profit_ctr_id = w.profit_ctr_id
			WHERE wom.manifest in (select manifest from #manifest_list)
			and w.workorder_status not in ('V')
	
		if (select count(*) from #generator) > 0
			insert #source
			select w.company_id, w.profit_ctr_id, 'workorder', w.workorder_id
			from workorderheader w (nolock)
			WHERE w.generator_id in (select generator_id from #generator)
			and w.workorder_status not in ('V')
	
		if (select count(*) from #transporter) > 0
			insert #source
			select wom.company_id, wom.profit_ctr_id, 'workorder', wom.workorder_id
			from WorkOrderTransporter wom (nolock)
			join workorderheader w on wom.workorder_id = w.workorder_id and wom.company_id = w.company_id and wom.profit_ctr_id = w.profit_ctr_id
			WHERE wom.transporter_code in (select transporter_code from #transporter)
			and w.workorder_status not in ('V')

	end

	if (select count(*) from #source) = 0 return
	
	if @debug > 0 SELECT * FROM #source
	
	-- Get distinct results	
	select distinct * into #output from #source
	
	-- SELECT * FROM #output

	-- output:
	select distinct
		o.document_source
		, o.company_id
		, o.profit_ctr_id
		, o.receipt_id
		, coalesce(r.manifest, wom.manifest) manifest
		, case o.document_source
			when 'receipt' then case trans_mode when 'I' then rt1.transporter_sign_date when 'O' then r.receipt_date end
			when 'workordoer' then coalesce (wos.date_act_arrive, wt1.transporter_sign_date, w.start_date) 
			else coalesce (rt1.transporter_sign_date, wos.date_act_arrive, wt1.transporter_sign_date, w.start_date) 
			end pickup_date
		, coalesce(r.date_added, w.date_added) date_added
		, case o.document_source
			when 'receipt' then
				case r.trans_mode when 'I' then 'Inbound' when 'O' then 'Outbound' end
			when 'workorder' then
				case wod.resource_type
					when 'D' then case when profile_company_id is not null then 'Inbound' else '3rd Party Disposal' end
					else 'Service'
					end
			end as transaction_direction
		, c.customer_id
		, c.cust_name
		, c.cust_phone

		, g.generator_id
		, g.epa_id
		, g.generator_name
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_address_4
		, g.generator_address_5
		, g.generator_phone
		, g.generator_fax
		, g.generator_city
		, g.generator_state
		, g.generator_zip_code
		, g.generator_county
		, g.generator_country
		, g.emergency_phone_number
		
		, t1.transporter_code				t1_transporter_code
		, t1.transporter_name				t1_transporter_name			
		, t1.transporter_addr1				t1_transporter_addr1
		, t1.transporter_addr2				t1_transporter_addr2
		, t1.transporter_addr3				t1_transporter_addr3
		, t1.transporter_EPA_ID				t1_transporter_EPA_ID
		, t1.transporter_phone				t1_transporter_phone
		, t1.transporter_contact				t1_transporter_contact
		, t1.transporter_contact_phone		t1_transporter_contact_phone
		, t1.DOT_id							t1_DOT_id
		, t1.transporter_city				t1_transporter_city
		, t1.transporter_state				t1_transporter_state
		, t1.transporter_zip_code			t1_transporter_zip_code
		, t1.transporter_country				t1_transporter_country

		, t2.transporter_code				t2_transporter_code
		, t2.transporter_name				t2_transporter_name			
		, t2.transporter_addr1				t2_transporter_addr1
		, t2.transporter_addr2				t2_transporter_addr2
		, t2.transporter_addr3				t2_transporter_addr3
		, t2.transporter_EPA_ID				t2_transporter_EPA_ID
		, t2.transporter_phone				t2_transporter_phone
		, t2.transporter_contact				t2_transporter_contact
		, t2.transporter_contact_phone		t2_transporter_contact_phone
		, t2.DOT_id							t2_DOT_id
		, t2.transporter_city				t2_transporter_city
		, t2.transporter_state				t2_transporter_state
		, t2.transporter_zip_code			t2_transporter_zip_code
		, t2.transporter_country				t2_transporter_country
		
		, coalesce(pc.profit_ctr_name, tsdf.tsdf_name) as destination_name
		, coalesce(pc.address_1, tsdf.TSDF_addr1)		destination_address_1
		, coalesce(pc.address_2, tsdf.TSDF_addr2)		destination_address_2
		, coalesce(pc.address_3, tsdf.TSDF_addr3)		destination_address_3
		, coalesce(pc.phone, tsdf.TSDF_phone)		destination_phone
		, coalesce(pc.fax, tsdf.tsdf_fax)		destination_fax
		, coalesce(pc.EPA_ID, tsdf_epa_id)			destination_EPA_ID

		, coalesce(pll.city, tsdf.tsdf_city) as destination_city
		, coalesce(pll.state, tsdf.tsdf_state) as destination_state
		, coalesce(pll.zip_code, tsdf.tsdf_zip_code) as destination_zip_code
		, coalesce(pll.country_code, tsdf.tsdf_country_code) as destination_country
	into #all
	from #output o
		left outer join receipt r (nolock) on o.receipt_id = r.receipt_id and o.company_id = r.company_id and o.profit_ctr_id = r.profit_ctr_id and o.document_source = 'receipt' and r.receipt_status not in ('V')
		left outer join receipttransporter rt1 (nolock) on o.receipt_id = rt1.receipt_id and o.company_id = rt1.company_id and o.profit_ctr_id = rt1.profit_ctr_id and o.document_source = 'receipt'
		left outer join receipttransporter rt2 (nolock) on o.receipt_id = rt2.receipt_id and o.company_id = rt2.company_id and o.profit_ctr_id = rt2.profit_ctr_id and o.document_source = 'receipt'

		left outer join workorderheader w (nolock) on o.receipt_id = w.workorder_id and o.company_id = w.company_id and o.profit_ctr_id = w.profit_ctr_id and o.document_source = 'workorder' and w.workorder_status not in ('V')
		left outer join workordermanifest wom (nolock) on o.receipt_id = wom.workorder_id and o.company_id = wom.company_id and o.profit_ctr_id = wom.profit_ctr_id and o.document_source = 'workorder'
		left outer join workorderdetail wod (nolock) on o.receipt_id = wod.workorder_id and o.company_id = wod.company_id and o.profit_ctr_id = wod.profit_ctr_id and wom.manifest = wod.manifest and o.document_source = 'workorder'
		left outer join workorderstop wos (nolock) on o.receipt_id = wos.workorder_id and o.company_id = wos.company_id and o.profit_ctr_id = wos.profit_ctr_id and wos.stop_sequence_id = 1 and o.document_source = 'workorder'

		left outer join workordertransporter wt1 (nolock) on o.receipt_id = wt1.workorder_id and o.company_id = wt1.company_id and o.profit_ctr_id = wt1.profit_ctr_id and o.document_source = 'workorder'
		left outer join workordertransporter wt2 (nolock) on o.receipt_id = wt2.workorder_id and o.company_id = wt2.company_id and o.profit_ctr_id = wt2.profit_ctr_id and o.document_source = 'workorder'

		left outer join transporter t1 (nolock) on t1.transporter_code = coalesce(rt1.transporter_code, wt1.transporter_code) and 1 = coalesce(rt1.transporter_sequence_id, wt1.transporter_sequence_id)
		left outer join transporter t2 (nolock) on t2.transporter_code = coalesce(rt2.transporter_code, wt2.transporter_code) and 2 = coalesce(rt2.transporter_sequence_id, wt2.transporter_sequence_id)
		left outer join customer c (nolock) on c.customer_id = coalesce(r.customer_id, w.customer_id)
		left outer join generator g (nolock) on g.generator_id = coalesce(r.generator_id, w.generator_id)

		left join profitcenter pc (nolock) on 
			pc.company_id = case o.document_source 
				when 'receipt' then
					case r.trans_mode when 'I' then r.company_id when 'O' then r.OB_profile_company_id end
				when 'workorder' then
					case when wod.tsdf_code in (select tsdf_code from tsdf where eq_flag = 'T') then wod.profile_company_id else null end
				end
			and pc.profit_ctr_id = case o.document_source 
				when 'receipt' then
					case r.trans_mode when 'I' then r.profit_ctr_id when 'O' then r.OB_profile_profit_ctr_id end
				when 'workorder' then
					case when wod.tsdf_code in (select tsdf_code from tsdf where eq_flag = 'T') then wod.profile_profit_ctr_id else null end
				end
		left join tsdf (nolock) on 
				tsdf.tsdf_code = case o.document_source when 'workorder' then wod.tsdf_code when 'receipt' then r.tsdf_code else null end
		left join PhoneListLocation pll (nolock)
			on pll.company_id = case pc.company_id when 2 then 3 else pc.company_id end
			and pll.profit_ctr_id = pc.profit_ctr_id

-- #all contains ALL the manifests from any source that contained ANY of the manifests.
-- That's cool and all, but the output is confusing when a non-match is included in the results.
-- Cleanup, cleanup, everybody, everywhere.

	if (select count(*) from #manifest_list) > 0
		delete from #all where manifest not in (select manifest from #manifest_list)
		
	if (select count(*) from #generator) > 0
		delete from #all where generator_id not in (select generator_id from #Generator)
		
	if (select count(*) from #transporter) > 0
		delete from #all WHERE t1_transporter_code not in (select transporter_code from #transporter)
			and t2_transporter_code not in (select transporter_code from #transporter)

if @debug > 0
	SELECT * FROM #all
	
set nocount on

	select distinct
		manifest

		, generator_id
		, epa_id
		, generator_name
		, generator_address_1
		, generator_address_2
		, generator_address_3
		, generator_address_4
		, generator_address_5
		, generator_phone
		, generator_fax
		, generator_city
		, generator_state
		, generator_zip_code
		, generator_county
		, generator_country
		, emergency_phone_number
		
		, t1_transporter_name			
		, t1_transporter_addr1
		, t1_transporter_addr2
		, t1_transporter_addr3
		, t1_transporter_EPA_ID
		, t1_transporter_phone
		, t1_transporter_contact
		, t1_transporter_contact_phone
		, t1_DOT_id
		, t1_transporter_city
		, t1_transporter_state
		, t1_transporter_zip_code
		, t1_transporter_country

		, t2_transporter_name			
		, t2_transporter_addr1
		, t2_transporter_addr2
		, t2_transporter_addr3
		, t2_transporter_EPA_ID
		, t2_transporter_phone
		, t2_transporter_contact
		, t2_transporter_contact_phone
		, t2_DOT_id
		, t2_transporter_city
		, t2_transporter_state
		, t2_transporter_zip_code
		, t2_transporter_country
		
		, destination_name
		, destination_address_1
		, destination_address_2
		, destination_address_3
		, destination_phone
		, destination_fax
		, destination_EPA_ID

		, destination_city
		, destination_state
		, destination_zip_code
		, destination_country
		, (
				-- Get CSV values
				SELECT SUBSTRING(
				(SELECT distinct ',' 
					+ transaction_direction + '|'
					+ document_source + '|' 
					+ convert(varchar(20), company_id) + '|' 
					+ convert(varchar(20), profit_ctr_id) + '|'
					+ convert(varchar(20), receipt_id) + '|'
					+ isnull(convert(varchar(20), min(date_added)), '') + '|'
					+ isnull(convert(varchar(20), min(pickup_date)), '') + '|'
					
				FROM #all a
				WHERE a.manifest = d.manifest
				-- ORDER BY a.date_added
				and a.generator_id = d.generator_id
				group by transaction_direction, document_source, company_id, profit_ctr_id, receipt_id
				FOR XML PATH('')),2,200000) 
			) as manifest_transactions


		/*
		document_source
		, company_id
		, profit_ctr_id
		, receipt_id
		, pickup_date
		, date_added
		, transaction_direction
		, customer_id
		, cust_name
		, cust_phone
		*/


		from #all d
		order by manifest

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'final output' as last_step_desc
	set @last_step = getdate()
   	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_emergency_response_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_emergency_response_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_emergency_response_search] TO [EQAI]
    AS [dbo];

