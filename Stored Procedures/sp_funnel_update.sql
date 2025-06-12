
/************************************************************
Procedure    : sp_funnel_update
Database     : PLT_AI*
Created      : Wed Jun 07 13:18:18 EDT 2006 - Jonathan Broome
Description  : Inserts or Updates a Funnel Record

************************************************************/
Create Procedure sp_funnel_update (

	@funnel_id            int,
	@customer_id          int,
	@contact_id           int,
	@project_name         varchar(50),
	@status               char(1),
	@status_date          datetime,
	@job_type             char(1),
	@project_type         varchar(35),
	@generator_name       varchar(40),
	@generator_id         varchar(12),
	@est_revenue          money,
	@probability          int,
	@est_start_date       datetime,
	@est_end_date         datetime,
	@company_list		  varchar(8000),
	@description          text,
	@added_by             varchar(10)

)
AS
	set nocount on
	
	if len(@company_list) > 0
	begin

		declare @intcount int

		create table #1 (copc varchar(5))

		/* Check to see if the number parser table exists, create if necessary */
		SELECT @intCount = COUNT(*) FROM syscolumns c INNER JOIN sysobjects o on o.id = c.id AND o.name = 'tblToolsStringParserCounter' AND c.name = 'ID'
		IF @intCount = 0
		BEGIN
			CREATE TABLE tblToolsStringParserCounter (
				ID	int	)

			DECLARE @i INT
			SELECT  @i = 1

			WHILE (@i <= 8000)
			BEGIN
				INSERT INTO tblToolsStringParserCounter SELECT @i
				SELECT @i = @i + 1
			END
		END

		INSERT INTO #1
		SELECT  ltrim(rtrim(NULLIF(SUBSTRING(',' + @company_list + ',' , ID ,
			CHARINDEX(',' , ',' + @company_list + ',' , ID) - ID) , ''))) AS copc
		FROM tblToolsStringParserCounter
		WHERE ID <= LEN(',' + @company_list + ',') AND SUBSTRING(',' + @company_list + ',' , ID - 1, 1) = ','
		AND CHARINDEX(',' , ',' + @company_list + ',' , ID) - ID > 0
		
	end
	
	if @funnel_id is null
		begin
			exec @funnel_id = sp_sequence_next 'CustomerFunnel.funnel_id'
			insert CustomerFunnel (
				funnel_id,
				customer_id,
				contact_id,
				project_name,
				status,
				job_type,
				project_type,
				generator_name,
				generator_id,
				est_revenue,
				probability,
				est_start_date,
				est_end_date,
				description,
				added_by,
				date_added,
				modified_by,
				date_modified
			) values (
				@funnel_id,
				@customer_id,
				@contact_id,
				@project_name,
				@status,
				@job_type,
				@project_type,
				@generator_name,
				@generator_id,
				@est_revenue,
				@probability,
				@est_start_date,
				@est_end_date,
				@description,
				@added_by,
				getdate(),	
				@added_by,
				getdate()	
			)
			
			insert FunnelDates (
				funnel_id,
				status,
				status_date,
				added_by,
				date_added
			) values (
				@funnel_id,
				@status,
				@status_date,
				@added_by,
				getdate()
			)
				
			if len(@company_list) > 0
				insert FunnelXCompany
				select 
					@funnel_id,
					company_id,
					profit_ctr_id
				from profitcenter 
				inner join #1 on convert(varchar(3), company_id) + '|' + convert(varchar(3), profit_ctr_id) = copc
		end
	else
		begin
			update CustomerFunnel set
				customer_id		 = @customer_id,
				contact_id       = @contact_id,
				project_name     = @project_name,
				status           = @status,
				job_type         = @job_type,
				project_type     = @project_type,
				generator_name   = @generator_name,
				generator_id     = @generator_id,
				est_revenue      = @est_revenue,
				probability      = @probability,
				est_start_date   = @est_start_date,
				est_end_date     = @est_end_date,
				description      = @description,
				modified_by      = @added_by,
				date_modified	 = getdate()
			where
				funnel_id = @funnel_id
			
			insert FunnelDates (
				funnel_id,
				status,
				status_date,
				added_by,
				date_added
			) values (
				@funnel_id,
				@status,
				@status_date,
				@added_by,
				getdate()
			)
			
			delete 
			from FunnelXCompany
			where funnel_id = @funnel_id
			
			if len(@company_list) > 0
				insert FunnelXCompany
				select 
					@funnel_id,
					company_id,
					profit_ctr_id
				from profitcenter 
				inner join #1 on convert(varchar(3), company_id) + '|' + convert(varchar(3), profit_ctr_id) = ltrim(rtrim(copc))
		end
				
	set nocount off

	select @funnel_id as funnel_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_funnel_update] TO [EQAI]
    AS [dbo];

