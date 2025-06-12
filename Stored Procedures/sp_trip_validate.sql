CREATE PROCEDURE sp_trip_validate (
	@trip_id    int,
	@profit_ctr_id int,
	@company_id int )
AS
BEGIN
-------------------------------------------------------------------------------
--  This procedure validated several aspects of a trip for a validation report
--  Loads to PLT_AI

--  08/17/2009 KAM Created
-- 09/02/2009 KAM  Added validation for manifest on voided row
-- 11/03/2009 KAM  Added Ppounds to the report
-- 11/11/2009 KAM   Added a check to not include void workorders
-- 11/11/2009 KAM  Removed Voided workorder lines Lines fron the report
-- 01/06/2011 KAM  Updated to use the new tables for workorderdetailunit and workorderstop
-- 01/06/2011 KAM  Updated to include voids if the QTY > 0
-- 06/19/2014 AM   Added profit_ctr and company id
-- 07/09/2014 AM   Bad sequence_id join. 
-- 07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

-- sp_trip_validate 1282
-------------------------------------------------------------------------------
Create Table #tripvalidation (
	trip_description	varchar(255) Null,
	trip_sequence_id	int	Null,
	company_id	int	NULL,
	profit_ctr_id	int	null,
	workorder_id	int	null,
	cust_name	varchar(75) NULL,
	cust_id	int	NULL,
	generator_id	int	NULL,
	generator_name	varchar(75) NULL,
	DOT_shipping_name	varchar(255) null,
	TSDF_code	varchar(15) NULL,
	TSDF_approval_code varchar(40) NULL,
	manifest	varchar(15) NULL,
	container_count float NULL,
	manifest_quantity float NULL,
	manifest_page_num	int NULL,
	manifest_line_id	int	null,
	bill_rate	int	null,
	TSDF_Name	varchar(40) NULL,
	trip_actual_arrive	datetime	NULL,
	approval_desc	varchar(50) NULL,
	sequence_id	int	NULL,
	waste_flag	char(1) NULL,
	consolidated_pickup_flag	char(1) NULL,
	cons_cont int	NULL,
	issues varchar(4000) Null,
	trip_status varchar(10) NULL,
	pounds float NULL)


Insert Into #tripvalidation 
 SELECT TripHeader.trip_desc,   
         WorkorderHeader.trip_sequence_id,   
         WorkorderDetail.company_id,   
         WorkorderDetail.profit_ctr_ID,   
         WorkorderDetail.workorder_ID,   
         Customer.cust_name,   
         Customer.customer_ID,   
         Generator.generator_id,   
         Generator.generator_name,   
         WorkorderDetail.DOT_shipping_name,   
         WorkorderDetail.TSDF_code,   
         WorkorderDetail.TSDF_approval_code,   
         WorkorderDetail.manifest,   
         WorkorderDetail.container_count,   
         wdu1.quantity,
         WorkorderDetail.manifest_page_num,
         WorkorderDetail.manifest_line,
         WorkorderDetail.bill_rate,
         TSDF.TSDF_name,   
         WorkorderStop.date_act_arrive,   
         Profile.approval_desc,   
         WorkorderDetail.sequence_ID,   
         WorkorderStop.waste_flag,   
         WorkorderHeader.consolidated_pickup_flag,
			(Select Count(*) from WorkorderDetailCC where workorderdetail.company_id = workorderdetailcc.company_id and
			  																workorderdetail.profit_ctr_id = workorderdetailcc.profit_ctr_id and
																			workorderdetail.workorder_id = workorderdetailcc.workorder_id and
																			workorderdetail.sequence_id = workorderdetailcc.sequence_id) as 'cons_cont',
			'',
			tripHeader.trip_status,
			wdu2.quantity
    FROM TripHeader join WorkorderHeader on WorkorderHeader.trip_id = TripHeader.trip_id    
         join WorkorderDetail on WorkorderDetail.workorder_ID = WorkorderHeader.workorder_ID  and  
         								WorkorderDetail.company_id = WorkorderHeader.company_id  and  
         								WorkorderDetail.profit_ctr_ID = WorkorderHeader.profit_ctr_ID    
   		join Customer on WorkorderHeader.customer_ID = Customer.customer_ID
        join TSDF on WorkorderDetail.TSDF_code = TSDF.TSDF_code 
		join Generator on WorkorderHeader.generator_id = Generator.generator_id 
        join Profile on WorkorderDetail.profile_id = Profile.profile_id
        Left outer Join WorkorderStop on Workorderheader.workorder_ID = WorkorderStop.workorder_ID  and  
         								Workorderheader.company_id = WorkorderStop.company_id  and  
         								Workorderheader.profit_ctr_ID = WorkorderStop.profit_ctr_ID and
         								WorkorderStop.stop_sequence_id = 1
         Left Outer Join Workorderdetailunit wdu1 on WorkorderDetail.workorder_ID = wdu1.workorder_ID  and  
         								WorkorderDetail.company_id = wdu1.company_id  and  
         								WorkorderDetail.profit_ctr_ID = wdu1.profit_ctr_ID 	and
         								WorkorderDetail.sequence_id = wdu1.sequence_id and
         								wdu1.manifest_flag = 'T'
         Left Outer Join Workorderdetailunit wdu2 on WorkorderDetail.workorder_ID = wdu2.workorder_ID  and  
         								WorkorderDetail.company_id = wdu2.company_id  and  
         								WorkorderDetail.profit_ctr_ID = wdu2.profit_ctr_ID 	and
         								WorkorderDetail.sequence_id = wdu2.sequence_id and
         								wdu2.bill_unit_code = 'LBS'         															 
   WHERE  TripHeader.trip_id = @trip_id 
            AND TripHeader.profit_ctr_id = @profit_ctr_id
            AND TripHeader.company_id = @company_id
			AND IsNull(TSDF.EQ_FLAG,'F') = 'T'
			AND workorderheader.workorder_status <> 'V' 
			AND (WorkorderDetail.bill_rate > -2  or
				 (WorkorderDetail.bill_rate = -2 and (Select SUM(quantity) from workorderdetailunit where
														company_id = WorkorderDetail.company_id and
														profit_ctr_id = WorkorderDetail.profit_ctr_ID and
														workorder_id = WorkorderDetail.workorder_ID and 
														sequence_id = WorkorderDetail.sequence_id and
														billing_flag = 'T') > 0))
