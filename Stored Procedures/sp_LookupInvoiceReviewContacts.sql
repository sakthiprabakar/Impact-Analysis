CREATE PROCEDURE sp_LookupInvoiceReviewContacts 
AS
/***************************************************************************************
Returns Review contact emails for a customer and billing project
Requires: none
Loads on PLT_AI

12/20/2014	SM Created
01/20/2015  SK Corrected to account for multiple billing projects on the same invoice
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
01/11/2022  DevOps:20699 -  AM  Modified resultset order from customer_id to customer_name

-- Select * from #invoicereviewcontactdetails
select * from customer where cust_name like "American%"

Testing:
Select * from InvoiceHeader where customer_id = 848 and status = 'H'
Select * from InvoiceDetail where invoice_id = 1067400 and status = 'H'

CREATE TABLE #InvoicereviewcontactDetails ( invoice_id int, revision_id int )
INSERT INTO #InvoicereviewcontactDetails VALUES ( 1067585, 1 )
	, (1067586, 1)
	, (1067587, 1)
	, (1067588, 1)
	, (1067589, 1)
	, (1067590, 1)
	, (1067591, 1)
DROP TABLE #InvoicereviewcontactDetails
exec sp_LookupInvoiceReviewContacts
No emails sent for Preview_1067400 "Internal review required" is not checked for billing project 6540
No emails sent for Preview_1067590. Customer ID 10974 Billing project 6564 does not have an active internal review contact assigned.
***********************************************************************/
BEGIN

SET NOCOUNT ON

-- Create a Results table
CREATE TABLE #InvoiceReviewResults (
	invoice_id			int	NULL
,	revision_id			int	NULL
,	invoice_code		varchar(16)	NULL
,	customer_id			int			NULL
,	cust_name			varchar(75)	NULL
,	billing_project_id	int		NULL
,	internal_review_flag	char(1)	NULL	
,	active_contacts		int			NULL
,	user_code			varchar(10)	NULL
,	group_id			int			NULL
,	user_name			varchar(40)	NULL
,	email				varchar(80)	NULL	
,	send_email			char(1)		NULL
,	msg					varchar(1000)		
)

/*--  Create a temporary table that we will populate fields
--CREATE TABLE #InvWork (
--	invoice_id int null,
--	revision_id int null,
--	invoice_code	varchar(16)	null,
--	customer_id int null,
--	cust_name	varchar(75)	null,
--	billing_project_id int null )

--  populate with the appropriate invoice_id and revision_id from temp table created outside of
--  this procedure
--INSERT INTO #InvWork 
--SELECT DISTINCT
--	ircd.invoice_id, 
--	ircd.revision_id,
--	IH.invoice_code,
--	IH.customer_id,
--	IH.cust_name,
--	ID.billing_project_id
--FROM #invoicereviewcontactdetails ircd
--JOIN InvoiceHeader IH ON IH.invoice_id = ircd.invoice_id AND IH.revision_id = ircd.revision_id
--JOIN InvoiceDetail ID ON ID.invoice_id = IH.invoice_id AND ID.revision_id = IH.revision_id 

SELECT	IW.invoice_id,
	IW.revision_id,
	IW.invoice_code,
	IW.customer_id,
	IW.cust_name,
	IW.billing_project_id,
	CB.internal_review_flag,
	cbrc.user_code,
	u.email
FROM #InvWork IW 
LEFT OUTER JOIN CustomerBillingReviewContact cbrc ON IW.customer_id = cbrc.customer_id AND IW.billing_project_id = cbrc.billing_project_id
LEFT OUTER JOIN CustomerBilling cb ON IW.customer_id = cb.customer_id AND IW.billing_project_id = cb.billing_project_id and cb.internal_review_flag = 'T'
LEFT OUTER JOIN users u ON u.user_code = cbrc.user_code and u.group_id <> 0
ORDER BY  u.email,IW.customer_id,IW.cust_name, IW.invoice_code

--  drop the temp table that we created
DROP TABLE #InvWork

*/

INSERT INTO #InvoiceReviewResults 
SELECT DISTINCT
	ircd.invoice_id, 
	ircd.revision_id,
	IH.invoice_code,
	IH.customer_id,
	IH.cust_name,
	ID.billing_project_id,
	CB.internal_review_flag,
	NULL,
	--active_contacts = (SELECT Count(user_code) FROM CustomerBillingReviewContact CBRC
	--					JOIN Users ON Users.user_code = CBRC.user_code
	--						AND Users.group_id <> 0							
	--					WHERE CBRC.customer_id = CB.customer_id
	--					AND CBRC.billing_project_id = CB.billing_project_id),
	CBR.user_code,
	U.group_id	,
	U.user_name,
	U.email,
	'F',
	NULL					
