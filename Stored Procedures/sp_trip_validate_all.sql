DROP PROCEDURE IF EXISTS [dbo].[sp_trip_validate_all]
GO

CREATE PROCEDURE [dbo].[sp_trip_validate_all] (
	@trip_id		int,
	@next_status	char(1),
	@profit_ctr_id  int,
	@company_id     int,
	@debug			int = 0 ) WITH RECOMPILE
AS
/***********************************************************************
This procedure validated several aspects of a trip for a validation report
Loads to PLT_AI

02/10/2010 KAM	Created
02/17/2010 KAM	Updated the questions not answered validation to be a warning instead of an error
02/17/2010 KAM	Updated the check on Transporters to join on manifest as well.
02/17/2010 KAM	Updated the check on manifest to remove the first count.
02/18/2010 KAM	Updated the check for confirmed approvals to match on CO and PC.
02/22/2010 KAM	Updated the procedure to stop processing trips that are missing data
02/24/2010 KAM	Update the logic to look for missing data on trips 
02/25/2010 JDB	Added a comparison between work order and approval / TSDF approval data
02/26/2010 JDB	Removed the drop of the temp table
03/02/2010 JDB	Enhanced comparison between work order and approval / TSDF approval data
				to show each field that's different.
				Also added error if WorkOrderDetailUnit.bill_unit_code is not in one of these three lists:
					1. LBS
					2. Manifest Unit (from WorkOrderDetail)
					3. Bill Unit (from approval / TSDF approval)
03/09/2010 JDB	Added better validation message for manifests out of sync between WorkOrderManifest and Detail
03/19/2010 KAM  Cleaned up the above validation to set Nulls = '' so nulls and '' equate to the same.
				Also add a contact IT support for the manifest check
08/05/2010 KAM  Updated the error message for the checking of trip start and end date
11/02/2010 KAM  Updated the validation for a transporter,Look for Missing manifest Units
11/24/2010 KAM  Updated the verification to NON_EQ TSDF''s to not include LBS when looking for multiplt bill units				
12/09/2010 KAM  Updated to look for consolidation percentages that do not add up to 100 %				
01/16/2011 RWB  Validation on workorder_type needs to check new workorder_type_id field
02/03/2012 RWB  Validate for duplicate WorkOrderTransporter, missing or shared WorkOrderManifest records
09/04/2012 RWB  Lab Pack support...look for WasteCodes or Constituents not defined on Profile
11/12/2012 RWB  Make the check for stops without approvals a warning instead of an error
09/13/2013 RWB	Removed validation of primary waste code against approvals
06/19/2014 AM   Added company_id and profit_ctr_id
01/05/2015 RWB  Added set transaction isolation level read uncommitted
07/22/2015 RWB	Check for CCIDs spanning different approvals
		Check for approvals with no billing unit set (warning for Arrived and Unloading, error for Completing)
07/23/2015 RWB	Fixed bug with last validation on CCIDs spanning different approvals
08/04/2015 RWB	For lab pack trips, report expired approvals as a warning instead of an error
09/11/2015 RWB	Add support for things that can go wrong with consolidate_containers_flag
09/21/2015 RWB  ADded logic to verify consolidated containers with and without mixed waste streams
10/09/2015 RWB	Clarified manifest out of sync message
10/14/2015 RWB	When completing a trip, added validations for trasporter sign date and actual arrive/depart dates
10/14/2015 RWB	Modify missing manifest_unit warning to be an error when dispatching
11/20/2015 RWB	Check for duplicate manifest entered...error if within the same trip, warning if outside the trip
11/23/2015 RWB	Don't allow Dispatch or higher if billing project not set
03/31/2016 AM   modified sql to get duplicate transporter_sequence_id's
11/17/2016 MPM	Removed "Multiple manifests exist for this stop" validation.
11/21/2016 MPM	Validate for trip stops that aren't synchronized
12/06/2016 MPM	Added an optional debug parameter.  Also added some "isnull()" wrappers for the validation of WorkOrderManifest table against WorkOrderDetail.
12/29/2016 MPM	Redid the logic behind the validation for trip stops that aren't synchronized.
01/06/2017 MPM	Modified the check for approvals with no billing unit set.
04/18/2017 AM   GEM:42798 - Commented code for 'Unit Weight/Vol' and 'Container Code'.
07/07/2017 MPM	GEM 44222 - Replaced calls to fn_consolidated_shipping_desc to calls to new function, fn_consolidated_shipping_desc_compare.
07/11/2017 MPM	GEM 44287 - Added validation when a trip is completed; each CCID needs to have the same container type and container size for all
				WorkOrderDetail lines that have that CCID.
10/04/2017 AM	GEM 46072 - Modified validation logic to "Not all of the questions for the pick-up report have been answered" and 
                          "Waste Codes added that are not defined on the Profile"
01/04/2018 MPM	GEM 47519 - Added an error when dispatching if the manifest state is blank on any manifest.
02/28/2018 AM   GEM 48589 - Trip - Add to trip validation routine
05/25/2018 AM   GEM 50876  Trip - Per the Retail group Request to remove 'Not all of the questions for the pick-up report have been answered'
										warning message from trip validation.
05/25/2018 AM   EQAI-50915 Trip - Add validation on change of status.
       Warning on move from Dispatched to Arrived, Arrived to Unloading , ERROR on Completing a trip.
08/06/2018 AM   EQAI-49477  *Priority/Urgent* EQAI Trip Does Not Error Out for Inactive Profiles into the designated TSDF
				 Modified "Approval has expired" from wraning to error when status is Complete.
08/10/2018 AM  EQAI-52766  Trip Complete - Error if manifest contains profiles with different customers 
08/24/2018 MPM	GEM 47136 - Added two validations:
				1. Create a warning when saving a trip and an approval is set up to print on a BOL or Non-Hazardous manifest that contains 
					RCRA Hazardous Waste Codes.
				2. Create an error when moving the status of a trip from New to Dispatch if an approval with RCRA Hazardous waste codes is 
					set up to print on a BOL or Non-Hazardous manifest.
11/12/2018 RWB	GEM:56643 - Remove making this an error when completing a trip. Sometimes they manually enter data if a MIM didn't upload a stop
07/22/2020 MPM	DevOps 16714 - Check for duplicate manifest lines.
08/18/2020 RWB  DevOps 17174 - Optimizer went to lunch, had to force an index (WorkOrderHeader wh (with (idx_trip_id))
09/04/2020 MPM	DevOps 17323 - Check for more than one treatment for all consolidated material within a container.
09/16/2020 MPM	DevOps 17202 - Modified the check for an already used manifest number to be done only for haz manifests (not for BOL's).
03/19/2021 MPM	DevOps 18339 - Added validation to ensure that work order detail lines that have waste codes that do not exist on the profile are caught.
04/23/2021 MPM  ME 76147 - Added "with recompile".
05/11/2021 MPM	DevOps 20755 - Added index hint WorkOrderHeader wh (with (idx_trip_id) to queries where appropriate.
05/27/2022 MPM	DevOps 30380 - Added warning message to be displayed when the trip is dispatched and any stop line items are hazmat class 7.
05/27/2022 MPM	DevOps 30393 - Added warning message to be displayed when the trip is dispatched and any stop line items are hazmat class 7 and there is no 
				"Class 7 Additional Description" entered.
08/26/2022 RWB  DevOps 49803 - The query validating combined waste streams started going to lunch, pulled out some code into a temp table
03/16/2023 MPM	DevOps 42688 - Changed the "Please review the approvals on this route as one or more are hazard class 7 and will require a Class 7 
				Additional Description entered at the time of pick up in order for the manifest and paperwork to be printed." validation warning to an error.
06/16/2023 MPM	DevOps 61118 - Added logic to produce an error when completing a trip if there are any non-voided work order detail lines with 
				WorkOrderDetailCC.percentage = 0.
04/02/2025 Umesh DE38463: Trip Dispatch - Need error validation for inactive approvals

sp_trip_validate_all 2152,'D'
sp_trip_validate_all 2670, 'D', 4, 15
sp_trip_validate_all 47693, 'C', 4, 14, 0
sp_trip_validate_all 49967, 'A', 6, 14, 1 
sp_trip_validate_all 76079, 'C', 18, 14, 0
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
		@error_count		integer,
		@total_stops_syncd integer,
		@total_stops		integer,
		@total_stops_not_syncd integer
		
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


-------------------------------------------------------------------
-- Look for WorkOrderDetailUnit records not in:
--
-- 1. LBS
-- 2. WorkOrderDetail.manifest_unit
-- 3. List of approved bill units from Profile or TSDF Approval
--
-------------------------------------------------------------------

IF @debug = 1
	PRINT 'Before ''Invalid WorkOrderDetailUnit'' validation'
	
INSERT INTO #tripvalidationall	
	SELECT woh.trip_id,
		woh.trip_sequence_id,
		woh.workorder_ID,
		wod.TSDF_approval_code,
		'E',
		'Invalid WorkOrderDetailUnit (' 
			+ CASE WHEN ISNULL(wodu.bill_unit_code, '') = '' THEN 'blank'
				ELSE wodu.bill_unit_code
				END
			+ ')',
		@trip_status
	FROM WorkOrderHeader woh with (index(idx_trip_id))
	JOIN WorkOrderDetail wod ON woh.company_id = wod.company_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND woh.workorder_id = wod.workorder_id
		AND wod.resource_type = 'D'
		AND IsNull(wod.TSDF_approval_code,'') > ''
	JOIN WorkOrderDetailUnit wodu ON wodu.company_id = wod.company_id 
		AND wodu.profit_ctr_id = wod.profit_ctr_id
		AND wodu.workorder_id = wod.workorder_id
		AND wodu.sequence_ID = wod.sequence_ID
	JOIN TSDF ON wod.tsdf_code = TSDF.tsdf_code
		AND TSDF.tsdf_status = 'A'
		AND ISNULL(TSDF.eq_flag, 'F') = 'T'
	WHERE woh.workorder_status IN ('N', 'C', 'A')
	AND woh.trip_id = @trip_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.company_id = @company_id
	AND wod.bill_rate <> -2
	AND wodu.bill_unit_code <> 'LBS'
	AND wodu.manifest_flag <> 'T'
	AND wodu.bill_unit_code NOT IN (
		SELECT bill_unit_code
		FROM ProfileQuoteDetail pqd
		WHERE pqd.profile_id = wod.profile_id
		AND pqd.company_id = wod.profile_company_id
		AND pqd.profit_ctr_id = wod.profile_profit_ctr_id
		AND pqd.record_type = 'D'
		AND pqd.status = 'A'
		)
	
	UNION
	
	SELECT woh.trip_id,
		woh.trip_sequence_id,
		woh.workorder_ID,
		wod.TSDF_approval_code,
		'E',
		'Invalid WorkOrderDetailUnit (' 
			+ CASE WHEN ISNULL(wodu.bill_unit_code, '') = '' THEN 'blank'
				ELSE wodu.bill_unit_code
				END
			+ ')',
		@trip_status
	FROM WorkOrderHeader woh with (index(idx_trip_id))
	JOIN WorkOrderDetail wod ON woh.company_id = wod.company_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND woh.workorder_id = wod.workorder_id
		AND wod.resource_type = 'D'
		AND IsNull(wod.TSDF_approval_code,'') > ''
	JOIN WorkOrderDetailUnit wodu ON wodu.company_id = wod.company_id 
		AND wodu.profit_ctr_id = wod.profit_ctr_id
		AND wodu.workorder_id = wod.workorder_id
		AND wodu.sequence_ID = wod.sequence_ID
	JOIN TSDF ON wod.tsdf_code = TSDF.tsdf_code
		AND TSDF.tsdf_status = 'A'
		AND ISNULL(TSDF.eq_flag, 'F') = 'F'
	WHERE woh.workorder_status IN ('N', 'C', 'A')
	AND woh.trip_id = @trip_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.company_id = @company_id
	AND wod.bill_rate <> -2
	AND wodu.bill_unit_code <> 'LBS'
	AND wodu.manifest_flag <> 'T'
	AND wodu.bill_unit_code NOT IN (
		SELECT bill_unit_code
		FROM TSDFApprovalPrice tap
		WHERE tap.tsdf_approval_id = wod.tsdf_approval_id
		AND tap.company_id = wod.company_id
		AND tap.profit_ctr_id = wod.profit_ctr_id
		AND tap.record_type = 'D'
		AND tap.status = 'A'
		)

------------------------------------------------
-- Look for Missing manifest Units
------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Manifest Unit is not defined'' validation'

INSERT INTO #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			case when @next_status = 'D' then 'E' else 'W' end,
			'Manifest Unit is not defined',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join workordermanifest wom on wod.company_id = wom.company_id 
										  AND wod.profit_ctr_id = wom.profit_ctr_id 
										  AND wod.workorder_id = wom.workorder_id 
										  AND wod.manifest = wom.manifest  
								Join TSDF on wod.tsdf_code = tsdf.tsdf_code 
											and tsdf.tsdf_status = 'A'	
											and Isnull(tsdf.eq_flag,'F') = 'T' 
								Left Outer JOIN WorkOrderDetailUnit wodu ON wodu.company_id = wod.company_id 
											AND wodu.profit_ctr_id = wod.profit_ctr_id
											AND wodu.workorder_id = wod.workorder_id
											AND wodu.sequence_ID = wod.sequence_ID
											and wodu.manifest_flag = 'T'			
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and IsNull(wodu.bill_unit_code,'') = ''

--------------------------------------------------------------      
-- Look for EQ ProfileQuoteApproval with not Active approvals  
--------------------------------------------------------------  
Insert Into #tripvalidationall
	(trip_id,
	trip_sequence_id,
	workorder_id,
	approval_id,
	issue_type,
	issues,
	trip_status)   
 SELECT  Distinct wo.trip_id,  
   wo.trip_sequence_id,  
   wo.workorder_ID,  
   wod.TSDF_approval_code,  
   'E',  
   'Approval is inactive',  
             @trip_status  
    FROM   workorderheader wo 
	JOIN workorderdetail wod on wo.company_id = wod.company_id   
            AND wo.profit_ctr_id = wod.profit_ctr_id   
            AND wo.workorder_id = wod.workorder_id  
            AND wod.resource_type = 'D'  
            AND wod.TSDF_approval_code IS NOT NULL
    JOIN ProfileQuoteApproval pqa on pqa.profile_id = wod.profile_id  
           AND pqa.approval_code = wod.TSDF_approval_code  
           AND pqa.profit_ctr_id = wod.profile_profit_ctr_id  
		   AND pqa.company_id = wod.profile_company_id
      JOIN TripHeader th on th.trip_id = wo.trip_id  
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
	   AND wo.company_id = @company_id
	   AND wo.profit_ctr_ID = @profit_ctr_id
	   AND wo.trip_id = @trip_id
	   AND pqa.status = 'I' 
 
------------------------------------------------ 	  
-- Look for Missing Container Code
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Container Code is Null'' validation'
	
Insert Into #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'W',
			'Container Code is Null',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join TSDF on wod.tsdf_code = tsdf.tsdf_code 
											and tsdf.tsdf_status = 'A'	
											and Isnull(tsdf.eq_flag,'F') = 'T' 
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and IsNull(wod.container_code,'') = '' 	  
 	  
------------------------------------------------ 	  
-- Look for wo dates outside the trip dates
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Pick-up date is outside the trip dates'' validation'
 	  
 Insert Into #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'E',
			'Pick-up date is outside the trip dates  ',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
		  AND wo.trip_id = @trip_id 
		  AND wo.profit_ctr_ID = @profit_ctr_id
	      AND wo.company_id = @company_id
 		  AND (wo.start_date < @trip_start or wo.start_date > @trip_end)  
 	  
------------------------------------------------ 	  
-- Look for bad dates
------------------------------------------------		  
IF @debug = 1
	PRINT 'Before ''Trip end date if before the trip start date.'' validation'
 	  
If @trip_end < @trip_start
Begin
	Insert Into #tripvalidationall values
		( @trip_id,
				0,
				0,
				NULL,
				'E',
				'Trip end date if before the trip start date.',
				@trip_status) 
 End  	  
 
------------------------------------------------ 	  
-- Look for bad types
------------------------------------------------		  
If @trip_type = 'T'
Begin
	IF @debug = 1
		PRINT 'Before ''Trip is a template, not allowing the status to be changed'' validation'

	Insert Into #tripvalidationall Values	
		( @trip_id,
				0,
				0,
				NULL,
				'E',
				'Trip is a template, not allowing the status to be changed',
				@trip_status)
 End 
 
If @trip_type = 'U'
Begin
	IF @debug = 1
		PRINT 'Before ''Trip is a unscheduled, not allowing the status to be changed'' validation'

	Insert Into #tripvalidationall values 	
	 (@trip_id,
				0,
				0,
				NULL,
				'E',
				'Trip is a unscheduled, not allowing the status to be changed',
				@trip_status)
 End

------------------------------------------------ 	  
-- Look for bad tsdf_status
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''TSDF Status is not Active'' validation'

Insert Into #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'E',
			'TSDF Status is not Active',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join TSDF on wod.tsdf_code = tsdf.tsdf_code 
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and TSDF.tsdf_status <> 'A'
 	  
------------------------------------------------ 	  
-- Look for bad transporter
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Transporter is missing'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'E',
			'Transporter is missing',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
							join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join WorkorderManifest wom on wod.company_id = wom.company_id 
										  AND wod.profit_ctr_id = wom.profit_ctr_id 
										  AND wod.workorder_id = wom.workorder_id
										  AND wod.manifest = wom.manifest
								Left Outer Join WorkorderTransporter wot on wot.company_id = wom.company_id
										  AND wot.profit_ctr_id = wom.profit_ctr_ID
										  and wot.manifest = wom.manifest
										  and wot.workorder_id = wom.workorder_ID 
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and IsNull(wot.transporter_code,'') = ''

------------------------------------------------ 	  
-- Look for duplicate WorkOrderTransporter records
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Duplicate transporters sequence ID'' validation'

-- rb 02/03/2012
-- modified sql to get duplicate transporter_sequence_id's
insert #tripvalidationall
select distinct wh.trip_id, wh.trip_sequence_id, wh.workorder_id, null, 'E',
      'Duplicate transporters sequence ID on ' + wd.manifest + '. Contact IT Support!',@trip_status
from workorderheader wh with (index(idx_trip_id))
join workorderdetail wd
      on wh.workorder_id = wd.workorder_id
      and wh.company_id = wd.company_id
      and wh.profit_ctr_id = wd.profit_ctr_id
      and wd.resource_type = 'D'
      and wd.bill_rate > -2
where wh.workorder_status in ('N', 'C', 'A') 
and wh.trip_id = @trip_id 
and wh.profit_ctr_ID = @profit_ctr_id
and wh.company_id = @company_id
and  exists (
            select 1
            from WorkOrderTransporter
            where workorder_id = wd.workorder_ID
            and company_id = wd.company_id
            and profit_ctr_id = wd.profit_ctr_ID
            and manifest = wd.manifest
            group by workorder_id, company_id, profit_ctr_id, manifest, transporter_sequence_id
            having COUNT(*) > 1
            )

------------------------------------------------ 	  
-- Look for bad workorder_type
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Work Order Type is missing'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'E',
			'Work Order Type is missing',
             @trip_status
    FROM   workorderheader wo  with (index(idx_trip_id))
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	 AND wo.company_id = @company_id
-- rb  	  and IsNull(wo.workorder_type,'') = ''	  
  	  and IsNull(wo.workorder_type_id,0) = 0
 	   
------------------------------------------------ 	  
-- Look for bad generator_status
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Generator Status is not Active'' validation'

Insert Into #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'E',
			'Generator Status is not Active',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''	  
								Join generator on generator.generator_id =wo.generator_id
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and generator.status <> 'A' 	   

------------------------------------------------ 	  
-- Look for trip_status before completing
------------------------------------------------
If @next_status = 'C' and @trip_status <> 'U' and @trip_status <> 'C'
Begin	
	IF @debug = 1
		PRINT 'Before ''Trip must be in unloading status before completing the trip'' validation'

	Insert Into #tripvalidationall values	
		(@trip_id,
				0,
				NULL,
				NULL,
				'E',
				'Trip must be in unloading status before completing the trip',
				 @trip_status)
 End
 
If @next_status = 'A' and @trip_status <> 'D' and @trip_status <> 'A'
Begin	
	IF @debug = 1
		PRINT 'Before ''Trip Is not in dispatched status and must be before arriving the trip'' validation'

	Insert Into #tripvalidationall values	
		(@trip_id,
				0,
				NULL,
				NULL,
				'E',
				'Trip Is not in dispatched status and must be before arriving the trip',
				 @trip_status)
 End

------------------------------------------------ 	  
-- Look for stops without approvals
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''This stop is defined but no approvals have been set-up'' validation'

Insert Into #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'W', -- 'E',  rb 11/12/2012 make a warning instead of an error
			'This stop is defined but no approvals have been set-up',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
    Left outer join WorkorderStop on wo.company_id = WorkorderStop.company_id
					and wo.profit_ctr_id = WorkorderStop.profit_ctr_id 
					and wo.workorder_id = WorkorderStop.workorder_id
					and WorkorderStop.stop_sequence_id = 1
    WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
	  AND IsNull(WorkorderStop.decline_id,1) = 1
	  and WorkorderStop.waste_flag = 'T'
      AND (Select count(*) from WorkorderDetail wod where  wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
										  AND wod.bill_rate <> -2) = 0


------------------------------------------------ 	  
-- Look for inactive or no admit customer
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Customer is either not active or is on no admit'' validation'

Insert Into #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'E',
			'Customer is either not active or is on no admit',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
	join customer on customer.customer_ID = wo.customer_id 
    WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
      AND (customer.cust_status <> 'A' or customer.terms_code = 'NOADMIT')


------------------------------------------------ 	  
-- Look for workorders
------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Trip has no active stops'' validation'

	Insert Into #tripvalidationall 	
		Select @trip_id,
				0,
				NULL,
				NULL,
				'E',
				'Trip has no active stops',
				 @trip_status
				 From TripHeader 
				 Where TripHeader.trip_id = @trip_id
				 AND TripHeader.profit_ctr_ID = @profit_ctr_id
	             AND TripHeader.company_id = @company_id
				 and (select count(*) from WorkorderHeader with (index(idx_trip_id)) where WorkorderHeader.trip_id = @trip_id AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
							AND WorkorderHeader.company_id = @company_id and WorkorderHeader.workorder_status in ('N', 'C', 'A')) = 0
						
------------------------------------------------ 	  
-- Look for manifest_qtys without a manifest #
------------------------------------------------
If @next_status = 'C'
	Select @tmp_status = 'E'
Else
	Select @tmp_status = 'W'

IF @debug = 1
	PRINT 'Before ''Approval has manifest quantity but no manifest is defined'' validation'

Insert Into #tripvalidationall	
	SELECT  wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			@tmp_status,
			'Approval has manifest quantity but no manifest is defined',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
							join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
							Left Outer JOIN WorkOrderDetailUnit wodu ON wodu.company_id = wod.company_id 
											AND wodu.profit_ctr_id = wod.profit_ctr_id
											AND wodu.workorder_id = wod.workorder_id
											AND wodu.sequence_ID = wod.sequence_ID
											and wodu.manifest_flag = 'T'
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and (wodu.quantity > 0 and wod.manifest like 'MANIFEST_%')

--  ************************************************************************************* 
--  Check the WorkOrderManifest table against WorkOrderDetail to make sure the manifests
--  match up. 
--  ************************************************************************************* 

SELECT DISTINCT wom.workorder_id, woh.trip_sequence_id, wom.manifest, wod.tsdf_code
INTO #tmp_wom_manifest
FROM WorkorderManifest wom
JOIN WorkorderHeader woh with (index(idx_trip_id))
	ON woh.company_id = wom.company_id
	AND woh.profit_ctr_ID = wom.profit_ctr_ID
	AND woh.workorder_ID = wom.workorder_ID
LEFT OUTER JOIN WorkOrderDetail wod ON wod.workorder_id = wom.workorder_id
	AND wod.company_id = wom.company_id
	AND wod.profit_ctr_id = wom.profit_ctr_id
	AND wod.manifest = wom.manifest
WHERE woh.trip_id = @trip_ID
AND woh.profit_ctr_ID = @profit_ctr_id
AND woh.company_id = @company_id
AND wom.manifest NOT LIKE 'MANIFEST_%'
AND woh.workorder_status in('N', 'C', 'A') 

SELECT DISTINCT wod.workorder_id, woh.trip_sequence_id, manifest
INTO #tmp_wod_manifest
FROM WorkorderDetail wod
JOIN WorkorderHeader woh with (index(idx_trip_id))
	ON woh.company_id = wod.company_id
	AND woh.profit_ctr_ID = wod.profit_ctr_ID
	AND woh.workorder_ID = wod.workorder_ID
WHERE woh.trip_id = @trip_ID
AND woh.profit_ctr_ID = @profit_ctr_id
AND woh.company_id = @company_id
AND resource_type = 'D'
AND bill_rate > -2
AND manifest NOT LIKE 'MANIFEST_%'
AND woh.workorder_status in('N', 'C', 'A') 

/* rb 10/09/2015 Change error message...also don't have one message with all stops, report stop and manifest together
Select @count_mismatched_manifest = 0

SELECT @count_mismatched_manifest = @count_mismatched_manifest + COUNT(*)
FROM #tmp_wom_manifest wom
WHERE wom.manifest NOT IN (SELECT wod.manifest FROM #tmp_wod_manifest wod WHERE wom.workorder_id = wod.workorder_id)
	
SELECT @count_mismatched_manifest = @count_mismatched_manifest + COUNT(*)
FROM #tmp_wod_manifest wod
WHERE wod.manifest NOT IN (SELECT wom.manifest FROM #tmp_wom_manifest wom WHERE wod.workorder_id = wom.workorder_id)
	
IF @count_mismatched_manifest > 0
BEGIN
	--SELECT @stop_list = COALESCE(@stop_list + ', ', '') + CAST(wom.trip_sequence_id AS varchar(5))
	--FROM #tmp_wom_manifest wom
	--JOIN #tmp_wod_manifest wod ON wom.workorder_id = wod.workorder_id
	--AND wom.manifest <> wod.manifest
	--ORDER BY wom.trip_sequence_id

	SELECT @stop_list = COALESCE(@stop_list + ', ', '') + CAST(wom.trip_sequence_id AS varchar(5))
	FROM #tmp_wom_manifest wom
	WHERE wom.manifest NOT IN (SELECT wod.manifest FROM #tmp_wod_manifest wod WHERE wom.workorder_id = wod.workorder_id)

	SELECT @stop_list = COALESCE(@stop_list + ', ', '') + CAST(wod.trip_sequence_id AS varchar(5))
	FROM #tmp_wod_manifest wod
	WHERE wod.manifest NOT IN (SELECT wom.manifest FROM #tmp_wom_manifest wom WHERE wod.workorder_id = wom.workorder_id)
	
	INSERT INTO #tripvalidationall 	
	SELECT @trip_id,
		0,
		NULL,
		NULL,
		'E',
		'Contact IT Support - Manifest records out of sync for stops:  ' + @stop_list,
		@trip_status
	FROM TripHeader 
	WHERE TripHeader.trip_id = @trip_id
	AND TripHeader.profit_ctr_ID = @profit_ctr_id
	AND TripHeader.company_id = @company_id
END 
*/
IF @debug = 1
	PRINT 'Before validation of WorkOrderManifest table against WorkOrderDetail'

