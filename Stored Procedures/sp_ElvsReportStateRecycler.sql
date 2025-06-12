drop proc if exists sp_ElvsReportStateRecycler 
go

CREATE PROCEDURE sp_ElvsReportStateRecycler (			
	@recycler_name	varchar(40) = NULL,	
	@city		varchar(40) = NULL,
	@state		char(2) = NULL,
	@zip_code	varchar(15) = NULL,	
	@startDate	varchar(40) = NULL,	
	@endDate	varchar(40) = NULL,	
	@omitlist varchar(8000) = '' --09/04/08 CMA Added per JPB	
)			
AS			
--======================================================
-- Description: Report on Elvs Data: By State, THEN by Recycler
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome  Initial Development
-- 04/10/2007  JPB 					    Added mailing_* AND shipping_* for address fields			
-- 12/08/2007  JPB 					    Added '(Out Of Scope Items)' fake state last in the list			
-- 08/25/2008  Chris Allen      - return participation_flag (w/o hard coded T or F and without using subquery;) 
--                                   previously this routine used this line (~88) : (CASE WHEN EXISTS (SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id) THEN 'T' ELSE 'F' END) AS participation_flag,				
--                                   I changed to this line:       r.participation_flag
--                                   participation_flag (now) relies on trigger (tr_ElvsParticipationFlagUpdate) to maintain proper state					
--                              - return AirbagSensor, quantity_ineligible 
--                              - return sums that include AirbagSensor, quantity_ineligible 
--                              - Formatted
-- 09/04/2008 CMA               - added as parameter @OmitList Added per JPB	
-- 09/05/2008 CMA               - per GID 6907: removed partial condition so returned results are by mailing state only (prior returned shipping OR mailing state) 
-- 09/09/2008 JPB               - reversed previous code: should select by shipping state, not mailing state - says Mary
--					- revised participation_flag logic to combine NVMSRP logic with old switches-received logic
-- 06/06/2016 JPB				 Added country_code to StateAbbreviation query
--
--             Testing
--					      sp_ElvsReportStateRecycler '', '', '', '', '', ''			
--					      sp_ElvsReportStateRecycler 'wrec', '', '', '', '5/1/2006', '6/1/2006'			
--======================================================
BEGIN
  -------------------------------------------------
  -- Break apart the omitlist to create a new list of states
  -------------------------------------------------
	DECLARE @intcount int					
  SET nocount ON						

	CREATE TABLE #1 (omitState char(2))					
						
	IF Len(@omitlist) > 0					
	BEGIN  					
		/* Check to see IF the number parser table exists, create IF necessary */				
		SELECT @intCount = Count(*) FROM syscolumns c INNER JOIN sysobjects o on o.id = c.id AND o.name = 'tblToolsStringParserCounter' AND c.name = 'ID'				
		IF @intCount = 0				
		BEGIN  				
			CREATE TABLE tblToolsStringParserCounter (			
				ID	int	)
						
			DECLARE @i INT			
			SELECT  @i = 1			
						
			WHILE (@i <= 8000)			
			BEGIN  			
				INSERT INTO tblToolsStringParserCounter SELECT @i		
				SELECT @i = @i + 1		
			END			
		END				
						
		/* INSERT the generator_id_list data INTO a temp table for use later */				
		INSERT INTO #1				
		SELECT  NULLIF(SUBSTRING(',' + @omitlist + ',' , ID ,				
			CHARINDEX(',' , ',' + @omitlist + ',' , ID) - ID) , '') AS omitState			
		FROM tblToolsStringParserCounter				
		WHERE ID <= Len(',' + @omitlist + ',') AND SUBSTRING(',' + @omitlist + ',' , ID - 1, 1) = ','				
		AND CHARINDEX(',' , ',' + @omitlist + ',' , ID) - ID > 0				
	END					
	SET nocount OFF					
  -------------------------------------------------


	--08/25/08 CMA removed (default declared in parameter list) IF @recycler_name = '' SET @recycler_name = NULL			

	IF @city = '' SET @city = NULL			
	IF @state = '' SET @state = NULL			
	IF @zip_code = '' SET @zip_code = NULL			
	IF @startDate = '' SET @startDate = NULL			
	IF @endDate = '' SET @endDate = NULL			
				
	SELECT			
		s.state_name,		
		r.recycler_id,		
		r.parent_company,		
		r.recycler_name,		
		r.mailing_address,		
		r.mailing_city,		
		r.mailing_state,		
		r.mailing_zip_code,		
		r.shipping_address,		
		r.shipping_city,		
		r.shipping_state,		
		r.shipping_zip_code,		
		r.contact_info,		
		r.email_address,		
		r.phone,		
		r.toll_free_phone,		
		r.fax,		
		co.name,		
		r.website,		
		--BEG 08/25/08 CMA Added (4 lines below) Removed c.quantity_received, (CASE WHEN EXISTS (SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id) THEN 'T' ELSE 'F' END) AS participation_flag,		
		-- r.participation_flag,		-- JPB 9/9/2008 per spec...
		CASE WHEN r.participation_flag <> 'N' THEN
			CASE WHEN EXISTS (
				SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id
			) THEN 'T' ELSE 'F' END
		ELSE
			r.participation_flag
		END as participation_flag,
		c.AirbagSensor,		
		c.misc_count,		
		Sum(IsNull(c.abs_count,0)) + Sum(IsNull(c.light_count,0)) + Sum(IsNull(c.misc_count,0)) + Sum(IsNull(c.AirbagSensor,0)) + Sum(IsNull(c.quantity_ineligible,0)) AS total_switches_accepted,					
  	--END 08/25/08 CMA Added (above)			
		c.container_id,		
		c.date_received,		
		c.light_count,		
		c.abs_count,		
		c.quantity_ineligible,		
		s.orderby		
	FROM			
		ElvsContainer c		
		INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'		
		INNER JOIN ElvsState es on r.shipping_state = es.state		
		INNER JOIN (SELECT state_name, abbr, 0 AS orderby FROM StateAbbreviation where country_code = 'USA' UNION SELECT '(Out Of Scope Items)', 'Z', 1)  s on r.shipping_state = s.abbr		
		LEFT OUTER JOIN contact co on r.contact_id = co.contact_id		
	WHERE c.status = 'A'			
		AND r.recycler_name = CASE WHEN @recycler_name is NULL THEN r.recycler_name ELSE @recycler_name END		
		AND (r.mailing_city = CASE WHEN @city is NULL THEN r.mailing_city ELSE @city END)				-- 09/05/08 CMA Removed per GID 6907 OR r.shipping_city = CASE WHEN @city is NULL THEN r.shipping_city ELSE @city END)		
		AND (r.shipping_state = CASE WHEN @state is NULL THEN r.shipping_state ELSE @state END)				-- 09/05/08 CMA Removed per GID 6907 OR r.shipping_state = CASE WHEN @state is NULL THEN r.shipping_state ELSE @state END)		
		AND (r.mailing_zip_code = CASE WHEN @zip_code is NULL THEN r.mailing_zip_code ELSE @zip_code END)				-- 09/05/08 CMA Removed per GID 6907 OR r.shipping_zip_code = CASE WHEN @zip_code is NULL THEN r.shipping_zip_code ELSE @zip_code END)		
		AND c.date_received >= CASE WHEN IsDate(@startDate) = 0 THEN '1899-01-01' ELSE @startDate + ' 00:00:00.000' END		
		AND c.date_received <= CASE WHEN IsDate(@endDate) = 0 THEN '2100-01-01' ELSE @endDate + ' 23:59:59:998' END		
		AND r.shipping_state not in (SELECT omitState FROM #1)	 --09/04/08 CMA Added 	
	--BEG 08/25/08 CMA Added GROUP BY (below)
  GROUP BY
		s.state_name,		
		r.recycler_id,		
		r.parent_company,		
		r.recycler_name,		
		r.mailing_address,		
		r.mailing_city,		
		r.mailing_state,		
		r.mailing_zip_code,		
		r.shipping_address,		
		r.shipping_city,		
		r.shipping_state,		
		r.shipping_zip_code,		
		r.contact_info,		
		r.email_address,		
		r.phone,		
		r.toll_free_phone,		
		r.fax,		
		co.name,		
		r.website,		
    r.participation_flag,		
		c.AirbagSensor,		
		c.misc_count,		
    c.container_id,		
		c.date_received,		
		c.light_count,		
		c.abs_count,		
		c.quantity_ineligible,		
		s.orderby		
	--END 08/25/08 CMA Added GROUP BY (above)
	UNION			
	SELECT			
		s.state_name,		
		r.recycler_id,		
		r.parent_company,		
		r.recycler_name,		
		r.mailing_address,		
		r.mailing_city,		
		r.mailing_state,		
		r.mailing_zip_code,		
		r.shipping_address,		
		r.shipping_city,		
		r.shipping_state,		
		r.shipping_zip_code,		
		r.contact_info,		
		r.email_address,		
		r.phone,		
		r.toll_free_phone,		
		r.fax,		
		co.name,		
		r.website,		
		--BEG 08/25/08 CMA Added (4 lines below) Removed c.quantity_received, (CASE WHEN EXISTS (SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id) THEN 'T' ELSE 'F' END) AS participation_flag,		
		-- r.participation_flag,		-- JPB 9/9/2008 per spec...
		CASE WHEN r.participation_flag <> 'N' THEN
			CASE WHEN EXISTS (
				SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id
			) THEN 'T' ELSE 'F' END
		ELSE
			r.participation_flag
		END as participation_flag,
		c.AirbagSensor,		
		c.misc_count,		
		Sum(IsNull(c.abs_count,0)) + Sum(IsNull(c.light_count,0)) + Sum(IsNull(c.misc_count,0)) + Sum(IsNull(c.AirbagSensor,0)) + Sum(IsNull(c.quantity_ineligible,0)) AS total_switches_accepted,					
  	--END 08/25/08 CMA Added (above)			
    c.container_id,		
		c.date_received,		
		c.light_count,		
		c.abs_count,		
		c.quantity_ineligible,		
		s.orderby		
	FROM			
		ElvsContainer c		
		INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'		
		INNER JOIN ElvsState es on r.shipping_state = es.state		
		INNER JOIN (SELECT state_name, abbr, 0 AS orderby FROM StateAbbreviation where country_code = 'USA' UNION SELECT '(Out Of Scope Items)', 'Z', 1) s on r.shipping_state = s.abbr		
		LEFT OUTER JOIN contact co on r.contact_id = co.contact_id		
	WHERE c.status = 'A'			
		AND r.recycler_name like '%' + CASE WHEN @recycler_name is NULL THEN r.recycler_name ELSE @recycler_name END + '%'		
		AND (r.mailing_city = CASE WHEN @city is NULL THEN r.mailing_city ELSE @city END)				-- 09/05/08 CMA Removed per GID 6907 OR r.shipping_city = CASE WHEN @city is NULL THEN r.shipping_city ELSE @city END)		
		AND (r.shipping_state = CASE WHEN @state is NULL THEN r.shipping_state ELSE @state END)				-- 09/05/08 CMA Removed per GID 6907 OR r.shipping_state = CASE WHEN @state is NULL THEN r.shipping_state ELSE @state END)		
		AND (r.mailing_zip_code = CASE WHEN @zip_code is NULL THEN r.mailing_zip_code ELSE @zip_code END)				-- 09/05/08 CMA Removed per GID 6907 OR r.shipping_zip_code = CASE WHEN @zip_code is NULL THEN r.shipping_zip_code ELSE @zip_code END)		
		AND c.date_received >= CASE WHEN IsDate(@startDate) = 0 THEN '1899-01-01' ELSE @startDate + ' 00:00:00.000' END		
		AND c.date_received <= CASE WHEN IsDate(@endDate) = 0 THEN '2100-01-01' ELSE @endDate + ' 23:59:59:998' END		
		AND r.shipping_state not in (SELECT omitState FROM #1)	 --09/04/08 CMA Added 	
	--BEG 08/25/08 CMA Added GROUP BY (below)
  GROUP BY
		s.state_name,		
		r.recycler_id,		
		r.parent_company,		
		r.recycler_name,		
		r.mailing_address,		
		r.mailing_city,		
		r.mailing_state,		
		r.mailing_zip_code,		
		r.shipping_address,		
		r.shipping_city,		
		r.shipping_state,		
		r.shipping_zip_code,		
		r.contact_info,		
		r.email_address,		
		r.phone,		
		r.toll_free_phone,		
		r.fax,		
		co.name,		
		r.website,		
    r.participation_flag,		
		c.AirbagSensor,		
		c.misc_count,		
    c.container_id,		
		c.date_received,		
		c.light_count,		
		c.abs_count,		
		c.quantity_ineligible,		
		s.orderby		
	--END 08/25/08 CMA Added GROUP BY (above)

	ORDER BY s.orderby, s.state_name, r.recycler_name, c.date_received		

END -- CREATE PROCEDURE sp_ElvsReportStateRecycler

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsReportStateRecycler] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsReportStateRecycler] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsReportStateRecycler] TO [EQAI]
    AS [dbo];
