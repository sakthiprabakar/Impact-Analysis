
create proc sp_eqip_arcos_worksheet (
	@tsdf_code	varchar(15),	-- 'EQDET'
	@dt_begin	datetime,		-- '01/01/2012'
	@dt_end		datetime,		-- '03/31/2012 23:59:59'
	@type_ind	char(1),		-- 'Q'=Quarterly, 'Y'=Year-end
	@user_code		varchar(20),
	@permission_id	int,
	@report_log_id	int
) AS
/* ****************************************************************************
sp_eqip_arcos_worksheet
	Creates an ARCOS worksheet to text file for EQIP download

	5/2/2012 - JPB Created (Rob_B wrote the SQL, JPB just made it a SP for EQIP)
		
sp_eqip_arcos_worksheet 'EQDET', '1/1/2012', '3/31/2012 23:59:59', 'Q'

**************************************************************************** */

if datepart(hh, @dt_end) = 0 set @dt_end = @dt_end + 0.99999

DECLARE @trans_code char(1),
		@action_ind char(1),
		@unit char(1),
		@correction_number varchar(8),
		@strength varchar(4),
		@blank char(1),
		@run_id	int

-- Default the columns that are standard and/or blank
SELECT	@trans_code = case @type_ind when 'Q' then 'P' when 'Y' then '3' end,
		@action_ind = ' ',
		@unit = ' ',
		@correction_number = replicate(' ',8),
		@strength = replicate('0',4),
		@blank = ' ',
		@run_id = (select isnull(max(run_id), 0) + 1 from EQ_TEMP..sp_eqip_arcos_worksheet_table)

DELETE FROM EQ_TEMP..sp_eqip_arcos_worksheet_table WHERE user_code = @user_code and @run_id <= @run_id

INSERT EQ_TEMP..sp_eqip_arcos_worksheet_table