insert #tripvalidationall
select @trip_id,
	wm.trip_sequence_id,
	null,
	null,
	'E',
	'Manifest ' + isnull(wm.manifest,'(null)') + ' for TSDF ' + isnull(wm.tsdf_code,'(null)') + ' does not contain any approvals with quantities. Please verify if this manifest should exist or not. If it is not needed, please change the manifest number to MANIFEST_{any digit not yet used}',
	@trip_status
from #tmp_wom_manifest wm
where wm.manifest is not null
and not exists (select 1 from #tmp_wod_manifest wd
			where wd.workorder_id = wm.workorder_id
			and wd.manifest = wm.manifest)

DROP TABLE #tmp_wom_manifest
DROP TABLE #tmp_wod_manifest

------------------------------------------------ 	  
-- Look for missing or shared WorkOrderManifest records
------------------------------------------------		
IF @debug = 1
	PRINT 'Before ''Missing manifest record'' validation'

-- rb 02/03/2012
insert #tripvalidationall
select distinct wh.trip_id, wh.trip_sequence_id, wh.workorder_id, wd.tsdf_approval_code, 'E',
	'Missing manifest record: ' + wd.manifest + '. Contact IT Support!',
	@trip_status
from workorderheader wh with (index(idx_trip_id))
join workorderdetail wd
	on wh.workorder_id = wd.workorder_id
	and wh.company_id = wd.company_id
	and wh.profit_ctr_id = wd.profit_ctr_id
	and wd.resource_type = 'D'