FROM #invoicereviewcontactdetails ircd
JOIN InvoiceHeader IH ON IH.invoice_id = ircd.invoice_id AND IH.revision_id = ircd.revision_id
JOIN InvoiceDetail ID ON ID.invoice_id = IH.invoice_id AND ID.revision_id = IH.revision_id
JOIN CustomerBilling CB ON CB.customer_id = IH.customer_id AND CB.billing_project_id = ID.billing_project_id
LEFT OUTER JOIN CustomerBillingReviewContact CBR
	ON CBR.customer_id = CB.customer_id
	AND CBR.billing_project_id = CB.billing_project_id
LEFT OUTER JOIN Users U
	ON U.user_code = CBR.user_code
--WHERE (CB.internal_review_flag = 'T' OR EXISTS (SELECT 1 from CustomerBillingReviewContact CBRC
--												WHERE CBRC.customer_id = CB.customer_id
--												AND CBRC.billing_project_id = CB.billing_project_id))
	
-- Get number of active contacts												
UPDATE #InvoiceReviewResults
SET active_contacts = (SELECT Count(CBRC.user_code) FROM CustomerBillingReviewContact CBRC
						JOIN Users ON Users.user_code = CBRC.user_code
							AND Users.group_id <> 0							
						WHERE CBRC.customer_id = IRR.customer_id
						AND CBRC.billing_project_id = IRR.billing_project_id)
FROM #InvoiceReviewResults IRR

-- Set send_email flag on each row
UPDATE #InvoiceReviewResults
SET send_email = 'T'
FROM #InvoiceReviewResults IRR
WHERE IRR.email IS NOT NULL
AND Isnull(IRR.group_id, 0) <> 0
AND IRR.internal_review_flag = 'T'

-- Add appropriate error msgs for the rows where send_email flag is F'
-- internal review flag is 'F'
UPDATE #InvoiceReviewResults
SET msg = 'Customer ' + Convert(varchar(10), IRR.customer_id) + ', ' + IRR.invoice_code + ': "Internal review required" is not checked for billing project ' + Convert(varchar(10), IRR.billing_project_id) + '.'
FROM #InvoiceReviewResults IRR
WHERE IRR.send_email = 'F' AND IRR.internal_review_flag = 'F' AND IRR.msg IS NULL
--SET msg = 'No emails sent for '+ IRR.invoice_code + '. "Internal review required" is not checked for Customer ID ' + Convert(varchar(10), IRR.customer_id) + ', Billing project ' + Convert(varchar(10), IRR.billing_project_id) + '.'

-- no contacts listed on the billing project
UPDATE #InvoiceReviewResults
SET msg = 'Customer ' + Convert(varchar(10), IRR.customer_id) + ', ' + IRR.invoice_code + ': Billing project ' + Convert(varchar(10), IRR.billing_project_id) + ' does not have an active internal review contact assigned.'
FROM #InvoiceReviewResults IRR
WHERE IRR.send_email = 'F' AND active_contacts = 0 AND IRR.msg IS NULL
--SET msg = 'No emails sent for '+ IRR.invoice_code + '. Customer ID '+ Convert(varchar(10), IRR.customer_id) + ' Billing project ' + Convert(varchar(10), IRR.billing_project_id) + ' does not have an active internal review contact assigned.'

-- contact listed is no longer active
UPDATE #InvoiceReviewResults
SET msg = 'Customer ' + Convert(varchar(10), IRR.customer_id) + ', ' + IRR.invoice_code + ': Email not sent to user '+ IRR.user_name + ' for billing project ' + Convert(varchar(10), IRR.billing_project_id) + '. This user is no longer active.'
FROM #InvoiceReviewResults IRR
WHERE IRR.send_email = 'F' AND group_id = 0 AND IRR.email IS NOT NULL AND IRR.msg IS NULL
--SET msg = 'Email not sent to user '+ IRR.user_name + ' for ' + IRR.invoice_code + ', customer ID ' + Convert(varchar(10), IRR.customer_id) + ', billing project ' + Convert(varchar(10), IRR.billing_project_id) + '. This user is no longer active.'

-- Select the ResultSet
SELECT * FROM #InvoiceReviewResults order by email,  cust_name, customer_id, invoice_code

-- drop temp table
DROP TABLE #InvoiceReviewResults

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_LookupInvoiceReviewContacts] TO [EQAI]
    AS [dbo];

