
CREATE PROCEDURE [dbo].[sp_Approved_ProfileDetail]
	-- Add the parameters for the stored procedure here
		@web_userid VARCHAR(100),
		@profile_id INT,
		@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
		@generator_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
AS

/*
  Author       : Sathiq
  Created date : 21-Dec-2018
  Decription   : Details for Approved Profile

		Get Profile Information such as Generator name, Waste Name  and Available Supplements for the given profileId

07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

  Input 
   web userid
   profile id

  Output 
   Approved profile details

  Sample 

   EXEC [plt_ai].[dbo].[sp_COR_Profile_Detail]  'nyswyn100' , 651685

*/
BEGIN


	declare @type_id int = (select top 1 type_id from plt_image..scandocumenttype where document_type = 'COR Signed Document' ) 
	declare @image_id int = (SELECT top 1 image_id 
		from plt_image..scan s 
		join plt_image..scandocumenttype t on s.type_id = t.type_id and t.view_on_web = 'T' 
		where profile_id = @profile_id and (@type_id = s.type_id or document_source = 'APPRRECERT') and s.view_on_web = 'T' and s.status = 'A' order by date_added desc)

	CREATE TABLE #results (
				 i_d INT IDENTITY(1,1)
				,profile_id INT
				,approval_desc VARCHAR(50)
				,generator_id INT, generator_name VARCHAR(75), epa_id VARCHAR(12),generator_type VARCHAR(20)
				,generator_addr_1 nvarchar(200), generator_city  nvarchar(30), generator_state  nvarchar(20), generator_country  nvarchar(15), generator_zip_code  nvarchar(15), generator_phone  nvarchar(15)
				,gen_mail_addr1 nvarchar(200), gen_mail_city  VARCHAR(30), gen_mail_state  VARCHAR(20), gen_mail_country nvarchar(15), gen_mail_zip nvarchar(15)
				,customer_id INT, cust_name VARCHAR(75), curr_status_code CHAR(1)
				,ap_expiration_date DATETIME,prices BIT,date_modified DATETIME,display_status VARCHAR(40), copy_source VARCHAR(10),image_id INT
                , SA CHAR(1)
                , SB CHAR(1)
                , SC CHAR(1)
                , SD CHAR(1)
                , SE CHAR(1)
                , SF CHAR(1)
                , SG CHAR(1)
                , SH CHAR(1)
                , LR CHAR(1)
                , ID CHAR(1)
				, PL CHAR(1)
                , PB CHAR(1)
                , UL CHAR(1)
                , WI CHAR(1)
                , CN CHAR(1)
                , TL CHAR(1)
                , BZ CHAR(1)
                , CR CHAR(1)
                , RA CHAR(1)
                , DS CHAR(1)
				, IsLDRAttached  CHAR(1) -- LDR Attached or not
				, IsIllinoisAttached  CHAR(1) -- Illinois Attached or not				
				, IsPharmaAttached  CHAR(1) -- Pharmaceutical Attached or not
				, IsPCBAttached  CHAR(1) -- PCB Attached or not	
				, IsUsedOilAttached  CHAR(1) -- Used Oil Attached or not	
				, IsWasteImportAttached  CHAR(1) -- Waste Import Attached or not	
				, IsCertificationAttached  CHAR(1) -- Certification Attached or not	
				, IsThermalAttached  CHAR(1) -- Thermal Attached or not
				, IsBenzeneAttached  CHAR(1) -- Benzene Attached or not					
				, IsCylinderAttached  CHAR(1) -- Cylinder Attached or not	
				, IsRadioActiveAttached  CHAR(1) -- RadioActive Attached or not	
				, IsDebrisAttached  CHAR(1)  -- Debris Attached or not)

)

DECLARE @Generator_id INT

DECLARE  @isAttach_LDR CHAR(1)
	, @isAttach_ID CHAR(1)
	, @isAttach_PL CHAR(1)
	, @isAttach_UL CHAR(1)
	, @isAttach_WI CHAR(1)
	, @isAttach_CN CHAR(1)
	, @isAttach_TL CHAR(1)
	, @isAttach_BZ CHAR(1)
	, @isAttach_PB CHAR(1)
	, @isAttach_DS CHAR(1)
	, @isAttach_CL CHAR(1)
	, @isAttach_RA CHAR(1);

