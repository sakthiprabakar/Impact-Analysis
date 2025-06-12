CREATE PROCEDURE sp_ElvsReportStateMake (						
	@recycler_name			varchar(40) = NULL,		
	@city					varchar(40) = NULL,
	@state					char(2) = NULL,
	@zip_code				varchar(15) = NULL,	
	@startDate				datetime = NULL,	
	@endDate				datetime = NULL	
)						
AS						
--======================================================
-- Description: Report on Elvs Data: By State, THEN by Vehicle Make
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 04/10/2007  JPB 					     Added mailing_* AND shipping_* for address fields						
--											         Note: Misc_ switches are intentionally left out - ELVS doesn't pay for them.						
-- 08/25/2008  Chris Allen       Formatted
-- 06/06/2016 JPB				 Added country_code to StateAbbreviation query
--
--								sp_ElvsReportStateMake '', '', '', '', '', ''						
--======================================================
BEGIN
	IF @recycler_name = '' SET @recycler_name = NULL						
	IF @city = '' SET @city = NULL						
	IF @state = '' SET @state = NULL						
	IF @zip_code = '' SET @zip_code = NULL						
	IF @startDate = '' SET @startDate = NULL						
	IF @endDate = '' SET @endDate = NULL						
							
	SELECT distinct						
			s.state_name,				
			d.make,				
			Sum(IsNull(d.abs_switches, 0) + IsNull(d.light_switches,0)) AS total				
	FROM						
		ElvsContainer c					
		INNER JOIN ElvsContainerDetail d on c.container_id = d.container_id AND d.passed_validation = 'T'					
		INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'					
		INNER JOIN StateAbbreviation s on r.shipping_state = s.abbr	and s.country_code = 'USA'
	WHERE c.status = 'A' AND d.make is not NULL						
		AND r.recycler_name = CASE WHEN @recycler_name is NULL THEN r.recycler_name ELSE @recycler_name END					
		AND (r.mailing_city = CASE WHEN @city is NULL THEN r.mailing_city ELSE @city END or r.shipping_city = CASE WHEN @city is NULL THEN r.shipping_city ELSE @city END)					
		AND (r.mailing_state = CASE WHEN @state is NULL THEN r.mailing_state ELSE @state END or r.shipping_state = CASE WHEN @state is NULL THEN r.shipping_state ELSE @state END)					
		AND (r.mailing_zip_code = CASE WHEN @zip_code is NULL THEN r.mailing_zip_code ELSE @zip_code END or r.shipping_zip_code = CASE WHEN @zip_code is NULL THEN r.shipping_zip_code ELSE @zip_code END)					
		AND c.date_received between CASE WHEN @startDate is NULL THEN c.date_received ELSE @startDate END AND CASE WHEN @endDate is NULL THEN c.date_received ELSE @endDate END					
	GROUP BY s.state_name, d.make						
	UNION						
	SELECT distinct						
			s.state_name,				
			d.make,				
			Sum(IsNull(d.abs_switches, 0) + IsNull(d.light_switches,0)) AS total				
	FROM						
		ElvsContainer c					
		INNER JOIN ElvsContainerDetail d on c.container_id = d.container_id AND d.passed_validation = 'T'					
		INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'					
		INNER JOIN StateAbbreviation s on r.shipping_state = s.abbr	and s.country_code = 'USA'
	WHERE c.status = 'A' AND d.make is not NULL						
		AND r.recycler_name like '%' + CASE WHEN @recycler_name is NULL THEN r.recycler_name ELSE @recycler_name END + '%'					
		AND (r.mailing_city like '%' +  CASE WHEN @city is NULL THEN r.mailing_city ELSE @city END + '%' or r.shipping_city like '%' +  CASE WHEN @city is NULL THEN r.shipping_city ELSE @city END + '%')					
		AND (r.mailing_state like '%' +  CASE WHEN @state is NULL THEN r.mailing_state ELSE @state END + '%' or r.shipping_state like '%' +  CASE WHEN @state is NULL THEN r.shipping_state ELSE @state END + '%')					
		AND (r.mailing_zip_code like '%' +  CASE WHEN @zip_code is NULL THEN r.mailing_zip_code ELSE @zip_code END + '%' or r.shipping_zip_code like '%' +  CASE WHEN @zip_code is NULL THEN r.shipping_zip_code ELSE @zip_code END + '%')					
		AND c.date_received between CASE WHEN @startDate is NULL THEN c.date_received ELSE @startDate END AND CASE WHEN @endDate is NULL THEN c.date_received ELSE @endDate END					
	GROUP BY s.state_name, d.make						
	ORDER BY state_name, make						

END -- CREATE PROCEDURE sp_ElvsReportStateMake

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsReportStateMake] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsReportStateMake] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsReportStateMake] TO [EQAI]
    AS [dbo];

