
CREATE PROCEDURE sp_trip_validate_approvals (
	@trip_id		int,
	@profit_ctr_id   int,
	@company_id      int )
AS
/***********************************************************************
This procedure validates that the approvals on a trip are not expired or not confirmed.

11/16/2016 MPM	Created from sp_trip_validate_all 
				(GEM 40236 û Trip - Display warning message upon saving a new trip if an approval is expired or not confirmed)
04/02/2025 Umesh DE38463: Trip Dispatch - Need error validation for inactive approvals

sp_trip_validate_approvals 45133, 17, 14
***********************************************************************/
CREATE TABLE #tripvalidationall (
	trip_id		int	NULL,
	trip_sequence_id	int	Null,
	workorder_id	int	null,
	approval_id		varchar(40) Null,
	issue_type	char(1) Null,
	issues varchar(4000) Null,
	trip_status varchar(10) NULL)
	
DECLARE @trip_status		char(1),
		@trip_start			datetime,
		@trip_end			datetime,
		@trip_company		integer,
		@trip_profit_ctr	integer,
		@trip_type			char(1),
		@count_mismatched_manifest	smallint,
		@stop_list					varchar(255),
		@rowcount			integer,
		@tmp_status			char(1),
		@error_count		integer

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
		
------------------------------------------------
--  Get the header information for later use.
------------------------------------------------
SELECT @trip_id = @trip_id,
	@trip_status = trip_status,
	@trip_start = trip_start_date,
	@trip_end = trip_end_date,
	@company_id = company_id,
	@profit_ctr_id = profit_ctr_id,
	@trip_type = type_code
FROM TripHeader WHERE trip_id = @trip_id 
AND profit_ctr_id = @profit_ctr_id
AND company_id =  @company_id 

-------------------------------------------------------------- 	  
-- Look for EQ TSDF with expired approvals
--------------------------------------------------------------
Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'W',
			'Approval has expired',
             @trip_status
    FROM   workorderheader wo join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join TSDF on wod.tsdf_code = tsdf.tsdf_code 
											and tsdf.tsdf_status = 'A'	
											and Isnull(tsdf.eq_flag,'F') = 'T'
								Join Profile on profile.profile_id = wod.profile_id			
      WHERE  wo.workorder_status in ('N', 'C', 'A')
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and profile.ap_expiration_date < GETDATE()
 	  
-------------------------------------------------------------- 	  
-- Look for EQ TSDF with not confirmed approvals
--------------------------------------------------------------
Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'W',
			'Approval is not confirmed',
             @trip_status
    FROM   workorderheader wo join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join TSDF on wod.tsdf_code = tsdf.tsdf_code 
											and tsdf.tsdf_status = 'A'	
											and Isnull(tsdf.eq_flag,'F') = 'T'
								Join ProfileQuoteApproval pqa on pqa.profile_id = wod.profile_id
											and pqa.company_id = wod.profile_company_id
											and pqa.profit_ctr_id = wod.profile_profit_ctr_id
		 
      JOIN TripHeader th on th.trip_id = wo.trip_id
      WHERE  wo.workorder_status in ('N', 'C', 'A')
      AND (isnull(th.lab_pack_flag,'F') = 'F')
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and pqa.confirm_author is null
   
-- return result set
SELECT @rowcount = COUNT(*) FROM #TripvalidationALL
IF @rowcount = 0
BEGIN
	Insert Into #tripvalidationall Values (	
		 @trip_id,
				0,
				0,
				NULL,
				NULL,
				'No Issues Found',
				@trip_status)
END

SELECT 	#TripvalidationALL.trip_id,
	#TripvalidationALL.trip_sequence_id,
	#TripvalidationALL.workorder_id,
	#TripvalidationALL.approval_id,
	#TripvalidationALL.issue_type,
	#TripvalidationALL.issues,
	#TripvalidationALL.trip_status,
	tripheader.trip_start_date,
	TripHeader.trip_end_date,
	TripHeader.trip_desc,
	TripHeader.company_id,
	TripHeader.profit_ctr_id
FROM #TripvalidationALL
JOIN TripHeader ON #TripvalidationALL.trip_id = TripHeader.trip_id
ORDER BY trip_sequence_id, issue_type ASC


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_validate_approvals] TO [EQAI]
    AS [dbo];

