DROP PROCEDURE IF EXISTS sp_cert_disposal_detail
GO

CREATE PROCEDURE sp_cert_disposal_detail 
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

01/06/2005 SCC	Modified for Container Tracking changes
02/08/2006 MK	Captured container weight and passed into sp_container_consolidation_location
02/20/2008 RG   Modified report_type 1 to be more consistent with report type 2
08/16/2010 JDB	Added new DEA Receipt fields for EQ Oklahoma.  Updated joins to new syntax.  
				Changed manifest line from letter to number.
10/12/2011 SK	Modified the query to select all approvals & not just active ones				
08/23/2012 RB   Set transaction isolation level so records will not be locked
06/23/2014 AM   Moved to plt_ai and added company_id
08/04/2015 SK	Added processed_flag to #container_locations 
06/02/2017 AM   GEM-43006 - Added foreign_generator_flag 
01/22/2018 MPM	GEM 47742 - Added @foreign_permit and @consent input parameters.
07/29/2022 MPM	DevOps 39160 - Added @report_type = 3, which returns only uncompleted containers.
06/03/2023 Dipankar #39159 - Added arg_receipt_id argument and added logic to filter records for arg_receipt_id

sp_cert_disposal_detail 0, 21, '10/1/09','10/20/09', 0,999999, '0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 1, 0 
sp_cert_disposal_detail 0, 21, '1/1/2013','06/30/2013', 1,999999, '0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'F',1, 0 
sp_cert_disposal_detail 0,22,'03/01/2006','04/30/2006', 1,99999, '03186','03186', '0','zzzzzzzzzz', 1,9999999, '0','ZZ','A',2, 0 
sp_cert_disposal_detail 0,21,'03/01/2017','03/02/2017', 1,99999, '0','zzzzzz', '0','zzzzzzzzzz', 1,9999999, '0','ZZ','A', 2, null, null, 0 
sp_cert_disposal_detail 0,21,'03/01/2017','03/02/2017', 1,99999, '0','zzzzzz', '0','zzzzzzzzzz', 1,9999999, '0','ZZ','A', 2, 'mpm test', null, 0 
sp_cert_disposal_detail 0,21,'03/01/2017','03/02/2017', 1,99999, '0','zzzzzz', '0','zzzzzzzzzz', 1,9999999, '0','ZZ','A', 2, null, 'mpm test', 0 

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
	@container_weight decimal(10,3)

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
    0 AS processed_flag
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
INNER JOIN Approval ON Receipt.company_id = approval.company_id
	AND Receipt.profit_ctr_id = approval.profit_ctr_id
	AND Receipt.approval_code = approval.approval_code
INNER JOIN Generator ON Receipt.generator_id = generator.generator_id
WHERE 1=1
--AND approval.curr_status_code = 'A'
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
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
AND ((@report_type IN (2,3)) 
	OR (@report_type = 1 AND NOT EXISTS (
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
		AND C2.status = 'N' )))

-- Update the outbound manifest information
UPDATE #container_locations SET 
	manifest_out = Receipt.manifest,
	manifest_line_id_out = Receipt.manifest_line,
	manifest_page_num_out = Receipt.manifest_page_num
FROM Receipt
WHERE #container_locations.tracking_num = (CONVERT(varchar(15), Receipt.receipt_id) + '-' + CONVERT(varchar(15), Receipt.line_id))
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

SET ROWCOUNT 0
IF @report_type = 1
BEGIN
	SELECT DISTINCT 
		ProfitCenter.profit_ctr_name, 
		ProfitCenter.address_1, 
		ProfitCenter.address_2,
		#container_locations.receipt_id, 
		#container_locations.line_id,
		#container_locations.container_id, 
		#container_locations.sequence_id, 
		Receipt.manifest AS manifest_in, 
		Receipt.manifest_line AS manifest_line_id_in, 
		Receipt.manifest_page_num AS manifest_page_num_in,
		#container_locations.container_weight, 
		Receipt.approval_code, 
		#container_locations.location AS destination,
		Treatment.treatment_desc, 
		#container_locations.disposal_date, 
		#container_locations.manifest_out, 
		#container_locations.manifest_line_id_out, 
		#container_locations.manifest_page_num_out,
		Generator.generator_name,
		Receipt.customer_id,
		Treatment.management_code,
		ProfitCenter.phone,
		ProfitCenter.fax,
		#container_locations.location_type,
		Generator.epa_id,
		Receipt.case_number,
		Receipt.control_number,
		Receipt.call_number
	FROM Receipt
	INNER JOIN #container_locations ON #container_locations.company_id = Receipt.company_id
		AND #container_locations.profit_ctr_ID = Receipt.profit_ctr_ID
		AND #container_locations.receipt_id = Receipt.receipt_id
		AND #container_locations.line_id = Receipt.line_id
	INNER JOIN ProfitCenter ON Receipt.profit_ctr_id = ProfitCenter.profit_ctr_ID 
	       AND ProfitCenter.company_ID = Receipt.company_id 
	INNER JOIN Treatment ON Receipt.treatment_id = Treatment.treatment_id 
		AND Receipt.company_id = Treatment.company_id 
		AND Receipt.profit_ctr_id = Treatment.profit_ctr_id 
	INNER JOIN Generator ON Receipt.generator_id = generator.generator_id
	WHERE 1=1
		AND Receipt.profit_ctr_id = @profit_ctr_id
		AND Receipt.company_id = @company_id
		AND #container_locations.location IS NOT NULL
		AND #container_locations.container_status = 'C'
		AND #container_locations.location_type IN ('P', 'O')
        AND NOT EXISTS ( SELECT 1 FROM #container_locations cl 
			WHERE cl.receipt_id = Receipt.receipt_id 
			AND cl.manifest_in = Receipt.manifest
			AND cl.container_status = 'N'
			)
	ORDER BY Receipt.manifest, #container_locations.receipt_id, #container_locations.line_id, 
		#container_locations.container_id, #container_locations.sequence_id
