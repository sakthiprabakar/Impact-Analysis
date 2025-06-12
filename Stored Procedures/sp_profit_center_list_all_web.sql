CREATE PROCEDURE sp_profit_center_list_all_web
	@CompanyList	varchar(8000) = NULL,
	@Feature	varchar(100) = NULL
AS
/*************************************************
sp_profit_center_list_all_web:

Returns the complete list of profit centers to show on the web.

example:
	exec sp_profit_center_list_all_web '14,15', ''
	exec sp_profit_center_list_all_web '', 'APPROVED WASTE PROFILES'
	exec sp_profit_center_list_all_web '', 'SCHEDULING'

select * from profitcenter where company_id in (2,3,21) and status = 'A'

LOAD TO PLT_AI*

12/05/2003 JPB Created
04/26/2005 JPB Modified Invoicing/Aging select
01/09/2006 JPB Modified to include cust_serv_email
10/01/2007 WAC Renamed table EQAICONNECT to EQCONNECT

*************************************************/

SET NOCOUNT ON

DECLARE @execute_sql	varchar(8000),
	@strSnippet	varchar(8000),
	@Order		varchar(8000)

-- SET @execute_sql = 'SELECT P.COMPANY_ID, P.PROFIT_CTR_ID, P.PROFIT_CTR_NAME, P.ADDRESS_1, P.ADDRESS_2, P.ADDRESS_3, P.PHONE, P.FAX, P.SHORT_NAME, P.EPA_ID  FROM PROFITCENTER P  INNER JOIN COMPANY C ON C.COMPANY_ID = P.COMPANY_ID  INNER JOIN #tmp_database T ON P.COMPANY_ID = T.COMPANY_ID and ((P.Profit_ctr_id = T.Profit_ctr_id and T.Profit_ctr_id is not null) or T.profit_ctr_id is null) WHERE P.STATUS = ''A'' AND C.VIEW_ON_WEB = ''T'' AND P.VIEW_ON_WEB = ''T'' '
SET @execute_sql = 'select distinct
	p.company_id,
	''Profit_ctr_id'' = case
		when p.view_on_web = ''P'' then p.profit_ctr_id
		when p.view_on_web = ''C'' then (select min(profit_ctr_id) from profitcenter where company_id = p.company_id) end,
	''Profit_ctr_Name'' = case
		when p.view_on_web = ''P'' then p.profit_ctr_name
		when p.view_on_web = ''C'' then company_name end,
	''address_1'' = case
		when p.view_on_web = ''P'' then p.address_1
		when p.view_on_web = ''C'' then c.address_1 end,
	''address_2'' = case
		when p.view_on_web = ''P'' then p.address_2
		when p.view_on_web = ''C'' then c.address_2 end,
	''address_3'' = case
		when p.view_on_web = ''P'' then p.address_3
		when p.view_on_web = ''C'' then c.address_3 end,
	''phone'' = case
		when p.view_on_web = ''P'' then p.phone
		when p.view_on_web = ''C'' then case when ''' + @Feature + ''' = ''SCHEDULING'' then p.scheduling_phone else c.phone end end,
	''fax'' = case
		when p.view_on_web = ''P'' then p.fax
		when p.view_on_web = ''C'' then c.fax end,
	''short_name'' = case
		when p.view_on_web = ''P'' then p.short_name
		when p.view_on_web = ''C'' then null end,
	''epa_id'' = case
		when p.view_on_web = ''P'' then p.epa_id
		when p.view_on_web = ''C'' then c.epa_id end ,
	''cust_serv_email'' = case
		when p.cust_serv_email is not null and p.view_on_web = ''P'' then p.cust_serv_email
		when p.cust_serv_email is not null and p.view_on_web = ''C'' then p.cust_serv_email
		when p.cust_serv_email is null and p.view_on_web IN (''C'', ''P'') then (
			select top 1 cust_serv_email from profitcenter where company_id = p.company_id
			and cust_serv_email is not null order by profit_ctr_id asc
		)
		else null end
	from profitcenter P
	inner join company C on p.company_id = c.company_id
	inner join #tmp_database t on p.company_id = t.company_id and ((P.Profit_ctr_id = T.Profit_ctr_id and T.Profit_ctr_id is not null) or T.profit_ctr_id is null)
	where
	p.status = ''A''
	and p.view_on_web in (''P'',  ''C'')
	and c.view_on_web = ''T''
'

SET @strSnippet = ''
IF @Feature = 'APPROVED WASTE PROFILES'
	SET @strSnippet = ' AND P.VIEW_APPROVALS_ON_WEB = ''T'' '
ELSE IF @Feature = 'SCHEDULING'
	SET @strSnippet = ' AND P.VIEW_SCHEDULING_ON_WEB = ''T'' '
ELSE IF @Feature = 'WASTE_RECEIVED'
	SET @strSnippet = ' AND P.VIEW_WASTE_RECEIVED_ON_WEB = ''T'' '
ELSE IF @Feature = 'WORKORDERS'
	SET @strSnippet = ' AND P.VIEW_WORKORDERS_ON_WEB = ''T'' '
ELSE IF @Feature = 'WASTE_SUMMARY'
	SET @strSnippet = ' AND P.VIEW_WASTE_SUMMARY_ON_WEB = ''T'' '
ELSE IF @Feature = 'INVOICING'
	SET @strSnippet = ' AND C.VIEW_INVOICING_ON_WEB = ''T'' AND P.PROFIT_CTR_ID = (SELECT MIN(PROFIT_CTR_ID) FROM PROFITCENTER P2 WHERE P.COMPANY_ID = P2.COMPANY_ID AND P2.VIEW_ON_WEB IN (''P'', ''C''))'
ELSE IF @Feature = 'AGING'
	SET @strSnippet = ' AND C.VIEW_AGING_ON_WEB = ''T''  AND P.PROFIT_CTR_ID = (SELECT MIN(PROFIT_CTR_ID) FROM PROFITCENTER P2 WHERE P.COMPANY_ID = P2.COMPANY_ID AND P2.VIEW_ON_WEB IN (''P'', ''C''))'
ELSE IF @Feature = 'SURVEY'
	SET @strSnippet = ' AND C.VIEW_SURVEY_ON_WEB = ''T''  AND P.PROFIT_CTR_ID = (SELECT MIN(PROFIT_CTR_ID) FROM PROFITCENTER P2 WHERE P.COMPANY_ID = P2.COMPANY_ID AND P2.VIEW_ON_WEB IN (''P'', ''C''))'

SET @Order = ' ORDER BY P.Company_ID, P.Profit_ctr_ID '

-- Create a temp table to hold the databases
CREATE TABLE #tmp_database (
	database_name varchar(60),
	company_id int,
	profit_ctr_id int,
	process_flag int	)

IF @CompanyList IS NOT NULL AND LEN(@CompanyList) > 0
	EXEC sp_reports_list_database 0, @CompanyList
ELSE
	INSERT #tmp_database SELECT distinct '' as database_name, company_id, NULL as profit_ctr_id, 0 as process_flag
	FROM EQCONNECT

SET @execute_sql = @execute_sql + @strSnippet + @Order
SET NOCOUNT OFF

EXEC(@execute_sql)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profit_center_list_all_web] TO [guest]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profit_center_list_all_web] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profit_center_list_all_web] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_profit_center_list_all_web] TO [EQAI]
    AS [dbo];

