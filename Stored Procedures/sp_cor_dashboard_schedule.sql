-- drop proc sp_cor_dashboard_schedule
go

CREATE PROCEDURE sp_cor_dashboard_schedule
	@debug					int, 			-- 0 or 1 for no debug/debug mode
	@database_list			varchar(8000),	-- Comma Separated Company List 
	@customer_id_list		varchar(8000),	-- Comma Separated Customer ID List -  what customers to include
	@confirmation_id		varchar(8000),	-- Confirmation ID List
	@start_date				varchar(20),	-- Start Date
	@end_date				varchar(20),	-- End Date
	@contact_id				varchar(100),	-- Contact_id
	@scheduleInfo_Calender	Char(1),	-- Type T- Calendar  F- Disposal Schedule By Facility
	@generator_id_list varchar(max) ='' /* Added 2019-07-16 by AA */
AS

/********************
sp_cor_dashboard_schedule:

Returns the data for Schedules.

LOAD TO PLT_AI* on NTSQL1

select top 100 p.customer_id, x.contact_id, s.* from schedule s
inner join profile p on s.profile_id = p.profile_id
inner join contactxref x on p.generator_id = x.generator_id
where x.status = 'A' and x.web_access = 'A' and s.status = 'A' and p.curr_status_code = 'A'
and  exists (select 1 from contactxref x2 where x2.contact_id = x.contact_id and x2.type = 'C')
order by time_scheduled desc

sp_reports_schedule 1, ' 2|0', '2277', '', '1/9/2013', '11/1/2013', ''

SELECT * FROM contactxref where contact_id = 101261

   SELECT Distinct   s.company_id,   s.profit_ctr_id,   s.confirmation_ID,   case when s.approval_code = 'VARIOUS' then s.confirmation_id else null end as approved_confirmation_id,   s.time_scheduled,   s.quantity,   s.approval_code,   s.contact,   s.contact_company,   s.contact_fax,   s.load_type,   g.epa_id,   g.generator_name,   p.approval_desc,   s.contact_phone,   p.OTS_flag  
   FROM schedule s      inner join profile p on s.profile_id = p.profile_id      inner join #customer ct on p.customer_id = ct.customer_id      left outer join generator g on p.generator_id = g.generator_id     
   WHERE 1=1   AND (s.time_scheduled between coalesce(nullif('12/9/2000',''), s.time_scheduled) and coalesce(nullif('1/1/2013',''), s.time_scheduled) )      and s.status = 'A'    AND p.curr_status_code = 'A'   
   ORDER BY s.company_id, s.profit_ctr_id, s.time_scheduled     


sp_cor_dashboard_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '2492', '', '', '', -1
sp_cor_dashboard_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '2492', '', '12/1/2004', '12/31/2004', -1
sp_cor_dashboard_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '888888', '', '4/1/2003', '5/1/2003', -1
sp_cor_dashboard_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '70', '', '', '', -1
sp_cor_dashboard_schedule 0, ' 2|0', '70', '', '6/1/2006', '6/30/2006', -1
sp_cor_dashboard_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '5252', '', '', '', 536,'T' -- works with contact
sp_cor_dashboard_schedule 0, ' 2|0, 3|0, 12|0, 14|0, 14|4, 14|6, 14|12, 15|1, 15|2, 21|0, 22|0, 23|0, 24|0', '5252', '', '', '', 5361 -- won't work, wrong contact


**********************/
BEGIN

	declare @i_start_date datetime = convert(date, @start_date)
		, @i_end_date datetime = convert(date, @end_date)

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	CREATE TABLE #temp
	(
		company_id	int,
		profit_ctr_id	int,
		confirmation_ID	int,
		approved_confirmation_id	int,
		time_scheduled	datetime,
		quantity int,	
		approval_code nvarchar(100),
		customer_id	int ,
		contact	nvarchar(500),
		contact_company	nvarchar(500),
		contact_fax	nvarchar(100),
		load_type	char(1),
		generator_id	int,
		epa_id	nvarchar(100),
		generator_name	nvarchar(500),
		approval_desc	nvarchar(MAX),
		contact_phone	nvarchar(100),
		OTS_flag	char(1),
		name nvarchar(500),
	)


  INSERT INTO #temp
  EXEC sp_reports_schedule @debug, @database_list, @customer_id_list, @confirmation_id, @i_start_date, @i_end_date, @contact_id,@generator_id_list -- works with contact
  IF(@scheduleInfo_Calender='T')
  BEGIN
	SELECT name as facility_name,CAST(time_scheduled AS DATE) time_scheduled, count(quantity) no_of_loads FROM #temp group by name,CAST(time_scheduled AS DATE)
  END
  ELSE
  BEGIN
	SELECT name facility_name, count(quantity) no_of_loads FROM #temp group by name
  END
  DROP TABLE #temp
END
GO
grant execute on sp_cor_dashboard_schedule to cor_user
GO