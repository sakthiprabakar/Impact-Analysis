CREATE PROCEDURE sp_get_manifest_transporter_uniform (
	@ra_source					varchar(20), 
	@ra_list					varchar(2000),
	@profit_center				int,
	@company_id					int,
	@rejection_manifest_flag	char(1) )
AS
/***************************************************************************************
Returns manifest transporter information for the manifest window
Requires: none
Loads on PLT_XX_AI

08/20/2010 RWB	created
02/28/2011 JDB	Added select for Inbound and Outbound Receipts.
08/22/2013 RWB	Moved to Plt_ai, added company_id to joins
06/25/2018 MPM	GEM 51165 - Added @rejection_manifest_flag input parameter and associated logic.

-- sp_get_manifest_transporter_uniform 'WORKORDER',83900,0,27
-- sp_get_manifest_transporter_uniform 'ORECEIPT',798516,0,21
sp_get_manifest_transporter_uniform 'IRECEIPT', 29601, 1, 21, 'T'
****************************************************************************************/
SET NOCOUNT ON

DECLARE  @more_rows int,
         @list_id int,
         @start int,
         @end int,
         @lnth int,
         @ob_transporter_code varchar(15)
         
CREATE TABLE #source_list (
	source_id int null	)

CREATE TABLE #manifest (
	control_id int null,
	source varchar(10) null,
	source_id int null,
	manifest varchar(15) null,
	transporter_sequence_id int null,
	transporter_code varchar(15) null,
	transporter_name varchar(40) null,
	transporter_EPA_ID varchar(15) null,
	transporter_phone varchar(20) null,
	transporter_sign_name varchar(40) null)

-- decode the source list for retirieval
-- load the source list table
IF LEN(@ra_list) > 0
BEGIN
	SELECT	@more_rows = 1,
		@start = 1
	WHILE @more_rows = 1
	BEGIN
		SELECT @end = CHARINDEX(',',@ra_list,@start)
		IF @end > 0 
		BEGIN
			SELECT @lnth = @end - @start
		  	SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @start = @end + 1
			INSERT INTO #source_list VALUES (@list_id)
		END
		ELSE 
		BEGIN
			SELECT @lnth = LEN(@ra_list)
			SELECT @list_id = CONVERT(int,SUBSTRING(@ra_list,@start,@lnth))
			SELECT @more_rows = 0
			INSERT INTO #source_list VALUES (@list_id)
		END
	END
END

-- determine the source; each source has its own query
-- workorders
IF @ra_source = 'WORKORDER'
BEGIN
	INSERT #manifest	
	SELECT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		wt.workorder_id as source_id,
		wt.manifest,
		wt.transporter_sequence_id,
		wt.transporter_code,
		t.transporter_name,
		t.transporter_EPA_ID,
		t.transporter_phone,
		wt.transporter_sign_name
	FROM WorkOrderTransporter wt, Transporter t
	WHERE wt.workorder_ID IN ( SELECT source_id FROM #source_list )
	AND wt.profit_ctr_ID = @profit_center
	AND wt.company_id = @company_id
	AND wt.transporter_code = t.transporter_code

	GOTO end_process
END

IF @ra_source = 'IRECEIPT' OR @ra_source = 'ORECEIPT'
BEGIN
	INSERT #manifest	
	SELECT DISTINCT 0 AS print_control_id,   
		CONVERT(varchar(10), @ra_source) AS source, 
		r.receipt_id as source_id,
		r.manifest,
		rt.transporter_sequence_id,
		rt.transporter_code,
		COALESCE(t.transporter_name, rt.transporter_name),
		COALESCE(t.transporter_EPA_ID, rt.transporter_EPA_ID),
		COALESCE(t.transporter_phone, rt.transporter_contact_phone),
		COALESCE(rt.transporter_sign_name, rt.transporter_sign_name)
	FROM ReceiptTransporter rt
	INNER JOIN Receipt r ON rt.company_id = r.company_id
		AND rt.company_id = r.company_id
		AND rt.profit_ctr_id = r.profit_ctr_id
		AND rt.receipt_id = r.receipt_id
	LEFT OUTER JOIN Transporter t ON rt.transporter_code = t.transporter_code
	WHERE rt.receipt_ID IN ( SELECT source_id FROM #source_list )
	AND rt.profit_ctr_ID = @profit_center
	AND rt.company_id = @company_id

	IF @ra_source = 'IRECEIPT' AND @rejection_manifest_flag = 'T'
	BEGIN
		-- If the user elected to print a rejection manifest, and if ReceiptDiscrepancy.ob_transporter_code 
		-- is different than the inbound, add that transporter to the inbound transporter(s) as the next 
		-- transporter sequence id.
		SELECT @ob_transporter_code = ISNULL(ob_transporter_code, '')
		  FROM ReceiptDiscrepancy
		 WHERE company_id = @company_id
		   AND profit_ctr_id = @profit_center
		   AND receipt_id IN (SELECT source_id FROM #source_list)

		IF LEN(@ob_transporter_code) > 0 
		BEGIN
			IF NOT EXISTS (SELECT 1 
			FROM ReceiptTransporter rt
			WHERE rt.company_id = @company_id 
			  AND rt.profit_ctr_id = @profit_center 
			  AND rt.transporter_code = @ob_transporter_code
			  AND rt.receipt_id IN (SELECT source_id FROM #source_list))	
			BEGIN
				INSERT #manifest	
					SELECT DISTINCT 0 AS print_control_id,   
						   CONVERT(varchar(10), @ra_source) AS source, 
						   r.receipt_id as source_id,
						   r.manifest,
						   (SELECT MAX(transporter_sequence_id) + 1 
							  FROM ReceiptTransporter
							 WHERE company_id = @company_id 
							   AND profit_ctr_id = @profit_center 
							   AND receipt_id IN (SELECT source_id FROM #source_list)),
						   t.transporter_code,
						   t.transporter_name, 
						   t.transporter_EPA_ID,
						   t.transporter_phone,
						   NULL
					  FROM Receipt r 
					  JOIN Transporter t 
						ON t.transporter_code = @ob_transporter_code
					 WHERE r.company_id = @company_id
					   AND r.profit_ctr_id = @profit_center
					   AND r.receipt_id IN (SELECT source_id FROM #source_list)
					
			END
		END
	END
	
	GOTO end_process
END

end_process:
-- dump the manifest table

SET NOCOUNT OFF

SELECT	control_id,
	source,
	source_id,
	manifest,
	transporter_sequence_id,
	transporter_code,
	transporter_name,
	transporter_EPA_ID,
	transporter_phone,
	transporter_sign_name
FROM #manifest
ORDER BY source_id, manifest, transporter_sequence_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_transporter_uniform] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_transporter_uniform] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_manifest_transporter_uniform] TO [EQAI]
    AS [dbo];

