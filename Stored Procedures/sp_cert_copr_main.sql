
CREATE PROCEDURE sp_cert_copr_main
		@profit_center int,
        @company_id int,
		@date_from datetime, 
		@date_to datetime, 
		@customer_id_from int, 
		@customer_id_to int, 
		@manifest_from varchar(15), 
		@manifest_to varchar(15), 
		@approval_from  varchar(15), 
		@approval_to  varchar(15), 
		@generator_from  int, 
		@generator_to int, 
		@epa_id_from varchar(12), 
		@epa_id_to varchar(12), 
		@report_type int  = 1, 
		@debug int  = 0
AS
/***************************************************************
 *sp_cert_disposal_detail (@date_from,@date_to,
 *	@customer_id_from,@customer_id_to,@manifest_from,@manifest_to
 *
 *This procedure returns information and manifest lists to print 
 *the COPD certificate from the report menu.
 *
 * 04/07/2007 rg created 
 * 06/23/2014 AM Moved to plt_ai

sp_cert_copr_main 0, '10/24/2007', '10/29/2007', 0, 999999, '0', 'zzz', '0', 'zzz', 0,999999,'0','zzz',1,0
****************************************************************/
declare @manifest_list varchar(4000),
        @comp_id int,
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
left outer join Invoiceheader h on b.invoice_id = h.invoice_id
	and h.status = 'I'
inner join CustomerBilling cb on b.billing_project_id = cb.billing_project_id
        and b.customer_id = cb.customer_id
	and cb.cor_required_flag = 'T'
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
inner join Customer c on b.customer_id = c.customer_id
where (b.profit_ctr_id = @profit_center
       and b.company_id = @company_id
       and b.billing_date between @date_from and @date_to
       and b.customer_id between @customer_id_from and @customer_id_to
       and b.manifest between @manifest_from and @manifest_to
       and b.approval_code between @approval_from and @approval_to
       and b.generator_id between @generator_from and @generator_to
       and g.epa_id between @epa_id_from and @epa_id_to )
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
left outer join Invoiceheader h on b.invoice_id = h.invoice_id
	and h.status = 'I'
inner join CustomerBilling cb on b.billing_project_id = cb.billing_project_id
        and b.customer_id = cb.customer_id
	and cb.cor_required_flag = 'T'
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
inner join Customer c on b.customer_id = c.customer_id
where (b.profit_ctr_id = @profit_center
       and b.company_id = @company_id
       and b.billing_date between @date_from and @date_to
       and b.customer_id between @customer_id_from and @customer_id_to
       and b.manifest between @manifest_from and @manifest_to
       and b.approval_code between @approval_from and @approval_to
       and b.generator_id between @generator_from and @generator_to
       and g.epa_id between @epa_id_from and @epa_id_to )
and   b.manifest is not null 
and b.trans_source = 'R'
and b.trans_type = 'D'
group by b.company_id, b.profit_ctr_id, b.generator_id, b.manifest

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
left outer join Invoiceheader h on b.invoice_id = h.invoice_id
	and h.status = 'I'
inner join CustomerBilling cb on b.billing_project_id = cb.billing_project_id
        and b.customer_id = cb.customer_id
	and cb.cor_required_flag = 'T'
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
inner join Customer c on b.customer_id = c.customer_id
where (b.profit_ctr_id = @profit_center
       and b.company_id = @company_id
       and b.billing_date between @date_from and @date_to
       and b.customer_id between @customer_id_from and @customer_id_to
       and b.manifest between @manifest_from and @manifest_to
       and b.approval_code between @approval_from and @approval_to
       and b.generator_id between @generator_from and @generator_to
       and g.epa_id between @epa_id_from and @epa_id_to )
and   b.secondary_manifest is not null 
and b.secondary_manifest <> b.manifest
and b.trans_source = 'R'
and b.trans_type = 'D'
group by b.company_id, b.profit_ctr_id, b.generator_id, b.secondary_manifest


-- parse the manifests together

-- declare cursor 

declare grp cursor for select
company_id,
profit_ctr_id,
generator_id
from #generators

open grp

fetch grp into @comp_id, @profit_ctr_id, @generator_id 

while @@fetch_status = 0
begin
     select @manifest_list = COALESCE( @manifest_list + ', ', '') + manifest  
        from #manifest x 
    	where x.company_id = @comp_id
          and x.profit_ctr_id = @profit_ctr_id
          and x.generator_id = @generator_id
		  and isnull(x.manifest,'') <> ''

     update #generators
        set manifest_list = @manifest_list
        where company_id = @comp_id
         and  profit_ctr_id = @profit_ctr_id
        and generator_id = @generator_id

      set @manifest_list = ''

      fetch grp into @comp_id, @profit_ctr_id, @generator_id 

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
    ON OBJECT::[dbo].[sp_cert_copr_main] TO [EQAI]
    AS [dbo];

