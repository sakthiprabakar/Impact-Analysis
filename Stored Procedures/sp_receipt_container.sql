
/***************************************************************************************
Returns summarized containers for assigning information from the receipt screen
Requires: none

05/06/07 SCC	created
05/15/07 SCC	Added column to receive the manifest line weight
05/16/07 SCC	Removed join to ReceiptPrice to get the default bill unit because there is no
	direct relationship between the container and the bill unit.  When the bill_unit_code
	is populated in the receipt, a default bill unit and weight will be retrieved; otherwise
	it won't.
06/11/13 RB	Included container percentage and total # of receipt containers in the result set
11/10/13 RB	Added min/max container_ids associated with each group of containers
06/13/2014 AM - Moving to plt_ai from plt_xx_ai and added company id as a parameter 

Loads on PLT_AI_XX

sp_receipt_container 1, 0, 52272
****************************************************************************************/

CREATE PROCEDURE sp_receipt_container
	@debug		int, 
	@profit_ctr_id	int,
	@company_id	int,
	@receipt_id	int
AS

DECLARE
	@group_count	 	int,
	@count_containers	int,
	@line_id		int,
	@staging_row		varchar(5), 
	@manifest_container	varchar(15), 
	@container_size		varchar(15), 
	@container_weight	decimal(10,3), 
	@description		varchar(30), 
	@base_tracking_num	varchar(15),
	@base_container_id	int,
	@base_sequence_id	int,
	@container_count	int,
	@container_id		int,
	@container_id_list	varchar(255),
	@location_type		char(1),
	@location 		varchar(15),
	@tracking_num		varchar(15),
	@tsdf_approval_code	varchar(50),
	@waste_stream		varchar(10),
@min_container_id int,
@max_container_id int

-- Get the containers
CREATE TABLE #container (
	company_id		int NULL,
	profit_ctr_id		int NULL,
	receipt_id		int NULL, 
	line_id			int NULL, 
	container_id		int NULL, 
	price_id		int NULL, 
	status			char(1) NULL,
	staging_row		varchar(5) NULL, 
	manifest_container	varchar(15) NULL, 
	container_size		varchar(15) NULL, 
	container_weight	decimal(10,3) NULL, 
	description		varchar(30) NULL, 
	sequence_id		int NULL,
	location_type		char(1) NULL,
	location		varchar(15) NULL,
	tracking_num		varchar(15) NULL,
	tsdf_approval_code	varchar(40) NULL,
	waste_stream		varchar(10) NULL,
	base_tracking_num	varchar(15) NULL,
	base_container_id	int NULL,
	base_sequence_id	int NULL,
	container_percent	int NULL,
	default_manifest_container	varchar(15) NULL, 
	default_container_size		varchar(15) NULL, 
	default_container_weight	decimal(10,3) NULL, 
	default_description		varchar(50) NULL, 
	container_count		int NULL,
	container_id_list	varchar(255) NULL,
	process_flag 		int NULL,
	treatment_id		int NULL,
	receipt_container_count int NULL,
min_container_id int NULL,
max_container_id int NULL
)

INSERT #container
SELECT DISTINCT 
	Container.company_id,
	Container.profit_ctr_id,
	Container.receipt_id, 
	Container.line_id, 
	Container.container_id, 
	Container.price_id, 
	ContainerDestination.status,
	IsNull(Container.staging_row,''), 
	IsNull(Container.manifest_container,''),
	IsNull(Container.container_size,''),
	IsNull(Container.container_weight,0),
	IsNull(Container.description,''),
	IsNull(ContainerDestination.sequence_id,1),
	IsNull(ContainerDestination.location_type,'U'),
	IsNull(ContainerDestination.location,''),
	IsNull(ContainerDestination.tracking_num,''),
	IsNull(ContainerDestination.tsdf_approval_code,''),
	IsNull(ContainerDestination.waste_stream,''),
	IsNull(ContainerDestination.base_tracking_num,''),
	IsNull(ContainerDestination.base_container_id,0),
	IsNull(ContainerDestination.base_sequence_id,0),
	IsNull(ContainerDestination.container_percent,0),
	IsNull(Receipt.manifest_container_code,'') AS default_manifest_container, 
	IsNull(Receipt.bill_unit_code, '') AS default_container_size,
	IsNull(BillUnit.pound_conv, 0) AS default_container_weight,
	IsNull(Profile.approval_desc,'') AS default_description, 
	container_count = dbo.fn_container_count(Container.receipt_id, Container.line_id, 'R', Container.profit_ctr_id, Container.company_id),
	'' as container_id_list,
	0 as process_flag,
	ContainerDestination.treatment_id as treatment_id,
	ISNULL(Receipt.container_count,0) as receipt_container_count,
