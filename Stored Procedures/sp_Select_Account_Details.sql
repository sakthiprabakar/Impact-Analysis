CREATE PROCEDURE [dbo].[sp_Select_Account_Details]



 @web_userid varchar(100)
 
AS
BEGIN
/* ******************************************************************

	Updated By		: Meenachi
	Updated On		: 11th Mar 2019
	Type			: Stored Procedure
	Object Name		: [sp_Select_Account_Details]


	User Account details 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_Select_Account_Details] @web_userid
 EXEC [sp_Select_Account_Details] 'manand84'

***********************************************************************/


	select 'Customer' as type,CusDtl.cust_name as Name, null as epa_id,CusDtl.customer_id as ID  from ContactCORCustomerBucket Cust JOIN  dbo.CONTACT c ON c.contact_id=Cust.contact_id 
	JOIN  customer CusDtl ON CusDtl.customer_id=Cust.customer_id 
	WHERE c.web_userid=@web_userid
	union
	select top 10 'Generator' as type,genDtl.generator_name as Name, null as epa_id,genDtl.generator_id as ID from  ContactCORGeneratorBucket Gen JOIN  CONTACT c ON c.contact_id=Gen.contact_id 
	JOIN  generator genDtl ON Gen.generator_id=genDtl.generator_id 
	WHERE c.web_userid=@web_userid

END
GO

