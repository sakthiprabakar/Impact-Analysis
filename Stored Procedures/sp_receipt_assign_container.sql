DROP PROCEDURE IF EXISTS sp_receipt_assign_container 
GO

CREATE PROCEDURE sp_receipt_assign_container
	@bulk_flag				char(1)
,	@outbound_receipt_id	int
,	@outbound_line_id		int
,	@company_id				int
,	@profit_ctr_id			int
,	@approval_transship_flag varchar(3)
,	@location				varchar(15)
,	@staging_row			varchar(5)
,	@date_from				datetime
,	@date_to				datetime
,	@inbound_receipt_id		int = NULL
WITH RECOMPILE
AS
/****************************************************************************************************************
10/03/2002  LJT Modified to replace if exists with 0 = on the nested select of nonbulk without drum detail.
02/18/2004  SCC Returns only containers where fingerprint status is Accepted or Rejected.
11/11/2004  MK  Changed generator_code to generator_id
12/27/2004  SCC Changed for Container Tracking
03/30/2005  MK  Added container_id to join between container and containerdestination
04/01/2005  MK  Added inbound_receipt_id to input args to accomodate retrieve in EQAI
08/02/2005  MK  Added lines to where clauses to restrict by inbound receipt id if entered
08/31/2005  MK  Added tsdf_approval_code to select
09/27/2005  SCC Added pre-assigned process containers for assignment
05/22/2006  SCC Added support for Transfers.  Transfer requests have @bulk_flag = 'X', sure to make
				the first set of Selects fail, which is what we want
06/30/2006  RG  changed to use Profile info for info inbound
07/03/2006  SCC Join on company, profit center, approval code until Receipt profile ID
				is populated.
09/21/2007  WAC Removed join to ProfileQuoteApproval table now that receipt.profile_id is populated.
05/07/2012  RWB Set transaction isolation level to eliminate blocking issues, remove temp table
08/22/2012  RWB Query was sometimes running for minutes, restructured reference to receipt_id in where clauses
09/11/2012  JDB Moved SP from Plt_XX_AI to Plt_AI in order to try to speed it up by not needing views.
				Added @company_id as a parameter and removed the "container" computed field.
09/24/2012	JDB	Added company_id and profit_ctr_id to Select list.
12/13/2013	RWB	Created temp table for results (PB was taking 10+ seconds to run without this)
12/10/2018  MPM	GEM 57113 - Added trip_id to the result set
12/01/2021	MPM	DevOps 22014 - Modified to return containers with null location_type.
02/21/2022	MPM DevOps 29881 - Added Container.manifest_container and Container.container_size to the result set.

EXEC  Plt_22_AI..sp_receipt_assign_container 'F', 182037, 1, 0, 'ALL', 'ALL', 'ALL', '8/13/12','9/13/12', NULL
EXEC  sp_receipt_assign_container 'F', 182037, 1, 22, 0, 'ALL', 'ALL', 'ALL', '8/13/12','9/13/12', NULL

EXEC  Plt_22_AI..sp_receipt_assign_container 'F', 182037, 1, 0, 'ALL', 'ALL', 'ALL', '1/1/80','9/13/12', NULL		-- 1174, 0:17 
EXEC  sp_receipt_assign_container 'F', 182037, 1, 22, 0, 'ALL', 'ALL', 'ALL', '1/1/80','9/13/12', NULL				-- 1174, 0:44

execute Plt_14_AI.dbo.sp_receipt_assign_container;1 @bulk_flag = 'F', @outbound_receipt_id = 19453, @outbound_line_id = 1, @profit_ctr_id = 6, @approval_transship_flag = 'ALL', @location = 'ALL', @staging_row = 'LIQ23', @date_from = '1-1-1980 0:0:0.000', @date_to = '9-14-2012 23:59:59.000', @inbound_receipt_id = 0		-- 0, 0:03
execute sp_receipt_assign_container;1 @bulk_flag = 'F', @outbound_receipt_id = 19453, @outbound_line_id = 1, @company_id = 14, @profit_ctr_id = 6, @approval_transship_flag = 'ALL', @location = 'ALL', @staging_row = 'LIQ23', @date_from = '1-1-1980 0:0:0.000', @date_to = '9-14-2012 23:59:59.000', @inbound_receipt_id = 0		-- 0, 0:01

EXEC Plt_22_AI.dbo.sp_receipt_assign_container;1 @bulk_flag = 'F', @outbound_receipt_id = 183237, @outbound_line_id = 3, @profit_ctr_id = 0, @approval_transship_flag = 'ALL', @location = 'ALL', @staging_row = 'WPRM', @date_from = '1-1-1980 0:0:0.000', @date_to = '9-13-2012 23:59:59.000', @inbound_receipt_id = 0
execute dbo.sp_receipt_assign_container;1 @bulk_flag = 'X', @outbound_receipt_id = 16492, @outbound_line_id = 2, @profit_ctr_id = 2, @approval_transship_flag = 'ALL', @location = 'ALL', @staging_row = 'EQOK', @date_from = '8-18-2012 0:0:0.000', @date_to = '9-18-2012 23:59:59.000', @inbound_receipt_id = 0
execute dbo.sp_receipt_assign_container;1 @bulk_flag = 'X', @outbound_receipt_id = 16490, @outbound_line_id = 1, @profit_ctr_id = 2, @approval_transship_flag = 'ALL', @location = 'EQFL', @staging_row = 'EQFLW', @date_from = '8-18-2012 0:0:0.000', @date_to = '9-18-2012 23:59:59.000', @inbound_receipt_id = 0
execute dbo.sp_receipt_assign_container;1 @bulk_flag = 'F', @outbound_receipt_id = 182037, @outbound_line_id = 5, @profit_ctr_id = 0, @approval_transship_flag = 'ALL', @location = 'ALL', @staging_row = 'TS', @date_from = '1-1-1980 0:0:0.000', @date_to = '9-18-2012 23:59:59.000', @inbound_receipt_id = 0
execute dbo.sp_receipt_assign_container;1 @bulk_flag = 'X', @outbound_receipt_id = 52985, @outbound_line_id = 1, @company_id = 14, @profit_ctr_id = 6, @approval_transship_flag = 'ALL', @location = 'ALL', @staging_row = 'ALL', @date_from = '11-9-2018 0:0:0.000', @date_to = '12-10-2018 23:59:59.000', @inbound_receipt_id = 0
****************************************************************************************************************/					

