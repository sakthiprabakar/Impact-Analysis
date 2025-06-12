
CREATE PROCEDURE sp_rpt_batches_without_scanned_worksheet
	@company_id			int
,	@profit_ctr_id		int
,	@batch_status		char(1)
,	@location_list		varchar(8000)
,	@date_opened_from	datetime = null
,	@date_opened_to		datetime = null
,	@date_closed_from	datetime = null
,	@date_closed_to		datetime = null
AS
/***************************************************************************************
This report displays batches that have a final destination assigned, but do not have a
scanned batch worksheet.

11/29/2017 MPM	Created
02/01/2018 - EQAI-48058 - AM - Added @location_list as ALL 

exec sp_rpt_batches_without_scanned_worksheet 21, 0, 'A', 'KC, test', null, null, null, null
exec sp_rpt_batches_without_scanned_worksheet 21, 0, 'O', 'KC, test', '1-1-1900', '1-1-3000', '1-1-1900', '1-1-3000'

exec sp_rpt_batches_without_scanned_worksheet 45, 0, 'A', '',  null, null, null, null

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @no_date_closed char(1),
		@no_date_opened char(1)

IF @date_opened_from IS NULL AND @date_opened_to IS NULL OR @date_opened_from = '1-1-1900' AND @date_opened_to = '1-1-3000'
	SET @no_date_opened = 'T'
	
IF @date_opened_from IS NULL
	SET @date_opened_from = '1-1-1900'

IF @date_opened_to IS NULL
	SET @date_opened_to = '1-1-3000'

IF @date_closed_from IS NULL AND @date_closed_to IS NULL OR @date_closed_from = '1-1-1900' AND @date_closed_to = '1-1-3000'
	SET @no_date_closed = 'T'
	
IF @date_closed_from IS NULL
	SET @date_closed_from = '1-1-1900'

IF @date_closed_to IS NULL
	SET @date_closed_to = '1-1-3000'

IF @location_list is null OR @location_list = '' SET @location_list = 'ALL' 

-- Locations:
create table #locations (location varchar(15))
if datalength((@location_list)) > 0 and @location_list <> 'ALL'
begin
    Insert #locations
    select convert(varchar(15), row)
    from dbo.fn_SplitXsvText(',', 0, @location_list)
    where isnull(row, '') <> ''
end

--SELECT * FROM #locations

SELECT DISTINCT 
		be.batch_id
		, be.location
		, be.tracking_num
		, b.date_opened
		, b.date_closed
		, CASE st.status_desc WHEN NULL THEN 'All' ELSE st.status_desc END as status
  FROM BatchEvent be
  JOIN ProcessLocation pl
	ON be.dest_location = pl.location
	AND be.company_id = pl.company_id
	AND be.profit_ctr_id = pl.profit_ctr_id
  JOIN Batch b
	ON b.company_id = be.company_id
	AND b.profit_ctr_id = be.profit_ctr_id
	AND b.location = be.location
	AND b.tracking_num = be.tracking_num
  LEFT OUTER JOIN StatusType st
	ON st.status = b.status
	AND st.status_type = 'batch'
 WHERE be.event_type = 'T'
	AND be.company_id = @company_id
	AND be.profit_ctr_id = @profit_ctr_id
	AND ( be.location in (select location from #locations) OR ( @location_list = 'ALL' ) )
	AND ((b.date_opened between @date_opened_from AND @date_opened_to) OR @no_date_opened = 'T')
	AND ((b.date_closed between @date_closed_from AND @date_closed_to) OR @no_date_closed = 'T')
	AND pl.final_destination_flag = 'T'
	AND (b.status = @batch_status or @batch_status = 'A')
	AND NOT EXISTS (SELECT 1 FROM plt_image..scan
				WHERE company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and batch_id = b.batch_id
				and type_id in (select type_id from ScanDocumentType where scan_type = 'batch' and document_type = 'Batch Worksheet/Batch Notes')) 
	ORDER BY be.location, be.tracking_num


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batches_without_scanned_worksheet] TO [EQAI]
    AS [dbo];

