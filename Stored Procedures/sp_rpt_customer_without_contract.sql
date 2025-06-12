CREATE PROCEDURE sp_rpt_customer_without_contract
	@customer_status    char(1)
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	r_customer_without_contract

06/26/2017 AM 	Created - Create a report to display the Customer accounts without a contract entered

select * from contract 
sp_rpt_customer_without_contract 'L'

****************************************************************************************/
Declare @cust_status varchar (3)

IF @customer_status = 'L'
  SET @cust_status = 'ALL'
ELSE 
  SET @cust_status = @customer_status

SELECT Customer.customer_id,
	   Customer.cust_name,
	   Customer.customer_type,
	   Customer.cust_status, 
	   Customer.terms_code,
       Customer.added_by,
       Customer.date_added,
       Customer.modified_by,
       Customer.date_modified
FROM  Customer 
LEFT OUTER JOIN Contract ON Contract.customer_id = Customer.customer_id
   AND Contract.customer_id is null 
WHERE ( Customer.cust_status = @cust_status OR ('ALL' = @cust_status) )
AND Customer.cust_prospect_flag = 'C'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_without_contract] TO [EQAI]
    AS [dbo];