-- 05/09/12 RWB include company_id to force use of index
--declare @company_id int
--select @company_id = company_id from Company (nolock)

-- 05/07/12 RWB Set transaction isolation level to eliminate blocking issues
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

create table #result (
include int null,
container_percent int null,
company_id int null,
profit_ctr_id int null,
receipt_id int null,
line_id int null,
container_id int null,
sequence_id int null,
container_type char(1) null,
status char(1) null,
location varchar(15) null,
staging_row varchar(5) null,
approval_code varchar(15) null,
manifest varchar(15),
generator varchar(54) null,
bulk_flag char(1) null,
receipt_date datetime null,
tsdf_approval_code varchar(40) null,
waste_stream varchar(10) null,
trip_id	int null,
manifest_container varchar(15) null,
container_size varchar(15) null)

DECLARE @debug int
SET @debug = 0

insert #result
-- Get Incomplete Container lines without a tracking number
SELECT DISTINCT 
0 as include, -- rb
--DBO.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container,
--CONVERT(varchar(10), ContainerDestination.receipt_id) + '-' + CONVERT(varchar(5), ContainerDestination.line_id) AS container,
ContainerDestination.container_percent,
ContainerDestination.company_id, 
ContainerDestination.profit_ctr_id,
ContainerDestination.receipt_id, 
ContainerDestination.line_id,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.container_type,
ContainerDestination.status,
ContainerDestination.location, 
Container.staging_row, 
Receipt.approval_code,
Receipt.manifest,
Generator.EPA_ID + '  ' + Generator.generator_name as generator,
Receipt.bulk_flag,
Receipt.receipt_date,
--rb Remove temp table, moved column above to position in result set
--Receipt.approval_code,
ContainerDestination.tsdf_approval_code,
ContainerDestination.waste_stream,
Container.trip_id,
Container.manifest_container,
Container.container_size
-- rb Remove temp table
--INTO #tmp
FROM Receipt
JOIN Profile ON Receipt.profile_id = Profile.profile_id
	AND Profile.curr_status_code = 'A'
