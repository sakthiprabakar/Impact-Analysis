-- exec jonathan.sp_emanifest_reconcile_report @date_start = '07/01/2024', @date_end = '09/30/2024'

drop proc if exists sp_emanifest_reconcile_report
go

create proc sp_emanifest_reconcile_report (
	@date_start datetime
	, @date_end datetime
	, @facility_epaid_list varchar(4000) = ''
) as

/*
sp_emanifest_reconcile_report

2024-10-02 - Crashed the database because of the tempdb activity it was doing
-- and probably more the fnIsEmanifestRequired activity.
-- Rewrote it later that night to be "less" impactful.

-- exec jonathan.sp_emanifest_reconcile_report @date_start = '07/01/2024', @date_end = '09/30/2024'
	-- ran over 2h before crash

-- Code below ran for 43s.  Returns 50,487 rows.
-- on 10/4/2024 - no cache in play, it ran for 2min 20s. Returned 50,768 rows.

*/

begin

if datepart(hh, @date_end) = 0 set @date_end = @date_end + 0.99999

Drop Table If Exists #c
select * into #c from Athena.athena.dbo.company

-- SELECT  * FROM    #c

--select count(*)
--from athena.athena.dbo.Aesop_manifest_Info a
--where a.received_date between '07/01/2024' and '09/30/2024'


-- Create & Populate @tmp_trans_copc
Drop Table If Exists #tmp_trans_copc 
create TABLE #tmp_trans_copc  (
	source_company_id varchar(10)
	, source_profit_ctr_id varchar(10)
)
IF LTRIM(RTRIM(ISNULL(@facility_epaid_list, ''))) in ('', 'ALL')
	INSERT #tmp_trans_copc
	SELECT distinct company_id, profit_ctr_id
	FROM #c
	where status = 'A'
ELSE
	INSERT #tmp_trans_copc
	SELECT distinct company_id, profit_ctr_id
	FROM fn_SplitXsvText(',', 1, @facility_epaid_list) x
	join #c c on c.epa_id = x.row
	WHERE isnull(row,'') <> ''

Drop Table If Exists #ai

select loc_code, source_id, received_date, gen_signed_date, custid, cust_name, cust_manifest_number, state_manifest_number
into #ai
from athena.athena.dbo.Aesop_manifest_Info a
join #tmp_trans_copc copc on  convert(int, a.loc_code) = copc.source_company_id 
where a.received_date between @date_start and @date_end


Drop Table If Exists #as

select distinct a.source, a.source_id, a.source_company_id, a.source_profit_ctr_id, a.manifest, a.status, a.record_type, a.date_signed
into #as 
from 
#tmp_trans_copc pc inner join 
Athena.athena.dbo.AthenaStatus a
on a.source_company_id = pc.source_company_id and isnull(a.source_profit_ctr_id, '') = isnull(pc.source_profit_ctr_id, '')
where coalesce(a.date_signed, a.date_uploaded, a.date_modified, a.date_added, a.receipt_date) between dateadd(yy, -1, @date_start) and dateadd(yy, 1, @date_end)

