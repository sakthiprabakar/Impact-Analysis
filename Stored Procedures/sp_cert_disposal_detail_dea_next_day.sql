DROP PROC IF EXISTS sp_cert_disposal_detail_dea_next_day
GO
CREATE PROCEDURE [dbo].[sp_cert_disposal_detail_dea_next_day] 
	@company_id			int,
	@profit_ctr_id		int,
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
	@foreign_permit		varchar(40),
	@consent			varchar(40), 
	@debug				int,
	@receipt_id			int
AS
/***************************************************************
This procedure returns a list of containers by manifest where 
all of the containers for the manifest are complete or void.
HISTORY
----------
DevOps 42148 GDE;  07/28/2022; Inbound Receipt Printing - Container Logs
06/03/2023 Dipankar #39159 - Added arg_receipt_id argument and added logic to filter records for receipt_id
08/28/2023 AM DevOPs:39205 - Added #39159 changes.
12/04/2023 Kamendra DevOps #74643 - Added call to execute sp_container_consolidation_location to pull secondary container information.
10/09/2024	Sailaja Rally # DE35384 Included cycle in select for #tmp_base
				Update statement to include manifest_out for location type 'P' 

sp_cert_disposal_detail_dea_next_day 22, 0, '8/1/10','8/3/10', 0,999999, '0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ',0
sp_cert_disposal_detail_dea_next_day 22,0, '03/01/2006','04/30/2006', 1,99999, '03186','03186', '0','zzzzzzzzzz', 1,9999999, '0','ZZ','F', 0 
sp_cert_disposal_detail_dea_next_day 21, 0, '3/1/2017','3/2/2017', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A', null, null, 0 
sp_cert_disposal_detail_dea_next_day 21, 0, '3/1/2017','3/2/2017', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A', 'mpm test', null, 0 
sp_cert_disposal_detail_dea_next_day 21, 0, '3/1/2017','3/2/2017', 0,99999,'0','zzzzzz', '0','zzzzzz', 0,99999, '0','ZZ', 'A', null, 'mpm test', 0 

****************************************************************/
DECLARE	@line_id int,
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

SET NOCOUNT ON

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
	 ContainerDestination.cycle AS cycle --Rally # DE35384
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
INNER JOIN Profile ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
INNER JOIN Generator ON Receipt.generator_id = Generator.generator_id
	AND Generator.epa_id BETWEEN @epa_id_from AND @epa_id_to
INNER JOIN Customer ON Customer.customer_id = Receipt.customer_id
INNER JOIN ContainerDisposalStatus ON Receipt.receipt_id = ContainerDisposalStatus.receipt_id
	AND Container.line_id = ContainerDisposalStatus.line_id
	AND Container.container_id = ContainerDisposalStatus.container_id
	AND Receipt.company_id = ContainerDisposalStatus.company_id
	AND Receipt.profit_ctr_id = ContainerDisposalStatus.profit_ctr_id
WHERE 1=1
AND Receipt.trans_mode = 'I'
AND Receipt.trans_type = 'D'
AND Receipt.company_id = @company_id
AND Receipt.profit_ctr_id = @profit_ctr_id
AND Receipt.receipt_date BETWEEN @date_from AND @date_to
AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
AND Receipt.manifest BETWEEN @manifest_from AND @manifest_to
AND Receipt.approval_code BETWEEN @approval_from AND @approval_to
AND Generator.generator_id BETWEEN @generator_from AND @generator_to
AND ( ( IsNull ( Generator.foreign_generator_flag, 'F' ) = @foreign_generator_flag )OR ('A' = @foreign_generator_flag) )
AND (IsNull(@foreign_permit, '') = '' OR Receipt.foreign_permit = @foreign_permit)
AND (ISNULL(@consent, '') = '' OR Receipt.consent = @consent)
AND (IsNull(@receipt_id, 0) = 0 OR Receipt.receipt_id = @receipt_id) -- Added for #39159
AND NOT EXISTS (
		SELECT C2.line_id 
		FROM Container C2, Receipt R2
		WHERE R2.receipt_id = Receipt.receipt_id
		AND R2.profit_ctr_id = Receipt.profit_ctr_id
		AND R2.company_id = Receipt.company_id
		AND R2.manifest = Receipt.manifest
		AND R2.receipt_id = C2.receipt_id
		AND R2.profit_ctr_id = C2.profit_ctr_id
		AND R2.company_id = C2.company_id
		AND C2.container_type = 'R'
		AND C2.status = 'N' )

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
AND Receipt.company_id = @company_id
AND Receipt.profit_ctr_id = @profit_ctr_id 

