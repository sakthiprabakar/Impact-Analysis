CREATE PROCEDURE sp_populate_form_CC
	@form_id		int,
	@profile_id		int,
	@added_by		varchar(60),
	@contact_id		int
AS
/***************************************************************************************
Populates FormCC tables with data from Profile
Filename:		L:\Apps\SQL\EQAI\sp_populate_form_CC.sql
Loads to:		Plt_AI

06/28/2005 JDB	Created
03/15/2006 RG	Removed join to WasteCode on profit_ctr_id
06/26/2006 MK	Modified to use Profile tables
07/18/2006 JDB	Modified to pull Orig Customer and Pricing when
		customer is InterCompany
08/01/2006 MK	Modified LDR for Workorders
09/22/2006 RG   added logic to string the detaildescriptions together from profile
09/27/2006 RG	Added temp table for comment field so that NTSQL3 won't complain
                about text pointer on the insert to the forms table on ntsql1.
                this is only a problem going from ntsql3 to ntsql1 and vice versa.
10/02/2007 WAC	Removed references to a database server.
09/18/2008 JDB	Added Energy Surcharge fields
10/21/2008 JDB	Fixed bug where NULL value of pqa.ensr_exempt was not being handled properly.
01/15/2009 JDB	Modified to only select Disposal, Service or Transportation records
				from ProfileQuoteDetail.
10/13/2011 SK	Moved to PLT_AI		
04/05/2012 SK	Forms changed to show multiple approvals , so autoselect all aprovals in Profilequoteapproval and 
				put them in FormXApproval
				Also the logic to determine insurance surcharge & energy surcharge changes to be per approval
04/05/2012 SK	Comments will also be Approval specific & not one per Form		
08/08/2012 SK	Changed insert into FormXApproval for insurance_surcharge_percent & ensr_exempt	
08/15/2012 SK	Added the logic to exclude bundled disposal price line
08/28/2012 SK	The query for Comments was missing Where profile_id = @profile_id....oooops!!
11/6/2012 SK	fixed bug - wrong interpretation of customerbilling.ensr_flag !! correct is when =T means energy surcharge applies
				its reverse on profilequoteapproval when ensr_exempt = 'T' means does not apply
11/9/2012 SK	For type "Disposal" don't insert bundled charges			
11/21/2012 SK  Populate waste codes into FormXwastecode	
11/23/2012 SK Fixed the comments, should not use sequenceID, should be comments for the quote-id
04/17/2013 SK Added waste_code_UID to FormXWasteCode
08/22/2013 SK The Join to WasteCode.waste_code should be wasteCode.waste_code_uid
10/02/2013 SK	Changed to copy only active waste codes to the form from profile
12/11/2013 SK	Added show_cust_flag to where criteria for bundled records
01/03/2014 SK Added ref_seq_id to FormCCdetail

Select * from FormXApproval where form_id = 0
sp_populate_form_CC 0, 411182, 'SMITA_K', 301
****************************************************************************************/
SET NOCOUNT ON

CREATE TABLE #comments (
	profile_id		INT		NULL
,	company_id		INT		NULL
,	profit_ctr_id	INT		NULL
,	comment			VARCHAR(8000)	NULL
)

DECLARE
    @revision_id INT
,   @status CHAR(1)
,   @locked CHAR(1)
,   @source CHAR(1)
,   @contact_name VARCHAR(40)
,   @current_form_version_id INT
,   @customer_id INT
,   @customer_id_insert INT
,   @cust_name VARCHAR(40)
,   @cust_addr1 VARCHAR(40)
,   @cust_addr2 VARCHAR(40)
,   @cust_addr3 VARCHAR(40)
,   @cust_addr4 VARCHAR(40)
,   @cust_addr5 VARCHAR(40)
,   @cust_city VARCHAR(40)
,   @cust_state VARCHAR(2)
,   @cust_zip_code VARCHAR(15)
,   @cust_fax VARCHAR(10)
,   @orig_customer_id INT
,   @customer_eq_flag CHAR(1)
,   @broker_flag CHAR(1)
,	@CARRIAGE_RETURN CHAR(2)
--,	@disposal_comment	varchar(2000)
--,	@transport_comment	varchar(2000)
--,	@service_comment	varchar(2000)
--,	@quote_comment		varchar(6000)

