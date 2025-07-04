﻿CREATE PROCEDURE sp_cert_disposition 
	@profit_ctr_id		int,
	@company_id          int,
	@date_from			datetime, 
	@date_to			datetime, 
	@customer_id_from	int, 
	@customer_id_to		int,
	@manifest_from		varchar(15), 
	@manifest_to		varchar(15), 
	@approval_from		varchar(15), 
	@approval_to		varchar(15),
	@generator_from		int, 
	@generator_to		int,
	@epa_id_from		varchar(12), 
	@epa_id_to			varchar(12),
	@foreign_generator_flag varchar(1),
	@report_type		int,
	@foreign_permit		varchar(40),
	@consent			varchar(40), 
	@debug				int,
	@arg_receipt_id		int
AS
/***************************************************************
This procedure returns a list of containers by manifest where 
all of the containers for the manifest are complete or void.

07/27/2015	SK	Created This is the new certificate of disposition sp requested as per GEM:32250
10/14/2015	SK	Fixed the SQL error for "invalid length to substring function". When the CharIndex fn 
				call inside of substring returns 0 and if Substring position ends at -1 relative to that
				then 0-1 = -1 leads to an SQL err of invalid length in the substring position. 
				In order to get over this, the charindex was modified to run so that in case where it returns 0, 
				it would return the last character position+1, so would return a valid length for the substring.
06/02/2017 AM   GEM-43006 - Added foreign_generator_flag 
01/22/2018 MPM	GEM 47742 - Added @foreign_permit and @consent input parameters.
06/26/2019 AM   Task:10981 - Added state_regulatory_id, authorized_COD_representative_name and authorized_COD_representative_title
06/03/2023 Dipankar #39159 - Added arg_receipt_id argument and added logic to filter records for arg_receipt_id
10/24/2023 Prakash Rally DE36053 - Included the CASE to find IsNumeric of tracking_num where we are setting the Receipt.receipt_id.

sp_cert_disposition 0, 21, '10/1/09','10/20/09', 0,999999, '0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 1, 0 
sp_cert_disposition 0, 21, '1/1/2016','1/10/2016', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A',1, 0 
sp_cert_disposition 0, 21, '3/1/2017','3/2/2017', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A',1, null, null, 0 
sp_cert_disposition 0, 21, '3/1/2017','3/2/2017', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A',1, 'mpm test', null, 0 
sp_cert_disposition 0, 21, '3/1/2017','3/2/2017', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A',1, null, 'mpm test', 0 
sp_cert_disposition 0, 21, '6/25/2018','6/26/2018', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A',1, null, null, 1

****************************************************************/
DECLARE	@receipt_id int,
	@line_id int,
	@container_id int,
	@sequence_id int,
	@consolidation_count int,
	@container varchar(15),
	@base_container varchar(15),
	@base_container_id int,
	@curr_manifest varchar(15),
	@container_weight decimal(10,3),
	@Disposal_date			datetime,
	@Disposal_dates_list	varchar(2000),
	@pcb_concentration_0_49	char(1),
	@pcb_concentration_50_499	char(1),
	@pcb_concentration_500	char(1),
	@pcb_source_concentration_gr_50	char(1)
	
--SK 
CREATE TABLE #results (
	company_id				int
,	profit_ctr_id			int
,	receipt_id				int
,	line_id					int
,	manifest_in				varchar(15)
,	manifest_page_num_in	int
,	manifest_line_id_in		int
,	disposal_dates			varchar(2000)
,	approval_code			varchar(15)
,	treatment_id			int
,	generator_id			int
,	customer_id				int
,	processed_flag			tinyint
,	print_stmt				tinyint		-- 1= tsca stmt, 2=recycle stmt, 3=disposal stmt
,	manifest_flag			char(1)
,	receipt_date			datetime
,	disposal_date			datetime
)

-- rb 08/23/2012
set transaction isolation level read uncommitted

-- These are the containers for the given criteria
SELECT  CONVERT(varchar(15), Receipt.receipt_id) + '-' + CONVERT(varchar(15), Receipt.line_id) AS container,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.receipt_id,
	Receipt.line_id,
	ContainerDestination.container_id,
	ContainerDestination.sequence_id,
	Receipt.manifest AS manifest_in,
	ISNULL(ContainerDestination.location_type,'U') AS location_type,
	ISNULL(ContainerDestination.location,'') AS location,
	ISNULL(ContainerDestination.tracking_num,'') AS tracking_num,
	ISNULL(ContainerDestination.base_tracking_num,'') AS base_tracking_num,
	ISNULL(ContainerDestination.base_container_id,0) AS base_container_id,
	ContainerDestination.treatment_id,
	ContainerDestination.disposal_date,
	Container.container_weight,
	CONVERT(varchar(15),'') AS manifest_out,
	CONVERT(int,NULL) AS manifest_line_id_out,
	CONVERT(int,NULL) AS manifest_page_num_out,
	CONVERT(varchar(15),'') AS secondary_container,
	CONVERT(int,NULL) AS secondary_container_id,
	CONVERT(int,NULL) AS secondary_sequence_id,
	Container.status AS container_status,
	ContainerDestination.status AS dest_status,
    1 AS include,
    0 AS processed_flag,
    ContainerDestination.disposal_date as disposal_date_date
