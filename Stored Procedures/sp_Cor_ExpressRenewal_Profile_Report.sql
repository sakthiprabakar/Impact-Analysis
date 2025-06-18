USE PLT_AI
GO

CREATE PROCEDURE [dbo].[sp_Cor_ExpressRenewal_Profile_Report]  
(  
    @profile_id_csv_list varchar(500),  
    @web_userid VARCHAR(100) 
)     
AS

/*******************************************************************  
  
 Created By		: Divya Bharathi R
 Updated On		: 11th March 2025
 Type			: Stored Procedure
 Object Name	: [sp_Cor_ExpressRenewal_Profile_Report]
 Purpose		: Procedure to Update signing_name, signing_company for the Express Renew Profiles based on logged in user
 Inputs			: @profile_id_csv_list, @web_userid
   

Samples:  
 EXEC [sp_Cor_ExpressRenewal_Profile_Report] @profile_id_csv_list, @web_userid
 EXEC [sp_Cor_ExpressRenewal_Profile_Report] '1076633,659778', 'vinolin24'

****************************************************************** */

BEGIN 

  DROP TABLE IF EXISTS #Temp_Profile_Details
  DECLARE @print_name varchar(50)    
  DECLARE @contact_company varchar(75)

  -- Get the print name & company name for the logged in user
  SELECT TOP 1 
	@print_name = first_name + ' ' + last_name ,
    @contact_company = contact_company
  FROM Contact
  WHERE web_userid = @web_userid AND web_access_flag = 'T' AND contact_status = 'A'

  --Create a temp table
  CREATE TABLE #Temp_Profile_Details
  (
   profile_id int,
   customer_id int,
   waste_code varchar(MAX), -- Length is defined as MAX because this value stores comma-separated waste codes for a profile, and the total length cannot be predetermined.
   cust_name varchar(75),
   cust_addr1 varchar(40),
   cust_city varchar(40),
   cust_state varchar(2),
   cust_zip_code varchar(15),
   [name] varchar(40),
   generator_name varchar(75),
   EPA_ID varchar(12),
   approval_desc varchar(50),
   approval_code varchar(15),
   company_id smallInt,
   profit_ctr_id int,
   quote_id int,
   ap_expiration_date datetime, 
   profit_ctr_name varchar(50),
   profit_ctr_epa_ID varchar(12),
   OTS_flag varchar(1),
   signing_name varchar(40),
   signing_company varchar(40),
   signing_date datetime
  )
  
  --Get the details of bulk renewal report from 'sp_Cor_BulkRenewal_Profile_Report' and insert into temp_table
  INSERT INTO #Temp_Profile_Details
  (
   profile_id, 
   customer_id, 
   waste_code,
   cust_name,
   cust_addr1,
   cust_city, 
   cust_state,
   cust_zip_code,
   [name],
   generator_name,  
   EPA_ID,  
   approval_desc,  
   approval_code,  
   company_id,  
   profit_ctr_id,  
   quote_id,  
   ap_expiration_date, 
   profit_ctr_name, 
   profit_ctr_epa_ID,  
   OTS_flag,  
   signing_name,  
   signing_company,  
   signing_date
  )
  EXEC sp_Cor_BulkRenewal_Profile_Report @profile_id_csv_list

  --Select the values from temp_table and use the signing_name, signing_company from contact table
  SELECT 
	   profile_id, 
	   customer_id, 
	   waste_code,
	   cust_name,
	   cust_addr1,
	   cust_city, 
	   cust_state,
	   cust_zip_code,
	   [name],
	   generator_name,  
	   EPA_ID,  
	   approval_desc,  
	   approval_code,  
	   company_id,  
	   profit_ctr_id,  
	   quote_id,  
	   ap_expiration_date, 
	   profit_ctr_name, 
	   profit_ctr_epa_ID,  
	   OTS_flag,  
	   @print_name as signing_name,  
	   @contact_company as signing_company
  FROM #Temp_Profile_Details

  --Drop temp table 
  DROP TABLE IF EXISTS #Temp_Profile_Details

END
GO

GRANT EXEC ON [dbo].[sp_Cor_ExpressRenewal_Profile_Report] TO COR_USER;
GO