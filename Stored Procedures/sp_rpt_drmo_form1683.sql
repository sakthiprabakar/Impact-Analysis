


/***************************************************************
 
06/23/2014 AM - Moved to plt_ai

sp_rpt_drmo_form1683 0, '4/1/2004','4/30/2004', 0,999999, 'MI9377398','MI9377398', '0','zz', 0,99999, '0','ZZ', 1, 1  

sp_rpt_drmo_form1683 0, '01/1/2003','7/10/2007', 10721,10721, '08001','08001', '0','zz', 0,99999, '0','ZZ', 1, 1  

 ***************************************************************
*/
CREATE PROCEDURE sp_rpt_drmo_form1683 
@profit_ctr_id int,
@company_id int,
@date_from datetime, @date_to datetime, 
@customer_id_from int, @customer_id_to int,
@manifest_from varchar(15), @manifest_to varchar(15), 
@approval_from varchar(15), @approval_to varchar(15),
@generator_from int, @generator_to int,
@epa_id_from varchar(12), @epa_id_to varchar(12),
@report_type int, @debug int
as

declare @company int,
        @profit_ctr int,
        @receipt int,
        @line int,
        @waste_list varchar(255),
        @outbound_manifest varchar(20),
        @outbound_receipt int,
        @outbound_line int

create table #inbound_manifests ( customer_id int null,
                                  receipt_id int null,
                                  line_id int null,
                                  company_id int null,
                                  profit_ctr_id int null,
                                  drmo_clint_num int null,
                                  drmo_hin_num int null,
                                  drmo_doc_num int null,
                                  inbound_manifest varchar(20) null,
                                  inbound_qty float null,
                                  receipt_date datetime null,
                                  inbound_waste_code varchar(255) null,
                                  outbound_manifest varchar(20) null,
                                  outbound_tsdf_code varchar(20) null,
                                  outbound_tsdf_epa_id varchar(20) null,
                                  outbound_qty float null,
				  outbound_accept_date datetime null,
                                  outbound_pcb_disposal_date datetime null,
                                  outbound_receipt_id int null,
                                  outbound_line_id int null,
                                  bill_project_id int null,
                                  bill_project_description varchar(50) null,
                                  po_number varchar(20) null,
                                  invoice_amount money null,
                                  invoice_code varchar(16) null,
                                  company_name varchar(50) null,
                                  initial_handling_code varchar(20) null,
                                  treatment_codes varchar(20) null,
                                  report_date datetime null,
                                  split int null,
                                  tracking_num varchar(30) null,
                                  invoice_date datetime null,
                                  release varchar(20) null)


insert #inbound_manifests
select receipt.customer_id,
  receipt.receipt_id ,
  receipt.line_id,
  receipt.company_id ,
  receipt.profit_ctr_id,
  receipt.drmo_clin_num,
  receipt.drmo_hin_num,
  receipt.drmo_doc_num,
  receipt.manifest as inbound_manifest,
  receipt.quantity as inbound_qty,
  receipt.receipt_date,
  '' as inbound_waste_code,
  '' as outbound_manifest,
  '' as outbound_tsdf_code,
  '' as outbound_tsdf_epa_id,
  null as outbound_qty,
  null as outbound_accept_date,
  null as outbound_pcb_disposal_date,
  null as outbound_receipt_id,
  null as outbound_line_id,
  0 as billing_project_id,
  null as bill_project_description,
  receipt.purchase_order,
  null as invoice_amount,
  null as invoice_code,
  profitcenter.profit_ctr_name,
  'S01' as initial_handling_code,
  '' as treatment_codes,
  getdate() as report_date,
  null as split,
  null as tracking_num,
  null as invoice_date,
  receipt.release
from receipt
inner join Generator on receipt.generator_id = Generator.generator_id
inner join ProfitCenter on receipt.company_id = ProfitCenter.company_id
        and receipt.profit_ctr_id = ProfitCenter.profit_ctr_id
where (Receipt.trans_mode = 'I')   
  AND (Receipt.trans_type = 'D') 
  and (receipt_status <> 'V' )  
  AND (Receipt.profit_ctr_id = @profit_ctr_id)
  AND (Receipt.company_id = @company_id)
  AND (Receipt.receipt_date between @date_from and @date_to)
  AND (Receipt.customer_id between @customer_id_from and @customer_id_to) 
  AND (Receipt.manifest between @manifest_from and @manifest_to)
  AND (Receipt.approval_code between @approval_from and @approval_to)
  AND (Receipt.generator_id between @generator_from and @generator_to)
  AND (Generator.epa_id between @epa_id_from and @epa_id_to)
  

