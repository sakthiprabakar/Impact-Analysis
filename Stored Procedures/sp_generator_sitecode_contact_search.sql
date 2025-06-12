
create proc sp_generator_sitecode_contact_search (
	@contact_id int		-- 0 if null/associate
	, @site_code_list	varchar(max)
)
as
/* **********************************************************************************
sp_generator_sitecode_contact_search

	Returns generator information that matches site codes
	Limits to contact_id access if non-zero

History

	10/13/2015	JPB	Created

Sample
	sp_generator_sitecode_contact_search 0, ''
	sp_generator_sitecode_contact_search 0, '*6'
	sp_generator_sitecode_contact_search 0, '6666'
	sp_generator_sitecode_contact_search 100913, '66' -- walmart contact
	sp_generator_sitecode_contact_search 100913, '*66*' -- walmart contact
	sp_generator_sitecode_contact_search 0, '*66*'

********************************************************************************** */

set nocount on

create table #SiteCodeList (
	site_code		varchar(16)
)

insert #SiteCodeList
select replace(left(row, 16), '*', '%') from dbo.fn_SplitXSVText(',', 1, @site_code_list)
where row is not null

set nocount off
	
SELECT distinct
g.generator_id
, g.generator_name
, g.epa_id
, g.site_type
, g.site_code
, g.generator_type_id
, g.status
, g.generator_city
, g.generator_state
FROM    generator  g
INNER JOIN #SiteCodeList scl on g.site_code like scl.site_code
left join customergenerator cg on g.generator_id = cg.generator_id 
left join contactxref xg on xg.type = 'G' and xg.generator_id = g.generator_id and xg.status = 'A' and xg.web_access = 'A'
left join contactxref xc on xc.type = 'C' and xc.customer_id = cg.customer_id and xc.status = 'A' and xc.web_access = 'A'
where g.status = 'A'
and isnull(g.site_code, '') <> ''
and (
	@contact_id = 0
	or
	(
		@contact_id <> 0
		and
		(
			xg.contact_id = @contact_id
			or
			xc.contact_id = @contact_id
		)
	)
)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_sitecode_contact_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_sitecode_contact_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_sitecode_contact_search] TO [EQAI]
    AS [dbo];

