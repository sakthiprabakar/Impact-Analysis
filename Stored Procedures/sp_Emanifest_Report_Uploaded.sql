	
create proc sp_Emanifest_Report_Uploaded (
	@copc_list	varchar(max) = ''
)
as
/* ***************************************************************************************
sp_Emanifest_Report_Uploaded

return AthenaStatus info for failed EQAI records

exec sp_Emanifest_Report_Uploaded ''
exec sp_Emanifest_Report_Uploaded '3|0'

exec Athena.athena.dbo.sp_AthenaQueue_Report_Uploaded 'eqai'


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
	, days_since_receipt	int
	, status varchar(100)
	, response_error varchar(max)
	, first_tried datetime
	, try_count int
	, last_tried datetime
	, date_uploaded datetime
	, date_signed datetime
)

insert #Results 
execute Athena.athena.dbo.sp_AthenaQueue_Report_Uploaded 'eqai', @copc_list

select distinct
	r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.customer_id
	, r.generator_id
	, r.receipt_date
	, a.days_since_receipt	
	, a.status
	, r.manifest
	, a.response_error
	, a.date_uploaded
from #Results a
left join receipt r 
	on a.source_id = r.receipt_id 
	and a.source_company_id = r.company_id 
	and a.source_profit_ctr_id = r.profit_ctr_id
	and a.manifest = r.manifest
-- where response_error not like '%EPA System Error during upload%'
order by 
r.company_id, r.profit_ctr_id, a.days_since_receipt desc, r.manifest


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Uploaded] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Uploaded] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Emanifest_Report_Uploaded] TO [EQAI]
    AS [dbo];