0 as min_container_id,
0 as max_container_id
FROM Container
JOIN ContainerDestination
	ON Container.profit_ctr_id = ContainerDestination.profit_ctr_id
     AND Container.company_id = ContainerDestination.company_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND Container.container_type = ContainerDestination.container_type
JOIN Receipt
	ON Container.profit_ctr_id = Receipt.profit_ctr_id
   AND Container.company_id = Receipt.company_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id
JOIN Profile
	ON Receipt.profile_id = Profile.profile_id
LEFT OUTER JOIN BillUnit
	ON IsNull(CASE WHEN IsNull(Container.container_size,'') <> '' THEN Container.container_size ELSE Receipt.bill_unit_code END, '')= BillUnit.bill_unit_code
WHERE Container.container_type = 'R'
	AND Container.profit_ctr_id = @profit_ctr_id
	AND Container.company_id = @company_id
	AND Container.receipt_id = @receipt_id   
ORDER BY 
	Container.company_id,
	Container.profit_ctr_id,
	Container.receipt_id, 
	Container.line_id, 
	Container.container_id, 
	Container.price_id, 
	IsNull(Container.staging_row,''), 
	IsNull(Container.manifest_container,''),
	IsNull(Container.container_size,''),
	IsNull(Container.container_weight,0),
	IsNull(Container.description,''),
	IsNull(ContainerDestination.sequence_id,1),
	IsNull(ContainerDestination.location_type,'U'),
	IsNull(ContainerDestination.location,''),
	IsNull(ContainerDestination.tracking_num,''),
	IsNull(ContainerDestination.tsdf_approval_code,''),
	IsNull(ContainerDestination.waste_stream,''),
	IsNull(ContainerDestination.base_tracking_num,''),
	IsNull(ContainerDestination.base_container_id,0),
	IsNull(ContainerDestination.base_sequence_id,0),
	IsNull(ContainerDestination.container_percent,0)
SELECT @count_containers = @@rowcount

IF @debug = 1 print 'selecting from #container'
IF @debug = 1 select * from #container

