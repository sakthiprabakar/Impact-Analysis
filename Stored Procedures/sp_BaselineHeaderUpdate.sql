CREATE PROCEDURE [dbo].[sp_BaselineHeaderUpdate] 
    @baseline_id int,
    @status char(1),
    @view_on_web char(1),
    @customer_id int,
    @baseline_description varchar(50),
    @start_date datetime,
    @end_date datetime,
    @custom_defined_name_1 varchar(50),
    @custom_defined_name_2 varchar(50),
    @custom_defined_name_3 varchar(50),
    @modified_by varchar(20)
AS 
	SET nocount ON
	UPDATE [dbo].[BaselineHeader] SET[status]=@status,
    		[view_on_web]=@view_on_web,
    		[customer_id]=@customer_id,
    		[baseline_description]=@baseline_description,
    		[start_date]=@start_date,
    		[end_date]=@end_date,
    		[custom_defined_name_1]=@custom_defined_name_1,
    		[custom_defined_name_2]=@custom_defined_name_2,
    		[custom_defined_name_3]=@custom_defined_name_3,
    		[modified_by]=@modified_by,
    		[date_modified]=Getdate()
    		WHERE [baseline_id]=@baseline_id
	
	exec sp_BaselineHeaderSelect @baseline_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderUpdate] TO [EQAI]
    AS [dbo];

