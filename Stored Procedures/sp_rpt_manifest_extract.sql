

CREATE PROCEDURE sp_rpt_manifest_extract (
	@customer_id			int,
	@start_date				datetime,
	@end_date				datetime
)
AS
/* ***********************************************************
Procedure    : sp_rpt_manifest_extract
Database     : PLT_AI
Created      : Apr 06 2009 - Jonathan Broome
Description  : Creates an extract of images related to billed items for a given customer, within a date range.

Examples:
	sp_rpt_manifest_extract 12113, '1/1/2009 00:00', '1/31/2009 23:59'
	sp_rpt_manifest_extract 10673, '10/1/2008 00:00', '10/31/2008 23:59'

Notes:
	The filename defined herein is:
	[Generator.Site_Code]-["Manifest" or other Scan Document Type name]-[Scan.document_name]-P[Scan.page_number]-[Scan.image_id].[Scan.filetype]

History:
	4/06/2009 - JPB - Created
		
*********************************************************** */

SET NOCOUNT ON

-- Define Walmart specific extract values:
DECLARE
	@usr			nvarchar(256),
	@today			datetime
SELECT
	@usr			= UPPER(SUSER_SNAME()),
	@today			= GETDATE()

IF RIGHT(@usr, 3) = '(2)'
	SELECT @usr = LEFT(@usr,(LEN(@usr)-3))

insert eq_extract.dbo.ManifestExtract
select distinct 
	s.image_id,
	b.customer_id,
	b.generator_id,
	s.document_source,
	b.receipt_id,
	b.company_id,
	b.profit_ctr_id,
	isnull(site_code, '') + '-' 
	+ replace(case when sdt.document_type like '%manifest%' then 'Manifest-' else sdt.document_type + '-' end, ' ', '-')
	+ isnull(s.document_name, '') + '-P' 
	+ convert(varchar(20), isnull(s.page_number, 1)) + '-' 
	+ convert(varchar(20), image_id) + '.' 
	+ lower(isnull(s.file_type, '')) as filename,
	@usr as added_by,
	@today as date_added
	-- convert(varchar(200), image_id) as filename
from
	billing b (nolock)
	inner join plt_image..scan s (nolock) on 
		b.receipt_id = s.receipt_id 
		and b.company_id = s.company_id 
		and b.profit_ctr_id = s.profit_ctr_id 
		and b.trans_source = 'R'
		and s.document_source = 'receipt'
	inner join plt_image..scandocumenttype sdt (nolock) on 
		s.type_id = sdt.type_id 
		and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
	left outer join generator g (nolock) on
		b.generator_id = g.generator_id
where
	(
		b.customer_id = @customer_id 
		or 
		b.generator_id in (
			select generator_id from customergenerator where customer_id = @customer_id
		)
	)
	and b.invoice_date between @start_date and @end_date
	and s.status = 'A'
union
select distinct 
	s.image_id,
	b.customer_id,
	b.generator_id,
	s.document_source,
	b.receipt_id,
	b.company_id,
	b.profit_ctr_id,
	isnull(site_code, '') + '-' 
	+ replace(case when sdt.document_type like '%manifest%' then 'Manifest-' else sdt.document_type + '-' end, ' ', '-')
	+ isnull(s.document_name, '') + '-P' 
	+ convert(varchar(20), isnull(s.page_number, 1)) + '-' 
	+ convert(varchar(20), image_id) + '.' 
	+ lower(isnull(s.file_type, '')) as filename,
	@usr as added_by,
	@today as date_added
	-- convert(varchar(200), image_id) as filename
from
	billing b (nolock)
	inner join plt_image..scan s (nolock) on 
		b.receipt_id = s.workorder_id 
		and b.company_id = s.company_id 
		and b.profit_ctr_id = s.profit_ctr_id 
		and b.trans_source = 'W'
		and s.document_source = 'workorder'
	inner join plt_image..scandocumenttype sdt (nolock) on 
		s.type_id = sdt.type_id 
		and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
	left outer join generator g (nolock) on
		b.generator_id = g.generator_id
where
	(
		b.customer_id = @customer_id 
		or 
		b.generator_id in (
			select generator_id from customergenerator where customer_id = @customer_id
		)
	)
	and b.invoice_date between @start_date and @end_date
	and s.status = 'A'

SET NOCOUNT OFF

SELECT 
	image_id,
	customer_id,
	generator_id,
	document_source,
	source_id,
	company_id,
	profit_ctr_id,
	filename,
	added_by,
	date_added
FROM EQ_Extract.dbo.ManifestExtract
WHERE
	date_added = @today
	and added_by = @usr
ORDER BY
	filename



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_extract] TO [EQAI]
    AS [dbo];

