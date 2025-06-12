USE [PLT_AI]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

  
ALTER PROCEDURE [dbo].[sp_COR_Profile_Fuel_Supplement]  
(  
 @profile_id INT   
)  
  
AS  
  
/* ******************************************************************  
  
 Author  : Prabhu  
 Updated On : 16-Aug-2023  
 Type  : Store Procedure   
 Object Name : [dbo].[sp_COR_Fuel_Supplement]  
 Ticket        : 73641
 Description : Procedure to Fuel Supplement  
  
 Input  : @profile_id  
  
                   
 Execution Statement : EXEC [plt_ai].[dbo].[sp_COR_Profile_Fuel_Supplement]  977371  
  
****************************************************************** */  
  
BEGIN  
  
  SELECT  
    
   PRE.viscosity_value AS viscosity_value,    
   PRE.total_solids_low AS total_solids_low,    
   PRE.total_solids_high AS total_solids_high,    
   PRE.total_solids_description AS total_solids_description, 
   PRE.fluorine_low AS fluorine_low,
   PRE.fluorine_high AS fluorine_high,
   PRE.chlorine_low AS chlorine_low,
   PRE.chlorine_high AS chlorine_high,
   PRE.bromine_low AS bromine_low,
   PRE.bromine_high AS bromine_high,
   PRE.iodine_low AS iodine_low,
   PRE.iodine_high AS iodine_high,
   PRE.added_by AS added_by,    
   PRE.modified_by AS modified_by,    
   GETDATE() AS date_added,    
   GETDATE() AS date_modified,
   PRE.total_solids_flag,
   PRE.organic_halogens_flag,
   PRE.fluorine_low_flag,
   PRE.fluorine_high_flag,
   PRE.chlorine_low_flag,
   PRE.chlorine_high_flag,
   PRE.bromine_low_flag,
   PRE.bromine_high_flag,
   PRE.iodine_low_flag,
   PRE.iodine_high_flag,
   P.wcr_sign_company AS signing_company,   
         P.wcr_sign_name AS signing_name,   
         P.wcr_sign_title AS signing_title,   
         P.wcr_sign_date AS signing_date  
   FROM  ProfileEcoflo AS PRE     
    JOIN  Profile AS P ON P.profile_id = PRE.profile_id  
   WHERE     
   PRE.profile_Id = @profile_id    
  
END   
  
