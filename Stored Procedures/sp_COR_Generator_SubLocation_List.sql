-- drop proc sp_COR_Generator_SubLocation_List
-- go

create proc sp_COR_Generator_SubLocation_List (
	@web_userid varchar(100),
	@customer_id_list varchar(max)='', /* Added 2019-08-05 by AA */
    @generator_id_list varchar(max)=''  /* Added 2019-08-05 by AA */
)
as
/* ****************************************************************
sp_COR_Generator_SubLocation_List

List the generator sub location types available to a user

09/27/2019 MPM  DevOps 11570: Added logic to filter the result sets
				using optional input parameters @customer_id_list and
				@generator_id_list.

sp_COR_Generator_SubLocation_List 'customer.demo@usecology.com'
sp_COR_Generator_SubLocation_List 'nyswyn100'
sp_COR_Generator_SubLocation_List 'zachery.wright'
sp_COR_Generator_SubLocation_List 'erindira7', '15622'
sp_COR_Generator_SubLocation_List 'erindira7', '', '135241'

**************************************************************** */

declare @i_web_userid varchar(100) = @web_userid,
    @i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

select distinct
	g.site_type,
	gsl.description
from ContactCORGeneratorBucket b
join CORcontact c on b.contact_id = c.contact_id
	and c.web_userid = @i_web_userid
join generator g
	on b.generator_id = g.generator_id
join GeneratorXGeneratorSubLocation gxgsl
	on g.generator_id = gxgsl.generator_id
join GeneratorSubLocation gsl
	on gxgsl.generator_sublocation_id = gsl.generator_sublocation_id
where
    (
        @i_customer_id_list = ''
        or
        (
			@i_customer_id_list <> ''
			and
			gsl.customer_id in (select customer_id from @customer)
		)
	)
and
	(
        @i_generator_id_list = ''
        or
        (
			@i_generator_id_list <> ''
			and
			g.generator_id in (select generator_id from @generator)
		)
	)
ORDER BY g.site_type, gsl.description

return 0

go

grant execute on sp_COR_Generator_SubLocation_List to eqweb, cor_user, eqai
go
