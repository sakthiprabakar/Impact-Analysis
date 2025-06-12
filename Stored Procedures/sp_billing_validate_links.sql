DROP PROCEDURE [dbo].[sp_billing_validate_links]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_billing_validate_links]
	@debug			int,
	@company_id	int,
	@profit_ctr_id	int,
	@source_id		int,
	@trans_source		varchar(1),
    @validate_date datetime,
    @user_code varchar(10)
AS
/***************************************************************************************
Displays list of pending Receipts and Work Orders with this Billing Link

Filename:	L:\Apps\SQL\EQAI\sp_billing_validate_links.sql
Loads to:	PLT_AI

06/08/2007 SCC	Created
10/03/2007 SCC	Changes for ProdTestDev to separate servers
02/18/2008 WAC	For a workorder transaction the source* fields in the billing record are
		        NULL so we need to look to the BillingLinkLookup table for related transactions.
		        NOTE:	There is no reason that this same logic can't be applied to receipts
			    but there seems to be some buggy code in the receipt window that doesn't
			    properly cleanup the BillingLinkLookup table, so the existing SQL
			    was left untouched for receipt processing.
02/22/2008 WAC	There was a condition on the where clause for receipt and workorder selects that 
		        was checking for a select list of statuses -- 
			    Receipt.receipt_status IN (''N'',''L'',''U'',''A'')
			    WorkOrderHeader.workorder_status IN (''N'',''C'',''D'',''A'')
		        Only status that matters is void since a voided transaction cannot be submitted.
05/08/2008 RG	Changed the logic of link validation to use the billing table instead of the workorder
				receipt submit status.  If it is not in the billing table then it has not been submitted.
05/21/2008 RG	Revised to warn if the transaction is an adjustment and not same status instead of erroring.
05/28/2009 KAM  Updated to allow for receipts that have an Exempt flag set
06/11/2009 KAM  updated to validate workorders and all associated receipts when a receipt is specified.
08/06/2009 JDB	Modified to allow receipts linked to zero-priced work orders validate properly.
12/30/2015 SK	Modified to bypass link required validation for Retail orders.
05/10/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.). 
06/01/2017 AM - Added billinglink join. 
05/10/2021 AM - DevOPs:19274 - Added #all_linked temp table and 2 new fields to #link_errors table.
06/02/2021 AM -  DevOps:21292 - Commented link_in_batch = 'T' since this is causing the slowness of the invoice validate,
				modified 2 updates (where ld.link_in_batch = 'F' ) by adding 2 subselects in where clause to filter the data.
				Also fixed ANSI joins 
06/09/2021 AM DevOps:21445 - When validating invoices this sql is causing slowness per dba,
			   so sql adjusted to match with index columns and removed where clause which no need.
09/16/2021 MPM	DevOps 27181 - Changed the logic that updates #all_linked.link_in_batch to what it was prior to 6/2/2021.
01/24/2022 MPM	DevOps 21208 - Corrected billing link validation date issues and added debugging statements.
07/28/2022 AGC  DevOps 19274 - added isnull() to get added_by and date_added values from BillingLinkLookup if they
                               don't exist in Billing and added code to get work order type description
08/16/2022 AGC  DevOps 39048 - added left outer join to #source and isnull to columns from #source to fix
							   bug where receipt was billed, workorder was billed but a different receipt
							   on the workorder was not billed. Workorder was finding error, receipt wasn't.
09/13/2022 AGC  DevOps 39048 - added back #linked table to replace #all_linked table. insert into #all_linked from #linked
                               at the end of the procedure.

****************************************************************************************/

-- the table here is created in the main procedure .  it is here for reference.

-- Captures output when checking receipt/work order linked records
--CREATE TABLE #link_errors (
--	company_id	int NULL,
--	profit_ctr_id	int NULL,
--	trans_source	char(1) NULL,
--	process_flag	int null,
--    validate_flag   char(1) null,
--    validate_message varchar(255) null
--)