-- Logic imported from fn_IsEmanifestRequired on 10/2.
		Drop Table If Exists #wastecode
			create table #wastecode(
			waste_code_state	varchar(2)
			,waste_code			varchar(10)
			,waste_code_origin	char(1)
			,haz_flag			char(1)
			,waste_code_uid		int
			)

			insert #wastecode (waste_code_state, waste_code) 
			values
			('CO', 'K901'),
			('CO', 'K902'),
			('CO', 'K903'),
			('CO', 'P909'),
			('CO', 'P910'),
			('CO', 'P911'),
			('IN', 'I001'),
			('KY', 'N001'),
			('KY', 'N002'),
			('KY', 'N003'),
			('KY', 'N101'),
			('KY', 'N102'),
			('KY', 'N201'),
			('KY', 'N202'),
			('KY', 'N203'),
			('KY', 'N301'),
			('KY', 'N302'),
			('KY', 'N401'),
			('KY', 'N402'),
			('KY', 'N501'),
			('KY', 'N502'),
			('KY', 'N601'),
			('KY', 'N602'),
			('KY', 'N701'),
			('KY', 'N702'),
			('KY', 'N703'),
			('KY', 'N801'),
			('KY', 'N802'),
			('KY', 'N803'),
			('KY', 'N901'),
			('KY', 'N902'),
			('KY', 'N903'),
			('KY', 'N1001'),
			('KY', 'N1002'),
			('KY', 'N1003'),
			('ME', 'K119'),
			('ME', 'K120'),
			('ME', 'K121'),
			('ME', 'M003'),
			('ME', 'MED001'),
			('ME', 'MED018'),
			('ME', 'MRD001'),
			('ME', 'MRD002'),
			('ME', 'MRD003'),
			('ME', 'MRD006'),
			('ME', 'MRD007'),
			('ME', 'MRD008'),
			('ME', 'MRD009'),
			('ME', 'MRD011'),
			('ME', 'MRM002'),
			('ME', 'P125'),
			('ME', 'P126'),
			('ME', 'P129'),
			('ME', 'P130'),
			('ME', 'P131'),
			('ME', 'P132'),
			('ME', 'P133'),
			('ME', 'P134'),
			('ME', 'P135'),
			('ME', 'P136'),
			('ME', 'P137'),
			('ME', 'P138'),
			('ME', 'P139'),
			('ME', 'P140'),
			('ME', 'P141'),
			('ME', 'P142'),
			('ME', 'P143'),
			('ME', 'P144'),
			('ME', 'P145'),
			('ME', 'P146'),
			('ME', 'P147'),
			('ME', 'P148'),
			('ME', 'P149'),
			('ME', 'P150'),
			('ME', 'P151'),
			('ME', 'P152'),
			('ME', 'P153'),
			('ME', 'P154'),
			('ME', 'P155'),
			('ME', 'P156'),
			('ME', 'P157'),
			('ME', 'P158'),
			('ME', 'U354'),
			('ME', 'U355'),
			('MD', 'F014'),
			('MD', 'F015'),
			('MD', 'U202'),
			('MD', 'K991'),
			('MD', 'K992'),
			('MD', 'K993'),
			('MD', 'K994'),
			('MD', 'K995'),
			('MD', 'K996'),
			('MD', 'K997'),
			('MD', 'K998'),
			('MD', 'K999'),
			('MD', 'M001'),
			('MD', 'MD01'),
			('MD', 'MD02'),
			('MD', 'MD03'),
			('MD', 'MT01'),
			('MA', 'MA01'),
			('MA', 'MA95'),
			('MA', 'MA97'),
			('MA', 'MA98'),
			('MA', 'MA99'),
			('MA', 'MA04'),
			('MI', '001T'),
			('MI', '003T'),
			('MI', '004T'),
			('MI', '005T'),
			('MN', 'MN02'),
			('MN', 'MN04'),
			('NV', 'PCBX'),
			('NV', 'CAONLY'),
			('NH', 'NH01'),
			('NH', 'NH02'),
			('NH', 'NHX1'),
			('NH', 'NHX2'),
			('NH', 'NHX3'),
			('NH', 'NHX4'),
			('NH', 'NHX5'),
			('NH', 'NHX6'),
			('OR', 'ORF998'),
			('OR', 'ORF999'),
			('OR', 'ORP001'),
			('OR', 'ORP002'),
			('OR', 'ORP003'),
			('OR', 'ORP004'),
			('OR', 'ORP005'),
			('OR', 'ORP006'),
			('OR', 'ORP007'),
			('OR', 'ORP008'),
			('OR', 'ORP009'),
			('OR', 'ORP010'),
			('OR', 'ORP011'),
			('OR', 'ORP012'),
			('OR', 'ORP013'),
			('OR', 'ORP014'),
			('OR', 'ORP015'),
			('OR', 'ORP016'),
			('OR', 'ORP017'),
			('OR', 'ORP018'),
			('OR', 'ORP020'),
			('OR', 'ORP021'),
			('OR', 'ORP022'),
			('OR', 'ORP023'),
			('OR', 'ORP024'),
			('OR', 'ORP026'),
			('OR', 'ORP027'),
			('OR', 'ORP028'),
			('OR', 'ORP029'),
			('OR', 'ORP030'),
			('OR', 'ORP031'),
			('OR', 'ORP033'),
			('OR', 'ORP034'),
			('OR', 'ORP036'),
			('OR', 'ORP037'),
			('OR', 'ORP038'),
			('OR', 'ORP039'),
			('OR', 'ORP040'),
			('OR', 'ORP041'),
			('OR', 'ORP042'),
			('OR', 'ORP043'),
			('OR', 'ORP044'),
			('OR', 'ORP045'),
			('OR', 'ORP046'),
			('OR', 'ORP047'),
			('OR', 'ORP048'),
			('OR', 'ORP049'),
			('OR', 'ORP050'),
			('OR', 'ORP051'),
			('OR', 'ORP054'),
			('OR', 'ORP056'),
			('OR', 'ORP057'),
			('OR', 'ORP058'),
			('OR', 'ORP059'),
			('OR', 'ORP060'),
			('OR', 'ORP062'),
			('OR', 'ORP063'),
			('OR', 'ORP064'),
			('OR', 'ORP065'),
			('OR', 'ORP066'),
			('OR', 'ORP067'),
			('OR', 'ORP068'),
			('OR', 'ORP069'),
			('OR', 'ORP070'),
			('OR', 'ORP071'),
			('OR', 'ORP072'),
			('OR', 'ORP073'),
			('OR', 'ORP074'),
			('OR', 'ORP075'),
			('OR', 'ORP076'),
			('OR', 'ORP077'),
			('OR', 'ORP078'),
			('OR', 'ORP081'),
			('OR', 'ORP082'),
			('OR', 'ORP084'),
			('OR', 'ORP085'),
			('OR', 'ORP087'),
			('OR', 'ORP088'),
			('OR', 'ORP089'),
			('OR', 'ORP092'),
			('OR', 'ORP093'),
			('OR', 'ORP094'),
			('OR', 'ORP095'),
			('OR', 'ORP096'),
			('OR', 'ORP097'),
			('OR', 'ORP098'),
			('OR', 'ORP099'),
			('OR', 'ORP101'),
			('OR', 'ORP102'),
			('OR', 'ORP103'),
			('OR', 'ORP104'),
			('OR', 'ORP105'),
			('OR', 'ORP106'),
			('OR', 'ORP108'),
			('OR', 'ORP109'),
			('OR', 'ORP110'),
			('OR', 'ORP111'),
			('OR', 'ORP112'),
			('OR', 'ORP113'),
			('OR', 'ORP114'),
			('OR', 'ORP115'),
			('OR', 'ORP116'),
			('OR', 'ORP118'),
			('OR', 'ORP119'),
			('OR', 'ORP120'),
			('OR', 'ORP121'),
			('OR', 'ORP122'),
			('OR', 'ORP123'),
			('OR', 'ORP127'),
			('OR', 'ORP128'),
			('OR', 'ORP185'),
			('OR', 'ORP188'),
			('OR', 'ORP189'),
			('OR', 'ORP190'),
			('OR', 'ORP191'),
			('OR', 'ORP192'),
			('OR', 'ORP194'),
			('OR', 'ORP196'),
			('OR', 'ORP197'),
			('OR', 'ORP198'),
			('OR', 'ORP199'),
			('OR', 'ORP201'),
			('OR', 'ORP202'),
			('OR', 'ORP203'),
			('OR', 'ORP204'),
			('OR', 'ORP205'),
			('OR', 'ORP998'),
			('OR', 'ORP999'),
			('OR', 'ORU001'),
			('OR', 'ORU002'),
			('OR', 'ORU003'),
			('OR', 'ORU004'),
			('OR', 'ORU005'),
			('OR', 'ORU006'),
			('OR', 'ORU007'),
			('OR', 'ORU008'),
			('OR', 'ORU009'),
			('OR', 'ORU010'),
			('OR', 'ORU011'),
			('OR', 'ORU012'),
			('OR', 'ORU014'),
			('OR', 'ORU015'),
			('OR', 'ORU016'),
			('OR', 'ORU017'),
			('OR', 'ORU018'),
			('OR', 'ORU019'),
			('OR', 'ORU020'),
			('OR', 'ORU021'),
			('OR', 'ORU022'),
			('OR', 'ORU023'),
			('OR', 'ORU024'),
			('OR', 'ORU025'),
			('OR', 'ORU026'),
			('OR', 'ORU027'),
			('OR', 'ORU028'),
			('OR', 'ORU029'),
			('OR', 'ORU030'),
			('OR', 'ORU031'),
			('OR', 'ORU032'),
			('OR', 'ORU033'),
			('OR', 'ORU034'),
			('OR', 'ORU035'),
			('OR', 'ORU036'),
			('OR', 'ORU037'),
			('OR', 'ORU038'),
			('OR', 'ORU039'),
			('OR', 'ORU041'),
			('OR', 'ORU042'),
			('OR', 'ORU043'),
			('OR', 'ORU044'),
			('OR', 'ORU045'),
			('OR', 'ORU046'),
			('OR', 'ORU047'),
			('OR', 'ORU048'),
			('OR', 'ORU049'),
			('OR', 'ORU050'),
			('OR', 'ORU051'),
			('OR', 'ORU052'),
			('OR', 'ORU053'),
			('OR', 'ORU055'),
			('OR', 'ORU056'),
			('OR', 'ORU057'),
			('OR', 'ORU058'),
			('OR', 'ORU059'),
			('OR', 'ORU060'),
			('OR', 'ORU061'),
			('OR', 'ORU062'),
			('OR', 'ORU063'),
			('OR', 'ORU064'),
			('OR', 'ORU066'),
			('OR', 'ORU067'),
			('OR', 'ORU068'),
			('OR', 'ORU069'),
			('OR', 'ORU070'),
			('OR', 'ORU071'),
			('OR', 'ORU072'),
			('OR', 'ORU073'),
			('OR', 'ORU074'),
			('OR', 'ORU075'),
			('OR', 'ORU076'),
			('OR', 'ORU077'),
			('OR', 'ORU078'),
			('OR', 'ORU079'),
			('OR', 'ORU080'),
			('OR', 'ORU081'),
			('OR', 'ORU082'),
			('OR', 'ORU083'),
			('OR', 'ORU084'),
			('OR', 'ORU085'),
			('OR', 'ORU086'),
			('OR', 'ORU087'),
			('OR', 'ORU088'),
			('OR', 'ORU089'),
			('OR', 'ORU090'),
			('OR', 'ORU091'),
			('OR', 'ORU092'),
			('OR', 'ORU093'),
			('OR', 'ORU094'),
			('OR', 'ORU095'),
			('OR', 'ORU096'),
			('OR', 'ORU097'),
			('OR', 'ORU098'),
			('OR', 'ORU099'),
			('OR', 'ORU101'),
			('OR', 'ORU102'),
			('OR', 'ORU103'),
			('OR', 'ORU105'),
			('OR', 'ORU106'),
			('OR', 'ORU107'),
			('OR', 'ORU108'),
			('OR', 'ORU109'),
			('OR', 'ORU110'),
			('OR', 'ORU111'),
			('OR', 'ORU112'),
			('OR', 'ORU113'),
			('OR', 'ORU114'),
			('OR', 'ORU115'),
			('OR', 'ORU116'),
			('OR', 'ORU117'),
			('OR', 'ORU118'),
			('OR', 'ORU119'),
			('OR', 'ORU120'),
			('OR', 'ORU121'),
			('OR', 'ORU122'),
			('OR', 'ORU123'),
			('OR', 'ORU124'),
			('OR', 'ORU125'),
			('OR', 'ORU126'),
			('OR', 'ORU127'),
			('OR', 'ORU128'),
			('OR', 'ORU129'),
			('OR', 'ORU130'),
			('OR', 'ORU131'),
			('OR', 'ORU132'),
			('OR', 'ORU133'),
			('OR', 'ORU134'),
			('OR', 'ORU135'),
			('OR', 'ORU136'),
			('OR', 'ORU137'),
			('OR', 'ORU138'),
			('OR', 'ORU140'),
			('OR', 'ORU141'),
			('OR', 'ORU142'),
			('OR', 'ORU143'),
			('OR', 'ORU144'),
			('OR', 'ORU145'),
			('OR', 'ORU146'),
			('OR', 'ORU147'),
			('OR', 'ORU148'),
			('OR', 'ORU149'),
			('OR', 'ORU150'),
			('OR', 'ORU151'),
			('OR', 'ORU152'),
			('OR', 'ORU153'),
			('OR', 'ORU154'),
			('OR', 'ORU155'),
			('OR', 'ORU156'),
			('OR', 'ORU157'),
			('OR', 'ORU158'),
			('OR', 'ORU159'),
			('OR', 'ORU160'),
			('OR', 'ORU161'),
			('OR', 'ORU162'),
			('OR', 'ORU163'),
			('OR', 'ORU164'),
			('OR', 'ORU165'),
			('OR', 'ORU166'),
			('OR', 'ORU167'),
			('OR', 'ORU168'),
			('OR', 'ORU169'),
			('OR', 'ORU170'),
			('OR', 'ORU171'),
			('OR', 'ORU172'),
			('OR', 'ORU173'),
			('OR', 'ORU174'),
			('OR', 'ORU176'),
			('OR', 'ORU177'),
			('OR', 'ORU178'),
			('OR', 'ORU179'),
			('OR', 'ORU180'),
			('OR', 'ORU181'),
			('OR', 'ORU182'),
			('OR', 'ORU183'),
			('OR', 'ORU184'),
			('OR', 'ORU185'),
			('OR', 'ORU186'),
			('OR', 'ORU187'),
			('OR', 'ORU188'),
			('OR', 'ORU189'),
			('OR', 'ORU190'),
			('OR', 'ORU191'),
			('OR', 'ORU192'),
			('OR', 'ORU193'),
			('OR', 'ORU194'),
			('OR', 'ORU196'),
			('OR', 'ORU197'),
			('OR', 'ORU200'),
			('OR', 'ORU201'),
			('OR', 'ORU203'),
			('OR', 'ORU204'),
			('OR', 'ORU205'),
			('OR', 'ORU206'),
			('OR', 'ORU207'),
			('OR', 'ORU208'),
			('OR', 'ORU209'),
			('OR', 'ORU210'),
			('OR', 'ORU211'),
			('OR', 'ORU213'),
			('OR', 'ORU214'),
			('OR', 'ORU215'),
			('OR', 'ORU216'),
			('OR', 'ORU217'),
			('OR', 'ORU218'),
			('OR', 'ORU219'),
			('OR', 'ORU220'),
			('OR', 'ORU221'),
			('OR', 'ORU222'),
			('OR', 'ORU223'),
			('OR', 'ORU225'),
			('OR', 'ORU226'),
			('OR', 'ORU227'),
			('OR', 'ORU228'),
			('OR', 'ORU234'),
			('OR', 'ORU235'),
			('OR', 'ORU236'),
			('OR', 'ORU237'),
			('OR', 'ORU238'),
			('OR', 'ORU239'),
			('OR', 'ORU240'),
			('OR', 'ORU243'),
			('OR', 'ORU244'),
			('OR', 'ORU246'),
			('OR', 'ORU247'),
			('OR', 'ORU248'),
			('OR', 'ORU249'),
			('OR', 'ORU271'),
			('OR', 'ORU278'),
			('OR', 'ORU279'),
			('OR', 'ORU280'),
			('OR', 'ORU328'),
			('OR', 'ORU353'),
			('OR', 'ORU359'),
			('OR', 'ORU364'),
			('OR', 'ORU367'),
			('OR', 'ORU372'),
			('OR', 'ORU373'),
			('OR', 'ORU387'),
			('OR', 'ORU389'),
			('OR', 'ORU394'),
			('OR', 'ORU395'),
			('OR', 'ORU404'),
			('OR', 'ORU409'),
			('OR', 'ORU410'),
			('OR', 'ORU411'),
			('OR', 'ORX001'),
			('OR', 'ORX002'),
			('OR', 'ORX007'),
			('RI', 'R001'),
			('RI', 'R009'),
			('RI', 'R014'),
			('RI', 'R015'),
			('SC', 'K900'),
			('UT', 'F999'),
			('UT', 'P999'),
			('VA', 'BCRUSH');

		-- 466 new
		-- 42 existing

			-- all the rows in #wastecode should be considered as State Hazardous codes for deciding
			-- if this receipt submits to Emanifest:
			update #wastecode set waste_code_origin = 'S', haz_flag = 'T'

			-- EQAI references waste codes by _uid, so our table needs to be updated to copy them
			-- when we have matches
			update l set waste_code_uid = wc.waste_code_uid
			FROM    #wastecode l
			JOIN wastecode wc
			on l.waste_code_state = wc.state
			and trim(l.waste_code) = trim(wc.display_name)
			and wc.status = 'A'
			and wc.waste_code_origin = 'S'
			and l.waste_code_uid is null

			-- We need to add EQAI's additional known state haz codes
			insert #wastecode (waste_code_state, waste_code, waste_code_origin, haz_flag, waste_code_uid)
			select distinct wc.state, wc.display_name as waste_code, wc.waste_code_origin, wc.haz_flag, wc.waste_code_uid
			from WasteCode wc
			WHERE  wc.haz_flag = 'T' and wc.status = 'A' and wc.waste_code_origin = 'S'
			and not exists (select 1 from #wastecode WHERE waste_code_state = wc.state and waste_code = wc.display_name)

			-- We need to add EQAI's additional fed haz codes
			insert #wastecode (waste_code_state, waste_code, waste_code_origin, haz_flag, waste_code_uid)
			select distinct wc.state, wc.display_name as waste_code, wc.waste_code_origin, wc.haz_flag, wc.waste_code_uid
			from WasteCode wc
			WHERE  wc.haz_flag = 'T' and wc.status = 'A' and wc.waste_code_origin = 'F'
	
			-- now we have #wastecode as a fit replacement to wastecode in queries below
			-- obviously, custom state codes from above that don't have a match in EQAI tables
			-- won't have a _uid to match against receipt data... which is fine, because they
			-- also won't appear in that data (has to be in wastecode in the first place to
			-- get saved on a receipt)