DECLARE @IsLDRAttached CHAR(1) -- LDR Attached or not
				, @IsIllinoisAttached CHAR(1) -- Illinois Attached or not				
				, @IsPharmaAttached CHAR(1) -- Pharmaceutical Attached or not
				, @IsPCBAttached CHAR(1) -- PCB Attached or not	
				, @IsUsedOilAttached CHAR(1) -- Used Oil Attached or not	
				, @IsWasteImportAttached CHAR(1) -- Waste Import Attached or not	
				, @IsCertificationAttached CHAR(1) -- Certification Attached or not	
				, @IsThermalAttached CHAR(1) -- Thermal Attached or not
				, @IsBenzeneAttached CHAR(1) -- Benzene Attached or not					
				, @IsCylinderAttached CHAR(1) -- Cylinder Attached or not	
				, @IsRadioActiveAttached CHAR(1) -- RadioActive Attached or not	
				, @IsDebrisAttached CHAR(1);  -- Debris Attached or not)


-- Select top 1 * from profile where generator_id = 37691
-- Select top 1 NAICS_code from Generator where generator_id = 37691


Set @Generator_id = (SELECT p.generator_id From profile as p JOIN Generator as g on   p.generator_id =  g.generator_id  where p.profile_id = @profile_id)


DECLARE @waste_water_flag CHAR(1),
        @exceed_ldr_standards CHAR(1),
		@meets_alt_soil_treatment_stds CHAR(1),
		@more_than_50_pct_debris CHAR(1),
		@contains_pcb CHAR(1),
		@used_oil CHAR(1),
		@pharmaceutical_flag CHAR(1),
		@thermal_process_flag CHAR(1),
		@origin_refinery CHAR(1),
		@radioactive_waste CHAR(1),
		@reactive_other CHAR(1),
		@biohazard CHAR(1),
		@container_type_cylinder CHAR(1),
		@compressed_gas CHAR(1),
		@specific_technology_requested CHAR(1)

---LDR 

SELECT @waste_water_flag = waste_water_flag , @exceed_ldr_standards=exceed_ldr_standards,
@pharmaceutical_flag=pharmaceutical_flag,
@thermal_process_flag=thermal_process_flag,@origin_refinery=origin_refinery,
@container_type_cylinder=container_type_cylinder,
@specific_technology_requested = specific_technology_requested FROM Profile WHERE profile_id = @profile_id

SELECT @biohazard=biohazard,
		@reactive_other = reactive_other,
		@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds,
@more_than_50_pct_debris=more_than_50_pct_debris,
@used_oil=used_oil,@radioactive_waste=radioactive_waste,
@compressed_gas = compressed_gas,
@contains_pcb=contains_pcb FROM ProfileLab La WHERE profile_id = @profile_id and La.type='A'
 -- 
 DECLARE @disabled CHAR(1) = 'N'
 DECLARE @enabled CHAR(1) = 'Y'

  SET @isAttach_LDR = 'F'
  SET @IsLDRAttached = @disabled
  
  /* LDR Supplement Trigger */
  IF @waste_water_flag = 'W' OR @waste_water_flag = 'N' OR 
			@exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' 
			OR @more_than_50_pct_debris = 'T'
   BEGIN
    SET @isAttach_LDR = 'T'
	  SET @IsLDRAttached = @enabled
   END

-- LDR END

-- VSQG/CESQG Certification Supplement Trigger Starts
  DECLARE @Generator_Country  VARCHAR(3)
  DECLARE @generator_type_id INT

  SET  @isAttach_CN = 'F'
  SET @IsCertificationAttached = 'N'
  SELECT @generator_type_id = generator_type_id ,
		@Generator_Country = generator_Country FROM Generator where generator_id = @Generator_id

  IF  @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType
							WHERE generator_type = 'VSQG/CESQG' ) -- OR @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'VSQG')
   BEGIN 
    SET  @isAttach_CN = 'T'
	SET @IsCertificationAttached = @enabled
   END
-- CERTIFICATE END

-- PCB Supplement Trigger Starts
  SET @isAttach_PB = 'F'
  SET @IsPCBAttached = @disabled
  IF @contains_pcb = 'T'
    BEGIN
	 SET @isAttach_PB = 'T'
	 SET @IsPCBAttached = @enabled
	END
-- PCB END  

-- USED OIL Supplement Trigger Starts
	SET @isAttach_UL = 'F'
	SET @IsUsedOilAttached = @disabled
	IF @used_oil = 'T'
		BEGIN
		SET @isAttach_UL = 'T'
		SET @IsUsedOilAttached = @enabled
	END