-- NOTE the #receipt_wo_link table is created in the parent SP, sp_billing_validate.


-- this table holds the records for the receipt/workorder that is passed
-- in by the main procedure.  For a workorder this willbe one record.  For receipts
-- this may be more than one record.
Declare @wol_source_id 	int,
	@wol_company_id		int,
	@wol_profit_ctr_id	int,
	@workorder_type_desc varchar(40),
	@source_billing_project_id int,
	@source_billing_link_id int

CREATE TABLE #source ( trans_source varchar(1) NULL,
	company_id int NULL,
	profit_ctr_id int NULL,
	receipt_id int NULL,
	receipt_date datetime NULL,
	customer_id int null,
    billing_project_id int null,
    invoice_id int null,
    void_flag char(1) null,
    linked_required_flag char(1) null,
    linked_required_validation char(1) null,
	billing_link_id int NULL,
    link_validate char(1) null,
    link_message varchar(255) null,
	link_present char(1) null,
    link_closed char(1) null,
	source_id int null )


-- this table holds any receipt/workorder that is linked to the records in source
-- this table is populated from the billinglinklookup table

-- the fields trans_source, company_id, profit_ctr_id,receipt_id,customer_id,billing_project_id are for joining 
-- from the source table to the linked table.
/*
create table #linked ( 
    trans_source varchar(1) NULL,
	company_id int NULL,
	profit_ctr_id int NULL,
	receipt_id int NULL,
	customer_id int null,
    billing_project_id int null,
   	billing_link_id int NULL,
	source_type char(1) null,
	source_company_id int NULL,
	source_profit_ctr_id int NULL,
	source_id int NULL,
        link_invoice_id int null,
        link_void_flag char(1) null,
	link_submitted_date datetime null,
    link_status char(1) null,
    link_print_on_invoice char(1) null,
    link_in_batch char(1) null,
	workorder_type_desc varchar(40) NULL,
	source_submitted_name varchar(40) null
	) */
--create table #linked to match #all_linked in sp_billing_validate
--the #linked table is the work table. insert #linked into #all_linked at the end of the procedure
create table #linked ( 
    trans_source varchar(1) NULL,
	company_id int NULL,
	profit_ctr_id int NULL,
	receipt_id int NULL,
	customer_id int null,
    billing_project_id int null,
   	billing_link_id int NULL,
	source_type char(1) null,
	source_company_id int NULL,
	source_profit_ctr_id int NULL,
	source_id int NULL,
    link_invoice_id int null,
    link_void_flag char(1) null,
	link_billing_date datetime null,
    link_status char(1) null,
    link_print_on_invoice char(1) null,
    link_in_batch char(1) null,
	workorder_type_desc varchar(40) NULL,
	source_submitted_name varchar(40) null,
	source_submitted_date datetime null
)
-- prime up the table for the source record
/***************************************************************************************
01/22/2024 Kamendra  DevOps 76511
	The BillingLinkLookup table contains information regarding work orders linked to receipts for billing and invoicing.
	The source_type is always 'W', which means that source_id, source_company_id and source_profit_ctr_id refer to the WorkOrderHeader.
	workorder_id, WorkOrderHeader.company_id and WorkOrderHeader.profit_ctr_id of the work order involved in a link to a receipt,
	and the receipt_id, company_id and profit_ctr_id refer to the Receipt.receipt_id, Receipt.
	company_id and Receipt.profit_ctr_id of a receipt involved in a link to a work order.
****************************************************************************************/
-- if link is exempt the skip validation altogether

if @trans_source = 'W' and ( select count(*) from billinglinklookup bl where 
                             bl.source_id = @source_id
                             and bl.source_company_id = @company_id
                             and bl.source_profit_ctr_id = @profit_ctr_id
                             and bl.link_required_flag = 'E' ) > 0 
   begin
     goto results
   end

if @trans_source = 'R' and ( select count(*) from billinglinklookup bl where 
                             bl.receipt_id = @source_id
                             and bl.company_id = @company_id
                             and bl.profit_ctr_id = @profit_ctr_id
                             and bl.link_required_flag = 'E' ) > 0 
   begin
     goto results
   end

