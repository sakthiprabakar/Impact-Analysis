/*

DO-42670 - ELVS Container Lookup - add paging

*/

use plt_ai
go

drop PROC if exists sp_ElvsContainerLookup 
go

CREATE PROCEDURE [dbo].[sp_ElvsContainerLookup] (				
	@recycler_name	varchar(40) = '',		
	@start_date		datetime = null,	
	@end_date		datetime = null,	
	@container_id	int = null,		
	@label			varchar(30) = '',
	@vin			varchar(20) = '',
	@page			bigint = 1,
	@perpage		bigint = 20,
	@sortby			varchar(100) = null
)				
AS				
/*
======================================================
 Description: Finds containers for re-editing
 Parameters :
 Returns    :
 Requires   : *.PLT_AI.*

 Modified    Author            Notes
 ----------  ----------------  -----------------------
 03/23/2006  Jonathan Broome   Initial Development
 08/25/2008  Chris Allen       Formatted
 09/05/2008  Chris Allen       Fixed to return proper quantity_received AS items



 Testing
	sp_ElvsContainerLookup '', '', '', NULL, '', ''				
	sp_ElvsContainerLookup '', '4/1/06', '5/1/06', NULL, '', ''				
	sp_ElvsContainerLookup '', '', '', 42, '', ''				

	exec sp_ElvsContainerLookup 
		@recycler_name	/* varchar(40),			*/ = ''
		,@start_date		/* datetime,		*/ = '1/1/2020'
		,@end_date		/* datetime,			*/ = '7/1/2022'
		,@container_id	/* int,					*/ = null
		,@label			/* varchar(30),			*/ = ''
		,@vin			/* varchar(20),			*/ = ''
		,@page			/* bigint = 1,			*/ = 1
		,@perpage		/* bigint = 20,			*/ = 200
		,@sortby			/* varchar(100) = null	*/ = 'recycler_name'
				

--======================================================
*/

