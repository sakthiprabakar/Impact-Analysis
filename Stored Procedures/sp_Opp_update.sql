
/************************************************************
Procedure    : sp_Opp_update
Database     : PLT_AI*
Created      : Jan 23 2008 - Jonathan Broome
Description  : Inserts or Updates a Opp Record

************************************************************/
Create Procedure sp_Opp_update (
	@Opp_id			int,
	@customer_id			int,
	@contact_id				int,
	@region_id				int,
	@nam_id					int,
	@Opp_name		varchar(50),
	@child_opp_ids			varchar(100),
	@primary_opp_id			int,
	@opp_county	varchar(50),
	@opp_city	varchar(50),
	@opp_state	varchar(50),
	@opp_country	varchar(50),
	@status					char(1),
	@generator_name			varchar(40),
	@proposal_due_date		datetime,
	@date_awarded			datetime,
	@est_start_date			datetime,
	@est_end_date			datetime,
	@actual_start_date		datetime,
	@actual_end_date		datetime,
	@sales_type				char(1),
	@job_type				char(1),
	@service_type			char(1),
	@est_revenue			money,
	@probability			varchar(4),
	@scale_job_size			int,
	@scale_cust_size		int,
	@scale_odds				int,
	@scale_profitability	int,
	@scale_bidders			varchar(50),
	@scale_competency		int,
	@scale_eq_pct			int,
	@loss_reason			varchar(50),
	@loss_comments			varchar(max),
	@comments				varchar(max),
	@responsible_user_code	varchar(20),
	@description			varchar(max),
	@added_by				varchar(10),
	@territory_code			varchar(10)
)
AS
	set nocount on
	declare @OppTrack_id int,
	@sequence_id int
	
	declare @old_primary_id int
	select @old_primary_id = primary_opp_id from Opp where Opp_id = @Opp_id	
	
	
	set @probability = convert(int, replace(replace(@probability, '%', ''), ' ', ''))
	
	if @Opp_id is null
		begin
			exec @Opp_id = sp_sequence_next 'Opp.Opp_id'
			insert Opp (
				Opp_id,
				Opp_name,
				primary_opp_id,
				opp_county,
				opp_city,
				opp_state,
				opp_country,
				status,
				sales_type,
				job_type,
				service_type,
				proposal_due_date,
				date_awarded,
				est_start_date,
				est_end_date,
				est_revenue,
				actual_start_date,
				actual_end_date,
				customer_id,
				contact_id,
				region_id,
				nam_id,
				generator_name,
				description,
				probability,
				scale_job_size,
				scale_cust_size,
				scale_odds,
				scale_profitability,
				scale_bidders,
				scale_competency,
				scale_eq_pct,
				loss_reason,
				loss_comments,
				comments,
				responsible_user_code,
				added_by,
				date_added,
				modified_by,
				date_modified,
				territory_code	
			) values (
				@Opp_id,
				@Opp_name,
				@primary_opp_id,
				@opp_county,
				@opp_city,
				@opp_state,
				@opp_country,				
				@status,
				@sales_type,
				@job_type,
				@service_type,
				@proposal_due_date,
				@date_awarded,
				@est_start_date,
				@est_end_date,
				@est_revenue,
				@actual_start_date,
				@actual_end_date,
				@customer_id,
				@contact_id,
				@region_id,
				@nam_id,
				@generator_name,
				@description,
				@probability,
				@scale_job_size,
				@scale_cust_size,
				@scale_odds,
				@scale_profitability,
				@scale_bidders,
				@scale_competency,
				@scale_eq_pct,
				@loss_reason,
				@loss_comments,
				@comments,
				@responsible_user_code,
				@added_by,
				GETDATE(),
				@added_by,
				GETDATE(),
				@territory_code
			)
			exec @OppTrack_id = sp_sequence_next 'OppTracking.OppTrack_id'
			set @sequence_id = 1
			insert OppTracking (
				Opp_id,
				OppTrack_id,
				sequence_id,
				status,
				description,
				added_by,
				date_added
			) values (
				@Opp_id,
				@OppTrack_id,
				@sequence_id,
				@status,
				null,
				@added_by,
				getdate()
			)
		end
	else
		begin
			update Opp set
				Opp_name       = @Opp_name,
				primary_opp_id			= @primary_opp_id,
				opp_county			   = @opp_county,
				opp_city			   = @opp_city,
				opp_state			   = @opp_state,
				opp_country			   = @opp_country,
				status                 = @status,
				sales_type             = @sales_type,
				job_type               = @job_type,
				service_type           = @service_type,
				proposal_due_date      = @proposal_due_date,
				date_awarded           = @date_awarded,
				est_start_date         = @est_start_date,
				est_end_date           = @est_end_date,
				est_revenue            = @est_revenue,
				actual_start_date      = @actual_start_date,
				actual_end_date        = @actual_end_date,
				customer_id            = @customer_id,
				contact_id             = @contact_id,
				region_id              = @region_id,
				nam_id                 = @nam_id,
				generator_name         = @generator_name,
				description            = @description,
				probability            = @probability,
				scale_job_size         = @scale_job_size,
				scale_cust_size        = @scale_cust_size,
				scale_odds             = @scale_odds,
				scale_profitability    = @scale_profitability,
				scale_bidders          = @scale_bidders,
				scale_competency       = @scale_competency,
				scale_eq_pct           = @scale_eq_pct,
				loss_reason			   = @loss_reason,
				loss_comments		   = @loss_comments,
				comments			   = @comments,
				responsible_user_code  = @responsible_user_code,
				modified_by            = @added_by,
				date_modified			= GETDATE()     ,
				territory_code			= @territory_code
			where
				Opp_id = @Opp_id
			
			exec @OppTrack_id = sp_sequence_next 'OppTracking.OppTrack_id'
			select @sequence_id = isnull(max(sequence_id)+1, 1) from OppTracking where opp_id = @opp_id and OppTrack_id = @OppTrack_id
			insert OppTracking (
				Opp_id,
				OppTrack_id,
				sequence_id,
				status,
				description,
				added_by,
				date_added
			) values (
				@Opp_id,
				@OppTrack_id,
				@sequence_id,
				@status,
				null,
				@added_by,
				getdate()
			)
		end
	
	
	/* set the primary / related opp_ids for this opportunity (if any) */
	declare @tbl_related_opps table (opp_id int)
	
	INSERT @tbl_related_opps
	SELECT row
	FROM   dbo.fn_splitxsvtext(',', 1, @child_opp_ids)
	WHERE  Isnull(row, '') <> ''	
	
	-- clear existing grouped ids
	--update Opp set primary_opp_id = null
	--	where primary_opp_id = @primary_opp_id
		
	--update Opp set primary_opp_id = null
	--	where Opp_id = @primary_opp_id
	
	SET @primary_opp_id = CASE WHEN @primary_opp_id = 0 THEN @Opp_id
		else @primary_opp_id
		end
	
	
	update Opp set primary_opp_id = NULL
		where primary_opp_id = @old_primary_id	
		AND opp_id <> @opp_id

	update Opp set primary_opp_id = @primary_opp_id
		FROM @tbl_related_opps t
		WHERE Opp.Opp_id = t.opp_id
		
	update Opp set primary_opp_id = @primary_opp_id
		where Opp.Opp_id = @Opp_id
		
	--IF (SELECT COUNT(*) FROM @tbl_related_opps) = 0
	--BEGIN
	--	update Opp set primary_opp_id = @Opp_id
	--		where Opp_id = @Opp_id
			
	--	UPDATE Opp set primary_opp_id = NULL
	--		WHERE primary_opp_id = @Opp_id
	--END	
				
	set nocount off

	select @Opp_id as Opp_id	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Opp_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Opp_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Opp_update] TO [EQAI]
    AS [dbo];