insert #source
	select distinct	b.trans_source,
		b.company_id ,
		b.profit_ctr_id ,
		b.receipt_id ,
		b.billing_date,
        b.customer_id,
        b.billing_project_id,
        b.invoice_id,
        isnull(b.void_status,'F'),
        isnull(cb.link_required_flag, 'F'),
        CASE @trans_source WHEN 'O' THEN NULL ELSE cb.link_required_validation END,
		b.billing_link_id,
        'A' as link_validate,
		null as link_message,
		'F' as link_present,
        'F' as link_closed,
		'' as source_id
from Billing  b
	inner join CustomerBilling cb on b.customer_id = cb.customer_id
                              and isnull(b.billing_project_id,0) = cb.billing_project_id
	where b.company_id = @company_id
	     and b.profit_ctr_id = @profit_ctr_id
	     and b.receipt_id = @source_id
	     and b.trans_source = @trans_source

if @debug = 1
begin 
	select '1: select * from #source'
	select * from #source
end

-- get the non group billing links if any
-- receipts will only have one 
if @trans_source = 'R'
begin
 insert into #linked
  select 	distinct s.trans_source,
	    s.company_id,
	    s.profit_ctr_id,
	    s.receipt_id ,
	    s.customer_id ,
        s.billing_project_id,
   	    s.billing_link_id,
        bl.source_type,
		bl.source_company_id,
		bl.source_profit_ctr_id,
		bl.source_id,
        b.invoice_id,
        isnull(b.void_status,'F'),
        b.billing_date,
		b.status_code,
	    case when bl.billing_link_id is null then 'F' else 'T' end  as link_print_on_invoice,
       'F' as link_in_batch,
		null as workorder_type_desc,
	    isnull(b.added_by,bl.added_by),
		isnull(b.date_added,bl.date_added)
	from  billinglinklookup bl 
	Join #source s ON s.receipt_id = bl.receipt_id
		and s.profit_ctr_id = bl.profit_ctr_id
		and s.company_id = bl.company_id
		and isnull(s.billing_link_id,0) = 0
	left outer join billing b on bl.source_type = b.trans_source
	and bl.source_id = b.receipt_id
	and bl.source_company_id = b.company_id
	and bl.source_profit_ctr_id = b.profit_ctr_id	
	where bl.trans_source in ('I','O')

	IF @@ROWCOUNT > 0 
	BEGIN

		if @debug = 1
		begin 
			select '2: select * from #linked'
			select * from #linked
		end
	
		--Make an exception for work orders that are submitted, but for $0.00 by updating the link status to Validated (N).
		UPDATE #linked SET link_status = 'N',#linked.workorder_type_desc = isnull(woth.account_desc,'') 
		-- SELECT *
		FROM #linked l
		INNER JOIN WorkorderHeader woh ON l.source_id = woh.workorder_id
		    AND l.source_profit_ctr_id = woh.profit_ctr_id
			AND l.source_company_id = woh.company_id
			AND woh.workorder_status = 'A'
			AND woh.submitted_flag = 'T'
			AND woh.total_price = 0.00
		Left Outer Join WorkOrderTypeHeader woth ON woth.workorder_type_id = woh.workorder_type_id
		WHERE l.source_type = 'W'
		--l.receipt_id IS NOT NULL 
		--AND l.profit_ctr_id IS NOT NULL 
	
		-- Get @wol_source_id, @wol_company_id, @wol_profit_ctr_id		
		Select @wol_source_id = source_id,
			 @wol_company_id = source_company_id,
			 @wol_profit_ctr_id = source_profit_ctr_id,
			 @workorder_type_desc = workorder_type_desc,
			 @source_billing_project_id = billing_project_id,
			 @source_billing_link_id = billing_link_id
		From	#linked

		--DevOps 39048 AGC 08/16/2022 added left outer join to #source and isnull to columns from #source to fix
		--							bug where receipt was billed, workorder was billed but a different receipt
		--							on the workorder was not billed. Workorder was finding error, receipt wasn't.
		insert into #linked
			 select distinct isnull(s.trans_source,@trans_source),
				    isnull(s.company_id,@company_id),
				    isnull(s.profit_ctr_id,@profit_ctr_id),
				    isnull(s.receipt_id,@source_id) ,
				    s.customer_id ,
			        isnull(s.billing_project_id,@source_billing_project_id),
			   	    isnull(s.billing_link_id,@source_billing_link_id),
			    	'R' as trans_source,
					bl.company_id,
					bl.profit_ctr_id ,
					bl.receipt_id,
			        	b.invoice_id,
			               isnull(b.void_status,'F'),
			        b.billing_date,
					b.status_code,
				    case when bl.billing_link_id is null then 'F' else 'T' end  as link_print_on_invoice,
			       'F' as link_in_batch,
				   @workorder_type_desc as workorder_type_desc,
	               isnull(b.added_by,bl.added_by),
		           isnull(b.date_added,bl.date_added)
			from billinglinklookup bl
			 left outer join billing b on  b.trans_source = 'R'
			   and bl.receipt_id = b.receipt_id
			   and bl.company_id = b.company_id
			   and bl.profit_ctr_id = b.profit_ctr_id
			 left outer join #source s ON isnull(s.billing_link_id,0) = 0
			   and s.receipt_id <> @source_id 
			where @wol_source_id = bl.source_id
			   and @wol_profit_ctr_id = bl.source_profit_ctr_id
			   and @wol_company_id = bl.source_company_id
			   and bl.trans_source in ('I','O') 
			   and bl.source_id <> @source_id
			   and bl.receipt_id <> @source_id

		if @debug = 1
		begin 
			select '3: select * from #linked'
			select * from #linked
		end

		--DevOps 19274 set work order type description
		UPDATE #linked SET #linked.workorder_type_desc = woth.account_desc
		FROM #linked l
		INNER JOIN WorkorderHeader woh ON woh.workorder_id = l.source_id  
			AND woh.profit_ctr_id = l.source_profit_ctr_id 
			AND woh.company_id = l.source_company_id 
			--AND woh.workorder_status = 'A'
			--AND woh.submitted_flag = 'T'
		INNER JOIN WorkOrderTypeHeader woth ON woth.workorder_type_id = woh.workorder_type_id
		WHERE  l.source_type = 'W'

	END

