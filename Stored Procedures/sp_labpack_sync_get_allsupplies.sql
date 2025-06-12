CREATE procedure [dbo].[sp_labpack_sync_get_allsupplies]
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 11 Sep 2020
-- Description:	This procedure is used to select all distinct supplies
-- Exec Stmt  : 

/*
	exec [dbo].[sp_labpack_sync_get_allsupplies]
	
*/
-- =============================================
as
set transaction isolation level read uncommitted

select distinct resource_class_code, description
from ResourceClass
where resource_type = 'S'
and status = 'A'
order by resource_class_code