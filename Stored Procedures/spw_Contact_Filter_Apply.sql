
CREATE PROCEDURE spw_Contact_Filter_Apply
@Logon	varchar(10)
 AS
declare @strSelect1	varchar(255)
declare @strSelect2	varchar(255)
declare @strWhere1	varchar(4000)
declare @strWhere2	varchar(4000)
declare @strWhere3	varchar(4000)
declare @strWhere4	varchar(4000)
declare @strEnd		varchar(30)
declare @intLength	int

set nocount on

set @strSelect1 = 'select 1 as tag, null as parent, '''' as [customers!1], null as [customer!2!cust_name], null as [customer!2!cust_city], null as [customer!2!cust_state], null as [customer!2!customer_id], null as [customer!2!cust_category] '
set @strSelect2 = ' union all select 2,  1,  '''', cust_name,  cust_city,  cust_state,  customer_id,  ''Industrial Service'' from customer '
set @strEnd = ' for xml explicit'

SELECT @intLength = datalength(favorite_text) 
FROM eqweb.dbo.tbl_favorite_filters f
WHERE f.logon = @logon and f.favorite_name = '*Last Filter Applied'

if @intLength >= 4000
begin
	select @strWhere1 = substring( favorite_text, 0, 4000)
	FROM eqweb.dbo.tbl_favorite_filters f
	WHERE f.logon = @logon and f.favorite_name = '*Last Filter Applied'
	if @intLength >= 8000
	begin
		select @strWhere1 = substring( favorite_text, 4000, 4000)
		FROM eqweb.dbo.tbl_favorite_filters f
		WHERE f.logon = @logon and f.favorite_name = '*Last Filter Applied'
		if @intLength >= 12000
		begin
			select @strWhere1 = substring( favorite_text, 8000, 4000)
			FROM eqweb.dbo.tbl_favorite_filters f
			WHERE f.logon = @logon and f.favorite_name = '*Last Filter Applied'
			if @intLength >= 16000
				select @strWhere1 = substring( favorite_text, 12000, 4000)
				FROM eqweb.dbo.tbl_favorite_filters f
				WHERE f.logon = @logon and f.favorite_name = '*Last Filter Applied'
		end
	end
end
else
begin
	select @strWhere1 = substring( favorite_text, 0, @intLength)
	FROM eqweb.dbo.tbl_favorite_filters f
	WHERE f.logon = @logon and f.favorite_name = '*Last Filter Applied'
end

set nocount off

exec( @strSelect1 + @strSelect2 + @strWhere1 + @strWhere2 + @strWhere3 + @strWhere4 + @strEnd)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_Filter_Apply] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_Contact_Filter_Apply] TO [COR_USER]
    AS [dbo];


