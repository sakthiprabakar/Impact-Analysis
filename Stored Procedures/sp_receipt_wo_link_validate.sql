DROP PROCEDURE IF EXISTS sp_receipt_wo_link_validate
GO

CREATE PROCEDURE sp_receipt_wo_link_validate
	@debug			int,
	@receipt_company_id	int,
	@receipt_profit_ctr_id	int,
	@receipt_id		int,
	@wo_company_id		int,
	@wo_profit_ctr_id	int,
	@workorder_id		int,
	@validate_type		char(1),
	@customer_id		int,
	@billing_link_id	int,
	@manifest		varchar(1000),
	@generator      varchar(1000),
	@billing_project varchar(1000), 
	@tsdf_code      varchar(max),
	@return_msg		varchar(255) OUTPUT
AS
/***************************************************************************************
Validates Receipt/Work Order link relationship

Filename:	L:\Apps\SQL\EQAI\sp_receipt_wo_link_validate.sql

Load to PLT_AI

This stored procedure verifies that the specified receipt and work order exists and is
compatible for establishing a link relationship. 

06/05/2007 SCC	Created
10/16/2007 SCC	Removed db_references
02/21/2008 WAC	Increased size of @manifest to varchar(1000), it used to be varchar(15), so calling 
		script can pass a comma separated list of manifests, if desired.  This procedure will
		replace commas with ',' so that the proper SQL string is created for the IN (xxx) clause.
06/17/2008 RG	Added additional logic to warn users that they are going to override an existing link
				revised logic on manifest matching, added logic for billing_project and generator
07/08/2008 KAM	Updated the validation for workorders making it a warning if the workorder is linked 
				to another receipt and to use the source fields when counting existing links.
07/09/2008 RG	Changed sql statement for workorder manifest to correct problem with dymanic sql failing.
07/10/2008 RG	Added tsdf_status to receipt validation to avoid inactive tsdf_codes
07/15/2008 JDB	Commented out the warning for work orders "currently linked to another receipt"
08/15/2008 KAM	Changed the comparison for tsdf to just compare and not select from #Manifest in
				an attempt to eliminate the wrongfully displayed 'facilities do not match' message
08/19/2008 KAM	Change the comparison to look at the length of the manifest list before validating the 
				facilities
05/12/2009 KAM	Changed text of the message that comes up if the manifest is different between
				linked receipts and work orders.
05/08/2012 JDB	GEM:17734 - Work Order - Added new validation for links to receipt.  
				1. First, it will now present a warning when linking to a receipt that has already been 
					invoiced (it will still allow you to link, but will warn you.)  
				2. Second, it will now prevent you from linking to a receipt that already has an exempt 
					link on it.  
				3. Third, it will prevent you from linking to a receipt if it is already linked to 
					another work order.  SQL Deploy (sp_receipt_wo_link_validate).
07/03/2012 JDB	Added "trans_source = 'R'" when checking to see if a receipt has already been invoiced.
07/23/2018 AM  EQAI-52415 - Added warning messages to Receipt and Workorder if @billing_link_id IS NOT NULL
04/01/2022 MPM	DevOps 39408 - Widened @tsdf_code to varchar(max).

DECLARE @return_msg	varchar(255)
EXEC sp_receipt_wo_link_validate 1, 21, 0, 856737, 14, 6, 4037400, 'R', 10673, 0, '009123091JJK', '83593', '3999', 'EQDET', @return_msg
PRINT @return_msg
DECLARE @return_msg	varchar(255)
EXEC sp_receipt_wo_link_validate 1, 21, 0, 856738, 14, 6, 4037400, 'R', 10673, 0, '009123091JJK', '83593', '3999', 'EQDET', @return_msg
PRINT @return_msg

sp_receipt_wo_link_validate 1, 21, 0, 658225, 21, 0, 2000, 'I', 1544, 8, '', ''
sp_receipt_wo_link_validate 1, 22, 0, 71402, 22, 0, 2681301, 'R', 10673, null, '23456wlmt', ''
sp_receipt_wo_link_validate 1, 22, 0, 66714, 22, 0, 2419000, 'W', 10673, NULL, 'SCCMAN5', '0','0','EQFL', ''
sp_receipt_wo_link_validate 1, 22, 0, 75895, 22, 0, 2966300, 'R', 10673, 0,'', 63300, '24','',''
****************************************************************************************/
DECLARE	@wo_company		varchar(2),
		@receipt_company	varchar(2),
		@result_count		int,
		@source_customer_id	int,
		@source_billing_link_id	int,
		@sql			varchar(2000),
		@validate_type_msg	varchar(20),
		@co_count int,
		@wo_link_count int,
		@receipt_link_count int,
		@wo_manifest_count int,
		@receipt_manifest_count int,
		@manifest_good char(1),
		@receipt_tsdf varchar(15),
		@invoiced_count		int

