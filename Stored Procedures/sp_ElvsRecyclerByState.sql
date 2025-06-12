/****** Object:  StoredProcedure [dbo].[sp_ElvsRecyclerByState]    Script Date: 4/11/2023 10:39:10 AM ******/
USE [PLT_AI]
GO

drop proc if exists [dbo].[sp_ElvsRecyclerByState]
GO

Create PROCEDURE [dbo].[sp_ElvsRecyclerByState] (					
	@state     varchar(3), 				
	@name      varchar(20) = null, 				
	@MailAddr  varchar(20) = null, 				
	@MailCity  varchar(20) = null, 				
	@MailZip   varchar(20) = null, 				
	@ShipAddr  varchar(20) = null, 				
	@ShipCity  varchar(20) = null, 				
	@ShipZip   varchar(20) = null,
	@Phone   varchar(20) = null,
	@omitlist  varchar(8000) = '',
	@search	   varchar(100) = null,
	@page	   int = 1,
	@perpage	int = 20,
	@sort		varchar(20) = 'recycler_name'
	
)					
AS					
/*
======================================================
 Description: Returns recycler information for display on the website in list format
 Parameters :
 Returns    :
 Requires   : *.PLT_AI.*

 Modified    Author            Notes
 ----------  ----------------  -----------------------
 03/23/2006  Jonathan Broome   Initial Development
 08/08/2007  JPB               add MailAddr, MailCity, MailZip, ShipAddr, ShipCity, ShipZip					
 08/13/2007  JPB               correctly handle apostrophes in inputs.					
						 JPB               GEM:6156.2  @name with Len(@name) = 1 is handled AS the first-letter of a name match only -- not found anyWHERE in the name.  This is to restore functionality WHERE clicking on a letter lists the recyclers that BEGIN  (AND only BEGIN ) with that letter.				
 08/20/2008  Chris Allen       - formatted
                               - return participation_flag; 
                                  previously this routine used this line (~154) : 			(IF r.participation_flag = ''N'' BEGIN ''N'' END ELSE BEGIN (CASE WHEN EXISTS (SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id) THEN ''T'' ELSE ''F'' END) END) AS participation_flag,			
                                  I changed to this line:       r.participation_flag
                               IMPORTANT NOTE: participation_flag (now) relies on trigger (tr_ElvsParticipationFlagUpdate) to maintain proper state					
                                               INSERTs or UPDATEs for participation_flag field only may be overridden.
 09/09/2008 Jonathan Broome - reversed the participation flag logic: Combined NVMSRP option with switches-received to determine participation per spec
					
 04/12/2023 Monish V		- Ticket 64109- For adding phone number search added new input param and search
							event

 04/17/2023 Monish V		- Ticket 64284- For adding Shipping state search added new input param and search
							event

							Testing						
							  sp_ElvsRecyclerByState '', '', '', '', '', '', '', '', 'WA'					
							  sp_ElvsRecyclerByState 'mi', 'r', '', '', '', '', '', '', ''					
							  sp_ElvsRecyclerByState '', 'wrec', '', '', '', '', '', '', ''					
							  sp_ElvsRecyclerByState '', 'wrec', '', 'springfield', '', '', '', '', ''					
							  sp_ElvsRecyclerByState '', '', '', 'bronx', '', '', '', '', ''					
							  sp_ElvsRecyclerByState '', '', '', '', '10466', '', '', '', ''					
							  sp_ElvsRecyclerByState '', '', '', '', '', '', 's city', '', ''					
							  sp_ElvsRecyclerByState 'all', '', 'Orquidia', '', '', '', '', '', ''					
							  sp_ElvsRecyclerByState 'all', '', '', 'Fitzg', ''					
							  sp_ElvsRecyclerByState 'all', 'a', '', '', '', '', '', '', '' 					
							  sp_ElvsRecyclerByState 'all', 'Z', '', '', '', '', '', '', ''		            			
							  
		sp_ElvsRecyclerByState 
			@state     ='all', 				
			@name       = 'A & B', 				
			@MailAddr  = '', 				
			@MailCity   = '', 				
			@MailZip    = '', 				
			@ShipAddr = '', 				
			@ShipCity = '', 				
			@ShipZip  = '', 				
			@omitlist = 'WA',
			@search	  = '',
			@page	  = 1,
			@perpage= 10,
			@sort	= ''

SELECT  * FROM    ElvsRecycler where recycler_name like '%  %'			
'Quality  Auto Repair & Sales', 'Fast Eddies Auto  Wreckers'
										  
====================================================== */


BEGIN

