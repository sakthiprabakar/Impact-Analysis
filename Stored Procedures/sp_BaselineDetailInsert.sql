CREATE PROCEDURE [dbo].[sp_BaselineDetailInsert] 
    @baseline_id int,
    @baseline_category_id int,
    @generator_id int,
    @status char(1),
    @reporting_type_id int,
    @quantity float,
    @expected_amount float,
    @bill_unit_code varchar(4),
    @pound_conv_override float,
    @time_period varchar(50),
    @baseline_category_id_custom_1 int,
    @baseline_category_id_custom_2 int,
    @baseline_category_id_custom_3 int,
    @added_by varchar(50)
AS 
	INSERT INTO [dbo].[BaselineDetail]
				([baseline_id],
				 [baseline_category_id],
				 [generator_id],
				 [status],
				 [reporting_type_id],
				 [quantity],
				 [expected_amount],
				 [bill_unit_code],
				 [pound_conv_override],
				 [time_period],
				 [baseline_category_id_custom_1],
				 [baseline_category_id_custom_2],
				 [baseline_category_id_custom_3],
				 [modified_by],
				 [date_modified],
				 [added_by],
				 [date_added])
	SELECT @baseline_id,
		   @baseline_category_id,
		   @generator_id,
		   @status,
		   @reporting_type_id,
		   @quantity,
		   @expected_amount,
		   @bill_unit_code,
		   @pound_conv_override,
		   @time_period,
		   @baseline_category_id_custom_1,
		   @baseline_category_id_custom_2,
		   @baseline_category_id_custom_3,
		   @added_by,
		   GETDATE(),
		   @added_by,
		   GETDATE()
	
	
	exec sp_BaselineDetailSelect @baseline_id, @baseline_category_id, @generator_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailInsert] TO [EQAI]
    AS [dbo];

