-- drop proc sp_cor_service_document
go

create procedure sp_cor_service_document (
	@web_userid			varchar(100)
	, @workorder_id		int
	, @company_id		int
    , @profit_ctr_id	int
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
) as

/* *******************************************************************
sp_cor_service_document

Description
	Provides a listing of all work order attachments

exec sp_cor_service_document
	@web_userid = 'nyswyn100'
	, @workorder_id = 22146300
	, @company_id = 14
	, @profit_ctr_id = 4
	
	
SELECT  *  FROM    plt_image..scan where workorder_id in (757041, 757042, 757043, 757044, 757045, 757046, 757047, 757048, 757049, 757050, 757051, 757052, 757053, 757054, 757056, 757058, 757061, 757063, 757065, 757066)
and company_id = 21
	
SELECT  *  FROM    plt_image..scan WHERE image_id in (3185518, 3185524) and company_id = 21
	
******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = @web_userid
	, @i_workorder_id		int = @workorder_id
	, @i_company_id		int = @company_id
    , @i_profit_ctr_id	int = @profit_ctr_id


-- declare @i_web_userid varchar(100) = 'vince.scheerer', @i_workorder_id int = 24670200, @i_company_id int = 14, @i_profit_ctr_id int = 14

declare @images  table (
	image_id	BIGINT				/* scan.image_id */
	, document_source varchar(30)	/* scan.document_source */
	, document_name	varchar(50)		/* scan.document_name */
	, manifest		varchar(15)		/* scan.manifest */
	, type_id		int				/* scan.type_id */
	, document_type	varchar(30)		/* scandocumenttype.document_type */
	, page_number	int				/* scan.page_number */
	, file_type		varchar(10)		/* scan.file_type */
	, relation		varchar(20)		/* input or related */
	, receipt_id	int				/* scan.workorder_id / scan.receipt_id */
	, company_id	int				/* scan.company_id */
	, profit_ctr_id	int				/* scan.profit_ctr_id */
)
insert @images
select
	image_id
	, document_source
	, document_name
	, manifest
	, type_id
	, document_type
	, page_number
	, file_type
	, relation
	, receipt_id
	, company_id
	, profit_ctr_id
from
dbo.fn_cor_scan_lookup (@i_web_userid, 'workorder', @i_workorder_id, @i_company_id, @i_profit_ctr_id, 1, '')

SELECT  
	image_id
	, document_type
	, document_name	
	, page_number
	, document_source
	, manifest
	, relation
	, case when isnull(page_number, 1) = 1 then 'T' else 'F' end as for_combined_display
	, isnull(( select substring(
	(
	select ', ' + 
	convert(varchar(20), image_id) + '|' + file_type + '|' + convert(varchar(20), page_number)
	FROM @images b
	where a.document_source = b.document_source
	and a.document_name = b.document_name
	and isnull(a.manifest, '') = isnull(b.manifest, '')
	and a.type_id = b.type_id
	and a.document_type = b.document_type
	order by isnull(b.page_number, 1)
	for xml path, TYPE).value('.[1]','nvarchar(max)'
),2,20000)	) , '')	as image_id_file_type_page_number_list
	, row_number() over (order by relation, company_id, profit_ctr_id, receipt_id, document_type, document_name, isnull(page_number, 1), image_id) as _ord
INTO #foo
FROM    @images a
order by relation, company_id, profit_ctr_id, receipt_id, document_type, document_name, isnull(page_number, 1), image_id

UPDATE #foo set for_combined_display = 'T' where image_id_file_type_page_number_list not like '%,%'

select
	image_id
	, document_type
	, document_name	
	, page_number
	, document_source
	, manifest
	, relation
	, for_combined_display
	, image_id_file_type_page_number_list
from #foo 
order by _ord


return 0
go

grant execute on sp_cor_service_document to eqai, eqweb, COR_USER
go