where wh.workorder_status in ('N', 'C', 'A') 
and wh.trip_id = @trip_id 
AND wh.profit_ctr_ID = @profit_ctr_id
AND wh.company_id = @company_id
and wd.bill_rate <> -2
and not exists (select 1 from WorkOrderManifest
			where workorder_id = wd.workorder_id
			and company_id = wd.company_id
			and profit_ctr_id = wd.profit_ctr_id
			and manifest = wd.manifest)

IF @debug = 1
	PRINT 'Before ''shared manifest record'' validation'

insert #tripvalidationall
select distinct wh.trip_id, wh.trip_sequence_id, wh.workorder_id, null, 'E',
	wm.manifest + ' shared with multiple TSDFs. Contact IT Support!',
	@trip_status
from workorderheader wh with (index(idx_trip_id))
join workordermanifest wm
	on wh.workorder_id = wm.workorder_id
	and wh.company_id = wm.company_id
	and wh.profit_ctr_id = wm.profit_ctr_id
where wh.workorder_status in ('N', 'C', 'A') 
and wh.trip_id = @trip_id 
AND wh.profit_ctr_ID = @profit_ctr_id
AND wh.company_id = @company_id
and (select count(distinct tsdf_code) from WorkOrderDetail
		where workorder_id = wm.workorder_id
		and company_id = wm.company_id
		and profit_ctr_id = wm.profit_ctr_id
		and resource_type = 'D'
		and bill_rate > -2
		and manifest = wm.manifest) > 1


------------------------------------------------ 	  
-- Look for Approval has quantity but no bill unit
------------------------------------------------		
--Insert Into #tripvalidationall	
--	SELECT  wo.trip_id,
--			wo.trip_sequence_id,
--			wo.workorder_ID,
--			wod.TSDF_approval_code,
--			'E',
--			'Approval has quantity but no bill unit',
--             @trip_status
--    FROM   workorderheader wo join workorderdetail wod on wo.company_id = wod.company_id 
--										  AND wo.profit_ctr_id = wod.profit_ctr_id 
--										  AND wo.workorder_id = wod.workorder_id
--										  AND wod.resource_type = 'D'
--      WHERE  wo.workorder_status in ('N', 'C', 'A') 
--      AND wo.trip_id = @trip_id 
-- 	  AND wod.bill_rate <> -2
-- 	  and (wod.quantity_used > 0 and wod.bill_unit_code is null)

------------------------------------------------ 	  
-- Look for pick-up date > complete date
------------------------------------------------
if @next_status = 'C'
Begin	
	
	IF @debug = 1
		PRINT 'Before ''Pick-up date is later than today''s date'' validation'

Insert Into #tripvalidationall	
	SELECT distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'E',
			'Pick-up date is later than today''s date',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
	join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and wo.start_date > GetDate()

End

------------------------------------------------ 	  
--EQAI-52766  Trip Complete - Error if manifest contains profiles with different customers
------------------------------------------------
if @next_status = 'C'
Begin
	
  Insert Into #tripvalidationall
	SELECT  distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
		    'E',
			'Manifest ' + isnull(wod.manifest ,'(null)') + ' contains approvals that are for different customers.  Please correct this before completing the trip.',
			@trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join workorderstop wos on wo.company_id = wos.company_id 
										  AND wo.profit_ctr_id = wos.profit_ctr_id 
										  AND wo.workorder_id = wos.workorder_id
										  and wos.stop_sequence_id = 1	  
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  AND (select COUNT(distinct p.customer_id)
 			from WorkOrderDetail wod2
 			join Profile p
 				on p.profile_id = wod2.profile_id
 			where wod2.workorder_ID = wo.workorder_ID
 			and wod2.company_id = wo.company_id
 			and wod2.profit_ctr_ID = wo.profit_ctr_ID
 			and wod2.manifest = wod.manifest
 			and wod2.bill_rate <> -2) > 1 
End
------------------------------------------------ 	  
-- Look for Non EQ TSDF with Multiple Bill Units
------------------------------------------------
--Insert Into #tripvalidationall	
--	SELECT  Distinct wo.trip_id,
--			wo.trip_sequence_id,
--			wo.workorder_ID,
--			wod.TSDF_approval_code,
--			'E',
--			'Non EQ TSDF has multiple billing units',
--             @trip_status
--    FROM   workorderheader wo join workorderdetail wod on wo.company_id = wod.company_id 
--										  AND wo.profit_ctr_id = wod.profit_ctr_id 
--										  AND wo.workorder_id = wod.workorder_id
--										  AND wod.resource_type = 'D'
--								Join TSDF on wod.tsdf_code = tsdf.tsdf_code 
--											and tsdf.tsdf_status = 'A'	
--											and Isnull(tsdf.eq_flag,'F') = 'F' 
--      WHERE  wo.workorder_status in ('N', 'C', 'A') 
--      AND wo.trip_id = @trip_id 
-- 	  AND wod.bill_rate <> -2
-- 	  and (Select count(*) from WorkorderdetailUnit wou where wou.workorder_id = wod.workorder_id
-- 														and wou.company_id = wod.company_id
-- 														and wou.profit_ctr_id = wod.profit_ctr_id
-- 														and wou.sequence_id = wod.sequence_ID
--														AND wou.bill_unit_code <> 'LBS') > 1
 														

-------------------------------------------------------------- 	  
-- Look for EQ TSDF with approvals about to expire
--------------------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Approval expires in 30 days or less'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'W',
			'Approval expires in 30 days or less',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
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
 	  and profile.ap_expiration_date < DateAdd(day,30,GETDATE())
 	  and profile.ap_expiration_date > GETDATE()
 	  
-------------------------------------------------------------- 	  
-- Look for EQ TSDF with expired approvals
--------------------------------------------------------------
if exists (select 1 from TripHeader where trip_id = @trip_id and isnull(lab_pack_flag,'F') = 'T')
	set @tmp_status = 'W'
else
	set @tmp_status = 'E'
-- EQAI-49477	
if @next_status = 'C'
	set @tmp_status = 'E'
	
IF @debug = 1
	PRINT 'Before ''Approval has expired'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			@tmp_status,
			'Approval has expired',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
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
IF @debug = 1
	PRINT 'Before ''Approval is not confirmed'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'E',
			'Approval is not confirmed',
       @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
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
      AND (isnull(th.lab_pack_flag,'F') = 'F' or @next_status = 'C')
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and pqa.confirm_author is null
 	  
-------------------------------------------------------------- 	  
-- Look for  stops marked as no waste that have QTY's
--------------------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Manifest quantities on stop that is specified as No Waste Picked Up'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'W',
			'Manifest quantities on stop that is specified as No Waste Picked Up',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join workorderstop wos on wo.company_id = wos.company_id 
										  AND wo.profit_ctr_id = wos.profit_ctr_id 
										  AND wo.workorder_id = wos.workorder_id
										  and wos.stop_sequence_id = 1		  
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and wos.waste_flag = 'F'
 	  and ((select SUM(quantity) from workorderdetailunit where wo.company_id = workorderdetailunit.company_id 
										  AND wo.profit_ctr_id = workorderdetailunit.profit_ctr_id 
										  AND wo.workorder_id = workorderdetailunit.workorder_id) > 0)
 	
 -------------------------------------------------------------- 	  
-- Look for  stops marked as Void that have QTY's
--------------------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Quantities on stop that is has a status of Void'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			'',
			'W',
			'Quantities on stop that is has a status of Void',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
								join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join workorderstop wos on wo.company_id = wos.company_id 
										  AND wo.profit_ctr_id = wos.profit_ctr_id 
										  AND wo.workorder_id = wos.workorder_id
										  and wos.stop_sequence_id = 1		  
      WHERE  wo.workorder_status = 'V'
      AND wo.trip_id = @trip_id
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id 
  	  and ((select SUM(quantity) from workorderdetailunit where wo.company_id = workorderdetailunit.company_id 
										  AND wo.profit_ctr_id = workorderdetailunit.profit_ctr_id 
										  AND wo.workorder_id = workorderdetailunit.workorder_id) > 0)
-------------------------------------------------------------- 	  
-- Look for Approvals where the container % does not = 100
--------------------------------------------------------------
if @next_status = 'C'
Begin
	IF @debug = 1
		PRINT 'Before ''CCID percentages do not add up to 100%'' validation'

	Insert Into #tripvalidationall	
		SELECT  Distinct wo.trip_id,
				wo.trip_sequence_id,
				wo.workorder_ID,
				wod.TSDF_approval_code,
				'E',
				'CCID percentages do not add up to 100%',
				 @trip_status
		FROM   workorderheader wo with (index(idx_trip_id))
		join workorderdetail wod on wo.company_id = wod.company_id 
											  AND wo.profit_ctr_id = wod.profit_ctr_id 
											  AND wo.workorder_id = wod.workorder_id
											  AND wod.resource_type = 'D'
		  WHERE  wo.workorder_status in ('N', 'C', 'A') 
		  AND wo.trip_id = @trip_id 
		  AND wo.profit_ctr_ID = @profit_ctr_id
	      AND wo.company_id = @company_id
 		  AND wod.bill_rate <> -2
 		  and (Select SUM(percentage) from WorkOrderDetailCC where WorkOrderDetailCC.workorder_id = wod.workorder_ID
 															AND WorkOrderDetailCC.company_id = wod.company_ID
 															AND WorkOrderDetailCC.profit_ctr_id = wod.profit_ctr_id
 															and WorkOrderDetailCC.sequence_id = wod.sequence_ID) not in (0,100, Null)
