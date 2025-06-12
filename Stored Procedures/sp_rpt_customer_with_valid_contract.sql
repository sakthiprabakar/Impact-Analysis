CREATE PROCEDURE sp_rpt_customer_with_valid_contract
	@customer_status    char(1)
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	r_customer_with_valid_contract
Customer accounts with valid contracts
06/26/2017 AM 	Created - Create a report to display the Customer accounts with a valid contract entered

select * from contract 
sp_rpt_customer_with_valid_contract 'L'
sp_rpt_customer_with_valid_contract 'A'
****************************************************************************************/
Declare @cust_status varchar (3)

IF @customer_status = 'L'
  SET @cust_status = 'ALL' 
ELSE 
  SET @cust_status = @customer_status

SELECT Customer.customer_ID, 
       Customer.cust_name,
       Customer.customer_type,
       Customer.cust_status,
       Customer.terms_code, 
       Contract.contract_number, 
       Contract.date_signed, 
       Contract.date_expire,
       Contract.status
FROM Customer 
LEFT OUTER JOIN Contract ON Customer.customer_id = Contract.customer_id 
WHERE ( Customer.cust_status = @cust_status OR ('ALL' = @cust_status) )
AND Customer.cust_prospect_flag = 'C'
AND Contract.customer_id is not null


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_with_valid_contract] TO [EQAI]
    AS [dbo];

