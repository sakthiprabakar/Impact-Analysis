if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_resources')
	drop procedure dbo.sp_labpack_sync_get_resources
go

CREATE procedure [dbo].[sp_labpack_sync_get_resources]
	@company_id int
as
set transaction isolation level read uncommitted

SELECT
	ResourceXResourceClass.resource_class_code,
	Resource.resource_code,
	Resource.description,
	ResourceClass.bill_unit_code,
	ResourceClass.profit_ctr_id
FROM Resource
INNER JOIN ResourceXResourceClass
	ON Resource.company_id = ResourceXResourceClass.resource_class_company_id
	AND Resource.default_profit_ctr_id = ResourceXResourceClass.resource_class_profit_ctr_id
	AND Resource.resource_code = ResourceXResourceClass.resource_code
INNER JOIN ResourceClass
	ON ResourceClass.company_id = ResourceXResourceClass.resource_class_company_id
	AND ResourceClass.profit_ctr_id = ResourceXResourceClass.resource_class_profit_ctr_id
	AND ResourceClass.resource_class_code = ResourceXResourceClass.resource_class_code
	AND ResourceClass.bill_unit_code = ResourceXResourceClass.bill_unit_code
WHERE Resource.company_id = @company_id
AND Resource.resource_status = 'A'
AND ResourceClass.resource_type = 'L'
ORDER BY ResourceXResourceClass.resource_class_code, Resource.resource_code
GO

grant execute on dbo.sp_labpack_sync_get_resources to EQAI, LPSERV
go