END
ELSE
BEGIN
	IF @report_type = 2
	BEGIN
		SELECT DISTINCT Receipt.customer_id,
			Receipt.manifest AS manifest_in, 
			Receipt.manifest_line AS manifest_line_id_in, 
			Receipt.manifest_page_num AS manifest_page_num_in,
			Receipt.approval_code, 
			generator.generator_name,
			Treatment.treatment_desc, 
			#container_locations.receipt_id, 
			#container_locations.line_id,
			#container_locations.container_id,
			#container_locations.sequence_id, 
			#container_locations.container_status,
			#container_locations.location AS destination,
			#container_locations.disposal_date, 
			#container_locations.manifest_out, 
			#container_locations.manifest_line_id_out, 
			#container_locations.manifest_page_num_out,
			#container_locations.secondary_container,
			#container_locations.secondary_container_id,
			#container_locations.location_type,
			Generator.epa_id,
			#container_locations.include AS processed,
			Receipt.case_number,
			Receipt.control_number,
			Receipt.call_number
		FROM Receipt
		INNER JOIN #container_locations ON #container_locations.company_id = Receipt.company_id
			AND #container_locations.profit_ctr_ID = Receipt.profit_ctr_ID
			AND #container_locations.receipt_id = Receipt.receipt_id
			AND #container_locations.line_id = Receipt.line_id
		INNER JOIN ProfitCenter ON Receipt.profit_ctr_id = ProfitCenter.profit_ctr_ID 
					AND Receipt.company_id = ProfitCenter.company_id
		INNER JOIN Treatment ON Receipt.treatment_id = Treatment.treatment_id 
			AND Receipt.company_id = Treatment.company_id 
			AND Receipt.profit_ctr_id = Treatment.profit_ctr_id 
		INNER JOIN Generator ON Receipt.generator_id = generator.generator_id
		WHERE 1=1
			AND Receipt.profit_ctr_id = @profit_ctr_id
			AND Receipt.company_id = @company_id
			AND #container_locations.location IS NOT NULL
			AND #container_locations.location_type IN ('P','O','U')
		ORDER BY Receipt.manifest, #container_locations.receipt_id, #container_locations.line_id, 
			#container_locations.container_id, #container_locations.sequence_id	 
	END

	-- MPM - 8/1/2022 - DevOps 39160 - Added report type 3, which returns only unprocessed containers
	ELSE
	IF @report_type = 3
	BEGIN
		SELECT DISTINCT Receipt.customer_id,
			Receipt.manifest AS manifest_in, 
			Receipt.manifest_line AS manifest_line_id_in, 
			Receipt.manifest_page_num AS manifest_page_num_in,
			Receipt.approval_code, 
			generator.generator_name,
			Treatment.treatment_desc, 
			#container_locations.receipt_id, 
			#container_locations.line_id,
			#container_locations.container_id,
			#container_locations.sequence_id, 
			#container_locations.container_status,
			#container_locations.location AS destination,
			#container_locations.disposal_date, 
			#container_locations.manifest_out, 
			#container_locations.manifest_line_id_out, 
			#container_locations.manifest_page_num_out,
			#container_locations.secondary_container,
			#container_locations.secondary_container_id,
			#container_locations.location_type,
			Generator.epa_id,
			#container_locations.include AS processed,
			Receipt.case_number,
			Receipt.control_number,
			Receipt.call_number
		FROM Receipt
		INNER JOIN #container_locations ON #container_locations.company_id = Receipt.company_id
			AND #container_locations.profit_ctr_ID = Receipt.profit_ctr_ID
			AND #container_locations.receipt_id = Receipt.receipt_id
			AND #container_locations.line_id = Receipt.line_id
		INNER JOIN ProfitCenter ON Receipt.profit_ctr_id = ProfitCenter.profit_ctr_ID 
					AND Receipt.company_id = ProfitCenter.company_id
		INNER JOIN Treatment ON Receipt.treatment_id = Treatment.treatment_id 
			AND Receipt.company_id = Treatment.company_id 
			AND Receipt.profit_ctr_id = Treatment.profit_ctr_id 
		INNER JOIN Generator ON Receipt.generator_id = generator.generator_id
		WHERE 1=1
			AND Receipt.profit_ctr_id = @profit_ctr_id
			AND Receipt.company_id = @company_id
			AND #container_locations.location IS NOT NULL
			AND #container_locations.location_type IN ('P','O','U')
			AND ISNULL(#container_locations.container_status, '') <> 'C'
		ORDER BY Receipt.manifest, #container_locations.receipt_id, #container_locations.line_id, 
			#container_locations.container_id, #container_locations.sequence_id	 
	END
END
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cert_disposal_detail] TO [EQAI]
    AS [dbo];

