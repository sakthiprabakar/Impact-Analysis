CREATE PROCEDURE [dbo].[sp_DashboardResultUpdate] 
    @result_id int,
    @answer varchar(500), -- the result of the metric (i.e. 10 items orders, 99 work orders submitted, etc...)
    @company_id int,
    @compliance_flag char(1),
    @measurement_id int, -- which DashboardMeasurement this is applied to
    @note varchar(500), -- any comments about the data
    @profit_ctr_id int,
    @report_period_end_date datetime, -- the ending date of the dashboard metric
    @threshold_operator varchar(10) = NULL, -- can be any of =,>,<,>=,<=,
    @threshold_value int = null, -- the value to compare against the answer field
    @threshold_pass varchar(50), -- whether the threshold is acceptable or not acceptable
    @modified_by varchar(50) -- who modified the record
/*	
	Description: 
	Updates a DashboardResult row and returns the newly updated record

	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 

		UPDATE [dbo].[DashboardResult]
	SET    
		   [answer] = @answer,
		   [company_id] = @company_id,
		   [compliance_flag] = @compliance_flag,
		   [measurement_id] = @measurement_id,
		   [note] = @note,
		   [profit_ctr_id] = @profit_ctr_id,
		   [report_period_end_date] = @report_period_end_date,
		   threshold_value = @threshold_value,
		   threshold_operator = @threshold_operator,
		   threshold_pass = @threshold_pass,
		   [modified_by] = @modified_by,
		   [date_modified] = getdate()
	WHERE  [result_id] = @result_id 
	
	exec sp_DashboardResultSelect @result_id

	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultUpdate] TO [EQAI]
    AS [dbo];

