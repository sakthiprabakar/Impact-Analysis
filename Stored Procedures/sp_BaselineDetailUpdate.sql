
CREATE PROCEDURE [dbo].[sp_BaselineDetailUpdate] 
    @original_baseline_id int,
    @original_category_id int,
    @original_generator_id int,
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
    @modified_by varchar(50)
AS 
	SET NOCOUNT ON 
	UPDATE [dbo].[BaselineDetail]
    SET    [baseline_id] = @baseline_id,
			[baseline_category_id] = @baseline_category_id,
           [generator_id] = @generator_id,
           [status] = @status,
           [reporting_type_id] = @reporting_type_id,
           [quantity] = @quantity,
           [expected_amount] = @expected_amount,
           [bill_unit_code] = @bill_unit_code,
           [pound_conv_override] = @pound_conv_override,
           [time_period] = @time_period,
           [baseline_category_id_custom_1] = @baseline_category_id_custom_1,
           [baseline_category_id_custom_2] = @baseline_category_id_custom_2,
           [baseline_category_id_custom_3] = @baseline_category_id_custom_3,
           [modified_by] = @modified_by,
           [date_modified] = GETDATE()
    WHERE  [baseline_id] = @original_baseline_id
           AND [baseline_category_id] = @original_category_id
           AND [generator_id] = @original_generator_id 
    
	exec sp_BaselineDetailSelect @baseline_id, @baseline_category_id, @generator_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineDetailUpdate] TO [EQAI]
    AS [dbo];