End 

-- DevOps 61118 - Return an error when completing a trip if there are any non-voided work order detail lines with WorkOrderDetailCC.percentage = 0.
IF @next_status = 'C'
BEGIN
	IF @debug = 1
		PRINT 'Before ''CCID percentage is 0'' validation'

	INSERT INTO #tripvalidationall	
		 SELECT DISTINCT wo.trip_id,
				wo.trip_sequence_id,
				wo.workorder_ID,
				wod.TSDF_approval_code,
				'E',
				'Please review the split percentages on manifest ' + wod.manifest + ' for approval code ' + wod.TSDF_approval_code + '.  A split percentage cannot be set to 0%.',
				 @trip_status
		FROM WorkOrderHeader wo WITH (INDEX(idx_trip_id))
		JOIN WorkOrderDetail wod 
			ON wo.company_id = wod.company_id 
			AND wo.profit_ctr_id = wod.profit_ctr_id 
			AND wo.workorder_id = wod.workorder_id
			AND wod.resource_type = 'D'
 			AND wod.bill_rate <> -2
		JOIN WorkOrderDetailCC wodcc 
			ON wodcc.company_id = wod.company_id 
			AND wodcc.profit_ctr_id = wod.profit_ctr_id 
			AND wodcc.workorder_id = wod.workorder_id
			AND wodcc.sequence_id = wod.sequence_id
			AND wodcc.percentage = 0
		  WHERE wo.workorder_status in ('N', 'C', 'A') 
			AND wo.trip_id = @trip_id 
			AND wo.profit_ctr_ID = @profit_ctr_id
			AND wo.company_id = @company_id
END 

-------------------------------------------------------------- 
------ EQAI-48589 - AM  	  
-------------------------------------------------------------- 	  
if @next_status = 'A' OR @next_status = 'U'
Begin
IF @debug = 1
		PRINT 'The work order is set as no waste picked up but appears to have waste.  Please correct the Pickup Status field'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'W',
			'The work order is set as no waste picked up but appears to have waste.  Please correct the Pickup Status field',
             @trip_status
	FROM   workorderheader wo with (index(idx_trip_id))
	JOIN workorderdetail wod on wo.company_id = wod.company_id 
		 AND wo.profit_ctr_id = wod.profit_ctr_id 
		 AND wo.workorder_id = wod.workorder_id
		 AND wod.bill_rate > -2
		 AND wod.resource_type = 'D'
	JOIN workorderstop wos on wod.company_id = wos.company_id 
		 AND wod.profit_ctr_id = wos.profit_ctr_id 
		 AND wod.workorder_id = wos.workorder_id
		 AND wos.stop_sequence_id = 1	
		 AND wos.waste_flag = 'F'  	  
    WHERE wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
END 

if  @next_status = 'C'	
Begin
IF @debug = 1
		PRINT 'The work order is set as no waste picked up but appears to have waste.  Please correct the Pickup Status field'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'E',
			'The work order is set as no waste picked up but appears to have waste.  Please correct the Pickup Status field',
             @trip_status
	FROM   workorderheader wo with (index(idx_trip_id))
	JOIN workorderdetail wod on wo.company_id = wod.company_id 
		 AND wo.profit_ctr_id = wod.profit_ctr_id 
		 AND wo.workorder_id = wod.workorder_id
		 AND wod.bill_rate > -2
		 AND wod.resource_type = 'D'
	JOIN workorderstop wos on wod.company_id = wos.company_id 
		 AND wod.profit_ctr_id = wos.profit_ctr_id 
		 AND wod.workorder_id = wos.workorder_id
		 AND wos.stop_sequence_id = 1	
		 AND wos.waste_flag = 'F'  	  
    WHERE wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
END 

-------------------------------------------------------------- 	  
-- Look for  stops without a manifest line or page that have QTY's -complete only
--------------------------------------------------------------
--if @next_status = 'C'
--Begin
--	Insert Into #tripvalidationall	
--		SELECT  Distinct wo.trip_id,
--				wo.trip_sequence_id,
--				wo.workorder_ID,
--				wod.TSDF_approval_code,
--				'E',
--				'Missing manifest page or line number',
--				 @trip_status
--		FROM   workorderheader wo join workorderdetail wod on wo.company_id = wod.company_id 
--											  AND wo.profit_ctr_id = wod.profit_ctr_id 
--											  AND wo.workorder_id = wod.workorder_id
--											  AND wod.resource_type = 'D'
--		  WHERE  wo.workorder_status in ('N', 'C', 'A') 
--		  AND wo.trip_id = @trip_id 
-- 		  AND wod.bill_rate <> -2
-- 		  and (wod.manifest_quantity  > 0 and (wod.manifest_line_id is null or wod.manifest_page_num is null))  
--End 	
 -------------------------------------------------------------- 	  
-- Look for  Non-EQ tsdfs with profile information
--------------------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Profile information loaded for Non-EQ TSDF'' validation'

Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			wod.TSDF_approval_code,
			'E',
			'Profile information loaded for Non-EQ TSDF',
             @trip_status
    FROM   workorderheader wo with (index(idx_trip_id))
							join workorderdetail wod on wo.company_id = wod.company_id 
										  AND wo.profit_ctr_id = wod.profit_ctr_id 
										  AND wo.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
							  Join TSDF on wod.TSDF_code = TSDF.TSDF_code
											and tsdf.tsdf_status = 'A'	
											and Isnull(tsdf.eq_flag,'F') = 'F'		  
      WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and (wod.profile_id  > 0 or wod.profile_company_id > 0 or wod.profile_profit_ctr_id > 0)  	
 	  
-------------------------------------------------------------- 	  
-- Look for stops with multiple manifests 
--------------------------------------------------------------
/*Insert Into #tripvalidationall	
	SELECT  Distinct wo.trip_id,
			wo.trip_sequence_id,
			wo.workorder_ID,
			NULL,
			'W',
			'Multiple manifests exist for this stop',
             @trip_status
    FROM   workorderheader wo 
    WHERE  wo.workorder_status in ('N', 'C', 'A') 
      AND wo.trip_id = @trip_id 
      AND wo.profit_ctr_ID = @profit_ctr_id
	  AND wo.company_id = @company_id
 	  and (Select count(distinct manifest) from WorkorderDetail where wo.company_id = WorkorderDetail.company_id 
										  AND wo.profit_ctr_id = WorkorderDetail.profit_ctr_id 
										  AND wo.workorder_id = WorkorderDetail.workorder_id
										  AND WorkorderDetail.resource_type = 'D'
										  AND IsNull(workorderdetail.TSDF_approval_code,'') > '' 
										  AND WorkorderDetail.bill_rate > -2) > 1
*/
-------------------------------------------------------------- 	  
-- Look for stops where the Pickup report Questions have not been answered
-- EQAI-50876  Trip - Request to remove warning message from trip validation
--------------------------------------------------------------
/*
IF @next_status = 'A' or @next_status = 'U' or @next_status = 'C'
BEGIN
	IF @debug = 1
		PRINT 'Before ''Not all of the questions for the pick-up report have been answered'' validation'
		
	INSERT INTO #tripvalidationall	
		SELECT DISTINCT wo.trip_id,
				wo.trip_sequence_id,
				wo.workorder_ID,
				NULL,
				'W',
				'Not all of the questions for the pick-up report have been answered',
				 @trip_status
		FROM   workorderheader wo 
		  WHERE  wo.workorder_status in ('N', 'C', 'A') 
		  AND wo.trip_id = @trip_id
		  AND wo.profit_ctr_ID = @profit_ctr_id
	      AND wo.company_id = @company_id 
 		  and exists (Select 1 from TripQuestion where workorder_id = wo.workorder_ID
						and company_id = wo.company_id 
						and profit_ctr_id = wo.profit_ctr_ID 
						and ISNULL(print_on_ltl_ind,0) > 0
						and answer_type_id <> 1 )
						--and DATALENGTH(ISNULL(ltrim(rtrim(answer_text)),'')) = 0)
END

*/
----------------------------------------------------------------------  
-- Look for stops where data doesn't match profile/TSDF approval
----------------------------------------------------------------------

IF @next_status = 'N' OR @next_status = 'D'
BEGIN
	CREATE TABLE #TripApprovalDiff	(
		workorder_id		int,
		trip_sequence_id	int,
		tsdf_approval_code	varchar(40),
		mismatch_field		varchar(50)	)

	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id, wod.tsdf_approval_code, 'Waste Stream'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id))
	ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.waste_stream, '') <> ISNULL(wod.waste_stream, '')

