USE [PLT_AI]
GO
/******************************************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_IllinoisDisposal_insert_update] 
GO 
CREATE PROCEDURE [dbo].[sp_IllinoisDisposal_insert_update]  
       @Data XML,  
    @form_id int,  
    @revision_id int,  
    @web_userid varchar(100)  
AS  
/* ******************************************************************    
Insert / update Illinois Disposal form  (Part of form wcr insert / update)  
  Updated By   : Ranjini C
  Updated On   : 08-AUGUST-2024
  Ticket       : 93217
  Decription   : This procedure is used to assign web_userid to created_by and modified_by columns.   
inputs      
 Data -- XML data having values for the FormIllinoisDisposal table objects  
 Form ID  
 Revision ID   
****************************************************************** */  
BEGIN    
  IF(NOT EXISTS(SELECT 1 FROM FormIllinoisDisposal  WITH(NOLOCK) WHERE wcr_id = @form_id  and wcr_rev_id=  @revision_id))  
 BEGIN    
    DECLARE @newForm_id INT   
  DECLARE @newrev_id INT  = 1      
  EXEC @newForm_id = sp_sequence_next 'form.form_id'    
  INSERT INTO FormIllinoisDisposal(  
   form_id,  
   revision_id,  
   wcr_id,  
   wcr_rev_id,  
   locked,  
   none_apply_flag,  
   incecticides_flag,  
   pesticides_flag,  
   herbicides_flag,  
   household_waste_flag,  
   carcinogen_flag,  
   other_flag,  
   other_specify,  
   sulfide_10_250_flag,  
   universal_waste_flag,  
   characteristic_sludge_flag,  
   virgin_unused_product_flag,  
   spent_material_flag,  
   cyanide_plating_on_site_flag,  
   substitute_commercial_product_flag,  
   by_product_flag,  
   rx_lime_flammable_gas_flag,  
   pollution_control_waste_IL_flag,  
   industrial_process_waste_IL_flag,  
   phenol_gt_1000_flag,  
   generator_state_id,  
   d004_above_PQL,  
   d005_above_PQL,  
   d006_above_PQL,  
   d007_above_PQL,  
   d008_above_PQL,  
   d009_above_PQL,  
   d010_above_PQL,  
   d011_above_PQL,  
   d012_above_PQL,  
   d013_above_PQL,  
   d014_above_PQL,  
   d015_above_PQL,  
   d016_above_PQL,  
   d017_above_PQL,  
   d018_above_PQL,  
   d019_above_PQL,  
   d020_above_PQL,  
   d021_above_PQL,  
   d022_above_PQL,  
   d023_above_PQL,  
   d024_above_PQL,  
   d025_above_PQL,  
   d026_above_PQL,  
   d027_above_PQL,  
   d028_above_PQL,  
   d029_above_PQL,  
   d030_above_PQL,  
   d031_above_PQL,  
   d032_above_PQL,  
   d033_above_PQL,  
   d034_above_PQL,  
   d035_above_PQL,  
   d036_above_PQL,  
   d037_above_PQL,  
   d038_above_PQL,  
   d039_above_PQL,  
   d040_above_PQL,  
   d041_above_PQL,  
   d042_above_PQL,  
   d043_above_PQL,  
   created_by,  
   date_created,  
   date_modified,  
   modified_by,  
   generator_certification_flag,  
   certify_flag  
   )  
        SELECT        
      form_id=@newForm_id,  
   revision_id=@newrev_id,  
      wcr_id= @form_id,  
   wcr_rev_id=@revision_id,  
   --locked = p.v.value('locked[1]','char(1)'),  
   locked = 'U',  
   none_apply_flag = p.v.value('none_apply_flag[1]','char(1)'),  
   incecticides_flag=p.v.value('incecticides_flag[1]','char(1)'),  
   pesticides_flag=p.v.value('pesticides_flag[1]','char(1)'),  
   herbicides_flag =p.v.value('herbicides_flag[1]','char(1)'),  
   household_waste_flag =p.v.value('household_waste_flag[1]','char(1)'),  
   carcinogen_flag =p.v.value('carcinogen_flag[1]','char(1)'),  
   other_flag =p.v.value('other_flag[1]','char(1)'),  
   other_specify =p.v.value('other_specify[1]','char(80)'),  
   sulfide_10_250_flag =p.v.value('sulfide_10_250_flag[1]','char(1)'),  
   universal_waste_flag =p.v.value('universal_waste_flag[1]','char(1)'),  
   characteristic_sludge_flag =p.v.value('characteristic_sludge_flag[1]','char(1)'),  
   virgin_unused_product_flag =p.v.value('virgin_unused_product_flag[1]','char(1)'),  
   spent_material_flag =p.v.value('spent_material_flag[1]','char(1)'),  
   cyanide_plating_on_site_flag =p.v.value('cyanide_plating_on_site_flag[1]','char(1)'),  
   substitute_commercial_product_flag =p.v.value('substitute_commercial_product_flag[1]','char(1)'),  
   by_product_flag =p.v.value('by_product_flag[1]','char(1)'),  
   rx_lime_flammable_gas_flag =p.v.value('rx_lime_flammable_gas_flag[1]','char(1)'),  
   pollution_control_waste_IL_flag =p.v.value('pollution_control_waste_IL_flag[1]','char(1)'),  
   industrial_process_waste_IL_flag =p.v.value('industrial_process_waste_IL_flag[1]','char(1)'),  
   phenol_gt_1000_flag =p.v.value('phenol_gt_1000_flag[1]','char(1)'),  
   generator_state_id =p.v.value('generator_state_id[1]','VARCHAR(40)'),  
   d004_above_PQL=p.v.value('d004_above_PQL[1]','char(1)'),  
   d005_above_PQL=p.v.value('d005_above_PQL[1]','char(1)'),  
   d006_above_PQL=p.v.value('d006_above_PQL[1]','char(1)'),  
   d007_above_PQL=p.v.value('d007_above_PQL[1]','char(1)'),  
   d008_above_PQL=p.v.value('d008_above_PQL[1]','char(1)'),  
   d009_above_PQL=p.v.value('d009_above_PQL[1]','char(1)'),  
   d010_above_PQL=p.v.value('d010_above_PQL[1]','char(1)'),  
   d011_above_PQL=p.v.value('d011_above_PQL[1]','char(1)'),  
   d012_above_PQL=p.v.value('d012_above_PQL[1]','char(1)'),  
   d013_above_PQL=p.v.value('d013_above_PQL[1]','char(1)'),  
   d014_above_PQL=p.v.value('d014_above_PQL[1]','char(1)'),  
   d015_above_PQL=p.v.value('d015_above_PQL[1]','char(1)'),  
   d016_above_PQL=p.v.value('d016_above_PQL[1]','char(1)'),  
   d017_above_PQL=p.v.value('d017_above_PQL[1]','char(1)'),  
   d018_above_PQL=p.v.value('d018_above_PQL[1]','char(1)'),  
   d019_above_PQL=p.v.value('d019_above_PQL[1]','char(1)'),  
   d020_above_PQL=p.v.value('d020_above_PQL[1]','char(1)'),  
   d021_above_PQL=p.v.value('d021_above_PQL[1]','char(1)'),  
   d022_above_PQL=p.v.value('d022_above_PQL[1]','char(1)'),  
   d023_above_PQL=p.v.value('d023_above_PQL[1]','char(1)'),  
   d024_above_PQL=p.v.value('d024_above_PQL[1]','char(1)'),  
   d025_above_PQL=p.v.value('d025_above_PQL[1]','char(1)'),  
   d026_above_PQL=p.v.value('d026_above_PQL[1]','char(1)'),  
   d027_above_PQL=p.v.value('d027_above_PQL[1]','char(1)'),  
   d028_above_PQL=p.v.value('d028_above_PQL[1]','char(1)'),  
   d029_above_PQL=p.v.value('d029_above_PQL[1]','char(1)'),  
   d030_above_PQL=p.v.value('d030_above_PQL[1]','char(1)'),  
   d031_above_PQL=p.v.value('d031_above_PQL[1]','char(1)'),  
   d032_above_PQL=p.v.value('d032_above_PQL[1]','char(1)'),  
   d033_above_PQL=p.v.value('d033_above_PQL[1]','char(1)'),  
   d034_above_PQL=p.v.value('d034_above_PQL[1]','char(1)'),  
   d035_above_PQL=p.v.value('d035_above_PQL[1]','char(1)'),  
   d036_above_PQL=p.v.value('d036_above_PQL[1]','char(1)'),  
   d037_above_PQL=p.v.value('d037_above_PQL[1]','char(1)'),  
   d038_above_PQL=p.v.value('d038_above_PQL[1]','char(1)'),  
   d039_above_PQL=p.v.value('d039_above_PQL[1]','char(1)'),  
   d040_above_PQL=p.v.value('d040_above_PQL[1]','char(1)'),  
   d041_above_PQL=p.v.value('d041_above_PQL[1]','char(1)'),  
   d042_above_PQL=p.v.value('d042_above_PQL[1]','char(1)'),  
   d043_above_PQL=p.v.value('d043_above_PQL[1]','char(1)'),  
   created_by = @web_userid,  
      date_created = GETDATE(),  
      date_modified = GETDATE(),     
      modified_by = @web_userid,  
   generator_certification_flag = p.v.value('generator_certification_flag[1]','CHAR(1)'),  
   certify_flag = p.v.value('certify_flag[1]','CHAR(1)')   
        FROM  
            @Data.nodes('IllinoisDisposal')p(v)  
  
   END  
  ELSE  
   BEGIN  
        UPDATE  FormIllinoisDisposal  
        SET                   
   --locked = p.v.value('locked[1]','char(1)'),  
   locked = 'U',  
   none_apply_flag = p.v.value('none_apply_flag[1]','char(1)'),  
   incecticides_flag=p.v.value('incecticides_flag[1]','char(1)'),  
   pesticides_flag=p.v.value('pesticides_flag[1]','char(1)'),  
   herbicides_flag =p.v.value('herbicides_flag[1]','char(1)'),  
   household_waste_flag =p.v.value('household_waste_flag[1]','char(1)'),  
   carcinogen_flag =p.v.value('carcinogen_flag[1]','char(1)'),  
   other_flag =p.v.value('other_flag[1]','char(1)'),  
   other_specify =p.v.value('other_specify[1]','char(80)'),  
   sulfide_10_250_flag =p.v.value('sulfide_10_250_flag[1]','char(1)'),  
   universal_waste_flag =p.v.value('universal_waste_flag[1]','char(1)'),  
   characteristic_sludge_flag =p.v.value('characteristic_sludge_flag[1]','char(1)'),  
   virgin_unused_product_flag =p.v.value('virgin_unused_product_flag[1]','char(1)'),  
   spent_material_flag =p.v.value('spent_material_flag[1]','char(1)'),  
   cyanide_plating_on_site_flag =p.v.value('cyanide_plating_on_site_flag[1]','char(1)'),  
   substitute_commercial_product_flag =p.v.value('substitute_commercial_product_flag[1]','char(1)'),  
   by_product_flag =p.v.value('by_product_flag[1]','char(1)'),  
   rx_lime_flammable_gas_flag =p.v.value('rx_lime_flammable_gas_flag[1]','char(1)'),  
   pollution_control_waste_IL_flag =p.v.value('pollution_control_waste_IL_flag[1]','char(1)'),  
   industrial_process_waste_IL_flag =p.v.value('industrial_process_waste_IL_flag[1]','char(1)'),  
   phenol_gt_1000_flag =p.v.value('phenol_gt_1000_flag[1]','char(1)'),  
   generator_state_id =p.v.value('generator_state_id[1]','VARCHAR(40)'),  
   d004_above_PQL=p.v.value('d004_above_PQL[1]','char(1)'),  
   d005_above_PQL=p.v.value('d005_above_PQL[1]','char(1)'),  
   d006_above_PQL=p.v.value('d006_above_PQL[1]','char(1)'),  
   d007_above_PQL=p.v.value('d007_above_PQL[1]','char(1)'),  
   d008_above_PQL=p.v.value('d008_above_PQL[1]','char(1)'),  
   d009_above_PQL=p.v.value('d009_above_PQL[1]','char(1)'),  
   d010_above_PQL=p.v.value('d010_above_PQL[1]','char(1)'),  
   d011_above_PQL=p.v.value('d011_above_PQL[1]','char(1)'),  
   d012_above_PQL=p.v.value('d012_above_PQL[1]','char(1)'),  
   d013_above_PQL=p.v.value('d013_above_PQL[1]','char(1)'),  
   d014_above_PQL=p.v.value('d014_above_PQL[1]','char(1)'),  
   d015_above_PQL=p.v.value('d015_above_PQL[1]','char(1)'),  
   d016_above_PQL=p.v.value('d016_above_PQL[1]','char(1)'),  
   d017_above_PQL=p.v.value('d017_above_PQL[1]','char(1)'),  
   d018_above_PQL=p.v.value('d018_above_PQL[1]','char(1)'),  
   d019_above_PQL=p.v.value('d019_above_PQL[1]','char(1)'),  
   d020_above_PQL=p.v.value('d020_above_PQL[1]','char(1)'),  
   d021_above_PQL=p.v.value('d021_above_PQL[1]','char(1)'),  
   d022_above_PQL=p.v.value('d022_above_PQL[1]','char(1)'),  
   d023_above_PQL=p.v.value('d023_above_PQL[1]','char(1)'),  
   d024_above_PQL=p.v.value('d024_above_PQL[1]','char(1)'),  
   d025_above_PQL=p.v.value('d025_above_PQL[1]','char(1)'),  
   d026_above_PQL=p.v.value('d026_above_PQL[1]','char(1)'),  
   d027_above_PQL=p.v.value('d027_above_PQL[1]','char(1)'),  
   d028_above_PQL=p.v.value('d028_above_PQL[1]','char(1)'),  
   d029_above_PQL=p.v.value('d029_above_PQL[1]','char(1)'),  
   d030_above_PQL=p.v.value('d030_above_PQL[1]','char(1)'),  
   d031_above_PQL=p.v.value('d031_above_PQL[1]','char(1)'),  
   d032_above_PQL=p.v.value('d032_above_PQL[1]','char(1)'),  
   d033_above_PQL=p.v.value('d033_above_PQL[1]','char(1)'),  
   d034_above_PQL=p.v.value('d034_above_PQL[1]','char(1)'),  
   d035_above_PQL=p.v.value('d035_above_PQL[1]','char(1)'),  
   d036_above_PQL=p.v.value('d036_above_PQL[1]','char(1)'),  
   d037_above_PQL=p.v.value('d037_above_PQL[1]','char(1)'),  
   d038_above_PQL=p.v.value('d038_above_PQL[1]','char(1)'),  
   d039_above_PQL=p.v.value('d039_above_PQL[1]','char(1)'),  
   d040_above_PQL=p.v.value('d040_above_PQL[1]','char(1)'),  
   d041_above_PQL=p.v.value('d041_above_PQL[1]','char(1)'),  
   d042_above_PQL=p.v.value('d042_above_PQL[1]','char(1)'),  
   d043_above_PQL=p.v.value('d043_above_PQL[1]','char(1)'),  
      date_modified = GETDATE(),  
      modified_by = @web_userid,  
   generator_certification_flag = p.v.value('generator_certification_flag[1]','CHAR(1)'),  
   certify_flag = p.v.value('certify_flag[1]','CHAR(1)')  
   FROM  
         @Data.nodes('IllinoisDisposal')p(v) WHERE wcr_id = @form_id and wcr_rev_id=@revision_id  
