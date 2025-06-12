drop PROCEDURE sp_container_manifest
go
CREATE PROCEDURE sp_container_manifest
	@debug		int, 		-- 0 or 1 for no debug/debug mode
	@receipt_id	int,
	@profit_ctr_id	int,
	@company_id	int
AS
/****************************************************************************************************
sp_container_manifest:

Assigns the manifest info from a Transfer receipt intelligently to its transfer containers
LOAD TO PLT_XX_AI* on NTSQL1, NTSQL3

sp_container_manifest 1, 65331, 6, 14

05/11/06 SCC	Created
01/29/07 SCC	Container Destination update changed to update only when approval code is NULL
01/18/08 rg     added manifest line to the select so more than one approval per manifest can be used
06/23/2014 SK	Moved to PLT_AI, added company_id input arg
11/29/2018 MPM	GEM 56627 - Modified to updated Container/ContainerDestination properly if either
				ReceiptCommingled.manifest or ReceiptCommingled.trip_id is populated.
12/04/2020 MPM	DevOps 18091 - Corrected the update of ContainerDestination.
01/14/2021 MPM	DevOps 18754 - Corrected the update of ContainerDestination.
01/26/2021 MPM	DevOps 18944 - Corrected the update of ContainerDestination.
****************************************************************************************************/
DECLARE	@container_count		int,
	@line_id			int,
	@manifest			varchar(15),
	@process_count			int,
	@tsdf_code			varchar(15),
	@manifest_quantity		int,
    @manifest_line          int,
	@sequence_id            int,
	@bill_unit_code			varchar(4),
	@container_code			varchar(10),
	@container_size			varchar(10),
	@approval_code			varchar(15),
	@hazmat_class			varchar(15),
	@trip_id				int

SELECT DISTINCT
	Receipt.tsdf_code, 
	ReceiptCommingled.line_id, 
	ReceiptCommingled.approval_code, 
	ReceiptCommingled.manifest, 
	ReceiptCommingled.manifest_unit, 
	ReceiptCommingled.manifest_quantity,
	ReceiptCommingled.manifest_container_code,
	ReceiptCommingled.manifest_hazmat_class,
	ReceiptCommingled.container_count,
	BillUnit.bill_unit_code,
	ContainerSize.container_size,
    ReceiptCommingled.manifest_line_id,
	ReceiptCommingled.sequence_id,
	0 as process_flag,
	ReceiptCommingled.trip_id 
INTO #tmp_process
FROM Receipt 
inner join ReceiptCommingled on Receipt.receipt_id = ReceiptCommingled.receipt_id
	AND Receipt.line_id = ReceiptCommingled.line_id
	AND Receipt.profit_ctr_id = ReceiptCommingled.profit_ctr_id
	AND Receipt.company_id = ReceiptCommingled.company_id
left outer join BillUnit on ReceiptCommingled.manifest_unit = BillUnit.manifest_unit
left outer join ContainerSize on BillUnit.bill_unit_code = ContainerSize.container_size
    AND IsNull(ContainerSize.bulk_flag, 'F') = 'F'
WHERE	Receipt.receipt_id = @receipt_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
ORDER BY ReceiptCommingled.line_id, 
	ReceiptCommingled.manifest,
        ReceiptCommingled.manifest_line_id
SET @process_count = @@rowcount

IF @debug = 1 select 'select * from #tmp_process:'
IF @debug = 1 select * from #tmp_process

-- Reset all previous assignments
IF @process_count > 0 
BEGIN
	UPDATE Container SET 
		manifest = NULL,
		container_size = NULL,
		manifest_container = NULL,
		manifest_hazmat_class = NULL,
		trip_id = NULL 
	WHERE receipt_id = @receipt_id
		AND profit_ctr_id = @profit_ctr_id
		AND company_id = @company_id
		AND container_type = 'R'
	
	UPDATE ContainerDestination SET
		location = NULL,
		tsdf_approval_code = NULL,
		tsdf_approval_bill_unit_code = NULL
	WHERE	ContainerDestination.profit_ctr_id = @profit_ctr_id
		AND ContainerDestination.company_id = @company_id 
		AND ContainerDestination.receipt_id = @receipt_id 
		AND container_type = 'R'
END

