CREATE PROCEDURE sp_rpt_contracts_about_to_expire
	@customer_id_from	int, 
	@customer_id_to		int,
	@date_from			datetime, 
	@date_to			datetime,
	@customer_status    char(1)
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	r_contracts_to_expire

06/26/2017 AM 	Created

select * from contract 
sp_rpt_contracts_about_to_expire 888880,888880,'06/27/2017','07/27/2017','L'
sp_rpt_contracts_about_to_expire 888880,888880,'01/01/1990','01/01/1990','A'
sp_rpt_contracts_about_to_expire 1,999999,'6/29/2017 00:00:00','6/29/2017 23:59:59','L'
****************************************************************************************/
Declare @cust_status varchar (3)

IF @customer_status = 'L'
  SET  @cust_status = 'ALL'
ELSE 
  SET @cust_status = @customer_status

IF ( CONVERT(VARCHAR(10), @date_from , 111)  = CONVERT(VARCHAR(10), GETDATE(), 111) 
			AND ( CONVERT(VARCHAR(10), @date_to , 111)  = CONVERT(VARCHAR(10), GETDATE(), 111)) )
 BEGIN 
  SET @date_from = '01/01/1990'
  SET @date_to = '01/01/1990'
 END 

SELECT Contract.contract_uid,
	   Contract.customer_id,
	   Contract.contract_number,
	   Contract.date_signed,
	   Contract.expire_flag,
	   Contract.date_expire,
	   Contract.notes,
       Contract.status,
       Contract.added_by,
       Contract.date_added,
       Contract.modified_by,
       Contract.date_modified,
       Contract.master_services_agreement_flag,
	   Contract.general_terms_flag,
	   Contract.retail_services_terms_flag,
	   Contract.industrial_service_terms_flag,
	   Contract.waste_transportation_flag,
	   Contract.disposal_flag,
	   Contract.recycling_agreement_flag,
	   Contract.emergency_response_terms_flag,
	   Contract.project_only_flag,
	   Contract.customer_contract_flag,
	   Contract.purchase_order_contract_flag,
	   Contract.amended_flag 
FROM  Contract 
INNER JOIN Customer ON Contract.customer_id = Customer.customer_id
   And ( Customer.cust_status = @cust_status OR ('ALL' = @cust_status) )
WHERE Contract.customer_id between @customer_id_from and @customer_id_to
AND  ( Contract.date_expire between @date_from and @date_to OR (@date_from = '01/01/1990' AND @date_to = '01/01/1990' ))


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_contracts_about_to_expire] TO [EQAI]
    AS [dbo];