END  
  
  DECLARE @h2sHCN INT,  
 @Standard INT,  
 @F_signing_name NVARCHAR(40),  
 @signing_name NVARCHAR(40)    
 SELECT @h2sHCN= form_signature_type_id FROM FormSignatureType WHERE [description]='H2S/HCN'  
 SELECT @Standard= form_signature_type_id FROM FormSignatureType WHERE [description]='Standard'  
 SELECT @F_signing_name= p.v.value('F_signing_name[1]','varchar(40)') FROM @Data.nodes('IllinoisDisposal')p(v)  
 SELECT @signing_name= p.v.value('signing_name[1]','varchar(40)') FROM @Data.nodes('IllinoisDisposal')p(v)  
   IF((@F_signing_name IS NOT NULL AND @F_signing_name<>'') AND NOT EXISTS(SELECT form_id FROM FormSignature WHERE form_id = @form_id  and revision_id=  @revision_id AND form_signature_type_id=@h2sHCN))  
  BEGIN  
  INSERT INTO FormSignature ( form_id,  
      revision_id ,  
      form_signature_type_id ,  
      sign_name ,  
      date_added,  
      rowguid )    
              SELECT  
      form_id = @form_id,  
      revision_id = @revision_id,  
      form_signature_type_id = @h2sHCN,  
      sign_name = p.v.value('F_signing_name[1]','varchar(40)'),  
      date_added = getdate(),  
      rowguid = NEWID()  
              FROM  
            @Data.nodes('IllinoisDisposal')p(v)    
END  
  
 IF((@signing_name IS NOT NULL AND @signing_name<>'') AND NOT EXISTS(SELECT form_id FROM FormSignature WHERE form_id = @form_id  and revision_id=  @revision_id AND form_signature_type_id=@Standard))  
  BEGIN  
  INSERT INTO FormSignature ( form_id,  
      revision_id ,  
      form_signature_type_id ,  
      sign_name ,  
      date_added,  
      rowguid )   
              SELECT  
      form_id = @form_id,  
      revision_id = @revision_id,  
      form_signature_type_id = @Standard,  
      sign_name = p.v.value('signing_name[1]','varchar(40)'),  
      date_added = getdate(),  
      rowguid = NEWID()  
              FROM  
            @Data.nodes('IllinoisDisposal')p(v)   
END  
END 
GO
	GRANT EXECUTE ON [dbo].[sp_IllinoisDisposal_insert_update] TO COR_USER;
GO 
/******************************************************************************************************************************/