-- USED OIL END

  SET @isAttach_ID = 'F'
  SET @IsIllinoisAttached = @disabled

  SET @isAttach_DS = 'F'
  SET @IsDebrisAttached = @disabled

 IF @specific_technology_requested = 'T' 
 BEGIN
	
	/* IllinoisSupplementForm */	
	 IF (SELECT COUNT(*) from ProfileUSEFacility pf Where 
			pf.profile_id = @profile_id AND pf.company_id = 26 AND pf.profit_ctr_id=0) > 0
	 BEGIN
		SET @isAttach_ID = 'T'
		SET @IsIllinoisAttached = @enabled
	 END

	 /* Debris */
	
	IF @more_than_50_pct_debris = 'T' AND 
	(SELECT COUNT(*) from ProfileUSEFacility pf Where 
		pf.profile_id = @profile_id AND pf.company_id = 2 AND pf.profit_ctr_id=0) > 0
	BEGIN 
		SET @isAttach_DS = 'T'
		SET @IsDebrisAttached = @enabled
	END
 END
 

--  pharmaceutical
SET @isAttach_PL = 'F'
SET @IsPharmaAttached = @disabled
IF @pharmaceutical_flag = 'T'
BEGIN
 SET @isAttach_PL = 'T'
 SET @IsPharmaAttached = @enabled
END
-- pharmaceutical END

-- Waste Import Supplement

SET @isAttach_WI = 'F'
SET @IsWasteImportAttached = @disabled
IF ISNULL(@Generator_Country,'') != '' AND @Generator_Country NOT IN('USA','VIR','PRI')
  BEGIN
   SET @isAttach_WI = 'T'
    SET @IsWasteImportAttached = @enabled
  END
  

-- THERMAL 
SET @isAttach_TL = 'F'
set @IsThermalAttached = @disabled
IF @thermal_process_flag = 'T'
BEGIN
 SET @isAttach_TL = 'T' 
 set @IsThermalAttached = @enabled
END
-- THERMAL END

-- BENZEN
SET @isAttach_BZ = 'F'
SET @IsBenzeneAttached = @disabled
IF @origin_refinery = 'T'
BEGIN
 SET @isAttach_BZ = 'T'
 SET @IsBenzeneAttached = @enabled
END
-- BENZEN END

-- RADIOACTIVE
SET @isAttach_RA = 'F'
SET @IsRadioActiveAttached = @disabled
IF @radioactive_waste = 'T' -- OR @reactive_other = 'T' OR	@biohazard = 'T' OR @container_type_cylinder = 'T'
BEGIN 
	SET @isAttach_RA = 'T'
	SET @IsRadioActiveAttached = @enabled
END
-- RADIOACTIVE END

-- 
SET @isAttach_CL = 'F'
SET @IsCylinderAttached = @disabled
IF @container_type_cylinder = 'T' OR @compressed_gas = 'T'
BEGIN 
	SET @isAttach_CL = 'T'
	SET @IsCylinderAttached = @enabled
END