end

-- get the non group billing links if any
-- workorders may have more than one 
if @trans_source = 'W'
begin
 insert into #linked
 select distinct s.trans_source,
	    s.company_id,
	    s.profit_ctr_id,
	    s.receipt_id ,
	    s.customer_id ,
        s.billing_project_id,
   	    s.billing_link_id,
    	'R' as trans_source,
		bl.company_id,
		bl.profit_ctr_id ,
		bl.receipt_id,
        	b.invoice_id,
               isnull(b.void_status,'F'),
        b.billing_date,
		b.status_code,
	    case when bl.billing_link_id is null then 'F' else 'T' end  as link_print_on_invoice,
       'F' as link_in_batch,
	   null as workorder_type_desc,
	    isnull(b.added_by,bl.added_by),
		isnull(b.date_added,bl.date_added)
   from billinglinklookup bl
	 left outer join billing b on  b.trans_source = 'R'
	   and bl.receipt_id = b.receipt_id
	   and bl.company_id = b.company_id
	   and bl.profit_ctr_id = b.profit_ctr_id
	 join #source s ON s.receipt_id = bl.source_id
	   and s.profit_ctr_id = bl.source_profit_ctr_id
	   and s.company_id = bl.source_company_id
	   and isnull(s.billing_link_id,0) = 0
	where bl.trans_source in ('I','O')

	if @debug = 1
	begin 
		select '4: select * from #linked'
		select * from #linked
	end

	--DevOps:21445 - When validating invoices this sql is causing slowness per dba,
			--so sql adjusted to match with index columns and removed where clause which no need.

	/* UPDATE #all_linked    SET #all_linked.workorder_type_desc = woth.account_desc 
		FROM #all_linked l 
		INNER JOIN WorkorderHeader woh ON l.source_id = woh.workorder_id 
			AND l.source_company_id = woh.company_id 
			AND l.source_profit_ctr_id = woh.profit_ctr_id 
			AND woh.workorder_status = 'A' 
			AND woh.submitted_flag = 'T' 
			AND l.source_type = 'W' 
		LEFT OUTER JOIN WorkOrderTypeHeader woth ON woth.workorder_type_id = woh.workorder_type_id 
		WHERE l.receipt_id IS NOT NULL 
		AND l.profit_ctr_id IS NOT NULL */

		UPDATE #linked SET #linked.workorder_type_desc = woth.account_desc
		FROM #linked l
		INNER JOIN WorkorderHeader woh ON woh.workorder_id = l.source_id  
			AND woh.profit_ctr_id = l.source_profit_ctr_id 
			AND woh.company_id = l.source_company_id 
			--AND woh.workorder_status = 'A'
			--AND woh.submitted_flag = 'T'
		INNER JOIN WorkOrderTypeHeader woth ON woth.workorder_type_id = woh.workorder_type_id
		WHERE  l.source_type = 'W'

		Select  @workorder_type_desc = workorder_type_desc
		From	#linked    

