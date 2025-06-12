CREATE PROCEDURE sp_container_entry_retrieve
	@profit_ctr_id	int
,	@staging_rows	varchar(max)
,	@treatment_id	int
,	@receipt_id		int
,	@company_id		int
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	d_container_entry_retrieve

11/03/2011 MPM 	Created

sp_container_entry_retrieve 0, '600A, 600B', -1, -1, 21 
****************************************************************************************/
SET NOCOUNT ON

CREATE TABLE #tmp_staging_rows (staging_row	varchar(5) NULL)
EXEC sp_list 0, @staging_rows, 'STRING', '#tmp_staging_rows'

SELECT DISTINCT ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
CONVERT(varchar(15), ContainerDestination.receipt_id) AS Container,
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
profile.ots_flag

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
INNER JOIN Receipt ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
Inner Join Profile on Receipt.profile_id = profile.profile_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND (Container.staging_row IS NOT NULL AND Container.staging_row in (select staging_row from #tmp_staging_rows) 
	AND ContainerDestination.treatment_id IS NOT NULL AND ContainerDestination.treatment_id = @treatment_id 
	AND Container.receipt_id = @receipt_id )
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.fingerpr_status NOT IN ('V', 'R')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND ContainerDestination.container_type = 'R'
AND ContainerDestination.company_id = @company_id

UNION ALL

SELECT DISTINCT 
ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
CONVERT(varchar(15), ContainerDestination.receipt_id) AS Container,
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
profile.ots_flag

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
INNER JOIN Receipt ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
Inner Join Profile on Receipt.profile_id = profile.profile_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND (
	((@staging_rows = 'ALL') OR (Container.staging_row IS NOT NULL AND Container.staging_row in (select staging_row from #tmp_staging_rows)))
	AND (ContainerDestination.treatment_id IS NOT NULL AND ContainerDestination.treatment_id = @treatment_id)
	AND @receipt_id = -1 )
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.fingerpr_status NOT IN ('V', 'R')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND ContainerDestination.container_type = 'R'
AND ContainerDestination.company_id = @company_id

UNION ALL

SELECT DISTINCT 
ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
CONVERT(varchar(15), ContainerDestination.receipt_id) AS Container,
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
profile.ots_flag

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
INNER JOIN Receipt ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
Inner Join Profile on Receipt.profile_id = profile.profile_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND (
	((@staging_rows = 'ALL') OR (Container.staging_row IS NOT NULL AND Container.staging_row in (select staging_row from #tmp_staging_rows)))
	AND (Container.receipt_id = @receipt_id)
	AND @treatment_id = -1)
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.fingerpr_status NOT IN ('V', 'R')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND ContainerDestination.container_type = 'R'
AND ContainerDestination.company_id = @company_id

UNION ALL

SELECT DISTINCT 
ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
CONVERT(varchar(15), ContainerDestination.receipt_id) AS Container,
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
profile.ots_flag

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
INNER JOIN Receipt ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
Inner Join Profile on Receipt.profile_id = profile.profile_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND (@staging_rows = 'NONE' AND ContainerDestination.treatment_id = @treatment_id 
	AND Container.receipt_id = @receipt_id )
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.fingerpr_status NOT IN ('V', 'R')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND ContainerDestination.container_type = 'R'
AND ContainerDestination.company_id = @company_id

UNION ALL

SELECT 
ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
CONVERT(varchar(15), ContainerDestination.receipt_id) AS Container,
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
profile.ots_flag

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
INNER JOIN Receipt ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
Inner Join Profile on Receipt.profile_id = profile.profile_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND (
((@staging_rows = 'ALL') OR (Container.staging_row IS NOT NULL AND Container.staging_row in (select staging_row from #tmp_staging_rows)))
	AND @treatment_id = -1 and @receipt_id = -1 )
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.fingerpr_status NOT IN ('V', 'R')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND ContainerDestination.container_type = 'R'
AND ContainerDestination.company_id = @company_id

UNION ALL

SELECT 
ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
CONVERT(varchar(15), ContainerDestination.receipt_id) AS Container,
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
profile.ots_flag

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
INNER JOIN Receipt ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
Inner Join Profile on Receipt.profile_id = profile.profile_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ( @staging_rows = 'NONE' AND ContainerDestination.treatment_id = @treatment_id and @receipt_id = -1 )
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.fingerpr_status NOT IN ('V', 'R')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND ContainerDestination.container_type = 'R'
AND ContainerDestination.company_id = @company_id

UNION ALL

SELECT 
ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
CONVERT(varchar(15), ContainerDestination.receipt_id) AS Container,
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
profile.ots_flag

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
INNER JOIN Receipt ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
Inner Join Profile on Receipt.profile_id = profile.profile_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ( @staging_rows = 'NONE' AND @treatment_id = -1 and Container.receipt_id = @receipt_id)
AND Receipt.receipt_status IN ('L', 'U', 'A')
AND Receipt.fingerpr_status NOT IN ('V', 'R')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND ContainerDestination.container_type = 'R'
AND ContainerDestination.company_id = @company_id

UNION ALL

SELECT ContainerDestination.receipt_id,
ContainerDestination.line_id,
ContainerDestination.profit_ctr_id,
ContainerDestination.container_type,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.location,
ContainerDestination.tracking_num,
ContainerDestination.disposal_date,
ContainerDestination.date_modified,
ContainerDestination.modified_by,
ContainerDestination.location_type,
Container.staging_row,
ContainerDestination.status,
Container = dbo.fn_container_stock(ContainerDestination.line_id,containerdestination.company_id, ContainerDestination.profit_ctr_id ),
CONVERT(varchar(8000), NULL) AS waste_codes,
1 AS assign_type,
tsdf_approval = dbo.fn_container_tsdf_approval (ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id, ContainerDestination.container_type, ContainerDestination.profit_ctr_ID,ContainerDestination.company_id),
ContainerDestination.treatment_id AS treatment_id,
Treatment.treatment_desc AS treatment_desc,
0 AS toggle,
'F'

FROM Container
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
	AND  Container.company_id = ContainerDestination.company_id
LEFT OUTER JOIN Treatment ON ContainerDestination.company_id = Treatment.company_id
	AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
	AND ContainerDestination.treatment_id = Treatment.treatment_id
WHERE ContainerDestination.status = 'N'
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.container_type = 'S'
AND ((@staging_rows = 'ALL') OR (Container.staging_row in (select staging_row from #tmp_staging_rows)))
AND ((@treatment_id = -1) OR (ContainerDestination.treatment_id = @treatment_id)) 
AND ContainerDestination.company_id = @company_id

ORDER BY Container

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_entry_retrieve] TO [EQAI]
    AS [dbo];