WHILE @count_containers > 0
BEGIN
	SET @container_id_list = ''
	SET ROWCOUNT 1
	SELECT @line_id = line_id, 
		@staging_row = staging_row, 
		@manifest_container = manifest_container, 
		@container_size = container_size, 
		@container_weight = container_weight, 
		@description = description, 
		@location_type = location_type,
		@location = location,
		@tracking_num = tracking_num,
		@tsdf_approval_code = tsdf_approval_code,
		@waste_stream = waste_stream,
		@base_tracking_num = base_tracking_num,
		@base_container_id = base_container_id,
		@base_sequence_id = base_sequence_id,
		@container_count = container_count
	FROM #container 
	WHERE process_flag = 0
	SET ROWCOUNT 0

	IF @debug = 1 print '@line_id = ' + str(@line_id)
	IF @debug = 1 print '@staging_row = ' + @staging_row 
	IF @debug = 1 print '@manifest_container = ' + @manifest_container 
	IF @debug = 1 print '@container_size = ' + @container_size 
	IF @debug = 1 print '@container_weight = ' + str(@container_weight) 
	IF @debug = 1 print '@description = ' + @description 
	IF @debug = 1 print '@base_tracking_num = ' + @base_tracking_num
	IF @debug = 1 print '@base_container_id = ' + str(@base_container_id)
	IF @debug = 1 print '@base_sequence_id = ' + str(@base_sequence_id)
	IF @debug = 1 print '@container_count = ' + str(@container_count)
	IF @debug = 1 print '@location_type = ' + @location_type
	IF @debug = 1 print '@location = ' + @location
	IF @debug = 1 print '@tracking_num = ' + @tracking_num
	IF @debug = 1 print '@tsdf_approval_code = ' + @tsdf_approval_code
	IF @debug = 1 print '@waste_stream = ' + @waste_stream

	-- Show the lines that belong to this group
	UPDATE #container SET process_flag = 1 
	WHERE line_id = @line_id
		AND staging_row = @staging_row
		AND manifest_container = @manifest_container 
		AND container_size = @container_size 
		AND container_weight = @container_weight 
		AND description = @description 
		AND location_type = @location_type
		AND location = @location
		AND tracking_num = @tracking_num
		AND tsdf_approval_code = @tsdf_approval_code
		AND waste_stream = @waste_stream
		AND base_tracking_num = @base_tracking_num
		AND base_container_id = @base_container_id
		AND base_sequence_id = @base_sequence_id
		AND process_flag = 0

	SELECT @group_count = @@rowcount
	IF @debug = 1 print '@group_count: ' + str(@group_count)

	-- Get the list of container IDs
	-- Just set the list to zero if all containers for this line were in this group
	IF @group_count = @container_count
	BEGIN
		SET @container_id_list = ',0'
		UPDATE #container SET process_flag = 2 WHERE process_flag = 1
		IF @debug = 1 print '@container_id_list: ' + @container_id_list
	END
	ELSE
	BEGIN
		-- Change the container count to the group_count

		UPDATE #container SET container_count = @group_count WHERE process_flag = 1
		/* rb This sets the weight to the correct amount for viewing purposes, but updates would not work as expected based on
				the window displaying lines per ContainerDestination record, but updating Container.container_weight for each
				one of those modified. The screen would have to sum container_weights per container_id when updating.
		update #container
		set container_weight = round (container_weight * ((container_count * 1.0) / (select count(*) from ContainerDestination
																					where company_id = #container.company_id
																					and profit_ctr_id = #container.profit_ctr_id
																					and receipt_id = #container.receipt_id
																					and line_id = #container.line_id
																					and container_id = #container.container_id)), 2)
		where process_flag = 1
		*/

		SET @container_id_list = ''
		SET ROWCOUNT 1
		WHILE @group_count > 0
		BEGIN
			SELECT @container_id = container_id FROM #container where process_flag = 1
			SET @container_id_list = @container_id_list + ',' + convert(varchar(10), @container_id)
			UPDATE #container SET process_flag = 2 WHERE process_flag = 1
			SET @group_count = @group_count - 1
			IF @debug = 1 print '@container_id_list: ' + @container_id_list
		END
		SET ROWCOUNT 0
	END

select @min_container_id = min(container_id)
from #container
where process_flag = 2

select @max_container_id = max(container_id)
from #container
where process_flag = 2

	-- Update container_id_list
	UPDATE #container SET 
		container_id_list = SUBSTRING(@container_id_list, 2, datalength(@container_id_list) - 1),
		process_flag = 3,
min_container_id = @min_container_id,
max_container_id = @max_container_id
	WHERE process_flag = 2
	SELECT @group_count = @@rowcount

	-- Finish this group
	SET @count_containers = @count_containers - @group_count
	
END

-- IF @debug = 1 print 'selecting from #container'
-- IF @debug = 1 select * from #container

-- Return summarized list of containers
SELECT DISTINCT 
	company_id,
	profit_ctr_id,
	receipt_id, 
	line_id, 
	status,
	staging_row, 
	manifest_container, 
	container_size, 
	container_weight, 
	description, 
	location_type,
	location,
	tracking_num,
	tsdf_approval_code,
	waste_stream,
	base_tracking_num,
	base_container_id,
	base_sequence_id,
	default_manifest_container, 
	default_container_size, 
	default_container_weight, 
	SUBSTRING(default_description,1,30) as default_description, 
	container_count,
	container_id_list,
	0 as include,
	0 as view_only,
	CONVERT(decimal(10,4), NULL) AS manifest_line_weight,
	treatment_id,
	container_percent,
	receipt_container_count,
min_container_id,
max_container_id
FROM #container
ORDER BY
	company_id,
	profit_ctr_id,
	receipt_id, 
	line_id, 
	staging_row, 
	manifest_container, 
	container_size, 
	container_weight, 
	description, 
	location_type,
	location,
	tracking_num,
	tsdf_approval_code,
	waste_stream,
	base_tracking_num,
	base_container_id,
	base_sequence_id

drop table #container

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_container] TO [EQAI]
    AS [dbo];

