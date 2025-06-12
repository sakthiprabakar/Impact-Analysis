
Create Procedure Sp_contact_online_services_info (
	@Contact_id		int,
	@debug			int = 0
)
AS

/************************************************************
Procedure    : Sp_contact_online_services_info
Database     : PLT_AI*
Created      : Thu Feb 23 17:35:02 EST 2006 - Jonathan Broome
Description  : Returns Online Services information about a contact_id

10/09/2007 WAC	Removed references to @mode which no longer applies in the Prod/Dev/Test environment

Sp_contact_online_services_info 2
Sp_contact_online_services_info 681
Sp_contact_online_services_info 999999
************************************************************/

declare @sql varchar(8000)

	set @sql = '
		select
			co.name,
			co.email,
			cx.type,
			case cx.type when ''C'' then cx.customer_id when ''G'' then cx.generator_id end as account_id,
			case cx.type when ''C'' then convert(varchar(20), cx.customer_id) when ''G'' then g.epa_id end as id_or_epa_id,
			case cx.type when ''C'' then c.cust_name when ''G'' then g.generator_name end as account_name,
			cx.web_access,
			(
				case when exists (
				select x.perm_id
				from eqweb..accessxperms x
				inner join eqweb..permissions p on x.perm_id = p.perm_id and p.perm_name like ''%administration%''
				where x.contact_id = cx.contact_id
				and x.record_type = cx.type
				and x.account_id = case cx.type when ''C'' then cx.customer_id when ''G'' then cx.generator_id end)
				then ''T'' else ''F'' end
			) as cust_admin,
			(
				case when exists (
				select x.perm_id
				from eqweb..accessxperms x
				inner join eqweb..permissions p on x.perm_id = p.perm_id and p.perm_name like ''%administration%''
				where x.contact_id = cx.contact_id
				and x.record_type = cx.type
				and x.account_id = case cx.type when ''C'' then cx.customer_id when ''G'' then cx.generator_id end)
				then ''T'' else ''F'' end
			) as esign,
			case when cx.web_access = ''A'' then
				isnull(
					(select top 1 convert(varchar(20),date_added)
					from eqweb..b2blog b
					where b.logon = co.email
					and action not like ''%failed%''
					order by date_added desc
				), ''Never'')
				else ''Never'' end
			 as last_login,
			co.contact_status,
			cx.status
			from contactxref cx
			left outer join customer c on cx.type = ''C'' and cx.customer_id = c.customer_id
			left outer join generator g on cx.type = ''G'' and cx.generator_id = g.generator_id
			inner join contact co on cx.contact_id = co.contact_id
		where
			cx.contact_id = ' + convert(varchar(20),@contact_id) + '
		order by
			cx.status,
			cx.type,
			account_name '

	if @debug = 1 print @sql

	exec(@sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_contact_online_services_info] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_contact_online_services_info] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_contact_online_services_info] TO [EQAI]
    AS [dbo];