--Sailaja Rally # DE35384 - Updating manifest_out for location type as P based on tracking_num of receipt table
UPDATE #container_locations SET 
	manifest_out = Receipt.manifest,
	manifest_line_id_out = Receipt.manifest_line,
	manifest_page_num_out = Receipt.manifest_page_num
FROM Receipt
WHERE #container_locations.tracking_num = Receipt.tracking_num
AND #container_locations.location_type = 'P'
AND #container_locations.location = Receipt.location
AND #container_locations.profit_ctr_id = Receipt.profit_ctr_id
AND #container_locations.company_id = Receipt.company_id
AND Isnull(#container_locations.cycle,0) = IsNull(Receipt.cycle, 0)
AND Receipt.trans_type = 'D'
AND Receipt.trans_mode = 'O'



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
SET NOCOUNT OFF

SELECT DISTINCT 
	ProfitCenter.profit_ctr_name, 
	ProfitCenter.address_1, 
	ProfitCenter.address_2,
	ProfitCenter.EPA_ID AS profitcenter_epa_id,
	#container_locations.receipt_id, 
	#container_locations.line_id,
	#container_locations.container_id, 
	#container_locations.sequence_id, 
	Receipt.receipt_date,
	Receipt.manifest AS manifest_in, 
	Receipt.manifest_line AS manifest_line_id_in, 
	Receipt.manifest_page_num AS manifest_page_num_in,
	#container_locations.container_weight, 
	Receipt.approval_code, 
	Profile.approval_desc,
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
	Receipt.call_number,
	Customer.cust_name,
	Contact.name AS contact_name,
	Contact.phone AS contact_phone,
	Generator.gen_mail_addr1,
	Generator.gen_mail_addr2,
	Generator.gen_mail_addr3,
	Generator.gen_mail_addr4,
	Generator.gen_mail_city,
	Generator.gen_mail_state,
	Generator.gen_mail_zip_code,
	Generator.generator_address_1,
	Generator.generator_address_2,
	Generator.generator_address_3,
	Generator.generator_address_4,
	Generator.generator_city,
	Generator.generator_state,
	Generator.generator_zip_code
FROM Receipt
INNER JOIN #container_locations ON #container_locations.company_id = Receipt.company_id
	AND #container_locations.profit_ctr_ID = Receipt.profit_ctr_ID
	AND #container_locations.receipt_id = Receipt.receipt_id
	AND #container_locations.line_id = Receipt.line_id
INNER JOIN ProfitCenter ON Receipt.profit_ctr_id = ProfitCenter.profit_ctr_ID 
      AND Receipt.company_id = ProfitCenter.company_ID 
INNER JOIN Treatment ON Receipt.treatment_id = Treatment.treatment_id 
	AND Receipt.company_id = Treatment.company_id 
	AND Receipt.profit_ctr_id = Treatment.profit_ctr_id 
INNER JOIN Customer ON Receipt.customer_id = Customer.customer_id   
INNER JOIN Generator ON Receipt.generator_id = generator.generator_id
INNER JOIN Profile ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
LEFT OUTER JOIN ContactXRef ON ContactXRef.customer_id = Customer.customer_id
	AND ContactXRef.type = 'C'
	AND ContactXRef.primary_contact = 'T'
LEFT OUTER JOIN Contact ON Contact.contact_id = ContactXRef.contact_id
WHERE 1=1
	AND Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
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
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cert_disposal_detail_dea_next_day] TO [EQAI]