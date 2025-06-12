-- drop proc sp_cor_country_list 
go

create proc sp_cor_country_list (
	@web_userid	varchar(100) = null
	, @customer_id_list	varchar(max) = ''
	, @generator_id_list varchar(max) = ''
)
as
/* **************************************************************
sp_cor_country_list

	Note the inputs are ignored for now - just included for 
	consistency of parameters with other SPs in the site.
	Maybe someday we'll use them.

*************************************************************** */

select 
	country_name
	, country_code
	, case country_code
		when 'USA' then 1
		when 'CAN' then 2
		when 'MEX' then 3
		else 
			case when status = 'A' then 4 else 5 end
		end as [do not display - country_order]
	from country
	order by [do not display - country_order], country_name

go

grant execute on sp_cor_country_list  to eqai
go
grant execute on sp_cor_country_list  to eqweb
go
grant execute on sp_cor_country_list  to cor_user
go
grant execute on sp_cor_country_list  to crm_service
go

go