INTO #container_locations
FROM Receipt
INNER JOIN Container ON Receipt.company_id = Container.company_id
	AND Receipt.profit_ctr_id = Container.profit_ctr_ID
	AND Receipt.receipt_id = Container.receipt_id 
	AND Receipt.line_id = Container.line_id
INNER JOIN ContainerDestination ON Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_ID
	AND Container.receipt_id = ContainerDestination.receipt_id 
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
INNER JOIN Customer ON Receipt.customer_id = Customer.customer_id 
INNER JOIN ProfileQuoteApproval PQA
	ON PQA.company_id = Receipt.company_id
	AND PQA.profit_ctr_id = Receipt.profit_ctr_id
	AND PQA.approval_code = Receipt.approval_code
--INNER JOIN Approval ON Receipt.company_id = approval.company_id
--	AND Receipt.profit_ctr_id = approval.profit_ctr_id
--	AND Receipt.approval_code = approval.approval_code
INNER JOIN Generator ON Receipt.generator_id = generator.generator_id
WHERE 1=1
--AND approval.curr_status_code = 'A'
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id
AND Receipt.receipt_date between @date_from and @date_to
AND Receipt.customer_id between @customer_id_from and @customer_id_to
AND Receipt.manifest between @manifest_from and @manifest_to
AND Receipt.approval_code between @approval_from and @approval_to
AND Generator.generator_id between @generator_from and @generator_to
AND Generator.epa_id between @epa_id_from and @epa_id_to
AND ( ( IsNull ( Generator.foreign_generator_flag, 'F' ) = @foreign_generator_flag )OR ('A' = @foreign_generator_flag) )
AND (IsNull(@foreign_permit, '') = '' OR Receipt.foreign_permit = @foreign_permit)
AND (ISNULL(@consent, '') = '' OR Receipt.consent = @consent)
AND (IsNull(@arg_receipt_id, 0) = 0 OR Receipt.receipt_id = @arg_receipt_id) -- Added for #39159
AND NOT EXISTS (
		SELECT C2.line_id 
		FROM Container C2, Receipt R2
		WHERE R2.receipt_id = Receipt.receipt_id
		AND R2.profit_ctr_id = Receipt.profit_ctr_id
		AND R2.company_id  = Receipt.company_id 
		AND R2.manifest = Receipt.manifest
		AND R2.receipt_id = C2.receipt_id
		AND R2.profit_ctr_id = C2.profit_ctr_id
		AND R2.company_id  = C2.company_id 
		AND C2.container_type = 'R'
		AND C2.status = 'N' )
		
-- Update the outbound manifest information
UPDATE #container_locations SET 
	manifest_out = Receipt.manifest,
	manifest_line_id_out = Receipt.manifest_line,
	manifest_page_num_out = Receipt.manifest_page_num