/*** rb 09/13/2013
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id, wod.tsdf_approval_code, 'Primary Waste Code'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader ON wod.company_id = WorkorderHeader.company_id

	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	INNER Join WorkorderWasteCode wowc on wowc.workorder_id = wod.workorder_ID
										and wowc.company_id = wod.company_id
										and wowc.profit_ctr_id = wod.profit_ctr_ID
										and wowc.workorder_sequence_id = wod.sequence_ID
										and wowc.sequence_id = 1
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND ISNULL(TSDFApproval.waste_code, '') <> ISNULL(wowc.waste_code, '')
***/
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id, wod.tsdf_approval_code, 'Waste Description'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.waste_desc, '') <> ISNULL(wod.description, '')
	
	--INSERT INTO #TripApprovalDiff
	--SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Container Code'
	--FROM WorkorderDetail wod
	--INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	--INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	--INNER JOIN WorkorderHeader ON wod.company_id = WorkorderHeader.company_id
	--AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	--AND wod.workorder_id = WorkorderHeader.workorder_id
	--WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	--AND WorkorderHeader.trip_id = @trip_id
 --   AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	--AND WorkorderHeader.company_id = @company_id
	--AND ISNULL(TSDFApproval.manifest_container_code, '') <> ISNULL(wod.container_code, '')
	
	--INSERT INTO #TripApprovalDiff
	--SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Unit Weight/Vol.'
	--FROM WorkorderDetail wod
	--INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	--INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	--INNER JOIN WorkorderHeader ON wod.company_id = WorkorderHeader.company_id
	--AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	--AND wod.workorder_id = WorkorderHeader.workorder_id
	--INNER JOIN WorkOrderDetailUnit wodu ON wodu.company_id = wod.company_id
	--								AND wodu.profit_ctr_id = wod.profit_ctr_id
	--								AND wodu.workorder_id = wod.workorder_id
	--								AND wodu.sequence_id = wod.sequence_id
	--								AND IsNull(wodu.manifest_flag,'F') = 'T'
	--Join BillUnit on wodu.bill_unit_code = BillUnit.bill_unit_code								
	--WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	--AND WorkorderHeader.trip_id = @trip_id
 --   AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	--AND WorkorderHeader.company_id = @company_id
	--AND ISNULL(TSDFApproval.manifest_wt_vol_unit, '') <> ISNULL(BillUnit.manifest_unit, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'DOT Shipping Name'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.DOT_shipping_name, '') <> ISNULL(wod.DOT_shipping_name, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Handling Instructions'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.hand_instruct, '') <> ISNULL(wod.manifest_hand_instruct , '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Management Code'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.management_code, '') <> ISNULL(wod.management_code , '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'RQ Flag'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.reportable_quantity_flag, '') <> ISNULL(wod.reportable_quantity_flag, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'RQ Reason'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.RQ_reason, '') <> ISNULL(wod.RQ_reason, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'DOT Haz Mat'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.hazmat, '') <> ISNULL(wod.hazmat, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Haz Class'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.hazmat_class, '') <> ISNULL(wod.hazmat_class , '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Sub Haz Class'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.subsidiary_haz_mat_class, '') <> ISNULL(wod.subsidiary_haz_mat_class , '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'UN/NA Number'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ( ISNULL(TSDFApproval.UN_NA_flag, '') <> ISNULL(wod.UN_NA_flag, '')
		OR ISNULL(TSDFApproval.UN_NA_number, -999) <> ISNULL(wod.UN_NA_number , -999) )
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Packing Group'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.package_group, '') <> ISNULL(wod.package_group , '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Handling Code'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.manifest_handling_code, '') <> ISNULL(wod.manifest_handling_code , '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'ERG Number'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ( ISNULL(TSDFApproval.ERG_number, -999) <> ISNULL(wod.ERG_number , -999)
		OR ISNULL(TSDFApproval.ERG_suffix, '') <> ISNULL(wod.ERG_suffix,'') )
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'DOT SP'
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN TSDFApproval ON wod.tsdf_approval_id = TSDFApproval.TSDF_approval_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'F'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(TSDFApproval.manifest_dot_sp_number, '') <> ISNULL(wod.manifest_dot_sp_number, '')

/*** rb 09/13/2013
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Primary Waste Code'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	INNER Join WorkorderWasteCode wowc on wowc.workorder_id = wod.workorder_ID
								and wowc.company_id = wod.company_id
								and wowc.profit_ctr_id = wod.profit_ctr_ID
								and wowc.workorder_sequence_id = wod.sequence_ID
								and wowc.sequence_id = 1
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND ISNULL(Profile.waste_code, '') <> ISNULL(wowc.waste_code, '')
***/

	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Waste Description'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.approval_desc, '') <> ISNULL(wod.description, '')
	
	--INSERT INTO #TripApprovalDiff
	--SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Container Code'
	--FROM WorkorderDetail wod
	--INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	--INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	--INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
	--	AND ProfileQuoteApproval.company_id = wod.profile_company_id
	--	AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	--INNER JOIN WorkorderHeader ON wod.company_id = WorkorderHeader.company_id
	--	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	--	AND wod.workorder_id = WorkorderHeader.workorder_id
	--WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	--AND WorkorderHeader.trip_id = @trip_id
	--AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	--AND WorkorderHeader.company_id = @company_id

	--AND ISNULL(Profile.manifest_container_code, '') <> ISNULL(wod.container_code, '')
	
	--INSERT INTO #TripApprovalDiff
	--SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Unit Weight/Vol.'
	--FROM WorkorderDetail wod
	--INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	--INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	--INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
	--	AND ProfileQuoteApproval.company_id = wod.profile_company_id
	--	AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	--INNER JOIN WorkorderHeader ON wod.company_id = WorkorderHeader.company_id
	--	AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
	--	AND wod.workorder_id = WorkorderHeader.workorder_id
	--INNER JOIN WorkOrderDetailUnit wodu ON wodu.company_id = wod.company_id
	--						AND wodu.profit_ctr_id = wod.profit_ctr_id
	--						AND wodu.workorder_id = wod.workorder_id
	--						AND wodu.sequence_id = wod.sequence_id
	--						AND IsNull(wodu.manifest_flag,'F') = 'T'
	--Join BillUnit on BillUnit.bill_unit_code = wodu.bill_unit_code							
	--WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	--AND WorkorderHeader.trip_id = @trip_id
	--AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	--AND WorkorderHeader.company_id = @company_id

	--AND ISNULL(Profile.manifest_wt_vol_unit, '') <> ISNULL(billUnit.manifest_unit, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'DOT Shipping Name'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.DOT_shipping_name, '') <> ISNULL(wod.DOT_shipping_name, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Handling Instructions'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.manifest_hand_instruct, '') <> ISNULL(wod.manifest_hand_instruct , '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Management Code'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	JOIN Treatment ON ProfileQuoteApproval.treatment_id = Treatment.treatment_id
		AND ProfileQuoteApproval.company_id = Treatment.company_id
		AND ProfileQuoteApproval.profit_ctr_id = Treatment.profit_ctr_id    
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Treatment.management_code, '') <> ISNULL(wod.management_code, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'RQ Flag'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.reportable_quantity_flag, '') <> ISNULL(wod.reportable_quantity_flag, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'RQ Reason'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.RQ_reason, '') <> ISNULL(wod.RQ_reason, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'DOT Haz Mat'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.hazmat, '') <> ISNULL(wod.hazmat, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Haz Class'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.hazmat_class, '') <> ISNULL(wod.hazmat_class, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Sub Haz Class'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.subsidiary_haz_mat_class, '') <> ISNULL(wod.subsidiary_haz_mat_class, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'UN/NA Number'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ( ISNULL(Profile.UN_NA_flag, '') <> ISNULL(wod.UN_NA_flag, '')
		OR ISNULL(Profile.UN_NA_number, -999) <> ISNULL(wod.UN_NA_number, -999) )
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Packing Group'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.package_group, '') <> ISNULL(wod.package_group, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'Handling Code'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.manifest_handling_code, '') <> ISNULL(wod.manifest_handling_code, '')
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'ERG Number'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ( ISNULL(Profile.ERG_number, -999) <> ISNULL(wod.ERG_number, -999)
		OR ISNULL(Profile.ERG_suffix, '') <> ISNULL(wod.ERG_suffix, '') )
	
	INSERT INTO #TripApprovalDiff
	SELECT DISTINCT wod.workorder_ID, WorkorderHeader.trip_sequence_id,	wod.tsdf_approval_code,	'DOT SP'
	FROM WorkorderDetail wod
	INNER JOIN Profile ON wod.profile_id = Profile.profile_id
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
	INNER JOIN ProfileQuoteApproval ON wod.profile_id = ProfileQuoteApproval.profile_id
		AND ProfileQuoteApproval.company_id = wod.profile_company_id
		AND ProfileQuoteApproval.profit_ctr_id = wod.profile_profit_ctr_id
	INNER JOIN WorkorderHeader with (index(idx_trip_id)) ON wod.company_id = WorkorderHeader.company_id
		AND wod.profit_ctr_id = WorkorderHeader.profit_ctr_id
		AND wod.workorder_id = WorkorderHeader.workorder_id
	WHERE ISNULL(TSDF.eq_flag, 'F') = 'T'
	AND WorkorderHeader.trip_id = @trip_id
	AND WorkorderHeader.profit_ctr_ID = @profit_ctr_id
	AND WorkorderHeader.company_id = @company_id
	AND ISNULL(Profile.manifest_dot_sp_number, '') <> ISNULL(wod.manifest_dot_sp_number, '')

	IF @debug = 1
		PRINT 'Before ''The {mismatch_field} does not match the approval'' validation'
	
	INSERT INTO #tripvalidationall	
	SELECT DISTINCT @trip_id,
		#TripApprovalDiff.trip_sequence_id,
		#TripApprovalDiff.workorder_ID,
		#TripApprovalDiff.TSDF_approval_code,
		'W',
		'The ' + mismatch_field + ' does not match the approval',
		@trip_status
	FROM #TripApprovalDiff
END

-- rb 09/10/2012 Lab Pack, Waste Codes and/or Constituents added
IF @next_status = 'A' OR @next_status = 'U' or @next_status = 'C'
BEGIN
	IF @debug = 1
		PRINT 'Before ''Waste Codes added that are not defined on the TSDF Approval'' validation'
	
	INSERT INTO #TripValidationAll
	SELECT DISTINCT @trip_id, woh.trip_sequence_id, wod.workorder_ID, wod.tsdf_approval_code, 'W',
			'Waste Codes added that are not defined on the TSDF Approval', @trip_status
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'F') = 'F'
	INNER JOIN WorkorderHeader woh with (index(idx_trip_id)) ON wod.company_id = woh.company_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.workorder_id = woh.workorder_id
	INNER Join WorkorderWasteCode wowc on wowc.workorder_id = wod.workorder_ID
								and wowc.company_id = wod.company_id
								and wowc.profit_ctr_id = wod.profit_ctr_ID
								and wowc.workorder_sequence_id = wod.sequence_ID
	WHERE woh.trip_id = @trip_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.company_id = @company_id
	AND NOT EXISTS (select 1 from TSDFApprovalWasteCode
			where tsdf_approval_id = wod.tsdf_approval_id
			and waste_code = wowc.waste_code)

	IF @debug = 1
		PRINT 'Before ''Waste Codes added that are not defined on the Profile'' validation'
	
	INSERT INTO #TripValidationAll
	SELECT DISTINCT @trip_id, woh.trip_sequence_id, wod.workorder_ID, wod.tsdf_approval_code, 'W',
			'Waste Codes added that are not defined on the Profile', @trip_status
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'F') = 'T'
	INNER JOIN WorkorderHeader woh with (index(idx_trip_id)) ON wod.company_id = woh.company_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.workorder_id = woh.workorder_id
	INNER Join WorkorderWasteCode wowc on wowc.workorder_id = wod.workorder_ID
								and wowc.company_id = wod.company_id
								and wowc.profit_ctr_id = wod.profit_ctr_ID
								and wowc.workorder_sequence_id = wod.sequence_ID
								and wowc.waste_code <> 'NONE'
	WHERE woh.trip_id = @trip_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.company_id = @company_id
	AND NOT EXISTS (select 1 from ProfileWasteCode
			where profile_id = wod.profile_id
			and waste_code = wowc.waste_code)


	IF @debug = 1
		PRINT 'Before ''Constituents added that are not defined on the TSDF Approval'' validation'
	
	INSERT INTO #TripValidationAll
	SELECT DISTINCT @trip_id, woh.trip_sequence_id, wod.workorder_ID, wod.tsdf_approval_code, 'W',
			'Constituents added that are not defined on the TSDF Approval', @trip_status
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'F') = 'F'
	INNER JOIN WorkorderHeader woh with (index(idx_trip_id)) ON wod.company_id = woh.company_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.workorder_id = woh.workorder_id
	INNER Join WorkorderDetailItem wodi on wodi.workorder_id = wod.workorder_ID
								and wodi.company_id = wod.company_id
								and wodi.profit_ctr_id = wod.profit_ctr_ID
								and wodi.sequence_id = wod.sequence_ID
								and wodi.item_type_ind = 'LP'
								and isnull(wodi.const_id,0) > 0
	WHERE woh.trip_id = @trip_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.company_id = @company_id
	AND NOT EXISTS (select 1 from TSDFApprovalConstituent
			where tsdf_approval_id = wod.tsdf_approval_id
			and const_id = wodi.const_id)

	IF @debug = 1
		PRINT 'Before ''Constituents added that are not defined on the Profile'' validation'
	
	INSERT INTO #TripValidationAll
	SELECT DISTINCT @trip_id, woh.trip_sequence_id, wod.workorder_ID, wod.tsdf_approval_code, 'W',
			'Constituents added that are not defined on the Profile', @trip_status
	FROM WorkorderDetail wod
	INNER JOIN TSDF ON wod.TSDF_code = TSDF.TSDF_code
		and isnull(TSDF.eq_flag,'F') = 'T'
	INNER JOIN WorkorderHeader woh with (index(idx_trip_id)) ON wod.company_id = woh.company_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.workorder_id = woh.workorder_id
	INNER Join WorkorderDetailItem wodi on wodi.workorder_id = wod.workorder_ID
								and wodi.company_id = wod.company_id
								and wodi.profit_ctr_id = wod.profit_ctr_ID
								and wodi.sequence_id = wod.sequence_ID
								and wodi.item_type_ind = 'LP'
								and isnull(wodi.const_id,0) > 0
	WHERE woh.trip_id = @trip_id
	AND woh.profit_ctr_ID = @profit_ctr_id
	AND woh.company_id = @company_id
	AND NOT EXISTS (select 1 from ProfileConstituent
			where profile_id = wod.profile_id
			and const_id = wodi.const_id)
END


-------------------------------------------------------------- 	  
-- Look for stops where data may be missing (sequence IDs)
--------------------------------------------------------------
SELECT trip_id,
	MIN(sequence_id) AS min_sequence_id,
	MAX(sequence_id) AS max_sequence_id,
	trip_sequence_id AS stop
INTO #TempTrip
FROM tripfieldupdates
WHERE trip_id = @trip_id
--AND sequence_id > 0
GROUP BY trip_id, Trip_sequence_id

SELECT @error_count = COUNT(*)
FROM tripfieldupdates a
	JOIN #TempTrip b ON a.trip_id = b.trip_id
WHERE b.stop <> a.trip_sequence_id
AND a.sequence_id BETWEEN b.min_sequence_id AND b.max_sequence_id
AND a.trip_id = @trip_id 
--AND sequence_id > 0
AND @trip_id NOT IN (
	SELECT trip_id FROM TripValidationException)

IF @error_count > 0
BEGIN
	IF @debug = 1
		PRINT 'Before ''Information for this trip may not be complete'' validation'
	
	INSERT INTO #tripvalidationall VALUES (	
		@trip_id,
		0,
		0,
		NULL,
		'E',
		'Information for this trip may not be complete.  Please contact IT Support!',
		@trip_status)
END

