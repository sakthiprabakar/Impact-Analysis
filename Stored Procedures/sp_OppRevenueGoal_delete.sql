CREATE PROC [dbo].[sp_OppRevenueGoal_delete] 
	@territory_code varchar(5) = NULL,
    @company_id int = NULL,
    @profit_ctr_id int = NULL,
    @region_id int = null,
    @nam_id int = null,
    @goal_month datetime
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	BEGIN TRAN
	
	IF @territory_code IS NOT NULL
	  BEGIN
		  DELETE FROM [dbo].[OppRevenueGoal]
		  WHERE  [territory_code] = @territory_code
				 AND [goal_month] = @goal_month
	  END

	IF @company_id IS NOT NULL
	  BEGIN
		  DELETE FROM [dbo].[OppRevenueGoal]
		  WHERE  company_id = @company_id
				 AND profit_ctr_id = @profit_ctr_id
				 AND [goal_month] = @goal_month
	  END

	IF @region_id IS NOT NULL
	  BEGIN
		  DELETE FROM [dbo].[OppRevenueGoal]
		  WHERE  region_id = @region_id
				 AND goal_month = @goal_month
	  END

	IF @nam_id IS NOT NULL
	  BEGIN
		  DELETE FROM OppRevenueGoal
		  WHERE  nam_id = @nam_id
				 AND goal_month = @goal_month
	  END 


	COMMIT

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppRevenueGoal_delete] TO [EQAI]
    AS [dbo];

