CREATE PROCEDURE sp_wProject_Types AS
select * from wlkp_Project_Type
order by sort_order

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wProject_Types] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wProject_Types] TO [COR_USER]
    AS [dbo];