end 

		
		
-- for billing groups where the billing link id > 0 we need to get the
-- destination records differently ( through the billinglink table )
-- we create a destitnation record for every billinglinklookup record that is part of the group.
-- if the billing record is present , use the billing status otherwise set the status to 'X' to indicated not submitted


insert #linked
select 	s.trans_source,
	    s.company_id,
	    s.profit_ctr_id,
	    s.receipt_id ,
	    s.customer_id ,
        s.billing_project_id,
   	    s.billing_link_id,
    	case when blu.trans_source = 'I' then 'R' when blu.trans_source = 'O' then 'R' when blu.trans_source = 'W' then 'W' end,
		blu.company_id,
		blu.profit_ctr_id ,
		blu.receipt_id ,
        b.invoice_id,
        isnull(b.void_status,'F'),
        b.billing_date,
		isnull(b.status_code,'X'),
	    case when blu.billing_link_id is null then 'F' else 'T' end  as link_print_on_invoice,
       'F' as link_in_batch,
	   @workorder_type_desc as workorder_type_desc,
	    isnull(b.added_by,blu.added_by),
		isnull(b.date_added,blu.date_added)
from billinglinklookup blu
join #source s on  s.billing_link_id = blu.billing_link_id
       and isnull(s.billing_link_id,0) > 0
join billinglink bl on  s.billing_link_id = bl.link_id
left outer join billing b on blu.receipt_id = b.receipt_id
  and blu.company_id = b.company_id
  and blu.profit_ctr_id = b.profit_ctr_id

	if @debug = 1
	begin 
		select '5: select * from #linked'
		select * from #linked
	end

		--DevOps 19274 set work order type description
		UPDATE #linked SET #linked.workorder_type_desc = woth.account_desc
		FROM #linked l
		INNER JOIN WorkorderHeader woh ON woh.workorder_id = l.source_id  
			AND woh.profit_ctr_id = l.source_profit_ctr_id 
			AND woh.company_id = l.source_company_id 
			--AND woh.workorder_status = 'A'
			--AND woh.submitted_flag = 'T'
		INNER JOIN WorkOrderTypeHeader woth ON woth.workorder_type_id = woh.workorder_type_id
		WHERE  l.source_type = 'W'
  
-- check to see if a link is present for receipt
-- DevOps:21292-Changed join from old stylr to ANSI join
update #source
set link_present = 'T',
    link_closed = 'C',
    billing_link_id = bl.billing_link_id,
	source_id = bl.source_id
