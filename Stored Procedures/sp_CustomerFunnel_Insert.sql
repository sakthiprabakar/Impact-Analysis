
/***************************************************************************************
Inserts a Funnel Entry

10/08/2003 JPB	Created
Test Cmd Line: sp_CustomerFunnel_Insert 2222, NULL, 'Test Project 3', 'N', 'T', 'E', 'Transfer and Disposal', 'BASF CORPORATION - WYANDOTTE', 'MID064197742', 100.0000, 'LOAD', 10.0000, 'Per Project', 1, 'T', 1000.0000, 60, '10/08/2003', '10/09/2003', 'Description', 'Jonathan', '2_21, 3_1, 12_0, 14_0, 14_1, 14_2, 14_3, 14_4, 14_5, 14_6, 14_7, 14_8, 14_9, 14_10, 14_11, 14_12, 15_1, 15_2'
****************************************************************************************/
create procedure sp_CustomerFunnel_Insert
	@customer_id	int,
	@contact_id		int,
	@project_name	varchar(40),
	@status 		char(1),
	@status_date	datetime,
	@direct_flag 	char(1),
	@job_type 		char(1),
	@project_type 	varchar(35),
	@generator_name	varchar(40),
	@generator_id 	varchar(12),
	@price 			float,
	@bill_unit_code	varchar(10),
	@quantity		float,
	@project_interval	varchar(20),
	@number_of_intervals	float,
	@calc_revenue_flag	char(1),
	@est_revenue	money,
	@probability 	int,
	@est_start_date	datetime,
	@est_end_date	datetime,
	@description	text,
	@added_by		varchar(10),
	@eq_company		varchar(8000)
AS
	declare @intFunnelID	int
	set nocount on
	exec @intFunnelID = sp_sequence_next 'CustomerFunnel.funnel_id'
	set nocount off
	Insert into CustomerFunnel (
		funnel_id,
		customer_id,
		contact_id,
		project_name,
		status,
		direct_flag,
		job_type,
		project_type,
		generator_name,
		generator_id,
		price,
		bill_unit_code,
		quantity,
		project_interval,
		number_of_intervals,
		calc_revenue_flag ,
		est_revenue,
		probability,
		est_start_date,
		est_end_date,
		description,
		added_by,
		date_added,
		modified_by,
		date_modified
		) Values (
		@intFunnelID,
		@customer_id,
		@contact_id,
		@project_name,
		@status,
		@direct_flag,
		@job_type,
		@project_type,
		@generator_name,
		@generator_id,
		@price,
		@bill_unit_code,
		@quantity,
		@project_interval,
		@number_of_intervals,
		@calc_revenue_flag,
		@est_revenue,
		@probability,
		@est_start_date,
		@est_end_date,
		@description,
		@added_by,
		GETDATE(),
		@added_by,
		GETDATE()
	)

	set nocount on

	insert into FunnelDates values (@intFunnelID, @status, @status_date, @added_by, GETDATE())

	declare @separator_position int -- this is used to locate each separator character
	declare @array_value varchar(1000) -- this holds each array value as it is returned
	declare @inner_separator int
	declare @inner_value1 varchar(1000)
	declare @inner_value2 varchar(1000)

	set @eq_company = @eq_company + ','

	while patindex('%' + ',' + '%' , @eq_company) <> 0
	begin

		select @separator_position = patindex('%' + ',' + '%' , @eq_company)
		select @array_value = ltrim(rtrim(left(@eq_company, @separator_position - 1)))

		while charindex('_', @array_value) <> 0
		begin
			select @inner_separator = charindex('_' , @array_value)
			select @inner_value1 = ltrim(rtrim(left(@array_value, @inner_separator - 1)))
			select @inner_value2 = ltrim(rtrim(replace(@array_value, @inner_value1 + '_', '')))

			insert into FunnelXCompany values(@intFunnelID, convert(int, @inner_value1), convert(int, @inner_value2))
			select @array_value = stuff(@array_value, 1, @inner_separator, '')
		end
		select @eq_company = stuff(@eq_company, 1, @separator_position, '')
	end

	set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerFunnel_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerFunnel_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerFunnel_Insert] TO [EQAI]
    AS [dbo];

