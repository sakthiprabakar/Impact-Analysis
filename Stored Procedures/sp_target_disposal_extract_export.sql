
create proc sp_target_disposal_extract_export (
	@start_date		datetime
	,@end_date		datetime
	,@report_log_id int = NULL
) AS
/* ******************************************************************
sp_target_disposal_extract_export

	Created to run the build process for Target, THEN perform export on that info.
	
	Created to satisfy Target (12113) requirements for monthly data
	formatted to their spec.
	
	Similar to (orig copied from, then modified)
	L:\IT Apps\SQL\Special Manual Requests\Target\Extract SC, 4-1 - 5-31-2012\
	
History:
	2012-10-10	JPB	Created
	
Samples:
	sp_target_disposal_extract_export  '3/28/2013', '5/18/2013 23:59'

****************************************************************** */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @customer_id int = 12113

-- Fix/Set EndDate's time.
if isnull(@end_date,'') <> ''
	if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Define extract values:
DECLARE
    @extract_datetime       datetime,
    @usr                    nvarchar(256),
    @sp_name_args           varchar(1000),
    @timer					    datetime = getdate(),
    @steptimer				    datetime = getdate(),
    @debug                  int
SELECT
    @extract_datetime       = GETDATE(),
    @usr                    = UPPER(SUSER_SNAME()),
    @sp_name_args           = object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + '''',
    @debug                  = 1
    
if @report_log_id is not null and len(@usr) > 10
   select @usr = user_code from reportlog where report_log_id = @report_log_id

if @debug > 0 begin
   Print 'Extract started at ' + convert(varchar(40), @timer)
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


IF RIGHT(@usr, 3) = '(2)'
    SELECT @usr = LEFT(@usr,(LEN(@usr)-3))

if @debug > 0 begin
   print 'Run Setup Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()
    

EXEC sp_target_disposal_extract_build 
	@start_date				
	,@end_date				
    ,@extract_datetime      
    ,@usr                   

if @debug > 0 begin
   print 'Build Run Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


/* *************************************************************
Populate Output tables from this run.
************************************************************* */


-- Disposal Information
if @debug > 0 begin
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

        INSERT EQ_Extract.dbo.TargetDisposalExtract (
			vendor_number ,						--	varchar(9) NULL,
			[target_location] ,					--	[varchar](4) NULL,
			[pickup_date] ,						--	[datetime] NULL,
			[workorder_id] ,					--	varchar(10) NULL,
			[manifest] ,						--	[varchar](12) NULL,
			[account_number] ,					--	varchar(7) NULL,
			[cost_center] ,						--	varchar(8) NULL,
			[service_description] ,				--	varchar(255) NULL,
			[number_of_containers] ,			--	[int] NULL,
			[total_weight] ,					--	[float] NULL,
			[federal_waste_code_1] ,			--	[varchar](4) NULL,
			[federal_waste_code_2] ,			--	[varchar](4) NULL,
			[state_waste_code_1] ,				--	[varchar](10) NULL,
			[disposal_cost]	,					--	money NULL,
			[delivery_date_at_disposal_site] ,	--	datetime NULL,
			[federal_waste_code_3] ,			--	[varchar](4) NULL,
			[federal_waste_code_4] ,			--	[varchar](4) NULL,
			[federal_waste_code_5] ,			--	[varchar](4) NULL,
			[federal_waste_code_6] ,			--	[varchar](4) NULL,
			[state_waste_code_2] ,				--	[varchar](10) NULL,
			[transporter_name_1] ,				--	[varchar](75) NULL,
			[transporter_epa_id_1] ,			--	[varchar](12) NULL,
			[transporter_name_2] ,				--	[varchar](100) NULL,
			[transporter_epa_id_2] ,			--	[varchar](12) NULL,
			[tsd_name] ,						--	[varchar](100) NULL,
			[tsd_epa_id] ,						--	[varchar](12) NULL,
			[management_code] ,					--	[varchar](4) NULL,
			[final_management_code] ,			--	[varchar](4) NULL,
			[added_by] ,						--	[varchar](10) NOT NULL,
			[date_added] 						--	[datetime] NOT NULL
        )
        SELECT
            vendor_number,
            site_code,
            service_date,
            purchase_order,
            manifest,
			account_number,
			cost_center,
			service_description,
			container_count,
			pounds,
			waste_code_1,
			waste_code_2,
			state_waste_code_1,
			billing_amt,
			date_delivered,
			waste_code_3,
			waste_code_4,
			waste_code_5,
			waste_code_6,
			state_waste_code_2,
			transporter1_name,     
			transporter1_epa_id,   
			transporter2_name,     
			transporter2_epa_id,   
			receiving_facility,
			receiving_facility_epa_id,
			management_code,
			management_code,
			@usr,
			@extract_datetime
        FROM EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
        WHERE added_by = @usr and date_added = @extract_datetime
        AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Output: Disposal, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- 4/26/2013 - set final_management_code to values matching target service description settings.
UPDATE EQ_Extract.dbo.TargetDisposalExtract SET final_management_code = TSD.final_management_code
FROM EQ_Extract.dbo.TargetDisposalExtract e inner join TargetServiceDescription tsd
	on e.service_description = tsd.service_description
WHERE e.added_by = @usr AND e.date_added = @extract_datetime 



SELECT
	vendor_number ,						
	[target_location] ,					
	[pickup_date] ,						
	[workorder_id] ,					
	[manifest] ,						
	[account_number] ,					
	[cost_center] ,						
	[service_description] ,				
	[number_of_containers] ,			
	[total_weight] ,					
	[federal_waste_code_1] ,			
	[federal_waste_code_2] ,			
	[state_waste_code_1] ,				
	[disposal_cost]	,					
	[delivery_date_at_disposal_site] ,	
	[federal_waste_code_3] ,			
	[federal_waste_code_4] ,			
	[federal_waste_code_5] ,			
	[federal_waste_code_6] ,			
	[state_waste_code_2] ,				
	[transporter_name_1] ,				
	[transporter_epa_id_1] ,			
	[transporter_name_2] ,				
	[transporter_epa_id_2] ,			
	[tsd_name] ,						
	[tsd_epa_id] ,						
	[management_code] ,					
	[final_management_code] 
from EQ_Extract.dbo.TargetDisposalExtract 
where 
	date_added = @extract_datetime 
	and added_by = @usr


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract_export] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract_export] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract_export] TO [EQAI]
    AS [dbo];