from #source s
Join billinglinklookup bl ON 
  s.receipt_id = bl.receipt_id
 and s.company_id = bl.company_id
 and s.profit_ctr_id = bl.profit_ctr_id
 and isnull(s.billing_link_id,0) = 0
 and bl.trans_source in ('I','O')
 WHERE s.trans_source = 'R' 

if @debug = 1
begin 
	select '6: select * from #source'
	select * from #source
end

-- check to see if a link is present for workorder
-- DevOps:21292-Changed join from old stylr to ANSI join
update #source
set link_present = 'T',
    link_closed = 'C',
	billing_link_id = bl.billing_link_id,
	source_id = bl.source_id
from #source s
Join billinglinklookup bl ON s.receipt_id = bl.source_id
 and s.company_id = bl.source_company_id
 and s.profit_ctr_id = bl.source_profit_ctr_id
 and isnull(s.billing_link_id,0) = 0
 and bl.trans_source in ('I','O')
WHERE s.trans_source = 'W'   

if @debug = 1
begin 
	select '7: select * from #source'
	select * from #source
end

-- check to see if a link is present for group and is closed 
-- DevOps:21292-Changed join from old stylr to ANSI join
update #source
set link_present = 'T',
    link_closed = bl.status
from #source s
Join billinglink bl on s.billing_link_id = bl.link_id
 and s.billing_link_id > 0
 and s.customer_id = bl.customer_id
 
if @debug = 1
begin 
	select '8: select * from #source'
	select * from #source
end

-- check to see if it is part of the current batch
-- DevOps:21203 - Commented for slowness
-- MPM - 9/16/2021 - DevOps 27181 - Uncommented the update below

update #linked
set link_in_batch = 'T'
from #linked ld, work_billingvalidate bw
where  ld.source_type = bw.trans_source
and  ld.source_id = bw.receipt_id
and   ld.source_profit_ctr_id = bw.profit_ctr_id
and   ld.source_company_id = bw.company_id
and   bw.validate_date = @validate_date
and   bw.user_code = @user_code

if @debug = 1
begin 
	select '9: select * from #linked'
	select * from #linked
end

-- now compute error messages

-- the error messages use the values in the source table that determine if there should be a link and whether to generate a warning or an error.  it uses the linked table
-- to check the status of linked transaction to the source to make sure the status are compatible for invoicing

--    linked_required_flag - is from the customerbilling project and determines whether the link is required for the source
--	                       a value of T indicates it is required
						   
--   linked_required_validation - is from the customerbilling project and dtermines whether to generate a warming (W) or error (E)
	
--   billing_link_id - indicates the type of billing link.  a zero indicates a billing link between a workorder and receipt and that
--	                  the two should be invoiced together. A billing link id > 0  indicates a billing group ( multiple receits/workorders)
--                         A billing link of null indicates that the link is between a receipt and workorder but they don't need to be invoiced together.
--                        You cannot tell from the billing link id alon that you have a link.  You must also loo at the link-present field which is set 
--                       to true when it finds a record in the billinglinklookup table for the source.
					  
--    link_validate - is the field taht is set based on the rules below.  Error (E) , Warn (W), or OK (A)
	
--    link_message  - is the error message if there is an error or warning
	
--    link_present - indicates that the source has a billinglinklookup record associated to it.
	
--    link_closed - indicates that the link group is closed ( billinglink.status) closed (C) or ready (R) you can invoice





---------------------------------------------------------------------------------e r r or s -----------------------------------------------------------


--if link required and no link present 
update #source
set link_validate  = 'E',
    link_message = 'No billing link entered and billing project requires link'
from #source
where link_present = 'F'
and linked_required_flag = 'T' and isnull(linked_required_validation,'W') = 'E'
and isnull(billing_link_id,0) = 0
and link_validate = 'A'



--if group link present and the link is not closed then error out
update #source
set link_validate  = 'E',
    link_message = 'The billing link is not closed'