CREATE TABLE #linked (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	source_id	int NULL,
	customer_id	int NULL,
	link_required char(1) null
)

create table #wo_manifest ( manifest varchar(20) null, 
                            tsdf_code varchar(15) null, 
                            eq_tsdf char(1) null,
                            eq_company int null,
                            eq_profit_center int null  )

create table #rec_manifest ( manifest varchar(20) null, 
                            tsdf_code varchar(15) null, 
                            eq_tsdf char(1) null,
                            eq_company int null,
                            eq_profit_center int null  )

create table #wo_generator ( generator_id int null )
create table #rec_generator ( generator_id int null )

create table #wo_billingproject ( billing_project_id int null )
create table #rec_billingproject ( billing_project_id int null )
    
   

-- Setup company database references
SET @wo_company = CASE WHEN @wo_company_id < 10 
	THEN '0' + CONVERT(varchar(1), @wo_company_id) 
	ELSE CONVERT(varchar(2), @wo_company_id) END
SET @receipt_company = CASE WHEN @receipt_company_id < 10 
	THEN '0' + CONVERT(varchar(1), @receipt_company_id) 
	ELSE CONVERT(varchar(2), @receipt_company_id) END


set @return_msg = ''
    

    -- validate company
    if @validate_type = 'W'
    begin
		select @co_count = count(*) from profitcenter 
		 where company_id = @wo_company_id and profit_ctr_id = @wo_profit_ctr_id
		if @co_count <= 0  
		begin
			select @return_msg = 'Invalid work order facility' 
			goto results
		end
    end
    

	if @validate_type = 'R'
    begin
    select @co_count = count(*) from profitcenter 
		 where company_id = @receipt_company_id and profit_ctr_id = @receipt_profit_ctr_id
		if @co_count <= 0  
		begin
			select @return_msg = 'Invalid receipt facility' 
            goto results
		end
     end
      

	-- Validate this work order
   
	IF @validate_type = 'W'
	BEGIN   
                    
		SET @sql = 'INSERT #linked SELECT '
			+ ' WorkOrderHeader.company_id, '
			+ ' WorkOrderHeader.profit_ctr_id, '
			+ ' WorkOrderHeader.workorder_id, '
			+ ' WorkOrderHeader.customer_id, '
			+ ' CustomerBilling.link_required_flag  ' 
			+ ' FROM WorkOrderHeader, '
            + ' CustomerBilling '
			+ ' WHERE WorkOrderHeader.customer_id =  CustomerBilling.customer_id ' 
			+ ' AND isnull(WorkOrderHeader.billing_project_id, 0)  = CustomerBilling.billing_project_id' 
			+ ' AND WorkOrderHeader.company_id = ' + convert(varchar(2), @wo_company_id)
			+ ' AND WorkOrderHeader.profit_ctr_id = ' + convert(varchar(2), @wo_profit_ctr_id)
			+ ' AND WorkOrderHeader.workorder_id = ' + convert(varchar(15), @workorder_id)
		SET @validate_type_msg = 'Work Order'

		IF @debug = 1 print @sql

		EXECUTE (@sql)
		
		if @@error > 0
        begin
			set @return_msg = 'Database error occurred while retrieving work order information'
        end

		
	END

	-- Validate this receipt
	ELSE
	BEGIN

		SET @sql = 'INSERT #linked SELECT DISTINCT '
				+ ' Receipt.company_id, '
				+ ' Receipt.profit_ctr_id, '
				+ ' Receipt.receipt_id, '
				+ ' Receipt.customer_id, '
				+ ' CustomerBilling.link_required_flag'
				+ ' FROM Receipt, '
                + '  CustomerBilling '
				+ ' WHERE Receipt.company_id = ' + convert(varchar(2), @receipt_company_id) 
				+ ' AND Receipt.profit_ctr_id = ' + convert(varchar(2), @receipt_profit_ctr_id)
				+ ' AND Receipt.receipt_id = ' + convert(varchar(15), @receipt_id)
                + ' and CustomerBilling.customer_id = Receipt.customer_id '
                + ' and CustomerBilling.billing_project_id = isnull(Receipt.billing_project_id, 0) '
			SET @validate_type_msg = 'Receipt'

		IF @debug = 1 print @sql

        execute (@sql)  

        if @@error > 0
        begin
			set @return_msg = 'Database error occurred while retrieving work order manifests'
        end
 end

