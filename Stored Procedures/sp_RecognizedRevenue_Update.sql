
create proc sp_RecognizedRevenue_Update as
/* **************************************************************************
sp_RecognizedRevenue_Update

	Updates the contents of the RecgonizedRevenue table.
	Tracks the dates of population for the contents.
	Gets called from a SQL Agent Job nightly (well, 4am ish)
	
History:
	03/31/2015	JPB	Created
	04/01/2015	JPB	Hey, let's add an AS_OF date to the Meta table.
	
Sample:
	sp_RecognizedRevenue_Update

The meta table:

	CREATE TABLE RecognizedRevenueMeta (
		recognizedrevenue_datarun_uid	int	not null identity(1,1),
		date_added						datetime,
		start_date						datetime,
		end_date						datetime,
		status							char(1),
		run_duration					int,
		as_of_date						datetime
	)
	create index idx_default on RecognizedRevenueMeta (start_date, end_date, status)
	grant insert, update, select, delete on RecognizedRevenueMeta to eqai, eqweb

	SELECT * FROM RecognizedRevenueMeta
	
************************************************************************** */


	-- select top 100 * from RecognizedRevenue

	if object_id('tempdb..#RevenueWork') is not null
		drop table #RevenueWork

	CREATE TABLE #RevenueWork (

		--	Header info:
			company_id					int			NULL,
			profit_ctr_id				int			NULL,
			trans_source				char(2)		NULL,	--	Receipt,	Workorder,	Workorder-Receipt,	etc
			receipt_id					int			NULL,	--	Receipt/Workorder	ID
			trans_type					char(1)		NULL,	--	Receipt	trans	type	(O/I)
			billing_project_id			int			NULL,	--	Billing	project	ID
			customer_id					int			NULL,	--	Customer	ID	on	Receipt/Workorder

		--	Detail info:
			line_id						int			NULL,	--	Receipt	line	id
			price_id					int			NULL,	--	Receipt	line	price	id
			ref_line_id					int			NULL,	--	Billing	reference	line_id	(which	line	does	this	refer	to?)
			workorder_sequence_id		varchar(15)	NULL,	--	Workorder	sequence	id
			workorder_resource_item		varchar(15)	NULL,	--	Workorder	Resource	Item
			workorder_resource_type		varchar(15)	NULL,	--	Workorder	Resource	Type
			Workorder_resource_category	Varchar(40)	NULL,	--	Workorder	Resource	Category
			quantity					float		NULL,	--	Receipt/Workorder	Quantity
			billing_type				varchar(20)	NULL,	--	'Energy',	'Insurance',	'Salestax'	etc.
			dist_flag					char(1)		NULL,	--	'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
			dist_company_id				int			NULL,	--	Distribution	Company	ID	(which	company	receives	the	revenue)
			dist_profit_ctr_id			int			NULL,	--	Distribution	Profit	Ctr	ID	(which	profitcenter	receives	the	revenue)
			extended_amt				float			NULL,	--	Revenue	amt
			generator_id				int			NULL,	--	Generator	ID
			treatment_id				int			NULL,	--	Treatment	ID
			bill_unit_code				varchar(4)	NULL,	--	Unit
			profile_id					int			NULL,	--	Profile_id
			quote_id					int			NULL,	--	Quote	ID
			product_id					int			NULL,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.

			job_type                    char(1)     NULL,	--  Job type - base or event.
			servicecategory_uid			int NULL,					-- 3/11/2015 - Adding service category & business segment.
			service_category_description	varchar(50) NULL,
			service_category_code		char(1) NULL,
			businesssegment_uid			int NULL,
			business_segment_code		varchar(10) NULL,
			pounds						float NULL,
			revenue_recognized_date				datetime NULL
		)

	create index idx_tmp on #RevenueWork (trans_source			,company_id				,profit_ctr_id			,receipt_id				,line_id					,workorder_resource_type	,workorder_sequence_id	)

	if object_id('tempdb..#Run') is not null
		drop table #Run

	select 0 as months_ago, getdate() as month_ago_date, getdate() as startdate, getdate() as enddate, 0 as progress into #Run
		union select 1, null, null, null, 0 /* Always do the most recent 3 months */
		union select 2, null, null, null, 0
		union select 3, null, null, null, 0
		union select 4, null, null, null, 0 where datepart(dw,getdate()) in (1,7) /* Only do extra months back on a weekend */
		union select 5, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 6, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 7, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 8, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 9, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 10, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 11, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 12, null, null, null, 0 where datepart(dw,getdate()) in (1,7)
		union select 13, null, null, null, 0 where datepart(dw,getdate()) in (1,7)

	update #Run set 
		month_ago_date = dateadd(m, -1 * months_ago, getdate())

	update #Run set 
		startdate = convert(datetime, convert(varchar(2), month(month_ago_date)) + '/1/' + convert(varchar(4), year(month_ago_date)))
		, enddate = convert(datetime, convert(varchar(2), month(dateadd(m, 1, month_ago_date))) + '/1/' + convert(varchar(4), year(dateadd(m, 1, month_ago_date))))-0.00001

	-- select * from #Run

	declare @sd datetime, @ed datetime, @n datetime, @ad datetime

	while exists (select 1 from #Run where progress = 0) begin

		select top 1 
			@sd = startdate
			, @ed = enddate
			, @n = getdate()
			, @ad = case when datepart(hh, getdate()) < 8 then convert(date, dateadd(d, -1, getdate())) else convert(date, getdate()) end
		from #Run where progress = 0
		order by month_ago_date

		truncate table #RevenueWork
		
		PRINT '------------------------------------------------------------------'
		
		EXEC sp_rpt_recognized_revenue_calc
			@copc_list			= 'ALL',
			@date_from			= @sd, --'12/31/2013',
			@date_to			= @ed, --'10/31/2011',
			@cust_id_from		= 0,
			@cust_id_to			= 999999,
			@debug_flag			= 0
			


--		if @@error <> 0 BEGIN 


		BEGIN TRANSACTION
		
			
			delete from RecognizedRevenue where revenue_recognized_date between @sd and @ed
			
			insert RecognizedRevenue select * from #RevenueWork

			
			update RecognizedRevenueMeta set
				status = 'I'
			where start_date = @sd 
			and end_date = @ed

			
			insert RecognizedRevenueMeta (date_added, start_date, end_date, status, run_duration, as_of_date)
			select
				getdate()
				, @sd
				, @ed
				, 'A'
				, abs(datediff(s, @n, getdate()))
				, @ad

			
			if @@error <> 0 begin
				ROLLBACK
			end
			else
			begin
				COMMIT
			end

			Update #RUN set progress = 1
			where startdate = @sd
			and enddate = @ed

		END
		

		PRINT '------------------------------------------------------------------'

--	END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RecognizedRevenue_Update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RecognizedRevenue_Update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RecognizedRevenue_Update] TO [EQAI]
    AS [dbo];