-- Generate header record and all of the drug records
/* --(Don't generate the header record when producing the Worksheet)
SELECT @run_id, 0 as row, convert(varchar(83),ltrim(rtrim(isnull(dea_id,''))) + replicate(' ',9-datalength(ltrim(rtrim(isnull(dea_id,''))))) + '*' + replace(convert(varchar(10),@dt_end,101),'/','') + 'Q') as arcos_record
FROM TSDF
WHERE TSDF_code = @tsdf_code
UNION
*/ --(Don't generate the header record when producing the Worksheet)
SELECT DISTINCT
	@user_code, @run_id, row_number() OVER (ORDER BY t.DEA_ID,g.DEA_ID,ws.date_act_arrive,wdi.merchandise_code,wdi.merchandise_quantity) as row,
	ltrim(rtrim(isnull(t.dea_id,''))) + replicate(' ',9-datalength(ltrim(rtrim(isnull(t.dea_id,'')))))
	+ @trans_code
	+ @action_ind
	+ replicate('0',11-datalength(convert(varchar(11),wdi.merchandise_code))) + convert(varchar(11),wdi.merchandise_code)
	+ replicate('0',8-datalength(convert(varchar(8),isnull(wdi.merchandise_quantity,0)))) + convert(varchar(8),isnull(wdi.merchandise_quantity,0))
	+ @unit
	+ upper(case @type_ind when 'Q' then ltrim(rtrim(isnull(g.dea_id,''))) + replicate(' ',9-datalength(ltrim(rtrim(isnull(g.dea_id,'')))))
					when 'Y' then REPLICATE(' ',9) end)
	+ case @type_ind when 'Q' then isnull(wdi.dea_form_222_number,'         ') when 'Y' then '         ' end
	+ case @type_ind when 'Q' then replace(convert(varchar(10),isnull(ws.date_act_arrive,replicate(' ',10)),101),'/','')
					when 'Y' then replace(convert(varchar(10),@dt_end,101),'/','') end
	+ @correction_number
	+ @strength
	+ replicate('0',10 - datalength(convert(varchar(10),row_number() OVER (ORDER BY t.DEA_ID,g.DEA_ID,ws.date_act_arrive,
	wdi.merchandise_code,wdi.merchandise_quantity,ws.date_act_arrive)))) + convert(varchar(9),row_number() OVER (ORDER BY t.DEA_ID,g.DEA_ID,ws.date_act_arrive,wdi.merchandise_code,wdi.merchandise_quantity,g.DEA_ID,ws.date_act_arrive))
	+ case when @type_ind = 'Q' then @trans_code else '' end as arcos_record
-- FOR WORKSHEET, map each ARCOS record to the WorkOrder/WorkOrderDetailItem used
-- When generating the worksheet, don't include the first unioned select that generates the header record
--,wh.workorder_id, wh.company_id, wh.profit_ctr_id, wd.tsdf_approval_code, wdi.dea_form_222_number, wdi.merchandise_code, wdi.merchandise_quantity
FROM WorkorderHeader wh (NOLOCK)
JOIN Generator g (NOLOCK) ON g.generator_id = wh.generator_id
JOIN WorkorderStop ws (NOLOCK) ON ws.workorder_ID = wh.workorder_id
	AND ws.company_id = wh.company_id
	AND ws.profit_ctr_id = wh.profit_ctr_ID
	AND ws.stop_sequence_id = 1
	AND ws.date_act_arrive BETWEEN @dt_begin and @dt_end
JOIN WorkorderDetail wd (NOLOCK) ON wd.workorder_ID = wh.workorder_ID
	AND wd.company_id = wh.company_id
	AND wd.profit_ctr_ID = wh.profit_ctr_ID
	AND wd.resource_type = 'D'
JOIN WorkOrderDetailItem wdi (NOLOCK) ON wdi.workorder_ID = wd.workorder_id
	AND wdi.company_id = wd.company_id
	AND wdi.profit_ctr_id = wd.profit_ctr_id
	AND wdi.sequence_id = wd.sequence_id
	AND wdi.item_type_ind = 'ME'
	AND wdi.merchandise_code_type = 'N'
	AND wdi.merchandise_id IS NOT NULL
	AND isnull(ltrim(rtrim(wdi.merchandise_code)),'') <> ''
	AND wdi.DEA_schedule in ('2','02')
	AND DATALENGTH(ltrim(rtrim(isnull(wdi.dea_form_222_number,'')))) = 9
JOIN Merchandise m (NOLOCK) ON m.merchandise_id = wdi.merchandise_id
JOIN TSDF t (NOLOCK) ON wd.TSDF_code = t.TSDF_code
	and t.TSDF_status = 'A'
	and t.TSDF_code = @tsdf_code
WHERE wh.workorder_status <> 'V'
order by row asc

-- Export to text for user:
declare @tmp_desc varchar(200),
	@tmp_filename varchar(200),
	@template_name varchar(200),
	@tablename varchar(1000),
	@from_to_file_date	varchar(100)

set @from_to_file_date = convert(varchar(4), datepart(yyyy, @dt_begin)) + '-' 
	+ right('00' + convert(varchar(2), datepart(mm, @dt_begin)),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(dd, @dt_begin)),2) + '-to-' 
	+ convert(varchar(4), datepart(yyyy, @dt_end)) + '-'
	+ right('00' + convert(varchar(2), datepart(mm, @dt_end)),2) + '-' 
	+ right('00' + convert(varchar(2), datepart(dd, @dt_end)),2)
	
select 
	@tmp_desc = upper(@tsdf_code) + ' ARCOS Worksheet ' 
		+ convert(varchar(10), @dt_begin, 110) + ' - ' 
		+ convert(varchar(12), @dt_end, 110),
	@tmp_filename = upper(@tsdf_code) + '-ARCOS-Worksheet- ' 
		+ @from_to_file_date + '.txt',
	@template_name = 'sp_eqip_arcos_worksheet.1',
	@tablename = ' SELECT arcos_record from eq_temp..sp_eqip_arcos_worksheet_table where run_id = ' + convert(varchar(20), @run_id) + ' order by row '

exec plt_export.dbo.sp_export_query_to_text 
	@table_name	= @tablename,
	@template	= @template_name,
	@filename	= @tmp_filename,
	@header_lines_to_remove = 2,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id
	-- , @debug = 1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_arcos_worksheet] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_arcos_worksheet] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_arcos_worksheet] TO [EQAI]
    AS [dbo];