-- get billing info
-- 
-- update #inbound_manifests
-- set invoice_code = b.invoice_code,
--     invoice_date = b.invoice_date,
--     purchase_order = coalesce(i.purchase_order,b.purchase_order),
--     release   = coalesce(i.release, b.release_code )
-- from #inbound_manifests i, Billing b
-- where i.receipt_id = b.receipt_id
--  and  i.line_id = b.line_id
--  and  i.company_id = b.company_id
--  and  i.profit_ctr_id = b.profit_ctr_id 

-- get invoice info
-- 
-- update #inbound_manifests
-- set invoice_amount = ih.total_amt_due
-- from #inbound_manifests i, InvoiceHeader ih
-- where i.invoice_code = ih.invoice_code
--  and  i.company_id = ih.company_id
--  and  i.profit_ctr_id = ih.profit_ctr_id 

-- get billing project

update #inbound_manifests
set bill_project_description = cb.project_name
from #inbound_manifests i, CustomerBilling cb
where i.bill_project_id = cb.billing_project_id
 and  i.customer_id = cb.customer_id


-- now identify the outbound receipt


-- parse the manifests together

-- declare cursor 

declare grp cursor for select
company_id,
profit_ctr_id,
receipt_id,
line_id
from #inbound_manifests

open grp

fetch grp into @company, @profit_ctr, @receipt, @line 

while @@fetch_status = 0
begin
     select @waste_list = COALESCE( @waste_list + ', ', '') + waste_code  
        from receiptwastecode x 
    	where x.company_id = @company
          and x.profit_ctr_id = @profit_ctr
          and x.receipt_id = @receipt
          and x.line_id = @line
          and isnull(x.primary_flag,'F') = 'T'

     

    -- now find the outbound manifest
     execute sp_get_outbound_manifest_from_inbound @receipt_id = @receipt, 
                                         		@line_id = @line,
                                                        @company_id = @company,
                                                        @profit_ctr_id = @profit_ctr,
                                                        @debug = 0,
                                                        @out_manifest = @outbound_manifest out,
                                                        @out_receipt = @outbound_receipt out,
                                                        @out_line = @outbound_line out

	update #inbound_manifests
        set inbound_waste_code = @waste_list,
            outbound_manifest = @outbound_manifest,
            outbound_receipt_id  = @outbound_receipt,
            outbound_line_id     = @outbound_line 
        where company_id = @company
         and  profit_ctr_id = @profit_ctr
        and receipt_id = @receipt
        and line_id = @line


      set @waste_list = ''

      fetch grp into @company, @profit_ctr, @receipt, @line 

end

close grp

deallocate grp


 --strip off leading commas
update #inbound_manifests
set inbound_waste_code = right(inbound_waste_code, (len(inbound_waste_code) - 1))
where charindex(',',inbound_waste_code) = 1

update #inbound_manifests
set inbound_waste_code = left(inbound_waste_code, (len(inbound_waste_code) - 2))
where right(inbound_waste_code,2) = ', '

update #inbound_manifests
set inbound_waste_code = ltrim(inbound_waste_code)


update #inbound_manifests
set inbound_waste_code = 'NONE'
where inbound_waste_code = '.'


-- now seelct the outbound receipt info


update #inbound_manifests
set outbound_tsdf_code = o.tsdf_code,
    outbound_qty = i.inbound_qty,
    outbound_accept_date = o.ob_tsdf_accept_date,
    outbound_pcb_disposal_date = o.ob_tsdf_pcb_disposal_date
from #inbound_manifests i,
     receipt o
where i.outbound_receipt_id = o.receipt_id
and   i.outbound_line_id = o.line_id
and   i.profit_ctr_id = o.profit_ctr_id
and   i.company_id = o.company_id
and   o.trans_mode = 'O'


-- now update the epa_id info
update #inbound_manifests
set outbound_tsdf_epa_id = tsdf.tsdf_epa_id
from #inbound_manifests i,
     tsdf
where i.outbound_tsdf_code = tsdf.tsdf_code






     
-- now dump out the results ordered

select receipt_id,
  line_id,
  company_id,
  profit_ctr_id,
  drmo_clint_num ,
  drmo_hin_num ,
  drmo_doc_num,
  inbound_manifest ,
  inbound_qty ,
  receipt_date ,
  inbound_waste_code,
  outbound_manifest,
  outbound_tsdf_code ,
  outbound_tsdf_epa_id ,
  outbound_qty ,
  outbound_accept_date ,
  outbound_pcb_disposal_date ,
  outbound_receipt_id ,
  outbound_line_id,
  bill_project_description,
  po_number,
  invoice_amount,
  invoice_code,
  company_name,
  initial_handling_code,
  treatment_codes,
  report_date,
  invoice_date,
  release
 -- tracking_num,
--  split 
from #inbound_manifests
order by inbound_manifest,
  drmo_clint_num ,
  drmo_doc_num ,
  drmo_hin_num
  





GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_drmo_form1683] TO [EQAI]
    AS [dbo];