-- end of imported logic (it'll get used and more imported logic below)


Drop Table If Exists #results

select 
'AESOP' as source
, convert(int, a.loc_code) source_company_id
, null source_profit_ctr_id
, a.source_id
,c.name
, c.epa_id,
coalesce(a.cust_manifest_number, a.state_manifest_number, '') as cust_manifest_number,
-- a.cust_manifest_number,
coalesce(q.manifest, '(not sent to Athena)') manifest,
a.received_date,
a.gen_signed_date,
a.custid,
a.cust_name,
( 
	select top 1 federal_user_fee 
	from emanifestuserfee f  (nolock)
	join eManifestSubmissionType ft (nolock) on f.emanifest_submission_type_uid = ft.emanifest_submission_type_uid
	and f.date_effective <= a.gen_signed_date
	WHERE ft.submission_type_desc = case when q.record_type = 'data+image send' then 'Data + Image Upload' else '' end
	order by f.date_effective desc
) emanifest_fee, 
q.status
into #results
from 
#ai a
-- join @tmp_trans_copc copc on  convert(int, a.loc_code) = copc.source_company_id 
left join #c c on convert(int, a.loc_code) = c.company_id
left join #as q on a.source_id = q.source_id and convert(int, a.loc_code) = q.source_company_id 
and coalesce(a.cust_manifest_number, a.state_manifest_number, '') = q.manifest and q.source = 'AESOP'



Drop Table If Exists #required

	select distinct
		r.company_id,
		r.profit_ctr_id,
		r.receipt_id,
		c.name,
		c.epa_id,
		r.manifest,
		r.manifest_flag,
		isnull(r.manifest_form_type, 'H') as manifest_form_type,
		r.receipt_status,
		r.fingerpr_status,
		r.receipt_date,
		r.customer_id,
		r.generator_id,
		customer.cust_name,
		rm.generator_sign_date,
		0 as Emanifest_Required
	into #required
	from #tmp_trans_copc copc 
	join receipt r (nolock) on r.company_id = copc.source_company_id and r.profit_ctr_id = copc.source_profit_ctr_id
	join customer (nolock) on r.customer_id = customer.customer_id
	join ReceiptManifest rm (nolock)
		on rm.receipt_id = r.receipt_id and rm.company_id = r.company_id and rm.profit_ctr_id = r.profit_ctr_id and rm.page = 1
	join tsdf (nolock) on tsdf.tsdf_status = 'A' 
		and tsdf.eq_company = r.company_id 
		and tsdf.eq_profit_ctr = r.profit_ctr_id 
		and isnull(tsdf.tsdf_country_code, '') = 'USA'
	left join #c c  (nolock)on r.company_id = c.company_id and r.profit_ctr_id = c.profit_ctr_id
	WHERE 
	 -- r.receipt_date between @date_start and @date_end
	r.receipt_date between @date_start and @date_end
	and rm.generator_sign_date >= '6/30/2018'
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.manifest_flag in ('M') -- manifest (bond)
	and isnull(r.manifest_form_type, 'H') = 'H' -- hazardous (james bond)
	and r.receipt_status not in ('V', 'R')
	and r.fingerpr_status not in ('V', 'R')
	and not exists ( /* Exclude fully rejected manifests */
		select 1 
		from ReceiptDiscrepancy rd (nolock) 
		where rd.receipt_id = r.receipt_id
		and rd.company_id = r.company_id
		and rd.profit_ctr_id = r.profit_ctr_id
		and rd.discrepancy_full_reject_flag = 'T'
		and isnull(rd.rejected_from_another_tsdf_flag, 'F') = 'F' -- 'F' meaning the rejection record is OURs, outbound.
	)


	-- imported logic from fn_IsEmanifestRequired, modified to run on a set instead of a single receipt.

			/* Hazardous Waste Code Present */
			update r set Emanifest_required = 1
			from #required r
			join ReceiptWasteCode rwc (nolock) 
					on r.receipt_id = rwc.receipt_id
					and r.company_id = rwc.company_id
					and r.profit_ctr_id = rwc.profit_ctr_id
			join #WasteCode wc on rwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin in ('S', 'F')
					and wc.haz_flag = 'T'
			WHERE r.emanifest_required = 0

			/* PCB Present */
			update r set Emanifest_required = 2
			from #required r
			join receiptpcb (nolock) 
				on ReceiptPCB.receipt_id = r.receipt_id  
				and ReceiptPCB.company_id = r.company_id and ReceiptPCB.profit_ctr_id = r.profit_ctr_id
			WHERE r.emanifest_required = 0

			/* Illinois Generator */
			update r set Emanifest_required = 3
			from #required r
			join generator g on r.generator_id = g.generator_id and g.generator_state = 'IL'
			WHERE r.emanifest_required = 0

			/* TX Class 1 Waste from TX Industrial Generator */
			update r set Emanifest_required = 4
			from #required r
			join generator g 
				on r.generator_id = g.generator_id 
				and g.generator_state = 'TX'
				and isnull(g.industrial_flag, 'F') in ('T')
			WHERE r.emanifest_required = 0
			and exists ( /* Require only TX Class 1 waste */
				select 1 
				from ReceiptWasteCode rwc 
				join WasteCode wc on rwc.waste_code_uid = wc.waste_code_uid
				-- 2024/03/19 No swap to local table needed here - it's only checking for TX, not haz.
				where rwc.receipt_id = r.receipt_id
				and rwc.company_id = r.company_id
				and rwc.profit_ctr_id = r.profit_ctr_id
				and wc.waste_code_origin in ('S')
				and wc.state = 'TX'
				and right(wc.display_name, 1) = '1'
			)

			/* TX Class 1 Waste from non-TX Generator */
			update r set Emanifest_required = 4
			from #required r
			join generator g on r.generator_id = g.generator_id and g.generator_state <> 'TX'
			WHERE r.emanifest_required = 0
			and exists ( /* Only relevant in TX TSDFs */ select top 1 1 from tsdf where tsdf_status = 'A' and eq_company = r.company_id and eq_profit_ctr = r.profit_ctr_id and isnull(tsdf_country_code, '') = 'USA' and isnull(tsdf_state, '') = 'TX')
			and exists ( /* Require only TX Class 1 waste */
				select 1 
				from ReceiptWasteCode rwc 
				join WasteCode wc on rwc.waste_code_uid = wc.waste_code_uid
				-- 2024/03/19 No swap to local table needed here - it's only checking for TX, not haz.
				where rwc.receipt_id = r.receipt_id
				and rwc.company_id = r.company_id
				and rwc.profit_ctr_id = r.profit_ctr_id
				and wc.waste_code_origin in ('S')
				and wc.state = 'TX'
				and right(wc.display_name, 1) = '1'
			)

		-- SELECT  * FROM    #required WHERE emanifest_required = 0

	-- end of imported logic (again)

insert #results
select distinct
'EQAI' as source
, convert(varchar(20), r.company_id) source_company_id
, convert(varchar(20), r.profit_ctr_id) source_profit_ctr_id
, convert(varchar(20), r.receipt_id) source_id
, r.name
, r.epa_id
, r.manifest
, coalesce(q.manifest, '(not sent to Athena)') manifest
, r.receipt_date
, r.generator_sign_date
, convert(varchar(20), r.customer_id) customer_id
, r.cust_name
, ( 
	select top 1 federal_user_fee 
	from emanifestuserfee f  (nolock)
	join eManifestSubmissionType ft on f.emanifest_submission_type_uid = ft.emanifest_submission_type_uid
	and f.date_effective <= r.generator_sign_date
	WHERE ft.submission_type_desc = case when q.record_type = 'data+image send' then 'Data + Image Upload' else '' end
	order by f.date_effective desc
) emanifest_fee
, q.status
from #required r (nolock)
left join #as q (nolock) on convert(varchar(20), r.receipt_id) = q.source_id and r.company_id = q.source_company_id and r.profit_ctr_id = q.source_profit_ctr_id and r.manifest = q.manifest and q.source = 'EQAI'
left join #c c  (nolock)on r.company_id = c.company_id and r.profit_ctr_id = c.profit_ctr_id
WHERE r.emanifest_required > 0


SELECT  *  FROM    #results
-- 4285 of 50487 rows not sent to athena

if object_id('tempdb..#c') is not null drop table #c;
if object_id('tempdb..#as') is not null drop table #as;
if object_id('tempdb..#ai') is not null drop table #ai;
-- if object_id('tempdb..#results') is not null drop table #results;

--SELECT  *  FROM    #results
--WHERE manifest like '%not sent%'
---- 2552 -- 2k less when I expand the #AthenaStatus range +- 90 days.
---- 2484 -- 2k less when I expand the #AthenaStatus range +- 1 year.

go

grant execute on sp_emanifest_reconcile_report to eqai, eqweb, cor_user
go
