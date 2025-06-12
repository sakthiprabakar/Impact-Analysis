USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_COR_Profile_Detail]
GO
CREATE PROCEDURE [dbo].[sp_COR_Profile_Detail]
	-- Add the parameters for the stored procedure here
		@web_userid VARCHAR(100),
		@profile_id INT,
		@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
		@generator_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
AS

/*
--EXEC [sp_COR_Profile_Detail] 1, 70,69286,1023
  Author       : Vinoth D
  Created date : 16/03/2023
  Decription   : Details for Approved Profile

		Get Profile Information such AS Generator name, Waste Name  and Available Supplements for the given profileId

07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

  Input 
   web userid
   profile id

  Output 
   Approved profile details

  Sample 

   EXEC [plt_ai].[dbo].[sp_COR_Profile_Detail]  'manand84' , 607235 
   EXEC [sp_COR_Profile_Detail] 'manand84',343474

    Updated By		: Sathiyamoorthi
	Updated On		: 11th Dec 2023
	Type			: Stored Procedure
	Ticket			: 75272

*/
BEGIN


	DECLARE @type_id INT = (SELECT top 1 type_id FROM plt_image..scandocumenttype WHERE document_type = 'COR Signed Document' ) 
	DECLARE @image_id INT = (SELECT top 1 image_id 
							FROM plt_image..scan s 
							JOIN plt_image..scandocumenttype t ON s.type_id = t.type_id AND t.view_on_web = 'T'
							WHERE profile_id = @profile_id AND (@type_id = s.type_id OR document_source = 'APPRRECERT') 
							AND s.view_on_web = 'T' AND s.status = 'A' ORDER BY date_added desc)

	DECLARE @contact_id INT = (SELECT TOP 1 contact_id FROM contact WHERE web_userid = @web_userid)

	DECLARE @WasteCode_table TABLE (
		profile_id INT NOT NULL,
		state_waste_codes  NVARCHAR(MAX)  NULL,
		pa_waste_codes NVARCHAR(MAX)  NULL,
		rcra_waste_codes NVARCHAR(MAX)  NULL,
		tx_waste_codes NVARCHAR(MAX)  NULL
		);

	;WITH profileWasteCodeCTE AS  
		(  
		SELECT p.profile_id,p.waste_code_uid,display_name waste_code,haz_flag,[status],
			P.waste_code WasteCode,waste_type_code,P.Texas_primary_flag,[state],waste_code_origin
			FROM dbo.WasteCode WasteCodes  
			JOIN profilewastecode P ON P.waste_code_uid=WasteCodes.waste_code_uid
			WHERE P.profile_id=@profile_id
		
		)  
 INSERT INTO @WasteCode_table 
 SELECT  E.profile_id,	STUFF(( SELECT ','+[state]+'-'+RTrim(LTrim(waste_code)) FROM profileWasteCodeCTE EE
									WHERE  EE.profile_id=E.profile_id  AND [status] = 'A'  AND WasteCode <> 'NONE'
										AND waste_code_origin = 'S'  AND [state] <> 'TX' AND [state] <> 'PA'
										ORDER BY [state],RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS state_waste_codes,

									STUFF(( SELECT ','+waste_code FROM profileWasteCodeCTE EE
									WHERE  EE.profile_id=E.profile_id  AND [status] = 'A'  AND waste_code_origin = 'S' AND [state] = 'PA'
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS pa_waste_codes,

									STUFF(( SELECT ','+waste_code FROM profileWasteCodeCTE EE
									WHERE  EE.profile_id=E.profile_id AND [status] = 'A' AND WasteCode <> 'NONE' 
									AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C')
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS rcra_waste_codes,

									STUFF(( SELECT TOP 1 ','+waste_code FROM profileWasteCodeCTE EE
									WHERE  EE.profile_id=E.profile_id  AND  [status] = 'A' AND WasteCode <> 'NONE' 
									and Texas_primary_flag = 'T' AND [status] = 'A' AND [state] = 'TX'
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS tx_waste_codes

							FROM profileWasteCodeCTE E
							GROUP BY E.profile_id

	CREATE TABLE #results (
				 i_d INT IDENTITY(1,1)
				, profile_id INT
				, approval_desc VARCHAR(50)
				, can_Amend_Renew CHAR(1)
				, doc_status_reason VARCHAR (255)
				, under_review		char(1)
				, generator_id INT, generator_name VARCHAR(75), epa_id VARCHAR(12),generator_type VARCHAR(20)
				, generator_addr_1 NVARCHAR(200), generator_city  NVARCHAR(30), generator_state  NVARCHAR(20)
				, generator_country  NVARCHAR(15), generator_zip_code  NVARCHAR(15), generator_phone  NVARCHAR(15)
				, gen_mail_addr1 NVARCHAR(200), gen_mail_city  VARCHAR(40), gen_mail_state  VARCHAR(20)
				, gen_mail_country NVARCHAR(15), gen_mail_zip NVARCHAR(15)
				, customer_id INT, cust_name VARCHAR(75), curr_status_code CHAR(1)
				, ap_expiration_date DATETIME,prices BIT,date_modified DATETIME,display_status VARCHAR(40)
				, copy_source VARCHAR(10),image_id INT
                , sa CHAR(1)
                , sb CHAR(1)
                , sc CHAR(1)
                , sd CHAR(1)
                , se CHAR(1)
                , sf CHAR(1)
                , sg CHAR(1)
                , sh CHAR(1)
                , lr CHAR(1)
                , id CHAR(1)
				, pl CHAR(1)
                , pb CHAR(1)
                , ul CHAR(1)
                , wi CHAR(1)
                , cn CHAR(1)
                , tl CHAR(1)
                , bz CHAR(1)
                , cr CHAR(1)
                , ra CHAR(1)
                , ds CHAR(1)
				, gk CHAR(1)
				, fb CHAR(1)
				, state_waste_codes NVARCHAR(MAX)
				, pa_waste_codes NVARCHAR(MAX)
				, rcra_waste_codes  NVARCHAR(MAX)
				, tx_waste_codes  NVARCHAR(MAX)
				, isLDRAttached  CHAR(1) -- LDR Attached or not
				, isIllinoisAttached  CHAR(1) -- Illinois Attached or not				
				, isPharmaAttached  CHAR(1) -- Pharmaceutical Attached or not
				, isPCBAttached  CHAR(1) -- PCB Attached or not	
				, isUsedOilAttached  CHAR(1) -- Used Oil Attached or not	
				, isWasteImportAttached  CHAR(1) -- Waste Import Attached or not	
				, isCertificationAttached  CHAR(1) -- Certification Attached or not	
				, isThermalAttached  CHAR(1) -- Thermal Attached or not
				, isBenzeneAttached  CHAR(1) -- Benzene Attached or not					
				, isCylinderAttached  CHAR(1) -- Cylinder Attached or not	
				, isRadioActiveAttached  CHAR(1) -- RadioActive Attached or not	
				, isDebrisAttached  CHAR(1)  -- Debris Attached or not)
				, isGeneratorKnowledgeAttached  CHAR(1)  -- Generator knowledge Attached or not)
				, isFuelsBlendingAttached  CHAR(1) -- Fuel Blending Attachment or not

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
	, @isAttach_RA CHAR(1)
	, @isAttach_GK CHAR(1)
	, @isAttach_FB CHAR(1);

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
				, @IsDebrisAttached CHAR(1) -- Debris Attached or not)
				, @IsGeneratorKnowledgeAttached CHAR(1)  -- Debris Attached or not)
				, @IsFuelsBlendingAttached CHAR(1); --Fuel Blending Attached or not


-- SELECT top 1 * FROM profile WHERE generator_id = 37691
-- SELECT top 1 NAICS_code FROM Generator WHERE generator_id = 37691


Set @Generator_id = (SELECT p.generator_id 
						FROM [profile]  p 
						JOIN Generator  g ON   p.generator_id =  g.generator_id 
						WHERE p.profile_id = @profile_id)

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
@specific_technology_requested = specific_technology_requested FROM [Profile] WHERE profile_id = @profile_id

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
		@Generator_Country = generator_Country FROM Generator WHERE generator_id = @Generator_id

  IF  @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType
							WHERE generator_type = 'VSQG/CESQG' ) 
							-- OR @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'VSQG')
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
	 IF (SELECT COUNT(*) 
			FROM ProfileUSEFacility pf 
			WHERE pf.profile_id = @profile_id AND pf.company_id = 26 AND pf.profit_ctr_id=0) > 0
	 BEGIN
		SET @isAttach_ID = 'T'
		SET @IsIllinoisAttached = @enabled
	 END

	 /* Debris */
	
	IF @more_than_50_pct_debris = 'T' AND 
	(SELECT COUNT(*) FROM ProfileUSEFacility pf WHERE 
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
SET @IsThermalAttached = @disabled
IF @thermal_process_flag = 'T'
BEGIN
 SET @isAttach_TL = 'T' 
 SET @IsThermalAttached = @enabled
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

SET @isAttach_GK = 'F'
SET @IsGeneratorKnowledgeAttached = @disabled
DECLARE @gk_option_count INT = 0

SET @gk_option_count = @gk_option_count + (
SELECT COUNT(*)   
FROM ProfileQuoteApproval 
WHERE primary_facility_flag = 'T' AND [status] = 'A' 
AND company_id = 55 AND profit_ctr_id = 0 AND profile_id = @profile_id)

SET @gk_option_count = @gk_option_count + (SELECT COUNT(*) FROM ProfileUSEFacility pf WHERE 
			pf.profile_id = @profile_id AND pf.company_id = 55 AND pf.profit_ctr_id=0)

IF (@gk_option_count > 0)
BEGIN 
	SET @isAttach_GK = 'T'
	SET @IsGeneratorKnowledgeAttached = @enabled
END

--Fuel Blending

SET @isAttach_FB = 'F'
SET @IsFuelsBlendingAttached = @disabled
DECLARE @fb_option_count INT = 0

SET @fb_option_count = @fb_option_count + (
SELECT count(*)   
	 FROM ProfileQuoteApproval 
	 WHERE primary_facility_flag = 'T' AND [status] = 'A' 
	 AND company_id = 73 AND profit_ctr_id=94 AND  profile_id = @profile_id)

SET @fb_option_count = @fb_option_count + (SELECT COUNT(*) FROM ProfileUSEFacility pf WHERE 
			pf.profile_id = @profile_id AND pf.company_id = 73 AND pf.profit_ctr_id=94)

IF (@fb_option_count > 0)
BEGIN 
	SET @isAttach_FB = 'T'
	SET @IsFuelsBlendingAttached = @enabled
END

--Fuel Blending end

INSERT #results (profile_id, approval_desc, can_Amend_Renew,doc_status_reason,under_review, generator_id, generator_name, epa_id, generator_type, 
customer_id, cust_name, curr_status_code, ap_expiration_date,prices,date_modified, copy_source, display_status,image_id
,generator_addr_1, generator_city, generator_state, generator_country, generator_zip_code, generator_phone
,gen_mail_addr1, gen_mail_city, gen_mail_state, gen_mail_country, gen_mail_zip, SA,SB,SC,SD,SE,SF,SG,SH,LR,ID,PL,PB,UL,WI,CN,TL,BZ,CR,RA,DS,GK,FB
,state_waste_codes,pa_waste_codes ,rcra_waste_codes ,tx_waste_codes  ,
isLDRAttached, isIllinoisAttached, isPharmaAttached, isPCBAttached,isUsedOilAttached, isWasteImportAttached, 
isCertificationAttached, isThermalAttached, isBenzeneAttached,
isCylinderAttached,isRadioActiveAttached,isDebrisAttached, isGeneratorKnowledgeAttached,isFuelsBlendingAttached)
SELECT
        p.profile_id,
		p.approval_desc,
		CASE WHEN p.doc_status_reason = 'Data Update' THEN 'F' ELSE 'T' END AS can_Amend_Renew,
		p.doc_status_reason,
		case when	
				(
					p.document_update_status <> 'P'
					OR
					p.document_update_status = 'P' AND p.doc_status_reason in (
						'Rejection in Process', 
						'Amendment in Process', 
						'Renewal in Process',
						'Profile Sync Required',
						'Data Update')
				)
		then 'N' else 'U' end as under_review,
		p.generator_id,
		gn.generator_name,
		gn.epa_id,
		gt.generator_type,
		p.customer_id,
		cn.cust_name,
		p.curr_status_code,
		p.ap_expiration_date,
		CASE WHEN EXISTS(SELECT TOP 1 * 
		FROM  ContactCORProfileBucket b  
		WHERE b.contact_id = @contact_id and b.profile_id = p.profile_id and b.prices = 'T') 
		THEN 1 ELSE 0 END AS prices,		
		p.date_modified,
		NULL AS copy_source,
		CASE WHEN p.ap_expiration_date > GETDATE()+30 THEN 
					'Approved'
				ELSE
					CASE WHEN p.ap_expiration_date > GETDATE() THEN
						'For Renewal'
					ELSE
						'Expired'
					END
				END,				
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
				'Y',-- Generator Knowledge
				'Y',--F
				state_waste_codes,
				pa_waste_codes ,
				rcra_waste_codes,  
				tx_waste_codes  ,
				CASE WHEN @IsLDRAttached = 'Y' THEN '1' else '0' end IsLDRAttached, -- LDR Attached or not
				CASE WHEN @IsIllinoisAttached = 'Y' THEN '1' else '0' end IsIllinoisAttached , -- Illinois Attached or not	
				CASE WHEN @IsPharmaAttached = 'Y' THEN '1' else '0' end IsPharmaAttached ,  -- Pharmaceutical Attached or not
				CASE WHEN @IsPCBAttached = 'Y' THEN '1' else '0' end IsPCBAttached ,  -- Pharmaceutical Attached or not		
				CASE WHEN @IsUsedOilAttached = 'Y' THEN '1' else '0' end IsUsedOilAttached ,-- Used Oil Attached or not			
				CASE WHEN @IsWasteImportAttached = 'Y' THEN '1' else '0' end IsWasteImportAttached, -- Waste Import Attached or not				 	
				CASE WHEN @IsCertificationAttached = 'Y' THEN '1' else '0' end IsCertificationAttached, -- Certification Attached or not					 
				CASE WHEN @IsThermalAttached = 'Y' THEN '1' else '0' end IsThermalAttached,  -- Thermal Attached or not
				CASE WHEN @IsBenzeneAttached = 'Y' THEN '1' else '0' end IsBenzeneAttached, -- Benzene Attached or not			
				CASE WHEN @IsCylinderAttached = 'Y' THEN '1' else '0' end IsCylinderAttached, -- Cylinder Attached or not	
				CASE WHEN @IsRadioActiveAttached = 'Y' THEN '1' else '0' end IsRadioActiveAttached, -- RadioActive Attached or not	 
				CASE WHEN @IsDebrisAttached = 'Y' THEN '1' else '0' end IsDebrisAttached, -- Debris Attached or not		
				CASE WHEN @IsGeneratorKnowledgeAttached = 'Y' THEN '1' else '0' end IsGeneratorKnowledgeAttached, -- Geneator Knowledge Attached or not
				CASE WHEN @IsFuelsBlendingAttached = 'Y' THEN '1' else '0' end isFuelsBlendingAttached --Fuel Blending Attached or not
				FROM [Profile] p	
				JOIN Customer cn ON p.customer_id = cn.customer_id
				JOIN Generator gn ON p.generator_id = gn.generator_id
				LEFT JOIN generatortype gt ON gn.generator_type_id = gt.generator_type_id
				LEFT JOIN @WasteCode_table D ON D.profile_id=P.profile_id	
				WHERE 
				p.profile_id=@profile_id

SELECT (
	SELECT r.*,
		(SELECT 
			(SELECT * FROM 
				(SELECT        
						ISNULL( DocumentAttachment.document_source,'') AS document_source,
						ISNULL( DocumentAttachment.file_type,'') AS document_type,						
						ISNULL( DocumentAttachment.document_name,'') AS document_name,	
						'' AS [db_name],
						ISNULL( sdt.document_type, '') AS scan_document_type,
						ISNULL( DocumentAttachment.form_id,'') AS form_id,
						ISNULL( DocumentAttachment.revision_id,'') AS revision_id,
						ISNULL( DocumentAttachment.profile_id,'') AS profile_id,
						ISNULL((SELECT comments.comment 
								FROM plt_image..scancomment comments 
								WHERE comments.image_id=DocumentAttachment.image_id), '') AS comment,
						ISNULL( DocumentAttachment.added_by,'') AS added_by,
						ISNULL( DocumentAttachment.date_added,'') AS date_created,
						ISNULL( DocumentAttachment.modified_by,'') AS modified_by,
						ISNULL( DocumentAttachment.date_modified,'') AS date_modified,
						ISNULL((SELECT TOP 1 DATALENGTH(image_blob) 
									FROM plt_image..scanimage scanimage 
									WHERE scanimage.image_id=DocumentAttachment.image_id),'') AS document_size,
						ISNULL( DocumentAttachment.image_id,'') AS document_id		
									FROM plt_image..Scan (nolock) DocumentAttachment
									JOIN plt_image..ScanDocumentType sdt ON sdt.[type_id] = DocumentAttachment.[type_id] and sdt.view_on_web = 'T'
									WHERE 
									DocumentAttachment.profile_id = @profile_id
									and DocumentAttachment.view_on_web = 'T'
									and DocumentAttachment.status = 'A') attachment

				FOR XML RAW ('DocumentAttachment'),TYPE,ROOT ('DocumentAttachment'), ELEMENTS)) FROM #results r
				FOR XML RAW (''),TYPE, ELEMENTS)
				FOR XML RAW (''), ROOT ('Profile'), ELEMENTS

DROP TABLE #results

END
GO
GRANT EXECUTE ON [dbo].[sp_COR_Profile_Detail] TO COR_USER;
GO