/* rb 09/11/2015 With consolidate_containers_flag added, more specific check below
-- rb 07/22/2015 Look for duplicate CCIDs
insert #tripvalidationall
select woh.trip_id,
		woh.trip_sequence_id,
		woh.workorder_ID,
		wod.TSDF_approval_code,
		case when @next_status = 'C' then 'E' else 'W' end,
		'CCID #' + CONVERT(varchar(3),wdc.consolidated_container_id) + ' was also entered for a different approval',
		@trip_status
from WorkOrderHeader woh 
join WorkOrderDetail wod
	on woh.company_id = wod.company_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.workorder_id = wod.workorder_id
	and wod.resource_type = 'D'
	and wod.bill_rate > -2
join WorkOrderDetailCC wdc
	on wod.workorder_id = wdc.workorder_id
	and wod.company_id = wdc.company_id
	and wod.profit_ctr_id = wdc.profit_ctr_id
	and wod.sequence_id = wdc.sequence_id
where woh.trip_id = @trip_id
and woh.workorder_status <> 'V'
and exists (select 1
			from WorkOrderHeader woh2
			join WorkOrderDetail wod2
				on woh2.company_id = wod2.company_id 
				and woh2.profit_ctr_id = wod2.profit_ctr_id
				and woh2.workorder_id = wod2.workorder_id
				and wod2.resource_type = 'D'
				and wod2.bill_rate > -2
				and ISNULL(wod2.profile_id,0) <> ISNULL(wod.profile_id,0)
			join WorkOrderDetailCC wdc2
				on wod2.workorder_id = wdc2.workorder_id
				and wod2.company_id = wdc2.company_id
				and wod2.profit_ctr_id = wdc2.profit_ctr_id
				and wod2.sequence_id = wdc2.sequence_id
				and wdc2.consolidated_container_id = wdc.consolidated_container_id
			where woh2.trip_id = @trip_id
			and woh2.workorder_status <> 'V'
			)
*/

IF @debug = 1
	PRINT 'Before ''No billing unit exists for this approval'' validation'

-- rb 07/22/2015 look for missing bill units
if @next_status in ('U','C')
	
	insert #tripvalidationall
	select woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			case when @next_status = 'C' then 'E' else 'W' end,
			'No billing unit exists for this approval',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join WorkOrderDetail wod
		on woh.company_id = wod.company_id 
		and woh.profit_ctr_id = wod.profit_ctr_id
		and woh.workorder_id = wod.workorder_id
		and wod.resource_type = 'D'
		and wod.bill_rate > -2
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
	and not exists (select 1
					from WorkOrderDetailUnit
					where workorder_id = wod.workorder_id
					and company_id = wod.company_id
					and profit_ctr_id = wod.profit_ctr_ID
					and sequence_id = wod.sequence_ID
					and isnull(billing_flag,'F') = 'T')
	                                                                
IF @debug = 1
	PRINT 'Before ''Profile is configured to allow consolidated waste in containers, but Customer is not'' validation'

--rb 09/11/2015 Look for profiles with consolidate_containers_flag='T', but Customer's flag is 'F'
if @next_status in ('D','A','U','C')

	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			case when @next_status in ('D','C') then 'E' else 'W' end,
			'Profile is configured to allow consolidated waste in containers, but Customer #' + CONVERT(varchar(10),woh.customer_id) + ' is not.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join Customer c
		on woh.customer_ID = c.customer_ID
		and isnull(c.consolidate_containers_flag,'F') <> 'T'
	join WorkOrderDetail wod
		on woh.company_id = wod.company_id 
		and woh.profit_ctr_id = wod.profit_ctr_id
		and woh.workorder_id = wod.workorder_id
		and wod.resource_type = 'D'
		and wod.bill_rate > -2
	join ProfileQuoteApproval pqa
		on wod.profile_id = pqa.profile_id
		and wod.profile_company_id = pqa.company_id
		and wod.profile_profit_ctr_id = pqa.profit_ctr_id
		and isnull(pqa.consolidate_containers_flag,'F') = 'T'
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'