BEGIN
	IF Len(@start_date) = 0 AND Len(@end_date) > 0 SET @start_date = @end_date			
	IF Len(@end_date) = 0 AND Len(@start_date) > 0 SET @end_date = @start_date			
	IF Len(@start_date) = 0 SET @start_date = '1/1/1900'			
	IF @end_date = '1/1/1900' SET @end_date = '1/1/2100'			
	SET @end_date = @end_date + ' 23:59:59.998'
	IF @container_id = '' SET @container_id = NULL

	declare 
		@i_page			bigint = isnull(@page,1),
		@i_perpage		bigint = isnull(@perpage, 20),
		@isortby		varchar(100) = isnull(@sortby, 'recycler_name')

	drop table if exists #tmp
				
	SELECT			
		c.container_id,		
		c.container_label,		
		c.date_received,		
		r.recycler_id,		
		r.recycler_name,
		r.mailing_address,
		r.mailing_city,
		r.mailing_state,
		r.mailing_zip_code,
		r.shipping_address,
		r.shipping_city,
		r.shipping_state,
		r.shipping_zip_code,
		r.Phone,
		r.contact_info,
		r.parent_company,
		r.email_address,
		r.date_joined,
		c.added_by,
		d.vin,
		--09/05/08 CMA Changed to (below) (SELECT Count(container_id) FROM ElvsContainerDetail WHERE container_id = c.container_id) AS items,		
		quantity_received AS items, --(SELECT SUM(quantity_received) FROM ElvsContainer WHERE r.recycler_id = ElvsContainer.recycler_id GROUP BY ElvsContainer.container_id) AS items,		
		0 AS s_order,		
		_rowpre = 0 + row_number() over ( order by
			case when @isortby = 'recycler_name' then r.recycler_name end asc,
			case when @isortby = 'container_id' then c.container_id end desc,
			case when @isortby = 'date_received' then c.date_received end desc
			, date_received desc
		)
	into #tmp
	FROM			
		ElvsContainer c		
		INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A' AND c.status = 'A'		
		LEFT OUTER JOIN ElvsContainerDetail d on c.container_id = d.container_id		
	WHERE			
		IsNull(r.recycler_name, '') = CASE WHEN @recycler_name = '' THEN IsNull(r.recycler_name, '') ELSE @recycler_name END		
		AND c.date_received between @start_date AND @end_date		
		AND c.container_id = CASE WHEN @container_id is NULL THEN c.container_id ELSE @container_id END		
		AND IsNull(c.container_label, '') = CASE WHEN @label = '' THEN IsNull(c.container_label, '') ELSE @label END		
		AND IsNull(d.vin, '') = CASE WHEN @vin = '' THEN IsNull(d.vin, '') ELSE @vin END		
	UNION			
	SELECT			
		c.container_id,		
		c.container_label,		
		c.date_received,		
		r.recycler_id,		
		r.recycler_name,
		r.mailing_address,
		r.mailing_city,
		r.mailing_state,
		r.mailing_zip_code,
		r.shipping_address,
		r.shipping_city,
		r.shipping_state,
		r.shipping_zip_code,
		r.Phone,
		r.contact_info,
		r.parent_company,
		r.email_address,
		r.date_joined,
		c.added_by,	
		d.vin,
		--09/05/08 CMA Changed to (below) (SELECT Count(container_id) FROM ElvsContainerDetail WHERE container_id = c.container_id) AS items,		
		quantity_received AS items, --(SELECT SUM(quantity_received) FROM ElvsContainer WHERE r.recycler_id = ElvsContainer.recycler_id GROUP BY .container_id) AS items,		
		1 AS s_order,
		_rowpre = 1000000 + row_number() over ( order by
			case when @isortby = 'recycler_name' then r.recycler_name end asc,
			case when @isortby = 'container_id' then c.container_id end desc,
			case when @isortby = 'date_received' then c.date_received end desc
			, date_received desc
		)
	FROM			
		ElvsContainer c		
		INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A' AND c.status = 'A'	
		LEFT OUTER JOIN ElvsContainerDetail d on c.container_id = d.container_id		
	WHERE			
		IsNull(r.recycler_name, '') like '%' + CASE WHEN @recycler_name = '' THEN IsNull(r.recycler_name, '') ELSE @recycler_name END + '%'		
		AND c.date_received between @start_date AND @end_date		
		AND c.container_id = CASE WHEN @container_id is NULL THEN c.container_id ELSE @container_id END		
		AND IsNull(c.container_label, '') like '%' + CASE WHEN @label = '' THEN IsNull(c.container_label, '') ELSE @label END + '%'		
		AND IsNull(d.vin, '') like '%' + CASE WHEN @vin = '' THEN IsNull(d.vin, '') ELSE @vin END + '%'		
		AND c.container_id not in (		
			SELECT	
				c.container_id
			FROM	
				ElvsContainer c
				INNER JOIN ElvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'
				LEFT OUTER JOIN ElvsContainerDetail d on c.container_id = d.container_id
			WHERE	
				IsNull(r.recycler_name, '') = CASE WHEN @recycler_name = '' THEN IsNull(r.recycler_name, '') ELSE @recycler_name END
				AND c.date_received between @start_date AND @end_date
				AND c.container_id = CASE WHEN @container_id is NULL THEN c.container_id ELSE @container_id END
				AND IsNull(c.container_label, '') = CASE WHEN @label = '' THEN IsNull(c.container_label, '') ELSE @label END
				AND IsNull(d.vin, '') = CASE WHEN @vin = '' THEN IsNull(d.vin, '') ELSE @vin END
		)		

		
	declare @total_rows bigint
	
	select
		container_id,		
		container_label,		
		date_received,		
		recycler_id,		
		recycler_name,
		mailing_address,
		mailing_city,
		mailing_state,
		mailing_zip_code,
		shipping_address,
		shipping_city,
		shipping_state,
		shipping_zip_code,
		Phone,
		contact_info,
		parent_company,
		email_address,
		date_joined,
		added_by,
		vin,
		items, --(SELECT SUM(quantity_received) FROM ElvsContainer WHERE r.recycler_id = ElvsContainer.recycler_id GROUP BY .container_id) AS items,		
		s_order,
		_row = row_number() over (order by s_order, _rowpre)
	into #out
	from #tmp
	
	set @total_rows = @@rowcount

	select
		container_id,		
		container_label,		
		date_received,		
		recycler_id,		
		recycler_name,
		mailing_address,
		mailing_city,
		mailing_state,
		mailing_zip_code,
		shipping_address,
		shipping_city,
		shipping_state,
		shipping_zip_code,
		Phone,
		contact_info,
		parent_company,
		email_address,
		date_joined,
		added_by,
		vin,
		items, --(SELECT SUM(quantity_received) FROM ElvsContainer WHERE r.recycler_id = ElvsContainer.recycler_id GROUP BY .container_id) AS items,		
		s_order,
		_row,
		@total_rows as total_rows
	from #out
	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
	order by _row
			
		
END -- CREATE PROCEDURE sp_ElvsContainerLookup

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerLookup] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerLookup] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerLookup] TO [EQAI]
    AS [dbo];

