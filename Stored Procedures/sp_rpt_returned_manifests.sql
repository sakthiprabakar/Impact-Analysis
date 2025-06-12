CREATE PROCEDURE sp_rpt_returned_manifests
	@mailing_type		char(1)
,	@facility			varchar(10)
,	@receipt_id_from	int
,	@receipt_id_to		int
,	@receipt_date_from	datetime
,	@receipt_date_to	datetime
,	@generator_state	varchar(2)
,	@generator_epa_id	varchar(12)
,	@manifest			varchar(15)
,	@trip_id			int
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	r_returned_manifests

04/11/2017 MPM 	Created

sp_rpt_returned_manifests 'X', 'ALL', 1, 999999, '1/1/1900 00:00:00', '1/1/3000 23:59:59', 'XX', 'ALL', 'ALL', -99
sp_rpt_returned_manifests null, '21-00', null, null, null, null, null, null, null, 49775
sp_rpt_returned_manifests null, '21-00', 1177852, 1178914, null, null, null, null, null, null
sp_rpt_returned_manifests null, '21-00', 1178898, null, null, null, null, null, null, null
sp_rpt_returned_manifests null, null, null, null, '03/01/2017', '04/11/2017', 'MI', null, null, null
sp_rpt_returned_manifests null, null, null, null, null, null, 'MI', 'MID981092190', null, null
sp_rpt_returned_manifests null, null, null, null, null, null, null, null, '014839245JJK', null
sp_rpt_returned_manifests null, null, 700377, null, null, null, null, null, null, null
sp_rpt_returned_manifests null, null, null, null, null, null, 'MI', null, null, null
sp_rpt_returned_manifests 'I', null, null, null, null, null, null, null, null, null

****************************************************************************************/

DECLARE @facility_all		varchar(3)
,	@receipt_id_all			varchar(3)
,	@receipt_date_all		varchar(3)
,	@generator_state_all	varchar(3)
,	@generator_epa_id_all	varchar(3)
,	@manifest_all			varchar(3)
,	@trip_id_all			varchar(3)
,	@mailing_type_all		varchar(3)
,	@company_id				int
,	@profit_ctr_id			int

IF @facility = '' SELECT @facility = NULL
IF @generator_state = '' SELECT @generator_state = NULL
IF @generator_epa_id = '' SELECT @generator_epa_id = NULL
IF @manifest = '' SELECT @manifest = NULL
IF @mailing_type = '' SELECT @mailing_type = NULL

IF @facility IS NULL OR @facility = 'ALL' 
BEGIN
	SELECT @facility_all = 'ALL'
END
ELSE
BEGIN
--	SELECT @company_id = CONVERT(int, LEFT(@facility, CHARINDEX('-', @facility) - 1))
--	SELECT @profit_ctr_id = CONVERT(int, SUBSTRING(@facility, CHARINDEX('-', @facility) + 1, LEN(@facility)))
	SELECT @company_id = CONVERT(int, LEFT(@facility, CASE WHEN CHARINDEX('-', @facility) = 0 THEN LEN(@facility) ELSE CHARINDEX('-', @facility) - 1 END))
	SELECT @profit_ctr_id = CONVERT(int, SUBSTRING(@facility, CASE WHEN CHARINDEX('-', @facility) = 0 THEN LEN(@facility) ELSE CHARINDEX('-', @facility) + 1 END, LEN(@facility)))
END

IF @receipt_id_from IS NULL AND @receipt_id_to IS NULL OR @receipt_id_from = 1 and @receipt_id_to = 999999 SELECT @receipt_id_all = 'ALL'
IF @receipt_date_from IS NULL AND @receipt_date_to IS NULL OR @receipt_date_from = '1/1/1900 00:00:00' AND @receipt_date_to = '1/1/3000 23:59:59' SELECT @receipt_date_all = 'ALL'
IF @generator_state IS NULL or @generator_state = 'XX' SELECT @generator_state_all = 'ALL'
IF @generator_epa_id IS NULL OR @generator_epa_id = 'ALL' SELECT @generator_epa_id_all = 'ALL'
IF @manifest IS NULL OR @manifest = 'ALL' SELECT @manifest_all = 'ALL'
IF @trip_id IS NULL OR @trip_id = -99 SELECT @trip_id_all = 'ALL'
IF @mailing_type IS NULL OR @mailing_type = 'X' SELECT @mailing_type_all = 'ALL'

select DISTINCT
	   replace(str(Receipt.company_id,2),' ','0') + '-' + replace(str(Receipt.profit_ctr_id,2),' ','0') as facility,
       Receipt.receipt_id,
	   Receipt.receipt_date,
	   Receipt.manifest,
	   Generator.generator_name,
	   Generator.EPA_ID,
	   Generator.generator_state,
	   Receipt.TSDF_code,
	   ReceiptHeader.trip_id,
	   ReturnedManifestLog.date_mailed,
	   MailingService.mailing_service,
	   ReturnedManifestLog.tracking_number,
	   ReturnedManifestLog.date_added,
	   ReturnedManifestLog.added_by,
	   ReturnedManifestLog.date_modified,
	   ReturnedManifestLog.modified_by,
	   CASE ReturnedManifestLog.mailing_type
			WHEN 'I' THEN 'Generator Initial'
			WHEN 'F' THEN 'Generator Final'
			WHEN 'S' THEN 'State'
		END as mailing_type
from Receipt
	 INNER JOIN Generator ON Generator.generator_id = Receipt.generator_id
	 INNER JOIN ReturnedManifestLog ON ReturnedManifestLog.company_id = Receipt.company_id	
		AND ReturnedManifestLog.profit_ctr_id = Receipt.profit_ctr_id
		AND ReturnedManifestLog.receipt_id = Receipt.receipt_id
	 LEFT OUTER JOIN ReceiptHeader ON ReceiptHeader.company_id = Receipt.company_id	
		AND ReceiptHeader.profit_ctr_id = Receipt.profit_ctr_id
		AND ReceiptHeader.receipt_id = Receipt.receipt_id
	 LEFT OUTER JOIN MailingService ON MailingService.mailing_service_uid = ReturnedManifestLog.mailing_service_uid
		WHERE Receipt.trans_mode = 'I'
			AND Receipt.receipt_status NOT IN ('V','R')
			AND Receipt.trans_type <> 'X'
			AND (@facility_all = 'ALL' OR (Receipt.company_id = @company_id AND Receipt.profit_ctr_id = @profit_ctr_id))
			AND (@receipt_id_all = 'ALL' OR (Receipt.receipt_id = @receipt_id_from AND @receipt_id_to IS NULL) OR (@receipt_id_from IS NOT NULL AND @receipt_id_to IS NOT NULL AND Receipt.receipt_id BETWEEN @receipt_id_from AND @receipt_id_to))
			AND (@receipt_date_all = 'ALL' OR (Receipt.receipt_date = @receipt_date_from AND @receipt_date_to IS NULL) OR (@receipt_date_from IS NOT NULL AND @receipt_date_to IS NOT NULL and Receipt.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to))
			AND (@manifest_all = 'ALL' OR Receipt.manifest = @manifest)
			AND (@generator_state_all = 'ALL' OR Generator.generator_state = @generator_state)
			AND (@generator_epa_id_all = 'ALL' OR Generator.EPA_ID = @generator_epa_id)
			AND (@trip_id_all = 'ALL' OR ReceiptHeader.trip_id = @trip_id)
			AND (@mailing_type_all = 'ALL' OR ReturnedManifestLog.mailing_type = @mailing_type)
	ORDER BY facility, Receipt.receipt_date

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_returned_manifests] TO [EQAI]
    AS [dbo];