-- is the link valid
	SELECT @result_count = count(*) FROM #linked
	IF @result_count = 0
    begin
		SET @return_msg = @validate_type_msg + ' does not exist.'
        goto results
    end

-- is the customer the same

	SELECT @source_customer_id = customer_id FROM #linked
	-- Customer must match
	IF ((@source_customer_id <> @customer_id) AND
		(@source_customer_id NOT IN (SELECT customer_ID FROM Customer WHERE IsNull(eq_flag,'F') = 'T')))
    begin 
		SET @return_msg = 'The customer on the ' + @validate_type_msg + ' does not match.'
        goto results
    end


	-- Billing Link must match if it is a real billing link
--	IF @billing_link_id IS NOT NULL AND @billing_link_id > 0 AND
--		@source_billing_link_id IS NOT NULL AND @source_billing_link_id > 0 AND
--		@billing_link_id <> @source_billing_link_id
--		begin
--			SET @return_msg = 'The billing link ID on the ' + @validate_type_msg + ' does not match.'
--            goto results
--		end

select @receipt_link_count = count(*) from billinglinklookup
    where receipt_id = @receipt_id
      and company_id = @receipt_company_id
      and profit_ctr_id = @receipt_profit_ctr_id
      and source_type = 'W'
      and source_company_id <> 0 
      and source_id <> 0 
      AND ( source_company_id <> @wo_company_id or source_profit_ctr_id <> @wo_profit_ctr_id
            or source_id <> @workorder_id)

-- check for current links
     if @receipt_link_count > 0 
     begin 
		select @return_msg = 'The receipt is currently linked to another work order.'
        goto results
     end
	
	------------------------------------------------
	-- Check for Exempt link on receipt
	------------------------------------------------
	IF @validate_type = 'R'
	BEGIN
		SET @receipt_link_count = 0
		
		SELECT @receipt_link_count = COUNT(*) 
		FROM BillingLinkLookup
		WHERE receipt_id = @receipt_id
		AND company_id = @receipt_company_id
		AND profit_ctr_id = @receipt_profit_ctr_id
		AND link_required_flag = 'E'

		IF @receipt_link_count > 0 
		BEGIN 
			SELECT @return_msg = 'The receipt currently has an Exempt link on it.  To resolve, either remove the Exempt link from the receipt screen and re-link it using the work order screen, or modify the Exempt link to be linked to this work order number.'
			GOTO results
		END
	END
	
	------------------------------------------------
	-- Check to see if the receipt is invoiced
	------------------------------------------------
	IF @validate_type = 'R'
	BEGIN
		SET @invoiced_count = 0
		
		SELECT @invoiced_count = COUNT(*) 
		FROM Billing
		WHERE company_id = @receipt_company_id
		AND profit_ctr_id = @receipt_profit_ctr_id
		AND receipt_id = @receipt_id
		AND status_code = 'I'
		AND trans_source = 'R'

		IF @invoiced_count > 0 
		BEGIN 
			SELECT @return_msg = 'WARNING: The receipt is already invoiced.'
			GOTO results
		END
	END


--select @wo_link_count = count(*) from billinglinklookup
--        where source_id = @workorder_id
--          and source_company_id = @wo_company_id
--          and source_profit_ctr_id = @wo_profit_ctr_id
--          and source_type = 'W'
--          and company_id <> 0 
--          and receipt_id <> 0 
--          AND (company_id <> @receipt_company_id or profit_ctr_id <> @receipt_profit_ctr_id
--                or receipt_id <> @receipt_id)
                
--	Commented because this makes no sense.  JDB 7/15/08
--     if @wo_link_count > 0 
--     begin 
--		select @return_msg = 'WARNING: The work order is currently linked to another receipt'
--        goto results
--     end