LEFT OUTER JOIN Generator ON Receipt.generator_id = Generator.generator_id 
JOIN Container ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
JOIN ContainerDestination ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.container_type = ContainerDestination.container_type
	AND ContainerDestination.status = 'N'
	AND ContainerDestination.container_type = 'R'
	AND LTRIM(RTRIM(ISNULL(ContainerDestination.location_type, ''))) IN ('O', 'U', '', 'P')
WHERE 1=1
AND Receipt.company_id = @company_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.receipt_date BETWEEN @date_from AND @date_to
AND Receipt.receipt_status IN ('L','U','A')
AND Receipt.fingerpr_status = 'A'
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND Receipt.bulk_flag = @bulk_flag
AND (@approval_transship_flag = 'ALL' OR Profile.transship_flag = @approval_transship_flag)
AND (@staging_row = 'ALL' OR (ISNULL(Container.staging_row, @staging_row) = @staging_row))
AND (@location = 'ALL' OR (ISNULL(ContainerDestination.location, '') = @location))
-- rb added when temp table removed
-- rb 08/22/2012 Sporadic occasions when query took minutes...restructure comparison to @inbound_receipt_id argument
--AND Receipt.receipt_id = case when ISNULL(@inbound_receipt_id,0) > 0 then @inbound_receipt_id else Receipt.receipt_id end
AND (ISNULL(@inbound_receipt_id,0) = 0 OR ISNULL(Receipt.receipt_id, 0) = @inbound_receipt_id)

UNION ALL

-- Include Containers for this outbound Receipt Line, regardless of dates, transship 
SELECT DISTINCT 
0 as include, -- rb
--DBO.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container,
ContainerDestination.container_percent,
ContainerDestination.company_id, 
ContainerDestination.profit_ctr_id,
ContainerDestination.receipt_id, 
ContainerDestination.line_id,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.container_type,
ContainerDestination.status,
ContainerDestination.location, 
Container.staging_row, 
Receipt.approval_code,
Receipt.manifest,
Generator.EPA_ID + '  ' + Generator.generator_name as generator,
Receipt.bulk_flag,
Receipt.receipt_date,
--rb Remove temp table, moved column above to position in result set
--Receipt.approval_code,
ContainerDestination.tsdf_approval_code,
ContainerDestination.waste_stream,
Container.trip_id,
Container.manifest_container,
Container.container_size
FROM Receipt
JOIN Profile ON Receipt.profile_id = Profile.profile_id
	AND Profile.curr_status_code = 'A'
LEFT OUTER JOIN Generator ON Receipt.generator_id = Generator.generator_id
JOIN Container ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
JOIN ContainerDestination ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.container_type = ContainerDestination.container_type
	AND ContainerDestination.status IN ('C', 'N')
	AND ContainerDestination.container_type = 'R'
	AND ISNULL(ContainerDestination.location_type,'') IN ('O', 'U', '', 'P')
WHERE 1=1
AND Receipt.company_id = @company_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.receipt_status IN ('L','U','A')
AND Receipt.fingerpr_status = 'A'
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND Receipt.bulk_flag = @bulk_flag
AND ContainerDestination.tracking_num = DBO.fn_container_receipt(@outbound_receipt_id, @outbound_line_id)
-- rb added when temp table removed
-- rb 08/22/2012 Sporadic occasions when query took minutes...restructure comparison to @inbound_receipt_id argument
--AND Receipt.receipt_id = case when ISNULL(@inbound_receipt_id,0) > 0 then @inbound_receipt_id else Receipt.receipt_id end
AND (ISNULL(@inbound_receipt_id,0) = 0 OR ISNULL(Receipt.receipt_id, 0) = @inbound_receipt_id)

UNION ALL