Union
 SELECT TripHeader.trip_desc,   
         WorkorderHeader.trip_sequence_id,   
         WorkorderDetail.company_id,   
         WorkorderDetail.profit_ctr_ID,   
         WorkorderDetail.workorder_ID,   
         Customer.cust_name,   
         Customer.customer_ID,   
         Generator.generator_id,   
         Generator.generator_name,   
         WorkorderDetail.DOT_shipping_name,   
         WorkorderDetail.TSDF_code,   
         WorkorderDetail.TSDF_approval_code,   
         WorkorderDetail.manifest,   
         WorkorderDetail.container_count,   
         wdu1.quantity,
         WorkorderDetail.manifest_page_num,
         WorkorderDetail.manifest_line,
         WorkorderDetail.bill_rate,
         TSDF.TSDF_name,   
         Workorderstop.date_act_arrive,   
         TSDFApproval.Waste_desc,   
         WorkorderDetail.sequence_ID,   
         Workorderstop.waste_flag,   
         WorkorderHeader.consolidated_pickup_flag,
			(Select Count(*) from WorkorderDetailCC where workorderdetail.company_id = workorderdetailcc.company_id and
			  																workorderdetail.profit_ctr_id = workorderdetailcc.profit_ctr_id and
																			workorderdetail.workorder_id = workorderdetailcc.workorder_id and
																			workorderdetail.sequence_id = workorderdetailcc.sequence_id) as 'cons_cont',
			'',
			tripHeader.trip_status,
			wdu2.quantity
    FROM TripHeader join WorkorderHeader on WorkorderHeader.trip_id = TripHeader.trip_id    
         join WorkorderDetail on WorkorderDetail.workorder_ID = WorkorderHeader.workorder_ID  and  
         								WorkorderDetail.company_id = WorkorderHeader.company_id  and  
         								WorkorderDetail.profit_ctr_ID = WorkorderHeader.profit_ctr_ID    
   		join Customer on WorkorderHeader.customer_ID = Customer.customer_ID
        join TSDF on WorkorderDetail.TSDF_code = TSDF.TSDF_code 
		join Generator on WorkorderHeader.generator_id = Generator.generator_id 
        join TSDFApproval on WorkorderDetail.TSDF_APPROVAL_ID = TSDFApproval.TSDF_APPROVAL_ID
        Left outer Join WorkorderStop on Workorderheader.workorder_ID = WorkorderStop.workorder_ID  and  
         								Workorderheader.company_id = WorkorderStop.company_id  and  
         								Workorderheader.profit_ctr_ID = WorkorderStop.profit_ctr_ID and
         								WorkorderStop.stop_sequence_id = 1
         Left Outer Join Workorderdetailunit wdu1 on WorkorderDetail.workorder_ID = wdu1.workorder_ID  and  
         								WorkorderDetail.company_id = wdu1.company_id  and  
         								WorkorderDetail.profit_ctr_ID = wdu1.profit_ctr_ID 	and
         								WorkorderDetail.sequence_id = wdu1.sequence_id and
         								wdu1.manifest_flag = 'T'
         Left Outer Join Workorderdetailunit wdu2 on WorkorderDetail.workorder_ID = wdu2.workorder_ID  and  
         								WorkorderDetail.company_id = wdu2.company_id  and  
         								WorkorderDetail.profit_ctr_ID = wdu2.profit_ctr_ID 	and
         								WorkorderDetail.sequence_id = wdu2.sequence_id and
         								wdu2.bill_unit_code = 'LBS'        
   WHERE  TripHeader.trip_id = @trip_id 
            AND TripHeader.profit_ctr_id = @profit_ctr_id
            AND TripHeader.company_id = @company_id
			AND IsNull(TSDF.EQ_FLAG,'F') = 'F'
			AND workorderheader.workorder_status <> 'V' 
			AND (WorkorderDetail.bill_rate > -2  or
				 (WorkorderDetail.bill_rate = -2 and (Select SUM(quantity) from workorderdetailunit where
														company_id = WorkorderDetail.company_id and
														profit_ctr_id = WorkorderDetail.profit_ctr_ID and
														workorder_id = WorkorderDetail.workorder_ID and 
														sequence_id = WorkorderDetail.sequence_id and
														billing_flag = 'T') > 0)) 