-- Process to assign Transfer manifest info to containers
WHILE @process_count > 0 
BEGIN
	SET ROWCOUNT 1
	SELECT @tsdf_code = tsdf_code,
		@line_id = line_id, 
		@manifest = manifest,
		@manifest_quantity = manifest_quantity,
		@approval_code = approval_code, 
		@container_code = manifest_container_code,
		@bill_unit_code = bill_unit_code, 
		@container_size = container_size,
		@hazmat_class = manifest_hazmat_class,
		@container_count = container_count,
        @manifest_line = manifest_line_id,
		@sequence_id = sequence_id,
		@trip_id = trip_id
	FROM #tmp_process WHERE process_flag = 0

	IF @debug = 1 select 'line_id: ' + convert(varchar(10), @line_id)
		+ ' manifest: ' + IsNull(@manifest, 'NULL')
        + ' manifest_line: ' + convert(varchar(10), IsNull(@manifest_line, 0))
		+ ' sequence_id: ' + convert(varchar(10), @sequence_id )
		+ ' manifest_quantity: ' + convert(varchar(10), IsNull(@manifest_quantity, 0))
		+ ' approval_code: ' + IsNull(@approval_code, 'NULL')
		+ ' container_count: ' + convert(varchar(10), @container_count)
		+ ' trip_id: ' + convert(varchar(10), IsNull(@trip_id, 0))
	
	SET ROWCOUNT @container_count
	UPDATE Container SET 
		manifest = @manifest,
		container_size = @container_size,
		manifest_container = @container_code,
		manifest_hazmat_class = @hazmat_class,
		trip_id = @trip_id
	WHERE receipt_id = @receipt_id
		AND profit_ctr_id = @profit_ctr_id
		AND company_id = @company_id
		AND line_id = @line_id
		AND container_type = 'R'
		AND (manifest IS NULL AND trip_id IS NULL AND container_size IS NULL AND manifest_container IS NULL AND manifest_hazmat_class IS NULL)

	IF @debug = 1 
	BEGIN
		select 'updated Container rows: '
		select manifest,
			container_size,
			manifest_container,
			manifest_hazmat_class,
			trip_id,
			*
		FROM Container 
		WHERE receipt_id = @receipt_id
		AND profit_ctr_id = @profit_ctr_id
		AND company_id = @company_id
		AND line_id = @line_id
		AND container_type = 'R'
		AND ((manifest = @manifest AND trip_id = @trip_id)
			OR (manifest = @manifest AND trip_id IS NULL and @trip_id IS NULL)
			OR (manifest IS NULL and @manifest IS NULL AND trip_id = @trip_id))
	END
	
	UPDATE ContainerDestination SET
		location = @tsdf_code,
	 	TSDF_approval_code = @approval_code,
		TSDF_approval_bill_unit_code = @bill_unit_code
	FROM Container
	WHERE ContainerDestination.profit_ctr_id = @profit_ctr_id
		AND ContainerDestination.company_id = @company_id
		AND ContainerDestination.receipt_id = @receipt_id
		AND ContainerDestination.line_id = @line_id
		AND ContainerDestination.container_type = 'R'
		AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
		AND ContainerDestination.company_id = Container.company_id
		AND ContainerDestination.receipt_id = Container.receipt_id
		AND ContainerDestination.line_id = Container.line_id
		AND ContainerDestination.container_id = Container.container_id
		AND ((Container.manifest = @manifest AND Container.trip_id = @trip_id)
			OR (Container.manifest = @manifest AND Container.trip_id IS NULL AND @trip_id IS NULL)
			OR (Container.manifest IS NULL AND Container.trip_id = @trip_id AND @manifest IS NULL))
		AND ContainerDestination.TSDF_approval_code IS NULL
		AND ContainerDestination.location IS NULL
		AND ContainerDestination.tsdf_approval_bill_unit_code IS NULL

	IF @debug = 1 
	BEGIN
		select 'updated ContainerDestination rows: '
		select location,
			TSDF_approval_code,
			TSDF_approval_bill_unit_code, * 
		FROM ContainerDestination 
		JOIN Container
		on ContainerDestination.profit_ctr_id = Container.profit_ctr_id
		AND ContainerDestination.company_id = Container.company_id
		AND ContainerDestination.receipt_id = Container.receipt_id
		AND ContainerDestination.line_id = Container.line_id
		AND ContainerDestination.container_id = Container.container_id
		WHERE ContainerDestination.profit_ctr_id = @profit_ctr_id
		AND ContainerDestination.company_id = @company_id
		AND ContainerDestination.receipt_id = @receipt_id
		AND ContainerDestination.line_id = @line_id
		AND ContainerDestination.container_type = 'R'	
		AND ((Container.manifest = @manifest AND Container.trip_id = @trip_id)
			OR (Container.manifest = @manifest AND Container.trip_id IS NULL AND @trip_id IS NULL)
			OR (Container.manifest IS NULL AND Container.trip_id = @trip_id AND @manifest IS NULL))
		AND ContainerDestination.TSDF_approval_code IS NULL	
	END

	SET ROWCOUNT 1
	UPDATE #tmp_process SET process_flag = 1 WHERE process_flag = 0
	SET @process_count = @process_count - 1
	SET ROWCOUNT 0
END

IF @debug = 1 select 'These are the updated containers'
IF @debug = 1 SELECT line_id, manifest, container_id, trip_id, * from Container
		WHERE receipt_id = @receipt_id
		AND profit_ctr_id = @profit_ctr_id
		AND company_id = @company_id
		AND container_type = 'R'
		ORDER BY Container.line_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_manifest] TO [EQAI]
    AS [dbo];
GO