/*
-- DEBUG
declare 	@state     varchar(3) = 'all', 				
	@name      varchar(20) = null, 				
	@MailAddr  varchar(20) = null, 				
	@MailCity  varchar(20) = null, 				
	@MailZip   varchar(20) = null, 				
	@ShipAddr  varchar(20) = null, 				
	@ShipCity  varchar(20) = null, 				
	@ShipZip   varchar(20) = null, 				
	@omitlist  varchar(8000) = '',
	@search	   varchar(100) = null,
	@page	   int = 3,
	@perpage	int = 100,
	@sort		varchar(20) = 'recycler_name'

	select @search = 'A'
*/
  --------------------------------------------------------
  --Declare Variables
  --------------------------------------------------------
	SET nocount on					
	IF @name = '-all-' SET @name = ''					

  --------------------------------------------------------


  --------------------------------------------------------
  --Initialize Variables
  --------------------------------------------------------
	DECLARE @intcount int, @sql_SELECT varchar(8000), @sql_FROM varchar(8000), @sql_where varchar(8000)					
						
	DECLARE @sname      varchar(40), 					
			@sMailAddr  varchar(40), 			
			@sMailCity  varchar(40), 			
			@sMailZip   varchar(40), 			
			@sShipAddr  varchar(40), 			
			@sShipCity  varchar(40), 			
			@sShipZip   varchar(40),
			@sPhone   varchar(40),
			@ssearch	varchar(200),
			@spage		int,
			@sperpage	int,
			@ssort	varchar(40)

	
	select @search = '' where isnull(@search, '') = ''
	select @page	= 1 where isnull(@page, 1) <= 1
	select @perpage = 20 where isnull(@perpage, 0) = 0
	select @sort	= 'recycler_name' where isnull(@sort, '') = ''

						
	SET @sname = isnull(replace(replace(@name, '''', ''''''), ' ', '%'), '')		
	SET @sMailAddr = isnull(replace(replace(@MailAddr, '''', ''''''), ' ', '%'), '')				
	SET @sMailCity = isnull(replace(replace(@MailCity, '''', ''''''), ' ', '%'), '')					
	SET @sMailZip = isnull(replace(replace(@MailZip, '''', ''''''), ' ', '%'), '')			
	SET @sShipAddr = isnull(replace(replace(@ShipAddr, '''', ''''''), ' ', '%'), '')				
	SET @sShipCity = isnull(replace(replace(@ShipCity, '''', ''''''), ' ', '%'), '')
	SET @sShipZip = isnull(replace(replace(@ShipZip, '''', ''''''), ' ', '%'), '')
	SET @sPhone = isnull(replace(replace(@Phone, '''', ''''''), ' ', '%'), '')
	set @ssearch = isnull(replace(replace(@search, '''', ''''''), ' ', '%'), '')
	set @spage	= @page
	set @sperpage = @perpage
	set @ssort = isnull(replace(@sort, '''', ''''''), '')

	if @ssort not in (
			'recycler_name',			
			'mailing_address',			
			'mailing_city',			
			'mailing_state',			
			'mailing_zip_code',			
			'shipping_address',			
			'shipping_city',			
			'shipping_state',			
			'shipping_zip_code',			
			'phone',			
			'toll_free_phone',			
			'fax'
		) set @ssort = 'recycler_name'	
	
	

  --------------------------------------------------------

						
  --------------------------------------------------------
  -- Prepare data that will later become part of, or necessary to, the final result set
  --------------------------------------------------------
	-- declare @omitlist varchar(100) = 'IN'
  
	drop table if exists #1
  
	CREATE TABLE #1 (omitState char(2))					
						
	IF Len(@omitlist) > 0					
		insert #1
		select row
		from dbo.fn_SplitXsvText(',' ,1, @omitlist)
		WHERE row is not null


	SET nocount OFF					
  --------------------------------------------------------

	-- declare @ssort varchar(40) = 'recycler_name', @state varchar(3) = 'mi'
  
  -- Searches
	drop table if exists #s
	
	
	select r.recycler_id
    , _row = row_number() over (order by 
        case when @ssort = 'recycler_name' then ltrim(rtrim(r.recycler_name)) end asc,
        case when @ssort = 'mailing_address' then ltrim(rtrim(r.mailing_address)) end asc,
		case when @ssort = 'mailing_city' then ltrim(rtrim(r.mailing_city)) end asc,
		case when @ssort = 'mailing_state' then ltrim(rtrim(r.mailing_state)) end asc,			
		case when @ssort = 'mailing_zip_code' then ltrim(rtrim(r.mailing_zip_code)) end asc,			
		case when @ssort = 'shipping_address' then ltrim(rtrim(r.shipping_address)) end asc,			
		case when @ssort = 'shipping_city' then ltrim(rtrim(r.shipping_city)) end asc,			
		case when @ssort = 'shipping_state' then ltrim(rtrim(r.shipping_state)) end asc,			
		case when @ssort = 'shipping_zip_code' then ltrim(rtrim(r.shipping_zip_code)) end asc,			
		case when @ssort = 'phone' then ltrim(rtrim(r.phone)) end asc,			
		case when @ssort = 'toll_free_phone' then ltrim(rtrim(r.toll_free_phone)) end asc,			
		case when @ssort = 'fax' then ltrim(rtrim(r.fax)) end asc
		, r.recycler_name, r.recycler_id
    ) 
	into #s
	from elvsrecycler r
	WHERE 
	r.status = 'A'
	and r.shipping_state not in (SELECT omitState FROM #1)
	and (
		@state = 'all'
		or
		ltrim(rtrim(r.shipping_state)) = @state
	)		
	and (
		@sMailAddr = ''
		or
		r.mailing_address like '%' + @sMailAddr + '%'
	)				
	and (
		@sMailCity = ''
		or
		r.mailing_city like '%' + @sMailCity + '%'
	)				
	and (
		@sMailZip = ''
		or
		r.mailing_zip_code like '%' + @sMailZip + '%'
	)				
	and (
		@sShipAddr = ''
		or
		r.shipping_address like '%' + @sShipAddr + '%'
	)				
	and (
		@sShipCity = ''
		or
		r.shipping_city like '%' + @sShipCity + '%'
	)				
	and (
		@sShipZip = ''
		or
		r.shipping_zip_code like '%' + @sShipZip + '%'
	)
	and (
		@sPhone = ''
		or
		r.phone like '%' + @sPhone + '%'
	)
	and (
		@sname = ''
		or
		(
			@sname = 'numbers' 
			and
			left(ltrim(rtrim(r.recycler_name)),1) in ('0','1','2','3','4','5','6','7','8','9')
		)
		or
		(
			len(@sname) = 1
			and ltrim(rtrim(r.recycler_name)) like @sname + '%'
		)
		or
		(
			len(@sname) > 1
			and ltrim(rtrim(r.recycler_name)) like '%' + @sname + '%'
		)
	)
	and 
	(
		@ssearch = ''
		or
		isnull(r.recycler_name, '') + ' '
			+ isnull(r.mailing_address,	'') + ' '
			+ isnull(r.mailing_city,	'') + ' '
			+ isnull(r.mailing_state,	'') + ' '
			+ isnull(r.mailing_zip_code,	'') + ' '	
			+ isnull(r.shipping_address,	'') + ' '
			+ isnull(r.shipping_city,	'') + ' '
			+ isnull(r.shipping_state,	'') + ' '
			+ isnull(r.shipping_zip_code,	'') + ' '
			+ isnull(r.phone,	'') + ' '
		like '%' + @ssearch + '%'
	)	

		
			
  --------------------------------------------------------
  -- Prepare SELECT and return final result set
  --------------------------------------------------------
  drop table if exists #out
  
		SELECT				
			r.recycler_id,
			r.status,
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
			r.added_by,
			r.modified_by,
			r.date_added,
			r.date_modified,
			co.name,			
			IsNull(r.date_joined, (SELECT min(date_added) FROM ElvsContainer c WHERE c.recycler_id = r.recycler_id AND c.status = 'A')) AS date_joined,			
			r.website,			
			-- r.participation_flag,		-- JPB 9/9/2008 per spec...
			CASE WHEN r.participation_flag <> 'N' THEN
				CASE WHEN EXISTS (
					SELECT container_id FROM ElvsContainer WHERE recycler_id = r.recycler_id
				) THEN 'T' ELSE 'F' END
			ELSE
				r.participation_flag
			END as participation_flag,
			r.non_participation_reason,			
			r.vehicles_processed_annually,			
			(SELECT max(c.date_added) FROM ElvsContainer c WHERE c.recycler_id = r.recycler_id AND c.status = 'A') AS date_last_activity,			
			(SELECT IsNull(Sum(IsNull(c.container_weight,0)),0) FROM ElvsContainer c WHERE c.recycler_id = r.recycler_id AND c.status = 'A') AS total_weight_accepted,			
			
		total_weight_of_mercury =
			isnull(
				(
					SELECT 
						Sum(IsNull(quantity_received,0)) 
						FROM ElvsContainer c 
						WHERE c.recycler_id = r.recycler_id
						AND c.status = 'A'
				) * 0.0022
			, 0),
			
			s.bounty_flag,			
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
				(	SELECT Sum(IsNull(c.quantity_ineligible,0))	
					FROM ElvsContainer c	
					WHERE c.recycler_id = r.recycler_id	
					AND c.status = 'A'	
				)		
				,0) AS ineligible,		
			IsNull(			
				(	
					SELECT 
						/*Sum(IsNull(c.abs_count,0)) + Sum(IsNull(c.light_count,0)) + Sum(IsNull(c.misc_count,0))	*/
						sum(isnull(c.quantity_received,0) - isnull(c.quantity_ineligible,0))
					FROM ElvsContainer c	
					WHERE c.recycler_id = r.recycler_id	
					AND c.status = 'A'	
				)		
				,0) AS total_switches_accepted,		
			s.vin_required,			
			s.vin_based_switch_count,			
			s.switches_per_abs_assembly,			
			s.show_detail_or_total,			
			0 AS s_order ,
			z._row
			into #out
			from #s z
			join ElvsRecycler r	on z.recycler_id = r.recycler_id
			LEFT OUTER JOIN ElvsState s on r.shipping_state = s.state			
			LEFT OUTER JOIN contact co on r.contact_id = co.contact_id 
			
SELECT  * 
, @@rowcount as total_rows
FROM    #out 
WHERE 
_row between ((@spage-1) * @sperpage ) + 1 and (@spage * @sperpage) 
order by _row
--------------------------------------------------------
						
						

END -- CREATE PROCEDURE sp_ElvsRecyclerByState

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerByState] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerByState] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerByState] TO [EQAI]
    AS [dbo];USE [PLT_AI]
GO
