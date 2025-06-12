CREATE PROC [dbo].[sp_OppRevenueGoal_update] 
    @territory_code varchar(5) = NULL,
    @company_id int = NULL,
    @profit_ctr_id int = NULL,
    @region_id int = NULL,
    @nam_id int = NULL,
    @goal_month datetime,
    @goal_amount float,
    @goal_type varchar(10),
    @modified_by varchar(10)
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	BEGIN TRAN
	
	declare @found_existing int
	
	if @territory_code IS NOT NULL
	begin
	select @found_existing = COUNT(*) FROM OppRevenueGoal og
		where og.territory_code = @territory_code
		and og.goal_month = @goal_month
	end
	
	if @company_id IS NOT NULL
	begin
		select @found_existing = COUNT(*) FROM OppRevenueGoal og
		where og.company_id = @company_id
		and og.profit_ctr_id = @profit_ctr_id
		and og.goal_month = @goal_month	
	end
	
	if @region_id is not null
	begin
		select @found_existing = COUNT(*) FROM OppRevenueGoal og
		where og.region_id = @region_id
		and og.goal_month = @goal_month		
	end
	
	if @nam_id is not null
	begin
		select @found_existing = COUNT(*) FROM OppRevenueGoal og
		where og.nam_id = @nam_id
		and og.goal_month = @goal_month		
	end
	
	if @goal_type = 'corporate'
	begin
		select @found_existing = COUNT(*) FROM OppRevenueGoal og
		where og.goal_type = 'corporate'
		and og.goal_month = @goal_month			
	end
	
	
	
		
	if @found_existing = 0
	begin
		INSERT INTO [dbo].[OppRevenueGoal]
            ([territory_code],
            company_id,
            profit_ctr_id,
            region_id,
            nam_id,
             [goal_month],
             [goal_amount],
             [goal_type],
             [added_by],
             [date_added],
             [modified_by],
             [date_modified])	
		SELECT @territory_code
			   ,@company_id
			   ,@profit_ctr_id
			   ,@region_id
			   ,@nam_id
			   ,@goal_month
			   ,@goal_amount
			   ,@goal_type
			   ,@modified_by
			   ,GETDATE()
			   ,@modified_by
			   ,GETDATE() 

        
                 
	end 
	else
	begin
	
		IF @territory_code IS NOT NULL
          BEGIN
              UPDATE [dbo].[OppRevenueGoal]
              SET    [territory_code] = @territory_code,
                     [region_id] = @region_id,
                     [company_id] = @company_id,
                     [profit_ctr_id] = @profit_ctr_id,
                     [nam_id] = @nam_id,
                     goal_type = @goal_type,
                     [goal_month] = @goal_month,
                     [goal_amount] = @goal_amount,
                     [modified_by] = @modified_by,
                     [date_modified] = getdate()
              WHERE  [territory_code] = @territory_code
                     AND [goal_month] = @goal_month
          END
        
        IF @company_id IS NOT NULL
          BEGIN
              UPDATE [dbo].[OppRevenueGoal]
              SET    [territory_code] = @territory_code,
                     [region_id] = @region_id,
                     [company_id] = @company_id,
                     [profit_ctr_id] = @profit_ctr_id,
                     [nam_id] = @nam_id,
                     goal_type = @goal_type,
                     [goal_month] = @goal_month,
                     [goal_amount] = @goal_amount,
                     [modified_by] = @modified_by,
                     [date_modified] = getdate()
              WHERE  company_id = @company_id
                     AND profit_ctr_id = @profit_ctr_id
                     AND [goal_month] = @goal_month
          END
        
        IF @region_id IS NOT NULL
          BEGIN
              UPDATE [dbo].[OppRevenueGoal]
              SET    [territory_code] = @territory_code,
                     [region_id] = @region_id,
                     [company_id] = @company_id,
                     [profit_ctr_id] = @profit_ctr_id,
                     [nam_id] = @nam_id,
                     goal_type = @goal_type,
                     [goal_month] = @goal_month,
                     [goal_amount] = @goal_amount,
                     [modified_by] = @modified_by,
                     [date_modified] = getdate()
              WHERE  region_id = @region_id
                     AND goal_month = @goal_month
          END
        
			IF @nam_id IS NOT NULL
			BEGIN
				UPDATE [dbo].[OppRevenueGoal]
				SET    [territory_code] = @territory_code,
				 [region_id] = @region_id,
				 [company_id] = @company_id,
				 [profit_ctr_id] = @profit_ctr_id,
				 [nam_id] = @nam_id,
				 goal_type = @goal_type,
				 [goal_month] = @goal_month,
				 [goal_amount] = @goal_amount,
				 [modified_by] = @modified_by,
				 [date_modified] = getdate()
				WHERE  nam_id = @nam_id
				 AND goal_month = @goal_month
			END 
          
		IF @goal_type = 'corporate'
		  BEGIN
			 UPDATE [dbo].[OppRevenueGoal]
				SET    [territory_code] = @territory_code,
				 [region_id] = @region_id,
				 [company_id] = @company_id,
				 [profit_ctr_id] = @profit_ctr_id,
				 [nam_id] = @nam_id,
				 goal_type = @goal_type,
				 [goal_month] = @goal_month,
				 [goal_amount] = @goal_amount,
				 [modified_by] = @modified_by,
				 [date_modified] = getdate()
			  FROM   OppRevenueGoal og
			  WHERE  og.goal_type = 'corporate'
					 AND og.goal_month = @goal_month
		  END 
	    
        	
		
		
	
	end
	
	

	
	exec sp_OppRevenueGoal_select @territory_code, @company_id, @profit_ctr_id, @region_id, @nam_id, @goal_type, @goal_month

	COMMIT TRAN

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_update] TO [EQAI]
    AS [dbo];