-- get the workorder manifest and the receipt manifest and compare the two
	set @sql = ' insert #wo_manifest '
                + '  select distinct wd.manifest, wd.tsdf_code, t.eq_flag, t.eq_company, t.eq_profit_ctr  '
                + '  FROM WorkOrderDetail wd, TSDF t  '
				+ '  WHERE wd.tsdf_code  = t.tsdf_code  '
                + '  and wd.resource_type = ''D'' '
				+ '  and wd.company_id = ' + convert(varchar(2), @wo_company_id)
                + '  and wd.profit_ctr_id = ' + convert(varchar(2), @wo_profit_ctr_id)
				+ '  AND wd.workorder_id = ' + convert(varchar(15), @workorder_id)
                + '  and wd.manifest is not null '
                + '   '

	IF @debug = 1 print @sql

    execute (@sql)  

    if @@error > 0
    begin
		set @return_msg = 'Database error occurred while retrieving work order manifests'
        goto results
    end


    set @sql = ' insert #rec_manifest '
                + '  select manifest,null, ''T'', company_id, profit_ctr_id '
                + '  FROM Receipt'
				+ '  WHERE Receipt.company_id = ' + convert(varchar(2), @receipt_company_id) 
				+ '  AND receipt.profit_ctr_id = ' + convert(varchar(2), @receipt_profit_ctr_id)
				+ '  AND receipt.receipt_id = ' + convert(varchar(15), @receipt_id)

	IF @debug = 1 print @sql

    execute (@sql)  

    if @@error > 0
    begin
		set @return_msg = 'Database error occurred while retrieving receipt manifests'
        goto results
    end

    select @wo_manifest_count = count(*) from #wo_manifest
