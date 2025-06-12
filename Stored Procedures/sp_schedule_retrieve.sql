SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_schedule_retrieve]
(
	@company_id int,
	@profit_ctr_id int ,
	@load_type char(1),
	@date_from datetime,
	@date_to  datetime,
	@material varchar(10)
)
--WITH RECOMPILE
AS
BEGIN
/***********************************************************************
-- Load this to company databases PLT_XX_AI

11/09/2006 RG	Created
12/26/2006 SCC	Added billing project ID
11/23/2012 DZ	Added company id, moved from plt_xx_ai to plt_ai
11/03/2016 MPM	Added location_control
05/08/2016 MPM	Added in_transit_flag
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
08/05/2020 AM  DevOps:17044 - Adedd set transaction isolation level read uncommitted
02/07/2024 KS  DevOps 78210 - Added schema reference, formatting update, and OPTIMIZE FOR UNKNOWN for better perfromance with parameter sniffing, and removed cursor
04/26/2024 KS  INC1255194 - Removed the while loop and added the cursor back as it was going into an infinite loop.

sp_schedule_retrieve 21, 0, 8, 2, 2006, 0, 'B', 'SHEILA_C'
sp_schedule_retrieve 21, 0, 'B', '12/30/2016 00:00:00', '12/30/2016 23:59:59', 'O-OilWater'
sp_schedule_retrieve 21, 0, 'N', '10/28/2016 00:00:00', '10/28/2016 23:59:59', 'Drum'
***********************************************************************/
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @tsdf_code_func VARCHAR(15)
		,@display_name VARCHAR(10)
		,@generator_id INT
		,@profile_id INT

	DROP TABLE IF EXISTS #hold
		CREATE TABLE #hold (
			confirmation_ID INT NULL
			,time_scheduled DATETIME NULL
			,approval_code VARCHAR(15) NULL
			,material VARCHAR(10) NULL
			,load_type CHAR(1) NULL
			,quantity FLOAT NULL
			,sched_quantity FLOAT NULL
			,special_instructions VARCHAR(20) NULL
			,end_block_time DATETIME NULL
			,STATUS CHAR(1) NULL
			,customer_id INT NULL
			,generator_id INT NULL
			,display_name VARCHAR(10) NULL
			,cust_name VARCHAR(75) NULL
			,generator_name VARCHAR(75) NULL
			,treatment_desc VARCHAR(40) NULL
			,secondary_waste_flag INT NULL
			,comment_flag INT NULL
			,OTS_flag CHAR(1) NULL
			,bill_unit_code VARCHAR(4) NULL
			,group_id INT NULL
			,schedule_type CHAR(1) NULL
			,TSDF_code VARCHAR(15) NULL
			,received_flag CHAR(1) NULL
			,purchase_order VARCHAR(20) NULL
			,profile_id INT NULL
			,group_interval INT NULL
			,billing_project_id INT NULL
			,location_control CHAR(1) NULL
			,in_transit_flag CHAR(1) NULL
			)

	-- initial load
	INSERT #hold
	SELECT Schedule.confirmation_ID
		,Schedule.time_scheduled
		,Schedule.approval_code
		,Schedule.material
		,Schedule.load_type
		,Schedule.quantity
		,Schedule.sched_quantity
		,Schedule.special_instructions
		,Schedule.end_block_time
		,Schedule.[Status]
		,[Profile].customer_id
		,[Profile].generator_id
		,'' display_name
		,Customer.cust_name
		,Generator.generator_name
		,Treatment.treatment_desc
		,0 AS secondary_waste_flag
		,ScheduleComment.confirmation_id AS comment_flag
		,[Profile].OTS_flag
		,Schedule.bill_unit_code
		,Schedule.group_id
		,Schedule.schedule_type
		,Schedule.TSDF_code
		,Schedule.received_flag
		,Schedule.purchase_order
		,Schedule.profile_id
		,Schedule.group_interval
		,Schedule.billing_project_id
		,ProfileQuoteApproval.location_control
		,'F' AS in_transit_flag
	FROM dbo.Schedule
	JOIN dbo.[Profile] 
		ON (Schedule.profile_id = [Profile].profile_id)
		AND ([Profile].curr_status_code = 'A')
	JOIN dbo.ProfileQuoteApproval 
		ON (Schedule.profile_id = ProfileQuoteApproval.profile_id)
		AND (Schedule.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id)
		AND (Schedule.company_id = ProfileQuoteApproval.company_id)
	JOIN dbo.Customer 
		ON ([Profile].customer_id = Customer.customer_id)
	JOIN dbo.Generator 
		ON ([Profile].generator_id = Generator.generator_id)
	JOIN dbo.Treatment 
		ON (ProfileQuoteApproval.treatment_id = Treatment.treatment_id)
		AND (ProfileQuoteApproval.profit_ctr_id = Treatment.profit_ctr_id)
		AND (ProfileQuoteApproval.company_id = Treatment.company_id)
	LEFT OUTER JOIN dbo.ScheduleComment 
		ON (Schedule.confirmation_id = ScheduleComment.confirmation_id)
		AND (Schedule.company_id = ScheduleComment.company_id)
		AND (Schedule.profit_ctr_id = ScheduleComment.profit_ctr_id)
	WHERE (Schedule.profit_ctr_id = @profit_ctr_id)
		AND (Schedule.company_id = @company_id)
		AND (Schedule.load_type = @load_type)
		AND (Schedule.material = @material)
		AND (Schedule.end_block_time IS NULL)
		AND (Schedule.STATUS <> ('V'))
		AND (
			Schedule.time_scheduled BETWEEN @date_from
				AND @date_to
			)
	OPTION (OPTIMIZE FOR UNKNOWN)

	-- now load blocked 
	INSERT #hold
	SELECT Schedule.confirmation_ID
		,Schedule.time_scheduled
		,Schedule.approval_code
		,Schedule.material
		,Schedule.load_type
		,Schedule.quantity
		,Schedule.sched_quantity
		,Schedule.special_instructions
		,Schedule.end_block_time
		,Schedule.[Status]
		,NULL AS customer_id
		,NULL AS generator_id
		,NULL AS display_name
		,NULL AS cust_name
		,NULL AS generator_name
		,NULL AS treatment_desc
		,NULL AS secondary_waste_flag
		,NULL AS comment_flag
		,NULL AS OTS_flag
		,Schedule.bill_unit_code
		,Schedule.group_id
		,Schedule.schedule_type
		,Schedule.TSDF_code
		,Schedule.received_flag
		,Schedule.purchase_order
		,Schedule.profile_id
		,Schedule.group_interval
		,Schedule.billing_project_id
		,ProfileQuoteApproval.location_control
		,'F' AS in_transit_flag
	FROM dbo.Schedule
	LEFT OUTER JOIN dbo.ProfileQuoteApproval 
		ON (Schedule.profile_id = ProfileQuoteApproval.profile_id)
		AND (Schedule.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id)
		AND (Schedule.company_id = ProfileQuoteApproval.company_id)
	WHERE (Schedule.profit_ctr_id = @profit_ctr_id)
		AND (Schedule.company_id = @company_id)
		AND (Schedule.load_type = @load_type)
		AND (Schedule.material = @material)
		AND (Schedule.[Status] <> ('V'))
		AND Schedule.end_block_time IS NOT NULL
		AND (
			(
				@date_from BETWEEN Schedule.time_scheduled
					AND Schedule.end_block_time
				)
			OR (
				Schedule.time_scheduled BETWEEN @date_from
					AND @date_to
				)
			)
	OPTION (OPTIMIZE FOR UNKNOWN)

	-- others
	INSERT #hold
	SELECT Schedule.confirmation_ID
		,Schedule.time_scheduled
		,Schedule.approval_code
		,Schedule.material
		,Schedule.load_type
		,Schedule.quantity
		,Schedule.sched_quantity
		,Schedule.special_instructions
		,Schedule.end_block_time
		,Schedule.[Status]
		,NULL AS customer_id
		,NULL AS generator_id
		,NULL AS display_name
		,Schedule.contact_company AS cust_name
		,NULL AS generator_name
		,NULL AS treatment_desc
		,NULL AS secondary_waste_flag
		,ScheduleComment.confirmation_id AS comment_flag
		,NULL AS comment_flag
		,Schedule.bill_unit_code
		,Schedule.group_id
		,Schedule.schedule_type
		,Schedule.TSDF_code
		,Schedule.received_flag
		,Schedule.purchase_order
		,Schedule.profile_id
		,Schedule.group_interval
		,Schedule.billing_project_id
		,ProfileQuoteApproval.location_control
		,'F' AS in_transit_flag
	FROM dbo.Schedule
	LEFT JOIN dbo.ScheduleComment 
		ON (Schedule.confirmation_id = ScheduleComment.confirmation_id)
		AND (Schedule.company_id = ScheduleComment.company_id)
		AND (Schedule.profit_ctr_id = ScheduleComment.profit_ctr_id)
	LEFT JOIN dbo.ProfileQuoteApproval 
		ON (Schedule.profile_id = ProfileQuoteApproval.profile_id)
		AND (Schedule.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id)
		AND (Schedule.company_id = ProfileQuoteApproval.company_id)
	WHERE Schedule.approval_code = 'VARIOUS'
		AND (Schedule.company_id = @company_id)
		AND (Schedule.profit_ctr_id = @profit_ctr_id)
		AND (Schedule.load_type = @load_type)
		AND (Schedule.material = @material)
		AND (Schedule.end_block_time IS NULL)
		AND (Schedule.[Status] NOT IN ('V'))
		AND (
			Schedule.time_scheduled BETWEEN @date_from
				AND @date_to
			)
	OPTION (OPTIMIZE FOR UNKNOWN)

	CREATE NONCLUSTERED INDEX [idx_Hold_profile_id_generator_id] ON #hold (
		profile_id
		,generator_id
		)

	 BEGIN -- anitha start
		  DECLARE c_schedule cursor FAST_FORWARD 
		  FOR
		  SELECT  profile_id
				, generator_id
		  FROM #hold h
      
		  OPEN c_schedule
		  FETCH c_schedule into @profile_id 
								, @generator_id
    
		  SELECT @tsdf_code_func = tsdf_code
		  FROM TSDF 
		  WHERE tsdf.eq_company = @company_id 
		  AND   tsdf.eq_profit_ctr = @profit_ctr_id
		  AND TSDF.eq_flag = 'T' 
		  AND TSDF.TSDF_status = 'A' 
 
		  WHILE @@FETCH_STATUS = 0
		  BEGIN
				SELECT @display_name = display_name
				FROM dbo.fn_tbl_manifest_waste_codes('Profile',@profile_id , @generator_id, @tsdf_code_func ) 
				WHERE primary_flag = 'T'
          
				UPDATE #hold 
				SET display_name =  @display_name 
				WHERE  @generator_id = generator_id 
				AND  @profile_id = profile_id 

				FETCH c_schedule into @profile_id 
									, @generator_id
		  END
		  CLOSE c_schedule
		  DEALLOCATE c_schedule
	END -- anitha end

	-- now update counts
	UPDATE #hold
	SET secondary_waste_flag = 1
	FROM #hold h
	WHERE EXISTS (
			SELECT 1
			FROM profilewastecode p
			WHERE p.profile_id = h.profile_id
				AND p.primary_flag = 'F'
			)
		AND h.secondary_waste_flag = 0

	UPDATE #hold
	SET in_transit_flag = 'T'
	FROM #hold h
	WHERE EXISTS (
			SELECT 1
			FROM Receipt r
			WHERE r.company_id = @company_id
				AND r.profit_ctr_id = @profit_ctr_id
				AND r.schedule_confirmation_id = h.confirmation_id
				AND r.receipt_status = 'T'
			)

	-- dump table 
	SELECT
		confirmation_ID ,   
		time_scheduled ,
		approval_code ,
		material ,
		load_type ,
		quantity ,
		sched_quantity ,
		special_instructions ,
		end_block_time ,
		status ,
		customer_id ,
		generator_id ,   
		display_name ,
		cust_name ,
		generator_name ,
		treatment_desc ,
		secondary_waste_flag , 
		comment_flag ,
		OTS_flag ,
		bill_unit_code ,
		group_id , 
		schedule_type , 
		TSDF_code ,
		received_flag ,
		purchase_order ,
		profile_id ,
		group_interval ,
		billing_project_id ,
		location_control ,
		in_transit_flag 
	FROM #hold

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_schedule_retrieve] TO [EQAI];

