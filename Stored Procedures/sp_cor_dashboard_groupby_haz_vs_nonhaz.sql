-- drop proc if exists sp_cor_dashboard_groupby_haz_vs_nonhaz
go

CREATE PROCEDURE [dbo].[sp_cor_dashboard_groupby_haz_vs_nonhaz]
	@web_userid		varchar(100)
	, @date_start	datetime = null
	, @date_end		datetime = null
	, @customer_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
	, @generator_id_list varchar(max)  =''/* Added 2019-07-23 by AA */
	, @pounds_or_tons	char(1) = 'T'  /* 'P'ounds or 'T'ons */
AS
/* ********************************************************************
sp_cor_dashboard_groupby_haz_vs_nonhaz

	  Returns RCRA Haz vs NonHaz waste totals

07/20/2021 DO:17669 - Added Pounds/Tons option

Samples:
sp_cor_dashboard_groupby_haz_vs_nonhaz
	@web_userid = 'nyswyn100'
	, @date_start = '1/1/2019'
	, @date_end = '1/1/2022'
	, @pounds_or_tons = 'P'

	
******************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

CREATE TABLE #temp
(
  contact_id	int,
  [year] int,
  [month] int,
  haz_flag	char(1),
  tons	float,
  [rank] int
)

CREATE TABLE #temp1
(
  contact_id	int,
  [year] int,
  [month] int,
  haz_value	float,
  non_haz_value	float,
  unit varchar(10) 
)


INSERT INTO #temp
EXEC sp_cor_dashboard_haz_vs_nonhaz @web_userid, @date_start,@date_end,@customer_id_list,@generator_id_list

INSERT INTO #temp1(contact_id,[year],[month])
SELECT 
contact_id,[year],[month] from #temp group by  contact_id,[year],[month]

/* BAD: You can't inner join when you may not have a record
UPDATE #temp1 
SET
  #temp1.haz_value = #temp.tons,
  #temp1.non_haz_value = #temp2.tons
FROM
  #temp1
INNER JOIN #temp ON #temp1.[month] = #temp.[month] AND #temp.haz_flag = 'T'
INNER JOIN #temp  #temp2 ON #temp2.[month] = #temp.[month] AND #temp2.haz_flag = 'F'

Better:
*/
UPDATE #temp1 
SET
  haz_value = isnull(haz.tons, 0),
  non_haz_value = isnull(nonhaz.tons, 0),
  unit = 'Tons'
  -- select t.*, isnull(haz.tons, 0) haz_tons, isnull(nonhaz.tons, 0) nonhaz_tons
FROM
  #temp1 t
left JOIN #temp haz ON t.[year] = haz.[year] and t.[month] = haz.[month] AND haz.[haz_flag] = 'T'
left JOIN #temp nonhaz ON t.[year] = nonhaz.[year] and t.[month] = nonhaz.[month] AND nonhaz.[haz_flag] = 'F'

if @pounds_or_tons = 'P'
	update #temp1 set 
	haz_value = haz_value * 2000.00
	,non_haz_value = non_haz_value * 2000.00
	,unit = 'Pounds'

SELECT *  FROM #temp1
DROP TABLE #temp1
DROP TABLE #temp
END
GO
grant execute on [sp_cor_dashboard_groupby_haz_vs_nonhaz] to cor_user
go