-- Get Incomplete TRANSFER Container lines without a tracking number
SELECT DISTINCT 
0 as include, -- rb
--DBO.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container,
ContainerDestination.container_percent,
ContainerDestination.company_id, 
ContainerDestination.profit_ctr_id,
ContainerDestination.receipt_id, 
ContainerDestination.line_id,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.container_type,
ContainerDestination.status,
ContainerDestination.location, 
Container.staging_row, 
ContainerDestination.tsdf_approval_code,
Container.manifest,
NULL as generator,
Receipt.bulk_flag,
Receipt.receipt_date,
--rb Remove temp table, moved column above to position in result set
--ContainerDestination.tsdf_approval_code,
ContainerDestination.tsdf_approval_code,
ContainerDestination.waste_stream,
Container.trip_id,
Container.manifest_container,
Container.container_size
FROM Receipt
JOIN Container ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
JOIN ContainerDestination ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.container_type = ContainerDestination.container_type
WHERE 1=1
AND Receipt.company_id = @company_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.receipt_date BETWEEN @date_from AND @date_to
AND Receipt.receipt_status IN ('U', 'A')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'X'
AND Receipt.bulk_flag = 'F'
AND ContainerDestination.status = 'N'
AND ContainerDestination.container_type = 'R'
AND LTRIM(RTRIM(ISNULL(ContainerDestination.location_type, ''))) IN ('O', 'U', '', 'P')
AND @bulk_flag = 'X'
AND (@staging_row = 'ALL' OR (ISNULL(Container.staging_row, @staging_row) = @staging_row))
AND (@location = 'ALL' OR (ISNULL(ContainerDestination.location, '') = @location))
-- rb added when temp table removed
-- rb 08/22/2012 Sporadic occasions when query took minutes...restructure comparison to @inbound_receipt_id argument
--AND Receipt.receipt_id = case when ISNULL(@inbound_receipt_id,0) > 0 then @inbound_receipt_id else Receipt.receipt_id end
AND (ISNULL(@inbound_receipt_id,0) = 0 OR ISNULL(Receipt.receipt_id, 0) = @inbound_receipt_id)

UNION ALL

-- Include TRANSFER Containers for this outbound Receipt Line, regardless of dates, transship 
SELECT DISTINCT 
0 as include, -- rb
--DBO.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container,
ContainerDestination.container_percent,
ContainerDestination.company_id, 
ContainerDestination.profit_ctr_id,
ContainerDestination.receipt_id, 
ContainerDestination.line_id,
ContainerDestination.container_id,
ContainerDestination.sequence_id,
ContainerDestination.container_type,
ContainerDestination.status,
ContainerDestination.location, 
Container.staging_row, 
ContainerDestination.tsdf_approval_code,
Container.manifest,
NULL as generator,
Receipt.bulk_flag,
Receipt.receipt_date,
--rb Remove temp table, moved column above to position in result set
--ContainerDestination.tsdf_approval_code,
ContainerDestination.tsdf_approval_code,
ContainerDestination.waste_stream,
Container.trip_id,
Container.manifest_container,
Container.container_size
FROM Receipt
JOIN Container ON Receipt.receipt_id = Container.receipt_id
	AND Receipt.line_id = Container.line_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_id
	AND Receipt.company_id = Container.company_id
JOIN ContainerDestination ON Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.container_type = ContainerDestination.container_type
WHERE 1=1 
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
AND Receipt.receipt_status IN ('U','A')
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'X'
AND Receipt.bulk_flag = 'F'
AND ContainerDestination.status IN ('C', 'N')
AND ContainerDestination.container_type = 'R'
AND ISNULL(ContainerDestination.location_type,'') IN ('O', 'U', '', 'P')
AND ContainerDestination.tracking_num = DBO.fn_container_receipt(@outbound_receipt_id, @outbound_line_id)
-- rb added when temp table removed
-- rb 08/22/2012 Sporadic occasions when query took minutes...restructure comparison to @inbound_receipt_id argument
--AND Receipt.receipt_id = case when ISNULL(@inbound_receipt_id,0) > 0 then @inbound_receipt_id else Receipt.receipt_id end
AND (ISNULL(@inbound_receipt_id,0) = 0 OR ISNULL(Receipt.receipt_id, 0) = @inbound_receipt_id)
--ORDER BY Container

--rbORDER BY ContainerDestination.receipt_id, ContainerDestination.line_id
select include,
container_percent,
company_id,
profit_ctr_id,
receipt_id,
line_id,
container_id,
sequence_id,
container_type,
status,
location,
staging_row,
approval_code,
manifest,
generator,
bulk_flag,
receipt_date,
tsdf_approval_code,
waste_stream,
trip_id,
manifest_container,
container_size
from #result
order by receipt_id, line_id

drop table #result
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_assign_container] TO [EQAI]
    AS [dbo];
GO