SET NOCOUNT ON

SELECT @CARRIAGE_RETURN = CHAR(13) + CHAR(10)

SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'

-- get form version
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'CC'
-- get contact info
SELECT @contact_name = name FROM Contact WHERE contact_ID = @contact_id AND contact_status = 'A'

SELECT
    @customer_id = Profile.customer_id
,   @orig_customer_id = Profile.orig_customer_id
,   @broker_flag = Profile.broker_flag
FROM Profile
WHERE Profile.profile_id = @profile_id

SELECT @customer_eq_flag = Customer.eq_flag FROM Customer WHERE Customer.customer_id = @customer_id
IF @customer_eq_flag = 'T' AND @orig_customer_id > 0 AND @broker_flag = 'B'
BEGIN
    SELECT
        @customer_id_insert = Customer.customer_id
    ,	@cust_name = Customer.cust_name
    ,   @cust_addr1 = Customer.cust_addr1
    ,   @cust_addr2 = Customer.cust_addr2
    ,   @cust_addr3 = Customer.cust_addr3
    ,   @cust_addr4 = Customer.cust_addr4
    ,   @cust_addr5 = Customer.cust_addr5
    ,   @cust_city = Customer.cust_city
    ,   @cust_state = Customer.cust_state
    ,   @cust_zip_code = Customer.cust_zip_code
    ,	@cust_fax = Customer.cust_fax
	FROM Customer WHERE customer_ID = @orig_customer_id -- use orig customerid here
END 
ELSE
BEGIN
     SELECT
        @customer_id_insert = Customer.customer_id
     ,  @cust_name = Customer.cust_name
     ,  @cust_addr1 = Customer.cust_addr1
     ,  @cust_addr2 = Customer.cust_addr2
     ,  @cust_addr3 = Customer.cust_addr3
     ,  @cust_addr4 = Customer.cust_addr4
     ,  @cust_addr5 = Customer.cust_addr5
     ,  @cust_city = Customer.cust_city
     ,  @cust_state = Customer.cust_state
     ,  @cust_zip_code = Customer.cust_zip_code
     ,  @cust_fax = Customer.cust_fax
     FROM Customer
     WHERE customer_ID = @customer_id
END

-- get comments
INSERT  INTO #comments
SELECT DISTINCT
    PQD.profile_id
,   PQD.company_id
,   PQD.profit_ctr_id
,   comment = (ISNULL(d.description, '') + CASE d.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END +
			   ISNULL(t.description, '') + CASE t.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END + ISNULL(s.description, '')
			   )
FROM ProfileQuoteApproval PQA
JOIN ProfileQuoteDetail PQD
	ON PQA.profile_id = PQD.profile_id
	AND PQA.quote_id = PQD.quote_id
	AND PQD.status = 'A'
LEFT OUTER JOIN ProfileQuoteDetailDesc d
    ON d.profile_id = PQD.profile_id
       AND d.company_id = PQD.company_id
       AND d.profit_ctr_id = PQD.profit_ctr_id
	   AND d.quote_id = PQD.quote_id
       AND d.record_type = 'D'
LEFT OUTER JOIN ProfileQuoteDetailDesc t
    ON t.profile_id = PQD.profile_id
       AND t.company_id = PQD.company_id
       AND t.profit_ctr_id = PQD.profit_ctr_id
        AND t.quote_id = PQD.quote_id
       AND t.record_type = 'T'
LEFT OUTER JOIN ProfileQuoteDetailDesc s
    ON s.profile_id = PQD.profile_id
       AND s.company_id = PQD.company_id
       AND s.profit_ctr_id = PQD.profit_ctr_id
       AND s.quote_id = PQD.quote_id
       AND s.record_type = 'S'
WHERE PQA.status = 'A'
 AND PQA.profile_id = @profile_ID
	
-- Insert FormCC records
INSERT  INTO FormCC
SELECT
    @form_id
