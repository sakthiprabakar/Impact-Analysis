--
drop proc if exists sp_ElvsRecyclerInfo
go

CREATE PROCEDURE sp_ElvsRecyclerInfo (
  @id int, 
  @omitlist varchar(8000) = '')					
AS					
/* ======================================================
 Description: Returns recycler information for display on the website in detail format
 Parameters :
 Returns    :
 Requires   : *.PLT_AI.*

 Modified    Author            Notes
 ----------  ----------------  -----------------------
 03/23/2006  Jonathan Broome   Initial Development
 08/20/2008  Chris Allen       - formatted
                               - return participation_flag (w/o hard coded T or F and without using subquery;) 
                                   previously this routine used this line (~88) : (CASE WHEN EXISTS (SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id) THEN 'T' ELSE 'F' END) AS participation_flag,				
                                   I changed to this line:       r.participation_flag
                                   participation_flag (now) relies on trigger (tr_ElvsParticipationFlagUpdate) to maintain proper state					
                               - return AirbagSensor, quantity_ineligible 
                               - return sums that include AirbagSensor, quantity_ineligible 
 09/09/2008 Jonathan Broome - reversed the participation flag logic: Combined NVMSRP option with switches-received to determine participation per spec
 06/29/2022 JPB - Added total_weight_of_mercury output                         



 									sp_ElvsRecyclerInfo 400					
 									sp_ElvsRecyclerInfo 1483					
====================================================== */
BEGIN
	SET nocount on					
						
	DECLARE @intcount int					
						
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
						
	SELECT					
		r.recycler_id,				
		r.status,
		case when r.status in ('I') then 'Deleted' else 'Active' end as deleted_flag,				
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
		r.phone,				
		r.toll_free_phone,				
		r.fax,				
		r.contact_info,				
		r.email_address,				
		co.name,				
		r.county,				
		r.contact_id,				
		IsNull(r.date_joined, (SELECT min(date_added) FROM ElvsContainer c WHERE c.recycler_id = r.recycler_id AND c.status = 'A')) AS date_joined,				
		r.website,				

    --BEG 08/22/08 CMA Added (below)
	--    r.participation_flag, --08/22/08 CMA Added (and removed line now left in notes section)
		CASE WHEN r.participation_flag <> 'N' THEN
			CASE WHEN EXISTS (
				SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id
			) THEN 'T' ELSE 'F' END
		ELSE
			r.participation_flag
		END as participation_flag_tf,
		participation_flag,
		IsNull(				
			(	SELECT Sum(IsNull(c.AirbagSensor,0))		
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS AirbagSensor,			
		IsNull(				
			(	SELECT Sum(IsNull(c.quantity_ineligible,0))		
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS quantity_ineligible,			
    --END 08/22/08 CMA Added (above)

		r.non_participation_reason,				
		r.vehicles_processed_annually,				
		(SELECT max(c.date_added) FROM ElvsContainer c WHERE c.recycler_id = r.recycler_id AND c.status = 'A') AS date_last_activity,				
		IsNull((SELECT Sum(c.container_weight) FROM ElvsContainer c WHERE c.recycler_id = r.recycler_id AND c.status = 'A'),0) AS total_weight_accepted,				
		r.date_added,				
		r.added_by,				
		r.date_modified,				
		r.modified_by,				
		s.vin_required,				
		s.vin_based_switch_count,				
		s.switches_per_abs_assembly,				
		s.show_detail_or_total,				
		IsNull(				
			(	SELECT Sum(IsNull(c.abs_assembly_count,0))		
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS abs_assemblies_accepted,			
		IsNull(				
			(	SELECT Sum(IsNull(c.abs_count,0))		
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS abs_accepted,			
		IsNull(				
			(	SELECT Sum(IsNull(c.light_count,0))		
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS light_accepted,			
		IsNull(				
			(	SELECT Sum(IsNull(c.misc_count,0))		
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS misc_accepted,			
		IsNull(				
			(	SELECT Sum(IsNull(c.abs_count,0)) + Sum(IsNull(c.light_count,0)) + Sum(IsNull(c.misc_count,0)) + Sum(IsNull(c.AirbagSensor,0)) + Sum(IsNull(c.quantity_ineligible,0))	--08/22/08 CMA Added AirbagSensor	
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS total_switches_accepted,
			IsNull(				
			(	SELECT Sum(IsNull(c.abs_count,0)) + Sum(IsNull(c.light_count,0)) + Sum(IsNull(c.misc_count,0)) + Sum(IsNull(c.AirbagSensor,0)) + Sum(IsNull(c.quantity_ineligible,0))	--08/22/08 CMA Added AirbagSensor	
				FROM ElvsContainer c		
				WHERE c.recycler_id = r.recycler_id		
				AND c.status = 'A'		
			)			
			,0) AS switches_received,
		isnull(
			(
				SELECT 
					Sum(IsNull(quantity_received,0)) 
					FROM ElvsContainer c 
					WHERE c.recycler_id = r.recycler_id
					AND c.status = 'A'
			) * 0.0022
			, 0) as total_weight_of_mercury
	FROM					
		ElvsRecycler r				
		LEFT OUTER JOIN contact co on r.contact_id = co.contact_id				
		LEFT OUTER JOIN ElvsState s on r.shipping_state = s.state				
	WHERE					
		recycler_id = @id				
		AND r.shipping_state not in (SELECT omitState FROM #1)				
	order by					
		r.recycler_name, r.shipping_state				

END -- CREATE PROCEDURE sp_ElvsRecyclerInfo

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerInfo] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerInfo] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerInfo] TO [EQAI]
    AS [dbo];

