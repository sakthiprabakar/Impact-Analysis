-- drop proc if exists sp_COR_Costco_Intelex_RunAll

go
create proc sp_COR_Costco_Intelex_RunAll
	@web_userid		varchar(100)
	, @start_date		datetime = null
	, @end_date		datetime = null
as
/*
sp_COR_Costco_Intelex_RunAll

	exec sp_COR_Costco_Intelex_RunAll @web_userid = 'use@costco.com'


*/

	declare 
		@i_web_userid varchar(100) = isnull(@web_userid, ''),
		@i_start_date	datetime,
		@i_end_date		datetime
		
	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') exec sp_COR_Costco_Intelex_RunAll ''' + @i_web_userid + ''', ''' + convert(varchar(40), @start_date, 121) + ''', ''' + convert(varchar(40), @end_date, 121) + '''')

	if @start_date is null and @end_date is null begin
		select @start_date = convert(datetime, config_value)
		from plt_ai..configuration
		where config_key = 'sp_COR_Costco_Intelex Start Date'
		and config_value <> ''
		
		select @end_date = convert(datetime, config_value)
		from plt_ai..configuration
		where config_key = 'sp_COR_Costco_Intelex End Date'
		and config_value <> ''
	end 

	if @start_date is null and @end_date is null begin
		set @start_date = dateadd(dd, -2, getdate())
		set @end_date = getdate()
	end 

	set @i_start_date = @start_date
	set @i_end_date = @end_date
	
	if @i_start_date is not null and @i_end_date is not null begin

		print 'sp_COR_Costco_Intelex_Waste_Service_Event_list ''' + @i_web_userid + ''', ''' + convert(varchar(40), @i_start_date) + ''', ''' + convert(varchar(40), @i_end_date) + ''''

		exec plt_ai..sp_COR_Costco_Intelex_Waste_Service_Event_list
			@web_userid		= @i_web_userid
			, @start_date	= @i_start_date
			, @end_date		= @i_end_date

		exec plt_ai..sp_COR_Costco_Intelex_Manifest_list
			@web_userid		= @i_web_userid
			, @start_date	= @i_start_date
			, @end_date		= @i_end_date

		exec plt_ai..sp_COR_Costco_Intelex_Manifest_Line_list
			@web_userid		= @i_web_userid
			, @start_date	= @i_start_date
			, @end_date		= @i_end_date
			
		exec plt_ai..sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list
			@web_userid		= @i_web_userid
			, @start_date	= @i_start_date
			, @end_date		= @i_end_date
			
		exec plt_ai..sp_COR_Costco_Intelex_Waste_Profile_list
			@web_userid		= @i_web_userid
			, @start_date	= @i_start_date
			, @end_date		= @i_end_date
			
		exec plt_ai..sp_COR_Costco_Intelex_Waste_Code_list
			@web_userid		= @i_web_userid
			, @start_date	= @i_start_date
			, @end_date		= @i_end_date

	end

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_RunAll finished')

go

grant execute on sp_COR_Costco_Intelex_RunAll
to cor_user
go

grant execute on sp_COR_Costco_Intelex_RunAll
to eqai
go

grant execute on sp_COR_Costco_Intelex_RunAll
to eqweb
go

grant execute on sp_COR_Costco_Intelex_RunAll
to CRM_Service
go

grant execute on sp_COR_Costco_Intelex_RunAll
to DATATEAM_SVC
go

