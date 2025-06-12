	
create proc sp_Emanifest_Report_Signed (
	@copc_list	varchar(max) = ''
	,@start_date	datetime
	,@end_date	datetime
)
as
/* ***************************************************************************************
sp_Emanifest_Report_Signed

return AthenaStatus info for signed EQAI records

exec sp_Emanifest_Report_Signed '', '9/28/2018', '9/28/2018 23:59:59'

exec Athena.athena.dbo.sp_AthenaQueue_Report_Failed 'eqai', '6/1/2018', '10/31/2018'

exec sp_Emanifest_Report_Signed '21|0', '9/28/2018', '9/28/2018 23:59:59'


*************************************************************************************** */


if object_id('tempdb..#Results') is not null
drop table #Results

create table #Results (
	_id	int
	, source	varchar(20)
	, source_table	varchar(20)
	, source_id		varchar(40)
	, source_company_id	varchar(10)
	, source_profit_ctr_id varchar(10)
	, manifest varchar(20)
	, receipt_date datetime
	, status varchar(100)
	, date_signed datetime
)

insert #Results 
execute Athena.athena.dbo.sp_AthenaQueue_Report_Signed 'eqai', @copc_list, @start_date, @end_date

select distinct
	r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.customer_id
	, r.generator_id
	, r.receipt_date
	, a.status
	, r.manifest
	, a.date_signed
from #Results a
left join receipt r 
	on a.source_id = r.receipt_id 
	and a.source_company_id = r.company_id 
	and a.source_profit_ctr_id = r.profit_ctr_id
	and a.manifest = r.manifest
-- where response_error not like '%EPA System Error during upload%'
order by 
r.company_id, r.profit_ctr_id, r.manifest, a.date_signed



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Signed] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Signed] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Signed] TO [EQAI]
    AS [dbo];

