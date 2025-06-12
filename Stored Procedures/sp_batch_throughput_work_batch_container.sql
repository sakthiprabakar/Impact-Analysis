
CREATE PROCEDURE dbo.sp_batch_throughput_work_batch_container 
	@company_id			int
,	@profit_ctr_id		int
,	@location_in		varchar(15)
,	@tracking_num		varchar(15)
,	@date_from			datetime
,	@date_to			datetime
,	@user_id			varchar(10)
,	@debug				int
AS

-- =============================================
-- Author:		Jim Gonzales
-- Create date: 11/16/17
-- Description:	Return Batch data from the work table
-- =============================================
BEGIN
	
	SET NOCOUNT ON
	
	delete from work_BatchContainer where work_BatchContainer.user_id = @user_id
	delete from work_BatchWasteCode where work_BatchWasteCode.user_id = @user_id
	delete from work_BatchConstituent where work_BatchConstituent.user_id = @user_id
	
	EXEC sp_work_batch @company_id, @profit_ctr_id, @date_from, @date_to, @location_in, @tracking_num, @user_id, @debug
	
	SELECT [location]
		  ,[tracking_num]
		  ,[company_id]
		  ,[profit_ctr_id]
		  ,[container]
		  ,[container_id]
		  ,[sequence_id]
		  ,[container_type]
		  ,[receipt_date]
		  ,[disposal_date]
		  ,[generator_name]
		  ,[quantity]
		  ,wbc.[bill_unit_code]
		  ,bu.pound_conv
		  ,[manifest]
		  ,[manifest_line_id]
		  ,[approval_code]
		  ,[treatment_id]
		  ,[treatment_desc]
		  ,[bulk_flag]
		  ,[benzene]
		  ,[generic_flag]
		  ,[approval_comments]
		  ,[group_report]
		  ,[group_container]
		  ,[user_id]
		  ,[batch_date]
		  ,[manifest_line]
		  ,[receipt_id]
		  , 
				CASE [container_type]
					WHEN 'S' THEN dbo.fn_container_stock([line_id], [company_id], [profit_ctr_id])
					WHEN 'R' THEN dbo.fn_container_receipt([receipt_id], [line_id])
				END as 'container_desc'
	FROM [dbo].[work_BatchContainer] wbc
	INNER JOIN BillUnit bu
		ON wbc.bill_unit_code = bu.bill_unit_code
	WHERE wbc.company_id = @company_id
	AND	wbc.profit_ctr_id = @profit_ctr_id
	AND	wbc.location = @location_in
	AND	wbc.batch_date between @date_from AND @date_to
	AND	wbc.user_id = @user_id
  
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_throughput_work_batch_container] TO [EQAI]
    AS [dbo];