,   @revision_id
,   @current_form_version_id
,   @customer_id_insert
,   @status
,   @locked
,   @source
,   NULL
,   NULL AS approval_key
,   NULL
,   NULL
,   NULL AS signing_name
,   NULL AS signing_company
,   NULL AS signing_title
,   NULL AS signing_date
,   GETDATE() AS date_created
,   GETDATE() AS date_modified
,   @added_by
,   @added_by
,   @cust_name
,   @cust_addr1
,   @cust_addr2
,   @cust_addr3
,   @cust_addr4
,   @cust_addr5
,   @cust_city
,   @cust_state
,   @cust_zip_code
,   @cust_fax
,   @contact_id AS contact_id
,   Contact_name = @contact_name
,   NULL
,   NULL
,   NULL
,   NULL
,   NULL
,   NULL
,   NULL
,   NULL
,   NULL
,   NULL
,   P.ap_expiration_date
,   Generator.generator_name
,   P.approval_desc
,   WasteCode.waste_code_desc
,	NULL, NULL
--,   WasteCode.waste_code moved to FormXwastecode
--,   secondary_waste_code_list = dbo.fn_sec_waste_code_list(@profile_id)
,   P.OTS_flag
,   Generator.EPA_ID
,   Generator.generator_id
,   NULL
,   NULL AS purchase_order
,   NULL AS release
,   NEWID()
,   @profile_id
,   NULL
FROM
    Profile P
,   WasteCode
,   Generator
WHERE
    P.profile_id = @profile_id
    AND P.curr_status_code IN ('A', 'H', 'P')
    AND P.generator_id = generator.generator_id
    AND P.waste_code_uid = WasteCode.waste_code_uid
    
-- Insert FormCCDetail records
INSERT  INTO FormCCDetail
SELECT DISTINCT
    @form_id
,   @revision_id
,   @current_form_version_id
,   P.profile_id AS approval_key
,   QuoteDetail.sequence_id
,   QuoteDetail.record_type
,   QuoteDetail.service_desc
,   QuoteApproval.sr_type_code
,   ProfitCenter.surcharge_flag
,   QuoteDetail.surcharge_price
,   QuoteDetail.hours_free_unloading
,   QuoteDetail.hours_free_loading
,   QuoteDetail.demurrage_price
,   QuoteDetail.unused_truck_price
,   QuoteDetail.lay_over_charge
,   QuoteDetail.bill_method
,   CASE @customer_id_insert
      WHEN @orig_customer_id THEN QuoteDetail.orig_customer_price
      WHEN @customer_id THEN QuoteDetail.price
    END
,   QuoteDetail.bill_unit_code
,   QuoteDetail.min_quantity
,   GETDATE()
,   GETDATE()
,   @added_by
,   @added_by
,   NEWID()
,	QuoteApproval.company_id
,	QuoteApproval.profit_ctr_id
,	QuoteDetail.ref_sequence_id
FROM Profile P
INNER JOIN ProfileQuoteDetail QuoteDetail
    ON P.profile_id = QuoteDetail.profile_id
    AND QuoteDetail.status = 'A'
    AND QuoteDetail.record_type IN ('S', 'T')
    AND ISNULL(QuoteDetail.fee_exempt_flag, 'F') = 'F'
    AND (IsNull(QuoteDetail.bill_method, '') <> 'B' OR (IsNull(QuoteDetail.bill_method, '') = 'B' AND QuoteDetail.show_cust_flag = 'T'))
INNER JOIN ProfileQuoteApproval QuoteApproval
    ON QuoteDetail.profile_id = QuoteApproval.profile_id
       AND QuoteDetail.company_id = QuoteApproval.company_id
       AND QuoteDetail.profit_ctr_id = QuoteApproval.profit_ctr_id
INNER JOIN ProfitCenter
    ON QuoteDetail.profit_ctr_id = ProfitCenter.profit_ctr_id
       AND QuoteDetail.company_id = ProfitCenter.company_ID
WHERE P.profile_id = @profile_id
UNION
SELECT DISTINCT
    @form_id
