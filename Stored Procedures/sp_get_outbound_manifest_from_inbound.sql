
/***********
   declare @out varchar(20), @oreceipt int, @oline int
   execute sp_get_outbound_manifest_from_inbound 41839,1,22,0,1,@out,  @oreceipt, @oline
   select @out, @oreceipt, @oline
   07/29/2010  Updated the final insert statement to use the proper column names (final_receipt, final_line, final_manifest)
   06/23/2014 AM - Moved to plt_ai
****/

create procedure sp_get_outbound_manifest_from_inbound ( @receipt_id int, 
                                         		@line_id int,
                                                        @company_id int,
                                                        @profit_ctr_id int,
                                                        @customer_id int,
                                                        @inbound_manifest varchar(20),
                                                      
                                                        @debug int = 0,
                                                        @out_manifest varchar(20) output,
                                                        @out_receipt int output,
                                                        @out_line int output ) AS


declare @count int,
        @more_loops char(1),
        @loop_count int


create table #containers ( company_id int NULL ,
        profit_ctr_id int NULL ,
	container_type char (1)  NULL ,
	receipt_id int NULL ,
	line_id int NULL ,
	container_id int NULL ,
	sequence_id int NULL ,
	location_type char (1)  NULL ,
	location varchar (15)  NULL ,
	tracking_num varchar (15)  NULL ,
	cycle int NULL ,
	disposal_date datetime NULL ,
	base_tracking_num varchar (15)  NULL ,
	base_container_id int NULL ,
	status char (1)  NULL ,
	base_sequence_id int NULL,
        origin_receipt int null,
        origin_line int null,
        origin_company int null,
        origin_profitcenter int null,
        final_receipt int null,
        final_line int null,
        final_company int null,
        final_profitcenter int null,
        final_manifest varchar(20) null,
        split int null,
        stock char(2) null ) 

-- initialize

insert #containers
select cd.company_id ,
        cd.profit_ctr_id ,
	cd.container_type  ,
	cd.receipt_id  ,
	cd.line_id ,
	cd.container_id  ,
	cd.sequence_id  ,
	cd.location_type  ,
	cd.location  ,
	cd.tracking_num  ,
	cd.cycle  ,
	cd.disposal_date  ,
	cd.base_tracking_num  ,
	cd.base_container_id  ,
	cd.status  ,
	cd.base_sequence_id ,
        @receipt_id as origin_receipt,
        @line_id as origin_line,
        @company_id as origin_company,
        @profit_ctr_id as origin_profitcenter, 
        NULL AS final_receipt,
        null as final_line,
        null as final_company,
        null as final_profitcenter, 
        null as final_manifest,
        charindex('-',base_tracking_num) as split,
        left(base_tracking_num,2) as stock
      
from containerdestination cd
where  cd.receipt_id = @receipt_id
and    cd.line_id = @line_id
and    cd.profit_ctr_id = @profit_ctr_id
--and    cd.company_id = @company_id

select @more_loops = 'T', @loop_count = 0

while @more_loops = 'T'
begin
if @debug = 1
begin
	select * from #containers
end
        select @loop_count = @loop_count + 1
	select @count = count(*) from #containers where location_type = 'C'

	if @count > 0
	begin
	
		--update #inbound_manifests
		update #containers
		set receipt_id = convert(int, base_tracking_num),
		line_id = 1,
	        container_id = base_container_id,
	        container_type = 'R'
		where split = 0
	        and stock <> 'DL'
	        and location_type = 'C'
		
		update #containers
		set  receipt_id = convert(int, left(base_tracking_num, (split - 1))),
		line_id = convert(int, right (tracking_num, (len(base_tracking_num) - split))),
	        container_id = base_container_id,
	        container_type = 'R'
		where split > 0
	        and stock <> 'DL'
	        and location_type = 'C'
	
	        update #containers
		set receipt_id = 0,
		line_id = base_container_id,
	        container_id = base_container_id,
	        container_type = 'S'
		where stock = 'DL'
	        and location_type = 'C'

		update #containers
		set location_type = cd.location_type  ,
		    location = cd.location  ,
	            tracking_num = cd.tracking_num  ,
	            cycle = cd.cycle  ,
	            disposal_date = cd.disposal_date  ,
	            base_tracking_num = cd.base_tracking_num  ,
	            base_container_id = cd.base_container_id  ,
	            status = cd.status  ,
	            base_sequence_id = cd.base_sequence_id 
               from #containers c,
                    containerdestination cd
               where c.receipt_id = cd.receipt_id
                 and c.line_id = cd.line_id
                 and c.container_id = cd.container_id
                 and c.container_type = cd.container_type
                 and c.profit_ctr_id = cd.profit_ctr_id
		 and c.company_id = cd.company_id

              if @@rowcount = 0
              begin 
                  select @more_loops = 'F'
              end
	end

    else
	begin 
		select @more_loops = 'F'
	end

-- check for resonableness don't go forever
    if @loop_count = 20 
    begin
	select @more_loops = 'F'
    end
end

-- now update the final outbound destinations

update #containers 
set split = charindex('-', tracking_num)


--update #inbound_manifests
update #containers
set final_receipt = convert(int, tracking_num),
    final_line = 1
where split = 0

update #containers
set  final_receipt = convert(int, left(tracking_num, (split - 1))),
  final_line = convert(int, right (tracking_num, (len(tracking_num) - split)))
where split > 0


-- now determine the destination

select @count = count(distinct(final_receipt)) from #containers

-- case logic 
if @count > 1 
-- inbound container appears on more than one out bound receipt
begin
    select @out_manifest =  'MULTIPLES',
           @out_receipt = null,
           @out_line = null
end
-- inbound container appears on no out bound receipt
else if @count <= 0 
begin
    select @out_manifest = '',
           @out_receipt = null,
           @out_line = null
end
-- inbound container could not be resolved
else if @loop_count = 20 
begin
    select @out_manifest = 'UNRESOLVED',
           @out_receipt = null,
           @out_line = null
end
-- inbound container appears one out bound receipt
else
begin
    select @out_receipt = max(final_receipt) from #containers

    select @out_manifest = receipt.manifest
    from receipt where receipt_id = @out_receipt

    select @out_line = max(final_line) 
    from #containers where final_receipt = @out_receipt
end

update #containers
set final_manifest = receipt.manifest
from receipt, #containers  
where receipt.receipt_id = #containers.receipt_id
and receipt.line_id = #containers.line_id


if @debug = 1
begin
	select * from #containers
end

if @debug = 1
begin
  select  @out_manifest, @out_receipt, @out_line
end


	-- update the calling proc with the results from the temp table
        insert #outbound_manifests 
        select  @customer_id,
                  @receipt_id ,
                  @line_id,
                  @company_id ,
                  @profit_ctr_id ,
                  @inbound_manifest,
                  max(final_manifest),
                  null as outbound_tsdf_code,
                  null as outbound_tsdf_epa_id ,
                  count(*),
		  null as outbound_accept_date,
                  null as outbound_pcb_disposal_date,
                  final_receipt,
                  final_line
       from #containers 
       group by final_receipt, final_line




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_outbound_manifest_from_inbound] TO [EQAI]
    AS [dbo];