insert #results (profile_id, approval_desc,generator_id, generator_name, epa_id, generator_type, 
customer_id, cust_name, curr_status_code, ap_expiration_date,prices,date_modified, copy_source, display_status,image_id
,generator_addr_1, generator_city, generator_state, generator_country, generator_zip_code, generator_phone
,gen_mail_addr1, gen_mail_city, gen_mail_state, gen_mail_country, gen_mail_zip, SA,SB,SC,SD,SE,SF,SG,SH,LR,ID,PL,PB,UL,WI,CN,TL,BZ,CR,RA,DS,
IsLDRAttached, IsIllinoisAttached, IsPharmaAttached, IsPCBAttached,IsUsedOilAttached, IsWasteImportAttached, 
IsCertificationAttached, IsThermalAttached, IsBenzeneAttached,
IsCylinderAttached,IsRadioActiveAttached,IsDebrisAttached)
SELECT
        p.profile_id,
		p.approval_desc,
		p.generator_id,
		gn.generator_name,
		gn.epa_id,
		gt.generator_type,
		p.customer_id,
		cn.cust_name,
		p.curr_status_code,
		p.ap_expiration_date,
		case when b.prices = 'T' then 1 else 0 end as prices,		
		p.date_modified,
		null as copy_source,
		case when p.ap_expiration_date > getdate()+30 then 
					'Approved'
				else
					case when p.ap_expiration_date > getdate() then
						'For Renewal'
					else
						'Expired'
					end
				end,				
		@image_id,
		gn.generator_address_1, 
		gn.generator_city, 
		gn.generator_state, 
		gn.generator_country, 
		gn.generator_zip_code,
		gn.generator_phone,
		gn.gen_mail_addr1,
		gn.gen_mail_city,
		gn.gen_mail_state,
		gn.gen_mail_country,
		gn.gen_mail_zip_code,
                 'Y',--sectionA

                'Y' ,--sectionB

                'Y' ,--sectionC

                'Y' ,--sectionD
 
                'Y' ,--sectionE
 
                'Y' ,--sectionF

                'Y' ,--sectionG

                'Y' ,--sectionH

                'Y' ,--LDR Attachment

                'Y' ,--illonisdisposal
				'Y' ,--PHARMA

                'Y' ,--PCB

                'Y',--Used Oil

                'Y',--wasteinport

                'Y',--certification

                'Y',--thermal

                'Y',--Beneze

				'Y',--CR

                'Y',--RADIO    
				'Y',--DEBRIS
				case when @IsLDRAttached = 'Y' then 1 else 0 end IsLDRAttached, -- LDR Attached or not
				case when @IsIllinoisAttached = 'Y' then 1 else 0 end IsIllinoisAttached , -- Illinois Attached or not	
				case when @IsPharmaAttached = 'Y' then 1 else 0 end IsPharmaAttached ,  -- Pharmaceutical Attached or not
				case when @IsPCBAttached = 'Y' then 1 else 0 end IsPCBAttached ,  -- Pharmaceutical Attached or not		
				case when @IsUsedOilAttached = 'Y' then 1 else 0 end IsUsedOilAttached ,-- Used Oil Attached or not			
				case when @IsWasteImportAttached = 'Y' then 1 else 0 end IsWasteImportAttached, -- Waste Import Attached or not				 	
				case when @IsCertificationAttached = 'Y' then 1 else 0 end IsCertificationAttached, -- Certification Attached or not					 
				case when @IsThermalAttached = 'Y' then 1 else 0 end IsThermalAttached,  -- Thermal Attached or not
				case when @IsBenzeneAttached = 'Y' then 1 else 0 end IsBenzeneAttached, -- Benzene Attached or not			
				case when @IsCylinderAttached = 'Y' then 1 else 0 end IsCylinderAttached, -- Cylinder Attached or not	
				case when @IsRadioActiveAttached = 'Y' then 1 else 0 end IsRadioActiveAttached, -- RadioActive Attached or not	 
				case when @IsDebrisAttached = 'Y' then 1 else 0 end IsDebrisAttached -- Debris Attached or not																                
                from ContactCORProfileBucket b
				join CORContact c on b.contact_id = c.contact_id
				and c.web_userid = @web_userid
				join [Profile] p on b.profile_id = p.profile_id		
				join Customer cn on p.customer_id = cn.customer_id
				join Generator gn on p.generator_id = gn.generator_id
				left join generatortype gt on gn.generator_type_id = gt.generator_type_id
				WHERE c.web_userid = @web_userid and p.profile_id=@profile_id

				-- select top 1 status from Generator 
				-- select top 1 status from profile

            -- select top 1 * from contact

-- SELECT *, (select COUNT(*) from #results) as _total_results from #results

SELECT (
Select r.*,
(select 
 (select * from 
					(SELECT        
						  ISNULL( DocumentAttachment.document_source,'') AS document_source,
						  ISNULL( DocumentAttachment.file_type,'') AS document_type,						
						  ISNULL( DocumentAttachment.document_name,'') as document_name,	
						  '' AS [db_name],
						  isnull( sdt.document_type, '') as scan_document_type,
						  ISNULL( DocumentAttachment.form_id,'') AS form_id,
						  ISNULL( DocumentAttachment.revision_id,'') AS revision_id,
						  ISNULL( DocumentAttachment.profile_id,'') AS profile_id,
						  ISNULL((select comments.comment from plt_image..scancomment comments WHERE comments.image_id=DocumentAttachment.image_id), '') AS comment,
						  ISNULL( DocumentAttachment.added_by,'') AS added_by,
						  ISNULL( DocumentAttachment.date_added,'') AS date_created,
						  ISNULL( DocumentAttachment.modified_by,'') AS modified_by,
						  ISNULL( DocumentAttachment.date_modified,'') AS date_modified,
						  ISNULL( DocumentAttachment.image_id,'') AS document_id		
				FROM plt_image..Scan (nolock) DocumentAttachment
				join plt_image..ScanDocumentType sdt on sdt.[type_id] = DocumentAttachment.[type_id] and sdt.view_on_web = 'T'
				WHERE 
					  DocumentAttachment.profile_id = @profile_id
					  and DocumentAttachment.view_on_web = 'T'
					  and DocumentAttachment.status = 'A') attachment

				FOR XML RAW ('DocumentAttachment'),TYPE,ROOT ('DocumentAttachment'), ELEMENTS)) from #results r
				FOR XML RAW (''),TYPE, ELEMENTS)
				FOR XML RAW (''), ROOT ('Profile'), ELEMENTS


--ORDER BY i_d

DROP TABLE #results

END


GO

	GRANT EXECUTE ON [dbo].[sp_Approved_ProfileDetail]  TO COR_USER;

GO

 

