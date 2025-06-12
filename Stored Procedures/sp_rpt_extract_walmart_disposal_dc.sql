
CREATE PROCEDURE sp_rpt_extract_walmart_disposal_dc (
    @start_date             datetime,
    @end_date               datetime
)
AS
/* ***********************************************************
Procedure    : sp_rpt_extract_walmart_disposal_dc
Database     : PLT_AI
Created      : Jan 25 2008 - Jonathan Broome
Description  : Creates a Wal-Mart Disposal Extract

Examples:
    sp_rpt_extract_walmart_disposal_dc '1/1/2010 00:00', '1/31/2010 23:59'
    
    select * from eq_extract..extractlog order by date_added desc
    
Output Routines:
    declare @extract_id int = 837 -- (returned above)
			-- Disposal Validation output
			sp_rpt_extract_walmart_disposal_output_validation1_jpb 1121

			-- Disposal vs Trip Validation output
			sp_rpt_extract_walmart_disposal_output_validation2_jpb 1121
			
			-- Generators List (Validation) output
			sp_rpt_extract_walmart_disposal_output_generators_jpb 850

			-- Manifest output
			sp_rpt_extract_walmart_disposal_output_manifests_jpb 850

			-- EQ format of data output
			sp_rpt_extract_walmart_disposal_output_eqformat_jpb 850 

			-- WM format of data output
			sp_rpt_extract_walmart_disposal_output_wmformat_jpb 850

			-- Trip Export format of data output
			sp_rpt_extract_walmart_disposal_dc_output_trip_jpb 850


Notes:
    IMPORTANT: This script is only valid from 2007/03 and later.
        2007-01 and 2007-02 need to exclude company-14, profit-ctr-4 data.
        2007-01 needs to INCLUDE 14/4 data from the state of TN.

Puts data in these tables:
	EQ_Extract.dbo.WalmartMissingGenerators
	EQ_Extract.dbo.WalmartDisposalExtract
	EQ_Extract.dbo.WalmartDisposalImages
	EQ_Extract..WMDisposalValidation
	EQ_Extract.dbo.WMDisposalGenerationValidation
	
History:
    2/22/2008 - JPB - converted [field names] to field_names
        converted table names to friendlier names
        added JDB validation to the SP

    3/12/2008 - JDB - Beautified comments.  Changed the select
        for site_type to be from Generator directly. Added
        validation for missing site_type, and validation list
        of generators not associated with customer 10673.

    3/14/2008 - JPB - Removed errant extra '' from select into #WMDisposal
        on transporter*_epa_id fields

    4/10/2008 - JPB - Added code to include workorder records for pickup stops where no waste was picked up.

    4/18/2008 - JPB - Changed receipt_workorder_id, workorder_company_id, workorder_profit_ctr_id, service_date calcuations
        to use receipt.source_id where possible, or fall back to stop 1 workorder... for same generator
        order by w.start_date desc like it used to.

    6/9/2008 - JPB -
        Changed dot_description: TSDF approvals use the dot_shipping_name from the approval
            (because it's been entered as they prefer to see it)
            Receipts (EQ approvals) use the new fn_manifest_dot_description function.
            And if a row is neither a TSDF nor has a profile, then the field is ''
        Added validation for missing DOT_description values (that aren't service fee records)
        Added validation for missing waste description values (that aren't service fee records)
        Tweaked validation to include counts before lists of id's that need attention.

    6/13/2008 - JPB -
        Changed Receipt/Transporter fix: No longer calculates or populates any other table:
        It only takes data from BillingLinkLookup, supplemented by data from old calculated info.

    6/17/2008 - JPB - (per Brie/LT/JPB conference call):
        Modified Generator selection logic: Include all of 10673 + any generator with a site type in:
          ('Amigo', 'Neighborhood Market', 'Sams Club', 'Sams DC', 'Supercenter', 'Wal-Mart', 'Wal-Mart DC', 'Optical Lab')
        No more replacing 'NONE' wastecodes with empty/blank/null (oops, wasn't doing this anyway)
        Omit billing project 145 from all disposal/financial data
            i.e. AND (isnull(w.billing_project_id, 0) <> 145 OR (isnull(w.billing_project_id, 0) = 145 and w.customer_id <> 10673))
            and similar.

    6/20/2008 - JPB
        Modified Validation for missing waste codes: Only check disposal/approval records.

    6/23/2008 - JPB
        Modified Image extract to correct matching (receipt_id = workorder_id is wrong)
        Added validation to look for missing scans

    7/11/2008 - JPB
        Removed join requirement in Workorders <-> TSDFApproval that WO.customer_id = TA.customer_id

    7/14/2008 - JPB
        Added export to Excel code.  Needs work to make it copy to L: though.

    8/13/2008 - JPB
        Use Load_Generator_EPA_ID where populated.

    8/22/2008 - JPB
        Changed extract dir referenced in script below from plt_ai to eq_extract

    9/3/2008 - JPB
        Replaced approval_code with replace(r.approval_code, ''WM'' + right(''0000'' + r.generator_site_code, 4), ''WM'')
            to remove generator site codes from approval codes in the extract. - did not address TSDF approval codes.

    12/08/2008 - JPB
        per Brie (GEM:9650):
            Exclude any Wal-Mart Distribution Center data from the Waste Extract
                " AND ISNULL(g.site_type, '''') NOT IN (''Sams DC'', ''Wal-Mart DC'') "
                " AND ISNULL(g.site_type, '') NOT IN ('Sams DC', 'Wal-Mart DC') "
            The financial extract should only contain data for billing projects 24 & 99
            Please extract manifest images for all Wal-Marts except Distribution Centers...
                (accomplished by DC exclusion above)

    01/05/2009 - JPB
        Revised from sp_walmart_monthly_disposal_extract
        Only returns 1 output per run now (instead of several tables)
        Only returns recordset - no excel output
        Runs from central (plt_ai) locations - subst. plt_21_ai while plt_ai locations don't exist yet.

    01/13/2009 - JPB
        Converted to run on PLT_AI, not company or _RPT dbs
        
    02/03/2009 - JPB
        Fixed No Waste Pickup select - wasn't excluding site codes already found in #Extract, should have been.
        Fixed Validation checks that were looking for whole words for 'Approval', 'Disposal', 'No Waste Pickup',
            but should have been looking for 'A', 'D' or 'N'.
        Fixed join syntax to tsdfapproval - now uses tsdf_approval_id, company_id, profit_ctr_id.
        
    03/04/2009 - JPB
        Fixed join in Receipt query to WRT - was omitting line_id in matches which created duplicates.
        Fixed join in Receipt query to Container - was not specifying container type of 'R'
        Fixed Order By on Extract select
        Fixed calculation of workorderdetail.quantity to align with what RPT database uses.
        Updated No Waste Pickup query to insert workorder_id as receipt_id - was left NULL before, inconsistent with old RPT method.
        Moved Important Site_Type values to temp tables instead of copied lists all over the SP
            #SiteTypeToInclude  - the list that should be included
            #SiteTypeToExclude  - the list that should not be included
            The entries here may conflict (be in both lists) - just like they do/did when used in the SP below.
    
    03/10/2009 - JPB
        Add Disposal Method to extract (comes from profile/tsdfapproval)
            ProfileQuoteApproval.disposal_service_id = DisposalService.disposal_service_id
            TSDFApproval.disposal_service_id = DisposalService.disposal_service_id
        Extract should include all waste data from:
            Sams Clubs, Walmart, Walmart Supercenter, Walmart Neighborhood Market, Walmart Optical Lab, and Walmart Return Center, Walmart PDMC
            (Removed Amigo)
        Include Walmart approval WMNH018L or WMxxxxNH018L on extract (previously excluded)
            This is done by removing the omission of billing_project_id 145
            commented all instances of the 145 exclude.

    03/16/2009 - JPB
        Added a fix for including Container records in the extract - container weights were being duplicated
            because ContainerDestination's percent_of_container was not being factored into the amounts
        Receipt select was selecting NULL as EPA_source_code.  Now selects Profile.EPA_source_code.
        Changed Receipt-Transporter logic per Brie's instructions:
            Always show transporter 1 as the first transporter to have moved the load
            Always show transporter 2 as the second transporter to have moved the load
            It does not matter if there were any other transporters: only the first 2 count.
            This replaces previously existing calculation logic.

    03/17/2009 - JPB
        Comment copied from sp_rpt_extract_walmart_financial...
        Receipt.Load_Generator_EPA_ID vs Generator.EPA_ID: Decided via conf. call internally
            to always use isnull(Receipt.Load_Generator_EPA_ID, Generator.EPA_ID) to be consistent
            with what the Disposal extract uses.
        This does not represent a change in the Disposal extract, just a comment on consistenty
            with the Financial extract.

    03/19/2009 - JPB
        Added Haz_Flag field to #tables and queries for GEM:10459
            This is a DC disposal extract request - but uses the same Tables as the regular disposal extract

    03/26/2009 - JPB
        Added handling to account for receipts that don't have ReceiptTransporter assignments - they'll use the
            Receipt.Hauler as transporter_code instead of using a ReceiptTransporter record.
        
    03/27/2009- JPB
        Removed ContainerDestination in Receipt query, wasn't needed.
        Revised query per meeting with JDB & LT To average weights across Bill Units for containers related to the same receipt
    
    03/30/2009 - JPB
        ** IMPORTANT NOTE ** Don't ever just copy this SP's handling of DOT_Descriptions for use elsewhere.
        Walmart's requirements on EQ business procedures are unique and adapted specifically for this customer.
        No other customers can be sure their DOT Descriptions are valid for use the way WM's are.
        For other extracts, consider using the actual receipt/workorder fields to create the DOT_Description value 
        instead of using the related profile/tsdfapproval info as Wal-Mart does.

    04/03/2009 - JPB
        Modified validation tables to hold 7500 chars of problem ids, instead of 1000.
        Modified @list var to accomodate 7500.
        No other changes.
        
    04/22/2009 - JPB
        Added Extract Logging so we can see in the future what args we called an extract run with
        
    05/28/2009 - JPB
        Per Brie, changed TSDF Approval derived DOT_Descriptions to use the same function that Receipt derived DOT_Descriptions use.

    05/29/2009 - JPB
        Per Brie, No Waste Pickup wo's MUST come from billing project 24 in the Disposal Extract (no effect on the Finance extract)
        Per Lorraine, Make that condition work both ways: as above, or also if the Workorder's No Waste Pickup flag is checked.
    
    06/22/2009 - JPB
        Converted #tables to EQ_Temp..Tables.
    
    07/01/2009 - JPB
        Receipt Query wasn't checking fingerprint status = 'A'.  So it was possible for a voided line
        where receipt_status = 'A' and fingerpr_status = 'V' to get into the extract.  Should not be allowed.
        Added "AND r.fingerpr_status = 'A'" to Receipt queries.
        
    08/11/2009 - JPB
        Changes to WM Format Extract per WM... GEM:13064
            >>> Jonathan Broome 7/30/2009 11:13 AM >>>

            1. They mention a list they'll provide that we're to compare our generator info to (verify EPA ID, City, State).
            I don't have that list.  Result: No Checking at this time.
             
            2. They say not to list "CESQG" as an EPA ID.  We have some CESQG EPA ID's in our system for them.
            I think I heard (at the EPA) "If the generator is a cesqg, they don't have an EPA ID."
            Need more info from WM.  Result: No changes at this time.
             
            3. We need to insert the date of the "no pick up" as the manifest # for No-Waste-Pickup records.
            No spec on date format, so I'll give them a plain mm/dd/yyyy date.
            Result: Changed accordingly in wm-extract output section
             
            4. Spec says... "Manifest Line (A, B, C, D, E) Separate line items for each waste profile... 
            Do not duplicate manifest line #s; must have a manifest # even for 'No pick up' record (can not use '0')"
            Do they know that "A" would duplicate on page 2?
            We'll continue using numbers for lines despite their letter example, and explain it if they ask.
            I'll use "1" as the line for NWP records, instead of blank.
            Result: No change except in No Waste Pickup: Where 1 was inserted instead of null
             
            5. Container Type (the extract field) will take some fun handling:
            The email describes they only want 1 extract line per manifest line, and that multiple container 
            counts & weights should be summed, and descriptive types should be combined (csv) into that single line.
            Do they care how many of each kind of container they had? I can work that into the combined 
            description, e.g. "(7) 5 gallon, (5) 10 gallon" - it's not much more work than comma-separating the 
            types anyway.
            Need clarification: split lines *only* by manifest + manifest_line, or also by profile?  
            We have cases where multiple profiles apply to the same manifest line, so waste descriptions, 
            dot descriptions etc. are different for each line.
            Result: Created fn_combine_wm_waste_desc and calling it on the wm-extract output.
             
            6. We have some '' waste_code_1 values they don't want in extracts.
            That can be a new validation exception we add and fix before delivery.
            Result: Added validation for this case.
            
            7. Column name for "WorkOrder #" (or is it "Receipt #"??) - Unclear in the spec.
            Result: Leave as is.
            
            8. In March they asked us for Disposal Method to be added to extracts.  Their spec omits it.  Which is correct?
            Result: Omit it on the external version, keep it in the internal.

    06/25/2010 - JPB
        Changes to WM Format Extract per WM
          1. Manifest Line was returning 0 for No Waste Pickups.  Change to 1.
          2. Container Type was converting different types to combined gallons.
            Revert to separate types/lines and convert to Wm-standardized bill unit list.
          3. Disposal Method changes to a WM-standardize disposal method list.
          4. When waste-code = 'UNIV', don't show it.
          5. Vendor Name field (new), at end) = 'EQ'

    07/12/2010 - JPB
          1. Change NWP Record check - not for omission of disposal where there's a WO anymore,
             but where there's a WO with a decline_id > 1
          2. For wm-extract runs, Don't include waste codes that aren't State or Federal
          3. Where Load_Generator_EPA_ID was used in favor of generator epa_id, we were re-using bad data
             that had since been fixed in the Generator table, so I reverted this code to just use the
             generator.epa_id field again.
          4. Convert mutliple bill units on a single manifest line to total gallons
             but leave single-bill-unit per manifst line alone.
             

	12/07/2010 - JPB
		1. Modified per WM/EQ investigation into Disposal extract vs Trip extract differences.
		2. Moved output logic to other SPs - this SP just generates data and returns a extract_id
		3. Combined trip extract logic with this SP
		4. Added validation to this SP for trip vs disposal differences
		5. Typical after hours run: 3min, 42s.

			-- Disposal Validation output
			sp_rpt_extract_walmart_disposal_dc_output_validation1 514

			-- Disposal vs Trip Validation output
			sp_rpt_extract_walmart_disposal_dc_output_validation2 514
			
			-- Generators List (Validation) output
			sp_rpt_extract_walmart_disposal_dc_output_generators 514

			-- Manifest output
			sp_rpt_extract_walmart_disposal_dc_output_manifests 514

			-- EQ format of data output
			sp_rpt_extract_walmart_disposal_dc_output_eqformat 514

			-- WM format of data output
			sp_rpt_extract_walmart_disposal_dc_output_wmformat 514

			-- Trip Export format of data output
			sp_rpt_extract_walmart_disposal_dc_output_trip 514

	12/08/2010 - JPB
		1. Revised validation routines, bugfixing, etc.
		2. Converted validation output to be rows, not lists (removed @list)
		3. per brie, Blank Waste Code 1 validation should not count for lines with NO waste codes at all.
		4. per Brie: High number of same manifest/line should ignore cylinder lines
		5. Add #ApprovalNoWorkorder to store hard-coded approvals that should be ignored in
			validation for Receipt without Workorder

	12/14/2010 - JPB
		1. Switched receipt weight calculations to use net_weight, not container_weight sum
		2. Generation log now comes from ReceiptDetailItemWM for EQ receipts.
			Still using WODI for 3rd party Receipts
	
	12/15/2010 -JPB
		1. There was a wm-extract only handling of waste-codes: filtering, inserting 'none' when appr.
			Now this always happens.
		2. The receipt weight calculation rounds to whole numbers, making weights < 0.5 lbs 0.
			Add handling so that if the un-rounded weight is > 0 and < 0.5, the extract gets 1.0 as
			the weight, otherwise rounds as-is.
		3. DisposalGeneration date formatting:
			This has to be manually done in Excel for now -can't be done via SQL.
			Will be done via EQIP when that's used to export the data again.
		4. Fix to Trip vs Disposal validation - should've looked for abs(differences) > 1, not <= 1

	12/16/2010 - JPB
		1. Waste Code fix: 
			Walmart does not want to see the EQ waste codes UNIV - we need to change that 
			to read NONE on the extracts for waste code 1 & state waste code 1
		2. Waste code NONE fix:
			Also, if NONE is listed as waste code 1, we need to remove the word NONE from 
			any waste code fields that follow (waste code 2, 3, 4, etc.)
		3. DisposalGeneration fix: Rounding was inconsistent in the TSDFApproval section (rounded to 1 decimal in top, 0 in bottom)
			Was supposed to round to tenths in receipt section, but was not.  Fixed.

	12/17/2010 - JPB
		1. rdi/wodi weight calculations that rounded when a sum was between 0 and 0.5 should be "between 0.0001 and..." because
			Between is inclusive, and 0 should not be assigned go 1.
		2. Only export to DisposalGeneration when the line weight > 0 - Brie.

	12/20/2010 - JPB
		1. Complaint received that Disposal != Generation log weights (and != receipt.net_weight).
			This is because receipt net_weight is divided across the number of lines on the extract
			and means a DM05 and DM55 are shown as each 1/2 of the total.  Silly, but WM.
			Fix: After the extract is completely populated, go back over it for each mismatch
			between sum(disposal extract weights) != receipt.net_weight and set the FIRST record
			for each set in the extract +/- whatever required to make the sum of them match the
			receipt.net_weight.
		2. There were 2 copies of the Receipt population query, one for un-submitted, one for submitted.
			Got rid of 1 of them (only 1 copy of the calculations now) and just pulled the Receipt.submitted_flag
			into the results instead of 2 separate similar queries.
		3. Problem where we were storing a disposal extract line for each receiptprice bill unit.  This is legacy - WM used
			to want to see each unit separately, but lately has wanted them combined via fn_wm_extract_line_convert.
			Made EQ_Temp versions of fn_wm_extract_line_convert and its related functions and put in some code to
			combine rows into EQ_Temp now, instead of leaving them separate.  This
				1. Means we're only storing in EQ_Extract..WalmartDisposalExport the exact output rows WM wanted to see
				2. Resolving the weight problem of round(1.5) + round(1.5) <> 3.

	1/12/2011 - JPB
		1. 	Bug
		Msg 8115, Level 16, State 6, Procedure sp_rpt_extract_walmart_disposal_dc, Line 1687
		Arithmetic overflow error converting float to data type numeric.
		
		2. Added print statements to track progress
		
		3. Added @timer to find slow parts.

	2/23/2011 - JPB
		1. Updated WorkOrderManifest references -> WorkOrderTransporter
		2. Updated WOH.Trip_Act_Arrive references -> WorkOrderSchedule		
		3. Updated WOD.pounds -> WorkorderDetailUnit ('lbs')
		
	2/25/2011 - JPB
		1. Converted ReceiptDetailItemWM references to ReceiptDetailItem
		2. Converted Receipt.net_weight to Receipt.line_weight
		
	3/02/2011 - JPB
		1. Speed updates. Was taking 15m.  Now just 1m30s.

	4/12/2011 - JPB
		1. Added "and d.bill_rate not in (-2)" to avoid voided WO Detail lines.

	5/5/2011 - JPB
		1. Got rid of any deleting from EQ_extract tables.  No more housekeeping.
		
	5/10/2011 - JPB
		1. Removed @output method param.  Not used.
		2. Changed @customer_id to #Customer.customer_id to handle more/other customers.
		3. Dumped a lot of old comments.
		4. Got rid of #SiteTypeToExclude - wasn't used.

   7/12/2011 - JPB
      1. Added validation to detect Disposal records that are not in the Generation Log
      2. Changed Generation Log procedure - 
         a. Used to only use (Receipt section) RDI pounds & ounces.
            Now it takes R.line_weight if pounds & ounces = 0.
         b. Used to omit records with 0 weight
            Now it includes them and there's a new validation routine to flag those
      3. After a couple sample runs, saw that the Workorder section really looked better with the skip-0's back in it.
			So I put it back in for that part.
	  4. Generation Log procedure for WO based (3rd party) records was requiring that any WO's to be included have been on a trip.
			This was leaving out some sites.  Removed the trip_id requirement.  WM doesn't care if we called it a trip or not. Right?

   7/14/2011 - JPB
      Review of SQL vs WM spec...
      1. Disposal Log Pounds is supposed to be a whole number.
      2. Generation Log is supposed to round weights to whole number UNLESS they're Pxxx waste codes (P-Listed). Those get rounded to 10ths.
      
      3. Lisa called and asked me to hold off on that change for the GenerationLog weights.  Commented them out.

   8/9/2011 - JPB
      Converted "numeric(5,1)" -> "numeric(6,1)" - was getting convert float errors otherwise.
      Billing Projects were different in 2010 vs 2011, and that wasn't highlighted previously. Never came up in validation/conversation.
      Added a #BillingProject(customer_id, billing_project_id) table to restrict if necessary
      note: Prior to this change Billing_Project_ID was ONLY MENTIONED in the extract process as part of the No Waste Pickup, so
         This change should have no effect whatsoever here... Finance may be different.

   8/31/2011 - JPB
      one-off save for DC versions just to create validations for Distribution Center finance exports      		
*********************************************************** */

