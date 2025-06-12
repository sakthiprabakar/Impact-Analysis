CREATE PROCEDURE [dbo].[sp_DashboardResultInsert] 
    @answer varchar(500), -- the metric number being measured
    @company_id int,
    @compliance_flag char(1),
    @measurement_id int, -- the DashboardMeasurement.measurement_id associated with the answer
    @note varchar(500), -- any misc. notes applicable
    @profit_ctr_id int,
    @report_period_end_date datetime, 
    @threshold_operator varchar(10) = NULL, -- can be >,<,>=,<=,
    @threshold_value int = null,  -- the value to compare against answer 
    @threshold_pass varchar(50) = null, -- whether the answer is acceptable or not
    @added_by varchar(50)
	
/*	
	Description: 
	Creates a new DashboardResult record.

	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 
	
	INSERT INTO [dbo].[DashboardResult]
			   ([added_by],
				[answer],
				[company_id],
				[compliance_flag],
				[date_added],
				[date_modified],
				[measurement_id],
				[modified_by],
				[note],
				[profit_ctr_id],
				[report_period_end_date],
				threshold_operator,
				threshold_value,
				threshold_pass
				)
	SELECT @added_by,
		   @answer,
		   @company_id,
		   @compliance_flag,
		   getdate(),
		   getdate(),
		   @measurement_id,
		   @added_by,
		   @note,
		   @profit_ctr_id,
		   @report_period_end_date ,
		   @threshold_operator,
		   @threshold_value,
		   @threshold_pass	   
	
	declare @result_id int
	set @result_id = scope_identity()
	exec sp_DashboardResultSelect @result_id
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultInsert] TO [EQAI]
    AS [dbo];

