CREATE PROCEDURE sp_rpt_steers_detail_report
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from		datetime
,	@date_to		datetime
AS
/***************************************************************************************
r_steers_detail

04/17/2018 AM	Created
05/23/2018 AM   Modified generator_state_id logic
06/11/2018 AM   GEM:51238  Not handling NULL for State waste code sequence_id for state_code field. 
06/22/2018 AM   GEM:51443  Modified report to add industrial_flag and changed where clause.
09/23/2018 PRK  DevOps:10591  Modified inventory weight to return only 3 decimal places, per TCEQ spec

sp_rpt_steers_detail_report 21, 0,  '3/1/2018', '6/1/2018'
sp_rpt_steers_detail_report 55, 0,  '7/1/2019', '8/1/2019'

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE 
	@debug 			int
	
SELECT
	SUBSTRING(LTRIM(RTRIM(ISNULL(t.state_regulatory_id,''))), 1, 5) as site_state_id, 
	'R1' as 'report_type',	--always R1?
    '' as 'for_internal_use',	--always blank?
    RIGHT('0' + CAST(MONTH(r.receipt_date) AS NVARCHAR(2)), 2) 
       + '/'  + RIGHT(CAST(YEAR(r.receipt_date) AS NVARCHAR(4)), 2) as 'report_period',  --how is this determined?    
    '' as 'no_shipments_received',	
    SUBSTRING(LTRIM(RTRIM(ISNULL(r.manifest,''))), 1, 12)as 'state_manifest',	--should this be spelled manifest?
   -- SUBSTRING(LTRIM(RTRIM(ISNULL(g.state_id,''))), 1, 12) as 'generator_state_id', --State ID from the generator record   
	CASE when g.generator_state = 'TX'
     THEN SUBSTRING(LTRIM(RTRIM(ISNULL(g.state_id,''))), 1, 12)
     else
        ( select SUBSTRING(LTRIM(RTRIM(ISNULL(trlc.tx_out_of_state_generator_code,''))), 1, 12)  
        from  TexasReportingLocationCode trlc
        where g.generator_state = trlc.state_code )
     end as generator_state_id ,
	SUBSTRING(LTRIM(RTRIM(ISNULL(g.EPA_ID,''))), 1, 12) as 'generator_epa_id',	--EPA ID from the generator record        
	(
		select SUBSTRING(LTRIM(RTRIM(ISNULL(wc.display_name,''))), 1, 8)
		from receiptwastecode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id  and wc.state = 'TX' and IsNull (rwc.sequence_id,1) = 
		(	select IsNull ( min(rwc.sequence_id),1 ) from receiptwastecode rwc 
			join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
			where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.state = 'TX' 
		)
	) as state_code,						--Texas state waste code
      (
		select SUBSTRING(LTRIM(RTRIM(ISNULL(wc.display_name,''))), 1, 4)
		from receiptwastecode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F' and rwc.sequence_id = 
		(	select min(rwc.sequence_id) from receiptwastecode rwc 
			join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
			where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F'
		)
	 ) as epa_code1,							--Federal waste code 1, need to add case for NULL to be empty string
	(
		select SUBSTRING(LTRIM(RTRIM(ISNULL(wc.display_name,''))), 1, 4) 
		from receiptwastecode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F' and rwc.sequence_id = 
		(	select min(rwc.sequence_id)+1 from receiptwastecode rwc 
			join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
			where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F'
		)
	)  as epa_code2,						--Federal waste code 2, need to add case for NULL to be empty string
	(
		select SUBSTRING(LTRIM(RTRIM(ISNULL(wc.display_name,''))), 1, 4) 
		from receiptwastecode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F' and rwc.sequence_id = 
		(	select min(rwc.sequence_id)+2 from receiptwastecode rwc 
			join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
			where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F'
		)
	)  as epa_code3,						--Federal waste code 3, need to add case for NULL to be empty string
	(
		select  SUBSTRING(LTRIM(RTRIM(ISNULL(wc.display_name,''))), 1, 4)
		from receiptwastecode rwc 
		join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
		where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F' and rwc.sequence_id = 
		(	select min(rwc.sequence_id)+3 from receiptwastecode rwc 
			join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid
			where rwc.receipt_id = r.receipt_id and rwc.company_id = r.company_id and rwc.profit_ctr_id = r.profit_ctr_id and rwc.line_id = r.line_id and wc.waste_code_origin = 'F'
		)
	)  as epa_code4,	--Federal waste code 4, need to add case for NULL to be empty string 
	    --CONVERT (varchar(30) ,dbo.fn_receipt_weight_line (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id) )as inv_wt,	--needs to be adjusted to be the sum of container weight for the inbound line?
		CONVERT (varchar(30) ,cast(dbo.fn_receipt_weight_line (r.receipt_id,r.line_id,r.profit_ctr_id,r.company_id) as decimal(18,3)) )as inv_wt,	--needs to be adjusted to be the sum of container weight for the inbound line?
		'P' as wt_unit,	--always in LBS  
    case when 
    ISNUMERIC ( SUBSTRING(LTRIM(RTRIM(ISNULL(trt.management_code,''))), 2, 4) ) = 1 Then 
			SUBSTRING(LTRIM(RTRIM(ISNULL(trt.management_code,''))), 2, 4)
    else
    ''
    end as system_type_code,     --management code?  this should be adjusted to just the number portion of the code.  What to do with LIB?  show NONE as empty string?	
	CONVERT(VARCHAR(15),r.receipt_date , 110)as date_shipped,	--Date received into the facility
	SUBSTRING(LTRIM(RTRIM(ISNULL(trid.transporter_state_id,''))), 1, 5)as trans_state_id, --Texas issued transporter state ID - not yet in EQAI, will need to join to new table where State = TX for this transporter  (tsi.state_id) and status = 'A'
	SUBSTRING(LTRIM(RTRIM(ISNULL(tr.transporter_EPA_ID,''))), 1, 12)as trans_epa_id,			--Transporter EPA ID
	'B' as 'rpt_method',							--always 'B'
	'A' as 'action_code',							--always 'A'
    Convert(varchar(10), r.company_id )as company_id,
    Convert(varchar(10),r.profit_ctr_id )as profit_ctr_id,
    Convert(varchar(20),r.receipt_id ) as receipt_id,
    Convert(varchar(10),r.line_id )  as line_id,
    g.industrial_flag as industrial_flag
from receipt r 
	join generator g
		on r.generator_id = g.generator_id
	join tsdf t
		on t.eq_company = @company_id
		and t.eq_profit_ctr = @profit_ctr_id
		and t.tsdf_status = 'A'
		and t.eq_flag = 'T'
		and t.tsdf_state = 'TX'  
	join transporter tr
		on r.hauler = tr.transporter_code
	left outer join TransporterXStateID trid
		on tr.transporter_code = trid.transporter_code
		and trid.transporter_state = 'TX'
	join treatment trt
		on r.treatment_id = trt.treatment_id
		and r.company_id = trt.company_id
		and r.profit_ctr_id = trt.profit_ctr_id
where 
	r.receipt_date between @date_from AND @date_to
	and r.company_id = @company_id
	and r.profit_ctr_id = @profit_ctr_id
	and r.receipt_status not in ('V', 'R')  
	and r.trans_mode = 'I'  
	and r.trans_type = 'D'  
	and (  --check for the presence of a STEERS reportable waste code
		select count(*) 
		from ReceiptWasteCode rwc 
		join wastecode wc 
		on rwc.waste_code_uid = wc.waste_code_uid 
		where wc.state = 'TX' 
		and rwc.company_id = r.company_id 
		and rwc.profit_ctr_id = r.profit_ctr_id 
		and rwc.receipt_id = r.receipt_id 
		and rwc.line_id = r.line_id
		and wc.STEERS_reportable_flag = 'T') > 0
	--Added for Gemini 51443
	--this next condition is to exclude receipt lines where the generator industrial flag = 'F' and the Texas code ends in a '1' and there are no Federal waste codes
	and not (g.industrial_flag <> 'T'
		and (  --check for the presence of a STEERS reportable waste code ending in '1'
			select count(*) 
				from ReceiptWasteCode rwc 
				join wastecode wc 
				on rwc.waste_code_uid = wc.waste_code_uid 
				where wc.state = 'TX' 
				and rwc.company_id = r.company_id 
				and rwc.profit_ctr_id = r.profit_ctr_id 
				and rwc.receipt_id = r.receipt_id 
				and rwc.line_id = r.line_id
				and wc.STEERS_reportable_flag = 'T'
				and Right(wc.display_name, 1) = '1' ) > 0 
		and  ( --check that the line has no federal waste codes
				select count(*) 
					from ReceiptWasteCode rwc 
					join wastecode wc 
					on rwc.waste_code_uid = wc.waste_code_uid 
					where  rwc.company_id = r.company_id 
					and rwc.profit_ctr_id = r.profit_ctr_id 
					and rwc.receipt_id = r.receipt_id 
					and rwc.line_id = r.line_id
					and  wc.waste_code_origin = 'F' ) = 0   
		)
order by r.receipt_date
GO

