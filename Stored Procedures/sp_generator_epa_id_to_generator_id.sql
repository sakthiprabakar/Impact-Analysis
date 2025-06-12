
create proc sp_generator_epa_id_to_generator_id (
	@epa_id_list	varchar(max),
	@contact_id		int
)
as
/* **********************************************************************************************
sp_generator_epa_id_to_generator_id
	Takes an input of epa id (may be a CSV list)
	Returns the generator_id's that are equivalent to those EPA IDs
	If @contact_id is a non-zero number, we also validate the contact can access those generators
	
History
	7/11/2012 - JPB - Created
	3/28/2013 - JPB - Override cases of "CESQG".  That's not a 1:1 match, and this sp was meant for 1:1. Or close.
		- Also 'NA', 'N/A', 'NONE'.  Come on.  Get real.
	
	select epa_id, count(*) from generator where epa_id not like '%CESQG%' group by epa_id order by count(*) desc

Sample:
	select * from customergenerator where customer_id = 888880 -- demo accessible
	select * from customergenerator where customer_id = 10673 -- demo NOT accessiable
	select * from generator where generator_id in (89258, 89259, 89260, 89261, 89262, 89263)
	select * from generator where generator_id in (63946 )
	select * from contactxref where generator_id in (1928, 1981, 2002) and contact_id = 10913
	
	sp_generator_epa_id_to_generator_id 'SAMPLE11235, SAMPLE10006, SAMPLE10577, SAMPLE10004, SAMPLE10008, SAMPLE10122', 10913 -- customer.demo
	sp_generator_epa_id_to_generator_id 'SAMPLE11235, SAMPLE10006, SAMPLE10577, SAMPLE10004, SAMPLE10008, SAMPLE10122', 0 -- associate

	sp_generator_epa_id_to_generator_id 'NYR000175299, PAR000520825, MOR000542258, ', 0 -- associate
	sp_generator_epa_id_to_generator_id 'NYR000175299, PAR000520825, MOR000542258, ', 10913 -- demo
	sp_generator_epa_id_to_generator_id 'NYR000175299, PAR000520825, MOR000542258, ', 100913 -- WM contact
	sp_generator_epa_id_to_generator_id 'TXR000080473', 0
	sp_generator_epa_id_to_generator_id 'TXR000080473', 10913
	
sp_generator_epa_id_to_generator_id 'KYD006396246', 199

sp_reports_waste_summary 0, '', '', '105832', '', '1/1/2012', '7/31/2012', 'G', '199', 'Y', 'D','',1,-1	

	select load_generator_EPA_ID, count(distinct receipt_id) from receipt r
	inner join customergenerator cg on r.generator_id = cg.generator_id
	where cg.customer_id = 10673
	group by load_generator_EPA_ID order by count(distinct receipt_id) desc

********************************************************************************************** */

set nocount on

create table #epaid (
	epa_id		varchar(20)
)

insert #epaid select left(row, 20) from dbo.fn_splitXsvText(',', 1, @epa_id_list) where isnull(row, '') <> ''

delete from #epaid where epa_id like '%CESQG%'
delete from #epaid where epa_id in ('NA', 'N/A', 'NONE', '.')

set nocount off

if isnull(@contact_id, 1) = 0
	select generator_id from generator where epa_id in (select epa_id from #epaid)
else
	select generator_id from generator where epa_id in (select epa_id from #epaid)
	and exists (
			select 1 from contactxref x where x.generator_id = generator.generator_id and x.contact_id = @contact_id and x.status = 'A' and x.web_access = 'A'
		union all
			select 1 from customergenerator cg inner join contactxref x on cg.customer_id = x.customer_id
			where cg.generator_id = generator.generator_id and x.contact_id = @contact_id and x.status = 'A' and x.web_access = 'A'
		union all
			select 1 from profile where generator_id = generator.generator_id and customer_id in (
				select customer_id from contactxref where contact_id = @contact_id and status = 'A' and web_access = 'A'
			)
		union all
			select 1 from workorderheader where generator_id = generator.generator_id and customer_id in (
				select customer_id from contactxref where contact_id = @contact_id and status = 'A' and web_access = 'A'
			)
	)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_epa_id_to_generator_id] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_epa_id_to_generator_id] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_epa_id_to_generator_id] TO [EQAI]
    AS [dbo];