--rb 09/21/2015 Look for incompatible approvals consolidated into same CCID
if @next_status in ('A','U','C')
begin
	IF @debug = 1
		PRINT 'Before ''Incompatible approvals consolidated into same CCID'' validation'

	select wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id, wdc.consolidated_container_id, pqa.profile_id, pqa.consolidate_containers_flag,
	dbo.fn_consolidated_shipping_desc_compare (wod.UN_NA_flag, wod.UN_NA_number, wod.DOT_shipping_name, wod.hazmat_class, wod.subsidiary_haz_mat_class,
											wod.package_group, wod.reportable_quantity_flag, wod.ERG_number, wod.ERG_suffix, pqa.print_dot_sp_flag, wod.manifest_dot_sp_number, wod.hazmat,
											wod.profile_id, wod.description, (select count(*)
																			  from WorkOrderWasteCode wwc
																			  join WasteCode wc
																					on wc.waste_code_uid = wwc.waste_code_uid
																					and wc.waste_code_origin = 'F'
																			 where wwc.workorder_id = wod.workorder_id
																				and wwc.company_id = wod.company_id
																				and wwc.profit_ctr_id = wod.profit_ctr_id
																				and wwc.workorder_sequence_id = wod.sequence_id)) shipping_desc_compare
	into #comp
	from WorkOrderHeader woh
	join WorkOrderDetail wod
		on woh.company_id = wod.company_id 
		and woh.profit_ctr_id = wod.profit_ctr_id
		and woh.workorder_id = wod.workorder_id
		and wod.resource_type = 'D'
		and wod.bill_rate > -2
	join TSDF t
		on wod.TSDF_code = t.TSDF_code
		and isnull(t.eq_flag,'') = 'T'
	join ProfileQuoteApproval pqa
		on wod.profile_id = pqa.profile_id
		and wod.profile_company_id = pqa.company_id
		and wod.profile_profit_ctr_id = pqa.profit_ctr_id
	join WorkOrderDetailCC wdc
		on wod.company_id = wdc.company_id 
		and wod.profit_ctr_id = wdc.profit_ctr_id
		and wod.workorder_id = wdc.workorder_id
		and wod.sequence_ID = wdc.sequence_id
		and isnull(wdc.consolidated_container_id,0) > 0
	where woh.trip_id = @trip_id


	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			case when @next_status = 'C' then 'E' else 'W' end,
			'CCID #' + CONVERT(varchar(10),wdc.consolidated_container_id) + ' contains waste from multiple approvals with incompatible waste streams.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join WorkOrderDetail wod
		on woh.company_id = wod.company_id 
		and woh.profit_ctr_id = wod.profit_ctr_id
		and woh.workorder_id = wod.workorder_id
		and wod.resource_type = 'D'
		and wod.bill_rate > -2
	join TSDF t
		on wod.TSDF_code = t.TSDF_code
		and isnull(t.eq_flag,'') = 'T'
	join ProfileQuoteApproval pqa
		on wod.profile_id = pqa.profile_id
		and wod.profile_company_id = pqa.company_id
		and wod.profile_profit_ctr_id = pqa.profit_ctr_id
	join WorkOrderDetailCC wdc
		on wod.company_id = wdc.company_id 
		and wod.profit_ctr_id = wdc.profit_ctr_id
		and wod.workorder_id = wdc.workorder_id
		and wod.sequence_ID = wdc.sequence_id
		and isnull(wdc.consolidated_container_id,0) > 0
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
	and (exists (select 1 from #comp
				where #comp.consolidated_container_id = wdc.consolidated_container_id
				and (((isnull(pqa.consolidate_containers_flag,'') <> 'T' or isnull(#comp.consolidate_containers_flag,'') <> 'T')
						and #comp.profile_id <> wod.profile_id ) or
					 ((isnull(pqa.consolidate_containers_flag,'') = 'T' and isnull(#comp.consolidate_containers_flag,'') = 'T')
						and #comp.shipping_desc_compare <>
							dbo.fn_consolidated_shipping_desc_compare (wod.UN_NA_flag, wod.UN_NA_number, wod.DOT_shipping_name, wod.hazmat_class, wod.subsidiary_haz_mat_class,
										wod.package_group, wod.reportable_quantity_flag, wod.ERG_number, wod.ERG_suffix, pqa.print_dot_sp_flag, wod.manifest_dot_sp_number, wod.hazmat,
										wod.tsdf_approval_id, wod.description, (select count(*)
                                                                          from WorkOrderWasteCode wwc
																		  join WasteCode wc
																				on wc.waste_code_uid = wwc.waste_code_uid
																				and wc.waste_code_origin = 'F'
																		 where wwc.workorder_id = wod.workorder_id
																			and wwc.company_id = wod.company_id
																			and wwc.profit_ctr_id = wod.profit_ctr_id
																			and wwc.workorder_sequence_id = wod.sequence_id)))
					)
				)
			or
			exists (select 1 from WorkOrderDetailCC wdc2
				join WorkorderDetail wod2
					on wdc2.company_id = wod2.company_id
					and wdc2.profit_ctr_id = wod2.profit_ctr_ID
					and wdc2.workorder_id = wod2.workorder_ID
					and wdc2.sequence_id = wod2.sequence_ID
					and wod2.resource_type = 'D'
					and wod2.bill_rate > -2
				join TSDF t2
					on wod2.TSDF_code = t2.TSDF_code
					and isnull(t2.eq_flag,'') <> 'T'
				join WorkOrderHeader woh2 with (index(idx_trip_id))
					on wod2.company_id = woh2.company_id
					and wod2.profit_ctr_ID = woh2.profit_ctr_ID
					and wod2.workorder_ID = woh2.workorder_ID
					and woh2.workorder_status <> 'V'
					and woh2.trip_id = @trip_id
				where wdc2.consolidated_container_id = wdc.consolidated_container_id
				and wod2.tsdf_approval_id <> isnull(wod.tsdf_approval_id,-999)
			))

	IF @debug = 1
		PRINT 'Before ''CCID contains waste from multiple approvals with incompatible waste streams'' validation'
		
	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			case when @next_status = 'C' then 'E' else 'W' end,
			'CCID #' + CONVERT(varchar(10),wdc.consolidated_container_id) + ' contains waste from multiple approvals with incompatible waste streams.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join WorkOrderDetail wod
		on woh.company_id = wod.company_id 
		and woh.profit_ctr_id = wod.profit_ctr_id
		and woh.workorder_id = wod.workorder_id
		and wod.resource_type = 'D'
		and wod.bill_rate > -2
	join TSDF t
		on wod.TSDF_code = t.TSDF_code
		and isnull(t.eq_flag,'') <> 'T'
	join WorkOrderDetailCC wdc
		on wod.company_id = wdc.company_id 
		and wod.profit_ctr_id = wdc.profit_ctr_id
		and wod.workorder_id = wdc.workorder_id
		and wod.sequence_ID = wdc.sequence_id
		and isnull(wdc.consolidated_container_id,0) > 0
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
	and (exists (select 1 from WorkOrderDetailCC wdc2
				join WorkorderDetail wod2
					on wdc2.company_id = wod2.company_id
					and wdc2.profit_ctr_id = wod2.profit_ctr_ID
					and wdc2.workorder_id = wod2.workorder_ID
					and wdc2.sequence_id = wod2.sequence_ID
					and wod2.resource_type = 'D'
					and wod2.bill_rate > -2
				join TSDF t2
					on wod2.TSDF_code = t2.TSDF_code
					and isnull(t2.eq_flag,'') = 'T'
				join WorkOrderHeader woh2 with (index(idx_trip_id))
					on wod2.company_id = woh2.company_id
					and wod2.profit_ctr_ID = woh2.profit_ctr_ID
					and wod2.workorder_ID = woh2.workorder_ID
					and woh2.workorder_status <> 'V'
					and woh2.trip_id = @trip_id
				where wdc2.consolidated_container_id = wdc.consolidated_container_id
				)
			or
			exists (select 1 from WorkOrderDetailCC wdc2
				join WorkorderDetail wod2
					on wdc2.company_id = wod2.company_id
					and wdc2.profit_ctr_id = wod2.profit_ctr_ID
					and wdc2.workorder_id = wod2.workorder_ID
					and wdc2.sequence_id = wod2.sequence_ID
					and wod2.resource_type = 'D'
					and wod2.bill_rate > -2
				join TSDF t2
					on wod2.TSDF_code = t2.TSDF_code
					and isnull(t2.eq_flag,'') <> 'T'
				join WorkOrderHeader woh2 with (index(idx_trip_id))
					on wod2.company_id = woh2.company_id
					and wod2.profit_ctr_ID = woh2.profit_ctr_ID
					and wod2.workorder_ID = woh2.workorder_ID
					and woh2.workorder_status <> 'V'
					and woh2.trip_id = @trip_id
				where wdc2.consolidated_container_id = wdc.consolidated_container_id
				and wod2.tsdf_approval_id <> isnull(wod.tsdf_approval_id,-999)
			))

end

-- rb 10/09/2015 Prevent 3rd party approvals showing up as blank lines on the MIM
if @next_status = 'D'
begin
	IF @debug = 1
		PRINT 'Before ''Prevent 3rd party approvals showing up as blank lines on the MIM'' validation'
		
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			wd.tsdf_approval_code,
			'E',
			'Because a waste description was not entered on the TSDF Approval, it will display as a blank line on a MIM. Please enter a waste description before attempting to dispatch.',
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkOrderDetail wd
		on wh.workorder_ID = wd.workorder_ID
		and wh.company_id = wd.company_id
		and wh.profit_ctr_ID = wd.profit_ctr_ID
		and wd.resource_type = 'D'
		and wd.bill_rate > -2
	join TSDF t
		on wd.TSDF_code = t.TSDF_code
		and isnull(t.eq_flag,'') <> 'T'
	join TSDFApproval ta
		on wd.TSDF_approval_id = ta.TSDF_approval_id
		and isnull(ltrim(ta.waste_desc),'') = ''
	where wh.trip_id = @trip_id

/*** rb temporary?
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			wd.tsdf_approval_code,
			'E',
			'Because this approval does not have a management code entered, it will not be editable on a MIM. Please enter a management code before attempting to dispatch.',
			@trip_status
	from WorkOrderHeader wh
	join WorkOrderDetail wd
		on wh.workorder_ID = wd.workorder_ID
		and wh.company_id = wd.company_id
		and wh.profit_ctr_ID = wd.profit_ctr_ID
		and wd.resource_type = 'D'
		and wd.bill_rate > -2
		and isnull(ltrim(wd.management_code),'') = ''
	where wh.trip_id = @trip_id
***/
end

--on trip complete only,
--check transporter sign date and actual arrival/departure dates against workorder start/end dates
if @next_status = 'C'
begin
	IF @debug = 1
		PRINT 'Before ''Transporter Sign Date must be greater than or equal to the Work Order Start Date'' validation'
		
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'E',
			'Transporter Sign Date must be greater than or equal to the Work Order Start Date (' + convert(varchar(10),wh.start_date,101) + ')',
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkOrderDetail wd
		on wh.workorder_ID = wd.workorder_ID
		and wh.company_id = wd.company_id
		and wh.profit_ctr_ID = wd.profit_ctr_ID
		and wd.resource_type = 'D'
		and wd.bill_rate > -2
	join WorkOrderTransporter wt
		on wd.workorder_ID = wt.workorder_id
		and wd.company_id = wt.company_id
		and wd.profit_ctr_ID = wt.profit_ctr_id
		and wd.manifest = wt.manifest
		and wt.transporter_sign_date < wh.start_date
	where wh.trip_id = @trip_id

	IF @debug = 1
		PRINT 'Before ''Transporter Sign Date cannot be more than 30 days greater than today''s date'' validation'

	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'E',
			'Transporter Sign Date cannot be more than 30 days greater than today''s date.',
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkOrderDetail wd
		on wh.workorder_ID = wd.workorder_ID
		and wh.company_id = wd.company_id
		and wh.profit_ctr_ID = wd.profit_ctr_ID
		and wd.resource_type = 'D'
		and wd.bill_rate > -2
	join WorkOrderTransporter wt
		on wd.workorder_ID = wt.workorder_id
		and wd.company_id = wt.company_id
		and wd.profit_ctr_ID = wt.profit_ctr_id
		and wd.manifest = wt.manifest
		and datediff(dd,convert(varchar(10),getdate(),101),convert(varchar(10),wt.transporter_sign_date,101)) > 30
	where wh.trip_id = @trip_id

	IF @debug = 1
		PRINT 'Before ''Actual Date of Arrival can not be greater than the Work Order End Date'' validation'
		
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'E',
			'Actual Date of Arrival can not be greater than the Work Order End Date (' + convert(varchar(10),wh.end_date,101) + ')',
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkorderStop ws
		on wh.workorder_ID = ws.workorder_ID
		and wh.company_id = ws.company_id
		and wh.profit_ctr_ID = ws.profit_ctr_ID
		and datediff(dd,wh.end_date,ws.date_act_arrive) > 0
	where wh.trip_id = @trip_id

	IF @debug = 1
		PRINT 'Before ''Actual Date of Departure must be greater than the Work Order Start Date'' validation'
		
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'E',
			'Actual Date of Departure must be greater than the Work Order Start Date (' + convert(varchar(10),wh.start_date,101) + ')',
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkorderStop ws
		on wh.workorder_ID = ws.workorder_ID
		and wh.company_id = ws.company_id
		and wh.profit_ctr_ID = ws.profit_ctr_ID
		and ws.date_act_depart < wh.start_date
	where wh.trip_id = @trip_id

	IF @debug = 1
		PRINT 'Before ''Actual Date of Departure can not be greater than the Work Order End Date'' validation'
	
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'E',
			'Actual Date of Departure can not be greater than the Work Order End Date (' + convert(varchar(10),wh.end_date,101) + ')',
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkorderStop ws
		on wh.workorder_ID = ws.workorder_ID
		and wh.company_id = ws.company_id
		and wh.profit_ctr_ID = ws.profit_ctr_ID
		and datediff(dd,wh.end_date,ws.date_act_depart) > 0
	where wh.trip_id = @trip_id
end

--check for duplicate manifest numbers
if @next_status in ('A','U','C')
begin
	IF @debug = 1
		PRINT 'Before ''Manifest number is duplicated on stop'' validation'

	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'E',
			'Manifest number ' + wd.manifest + ' is duplicated on Stop #' + convert(varchar(10),wh2.trip_sequence_id),
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkOrderDetail wd
		on wd.workorder_ID = wh.workorder_ID
		and wd.company_id = wh.company_id
		and wd.profit_ctr_ID = wh.profit_ctr_ID
		and wd.resource_type = 'D'
		and wd.bill_rate > -2
		and wd.manifest not like 'MANIFEST%'
	join WorkOrderHeader wh2
		on wh2.trip_id = wh.trip_id
		and wh2.workorder_id <> wh.workorder_id
		and wh2.company_id = wh.company_id
		and wh2.profit_ctr_id = wh.profit_ctr_id
		and wh2.workorder_status <> 'V'
	join WorkOrderDetail wd2
		on wd2.workorder_ID = wh2.workorder_ID
		and wd2.company_id = wh2.company_id
		and wd2.profit_ctr_ID = wh2.profit_ctr_ID
		and wd2.resource_type = 'D'
		and wd2.bill_rate > -2
		and wd2.manifest = wd.manifest
	where wh.trip_id = @trip_id
	and wh.workorder_status <> 'V'

	IF @debug = 1
		PRINT 'Before ''Manifest number was already entered for work order'' validation'
		
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'W',
			'Manifest number ' + wd.manifest + ' was already entered for Work Order '
			+ RIGHT('0' + convert(varchar(2),wh2.company_id),2) + '-'
			+ RIGHT('0' + convert(varchar(2),wh2.profit_ctr_ID),2) + '-'
			+ CONVERT(varchar(10),wh2.workorder_id),
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	join WorkOrderDetail wd
		on wd.workorder_ID = wh.workorder_ID
		and wd.company_id = wh.company_id
		and wd.profit_ctr_ID = wh.profit_ctr_ID
		and wd.resource_type = 'D'
		and wd.bill_rate > -2
		and wd.manifest not like 'MANIFEST%'
	join WorkOrderManifest wm
		on wm.manifest = wd.manifest
		and wm.manifest_flag = 'T' 
		and wm.manifest_state = ' H'
		and (wm.workorder_id not in (select workorder_ID from WorkOrderHeader where trip_id = @trip_id)
				or wm.company_id <> wd.company_id or wm.profit_ctr_ID <> wd.profit_ctr_ID)
	join WorkOrderDetail wd2
		on wd2.workorder_ID = wm.workorder_ID
		and wd2.company_id = wm.company_id
		and wd2.profit_ctr_ID = wm.profit_ctr_ID
		and wd2.resource_type = 'D'
		and wd2.bill_rate > -2
	join WorkOrderHeader wh2 with (index(idx_trip_id))
		on wh2.workorder_ID = wd2.workorder_ID
		and wh2.company_id = wd2.company_id
		and wh2.profit_ctr_ID = wd2.profit_ctr_ID
		and wh2.workorder_status <> 'V'
	where wh.trip_id = @trip_id
	and wh.workorder_status <> 'V'
end

IF @debug = 1
	PRINT 'Before ''Billing project has not been selected'' validation'

--check for billing project not set
if @next_status in ('D','A','U','C')
		
	insert #tripvalidationall
	select distinct @trip_id,
			wh.trip_sequence_id,
			wh.workorder_ID,
			null,
			'E',
			'Billing project has not been selected',
			@trip_status
	from WorkOrderHeader wh with (index(idx_trip_id))
	where wh.trip_id = @trip_id
	and wh.workorder_status <> 'V'
	and wh.billing_project_id is null

IF @debug = 1
	PRINT 'Before ''This stop has not been synchronized'' validation'

-- Find trip stops where there is waste to pick up and the stop isn't synchronized
if @next_status in ('A','U','C')
		
	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			null,
			case when @next_status = 'A' OR @next_status = 'U' then 'W' else 'E' end,
			'This stop has not been synchronized',
			@trip_status
    FROM   workorderheader woh with (index(idx_trip_id))
								join workorderdetail wod on woh.company_id = wod.company_id 
										  AND woh.profit_ctr_id = wod.profit_ctr_id 
										  AND woh.workorder_id = wod.workorder_id
										  AND wod.resource_type = 'D'
										  AND IsNull(wod.TSDF_approval_code,'') > ''
								Join workorderstop wos on woh.company_id = wos.company_id 
										  AND woh.profit_ctr_id = wos.profit_ctr_id 
										  AND woh.workorder_id = wos.workorder_id
										  and wos.stop_sequence_id = 1		  
      WHERE  woh.workorder_status <> 'V' 
      AND woh.trip_id = @trip_id  
      AND woh.profit_ctr_ID = @profit_ctr_id
	  AND woh.company_id = @company_id
 	  AND wod.bill_rate <> -2
 	  and wos.waste_flag = 'T'
 	  and ((select SUM(isnull(quantity, 0)) from workorderdetailunit where wod.company_id = workorderdetailunit.company_id 
										  AND wod.profit_ctr_id = workorderdetailunit.profit_ctr_id 
										  AND wod.workorder_id = workorderdetailunit.workorder_id
										  and wod.sequence_ID = workorderdetailunit.sequence_id
										  and wod.bill_unit_code = workorderdetailunit.bill_unit_code) = 0)


IF @debug = 1
	PRINT 'Before ''Container size and/or type are not the same within a CCID'' validation'
	
/*** GEM:56643 - Remove making this an error when completing a trip. Sometimes they manually enter data if a MIM didn't upload a stop
--  EQAI-50915 - Error on Complete
IF @next_status in ('C')
   set @total_stops_syncd = ( select COUNT(*) from WorkOrderHeader 
                         where trip_id = @trip_id and workorder_status <> 'V' 
                         and field_upload_date is not null )
   set @total_stops = (select count(*) from WorkOrderHeader
                         where trip_id = @trip_id and workorder_status <> 'V')
   set @total_stops_not_syncd  = (@total_stops - @total_stops_syncd)
 
 IF @total_stops_not_syncd > 0 AND @total_stops_syncd > 0  
  BEGIN 
    insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			null,
			'E',
			'This stop has not been synchronized. Please have the technician synch their MIM or void this stop, if not needed.',
			--'Please review this trip.  Some stops have not synchronized from the MIM. Either have the technician synchronize their trip or void the stops that are not needed.',
			@trip_status
	from WorkOrderHeader woh 
	where woh.trip_id = @trip_id
	AND  field_upload_date is null
	AND woh.workorder_status <> 'V'
	
  END
***/
  
/* GEM:56643 - Only give the warning when moving beyond Dispatched
  -- EQAI-50915 - Warning on move from Dispatched to Arrived, Arrived to Unloading
IF ( @trip_status = 'D' AND @next_status = 'A' ) OR ( @trip_status = 'A' AND @next_status = 'U' )
*/
if @next_status in ('A','U','C')
begin
   set @total_stops_syncd = ( select COUNT(*) from WorkOrderHeader with (index(idx_trip_id))
                         where trip_id = @trip_id and workorder_status <> 'V' 
                         and field_upload_date is not null )
   set @total_stops = (select count(*) from WorkOrderHeader with (index(idx_trip_id))
                         where trip_id = @trip_id and workorder_status <> 'V')
   set @total_stops_not_syncd  = (@total_stops - @total_stops_syncd)
end
 
 IF @total_stops_not_syncd > 0 AND @total_stops_syncd > 0  
  BEGIN 
    insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			null,
			'W',
			'This stop has not been synchronized. Please have the technician synch their MIM or void this stop, if not needed.',
			--'Please review this trip.  Some stops have not synchronized from the MIM. Either have the technician synchronize their trip or void the stops that are not needed.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	where woh.trip_id = @trip_id
	 AND  field_download_date is not null --GEM:56643 - Only check the upload date if the download date is set...trips can be created without the use a MIM
	 AND  field_upload_date is null
	 AND woh.workorder_status <> 'V'
	
  END
  	
if @next_status in ('C')
	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			'E',
			'CCID #' + CONVERT(varchar(10),wdc.consolidated_container_id) + ' has work order detail lines that have differing container types or container sizes.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join WorkOrderDetail wod
		on woh.company_id = wod.company_id 
		and woh.profit_ctr_id = wod.profit_ctr_id
		and woh.workorder_id = wod.workorder_id
		and wod.resource_type = 'D'
		and wod.bill_rate > -2
	join WorkOrderDetailCC wdc
		on wod.company_id = wdc.company_id 
		and wod.profit_ctr_id = wdc.profit_ctr_id
		and wod.workorder_id = wdc.workorder_id
		and wod.sequence_ID = wdc.sequence_id
		and isnull(wdc.consolidated_container_id,0) > 0
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
	and (exists (select 1 from WorkOrderDetailCC wdc2
				join WorkorderDetail wod2
					on wdc2.company_id = wod2.company_id
					and wdc2.profit_ctr_id = wod2.profit_ctr_ID
					and wdc2.workorder_id = wod2.workorder_ID
					and wdc2.sequence_id = wod2.sequence_ID
					and wod2.resource_type = 'D'
					and wod2.bill_rate > -2
				join WorkOrderHeader woh2 with (index(idx_trip_id))
					on wod2.company_id = woh2.company_id
					and wod2.profit_ctr_ID = woh2.profit_ctr_ID
					and wod2.workorder_ID = woh2.workorder_ID
					and woh2.workorder_status <> 'V'
					and woh2.trip_id = @trip_id
				where wdc2.consolidated_container_id = wdc.consolidated_container_id
				and (wdc2.container_type <> wdc.container_type
				 or wdc2.container_size <> wdc.container_size)
	))

IF @debug = 1
	PRINT 'Before manifest state validation'

if @next_status in ('D')
	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			null,
			'E',
			'The manifest form type is not populated.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join WorkorderManifest wom
		on woh.company_id = wom.company_id 
		and woh.profit_ctr_id = wom.profit_ctr_id
		and woh.workorder_id = wom.workorder_id
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
	and wom.manifest_state IS NULL

if @next_status = 'D'
BEGIN
	IF @debug = 1
		PRINT 'Before error for approval is set up to print on a BOL or Non-Hazardous manifest that contains RCRA Hazardous Waste Codes validation'

	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			'E',
			'Approval is set up to print on a BOL or non-hazardous manifest that contains RCRA Hazardous Waste Codes.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join workorderdetail wod 
		on woh.company_id = wod.company_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id 
		AND woh.workorder_id = wod.workorder_id
		AND wod.resource_type = 'D'
		AND IsNull(wod.TSDF_approval_code,'') > ''
		AND wod.bill_rate > -2
	join WorkorderManifest wom
		on woh.company_id = wom.company_id 
		and woh.profit_ctr_id = wom.profit_ctr_id
		and woh.workorder_id = wom.workorder_id
		and wom.manifest = wod.manifest
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
	and (wom.manifest_flag = 'F' 
		and (exists (select 1 from Profile p where p.profile_id = wod.profile_id and p.RCRA_haz_flag = 'H') 
			OR exists(select 1 from TSDFApproval ta where ta.TSDF_approval_id = wod.TSDF_approval_id and ta.RCRA_haz_flag = 'H'))
	or (wom.manifest_flag = 'T' 
		and ltrim(rtrim(wom.manifest_state)) = 'N'
		and (exists (select 1 from Profile p where p.profile_id = wod.profile_id and p.RCRA_haz_flag = 'H') 
			OR exists(select 1 from TSDFApproval ta where ta.TSDF_approval_id = wod.TSDF_approval_id and ta.RCRA_haz_flag = 'H'))))
END



------------------------------------------------
-- DevOps 16714 - Check for duplicate manifest lines
------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Multiple approvals are assigned to manifest page and line combination'' validation'

INSERT INTO #tripvalidationall	
	SELECT  woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			'Multiple approvals',
			case when @next_status = 'C' then 'E' else 'W' end,
			'Multiple approvals are assigned to manifest ' + wod.manifest + ', page ' + CONVERT(VARCHAR(4), wod.manifest_page_num) + ', line ' + CONVERT(VARCHAR(4), wod.manifest_line) + '.',
             @trip_status
	from workorderdetail wod​
	join workorderheader woh​ with (index(idx_trip_id))
		on woh.company_id = wod.company_id​
		and woh.profit_ctr_ID = wod.profit_ctr_ID​
		and woh.workorder_ID = wod.workorder_ID​
	where woh.trip_id = @trip_id ​
	and woh.company_id = @company_id ​
	and woh.profit_ctr_ID = @profit_ctr_id​
	and wod.resource_type = 'D' ​
	and wod.manifest is not null ​
	--and wod.manifest not like 'MANIFEST_%'​
	and wod.manifest_page_num is not null​
	and wod.manifest_line is not null​
	and woh.workorder_status not in ('V')​
	AND wod.bill_rate <> -2
	group by woh.trip_id, woh.trip_sequence_id, wod.company_id, wod.profit_ctr_id, woh.workorder_id, wod.manifest, wod.manifest_page_num, wod.manifest_line​
	having count(*) > 1​

------------------------------------------------
-- DevOps 16714 - Check for more than one treatment 
-- for all consolidated material within a container
------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Multiple treatments for all consolidated material within a container'' validation'

INSERT INTO #tripvalidationall	
	SELECT  woh.trip_id,
			null, 
			null, 
			'Multiple approvals',
			case when @next_status = 'C' then 'E' else 'W' end,
			'Please review the treatment assigned to the approvals that are in CCID ' + CONVERT(VARCHAR(6), wodc.consolidated_container_id) +
			'. The treatment must be the same for all consolidated material within this container.',
             @trip_status
from workorderheader woh with (nolock, index(idx_trip_id))
join workorderdetailcc wodc (nolock)
	on woh.company_id = wodc.company_id
	and woh.profit_ctr_ID = wodc.profit_ctr_id
	and woh.workorder_ID = wodc.workorder_id
join workorderdetail wod (nolock)
	on wod.company_id = wodc.company_id
	and wod.profit_ctr_ID = wodc.profit_ctr_id
	and wod.workorder_ID = wodc.workorder_id
	and wod.sequence_ID = wodc.sequence_id
join ProfileQuoteApproval pqa (nolock)
	on wod.profile_id = pqa.profile_id
	and wod.profile_company_id = pqa.company_id
	and wod.profile_profit_ctr_id = pqa.profit_ctr_id
where woh.trip_id = @trip_id
	and woh.company_id = @company_id
	and woh.profit_ctr_ID = @profit_ctr_id
group by 
	woh.trip_id,
	wodc.consolidated_container_id, 
	wod.tsdf_code
having 
	count(distinct pqa.treatment_id) > 1
order by 
	wodc.consolidated_container_id, wod.tsdf_code

------------------------------------------------
-- DevOps 18339 - Check for work order detail lines 
-- that have waste codes that do not exist on the profile
------------------------------------------------
IF @debug = 1
	PRINT 'Before ''Work order detail lines that have waste codes that do not exist on the profile/TSDF approval'' validation'

INSERT INTO #tripvalidationall	
	SELECT  woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID, 
			wod.TSDF_approval_code,
			case when @next_status = 'C' then 'E' else 'W' end,
			'Please review the waste codes on work order ' + CAST(woh.workorder_id as varchar(20)) + ', manifest ' + wod.manifest + ', page ' + 
			CONVERT(VARCHAR(4), wod.manifest_page_num) + ', line ' + CONVERT(VARCHAR(4), wod.manifest_line) + '.  This line has waste codes that are not on the profile.',
            @trip_status
from WorkOrderHeader woh with (nolock, index(idx_trip_id))
join WorkOrderDetail wod (nolock)
	on woh.workorder_ID = wod.workorder_ID
	and woh.company_id = wod.company_id
	and woh.profit_ctr_ID = wod.profit_ctr_ID
	and wod.resource_type = 'D'
	and wod.bill_rate > -2
JOIN TSDF t (nolock)
	ON wod.tsdf_code = t.tsdf_code
	AND t.tsdf_status = 'A'
	AND ISNULL(t.eq_flag, 'F') = 'T'
join WorkOrderWasteCode wowc (nolock)
	on wod.company_id = wowc.company_id
	and wod.profit_ctr_ID = wowc.profit_ctr_id
	and wod.workorder_ID = wowc.workorder_id
	and wod.sequence_ID = wowc.workorder_sequence_id
	and wowc.waste_code <> 'NONE'
left outer join ProfileWasteCode pwc (nolock)
	on wod.profile_id = pwc.profile_id
	and wowc.waste_code_uid = pwc.waste_code_uid
where woh.trip_id = @trip_id
	and woh.company_id = @company_id
	and woh.profit_ctr_ID = @profit_ctr_id
	and pwc.waste_code_uid is null
	and woh.workorder_status not in ('V')​
union
	SELECT  woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID, 
			wod.TSDF_approval_code,
			case when @next_status = 'C' then 'E' else 'W' end,
			'Please review the waste codes on work order ' + CAST(woh.workorder_id as varchar(20)) + ', manifest ' + wod.manifest + ', page ' + 
			CONVERT(VARCHAR(4), wod.manifest_page_num) + ', line ' + CONVERT(VARCHAR(4), wod.manifest_line) + '.  This line has waste codes that are not on the TSDF approval.',
            @trip_status
from WorkOrderHeader woh with (nolock, index(idx_trip_id))
join WorkOrderDetail wod (nolock)
	on woh.workorder_ID = wod.workorder_ID
	and woh.company_id = wod.company_id
	and woh.profit_ctr_ID = wod.profit_ctr_ID
	and wod.resource_type = 'D'
	and wod.bill_rate > -2
JOIN TSDF t (nolock)
	ON wod.tsdf_code = t.tsdf_code
	AND t.tsdf_status = 'A'
	AND ISNULL(t.eq_flag, 'F') = 'F'
join WorkOrderWasteCode wowc (nolock)
	on wod.company_id = wowc.company_id
	and wod.profit_ctr_ID = wowc.profit_ctr_id
	and wod.workorder_ID = wowc.workorder_id
	and wod.sequence_ID = wowc.workorder_sequence_id
	and wowc.waste_code <> 'NONE'
left outer join TSDFApprovalWasteCode tawc (nolock)
	on wod.tsdf_approval_id = tawc.tsdf_approval_id
	and wowc.waste_code_uid = tawc.waste_code_uid
where woh.trip_id = @trip_id
	and woh.company_id = @company_id
	and woh.profit_ctr_ID = @profit_ctr_id
	and tawc.waste_code_uid is null
	and woh.workorder_status not in ('V')​

-- MPM - 5/27/2022 - DevOps 30380 - Added warning message to be displayed when the trip is dispatched and any stop line items are hazmat class 7.
if @next_status = 'D'
BEGIN
	IF @debug = 1
		PRINT 'Before warning any stop line items are hazmat class 7'

	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			'W',
			'Radioactive Shipment: 49 CFR 172.203(d) requires additional descriptions for Class 7 proper shipping names. Please ensure that a qualified Class 7 shipper has reviewed this document for compliance prior to shipping. If you have additional questions, please contact the US Ecology rad team at radteam@usecology.com.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join workorderdetail wod 
		on woh.company_id = wod.company_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id 
		AND woh.workorder_id = wod.workorder_id
		AND wod.resource_type = 'D'
		AND IsNull(wod.TSDF_approval_code,'') > ''
		AND wod.bill_rate > -2
		AND wod.hazmat_class = '7'
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
END

-- MPM - 5/27/2022 - DevOps 30380 - Added warning message to be displayed when the trip is dispatched and any stop line items are hazmat class 7.
if @next_status = 'D'
BEGIN
	IF @debug = 1
		PRINT 'Before warning any stop line items are hazmat class 7 and there is no "Class 7 Additional Description" entered'

	insert #tripvalidationall
	select distinct woh.trip_id,
			woh.trip_sequence_id,
			woh.workorder_ID,
			wod.TSDF_approval_code,
			'E',
			'Radioactive Shipment: Please review the approvals on this route as one or more are hazard class 7 and will require a Class 7 Additional Description entered at the time of pick up in order for the manifest and paperwork to be printed.',
			@trip_status
	from WorkOrderHeader woh with (index(idx_trip_id))
	join workorderdetail wod 
		on woh.company_id = wod.company_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id 
		AND woh.workorder_id = wod.workorder_id
		AND wod.resource_type = 'D'
		AND IsNull(wod.TSDF_approval_code,'') > ''
		AND wod.bill_rate > -2
		AND wod.hazmat_class = '7'
		AND IsNull(Ltrim(Rtrim(wod.class_7_additional_desc)), '') = ''
	where woh.trip_id = @trip_id
	and woh.workorder_status <> 'V'
END

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
    ON OBJECT::[dbo].[sp_trip_validate_all] TO [EQAI];