from #source
where link_present = 'T'
and link_closed not in ('C','R')
and billing_link_id > 0 
and link_validate = 'A'


--if link required  but invoice together  not set
update #source
set link_validate = 'E',
    link_message = 'Billing link not set to Invoice Together and billing project requires Invoice Together'
from #source s
where link_present = 'T'
and billing_link_id is null
and linked_required_flag = 'T' 
and isnull(linked_required_validation,'W') = 'E'
and link_validate = 'A'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id 
								and ld.link_status <> 'I' )
								
								
-- both must be in same status and part of the same validation batch unless the destination record  is invoiced already or validated already
-- DevOps:21203 - Added subselect for ld.link_in_batch not in
-- MPM - 9/16/2021 - DevOps 27181 - Changed the update below to about what it was prior to 6/2/2021

update #source
set link_message = 'Linked transaction not same status or not in validation batch',
    link_validate  = 'E'
from #source s
where link_present = 'T'
and link_closed in ('C','R')
and link_validate = 'A'
and billing_link_id is not null
and invoice_id is null 
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id 
							   and ld.link_status not in ('I','N')
							   and ld.link_in_batch = 'F'
          --                     and ld.link_in_batch not in (select ld.link_in_batch 
										--from #linked ld, work_billingvalidate bw
										--where  ld.source_type = bw.trans_source
										--and  ld.source_id = bw.receipt_id
										--and   ld.source_profit_ctr_id = bw.profit_ctr_id
										--and   ld.source_company_id = bw.company_id
										--and   bw.validate_date = @validate_date
										--and   bw.user_code = @user_code)
                               and ld.link_invoice_id is null )




-- the linked transaction is not in the linked table beause it is not in Billing ( not submitted)
update #source
set link_message = 'Linked transaction not submitted for billing and is required by billing project',
    link_validate  = 'E'
from #source s
where link_present = 'T'
and link_closed in ('C','R')
and link_validate = 'A'
and linked_required_flag = 'F'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id
                               and ld.link_status is null
                               and ld.link_print_on_invoice = 'T'
                               and ld.source_id <> 0  )

if @debug = 1
begin 
	select '10: select * from #source'
	select * from #source
end

-- the linked transaction is not in the linked table because it is not in Billing ( not submitted)
update #source
set link_message = 'Linked transaction not submitted for billing and is required by billing project',
    link_validate  = 'E'
from #source s
where link_present = 'T'
and link_closed in ('C','R')
and link_validate = 'A'
and linked_required_flag  = 'T'
and linked_required_validation = 'E'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id
                               and ld.link_status is null 
                               and ld.source_id <> 0  )
                              
if @debug = 1
begin 
	select '11: select * from #source'
	select * from #source
end
 
-- finally we need to check empty links for billing link records where the source is null
-- these links are placeholders used to indcate a link is needed between the receipt and the workorder but
-- the linked transaction is currently unknown
update #source
set link_message = 'Linked transaction is incomplete',
    link_validate  = 'E'
from #source s
where link_present = 'T'
and link_closed in ('C','R')
and link_validate = 'A'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id 
							   and (ld.source_id = 0 or ld.source_id is null ) )
                               
---------------------------------------------------------------------------------w a r n i n g s - -----------------------------------------------------------

--if link required and the link is not present and we just want a warning.

update #source
set link_validate = 'W',
    link_message = 'No billing link entered and billing project requires link'
from #source
where link_present = 'F'
and linked_required_flag = 'T' and isnull(linked_required_validation,'W') = 'W'
and isnull(billing_link_id,0) = 0
and link_validate = 'A'

--if link is populated but no link defined (for groups)
update #source
set link_validate = 'W',
    link_message = 'No billing link entered'
from #source
where link_present = 'F'
and billing_link_id > 0 
and link_validate = 'A'

--if link required  but invoice together  not set and we only want to warn
update #source
set link_message = 'Billing link not set to Invoice Together and billing project requires Invoice Together',
    link_validate = 'W'
