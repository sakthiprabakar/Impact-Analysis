CREATE PROCEDURE [dbo].[sp_DashboardMeasurementInsert] 
    @compliance_flag char(1), -- T or F on whether this is for regulartory info
    @dashboard_type_id int,
    @description varchar(500), -- name/descriptor
    @display_format varchar(50), -- Numeric or YesNo
    @editable char(1), -- whether the user can edit/modify the records
    @threshold_operator varchar(50), -- >,<,<=,>=,= operators for evaluating acceptable threshold
    @notification_flag char(1), -- whether this measurement is used as a notification measurement (i.e. people will be notified about it)
    @threshold_value varchar(50),-- used with threshold_operator to evaluate the acceptable value of the data
    @threshold_type char(1), -- 'E'rror or 'I'nformational
    @sort_order varchar(10), -- not used
    @source varchar(50), -- manual or system generated 
    @status char(1), -- [A]ctive or [I]nactive
    @tier_id int, -- tier: 1 = corporate, 2 = co/pc
    @category_id_list varchar(2000), -- category_id csv of associated categories
    @notification_user_list varchar(2000), -- user_id list csv of associated notification users
    @profit_center_list varchar(2000), -- co|pc csv list of associated profit centers (if applicable)
    @time_period varchar(50), -- Daily, Weekliy, Monthly, Yearly - this represents what time period is being reported on
    @source_stored_procedure varchar(100), -- for System generated metrics, the stored PROCEDURE that will fill in the DashboardResult data
    @source_stored_procedure_type varchar(100), -- StandardStartEnd = format of @measurement_id, @start_date, @end_date, TotalCount = @measurement_id, @until_date
												-- these procs are programmatically invoked, and this determines what parameteres will be passed in
												-- if a new set of parameters is created, a new source_stored_procedure_type will also be created
												-- this is used in the Threshold Notifier application
	@copc_waste_receipt_flag char(1), -- used in UI only
	@copc_workorder_flag char(1),    -- used in UI only
	@copc_all_flag char(1),  -- if set, there will be NO record in the associated DashboardMeasurementProfitCenter but this denotes this measurement is associated to ALL co/pc
    @added_by varchar(50) -- who changed this record
AS 
	
	declare @tblCategories table (category_id int)
	INSERT @tblCategories 
		select convert(int, row) 
		from dbo.fn_SplitXsvText(',', 0, @category_id_list) 
		where isnull(row, '') <> ''		
		
	declare @tblNotificationUsers table ([user_id] int)
	INSERT @tblNotificationUsers 
		select convert(int, row) 
		from dbo.fn_SplitXsvText(',', 0, @notification_user_list) 
		where isnull(row, '') <> ''	
		
	declare @tblProfitCenters table ([company_id] int, profit_ctr_id int)
	INSERT @tblProfitCenters 
		SELECT 
			RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @profit_center_list) 
		where isnull(row, '') <> ''							
	
	INSERT INTO [dbo].[DashboardMeasurement]
           ([compliance_flag],
            [dashboard_type_id],
            [description],
            [display_format],
            [editable],
            [threshold_operator],
            [notification_flag],
            [threshold_value],
            [threshold_type],
            [sort_order],
            [source],
            [status],
            [tier_id],
            [time_period], 
            source_stored_procedure,
            source_stored_procedure_type,
            copc_waste_receipt_flag,
            copc_workorder_flag,
            copc_all_flag,
            added_by, 
            date_added, 
            modified_by, 
            date_modified)
            
			SELECT 
				   @compliance_flag,
				   @dashboard_type_id,
				   @description,
				   @display_format,
				   @editable,
				   @threshold_operator,
				   @notification_flag,
				   @threshold_value,
				   @threshold_type,
				   @sort_order,
				   @source,
				   @status,
				   @tier_id,
				   @time_period,
				   @source_stored_procedure,
				   @source_stored_procedure_type,
				   @copc_waste_receipt_flag,
				   @copc_workorder_flag,
				   @copc_all_flag,
				   @added_by, getdate(), @added_by, getdate()

	declare @id int
	set @id = scope_identity()
	
	
	-- insert categories
INSERT INTO DashboardCategoryXMeasurement (category_id, measurement_id, date_added, added_by)
	SELECT DISTINCT category_id, @id, getdate(), @added_by FROM @tblCategories
	
	-- insert notification users
	INSERT INTO DashboardMeasurementNotification (
		[user_id], 
		measurement_id, 
		date_modified, 
		modified_by)
	SELECT DISTINCT [user_id], @id, getdate(), @added_by FROM @tblNotificationUsers

	-- insert profit centers
	INSERT INTO DashboardMeasurementProfitCenter (
		measurement_id, 
		company_id,
		profit_ctr_id,
		date_modified, 
		modified_by)
	SELECT DISTINCT 
		@id, 
		company_id, 
		profit_ctr_id, 
		getdate(), 
		@added_by 
	FROM @tblProfitCenters	
		
	
	-- get latest copy of the object
	exec sp_DashboardMeasurementSelect @id
               
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementInsert] TO [EQAI]
    AS [dbo];

