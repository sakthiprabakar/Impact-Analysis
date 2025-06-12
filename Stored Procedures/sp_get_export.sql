create procedure sp_get_export (
	@export_id	int,
	@user_code	varchar(20)
) as
/* ****************************************
sp_get_export:
	returns the filename, filetype and content of an export

sp_get_export 1, 'jonathan'
	
created 7/28/2011 - JPB
	
**************************************** */

select 
	e.filename, 
	e.filetype,
	e.content 
from plt_export..export e
inner join ReportLog rl on e.report_log_id = rl.report_log_id
where e.export_id = @export_id
and rl.user_code = @user_code
and rl.date_finished is not null


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_export] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_export] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_export] TO [EQAI]
    AS [dbo];