-- Fix/Set EndDate's time.
	if isnull(@end_date,'') <> ''
		if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Define Walmart specific extract values:
DECLARE
    @extract_datetime       datetime,
    @usr                    nvarchar(256),
    @sp_name_args           varchar(1000),
    @timer					datetime = getdate(),
    @steptimer				datetime = getdate()
SELECT
    @extract_datetime       = GETDATE(),
    @usr                    = UPPER(SUSER_SNAME()),
    @sp_name_args           = object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + ''''

Print 'Extract started at ' + convert(varchar(40), @timer)
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


CREATE TABLE #Customer (
	customer_id 	int
)
INSERT #Customer values (12650)

CREATE TABLE #BillingProject(
   customer_id          int,
   billing_project_id   int
)
/*
-- Standard Bucket Project Values:
   insert #BillingProject
   select 10673, 24 where @start_date between '1/1/2010' and '12/31/2010 23:59'
   union all
   select 10673, 3996 where @start_date between '1/1/2011' and '12/31/2011 23:59'
   union all
   select 10673, 3997 where @start_date between '1/1/2011' and '12/31/2011 23:59'
-- Pharmacy Values:   
   insert #BillingProject
   select 10673, 3636 where @start_date between '1/1/2010' and '12/31/2010 23:59'
   union all
   select 10673, 3998 where @start_date between '1/1/2011' and '12/31/2011 23:59'
   union all
   select 10673, 3999 where @start_date between '1/1/2011' and '12/31/2011 23:59'
*/   
-- Distribution Center Values:
   insert #BillingProject
   select customer_id, billing_project_id from CustomerBilling where customer_id = 12650 

CREATE TABLE #ApprovalNoWorkorder (
	-- These approval_codes should never have a workorder related to them
	-- So use this table during validation so we do not complain about
	-- receipts missing workorders for these.
	approval_code	varchar(20)
)
-- insert #ApprovalNoWorkorder values ('WMNHW10')


IF RIGHT(@usr, 3) = '(2)'
    SELECT @usr = LEFT(@usr,(LEN(@usr)-3))


print 'Log Run Information'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Log Run information
    INSERT EQ_Extract..ExtractLog (
        extract,
        extract_command,
        start_date,
        end_date,
        extract_table,
        record_count,
        date_added,
        added_by
    ) VALUES (
        'Walmart Disposal DC',
        @sp_name_args,
        GETDATE(),
        null,
        null,
        null,
        @extract_datetime,
        @usr
    )


-- select * From EQ_TEMP.dbo.WalmartDisposalReceiptTransporter
-- EQ_Temp table housekeeping
-- Deletes temp data more than 2 days old, or by this user (past runs)
DELETE FROM EQ_TEMP.dbo.WalmartDisposalExtract where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartDisposalReceiptTransporter where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartExtractImages where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartDisposalValidation where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartMissingGenerators where added_by = @usr and date_added = @extract_datetime



-- Create table to store important site types for this query (saves on update/retype issues)
CREATE TABLE #SiteTypeToInclude (
    site_type       varchar(40)
)
/*	
-- Load #SiteTypeToInclude table values:
	INSERT #SiteTypeToInclude
		SELECT 'Neighborhood Market' 
		UNION SELECT 'Sams Club'
		UNION SELECT 'Supercenter'
		UNION SELECT 'Wal-Mart'
		UNION SELECT 'Optical Lab'
		UNION SELECT 'Wal-Mart Return Center'
 		UNION SELECT 'Wal-Mart PMDC'
		UNION SELECT 'Sams DC'
		UNION SELECT 'Wal-Mart DC'
		-- UNION SELECT 'Amigo'
*/

print 'Run Setup Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
    

/* *************************************************************

Build Phase...
    Insert records to #Extract from
    1. TSDF (3rd party) disposal
    2. Receipt (EQ) disposal
    3. No-Waste Pickup Workorders

    Each step also has a #NotSubmitted copy - to trap for records
    that would have been included, if only they were submitted for
    billing already.  This info is for validation purposes.

    Before Receipts can be inseted into #Extract, a separate
    pre-condition query has to be run to build #ReceiptTransporter
    with info needed by the Receipt insert.

************************************************************** */


-- Work Orders using TSDFApprovals
INSERT EQ_Temp..WalmartDisposalExtract
SELECT DISTINCT
    -- Walmart Fields:
    g.site_code AS site_code,
    gst.generator_site_type_abbr AS site_type_abbr,
    g.generator_city AS generator_city,
    g.generator_state AS generator_state,
   	coalesce(wos.date_act_arrive, w.start_date) as service_date,
    g.epa_id AS epa_id,
    d.manifest AS manifest,
    CASE WHEN isnull(d.manifest_line, '') <> '' THEN
        CASE WHEN IsNumeric(d.manifest_line) <> 1 THEN
            dbo.fn_convert_manifest_line(d.manifest_line, d.manifest_page_num)
        ELSE
            d.manifest_line
        END
    ELSE
        NULL
    END AS manifest_line,
	convert(int, Round(ISNULL(
		(
			SELECT 
				quantity
				FROM WorkOrderDetailUnit a (nolock)
				WHERE a.workorder_id = d.workorder_id
				AND a.company_id = d.company_id
				AND a.profit_ctr_id = d.profit_ctr_id
				AND a.sequence_id = d.sequence_id
				AND a.bill_unit_code = 'LBS'
		) 
	, 0), 0)) as pounds, -- workorder detail pounds
    b.bill_unit_desc AS bill_unit_desc,
    ISNULL( 
        CASE
                WHEN u.quantity IS NULL
                THEN IsNull(d.quantity,0)
                ELSE u.quantity
        END
    , 0) AS quantity,
    t.waste_desc AS waste_desc,
    CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
        d.resource_class_code
    ELSE
        d.tsdf_approval_code
    END AS approval_or_resource,
    NULL as dot_description,        -- Populated later
    null as waste_code_1,           -- Populated later
    null as waste_code_2,           -- Populated later
    null as waste_code_3,           -- Populated later
    null as waste_code_4,           -- Populated later
    null as waste_code_5,           -- Populated later
    null as waste_code_6,           -- Populated later
    null as waste_code_7,           -- Populated later
    null as waste_code_8,           -- Populated later
    null as waste_code_9,           -- Populated later
    null as waste_code_10,          -- Populated later
    null as waste_code_11,          -- Populated later
    null as waste_code_12,          -- Populated later
    null as state_waste_code_1,     -- Populated later
    null as state_waste_code_2,     -- Populated later
    null as state_waste_code_3,     -- Populated later
    null as state_waste_code_4,     -- Populated later
    null as state_waste_code_5,     -- Populated later
    t.management_code AS management_code,
    t.EPA_source_code AS EPA_source_code,
    t.EPA_form_code AS EPA_form_code,
    null AS transporter1_name,      -- Populated later
    null as transporter1_epa_id,    -- Populated later
    null as transporter2_name,      -- Populated later
    null as transporter2_epa_id,    -- Populated later
    t2.TSDF_name AS receiving_facility,
    t2.TSDF_epa_id AS receiving_facility_epa_id,
    d.workorder_id as receipt_id,
    replace(
      CASE 
          WHEN t.disposal_service_id = (select disposal_service_id from DisposalService (nolock) where disposal_service_desc = 'Other') THEN 
              t.disposal_service_other_desc
          ELSE
              ds.disposal_service_desc
      END 
    , 'Incineration/Witness', 'Incineration') as disposal_service_desc,

    -- EQ Fields:
    w.company_id,
    w.profit_ctr_id,
    d.sequence_id,
    g.generator_id,
    g.generator_name AS generator_name,
    g.site_type AS site_type,
    d.manifest_page_num AS manifest_page,
    d.resource_type AS item_type,
    t.tsdf_approval_id,
    d.profile_id AS profile_id,
    ISNULL(d.container_count, 0) AS container_count,
    null, -- t.waste_code + ', ' + dbo.fn_approval_sec_waste_code_list(t.tsdf_approval_id, 'T') AS waste_codes,
    null, -- dbo.fn_sec_waste_code_list_state(t.tsdf_approval_id, 'T') AS state_waste_codes,
    wot1.transporter_code AS transporter1_code,
    wot2.transporter_code AS transporter2_code,
    wot1.transporter_sign_date AS date_delivered,
    'Workorder' AS source_table,
    NULL AS receipt_date,
    NULL AS receipt_workorder_id,
    w.start_date AS workorder_start_date,
    NULL AS workorder_company_id,
    NULL AS workorder_profit_ctr_id,
    w.customer_id AS customer_id,
    t.hazmat as haz_flag,
    w.submitted_flag,
    @usr,
    @extract_datetime
    
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
LEFT OUTER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T'
LEFT OUTER JOIN BillUnit b  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = b.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
    AND d.company_id = t.company_id
    AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN WorkOrderTransporter wot1 (nolock) ON w.workorder_id = wot1.workorder_id and w.company_id = wot1.company_id and w.profit_ctr_id = wot1.profit_ctr_id and d.manifest = wot1.manifest and wot1.transporter_sequence_id = 1
LEFT OUTER JOIN WorkOrderTransporter wot2 (nolock) ON w.workorder_id = wot2.workorder_id and w.company_id = wot2.company_id and w.profit_ctr_id = wot2.profit_ctr_id and d.manifest = wot2.manifest and wot2.transporter_sequence_id = 2
LEFT OUTER JOIN DisposalService ds  (nolock) ON t.disposal_service_id = ds.disposal_service_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
AND (w.customer_id IN (select customer_id from #Customer)
    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
    OR w.generator_id IN (
        SELECT generator_id FROM generator (nolock) where site_type IN (
            SELECT site_type from #SiteTypeToInclude
        )
    )
)
AND w.start_date BETWEEN @start_date AND @end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND d.resource_type = 'D'
AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
AND d.bill_rate NOT IN (-2)

print '3rd party WOs Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()



--  PRINT 'Receipt/Transporter Fix'
/*

12/7/2010 - The primary source for EQ data is the Receipt table.
	It's out of order in the select logic below and needs to be reviewed/revised
	because it's misleading.
	
This query has 2 union'd components:
first component: workorder inner join to billinglinklookup and receipt
third component: receipt not linked to either BLL or WMRWT
*/
    INSERT  EQ_Temp..WalmartDisposalReceiptTransporter
    select distinct
        r.receipt_id,
        r.line_id,
        r.company_id,
        r.profit_ctr_id,
        wo.workorder_id as receipt_workorder_id,
        wo.company_id as workorder_company_id,
        wo.profit_ctr_id as workorder_profit_ctr_id,
        isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
        r.receipt_date,
        'F' as calc_recent_wo_flag,
        CASE WHEN rt1.transporter_code IS NULL THEN
            r.hauler
        ELSE
            rt1.transporter_code 
        END as transporter1,
        rt2.transporter_code as transporter2,
        @usr,
        @extract_datetime        
    from workorderheader wo (nolock) 
    inner join billinglinklookup bll  (nolock) on
        wo.company_id = bll.source_company_id
        and wo.profit_ctr_id = bll.source_profit_ctr_id
        and wo.workorder_id = bll.source_id
    inner join receipt r  (nolock) on bll.receipt_id = r.receipt_id
        and bll.profit_ctr_id = r.profit_ctr_id
        and bll.company_id = r.company_id
    left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
        and rt1.profit_ctr_id = r.profit_ctr_id
        and rt1.company_id = r.company_id
        and rt1.transporter_sequence_id = 1
    left outer join receipttransporter rt2  (nolock) on rt2.receipt_id = r.receipt_id
        and rt2.profit_ctr_id = r.profit_ctr_id
        and rt2.company_id = r.company_id
        and rt2.transporter_sequence_id = 2
    inner join generator g  (nolock) on r.generator_id = g.generator_id
    where
        wo.start_date between @start_date AND @end_date
        and (1=0
            or wo.customer_id IN (select customer_id from #Customer)
            or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
            or r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
        )
    union
    select distinct
        r.receipt_id,
        r.line_id,
        r.company_id,
        r.profit_ctr_id,
        null as receipt_workorder_id,
        null as workorder_company_id,
        null as workorder_profit_ctr_id,
        rt1.transporter_sign_date as service_date,
        r.receipt_date,
        'F' as calc_recent_wo_flag,
        CASE WHEN rt1.transporter_code IS NULL THEN
            r.hauler
        ELSE
            rt1.transporter_code 
        END as transporter1,
        rt2.transporter_code as transporter2,
        @usr,
        @extract_datetime
    from receipt r (nolock) 
    inner join generator g  (nolock) on r.generator_id = g.generator_id
    left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
        and rt1.profit_ctr_id = r.profit_ctr_id
        and rt1.company_id = r.company_id
        and rt1.transporter_sequence_id = 1
    left outer join receipttransporter rt2  (nolock) on rt2.receipt_id = r.receipt_id
        and rt2.profit_ctr_id = r.profit_ctr_id
        and rt2.company_id = r.company_id
        and rt2.transporter_sequence_id = 2
    where
        coalesce(rt1.transporter_sign_date, r.receipt_date) between @start_date AND @end_date
        and (r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
        )
        and not exists (
            select receipt_id from billinglinklookup bll (nolock) 
            where bll.company_id = r.company_id
            and bll.profit_ctr_id = r.profit_ctr_id
            and bll.receipt_id = r.receipt_id
        )


print 'Receipt/Transporter Population Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Fix #ReceiptTransporter records...
    --  PRINT 'Can''t allow null transporter1 and populated transporter2, so move the data to transporter1 field.'
        UPDATE EQ_Temp..WalmartDisposalReceiptTransporter set transporter1 = transporter2
        WHERE ISNULL(transporter1, '') = '' and ISNULL(transporter2, '') <> ''
        AND added_by = @usr and date_added = @extract_datetime

    --  PRINT 'Can''t have the same transporter for both fields.'
        UPDATE EQ_Temp..WalmartDisposalReceiptTransporter set transporter2 = null
        WHERE transporter2 = transporter1
        AND added_by = @usr and date_added = @extract_datetime

print 'Receipt/Transporter Transporter Updates Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Receipts
INSERT EQ_TEMP.dbo.WalmartDisposalExtract
SELECT distinct
    -- Walmart Fields:
    g.site_code AS site_code,
    gst.generator_site_type_abbr AS site_type_abbr,
    g.generator_city AS generator_city,
    g.generator_state AS generator_state,
    wrt.service_date,
    g.epa_id,
    r.manifest AS manifest,
    CASE WHEN ISNULL(r.manifest_line, '') <> '' THEN
        CASE WHEN IsNumeric(r.manifest_line) <> 1 THEN
            dbo.fn_convert_manifest_line(r.manifest_line, r.manifest_page_num)
        ELSE
            r.manifest_line
        END
    ELSE
        NULL
    END AS manifest_line,
	NULL as pounds, -- pull in NULL for now, we'll update it from Receipt.Net_weight later - 12/20/2010
    b.bill_unit_desc AS bill_unit_desc,
    ISNULL(max(rp.bill_quantity), 0) AS quantity,
    p.Approval_desc AS waste_desc,
    COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
    NULL as dot_description,        -- Populated later
    null as waste_code_1,           -- Populated later
    null as waste_code_2,           -- Populated later
    null as waste_code_3,           -- Populated later
    null as waste_code_4,           -- Populated later
    null as waste_code_5,           -- Populated later
    null as waste_code_6,           -- Populated later
    null as waste_code_7,           -- Populated later
    null as waste_code_8,           -- Populated later
    null as waste_code_9,           -- Populated later
    null as waste_code_10,          -- Populated later
    null as waste_code_11,          -- Populated later
    null as waste_code_12,          -- Populated later
    null as state_waste_code_1,     -- Populated later
    null as state_waste_code_2,     -- Populated later
    null as state_waste_code_3,     -- Populated later
    null as state_waste_code_4,     -- Populated later
    null as state_waste_code_5,     -- Populated later
    tr.management_code,
    p.EPA_source_code,
    EPA_form_code,
    null AS transporter1_name,      -- Populated later
    null as transporter1_epa_id,    -- Populated later
    null as transporter2_name,      -- Populated later
    null as transporter2_epa_id,    -- Populated later
    pr.profit_ctr_name AS receiving_facility,
    (select epa_id from profitcenter  (nolock) where company_id = r.company_id and profit_ctr_id = r.profit_ctr_id) AS receiving_facility_epa_id,
    wrt.receipt_id,
    replace(
      dbo.fn_wm_disposal_method(
        ds.disposal_service_desc,
        pqa.disposal_service_other_desc,
        pqa.ob_tsdf_approval_id,
        pqa.ob_eq_profile_id,
        pqa.ob_eq_company_id,
        pqa.ob_eq_profit_ctr_id)
       , 'Incineration/Witness', 'Incineration') as disposal_service_desc,

    -- EQ Fields:
    wrt.company_id,
    wrt.profit_ctr_id,
    r.line_id,
    r.generator_id,
    g.generator_name AS generator_name,
    g.site_type AS site_type,
    r.manifest_page_num AS manifest_page,
    r.trans_type AS item_type,
    NULL AS tsdf_approval_id,
    r.profile_id,
    ISNULL(r.container_count, 0) AS container_count,
    null, -- dbo.fn_receipt_waste_code_list(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS waste_codes,
	null, -- dbo.fn_receipt_waste_code_list_state(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS state_waste_codes,
    wrt.transporter1 as transporter1_code,
    wrt.transporter2 as transporter2_code,
    r.receipt_date as date_delivered,
    'Receipt' AS source_table,
    r.receipt_date AS receipt_date,
    wrt.receipt_workorder_id,
    wrt.service_date AS workorder_start_date,
    wrt.workorder_company_id,
    wrt.workorder_profit_ctr_id,
    r.customer_id AS customer_id,
    p.hazmat as haz_flag,

    r.submitted_flag,
    @usr as added_by,
    @extract_datetime as date_added
    
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
    R.receipt_id = rp.receipt_id
    and r.line_id = rp.line_id
    and r.company_id = rp.company_id
    and r.profit_ctr_id = rp.profit_ctr_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
INNER JOIN EQ_Temp..WalmartDisposalReceiptTransporter wrt ON
    r.company_id = wrt.company_id
    and r.profit_ctr_id = wrt.profit_ctr_id
    and r.receipt_id = wrt.receipt_id
    and r.line_id = wrt.line_id
	AND wrt.added_by = @usr
	AND wrt.date_added = @extract_datetime
INNER JOIN ProfitCenter pr (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
LEFT OUTER JOIN Profile p  (nolock) ON r.profile_id = p.profile_id
LEFT OUTER JOIN Treatment tr  (nolock) ON r.treatment_id = tr.treatment_id
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN ProfileQuoteApproval pqa  (nolock)
    on r.profile_id = pqa.profile_id 
    and r.company_id = pqa.company_id 
    and r.profit_ctr_id = pqa.profit_ctr_id 
LEFT OUTER JOIN DisposalService ds  (nolock)
    on pqa.disposal_service_id = ds.disposal_service_id
WHERE r.receipt_status = 'A'
AND r.fingerpr_status = 'A'
AND ISNULL(r.trans_type, '') = 'D'
AND r.trans_mode = 'I'
GROUP BY
    g.site_code,
    gst.generator_site_type_abbr,
    g.generator_city,
    g.generator_state,
    wrt.service_date,
    g.EPA_ID,
    r.manifest,
    r.manifest_page_num,
    r.manifest_line,
    r.line_weight,
    b.bill_unit_desc,
    r.quantity,
    p.approval_desc,
    r.approval_code,
    r.service_desc,
    tr.management_code,
    p.EPA_source_code,
    p.EPA_form_code,
    wrt.transporter1,
    wrt.transporter2,
    pr.profit_ctr_name,
    r.company_id,
    r.profit_ctr_id,
    wrt.receipt_id,
    pqa.OB_TSDF_Approval_id,
    pqa.ob_eq_profile_id,
    pqa.ob_eq_company_id,
    pqa.ob_eq_profit_ctr_id,
    pqa.disposal_service_id,
    pqa.disposal_service_other_desc,
    ds.disposal_service_desc,
    wrt.company_id,
    wrt.profit_ctr_id,
    r.line_id,
    r.generator_id,
    g.generator_name,
    g.site_type,
    r.trans_type,
    r.profile_id,
    r.container_count,
    r.receipt_id,
    r.receipt_date,
    wrt.receipt_workorder_id,
    wrt.workorder_company_id,
    wrt.workorder_profit_ctr_id,
    r.customer_id,
    p.hazmat,
    r.submitted_flag

print 'Receipts Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- No-Waste Pickup Records:
INSERT EQ_TEMP.dbo.WalmartDisposalExtract
	SELECT DISTINCT
	-- Walmart Fields:
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	w.start_date AS service_date,
	g.epa_id AS epa_id,
	null AS manifest,
	1 AS manifest_line,
	0 AS pounds,
	null AS bill_unit_desc,
	0 AS quantity,
	'No waste picked up' AS waste_desc,
	null as approval_or_resource,
	null as dot_description,
	null as waste_code_1,
	null as waste_code_2,
	null as waste_code_3,
	null as waste_code_4,
	null as waste_code_5,
	null as waste_code_6,
	null as waste_code_7,
	null as waste_code_8,
	null as waste_code_9,
	null as waste_code_10,
	null as waste_code_11,
	null as waste_code_12,
	null as state_waste_code_1,
	null as state_waste_code_2,
	null as state_waste_code_3,
	null as state_waste_code_4,
	null as state_waste_code_5,
	null AS management_code,
	null AS EPA_source_code,
	null AS EPA_form_code,
	null AS transporter1_name,
	null as transporter1_epa_id,
	null AS transporter2_name,
	null as transporter2_epa_id,
	null AS receiving_facility,
	null AS receiving_facility_epa_id,
	d.workorder_id as receipt_id,
	null as disposal_service_desc,

	-- EQ Fields:
	w.company_id,
	w.profit_ctr_id,
	null as sequence_id,
	g.generator_id,
	g.generator_name AS generator_name,
	g.site_type AS site_type,
	null AS manifest_page,
	'N' AS item_type,
	null as tsdf_approval_id,
	NULL AS profile_id,
	0 AS container_count,
	'' AS waste_codes,
	'' AS state_waste_codes,
	null as transporter1_code,
	null as transporter2_code,
	null AS date_delivered,
	'Workorder' AS source_table,
	NULL AS receipt_date,
	NULL AS receipt_workorder_id,
	w.start_date AS workorder_start_date,
	NULL AS workorder_company_id,
	NULL AS workorder_profit_ctr_id,
	w.customer_id AS customer_id,
	null AS haz_flag,

	'T' as submitted_flag,
	@usr as added_by,
	@extract_datetime as date_added
	 
	FROM WorkOrderHeader w (nolock) 
	INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
	INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
    LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
    LEFT OUTER JOIN WorkOrderStop wos (nolock) ON w.workorder_id = wos.workorder_id and w.company_id = wos.company_id and w.profit_ctr_id = wos.profit_ctr_id 
    	and wos.stop_sequence_id = 1
	WHERE 1=1
	AND (w.customer_id IN (select customer_id from #Customer)
	    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
	    OR w.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
	)
	AND w.start_date BETWEEN @start_date AND @end_date
	AND w.submitted_flag = 'T'
	AND w.workorder_status IN ('A','C','D','N','P','X')
	AND d.bill_rate NOT IN (-2)
	AND d.resource_class_code = 'STOPFEE'
	AND wos.decline_id > 1
	AND (
--	    (isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
       (isnull(w.billing_project_id, 0) IN (select billing_project_id from #BillingProject) and w.customer_id IN (select customer_id from #customer))
	    OR
	    (wos.waste_flag = 'F')
	)    

print 'No Waste Pickup records finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Create a table for waste codes
	create table #WM_Waste_Codes (
		source	varchar(20),
		tsdf_approval_id	int,
		receipt_id			int,
		line_id				int,
		company_id			int,
		profit_ctr_id		int,
		sequence_id			int,
		origin				char(1),
		waste_code			varchar(10)
	)
	create index idx_1 on #WM_Waste_Codes (source, tsdf_approval_id, origin, sequence_id, waste_code)
	create index idx_2 on #WM_Waste_Codes (source, receipt_id, line_id, company_id, profit_ctr_id, origin, sequence_id, waste_code)

-- Workorder Waste Codes (1)
	insert #WM_Waste_Codes (source, tsdf_approval_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.tsdf_approval_id,
		1 as sequence_id,
		wc.waste_code_origin,
		xwc.waste_code
	FROM TSDFApprovalWasteCode xwc (nolock)
		INNER JOIN WasteCode wc (nolock) ON xwc.waste_code = wc.waste_code
		INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime


print 'Workorder Waste Codes (1), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Workorder Waste Codes (2+)
	insert #WM_Waste_Codes (source, tsdf_approval_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.tsdf_approval_id,
		2,
		wc.waste_code_origin,
		xwc.waste_code
	FROM TSDFApprovalWasteCode xwc (nolock)
		INNER JOIN WasteCode wc (nolock) ON xwc.waste_code = wc.waste_code
		INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		and xwc.waste_code not in (select waste_code from #WM_Waste_Codes
			where source = e.source_table 
			and tsdf_approval_id = xwc.tsdf_approval_id 
			)
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime
	ORDER BY xwc.waste_code

print 'Workorder Waste Codes (2+), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Receipt Waste Codes (1)
	insert #WM_Waste_codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.receipt_id,
		xwc.line_id,
		xwc.company_id,
		xwc.profit_ctr_id,
		1 as sequence_id,
		wc.waste_code_origin,
		xwc.waste_code
	FROM ReceiptWasteCode xwc (nolock)
	INNER JOIN wastecode wc (nolock) on xwc.waste_code = wc.waste_code
	INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
		on e.receipt_id = xwc.receipt_id
		and e.line_sequence_id = xwc.line_id
		and e.company_id = xwc.company_id
		and e.profit_ctr_id = xwc.profit_ctr_id
	WHERE e.source_table = 'Receipt'
		and e.submitted_flag = 'T'
		AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime

print 'Receipt Waste Codes (1), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Receipt Waste Codes (2+)
	insert #WM_Waste_codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.receipt_id,
		xwc.line_id,
		xwc.company_id,
		xwc.profit_ctr_id,
		2 as sequence_id,
		wc.waste_code_origin,
		xwc.waste_code
	FROM ReceiptWasteCode xwc (nolock)
	INNER JOIN wastecode wc (nolock) on xwc.waste_code = wc.waste_code
	INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
		on e.receipt_id = xwc.receipt_id
		and e.line_sequence_id = xwc.line_id
		and e.company_id = xwc.company_id
		and e.profit_ctr_id = xwc.profit_ctr_id
	WHERE e.source_table = 'Receipt'
		and e.submitted_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		and xwc.waste_code not in (select waste_code from #WM_Waste_Codes
			where source = e.source_table 
			and receipt_id = xwc.receipt_id
			and line_id = xwc.line_id
			and company_id = xwc.company_id
			and profit_ctr_id = xwc.profit_ctr_id
			)
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime
	ORDER BY xwc.waste_code

print 'Workorder Waste Codes (1), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Don't include UNIV
delete from #WM_Waste_Codes where waste_code = 'UNIV'

-- Don't include NONE
delete from #WM_Waste_Codes where waste_code = 'NONE'

-- Don't include .
delete from #WM_Waste_Codes where waste_code = '.'

print 'Waste Code Cleanup, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Number the sequence 2+ rows
declare @incrementer int = 2
update #WM_Waste_Codes 
set @incrementer = sequence_id = @incrementer + 1
where sequence_id > 1

print 'Waste Codes (2+) Numbering, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Fix gaps: Workorder
UPDATE #WM_Waste_Codes
  SET sequence_id
      = (SELECT COUNT(sequence_id)
           FROM #WM_Waste_Codes AS G1
          WHERE G1.sequence_id < #WM_Waste_Codes.sequence_id
          and G1.source = 'Workorder'
          and G1.tsdf_approval_id = #WM_Waste_Codes.tsdf_approval_id
          and G1.origin = #WM_Waste_codes.origin
          ) + 1
WHERE source = 'Workorder'

print 'Waste Code (Workorder) Gap Fix, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

         
-- Fix gaps: Receipt
UPDATE #WM_Waste_Codes
  SET sequence_id
      = (SELECT COUNT(sequence_id)
           FROM #WM_Waste_Codes AS G1
          WHERE G1.sequence_id < #WM_Waste_Codes.sequence_id
          and G1.source = 'Receipt'
          and G1.receipt_id = #WM_Waste_Codes.receipt_id
          and G1.line_id = #WM_Waste_Codes.line_id
          and G1.company_id = #WM_Waste_Codes.company_id
          and G1.profit_ctr_id = #WM_Waste_Codes.profit_ctr_id
          and G1.origin = #WM_Waste_Codes.origin
          ) + 1
WHERE source = 'Receipt'

print 'Waste Codes (Receipt) Gap Fix, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Update fields left null in #Extract
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract set
    dot_description =
        CASE WHEN e.tsdf_approval_id IS NOT NULL THEN
            left(dbo.fn_manifest_dot_description('T', e.tsdf_approval_id), 255)
        ELSE
            CASE WHEN e.profile_id IS NOT NULL THEN
                left(dbo.fn_manifest_dot_description('P', e.profile_id), 255)
            ELSE
                ''
            END
        END,
    transporter1_name = t1.transporter_name,
    transporter1_epa_id = t1.transporter_epa_id,
    transporter2_name = t2.transporter_name,
    transporter2_epa_id = t2.transporter_epa_id
FROM 
	EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
	left outer join Transporter t1 (nolock)
		on e.transporter1_code = t1.transporter_code
	left outer join Transporter t2 (nolock)
		on e.transporter2_code = t2.transporter_code
WHERE e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

print 'Update fields left null (dot, trans), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

		
-- Update Waste Codes for WOs		
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract set
    waste_code_1  = coalesce(ft1.waste_code, 'NONE'),
    waste_code_2  = coalesce(ft2.waste_code, ''),
    waste_code_3  = coalesce(ft3.waste_code, ''),
    waste_code_4  = coalesce(ft4.waste_code, ''),
    waste_code_5  = coalesce(ft5.waste_code, ''),
    waste_code_6  = coalesce(ft6.waste_code, ''),
    waste_code_7  = coalesce(ft7.waste_code, ''),
    waste_code_8  = coalesce(ft8.waste_code, ''),
    waste_code_9  = coalesce(ft9.waste_code, ''),
    waste_code_10 = coalesce(ft10.waste_code, ''),
    waste_code_11 = coalesce(ft11.waste_code, ''),
    waste_code_12 = coalesce(ft12.waste_code, ''),
    state_waste_code_1 = coalesce(st1.waste_code, 'NONE'),
    state_waste_code_2 = coalesce(st2.waste_code, ''),
    state_waste_code_3 = coalesce(st3.waste_code, ''),
    state_waste_code_4 = coalesce(st4.waste_code, ''),
    state_waste_code_5 = coalesce(st5.waste_code, '')
FROM 
	EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
	left outer join #WM_Waste_codes ft1 on  ft1.source = e.source_table and ft1.tsdf_approval_id = e.tsdf_approval_id and ft1.origin = 'F' and ft1.sequence_id = 1
	left outer join #WM_Waste_codes ft2 on  ft2.source = e.source_table and ft2.tsdf_approval_id = e.tsdf_approval_id and ft2.origin = 'F' and ft2.sequence_id = 2		
	left outer join #WM_Waste_codes ft3 on  ft3.source = e.source_table and ft3.tsdf_approval_id = e.tsdf_approval_id and ft3.origin = 'F' and ft3.sequence_id = 3		
	left outer join #WM_Waste_codes ft4 on  ft4.source = e.source_table and ft4.tsdf_approval_id = e.tsdf_approval_id and ft4.origin = 'F' and ft4.sequence_id = 4		
	left outer join #WM_Waste_codes ft5 on  ft5.source = e.source_table and ft5.tsdf_approval_id = e.tsdf_approval_id and ft5.origin = 'F' and ft5.sequence_id = 5		
	left outer join #WM_Waste_codes ft6 on  ft6.source = e.source_table and ft6.tsdf_approval_id = e.tsdf_approval_id and ft6.origin = 'F' and ft6.sequence_id = 6		
	left outer join #WM_Waste_codes ft7 on  ft7.source = e.source_table and ft7.tsdf_approval_id = e.tsdf_approval_id and ft7.origin = 'F' and ft7.sequence_id = 7		
	left outer join #WM_Waste_codes ft8 on  ft8.source = e.source_table and ft8.tsdf_approval_id = e.tsdf_approval_id and ft8.origin = 'F' and ft8.sequence_id = 8
	left outer join #WM_Waste_codes ft9 on  ft9.source = e.source_table and ft9.tsdf_approval_id = e.tsdf_approval_id and ft9.origin = 'F' and ft9.sequence_id = 9
	left outer join #WM_Waste_codes ft10 on ft10.source = e.source_table and ft10.tsdf_approval_id = e.tsdf_approval_id and ft10.origin = 'F' and ft10.sequence_id = 10
	left outer join #WM_Waste_codes ft11 on ft11.source = e.source_table and ft11.tsdf_approval_id = e.tsdf_approval_id and ft11.origin = 'F' and ft11.sequence_id = 11
	left outer join #WM_Waste_codes ft12 on ft12.source = e.source_table and ft12.tsdf_approval_id = e.tsdf_approval_id and ft12.origin = 'F' and ft12.sequence_id = 12
	left outer join #WM_Waste_codes st1 on st1.source = e.source_table and st1.tsdf_approval_id = e.tsdf_approval_id and st1.origin = 'S' and st1.sequence_id = 1
	left outer join #WM_Waste_codes st2 on st2.source = e.source_table and st2.tsdf_approval_id = e.tsdf_approval_id and st2.origin = 'S' and st2.sequence_id = 2
	left outer join #WM_Waste_codes st3 on st3.source = e.source_table and st3.tsdf_approval_id = e.tsdf_approval_id and st3.origin = 'S' and st3.sequence_id = 3
	left outer join #WM_Waste_codes st4 on st4.source = e.source_table and st4.tsdf_approval_id = e.tsdf_approval_id and st4.origin = 'S' and st4.sequence_id = 4
	left outer join #WM_Waste_codes st5 on st5.source = e.source_table and st5.tsdf_approval_id = e.tsdf_approval_id and st5.origin = 'S' and st5.sequence_id = 5
WHERE e.source_table = 'Workorder'
and e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

print 'Update fields left null (WO waste codes), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Update Waste Codes for Receipts
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract set
    waste_code_1  = coalesce(fr1.waste_code, 'NONE'),
    waste_code_2  = coalesce(fr2.waste_code, ''),
    waste_code_3  = coalesce(fr3.waste_code, ''),
    waste_code_4  = coalesce(fr4.waste_code, ''),
    waste_code_5  = coalesce(fr5.waste_code, ''),
    waste_code_6  = coalesce(fr6.waste_code, ''),
    waste_code_7  = coalesce(fr7.waste_code, ''),
    waste_code_8  = coalesce(fr8.waste_code, ''),
    waste_code_9  = coalesce(fr9.waste_code, ''),
    waste_code_10 = coalesce(fr10.waste_code, ''),
    waste_code_11 = coalesce(fr11.waste_code, ''),
    waste_code_12 = coalesce(fr12.waste_code, ''),
    state_waste_code_1 = coalesce(sr1.waste_code, 'NONE'),
    state_waste_code_2 = coalesce(sr2.waste_code, ''),
    state_waste_code_3 = coalesce(sr3.waste_code, ''),
    state_waste_code_4 = coalesce(sr4.waste_code, ''),
    state_waste_code_5 = coalesce(sr5.waste_code, '')
FROM 
	EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
	left outer join #WM_Waste_Codes fr1 on fr1.source = e.source_table and fr1.receipt_id = e.receipt_id and fr1.line_id = e.line_sequence_id and fr1.company_id = e.company_id and fr1.profit_ctr_id = e.profit_ctr_id and fr1.origin = 'F' and fr1.sequence_id = 1
	left outer join #WM_Waste_Codes fr2 on fr2.source = e.source_table and fr2.receipt_id = e.receipt_id and fr2.line_id = e.line_sequence_id and fr2.company_id = e.company_id and fr2.profit_ctr_id = e.profit_ctr_id and fr2.origin = 'F' and fr2.sequence_id = 2
	left outer join #WM_Waste_Codes fr3 on fr3.source = e.source_table and fr3.receipt_id = e.receipt_id and fr3.line_id = e.line_sequence_id and fr3.company_id = e.company_id and fr3.profit_ctr_id = e.profit_ctr_id and fr3.origin = 'F' and fr3.sequence_id = 3
	left outer join #WM_Waste_Codes fr4 on fr4.source = e.source_table and fr4.receipt_id = e.receipt_id and fr4.line_id = e.line_sequence_id and fr4.company_id = e.company_id and fr4.profit_ctr_id = e.profit_ctr_id and fr4.origin = 'F' and fr4.sequence_id = 4
	left outer join #WM_Waste_Codes fr5 on fr5.source = e.source_table and fr5.receipt_id = e.receipt_id and fr5.line_id = e.line_sequence_id and fr5.company_id = e.company_id and fr5.profit_ctr_id = e.profit_ctr_id and fr5.origin = 'F' and fr5.sequence_id = 5
	left outer join #WM_Waste_Codes fr6 on fr6.source = e.source_table and fr6.receipt_id = e.receipt_id and fr6.line_id = e.line_sequence_id and fr6.company_id = e.company_id and fr6.profit_ctr_id = e.profit_ctr_id and fr6.origin = 'F' and fr6.sequence_id = 6
	left outer join #WM_Waste_Codes fr7 on fr7.source = e.source_table and fr7.receipt_id = e.receipt_id and fr7.line_id = e.line_sequence_id and fr7.company_id = e.company_id and fr7.profit_ctr_id = e.profit_ctr_id and fr7.origin = 'F' and fr7.sequence_id = 7
	left outer join #WM_Waste_Codes fr8 on fr8.source = e.source_table and fr8.receipt_id = e.receipt_id and fr8.line_id = e.line_sequence_id and fr8.company_id = e.company_id and fr8.profit_ctr_id = e.profit_ctr_id and fr8.origin = 'F' and fr8.sequence_id = 8
	left outer join #WM_Waste_Codes fr9 on fr9.source = e.source_table and fr9.receipt_id = e.receipt_id and fr9.line_id = e.line_sequence_id and fr9.company_id = e.company_id and fr9.profit_ctr_id = e.profit_ctr_id and fr9.origin = 'F' and fr9.sequence_id = 9
	left outer join #WM_Waste_Codes fr10 on fr10.source = e.source_table and fr10.receipt_id = e.receipt_id and fr10.line_id = e.line_sequence_id and fr10.company_id = e.company_id and fr10.profit_ctr_id = e.profit_ctr_id and fr10.origin = 'F' and fr10.sequence_id = 10
	left outer join #WM_Waste_Codes fr11 on fr11.source = e.source_table and fr11.receipt_id = e.receipt_id and fr11.line_id = e.line_sequence_id and fr11.company_id = e.company_id and fr11.profit_ctr_id = e.profit_ctr_id and fr11.origin = 'F' and fr11.sequence_id = 11 
	left outer join #WM_Waste_Codes fr12 on fr12.source = e.source_table and fr12.receipt_id = e.receipt_id and fr12.line_id = e.line_sequence_id and fr12.company_id = e.company_id and fr12.profit_ctr_id = e.profit_ctr_id and fr12.origin = 'F' and fr12.sequence_id = 12
	left outer join #WM_Waste_Codes sr1 on sr1.source = e.source_table and sr1.receipt_id = e.receipt_id  and sr1.line_id = e.line_sequence_id and sr1.company_id = e.company_id and sr1.profit_ctr_id = e.profit_ctr_id and sr1.origin = 'S' and sr1.sequence_id = 1 
	left outer join #WM_Waste_Codes sr2 on sr2.source = e.source_table and sr2.receipt_id = e.receipt_id and sr2.line_id = e.line_sequence_id and sr2.company_id = e.company_id and sr2.profit_ctr_id = e.profit_ctr_id and sr2.origin = 'S' and sr2.sequence_id = 2
	left outer join #WM_Waste_Codes sr3 on sr3.source = e.source_table and sr3.receipt_id = e.receipt_id and sr3.line_id = e.line_sequence_id and sr3.company_id = e.company_id and sr3.profit_ctr_id = e.profit_ctr_id and sr3.origin = 'S' and sr3.sequence_id = 3
	left outer join #WM_Waste_Codes sr4 on sr4.source = e.source_table and sr4.receipt_id = e.receipt_id and sr4.line_id = e.line_sequence_id and sr4.company_id = e.company_id and sr4.profit_ctr_id = e.profit_ctr_id and sr4.origin = 'S' and sr4.sequence_id = 4
	left outer join #WM_Waste_Codes sr5 on sr5.source = e.source_table and sr5.receipt_id = e.receipt_id and sr5.line_id = e.line_sequence_id and sr5.company_id = e.company_id and sr5.profit_ctr_id = e.profit_ctr_id and sr5.origin = 'S' and sr5.sequence_id = 5
WHERE e.source_table = 'Receipt' and e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

print 'Update fields left null (R waste codes), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

/*
Texas waste codes are 8 digits, and wouldn't fit into the wastecode table's waste_code field.
BUT, the waste_code field on those records is unique, so EQ systems handle it correctly, but we
need to remember to update the extract to swap the waste_description (the TX 8 digit code) for
the waste_code for waste_codes that are from TX.
*/
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_1 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_1 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_2 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_2 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_3 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_3 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_4 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_4 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_5 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_5 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'

print 'Texas Waste Code Updates, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


/*
12/20/2010 - Weight mismatch handling (notice I don't call it "fix")
	12/20/2010 - JPB
		1. Complaint received that Disposal != Generation log weights (and != receipt.net_weight).
			This is because receipt net_weight is divided across the number of lines on the extract
			and means a DM05 and DM55 are shown as each 1/2 of the total.  Silly, but WM.
			Fix: After the extract is completely populated, go back over it for each mismatch
			between sum(disposal extract weights) != receipt.net_weight and set the FIRST record
			for each set in the extract +/- whatever required to make the sum of them match the
			receipt.net_weight.
			
			
1. Set the timestamp on the EQ_TEMP records back by 3.  Then select insert them into EQ_Temp again, at the right timestamp?
	-- 40 chars avail, longest ever is 18, should be fine.
			
*/
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET date_added = dateadd(s, -3, @extract_datetime) where date_added = @extract_datetime AND source_table = 'Receipt'

print 'Move current run back 3 seconds, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

INSERT EQ_TEMP.dbo.WalmartDisposalExtract
SELECT
	e.site_code,
	e.site_type_abbr,
	e.generator_city,
	e.generator_state,
	e.service_date,
	e.epa_id,
	e.manifest,
	e.manifest_line,
    convert(int, round((case when isnull(R.line_weight, 0) between 0.0001 and 1 then 1 else isnull(R.line_weight, 0) end), 0)) as pounds,
	dbo.fn_wm_extract_line_convert_eq_temp(e.manifest, e.manifest_line, @usr, dateadd(s, -3, @extract_datetime)) as bill_unit_desc,
    SUM(ISNULL(e.quantity, 0)) as quantity,
	e.waste_desc,
	e.approval_or_resource,
	e.dot_description,
	e.waste_code_1,
	e.waste_code_2,
	e.waste_code_3,
	e.waste_code_4,
	e.waste_code_5,
	e.waste_code_6,
	e.waste_code_7,
	e.waste_code_8,
	e.waste_code_9,
	e.waste_code_10,
	e.waste_code_11,
	e.waste_code_12,
	e.state_waste_code_1,
	e.state_waste_code_2,
	e.state_waste_code_3,
	e.state_waste_code_4,
	e.state_waste_code_5,
	e.management_code,
	e.EPA_source_code,
	e.EPA_form_code,
	e.transporter1_name,
	e.transporter1_epa_id,
	e.transporter2_name,
	e.transporter2_epa_id,
	e.receiving_facility,
	e.receiving_facility_epa_id,
	e.receipt_id,
	e.disposal_service_desc,
	e.company_id,
	e.profit_ctr_id,
	e.line_sequence_id,
	e.generator_id,
	e.generator_name,
	e.site_type,
	e.manifest_page,
	e.item_type,
	e.tsdf_approval_id,
	e.profile_id,
	e.container_count,
	e.waste_codes,
	e.state_waste_codes,
	e.transporter1_code,
	e.transporter2_code,
	e.date_delivered,
	e.source_table,
	e.receipt_date,
	e.receipt_workorder_id,
	e.workorder_start_date,
	e.workorder_company_id,
	e.workorder_profit_ctr_id,
	e.customer_id,
	e.haz_flag,
	e.submitted_flag,
	@usr as added_by,
	@extract_datetime as date_added
FROM EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
INNER JOIN Receipt r (nolock)
	ON e.receipt_id = r.receipt_id
	and e.line_sequence_id = r.line_id
	AND e.company_id = r.company_id
	and e.profit_ctr_id = r.profit_ctr_id
WHERE e.date_added = dateadd(s, -3, @extract_datetime)
GROUP BY	
	e.site_code,
	e.site_type_abbr,
	e.generator_city,
	e.generator_state,
	e.service_date,
	e.epa_id,
	e.manifest,
	e.manifest_line,
	r.line_weight,
	e.waste_desc,
	e.approval_or_resource,
	e.dot_description,
	e.waste_code_1,
	e.waste_code_2,
	e.waste_code_3,
	e.waste_code_4,
	e.waste_code_5,
	e.waste_code_6,
	e.waste_code_7,
	e.waste_code_8,
	e.waste_code_9,
	e.waste_code_10,
	e.waste_code_11,
	e.waste_code_12,
	e.state_waste_code_1,
	e.state_waste_code_2,
	e.state_waste_code_3,
	e.state_waste_code_4,
	e.state_waste_code_5,
	e.management_code,
	e.EPA_source_code,
	e.EPA_form_code,
	e.transporter1_name,
	e.transporter1_epa_id,
	e.transporter2_name,
	e.transporter2_epa_id,
	e.receiving_facility,
	e.receiving_facility_epa_id,
	e.receipt_id,
	e.disposal_service_desc,
	e.company_id,
	e.profit_ctr_id,
	e.line_sequence_id,
	e.generator_id,
	e.generator_name,
	e.site_type,
	e.manifest_page,
	e.item_type,
	e.tsdf_approval_id,
	e.profile_id,
	e.container_count,
	e.waste_codes,
	e.state_waste_codes,
	e.transporter1_code,
	e.transporter2_code,
	e.date_delivered,
	e.source_table,
	e.receipt_date,
	e.receipt_workorder_id,
	e.workorder_start_date,
	e.workorder_company_id,
	e.workorder_profit_ctr_id,
	e.customer_id,
	e.haz_flag,
	e.submitted_flag


-- EQ_TEMP.dbo.WalmartDisposalExtract is finished now.

print 'Copy current run to new instance summing quantity, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Create Image Lists
INSERT EQ_TEMP..WalmartExtractImages
    (site_code, generator_id, service_date, image_id, document_name, document_type, page_number, file_type, filename, process_flag, newname, added_by, date_added)
SELECT DISTINCT
    site_code,
    t.generator_id,
    service_date,
    s.image_id, s.document_name, sdt.document_type, s.page_number, s.file_type,
    CONVERT(varchar(60), RIGHT('00000' + ltrim(rtrim(ISNULL(site_code,''))), 5) + 'D_' +
        case when service_date is null then '00000000' else
            RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)),2) +
            RIGHT('00' + CONVERT(varchar(2), DATEPART(dd, service_date)),2) +
            RIGHT('0000' + CONVERT(varchar(4), DATEPART(yyyy, service_date)), 4) 
        end +
        '_' + replace(sdt.document_type, ' ', '_') +
        '_') AS filename,
    0 AS process_flag,
    NULL AS newname,
    @usr as added_by,
    @extract_datetime as date_added
FROM EQ_TEMP.dbo.WalmartDisposalExtract t (nolock) 
INNER JOIN plt_image..scan s  (nolock) on s.company_id = t.company_id
    and s.profit_ctr_id = t.profit_ctr_id
    and (
        (s.workorder_id = t.receipt_id and s.document_source = 'workorder')
    )
    and s.status = 'A'
INNER JOIN plt_image..scandocumenttype sdt  (nolock) on s.type_id = sdt.type_id and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
WHERE item_type = 'D'
AND t.added_by = @usr 
AND t.date_added = @extract_datetime
AND t.submitted_flag = 'T'
UNION
SELECT DISTINCT
site_code,
t.generator_id,
service_date,
s.image_id, s.document_name, sdt.document_type, s.page_number, s.file_type,
CONVERT(varchar(60), RIGHT('00000' + ltrim(rtrim(ISNULL(site_code,''))), 5) + 'D_' +
    case when service_date is null then '00000000' else
        RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)),2) +
        RIGHT('00' + CONVERT(varchar(2), DATEPART(dd, service_date)),2) +
        RIGHT('0000' + CONVERT(varchar(4), DATEPART(yyyy, service_date)), 4) 
    end +
    '_' + replace(sdt.document_type, ' ', '_') +
    '_') AS filename,
0 AS process_flag,
NULL AS newname,
    
    @usr as added_by,
    @extract_datetime as date_added

FROM EQ_TEMP.dbo.WalmartDisposalExtract t (nolock) 
inner join plt_image..scan s  (nolock) on s.company_id = t.company_id
and s.profit_ctr_id = t.profit_ctr_id
and (
    (s.workorder_id = t.receipt_workorder_id and s.document_source = 'workorder')
)
and s.status = 'A'
inner join plt_image..scandocumenttype sdt (nolock) on s.type_id = sdt.type_id and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
WHERE item_type = 'D'
AND t.added_by = @usr 
AND t.date_added = @extract_datetime
AND t.submitted_flag = 'T'

UNION

SELECT DISTINCT
    site_code,
    t.generator_id,
    service_date,
    s.image_id, s.document_name, sdt.document_type, s.page_number, s.file_type,
    CONVERT(varchar(60), RIGHT('00000' + ltrim(rtrim(ISNULL(site_code,''))), 5) + 'D_' +
        case when service_date is null then '00000000' else
            RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)),2) +
            RIGHT('00' + CONVERT(varchar(2), DATEPART(dd, service_date)),2) +
            RIGHT('0000' + CONVERT(varchar(4), DATEPART(yyyy, service_date)), 4)
        end +
        '_' + replace(sdt.document_type, ' ', '_') +
        '_') AS filename,
    0 AS process_flag,
    NULL AS newname,
    
    @usr as added_by,
    @extract_datetime as date_added

FROM EQ_TEMP.dbo.WalmartDisposalExtract t (nolock) 
inner join plt_image..scan s  (nolock) on s.company_id = t.company_id
    and s.profit_ctr_id = t.profit_ctr_id
    and (
        (s.receipt_id = t.receipt_id and s.document_source = 'receipt')
    )
    and s.status = 'A'
inner join plt_image..scandocumenttype sdt (nolock) on s.type_id = sdt.type_id and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
WHERE item_type = 'D'
AND t.added_by = @usr 
AND t.date_added = @extract_datetime
AND t.submitted_flag = 'T'

ORDER BY site_code, service_date, page_number

print 'Create List of Images, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Update the 'newname' column for calculating name changes.
UPDATE EQ_TEMP..WalmartExtractImages SET newname = filename
WHERE added_by = @usr 
AND date_added = @extract_datetime


-- remove duplicate flag from images that aren't duplicates (only 1 mention of the generator)
-- (duplicates are images from a 2 sites with the same site code, where one is active, one is inactive, on the same day)
-- Why the following query is correct:
--    Newname includes the facility # and date of service.  count of distinct generators will tell you how many have the same site # & date.
UPDATE EQ_TEMP..WalmartExtractImages
    SET newname = replace(newname, 'D_', '_')
WHERE newname IN (
    SELECT newname FROM (
        SELECT newname, count(distinct generator_id) AS gen_count
        FROM EQ_TEMP..WalmartExtractImages (nolock) 
        WHERE added_by = @usr 
        AND date_added = @extract_datetime
        GROUP BY newname HAVING count(distinct generator_id) = 1
    ) a
)
AND added_by = @usr 
AND date_added = @extract_datetime

print 'Setting Image FileNames, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- remove duplicate flag from images that aren't duplicates
-- ('A'ctive generators are the original records, inactive are the duplicates)
UPDATE EQ_TEMP..WalmartExtractImages
    SET newname = replace(newname, 'D_', '_')
WHERE newname IN (
    SELECT newname 
    FROM EQ_TEMP..WalmartExtractImages (nolock) 
    WHERE newname LIKE '%D_%'
	AND added_by = @usr
	AND date_added = @extract_datetime
)
AND generator_id NOT IN (select generator_id FROM generator (nolock) where status <> 'A')
AND added_by = @usr 
AND date_added = @extract_datetime

print 'Clearing Image Filename Duplicate Flags, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Add a sequence'd id to the images to avoid overwriting images from multiple manifest pages.
UPDATE EQ_TEMP..WalmartExtractImages set
    newname = newname + CONVERT(varchar(5),
        (
            row_id -
            (
            	select min(row_id) 
            	FROM EQ_TEMP..WalmartExtractImages i2 (nolock) 
            	WHERE i2.newname = EQ_TEMP..WalmartExtractImages.newname
				AND added_by = @usr
				AND date_added = @extract_datetime
            )
        ) + 1
    ) + '.' + file_type
WHERE added_by = @usr 
AND date_added = @extract_datetime

print 'Adding sequence ids to duplicate filenames, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


 -- Trip Export Information (where the data actually comes from workorder info that exists for disposal manifest info)
INSERT EQ_Extract..WMDisposalGeneration
  SELECT distinct
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date as shipment_date,
      case when wodi.month is null or wodi.year is null then
		convert(datetime, 
			convert(varchar(2), datepart(m, f.service_date)) + '/01/' + convert(varchar(4), datepart(yyyy, f.service_date))
		)
		else
			convert(datetime, convert(varchar(2), wodi.month) + '/01/' + CONVERT(varchar(4), wodi.year)) 
	  end as generation_date,
      f.epa_id,
      CASE WHEN 
				convert(numeric(6,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) BETWEEN 0.0001 AND 1.0 THEN 
		1.0
	  ELSE
			round(
				convert(numeric(6,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) 	  
			, 1)
	  END as Weight,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
      NULL, 
      'F' as calculated_flag,
	  exclude_flag = 
		  CASE WHEN (1=0
		  	-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
		  	OR f.site_type LIKE '%Optical Lab%'
		  	OR f.site_type LIKE '%DC%'
		  	OR f.site_type LIKE '%Return Center%'
		  	OR f.site_type LIKE '%PMDC%'
		  ) THEN 
			  'T'
		  ELSE
		  	/*
		  	exclude any non-hazardous or universal waste approvals: 
				approval numbers WMNHW01-WMNHW16, WMUW01-WMUW03 
				approvals that do not contain a RCRA hazardous waste code (D, F, K, P, U)
			*/
			  CASE WHEN (1=0
			  	OR f.approval_or_resource IN ('WMNHW01','WMNHW02','WMNHW03','WMNHW04','WMNHW05','WMNHW06','WMNHW07','WMNHW08','WMNHW09','WMNHW10','WMNHW11','WMNHW12','WMNHW13','WMNHW14','WMNHW15','WMNHW16')
				OR f.approval_or_resource IN ('WMUW01', 'WMUW02', 'WMUW03')
			  ) THEN
			  	'T'
			  ELSE
			  	CASE WHEN NOT EXISTS (
			  		SELECT tawc.waste_code
			  		FROM TSDFApprovalWasteCode tawc  (nolock)
			  		INNER JOIN WasteCode wc (nolock) on tawc.waste_code = wc.waste_code
			  		WHERE tawc.tsdf_approval_id = f.tsdf_approval_id
			  		AND tawc.company_id = f.company_id
			  		AND tawc.profit_ctr_id = f.profit_ctr_id
			  		AND f.tsdf_approval_id is not null
			  		AND wc.waste_code_origin = 'F'
			  		AND left(wc.waste_code, 1) in ('D', 'F', 'P', 'K', 'U')
			  		AND wc.haz_flag = 'T'
			  	) THEN
			  		'T'
			  	ELSE
			  		'F'
			  	END
			  END
			END,
	  @usr as added_by,
	  @extract_datetime as date_added
      , CASE WHEN CHARINDEX(',P', ',' + waste_code_1 + ',' +waste_code_2 + ',' +waste_code_3 + ',' +waste_code_4 + ',' +waste_code_5 + ',' +waste_code_6 + ',' +waste_code_7 + ',' +waste_code_8 + ',' +waste_code_9 + ',' +waste_code_10 + ',' +waste_code_11 + ',' +waste_code_12) <= 0 THEN
				''
			ELSE
			'P'
		END AS plisted
  from EQ_TEMP.dbo.WalmartDisposalExtract f (nolock)
  inner join tsdfapproval tsdfa (nolock) on f.tsdf_approval_id = tsdfa.tsdf_approval_id
  inner join tsdf (nolock) on tsdfa.tsdf_code = tsdf.tsdf_code and tsdf.eq_flag = 'F'
  inner join workorderheader woh (nolock)       on f.receipt_id = woh.workorder_id
      and f.company_id = woh.company_id
      and f.profit_ctr_id = woh.profit_ctr_id
      -- and woh.trip_id is not null
  left outer join workorderdetailitem wodi (nolock)
      on f.receipt_id = wodi.workorder_id
      and f.line_sequence_id = wodi.sequence_id
      and f.company_id = wodi.company_id
      and f.profit_ctr_id = wodi.profit_ctr_id
      AND wodi.added_by <> 'sa-extract'
  WHERE 1=1
  and f.added_by = @usr
  and f.date_added = @extract_datetime
  AND f.submitted_flag = 'T'
GROUP BY
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date,
      wodi.month,
      wodi.year,
      f.epa_id,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
	  f.site_type,
	  f.tsdf_approval_id,
	  f.added_by,
      f.date_added,
	  f.submitted_flag
	  , ',' + waste_code_1 + ',' +waste_code_2 + ',' +waste_code_3 + ',' +waste_code_4 + ',' +waste_code_5 + ',' +waste_code_6 + ',' +waste_code_7 + ',' +waste_code_8 + ',' +waste_code_9 + ',' +waste_code_10 + ',' +waste_code_11 + ',' +waste_code_12
HAVING -- 12/17/2010 - per Brie
	 CASE WHEN 
				convert(numeric(6,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) BETWEEN 0.0001 AND 1.0 THEN 
		1.0
	  ELSE
			round(
				convert(numeric(6,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) 	  
			, 1) 
	  END > 0
  -- Above is 3rd party disposal
  UNION
  -- Below is EQ disposal
  SELECT distinct
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date as shipment_date,
      case when rdi.month is null or rdi.year is null then
		convert(datetime, 
			convert(varchar(2), datepart(m, f.service_date)) + '/01/' + convert(varchar(4), datepart(yyyy, f.service_date))
		)
		else
			convert(datetime, convert(varchar(2), rdi.month) + '/01/' + CONVERT(varchar(4), rdi.year)) 
	  end as generation_date,
      f.epa_id,
      CASE WHEN (
		  CASE WHEN 
					convert(numeric(6,1),
						round(sum(
								(
									(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
								) 
								* isnull(rdi.merchandise_quantity,1)
							),1)
					) BETWEEN 0.0001 AND 1.0 THEN 
			1.0
		  ELSE
				round(
					convert(numeric(6,1),
						round(sum(
								(
									(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
								) 
								* isnull(rdi.merchandise_quantity,1.0)
							),1)
					) 	  
				, 1)
		  END ) > 0 
	   THEN
			round(
				convert(numeric(6,1),
					round(sum(
							(
							(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
							) 
							* isnull(rdi.merchandise_quantity,1.0)
						),1)
				) 	  
			, 1)
		ELSE
			(
				select line_weight 
				FROM receipt 
				WHERE receipt_id = f.receipt_id 
				and line_id = f.line_sequence_id 
				AND company_id = f.company_id 
				and profit_ctr_id = f.profit_ctr_id
			)
		END	AS Weight,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
      NULL,
      'F' as calculated_flag,
	  exclude_flag = 
		  CASE WHEN (1=0
		  	-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
		  	OR f.site_type LIKE '%Optical Lab%'
		  	OR f.site_type LIKE '%DC%'
		  	OR f.site_type LIKE '%Return Center%'
		  	OR f.site_type LIKE '%PMDC%'
		  ) THEN 
			  'T'
		  ELSE
		  	/*
		  	exclude any non-hazardous or universal waste approvals: 
				approval numbers WMNHW01-WMNHW16, WMUW01-WMUW03 
				approvals that do not contain a RCRA hazardous waste code (D, F, K, P, U)
			*/
			  CASE WHEN (1=0
			  	OR f.approval_or_resource IN ('WMNHW01','WMNHW02','WMNHW03','WMNHW04','WMNHW05','WMNHW06','WMNHW07','WMNHW08','WMNHW09','WMNHW10','WMNHW11','WMNHW12','WMNHW13','WMNHW14','WMNHW15','WMNHW16')
				OR f.approval_or_resource IN ('WMUW01', 'WMUW02', 'WMUW03')
			  ) THEN
			  	'T'
			  ELSE
			  	CASE WHEN NOT EXISTS (
			  		SELECT wc.waste_code
			  		FROM ProfileWasteCode pwc  (nolock)
			  		INNER JOIN WasteCode wc (nolock) on pwc.waste_code = wc.waste_code
			  		WHERE pwc.profile_id = f.profile_id
			  		AND f.profile_id is not null
			  		AND wc.waste_code_origin = 'F'
			  		AND left(wc.waste_code, 1) in ('D', 'F', 'P', 'K', 'U')
			  		AND wc.haz_flag = 'T'
			  	) THEN
			  		'T'
			  	ELSE
			  		'F'
			  	END
			  END
			END,
	  @usr as added_by,
	  @extract_datetime as date_added
       , CASE WHEN CHARINDEX(',P', f.waste_codes) <= 0 THEN
				''
			ELSE
			'P'
		END AS plisted
  from 
  (
	SELECT DISTINCT 
      site_code, 
      generator_city, 
      generator_state,
      service_date,
	  epa_id,
      approval_or_resource,
      manifest,
      manifest_line,
      company_id,
      profit_ctr_id,
      receipt_id,
      item_type,
      line_sequence_id,
	  site_type,
	  profile_id,
      added_by,
      date_added
     , ',' + waste_code_1 + ',' +waste_code_2 + ',' +waste_code_3 + ',' +waste_code_4 + ',' +waste_code_5 + ',' +waste_code_6 + ',' +waste_code_7 + ',' +waste_code_8 + ',' +waste_code_9 + ',' +waste_code_10 + ',' +waste_code_11 + ',' +waste_code_12 AS waste_codes
	FROM EQ_TEMP.dbo.WalmartDisposalExtract   (nolock)
	  WHERE 1=1
	  and added_by = @usr
	  and date_added = @extract_datetime
	  AND submitted_flag = 'T'
) f
  inner join profilequoteapproval pro 
		on f.profile_id = pro.profile_id 
		and f.company_id = pro.company_id 
		and f.profit_ctr_id = pro.profit_ctr_id
  left outer join ReceiptDetailItem rdi (nolock)
		on f.receipt_id = rdi.receipt_id
		and f.line_sequence_id = rdi.line_id
		and f.company_id = rdi.company_id
		and f.profit_ctr_id = rdi.profit_ctr_id
  WHERE 1=1
  and f.added_by = @usr
  and f.date_added = @extract_datetime
GROUP BY
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date,
      rdi.month,
      rdi.year,
      f.epa_id,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
	  f.site_type,
	  f.profile_id,
      f.added_by,
      f.date_added
    , f.waste_codes
/*      
HAVING -- 12/17/2010 - per Brie
      CASE WHEN 
				convert(numeric(6,1),
					round(sum(
							(
								(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
							) 
							* isnull(rdi.merchandise_quantity,1)
						),1)
				) BETWEEN 0.0001 AND 1.0 THEN 
		1.0
	  ELSE
			round(
				convert(numeric(6,1),
					round(sum(
							(
								(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
							) 
							* isnull(rdi.merchandise_quantity,1.0)
						),1)
				) 	  
			, 1)
	  END > 0  
*/

print 'Populating EQ_Extract..WMDisposalGeneration, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- since calculating 2 versions of every weight was horrid for CPU/performance, we just stored whether each line was plisted or not.
-- Time to go back and take care of the rounding.

UPDATE EQ_Extract..WMDisposalGeneration
SET weight = round(weight,0)
WHERE
	date_added = @extract_datetime
	  AND added_by = @usr
	  and plisted = '' 
	  and weight > 1

print 'Updating EQ_Extract..WMDisposalGeneration weights rounded to whole numbers where > 1 and not plisted, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


UPDATE EQ_Extract..WMDisposalGeneration
SET weight = round(weight,1)
WHERE
	date_added = @extract_datetime
	  AND added_by = @usr
	  and plisted = 'P' 

print 'Updating EQ_Extract..WMDisposalGeneration weights rounded to 1/10th where plisted, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

UPDATE EQ_Extract..WMDisposalGeneration
SET weight = 1
WHERE
	date_added = @extract_datetime
	  AND added_by = @usr
	  and plisted = '' 
	  and weight between 0.0001 AND 1
	  
print 'Updating EQ_Extract..WMDisposalGeneration weights to 1 where between 0 & 1 and not plisted, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

/* *************************************************************

Validate Phase...

    Run the Validation every time, but may not be exported below...

    Look for blank transporter info
    Look for missing waste codes
    Look for 0 weight lines
    Look for blank service_date
    Look for blank Facility Number
    Look for blank Facility Type
    Look for un-submitted records that would've been included if they were submitted
    Look for count of D_ images
    Look for duplicate manifest/line combinations
    Look for missing dot descriptions
    Look for missing waste descriptions

************************************************************** */

-- Create list of missing transporter info
    INSERT EQ_Extract..WMDisposalValidation
    SELECT  DISTINCT
    	'Missing Transporter Info' as Problem,
    	source_table,
    	Company_id,
    	Profit_ctr_id,
    	Receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    WHERE 
    	ISNULL((select transporter_name from transporter (nolock) where transporter_code = EQ_TEMP.dbo.WalmartDisposalExtract.transporter1_code), '') = ''
	    AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
    	
print 'Validation: Missing Transporter Info, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of Missing Waste Code
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract e (nolock) 
    where
	    waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D', 'N')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and source_table = 'Workorder'
	    and coalesce(waste_code_1, waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, waste_code_11, waste_code_12, '') = ''
	    and coalesce(state_waste_code_1, state_waste_code_2, state_waste_code_3, state_waste_code_4, state_waste_code_5, '') = ''
	UNION ALL
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract e (nolock) 
    where
	    waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D', 'N')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and source_table = 'Receipt'
	    and coalesce(waste_code_1, waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, waste_code_11, waste_code_12, '') = ''
	    and coalesce(state_waste_code_1, state_waste_code_2, state_waste_code_3, state_waste_code_4, state_waste_code_5, '') = ''

print 'Validation: Missing Waste Codes, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing Weights
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Missing Weight',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	isnull(pounds,0) = 0
	    AND waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Weights, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing Service Dates
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Missing Service Date',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	isnull(service_date, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    AND approval_or_resource not in (
	    	select approval_code from #ApprovalNoWorkorder
	    )

print 'Validation: Missing Service Dates, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of receipts missing workorders
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Receipt missing Workorder',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    WHERE
		source_table = 'receipt'
    	AND isnull(receipt_workorder_id, '') = ''
    	AND approval_or_resource not in (select approval_code from #ApprovalNoWorkorder)
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Receipts Missing Workorders, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing site codes
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	site_code = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Site Codes, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing site type
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Type',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	isnull(site_type, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Site Types, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of unsubmitted receipts
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Receipt Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table = 'Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'

print 'Validation: Unsubmitted Receipts, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of unsubmitted workorders
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Workorder Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table like 'Workorder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'
	    
print 'Validation: Unsubmitted Workorders, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of records missing scans
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Scan',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'missing ' + isnull(manifest, ''),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table in ('Receipt', 'Workorder')
    	AND approval_or_resource not in (select approval_code from #ApprovalNoWorkorder)
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
		AND manifest not in (
			select document_name 
			from EQ_TEMP..WalmartExtractImages (nolock) 
			WHERE added_by = @usr 
				and date_added = @extract_datetime 
				AND submitted_flag = 'T' 
		)
    	and item_type <> 'N'

print 'Validation: Missing Scans, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create count of receipt-based records in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT
    	' Count of Receipt-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table ='Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Receipt Record Count, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create count of workorder -based records in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT 
    	' Count of Workorder-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Workorder Record Count, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create count of NWP -based records in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT 
    	' Count of No Waste Pickup records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc = 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: No Waste Pickup Record Count, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of unusually high number of manifest names
    INSERT EQ_Extract..WMDisposalValidation
     SELECT
    	'High Number of same manifest-line',
    	null,
    	null,
    	null,
    	null,
    	CONVERT(varchar(20), count(*)) + ' times: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), ''),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	waste_desc <> 'No waste picked up'
    	AND bill_unit_desc not like '%cylinder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	group by manifest, manifest_line
	having count(*) > 2

print 'Validation: Count high # of Manifest-Line combo, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing dot descriptions
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing DOT Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
	    added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
        AND ISNULL(
            CASE WHEN EQ_TEMP.dbo.WalmartDisposalExtract.tsdf_approval_id IS NOT NULL THEN
                dbo.fn_manifest_dot_description('T', EQ_TEMP.dbo.WalmartDisposalExtract.tsdf_approval_id)
            ELSE
                CASE WHEN EQ_TEMP.dbo.WalmartDisposalExtract.profile_id IS NOT NULL THEN
                    dbo.fn_manifest_dot_description('P', EQ_TEMP.dbo.WalmartDisposalExtract.profile_id)
                ELSE
                    ''
                END
            END
        , '') = ''
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'


print 'Validation: Missing DOT Description, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Create list of missing bill units in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT 
    	'Missing Bill Unit',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line ' + convert(varchar(10), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		isnull(bill_unit_desc, '') = ''
		AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Bill Unit Description, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Create list of missing waste descriptions
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Waste Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	waste_desc = ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'

print 'Validation: Missing Waste Description, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of blank waste code 1's
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Blank Waste Code 1',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	ISNULL(waste_code_1, '') = ''
    	AND coalesce(waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, '') <> ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and waste_desc <> 'No waste picked up'

print 'Validation: Blank Waste Code 1, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Catch generators serviced that aren't in the extracts
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Site serviced, NOT in extract',
    	'Workorder',
    	woh.company_id,
    	woh.profit_ctr_id,
    	woh.workorder_id,
    	left(convert(varchar(20), woh.generator_id) + ' (' + isnull(g.site_code, 'Code?') + ' - ' + isnull(g.generator_city, 'city?') + ', ' + isnull(g.generator_state, 'ST?') + ')', 40),
    	@usr,
    	@extract_datetime
	FROM workorderheader woh (nolock)
	INNER join TripHeader th (nolock) ON woh.trip_id = th.trip_id
	INNER JOIN generator g (nolock) on woh.generator_id = g.generator_id
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
		and wos.company_id = woh.company_id
		and wos.profit_ctr_id = woh.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	WHERE th.trip_status IN ('D', 'C', 'A', 'U')
	AND woh.workorder_status <> 'V'
	AND (woh.customer_id IN (select customer_id from #Customer) OR woh.generator_id in (select generator_id from CustomerGenerator (nolock) where customer_id IN (select customer_id from #Customer)))
	AND coalesce(wos.date_act_arrive, woh.start_date) between @start_date and @end_date
	AND g.generator_id not in (
		select generator_id 
		from EQ_TEMP.dbo.WalmartDisposalExtract  (nolock)
		where submitted_flag = 'T'
		AND added_by = @usr
		AND date_added = @extract_datetime
	)

print 'Validation: Generators Serviced, but not in extracts, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of look-alike generators not assigned to WM yet:
    INSERT EQ_TEMP..WalmartMissingGenerators
    SELECT generator_id, epa_id, generator_name, generator_city, generator_state, site_code, site_type, status, @usr, @extract_datetime
    FROM Generator (nolock) 
    WHERE (
        (generator_name LIKE '%wal%' AND generator_name LIKE '%mart%')
        OR
        (generator_name LIKE '%sam%' AND generator_name LIKE '%club%')
        OR
        (generator_name LIKE '%nei%' AND generator_name LIKE '%hood%' AND generator_name LIKE '%wal%')
        )
    AND generator_id NOT IN (SELECT generator_id FROM CustomerGenerator (nolock) WHERE customer_id IN (select customer_id from #Customer))
    ORDER BY generator_state, generator_city, site_code

print 'Validation: Generators that look like WM, but not in WM related set, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

 -- Disposal vs Trip info: Approvals or Weights don't match.
 -- Step 1: Create a temp table that contains totals per line to compare against each other.
		 SELECT
			receipt_weight = (
				SELECT sum(pounds) FROM EQ_TEMP.dbo.WalmartDisposalExtract d2 (nolock)
				WHERE d2.receipt_id = d.receipt_id
				AND d2.company_id = d.company_id
				AND d2.profit_ctr_id = d.profit_ctr_id
				AND d2.line_sequence_id = d.line_sequence_id
				and d2.added_by = d.added_by
				and d2.date_added = d.date_added
				AND d2.submitted_flag = d.submitted_flag
			),
			wodi_weight = (
				CASE WHEN d.source_table = 'Workorder' THEN (
                    SELECT 
                        CASE WHEN convert(numeric(6,1), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  * isnull(wodi.merchandise_quantity,1) ),1) ) BETWEEN 0.0001 AND 1.0 THEN 
                            1.0 
                        ELSE
                            round( convert(numeric(6,1), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  * isnull(wodi.merchandise_quantity,1) ),1) )  , 1)
                        END
                    FROM
                        [dbo].[WorkOrderDetailItem] wodi
                    WHERE [wodi].[workorder_id] = t.workorder_id
                        AND [wodi].[sequence_id] = t.sequence_id
                        AND [wodi].[company_id] = t.company_id
                        AND [wodi].[profit_ctr_id] = t.profit_ctr_id
                    )
				ELSE -- source_table = 'Receipt'...
                    CASE WHEN 
                        (
                            CASE WHEN 
                                (
                                    SELECT 
                                        CONVERT(numeric(6,1), ROUND(SUM( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  * ISNULL(rdi.merchandise_quantity,1) ),1))
                                    FROM
                                        [dbo].[ReceiptDetailItem] rdi
                                    WHERE [rdi].[receipt_id] = d.receipt_id
                                        AND [rdi].[line_id] = d.line_sequence_id
                                        AND [rdi].[company_id] = d.company_id
                                        AND [rdi].[profit_ctr_id] = d.profit_ctr_id
                                ) BETWEEN 0.0001 AND 1.0 
                            THEN 
                                1.0
                            ELSE
                                (
                                    SELECT 
                                        ROUND( CONVERT(numeric(6,1), round(SUM( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  * ISNULL(rdi.merchandise_quantity,1.0) ),1) ), 1)
                                    FROM
                                        [dbo].[ReceiptDetailItem] rdi
                                    WHERE [rdi].[receipt_id] = d.receipt_id
                                        AND [rdi].[line_id] = d.line_sequence_id
                                        AND [rdi].[company_id] = d.company_id
                                        AND [rdi].[profit_ctr_id] = d.profit_ctr_id
                                )
                            END 
                        ) > 0 
                    THEN
                        (
                            SELECT 
                                ROUND( CONVERT(numeric(6,1), round(SUM( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  * ISNULL(rdi.merchandise_quantity,1.0) ),1) ), 1)
                            FROM
                                [dbo].[ReceiptDetailItem] rdi
                            WHERE [rdi].[receipt_id] = d.receipt_id
                                AND [rdi].[line_id] = d.line_sequence_id
                                AND [rdi].[company_id] = d.company_id
                                AND [rdi].[profit_ctr_id] = d.profit_ctr_id
                        )
                    ELSE
                        (
                            select line_weight 
                            FROM receipt 
                            WHERE receipt_id = d.receipt_id 
                            and line_id = d.line_sequence_id 
                            AND company_id = d.company_id 
                            and profit_ctr_id = d.profit_ctr_id
                        )
                    END	
                END
            ),
			d.company_id AS receipt_company_id,
			d.profit_ctr_id AS receipt_profit_ctr_id,
			d.receipt_id,
			d.line_sequence_id as receipt_line_id,
			d.approval_or_resource AS receipt_approval,
			d.manifest,
			d.manifest_line,
			t.company_id as wo_company_id,
			t.profit_ctr_id as wo_profit_ctr_id,
			t.workorder_id as workorder_id,
			t.resource_type AS wo_resource_type,
			t.sequence_id as wo_sequence_id,
			t.tsdf_approval_code as wo_tsdf_approval,
			t.calculated_flag,
			0 as exported_flag,
			d.date_added,
			d.added_by
		INTO #DisposalVsTripValidation	
		FROM EQ_TEMP.dbo.WalmartDisposalExtract d (nolock)
		INNER JOIN EQ_Extract.dbo.WMDisposalGeneration T (nolock)
			on d.manifest = t.manifest
			and d.manifest_line = t.manifest_line
		    and t.added_by = d.added_by
		    and t.date_added = d.date_added
			AND t.weight > 1
		WHERE d.source_table = 'Receipt'
		and d.added_by = @usr
		and d.date_added = @extract_datetime
		AND d.submitted_flag = 'T'
		AND isnull(t.exclude_flag, 'F') = 'F'
		AND EXISTS (
			-- Don't bother comparing records using approvals that are non-haz. They won't be in the trip stuff, intentionally.
			SELECT wc.waste_code
			FROM profilequoteapproval pqa (nolock)
			inner join profilewastecode pwc (nolock) ON pqa.profile_id = pwc.profile_id
			inner join wastecode wc (nolock) on pwc.waste_code = wc.waste_code
			WHERE 
			pqa.approval_code = d.approval_or_resource
			AND wc.haz_flag = 'T' 
			AND wc.waste_code_origin = 'F'
		)

print 'Validation: Disposal vs Trip info, #tmp table, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

	-- Step 2: Export lines where both approval and weight don't match.
	UPDATE #DisposalVsTripValidation SET
		exported_flag = 2 
	WHERE 1=1
	AND abs(round(isnull(receipt_weight, -1111),1) - round(isnull(wodi_weight, -2222),1)) > 1
	AND isnull(receipt_approval, '-1111') <> isnull(wo_tsdf_approval, '-2222')
	AND isnull(wodi_weight, -2222) <> -2222
	AND exported_flag = 0
	
print 'Validation: Disposal vs Trip info - Approval and Weight do not match, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
		
	-- Step 3: Export lines where approval matches, but weight does not.
	UPDATE #DisposalVsTripValidation SET
		exported_flag = 4 
	WHERE 1=1
	AND abs(round(isnull(receipt_weight, -1111),1) - round(isnull(wodi_weight, -2222),1)) > 1
	AND isnull(receipt_approval, '-1111') = isnull(wo_tsdf_approval, '-2222')
	AND isnull(wodi_weight, -2222) <> -2222
	AND exported_flag = 0

print 'Validation: Disposal vs Trip info, Approval Matches, Weight not so much, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

	-- Step 4: Export lines Generation record was created from Disposal info.
	UPDATE #DisposalVsTripValidation SET
		exported_flag = 5
	WHERE 1=1
	AND calculated_flag = 'T'
	AND isnull(wodi_weight, -2222) <> -2222
	AND exported_flag = 0

print 'Validation: Disposal vs Trip info - Generation record was created from Disposal info only, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


	-- Step Last: Export to WMDisposalGenerationValidation
	INSERT EQ_Extract.dbo.WMDisposalGenerationValidation
	SELECT DISTINCT
		CASE dvtv.exported_flag 
			WHEN 2 THEN 'Appovals and Weights do not match'
			WHEN 3 THEN 'Approvals do not match. Weights do'
			WHEN 4 THEN 'Approvals match. Weights do not'
			WHEN 5 THEN 'Calculated Generation record, no WO found'
			ELSE 'No problem'
		END AS problem,
		dvtv.receipt_company_id,
		dvtv.receipt_profit_ctr_id,
		dvtv.receipt_id,
		dvtv.receipt_line_id,
		dvtv.manifest,
		dvtv.manifest_line,
		dvtv.wo_company_id,
		dvtv.wo_profit_ctr_id,
		dvtv.workorder_id,
		dvtv.wo_resource_type,
		dvtv.wo_sequence_id,
		NULL , --t.sub_sequence_id AS wodi_sub_sequence_id,
		NULL, -- datepart(m, t.generation_date) as wodi_month,
		NULL, -- datepart(yyyy, t.generation_date) as wodi_year,
		dvtv.wo_tsdf_approval,
		dvtv.wodi_weight,
		dvtv.receipt_approval,
		dvtv.receipt_weight,
		null as corrected_wodi_weight,
		@usr as added_by,
		@extract_datetime as date_added
	FROM #DisposalVsTripValidation dvtv
	INNER JOIN EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		on dvtv.workorder_id = t.workorder_id
		AND dvtv.wo_sequence_id = t.sequence_id
		AND dvtv.wo_company_id = t.company_id
	    AND dvtv.wo_resource_type = t.resource_type
		AND dvtv.wo_profit_ctr_id = t.profit_ctr_id
		AND dvtv.manifest = t.manifest
		and dvtv.manifest_line = t.manifest_line
	    and dvtv.added_by = t.added_by
	    and dvtv.date_added = t.date_added
	WHERE dvtv.exported_flag > 0
/*
	SELECT
		CASE dvtv.exported_flag 
			WHEN 2 THEN 'Appovals and Weights do not match'
			WHEN 3 THEN 'Approvals do not match. Weights do'
			WHEN 4 THEN 'Approvals match. Weights do not'
			WHEN 5 THEN 'Calculated Generation record, no WO found'
			ELSE 'No problem'
		END AS problem,
		d.company_id AS receipt_company_id,
		d.profit_ctr_id AS receipt_profit_ctr_id,
		d.receipt_id,
		d.line_sequence_id as receipt_line_id,
		d.manifest,
		d.manifest_line,
		t.company_id as wo_company_id,
		t.profit_ctr_id as wo_profit_ctr_id,
		t.workorder_id as workorder_id,
		t.resource_type AS wo_resource_type,
		t.sequence_id as wo_sequence_id,
		NULL , --t.sub_sequence_id AS wodi_sub_sequence_id,
		datepart(m, t.generation_date) as wodi_month,
		datepart(yyyy, t.generation_date) as wodi_year,
		t.tsdf_approval_code as wo_tsdf_approval,
		sum(t.weight) as wodi_weight,
		d.approval_or_resource AS receipt_approval,
		d.pounds AS receipt_weight,
		null as corrected_wodi_weight,
		@usr as added_by,
		@extract_datetime as date_added
	FROM #DisposalVsTripValidation dvtv
	INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract d
		ON dvtv.receipt_company_id = d.company_id
		AND dvtv.receipt_profit_ctr_id = d.profit_ctr_id
		AND dvtv.receipt_id = d.receipt_id
		AND dvtv.receipt_line_id = d.line_sequence_id
	LEFT OUTER JOIN EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		on d.manifest = t.manifest
		and d.manifest_line = t.manifest_line
	    and t.added_by = d.added_by
	    and t.date_added = d.date_added
	    and t.company_id = dvtv.wo_company_id
	    AND t.profit_ctr_id = dvtv.wo_profit_ctr_id
	    AND t.workorder_id = dvtv.workorder_id
	    AND t.resource_type = dvtv.wo_resource_type
	    AND t.sequence_id = dvtv.wo_sequence_id
	WHERE d.source_table = 'Receipt'
	and d.added_by = @usr
	and d.date_added = @extract_datetime
	AND d.submitted_flag = 'T'
	AND isnull(t.exclude_flag, 'F') = 'F'
	AND dvtv.exported_flag > 0
	GROUP by
		dvtv.exported_flag,
		d.company_id,
		d.profit_ctr_id,
		d.receipt_id,
		d.line_sequence_id,
		d.manifest,
		d.manifest_line,
		t.company_id,
		t.profit_ctr_id,
		t.workorder_id,
		t.resource_type,
		t.sequence_id,
		datepart(m, t.generation_date),
		datepart(yyyy, t.generation_date),
		t.tsdf_approval_code,
		d.approval_or_resource,
		d.pounds
*/

print 'Validation: Disposal vs Trip info - Results to WMDisposalGenerationValidation, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Find Generation records with 0 weight that we did not export before, but do now
-- because we fall back to Receipt.Line_Weight when rdi weights = 0... users need to know.
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Generation Log Weight = 0 (should not be 0)',
    	NULL,
    	t.company_id,
    	t.profit_ctr_id,
    	t.workorder_id,
    	'line/seq: ' + convert(varchar(20), t.sequence_id),
    	@usr,
    	@extract_datetime
   from EQ_Extract.dbo.WMDisposalGeneration T (nolock)
	where t.weight = 0
	AND date_added = @extract_datetime
	AND added_by = @usr


-- Find disposal approvals not in Generation
	INSERT EQ_Extract..WMDisposalValidation
	SELECT DISTINCT
		'Disposal Approval not in Gen. Log: site:' + isnull(d.site_code,'?') + ', approval:' + isnull(d.approval_or_resource,'?'),
		d.source_table,
		d.company_id,
		d.profit_ctr_id,
		d.receipt_id,
		'line/seq: ' + convert(varchar(20), d.line_sequence_id),
		@usr,
		@extract_datetime
	from EQ_TEMP.dbo.WalmartDisposalExtract d (nolock)
	WHERE d.added_by = @usr
	and d.date_added = @extract_datetime
	AND d.submitted_flag = 'T'
	AND d.waste_desc <> 'No waste picked up'
	AND EXISTS (
		SELECT t.tsdf_approval_code
		FROM EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		WHERE t.site_code = d.site_code
		and t.added_by = d.added_by
		and t.date_added = d.date_added
	)
	AND NOT EXISTS (
		SELECT t.tsdf_approval_code
		FROM EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		WHERE t.site_code = d.site_code
		and t.added_by = d.added_by
		and t.date_added = d.date_added
		and t.tsdf_approval_code = d.approval_or_resource
	)
	AND NOT EXISTS (
		SELECT 1 FROM EQ_Extract.dbo.WMDisposalGeneration e (nolock)
		WHERE date_added = d.date_added
		and added_by = d.added_by
		and site_code = d.site_code
		and tsdf_approval_code = d.approval_or_resource
		AND isnull(exclude_flag, 'F') = 'T'
	)
	AND NOT (
		1=0
	  	-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
	  	OR d.site_type LIKE '%Optical Lab%'
	  	OR d.site_type LIKE '%DC%'
	  	OR d.site_type LIKE '%Return Center%'
	  	OR d.site_type LIKE '%PMDC%'
	)

	
-- Find disposal facilities not in Generation
	INSERT EQ_Extract..WMDisposalValidation
	SELECT DISTINCT
		'Disposal Site not in Gen. Log: site:' + isnull(d.site_code,'?'),
		d.source_table,
		d.company_id,
		d.profit_ctr_id,
		d.receipt_id,
		NULL,
		@usr,
		@extract_datetime
	from EQ_TEMP.dbo.WalmartDisposalExtract d (nolock)
	WHERE d.added_by = @usr
	and d.date_added = @extract_datetime
	AND d.submitted_flag = 'T'
	AND d.waste_desc <> 'No waste picked up'
	AND NOT EXISTS (
		SELECT t.site_code
		FROM EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		WHERE t.site_code = d.site_code
		and t.added_by = d.added_by
		and t.date_added = d.date_added
	)
	AND NOT EXISTS (
		SELECT 1 FROM EQ_Extract.dbo.WMDisposalGeneration e (nolock)
		WHERE date_added = d.date_added
		and added_by = d.added_by
		and site_code = d.site_code
		and tsdf_approval_code = d.approval_or_resource
		AND isnull(exclude_flag, 'F') = 'T'
	)
	AND NOT (
		1=0
	  	-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
	  	OR d.site_type LIKE '%Optical Lab%'
	  	OR d.site_type LIKE '%DC%'
	  	OR d.site_type LIKE '%Return Center%'
	  	OR d.site_type LIKE '%PMDC%'
	)


-- Find shipment dates approvals not in Generation
	INSERT EQ_Extract..WMDisposalValidation
	SELECT DISTINCT
		'Disposal ShipmentDate not in Gen. Log: site:' + isnull(d.site_code,'?') + ', date:' + isnull(convert(varchar(20), d.service_date, 120),'?'),
		d.source_table,
		d.company_id,
		d.profit_ctr_id,
		d.receipt_id,
		NULL,
		@usr,
		@extract_datetime
	from EQ_TEMP.dbo.WalmartDisposalExtract d (nolock)
	WHERE d.added_by = @usr
	and d.date_added = @extract_datetime
	AND d.submitted_flag = 'T'
	AND d.waste_desc <> 'No waste picked up'
	AND EXISTS (
		SELECT t.tsdf_approval_code
		FROM EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		WHERE t.site_code = d.site_code
		and t.added_by = d.added_by
		and t.date_added = d.date_added
	)
	AND NOT EXISTS (
		SELECT t.shipment_date
		FROM EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		WHERE t.site_code = d.site_code
		and t.added_by = d.added_by
		and t.date_added = d.date_added
		and t.shipment_date = d.service_date
	)
	AND NOT EXISTS (
		SELECT 1 FROM EQ_Extract.dbo.WMDisposalGeneration e (nolock)
		WHERE date_added = d.date_added
		and added_by = d.added_by
		and site_code = d.site_code
		and tsdf_approval_code = d.approval_or_resource
		AND isnull(exclude_flag, 'F') = 'T'
	)
	AND NOT (
		1=0
	  	-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
	  	OR d.site_type LIKE '%Optical Lab%'
	  	OR d.site_type LIKE '%DC%'
	  	OR d.site_type LIKE '%Return Center%'
	  	OR d.site_type LIKE '%PMDC%'
	)


/* *************************************************************
Populate Output tables from this run.
************************************************************* */

-- Validation Information
-- EQ_TEMP..WalmartDisposalValidation isn't used anymore.


-- Generators Information
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


        INSERT EQ_Extract.dbo.WalmartMissingGenerators
        SELECT
            generator_id,
            epa_id,
            generator_name,
            generator_city,
            generator_state,
            site_code,
            site_type,
            status,
            @usr,
            @extract_datetime
        FROM EQ_TEMP..WalmartMissingGenerators (nolock)
        WHERE added_by = @usr and date_added = @extract_datetime

        
print 'Output: Generators, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Disposal Information
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

        INSERT EQ_Extract.dbo.WalmartDisposalExtract (
            site_code,
            site_type_abbr,
            generator_city,
            generator_state,
            service_date,
            epa_id,
            manifest,
            manifest_line,
            pounds,
            bill_unit_desc,
            quantity,
            waste_desc,
            approval_or_resource,
            dot_description,
            waste_code_1,
            waste_code_2,
            waste_code_3,
            waste_code_4,
            waste_code_5,
            waste_code_6,
            waste_code_7,
            waste_code_8,
            waste_code_9,
            waste_code_10,
            waste_code_11,
            waste_code_12,
            state_waste_code_1,
            state_waste_code_2,
            state_waste_code_3,
            state_waste_code_4,
            state_waste_code_5,
            management_code,
            EPA_source_code,
            EPA_form_code,
            transporter1_name,
            transporter1_epa_id,
            transporter2_name,
            transporter2_epa_id,
            receiving_facility,
            receiving_facility_epa_id,
            receipt_id,
            disposal_service_desc,
            company_id,
            profit_ctr_id,
            line_sequence_id,
            generator_id,
            generator_name,
            site_type,
            manifest_page,
            item_type,
            tsdf_approval_id,
            profile_id,
            container_count,
            waste_codes,
            state_waste_codes,
            transporter1_code,
            transporter2_code,
            date_delivered,
            source_table,
            receipt_date,
            receipt_workorder_id,
            workorder_start_date,
            workorder_company_id,
            workorder_profit_ctr_id,
            customer_id,
            haz_flag,
            added_by,
            date_added      
        )
        SELECT
            -- Walmart Fields:
            site_code,
            site_type_abbr,
            generator_city,
            generator_state,
            service_date,
            epa_id,
            manifest,
            manifest_line,
            pounds,
            bill_unit_desc,
            quantity,
            waste_desc,
            approval_or_resource,
            dot_description,
            waste_code_1,
            waste_code_2,
            waste_code_3,
            waste_code_4,
            waste_code_5,
            waste_code_6,
            waste_code_7,
            waste_code_8,
            waste_code_9,
            waste_code_10,
            waste_code_11,
            waste_code_12,
            state_waste_code_1,
            state_waste_code_2,
            state_waste_code_3,
            state_waste_code_4,
            state_waste_code_5,
            management_code,
            EPA_source_code,
            EPA_form_code,
            transporter1_name,
            transporter1_epa_id,
            transporter2_name,
            transporter2_epa_id,
            receiving_facility,
            receiving_facility_epa_id,
            receipt_id,
            disposal_service_desc,

            -- EQ Fields:
            company_id,
            profit_ctr_id,
            line_sequence_id,
            generator_id,
            generator_name,
            site_type,
            manifest_page,
            item_type,
            tsdf_approval_id,
            profile_id,
            container_count,
            waste_codes,
            state_waste_codes,
            transporter1_code,
            transporter2_code,
            date_delivered,
            source_table,
            receipt_date,
            receipt_workorder_id,
            workorder_start_date,
            workorder_company_id,
            workorder_profit_ctr_id,
            customer_id,
            haz_flag,
            @usr,
            @extract_datetime
        FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
        WHERE added_by = @usr and date_added = @extract_datetime
        AND submitted_flag = 'T'

print 'Output: Disposal, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Manifest Information

PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
        
        INSERT EQ_Extract.dbo.WalmartDisposalImages
        SELECT
            row_id,
            site_code,
            generator_id,
            service_date,
            image_id,
            document_name,
            page_number,
            file_type,
            filename,
            process_flag,
            newname,
            @usr,
            @extract_datetime
        FROM EQ_TEMP..WalmartExtractImages (nolock) WHERE added_by = @usr and date_added = @extract_datetime

print 'Output: Images, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Return Run information
    SELECT extract_id 
    FROM EQ_Extract..ExtractLog (nolock)
    WHERE date_added = @extract_datetime
    AND added_by = @usr

print 'Return Run Information, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_walmart_disposal_dc] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_walmart_disposal_dc] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_walmart_disposal_dc] TO [EQAI]
    AS [dbo];

