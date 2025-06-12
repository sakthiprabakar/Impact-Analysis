

CREATE PROCEDURE sp_cert_weight_ticket 
		@profit_ctr_id int, 
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
as
/***************************************************************
 * *
 *This procedure returns a list of  manifest where 
 *the manifest appear ona given invoice.
 *
 * 04/07/2007 rg created
 * 06/23/2014 AM - Moved to plt_ai and added company_id
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_cert_weight_ticket 4,'07/01/2006','07/31/2006',2396,2396,'0','z','0','z',0,99999,'0','z',1,0
****************************************************************/
create table #tickets (invoice_id int null,
			invoice_code varchar(16) null,
			invoice_date datetime null,
			company_id int null ,
			profit_ctr_id int null,
			manifest varchar(15) null,
			billing_date datetime null,
			generator_id int null,
			generator_name varchar(75) null,
			generator_epa_id varchar(12) null,
			customer_id int null,
			cust_name varchar(75) null,
			approval_code varchar(15) null,
			profit_ctr_name varchar(50) null,
			address_1 varchar(75) null,
			address_2 varchar(75) null,
			phone varchar(14) null,
			fax varchar(14) null,
			cust_addr_1 varchar(75) null,
			cust_addr_2 varchar(75) null, 
			cust_addr_3 varchar(75) null, 
			cust_addr_4 varchar(75) null, 
			cust_addr_5 varchar(75) null,
			receipt_id  int null,
			line_id     int null,
			gross_weight float null,
			net_weight   float null,
			tare_weight  float null,
			waste_code_desc varchar(40) null,
			time_in datetime null,
			time_out datetime null,
			hauler varchar(20) null,
            secondary_manifest varchar(15) null	,
            profile_id int null			)


insert #tickets
select  max(b.invoice_id),
	max(b.invoice_code),
	max(b.invoice_date),
	b.company_id,
	b.profit_ctr_id,
	max(b.manifest),
	max(b.billing_date),
	max(b.generator_id),
	max(g.generator_name),
	max(g.epa_id),
	max(b.customer_id),
	max(c.cust_name),
	max(b.approval_code),
	max(pc.profit_ctr_name),
	max(pc.address_1),
	max(pc.address_2),
	max(pc.phone),
	max(pc.fax),
	max(c.cust_addr1),
	max(c.cust_addr2),
	max(c.cust_addr3),
	max(c.cust_addr4),
	max(c.cust_addr5),
	b.receipt_id,
	b.line_id,
	max(b.gross_weight),
	max(b.net_weight),
	max(b.tare_weight),
	'',
	max(b.time_in),
	max(b.time_out),
	max(b.hauler),
	max(isnull(b.manifest,'')),
	max(b.profile_id)
from Billing b
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
inner join Customer c on b.customer_id = c.customer_id
where ( b.profit_ctr_id = @profit_ctr_id
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
and b.gross_weight is not null
and b.gross_weight > 0 
and b.net_weight > 0 
and b.tare_weight > 0 
group by b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id


-- now update for the secondaries

update #tickets
set manifest = secondary_manifest
from #tickets 
where len(secondary_manifest) > 0


update #tickets
set waste_code_desc = p.approval_desc
from #tickets t, profile p
where t.profile_id = p.profile_id



-- now select out

select  invoice_id,
	invoice_code,
	invoice_date,
	company_id,
	profit_ctr_id,
	manifest,
	billing_date,
	generator_id,
	generator_name,
	generator_epa_id,
	customer_id,
	cust_name,
	approval_code,
	profit_ctr_name,
	address_1,
	address_2,
	phone,
	fax,
	cust_addr_1,
	cust_addr_2, 
	cust_addr_3, 
	cust_addr_4, 
	cust_addr_5,
	receipt_id ,
	line_id,
	gross_weight,
	net_weight,
	tare_weight,
	waste_code_desc,
    	time_in,
	time_out,
	hauler
from #tickets
order by company_id, profit_ctr_id, customer_id, manifest



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cert_weight_ticket] TO [EQAI]
    AS [dbo];

