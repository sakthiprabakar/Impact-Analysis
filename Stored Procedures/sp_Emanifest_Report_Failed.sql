	
create proc sp_Emanifest_Report_Failed (
	@copc_list	varchar(max) = ''
	,@start_date	datetime
	,@end_date	datetime
)
as
/* ***************************************************************************************
sp_Emanifest_Report_Failed

return AthenaStatus info for failed EQAI records

exec sp_Emanifest_Report_Failed '', '6/1/2018', '10/31/2018'

exec Athena.athena.dbo.sp_AthenaQueue_Report_Failed 'eqai', '6/1/2018', '10/31/2018'


*************************************************************************************** */


if object_id('tempdb..#Errors') is not null
drop table #Errors

create table #Errors (
	_id	int
	, first_tried datetime
	, times_tried int
	, last_tried datetime
	, source	varchar(20)
	, source_table	varchar(20)
	, source_id		varchar(40)
	, source_company_id	varchar(10)
	, source_profit_ctr_id varchar(10)
	, receipt_date datetime
	, age_in_days	int
	, status varchar(100)
	, manifest varchar(20)
	, manifest_line int
	, response_error varchar(max)
)

insert #Errors 
execute Athena.athena.dbo.sp_AthenaQueue_Report_Failed 'eqai', @copc_list, @start_date, @end_date

select 
	r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.customer_id
	, r.generator_id
	, r.receipt_date
	, a.age_in_days	
	, r.line_id
	, r.profile_id
	, a.status
	, r.manifest
	, a.manifest_line
	, a.response_error
	, a.first_tried
	, a.times_tried
	, a.last_tried
from #Errors a
left join receipt r 
	on a.source_id = r.receipt_id 
	and a.source_company_id = r.company_id 
	and a.source_profit_ctr_id = r.profit_ctr_id
	and a.manifest = r.manifest
	and case a.manifest_line when 0 then 1 else a.manifest_line end = r.manifest_line
-- where response_error not like '%EPA System Error during upload%'
order by 
case when a.response_error not like '%EPA System Error during upload%' then 1 else 2 end
, a.source_company_id, a.source_profit_ctr_id, a.age_in_days desc, a.manifest, a.manifest_line



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Failed] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Failed] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Failed] TO [EQAI]
    AS [dbo];

