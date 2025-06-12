CREATE PROCEDURE sp_wProject_Intervals AS
select interval_id, interval_desc from wlkp_Projectintervals
order by interval_sort

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wProject_Intervals] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wProject_Intervals] TO [COR_USER]
    AS [dbo];


