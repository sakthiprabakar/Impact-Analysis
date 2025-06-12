


/***************************************************************
 * *
 *This procedure returns a list of  manifest where 
 *the manifest appear ona given invoice.
 *
 * 01/06/05 SCC Modified for Container Tracking changes
 * 02/08/06 MK  Captured container weight and passed into sp_container_consolidation_location
 * 06/18/15 RB  set transaction isolation level read uncommitted
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_invoice_print_weight_ticket 439933


 ***************************************************************
*/
CREATE PROCEDURE sp_invoice_print_weight_ticket 
		@invoice_id int
as

set transaction isolation level read uncommitted

declare @addr1 varchar(40),
@addr2 varchar(40),
@addr3 varchar(40),
 @addr4 varchar(40),
@addr5 varchar(40),
  @city  varchar(40),
  @state varchar(2) ,
  @zipcode varchar(20),
  @country varchar(40),
 @ot_addr1 varchar(40),
@ot_addr2 varchar(40),
@ot_addr3 varchar(40),
@ot_addr4 varchar(40),
@ot_addr5 varchar(40),
@cust_id int,
@cust_name varchar(75)


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
			waste_code_desc varchar(50) null,
			time_in datetime null,
			time_out datetime null,
			hauler varchar(20) null,
            secondary_manifest varchar(15) null	,
                      profile_id int null		)

-- get the billto address formatted

select @cust_id = max(customer_id) from Billing where invoice_id = @invoice_id

select @addr1 = bill_to_addr1,
	@addr2 = bill_to_addr2,
	@addr3 = bill_to_addr3,
	@addr4 = bill_to_addr4,
	@addr5 = bill_to_addr5,
        @city = bill_to_city,
  	@state = bill_to_state ,
  	@zipcode = bill_to_zip_code,
  	@country = bill_to_country,
        @cust_name = bill_to_cust_name
from Customer 
where customer_id = @cust_id

-- now format it


execute sp_format_address @addr1 = @addr1,
			@addr2 = @addr2,
			@addr3 = @addr3,
                        @addr4 = @addr4,
			@addr5 = @addr5,
                        @city = @city,
                        @state = @state,
                       @zipcode = @zipcode,
                         @country = @country,
                       @ot_addr1 = @ot_addr1 out,
			@ot_addr2 = @ot_addr2 out,
			@ot_addr3 = @ot_addr3 out,
			@ot_addr4 = @ot_addr4 out,
			@ot_addr5 = @ot_addr5 out 


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
	@cust_name,
	max(b.approval_code),
	max(pc.profit_ctr_name),
	max(pc.address_1),
	max(pc.address_2),
	max(pc.phone),
	max(pc.fax),
	@ot_addr1,
	@ot_addr2,
	@ot_addr3,
	@ot_addr4,
	@ot_addr5,
	b.receipt_id,
	b.line_id,
	max(b.gross_weight),
	max(b.net_weight),
	max(b.tare_weight),
	'',
	max(b.time_in),
	max(b.time_out),
	max(b.hauler),
	max(isnull(b.secondary_manifest,'')),
        max(b.profile_id)
from Billing b
inner join CustomerBilling cb on b.billing_project_id = cb.billing_project_id
        and b.customer_id = cb.customer_id
	and cb.weight_ticket_required_flag = 'T'
inner join profitcenter pc on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
inner join Generator g on b.generator_id = g.generator_id
where b.invoice_id = @invoice_id
and   b.manifest is not null 
and b.trans_source = 'R'
and b.trans_type = 'D'
and b.gross_weight > 0
and b.net_weight > 0 
and b.tare_weight > 0
group by b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id


-- now get the secondaries


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
order by company_id, profit_ctr_id, manifest


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_weight_ticket] TO [EQAI]
    AS [dbo];