FROM Receipt
WHERE Receipt.receipt_id = CASE 
						   WHEN ISNUMERIC(SUBSTRING(#container_locations.tracking_num, 1, (CHARINDEX('-', #container_locations.tracking_num + '-', 1)) - 1)) = 1
						   THEN CONVERT(INT, SUBSTRING(#container_locations.tracking_num, 1, (CHARINDEX('-', #container_locations.tracking_num + '-', 1)) - 1)) ELSE NULL
						   END
AND Receipt.line_id = CONVERT(INT, SUBSTRING(#container_locations.tracking_num, (CHARINDEX('-', #container_locations.tracking_num, 1)) + 1, LEN(#container_locations.tracking_num) - (CHARINDEX('-', #container_locations.tracking_num, 1))))
--#container_locations.tracking_num = (CONVERT(varchar(15), Receipt.receipt_id) + '-' + CONVERT(varchar(15), Receipt.line_id))
AND #container_locations.location_type = 'O'
AND Receipt.trans_mode = 'O'
AND Receipt.trans_type = 'D'
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.company_id = @company_id

IF @debug = 1 PRINT 'selecting from #container_locations'
IF @debug = 1 SELECT * FROM #container_locations

-- Get the locations for the consolidated containers
SELECT *, 0 AS process_flag INTO #consolidation_list FROM #container_locations WHERE location_type = 'C'
SELECT @consolidation_count = @@ROWCOUNT

WHILE @consolidation_count > 0
BEGIN
  -- Get a container
  SET ROWCOUNT 1
  SELECT @container = container, 
	@receipt_id = receipt_id, 
	@line_id = line_id,
	@container_id = container_id,
	@sequence_id = sequence_id,
	@curr_manifest = manifest_in,
	@base_container = base_tracking_num,
	@base_container_id = base_container_id,
	@container_weight = container_weight
  FROM #consolidation_list where process_flag = 0
  SET ROWCOUNT 0
  if @debug = 1 print 'Working on container: ' + @container + ' container_id: ' + convert(varchar(10),@container_id) +' sequence_id: ' + convert(varchar(10),@sequence_id)


	-- Get all the final destinations for this consolidated container
	EXEC sp_container_consolidation_location @receipt_id, @line_id, @container_id, @sequence_id, @curr_manifest,
		@base_container, @base_container_id, @profit_ctr_id, @company_id, @container_weight, @debug

	-- When this stored procedure completes, all locations for this consolidated container have been
	-- drilled down to and recorded in the #container_locations table
  SET ROWCOUNT 1
  UPDATE #consolidation_list SET process_flag = 1 WHERE process_flag = 0
  SET @consolidation_count = @consolidation_count - 1
  SET ROWCOUNT 0
END

-- now determine the container has been fully processed rg022008 
UPDATE #container_locations SET include = 0 WHERE container_status = 'N'

-- SK Disposal date
UPDATE #container_locations SET processed_flag = 0

SET ROWCOUNT 0
INSERT INTO #Results
SELECT DISTINCT 
	r.company_id,
	r.profit_ctr_id,
	r.receipt_id,
	r.line_id,
	r.manifest AS manifest_in, 
	r.manifest_page_num AS manifest_page_num_in,
	r.manifest_line AS manifest_line_id_in, 
	#container_locations.disposal_date as disposal_dates,
	r.approval_code, 
	r.treatment_id,
	r.generator_id,
	r.customer_id,
	0 as processed_flag,
	0 AS print_stmt,
	r.manifest_flag,
	r.receipt_date,
	#container_locations.disposal_date_date as disposal_date
FROM Receipt r
INNER JOIN #container_locations ON #container_locations.company_id = r.company_id
	AND #container_locations.profit_ctr_ID = r.profit_ctr_ID
	AND #container_locations.receipt_id = r.receipt_id
	AND #container_locations.line_id = r.line_id
WHERE 1=1
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.company_id = @company_id
	AND #container_locations.location IS NOT NULL
	AND #container_locations.container_status = 'C'
	AND #container_locations.location_type IN ('P', 'O')
    AND NOT EXISTS ( SELECT 1 FROM #container_locations cl 
		WHERE cl.receipt_id = r.receipt_id 
		AND cl.manifest_in = r.manifest
		AND cl.container_status = 'N'
		)	

-- Fetch the distinct list of disposal dates
SELECT @consolidation_count = @@ROWCOUNT

WHILE @consolidation_count > 0
BEGIN
  -- Get a receipt-line
  SET ROWCOUNT 1
  SELECT  
	@receipt_id = receipt_id, 
	@line_id = line_id
	FROM #Results where processed_flag = 0
	
	SELECT @Disposal_date = disposal_date from 
	#container_locations  
	WHERE #container_locations.receipt_id = @receipt_id 
	AND #container_locations.line_id = @line_id
	AND #container_locations.profit_ctr_id = @profit_ctr_id
	AND #container_locations.company_id = @company_id
	AND #container_locations.processed_flag = 0
	
	WHILE @Disposal_date IS NOT NULL
	BEGIN
		IF @Disposal_dates_list IS NULL
		BEGIN	
			SET @Disposal_dates_list = Convert(varchar(10), @Disposal_date, 101)
		END
		ELSE
		BEGIN
			IF CHARINDEX(Convert(varchar(10), @Disposal_date, 101), @Disposal_dates_list, 0) = 0
				SET @Disposal_dates_list = @Disposal_dates_list +'  ' + Convert(varchar(10), @Disposal_date, 101)
		END
		 		
		UPDATE #container_locations SET processed_flag = 1 
		WHERE #container_locations.receipt_id = @receipt_id 
		AND #container_locations.line_id = @line_id
		AND #container_locations.profit_ctr_id = @profit_ctr_id
		AND #container_locations.company_id = @company_id
		AND #container_locations.processed_flag = 0 
		AND #container_locations.disposal_date = @Disposal_date
		
		SET @Disposal_date = NULL
		
		SELECT @Disposal_date = disposal_date from 
		#container_locations  
		WHERE #container_locations.receipt_id = @receipt_id 
		AND #container_locations.line_id = @line_id
		AND #container_locations.profit_ctr_id = @profit_ctr_id
		AND #container_locations.company_id = @company_id
		AND #container_locations.processed_flag = 0
	END
		
	UPDATE #Results SET disposal_dates = @Disposal_dates_list, processed_flag = 1 WHERE
	company_id = @company_id and profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id and line_id = @line_id
	
	SET @Disposal_dates_list = NULL
	SET @consolidation_count = @consolidation_count - 1
	SET ROWCOUNT 0
END

-- Decide Which statement to print per manifest line
-- TSCA
UPDATE #Results SET print_stmt = 1
FROM #Results R
JOIN ProfileQuoteApproval PQA
	ON PQA.company_id = R.company_id
	AND PQA.profit_ctr_id = R.profit_ctr_id
	AND PQA.approval_code = R.approval_code
JOIN Profile P
	ON P.profile_id = PQA.profile_id
JOIN ProfileLab PL
	ON PL.profile_id = P.profile_id
	AND PL.type = 'A'
	AND ((PL.pcb_concentration_50_499 = 'T' OR PL.pcb_concentration_500 = 'T') OR
		 (PL.pcb_concentration_0_49 = 'T' AND PL.pcb_source_concentration_gr_50 = 'T'))
WHERE R.print_stmt = 0
		 
-- Recycling
UPDATE #Results SET print_stmt = 2
FROM #Results R
JOIN Treatment T
	ON T.treatment_id = R.treatment_id
	AND T.company_id = R.company_id
	AND T.profit_ctr_id = R.profit_ctr_id
JOIN TreatmentProcess TP
	ON TP.treatment_process_id = T.treatment_process_id
WHERE R.print_stmt = 0
AND TP.treatment_process like '%recycl%' 

UPDATE #Results SET print_stmt = 2
FROM #Results R
JOIN Treatment T
	ON T.treatment_id = R.treatment_id
	AND T.company_id = R.company_id
	AND T.profit_ctr_id = R.profit_ctr_id
JOIN DisposalService DS
	ON DS.disposal_service_id = T.disposal_service_id
WHERE R.print_stmt = 0
AND DS.disposal_service_desc like '%recycl%'

-- All remaining rows get Disposal stmt
UPDATE #Results SET print_stmt = 3
FROM #Results R
WHERE R.print_stmt = 0

-- Select the resultset
SELECT DISTINCT 
	r.company_id,
	r.profit_ctr_id,
	ProfitCenter.profit_ctr_name, 
	ProfitCenter.address_1, 
	ProfitCenter.address_2,
	r.receipt_id,
	r.customer_id,
	r.manifest_in, 
	r.manifest_page_num_in,
	r.manifest_line_id_in, 
	r.disposal_dates,
	r.approval_code, 
	r.treatment_id,
	Treatment.treatment_desc, 
	Treatment.management_code,
	r.generator_id,
	Generator.epa_id,
	Generator.generator_name,
	Generator.generator_address_1,
	Generator.generator_city,
	Generator.generator_state,
	Generator.generator_zip_code,
	Generator.generator_phone,
	Company.phone_customer_service,
	r.print_stmt,
	r.manifest_flag,
	ProfitCenter.EPA_ID AS TSDF_EPA_ID,
	TSDF.state_regulatory_id,
	ProfitCenter.authorized_COD_representative_name,
	ProfitCenter.authorized_COD_representative_title,
	r.receipt_date,
	r.disposal_date
FROM #Results r
INNER JOIN ProfitCenter ON r.profit_ctr_id = ProfitCenter.profit_ctr_ID 
       AND ProfitCenter.company_ID = r.company_id 
INNER JOIN Treatment ON r.treatment_id = Treatment.treatment_id 
	AND r.company_id = Treatment.company_id 
	AND r.profit_ctr_id = Treatment.profit_ctr_id 
INNER JOIN Generator ON r.generator_id = generator.generator_id
LEFT OUTER JOIN TSDF ON ProfitCenter.company_id = TSDF.eq_company 
    AND ProfitCenter.profit_ctr_id = TSDF.eq_profit_ctr
    AND TSDF.eq_flag = 'T' AND TSDF.TSDF_status = 'A'
LEFT JOIN Company
	ON Company.company_id = 1
WHERE 1=1
ORDER BY r.manifest_in, r.receipt_id, r.manifest_page_num_in, r.manifest_line_id_in
--, #container_locations.receipt_id, #container_locations.line_id, 
	--#container_locations.container_id, #container_locations.sequence_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cert_disposition] TO [EQAI]
    AS [dbo];
GO

