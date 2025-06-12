
-- drop PROCEDURE if exists [dbo].[sp_State_List]    
go

-- =============================================  
-- Author:   Dinesh  
-- Create date: 10-Nov-2018  
-- Description: This procedure is used to state list binding dropdown values  i.e state list for registarion and profile.  
-- Modified 10/4/2021 - Dinesh/Jonathan to add country-abbreviation field
-- =============================================  
CREATE PROCEDURE [dbo].[sp_State_List]  
 -- Add the parameters for the stored procedure here  
  
AS  
/* ******************************************************************  
List all State values for the lookp dropdown  
  
[sp_State_List]  
  
Returns  
  
 Abbreviation  
 State Name  
 Country Code  
 Country-Abbreviation
  
****************************************************************** */  
BEGIN  
 -- SET NOCOUNT ON added to prevent extra result sets from  
 -- interfering with SELECT statements.  
 SET NOCOUNT ON;  
  
    -- Insert statements for procedure here  
 -- select abbr, state_name, country_code from [dbo].[StateAbbreviation] where country_code IN ('USA', 'CAN', 'MEX', 'PRI')  
  
 select 
 abbr as abbr
 , state_name
 , country_code
 ,  country_code + '-' + abbr as countryabbr 
 from [dbo].[StateAbbreviation]   
 where country_code IN (select country_code from country where status = 'A')  
END  

GO

	GRANT EXECUTE ON [dbo].[sp_State_List] TO COR_USER;

GO