,   @revision_id
,   @current_form_version_id
,   P.profile_id AS approval_key
,   QuoteDetail.sequence_id
,   QuoteDetail.record_type
,   QuoteDetail.service_desc
,   QuoteApproval.sr_type_code
,   ProfitCenter.surcharge_flag
,   QuoteDetail.surcharge_price
,   QuoteDetail.hours_free_unloading
,   QuoteDetail.hours_free_loading
,   QuoteDetail.demurrage_price
,   QuoteDetail.unused_truck_price
,   QuoteDetail.lay_over_charge
,   QuoteDetail.bill_method
,   CASE @customer_id_insert
      WHEN @orig_customer_id THEN QuoteDetail.orig_customer_price
      WHEN @customer_id THEN QuoteDetail.price
    END
,   QuoteDetail.bill_unit_code
,   QuoteDetail.min_quantity
,   GETDATE()
,   GETDATE()
,   @added_by
,   @added_by
,   NEWID()
,	QuoteApproval.company_id
,	QuoteApproval.profit_ctr_id
,	QuoteDetail.ref_sequence_id
FROM Profile P
INNER JOIN ProfileQuoteDetail QuoteDetail
    ON P.profile_id = QuoteDetail.profile_id
    AND QuoteDetail.status = 'A'
    AND QuoteDetail.record_type = 'D'
    AND ISNULL(QuoteDetail.fee_exempt_flag, 'F') = 'F'
	AND IsNull(QuoteDetail.bill_method, '') <> 'B'
INNER JOIN ProfileQuoteApproval QuoteApproval
    ON QuoteDetail.profile_id = QuoteApproval.profile_id
       AND QuoteDetail.company_id = QuoteApproval.company_id
       AND QuoteDetail.profit_ctr_id = QuoteApproval.profit_ctr_id
INNER JOIN ProfitCenter
    ON QuoteDetail.profit_ctr_id = ProfitCenter.profit_ctr_id
       AND QuoteDetail.company_id = ProfitCenter.company_ID
WHERE P.profile_id = @profile_id   

-- Insert FormXApproval records
INSERT  INTO FormXApproval
SELECT DISTINCT
	'CC'
,	@form_id
,	@revision_id
,	PQA.company_id
,	PQA.profit_ctr_id
,	PQA.profile_id
,	PQA.approval_code
,	PC.profit_ctr_name
,	PC.EPA_ID
,	CASE CB.insurance_surcharge_flag 
		WHEN 'T' THEN IsNull(Company.insurance_surcharge_percent, 0.00)
		WHEN 'F' THEN 0.00
		ELSE (CASE PQA.insurance_exempt WHEN 'T' THEN 0.00 ELSE IsNull(Company.insurance_surcharge_percent, 0.00) END)
	END AS insurance_surcharge_percent
,	CASE CB.ensr_flag 
		WHEN 'T' THEN 'F' 
		WHEN 'F' THEN 'T' 
		ELSE (CASE PQA.ensr_exempt WHEN 'T' THEN 'T' ELSE 'F' END)
	END AS ensr_exempt
,	X.comment
FROM PRofile P
INNER JOIN ProfileQuoteApproval PQA
	ON PQA.profile_id = P.profile_id
	AND PQA.status = 'A'
INNER JOIN CustomerBilling CB
	ON CB.customer_id = P.customer_id
	AND CB.billing_project_id = ISNULL(PQA.billing_project_id, 0)
INNER JOIN ProfitCenter PC
	ON PC.company_ID = PQA.company_id
	AND PC.profit_ctr_ID = PQA.profit_ctr_id
INNER JOIN Company
	ON Company.company_id = PQA.company_id
LEFT OUTER JOIN #comments X
	ON X.profile_id = PQA.profile_id
	AND X.company_id = PQA.company_id
	AND X.profit_ctr_id = PQA.profit_ctr_id
WHERE P.profile_id = @profile_id

-- Populate FormXWasteCode
INSERT INTO FormXWasteCode
SELECT	@form_id AS form_id,
	@revision_id AS revision_id,
	NULL AS page_number,
	NULL AS line_item,
	PW.waste_code_uid,
	PW.waste_code AS waste_code,
	specifier = CASE PW.primary_flag WHEN 'T' THEN 'primary' ELSE 'secondary' END,
        'F' AS lock_flag 
FROM ProfileWasteCode PW
JOIN WasteCode W ON W.waste_code_uid = PW.waste_code_uid AND W.status = 'A'
WHERE PW.profile_id = @profile_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_CC] TO [EQAI]
