



/***************************************************************
 *sp_cert_disposal_detail (@date_from,@date_to,
 *	@customer_id_from,@customer_id_to,@manifest_from,@manifest_to
 *
 *This procedure returns a list of containers by manifest where 
 *all of the containers for the manifest are complete or void.
 *
 * 01/06/05 SCC Modified for Container Tracking changes
 * 02/08/06 MK  Captured container weight and passed into sp_container_consolidation_location
   06/18/15 RB  set transaction isolation level read uncommitted

sp_invoice_print_copd 439933

 ***************************************************************
*/
CREATE PROCEDURE sp_invoice_print_copd
		@invoice_id int,
		@debug int = 0
as

set transaction isolation level read uncommitted

declare @manifest_list varchar(4000),
        @company_id int,
        @profit_ctr_id int,
        @generator_id int

create table #generators (invoice_id int null,
			invoice_code varchar(16) null,
			invoice_date datetime null,
			company_id int null ,
			profit_ctr_id int null,
			generator_id int null,
			generator_name varchar(40) null,
			generator_epa_id varchar(12) null,
			profit_ctr_name varchar(50) null,
			address_1 varchar(40) null,
			address_2 varchar(40) null,
			phone varchar(14) null,
			fax varchar(14) null,
                        manifest_list varchar(4000) null)


create table #manifest (invoice_id int null,
			invoice_code varchar(16) null,
			invoice_date datetime null,
			company_id int null ,
			profit_ctr_id int null,
			manifest varchar(15) null,
			generator_id int null,
			receipt_id int null,
            		line_id int null,
            		secondary_manifest varchar(15) null )



insert #generators
select  max(b.invoice_id),
	max(b.invoice_code),
	max(b.invoice_date),
	b.company_id,
	b.profit_ctr_id,
	max(b.generator_id),
	max(g.generator_name),
	max(g.epa_id),
	max(pc.profit_ctr_name),
	max(pc.address_1),
	max(pc.address_2),
	max(pc.phone),
	max(pc.fax),
        null
from Billing b
inner join CustomerBilling cb on b.billing_project_id = cb.billing_project_id
        and b.customer_id = cb.customer_id
	and cb.copd_required_flag = 'T'
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
inner join Customer c on b.customer_id = c.customer_id
where (b.invoice_id = @invoice_id )
and   b.manifest is not null 
and b.trans_source = 'R'
and b.trans_type = 'D'
group by b.company_id, b.profit_ctr_id, b.generator_id


-- first group by receipt for one ginve manifest
insert #manifest
select  max(b.invoice_id),
	max(b.invoice_code),
	max(b.invoice_date),
	b.company_id,
	b.profit_ctr_id,
        b.manifest,
	max(b.generator_id),
	max(b.receipt_id),
    max(b.line_id),
        max(isnull(b.secondary_manifest,''))
from Billing b
inner join CustomerBilling cb on b.billing_project_id = cb.billing_project_id
        and b.customer_id = cb.customer_id
	and cb.copd_required_flag = 'T'
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
inner join Customer c on b.customer_id = c.customer_id
where (b.invoice_id = @invoice_id )
and   b.manifest is not null 
and b.trans_source = 'R'
and b.trans_type = 'D'
group by b.company_id, b.profit_ctr_id, b.generator_id,b.manifest

-- then get all teh lines where the secondary manifest is different from the manifest

insert #manifest
select  max(b.invoice_id),
	max(b.invoice_code),
	max(b.invoice_date),
	b.company_id,
	b.profit_ctr_id,
        b.secondary_manifest,
	max(b.generator_id),
	max(b.receipt_id),
        max(b.line_id),
        max(isnull(b.secondary_manifest,''))
from Billing b
inner join CustomerBilling cb on b.billing_project_id = cb.billing_project_id
        and b.customer_id = cb.customer_id
	and cb.copd_required_flag = 'T'
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
inner join Customer c on b.customer_id = c.customer_id
where (b.invoice_id = @invoice_id )
and   b.secondary_manifest is not null 
and   b.manifest <> b.secondary_manifest
and b.trans_source = 'R'
and b.trans_type = 'D'
group by b.company_id, b.profit_ctr_id, b.generator_id,b.secondary_manifest


-- parse the manifests together

-- declare cursor 

declare grp cursor for select
company_id,
profit_ctr_id,
generator_id
from #generators

open grp

fetch grp into @company_id, @profit_ctr_id, @generator_id 

while @@fetch_status = 0
begin
     select @manifest_list = COALESCE( @manifest_list + ', ', '') + manifest  
        from #manifest x 
    	where x.company_id = @company_id
          and x.profit_ctr_id = @profit_ctr_id
          and x.generator_id = @generator_id
		  and isnull(x.manifest,'') <> ''

     update #generators
        set manifest_list = @manifest_list
        where company_id = @company_id
         and  profit_ctr_id = @profit_ctr_id
        and generator_id = @generator_id

      set @manifest_list = ''

      fetch grp into @company_id, @profit_ctr_id, @generator_id 

end

close grp

deallocate grp
 --strip off leading commas
update #generators
set manifest_list = right(manifest_list, (len(manifest_list) - 1))
where charindex(',',manifest_list) = 1

update #generators
set manifest_list = left(manifest_list, (len(manifest_list) - 2))
where right(manifest_list,2) = ', '




-- now select out

select  invoice_id,
	invoice_code,
	invoice_date,
	company_id,
	profit_ctr_id,
	generator_id ,
	generator_name ,
	generator_epa_id ,
	profit_ctr_name ,
	address_1,
	address_2,
	phone,
	fax,
        manifest_list
from #generators
order by company_id, profit_ctr_id, generator_id



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_copd] TO [EQAI]
    AS [dbo];

