



create procedure sp_check_submitted_workorder (
   @workorder_id int,
   @company_id int,
   @profit_ctr_id int,
   @fixed_price_flag char(1) ) as



declare @bill_count int

-- determine if it is fixed price or not

if @fixed_price_flag = 'T'
begin
--     if there is at least one then its good so set count to zero

	select @bill_count = count(*) from billing 
                  where receipt_id = @workorder_id
                  and profit_ctr_id = @profit_ctr_id
                  and company_id = @company_id
                  and trans_source = 'W'


        if isnull(@bill_count,0) = 0 
           begin
		select @bill_count = 1
           end
        else
	   begin
            	select @bill_count = 0
           end
        

end

else
begin
	select @bill_count = count(*)  from workorderheader h
	where workorder_id = @workorder_id
		and company_id = @company_id
        and profit_ctr_id = @profit_ctr_id
        and h.fixed_price_flag = 'F'
	and h.workorder_status = 'X'
	and exists ( select 1 from workorderdetail d where d.workorder_id = h.workorder_id
											 and d.company_id = h.company_id
                                             and d.profit_ctr_id = h.profit_ctr_id
                                             and isnull(d.price,0) > 0 
                                             and isnull(d.quantity_used,0) > 0 
                                             and isnull(d.bill_rate,0) > 0 )
	and not exists ( select 1 from billing b where b.receipt_id = h.workorder_id
											 and b.company_id = h.company_id
                                             and b.profit_ctr_id = h.profit_ctr_id
                                             and b.trans_source = 'W'
                                             and b.status_code <> 'V' )

end

-- return the bad count of workorder lines

select @bill_count


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_check_submitted_workorder] TO [EQAI]
    AS [dbo];