--  make sure that we have real manifests
Update #tripvalidation 
set issues =issues + '  Missing Manifest Number,' 
where Left(manifest,3) = 'MAN' and (ISNULL(container_count,0) <> 0 or 
IsNull(manifest_quantity,0) <> 0) and bill_rate <> -2

--  Validate the container counts
Update #tripvalidation 
set issues = issues + '  Missing QTY,' 
	where (IsNull(manifest_quantity,0) = 0 and IsNull(container_count,0) > 0) or 
			(IsNull(manifest_quantity,0) > 0 and IsNull(container_count,0) = 0)

-- Check for voided rows
Update #tripvalidation 
set issues = issues + '  Qtys on Voided Row,' 
	where (IsNull(manifest_quantity,0) > 0 or IsNull(container_count,0) > 0) and
			bill_rate = -2

-- Check for consolidtions without qtys
Update #tripvalidation 
set issues = issues + '  No Qty on Consolidated,' 
	where (IsNull(manifest_quantity,0) = 0 and IsNull(container_count,0) = 0) and
			cons_cont > 0

-- Check for waste on no waste pickup
Update #tripvalidation 
set issues = issues + '  Waste on No Waste Stop,' 
	where (IsNull(manifest_quantity,0) > 0 or IsNull(container_count,0) > 0) and
			waste_flag <> 'T'

-- Check for manifest Info on voided row
Update #tripvalidation 
set issues = issues + '  Manifest Info on Void,' 
	where (IsNull(manifest_page_num,0) > 0 or IsNull(manifest_line_id,0) > 0) and
			bill_rate = -2


-- return result set

Select 	trip_description,
	trip_sequence_id,
	company_id,
	profit_ctr_id,
	workorder_id,
	cust_name,
	cust_id,
	generator_id,
	generator_name,
	DOT_shipping_name,
	TSDF_code,
	TSDF_approval_code,
	manifest,
	container_count,
	manifest_quantity,
	manifest_page_num,
	manifest_line_id,
	bill_rate,
	TSDF_Name,
	trip_actual_arrive,
	approval_desc,
	sequence_id,
	waste_flag,
	consolidated_pickup_flag,
	cons_cont,
	issues,
	trip_status,
	pounds
From #Tripvalidation

End

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_validate] TO [EQAI]
    AS [dbo];