from #source s
where link_present = 'T'
and billing_link_id is null
and linked_required_flag = 'T' 
and isnull(linked_required_validation,'W') = 'W'
and link_validate = 'A'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id 
								and ld.link_status <> 'I' )

-- the linked transaction is not in the linked table beause it is not in Billing ( not submitted)
update #source
set link_message = 'Linked transaction not submitted for billing and is required by billing project',
    link_validate  = 'W'
from #source s
where link_present = 'T'
and link_closed in ('C','R')
and link_validate = 'A'
and linked_required_flag = 'T'
and linked_required_validation = 'W'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id
                               and ld.link_status is null
                               and ld.source_id <> 0  )

if @debug = 1
begin 
	select '12: select * from #source'
	select * from #source
end
							
-- both must be in same status and part of the same validation batch unless the destination record  is invoiced already or validated already
-- DevOps:21203 - Added subselect for ld.link_in_batch not in
-- MPM - 9/16/2021 - DevOps 27181 - Changed the update below to about what it was prior to 6/2/2021

update #source
set link_message = 'Linked transaction not same status or not in validation batch',
    link_validate  = 'W'
from #source s
where link_present = 'T'
and link_closed in ('C','R')
and link_validate = 'A'
--and linked_required_flag  = 'T'
--and linked_required_validation = 'W'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id 
							   and ld.link_status not in ('I','N')
							   and ld.link_in_batch = 'F')
	                           --and ld.link_in_batch not in (select ld.link_in_batch from #linked ld, work_billingvalidate bw
	                           --                               where  ld.source_type = bw.trans_source
                            --                                   and  ld.source_id = bw.receipt_id
	                           --                                and   ld.source_profit_ctr_id = bw.profit_ctr_id
	                           --                                and   ld.source_company_id = bw.company_id
	                           --                                and   bw.validate_date = @validate_date
	                           --                                and   bw.user_code = @user_code)
							   --)
													
if @debug = 1
begin 
	select '13: select * from #source'
	select * from #source
end
									
-- if  the linked transaction has already been invoiced then warn the user.
update #source
set link_message = 'Linked transaction already invoiced',
    link_validate = 'W'
from #source s
where link_present = 'T'
and link_closed = 'C'
and link_validate = 'A'
and exists ( select 1 from #linked ld  where s.trans_source = ld.trans_source
                               and s.receipt_id = ld.receipt_id
                               and s.company_id = ld.company_id
                               and s.profit_ctr_id = ld.profit_ctr_id
                               and s.billing_project_id = ld.billing_project_id 
								and ld.link_status = 'I' )
update #source
set source_id = #linked.source_id
from #linked
where #linked.source_id = #source.source_id

results:
if @debug = 1
begin 
	select 'select results:'
	select 'select * from #source'
	select * from #source
	select 'select * from #linked'
    select * from #linked
end

--DevOps 39048 insert #linked into #all_linked
insert #all_linked
select	l.trans_source,
		l.company_id,
		l.profit_ctr_id,
		l.receipt_id,
		l.customer_id,
		l.billing_project_id,
	   	l.billing_link_id,
		l.source_type,
		l.source_company_id,
		l.source_profit_ctr_id,
		l.source_id,
		l.link_invoice_id,
	    l.link_void_flag,
		l.link_billing_date,
	    l.link_status,
		l.link_print_on_invoice,
	    l.link_in_batch,
		l.workorder_type_desc,
		l.source_submitted_name,
		l.source_submitted_date
from #linked l
where l.trans_source = @trans_source
and l.company_id = @company_id
and l.profit_ctr_id = @profit_ctr_id
and l.receipt_id = @source_id

-- if no error message then do'nt return
insert #link_errors 
select s.company_id,
	s.profit_ctr_id,
	s.trans_source,
	0,
  s.link_validate,
  s.link_message,
  s.receipt_id,
  s.source_id
from #source s
where s.link_validate <> 'A'


GO





GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_validate_links] TO [EQAI]
    AS [dbo];

GO