if @debug = 1 print @wo_manifest_count

    select @receipt_manifest_count = count(*) from #rec_manifest

    if @validate_type = 'W' and @wo_manifest_count <> 0 
    begin
		if ( select count(*) from #wo_manifest 
             where #wo_manifest.eq_tsdf = 'T' 
               and #wo_manifest.eq_company = @receipt_company_id
               and #wo_manifest.eq_profit_center = @receipt_profit_ctr_id  )  = 0 
        begin
			set @return_msg = 'Receiving facility does not match the facility on the disposal tab of the work order.'
			goto results
        end


		if ( select count(*) from #wo_manifest 
             where #wo_manifest.eq_tsdf = 'T' 
               and #wo_manifest.eq_company = @receipt_company_id
               and #wo_manifest.eq_profit_center = @receipt_profit_ctr_id
               and #wo_manifest.manifest = @manifest )  = 0 
        begin
			set @return_msg = 'Cannot Link - Receipt Manifest does not match the manifest on the linked Work Order record'
			goto results
        end
    end

	if @validate_type = 'R' and @tsdf_code > '' -- and @wo_manifest_count <> 0 
    begin
        select @receipt_tsdf = tsdf_code from tsdf where eq_flag = 'T'
               and eq_company = @receipt_company_id
               and eq_profit_ctr = @receipt_profit_ctr_id
               and tsdf_status = 'A'

        if charindex(@receipt_tsdf, @tsdf_code ) = 0 
        begin
			set @return_msg = 'Receiving facility does not match the facility on the disposal tab of the work order.'
			goto results
        end
	end
	if @validate_type = 'R' and @manifest > ''
		begin
			if ( select count(*) from #rec_manifest r 
	             where charindex(r.manifest, @manifest ) >  0 ) = 0
	        begin
				set @return_msg = 'Cannot Link - Work Order Manifest does not match the manifest on the linked Receipt record'
				goto results
	        end
   	 end

 -- get the workorder generator and the receipt generator and compare the two

	set @sql = ' insert #wo_generator '
                + '  select generator_id FROM WorkOrderHeader WOH '
				+ '  WHERE WOH.company_id = ' + convert(varchar(2), @wo_company_id)
				+ '  AND WOH.profit_ctr_id = ' + convert(varchar(2), @wo_profit_ctr_id)
				+ '  AND WOH.workorder_id = ' + convert(varchar(15), @workorder_id)
                

	IF @debug = 1 print @sql

    execute (@sql)  

    if @@error > 0
    begin
		set @return_msg = 'Database error occurred while retrieving work order generator'
        goto results
    end

    set @sql = ' insert #rec_generator '
                + '  select generator_id FROM Receipt'
				+ '  WHERE Receipt.company_id = ' + convert(varchar(2), @receipt_company_id) 
				+ '  AND receipt.profit_ctr_id = ' + convert(varchar(2), @receipt_profit_ctr_id)
				+ '  AND receipt.receipt_id = ' + convert(varchar(15), @receipt_id)

	IF @debug = 1 print @sql

    execute (@sql)  

    if @@error > 0
    begin
		set @return_msg = 'Database error occurred while retrieving receipt generators'
        goto results
    end

    if @validate_type = 'W' 
    begin
        if (select count(*) from #wo_generator where generator_id is not null)  > 0 
        begin 
			if ( select count(*) from #wo_generator wo
				 where charindex(convert(varchar(20), wo.generator_id), @generator ) > 0 ) = 0
			begin
				set @return_msg = 'Receipt generator does not match work order generator'
				goto results
			end
		end 
    end

	if @validate_type = 'R' 
    begin
        if @generator is not null 
        begin
			if ( select count(*) from #rec_generator r 
				 where r.generator_id = convert(int, @generator) ) = 0
			begin
				set @return_msg = 'Receipt generator does not match work order generator'
				goto results
            end
        end
    end
   
-- get the workorder billing project and the receipt billing project and compare the two

	set @sql = ' insert #wo_billingproject '
                + '  select billing_project_id FROM WorkOrderHeader WOH '
				+ '  WHERE WOH.company_id = ' + convert(varchar(2), @wo_company_id)
				+ '  AND WOH.profit_ctr_id = ' + convert(varchar(2), @wo_profit_ctr_id)
				+ '  AND WOH.workorder_id = ' + convert(varchar(15), @workorder_id)
                

	IF @debug = 1 print @sql

    execute (@sql)  

    if @@error > 0
    begin
		set @return_msg = 'Database error occurred while retrieving work order billing Project'
        goto results
    end

    set @sql = ' insert #rec_billingproject '
                + '  select distinct billing_project_id FROM Receipt'
				+ '  WHERE Receipt.company_id = ' + convert(varchar(2), @receipt_company_id) 
				+ '  AND receipt.profit_ctr_id = ' + convert(varchar(2), @receipt_profit_ctr_id)
				+ '  AND receipt.receipt_id = ' + convert(varchar(15), @receipt_id)

	IF @debug = 1 print @sql

    execute (@sql)  

    if @@error > 0
    begin
		set @return_msg = 'Database error occurred while retrieving receipt billing project'
        goto results
    end

    if @validate_type = 'W' 
    begin
        if ( select count(*) from #wo_billingproject where billing_project_id is not null) > 0 
        begin
			if ( select count(*) from #wo_billingproject wo
				 where charindex(convert(varchar(20), wo.billing_project_id), @billing_project ) > 0 ) = 0
			begin
				if @billing_link_id IS NOT NULL
				  begin
					set @return_msg = 'The Receipt billing project does not match the work order''s billing project and cannot be set as invoice together.'
					goto results
				  end
				else 
				  begin
					set @return_msg = 'WARNING: Receipt billing project does not match work order billing project and these transactions may not be able to be invoiced together.'
					goto results
				  end
			end
         end 
    end

	if @validate_type = 'R' 
    begin
        if @billing_project is not null 
		begin 
			if ( select count(*) from #rec_billingproject r 
				 where r.billing_project_id = convert(int, @billing_project) ) = 0
			begin
				if @billing_link_id IS NOT NULL
				  begin
					--set @return_msg = 'Receipt billing project does not match work order billing project.'
					set @return_msg = 'The Receipt billing project does not match the work order''s billing project and cannot be set as invoice together.'
					goto results
				  end
				else 
				  begin
					set @return_msg = 'WARNING: Receipt billing project does not match work order billing project and these transactions may not be able to be invoiced together.'
					goto results
				  end
			end
        end 
    end
      

results:

	IF @debug = 1 
    begin
       select * from #linked 
	   select * from #wo_manifest 
       select * from #rec_manifest 
       select * from #wo_generator 
       select * from #rec_generator 
       select * from #wo_billingproject
       select * from #rec_billingproject 
       print @return_msg
    end 


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_wo_link_validate] TO [EQAI]
    AS [dbo];

