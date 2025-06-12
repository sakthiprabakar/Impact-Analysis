CREATE PROCEDURE [dbo].[sp_COR_dashboard_invoices_manifest]
	@web_userid		varchar(100) = ''
	, @start_date	datetime
	, @end_date		datetime
	, @search		varchar(max) = ''
	, @invoice_code		varchar(max)= ''	-- Invoice ID
	, @purchase_order	varchar(max) = ''
	, @adv_search	varchar(max) = ''
	, @manifest		varchar(max) = ''	-- Manifest list
	, @generator	varchar(max) = '' -- Generator Name/Store Number Search
	, @generator_site_code	varchar(max) = '' -- Generator Site Code / Store Number
	, @searchCriteria varchar(max) = ''	-- Criteria
	, @documentType varchar(max) = ''	-- DocumentType
	, @sort			varchar(20) = ''
	, @page			bigint = 1
	, @perpage		bigint = 20
	, @excel_output	int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
AS
/* ***************************************************************************************************
[sp_COR_dashboard_invoices_manifest]:

Returns the data for Invoices.

LOAD TO PLT_AI* on NTSQL1

12/17/2018	JPB	Copy of sp_reports_invoices, modified for COR
07/31/2019	JPB	Added @generator input for searching by generator name/store number, also returning generator name/store num or "multiple" if more than 1 on a record.

exec [sp_COR_dashboard_invoices_manifest]
	@web_userid		= 'amoser@capitolenv.com'
	, @start_date	= '1/1/2000'
	, @end_date		= '12/31/2018'
	, @search		= ''
	, @purchase_order = ''
	, @invoice_code = '398878'
	, @adv_search	= ''
	, @sort			= ''
	, @page			= 1
	, @perpage		= 2000
	

select * from invoiceheader where customer_id in (select customer_id from contactxref where contact_id =3682)

select * from invoicedetail where invoice_id = 464987

sp_help invoicedetail
SELECT  *  FROM    invoicedetail where manifest = 'MI8282919'


*************************************************************************************************** */

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	  
	exec [sp_COR_reports_invoices_list]
		@web_userid		= @web_userid
		, @start_date	= @start_date
		, @end_date		= @end_date
		, @search		= @search
		, @purchase_order = @purchase_order
		, @invoice_code = @invoice_code
		, @adv_search	= @adv_search
		, @manifest = @manifest
		, @generator  = @generator -- Generator Name/Store Number Search
		, @generator_site_code	= @generator_site_code -- Generator Site Code / Store Number
		, @sort			=@sort
		, @page			= @page
		, @perpage		= @perpage
		, @excel_output=@excel_output
		, @customer_id_list=@customer_id_list
		, @generator_id_list=@generator_id_list
END

