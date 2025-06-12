USE [PLT_AI]
GO



DROP PROCEDURE IF EXISTS [dbo].[sp_formWCR_Detail] 
GO 

CREATE PROCEDURE [dbo].[sp_formWCR_Detail]
                @web_userid VARCHAR(100),
                @revision_id INT ,
                @form_id INT

AS


/* ******************************************************************

	Updated By		: Pasupathi P
	Updated On		: 1st JUL 2024
	Type			: Stored Procedure
	Object Name		: [sp_formWCR_Detail]


   Updated the template_formId in this sp_formWCR_Detail for Requirement 89274: Profile Template > UI Functionality & API Integration

Samples:
 EXEC [sp_formWCR_Detail] @web_userid,@form_id,@revision_ID
 EXEC [sp_formWCR_Detail] 'manand84',1,562568 
 EXEC [sp_formWCR_Detail] 'myaklin',612751,1
 EXEC [sp_formWCR_Detail] 'myaklin',1,612751

****************************************************************** */    

           
		   
BEGIN

DECLARE @IsSubmitDocument_Available INT = (SELECT Count(1) 
											FROM plt_image..Scan (nolock) 
											WHERE form_id = @form_id AND revision_id = @revision_id 
											AND (document_source ='cordoc' OR document_source = 'APPRFORM'))

DECLARE @SendSubmitEmailAddress nvarchar(500)='N/A';

IF EXISTS (SELECT * FROM FormWCR WHERE form_id=@form_id and revision_id=@revision_ID and display_status_uid in 
				(SELECT display_status_uid FROM FormDisplaystatus WHERE display_status='Pending Signature'))
BEGIN

SET	@SendSubmitEmailAddress = (SELECT TOP 1 recipient_email 
								FROM FormSignatureQueue 
								WHERE status='sent' and form_id=@form_id  and revision_id=@revision_id ORDER BY date_sent DESC)
END

DECLARE @IncludeCESQGDocument CHAR(1) = (SELECT vsqg_cesqg_accept_flag 
											FROM FormVSQGCESQG 
											WHERE wcr_id = @form_id and wcr_rev_id = @revision_id)

-- pre grab form's profile_id:
DECLARE @form_profile_id int
SELECT top 1 @form_profile_id = profile_id
FROM plt_ai..formwcr 
WHERE form_id = @form_id and revision_id = @revision_id

CREATE TABLE #WasteCode_table (
    Form_id INT NOT NULL,
    state_waste_codes VARCHAR(1000) NULL,
    pa_waste_codes VARCHAR(1000) NULL,
    rcra_waste_codes VARCHAR(1000) NULL,
    tx_waste_codes VARCHAR(1000) NULL
);

;with formWasteCodeCTE AS  
   (  
     SELECT p.Form_id,p.waste_code_uid, display_name waste_code,haz_flag,[status],P.waste_code WasteCode,waste_type_code,
	 [state],waste_code_origin
		FROM dbo.WasteCode WasteCodes  
		LEFT JOIN FormXWasteCode P ON P.waste_code_uid=WasteCodes.waste_code_uid
		WHERE p.Form_id=@form_id and p.revision_id=@revision_id
	
    )  
 INSERT INTO #WasteCode_table (Form_id, state_waste_codes, pa_waste_codes, rcra_waste_codes, tx_waste_codes)
 SELECT  E.Form_id,	STUFF(( SELECT ','+[state]+'-'+RTrim(LTrim(waste_code)) FROM formWasteCodeCTE EE
									WHERE  EE.Form_id=E.Form_id  AND [status] = 'A'  AND WasteCode <> 'NONE'
										AND waste_code_origin = 'S'  AND [state] <> 'TX' AND [state] <> 'PA'
										ORDER BY [state],RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(4000)')
									, 1, LEN(','), '') AS state_waste_codes,

									STUFF(( SELECT ','+waste_code FROM formWasteCodeCTE EE
									WHERE  EE.Form_id=E.Form_id  AND [status] = 'A'  AND waste_code_origin = 'S' AND [state] = 'PA'
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(4000)')
									, 1, LEN(','), '') AS pa_waste_codes,

									STUFF(( SELECT ','+waste_code FROM formWasteCodeCTE EE
									WHERE  EE.Form_id=E.Form_id AND [status] = 'A' AND WasteCode <> 'NONE' 
									AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C')
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(4000)')
									, 1, LEN(','), '') AS rcra_waste_codes,

									STUFF(( SELECT TOP 1 ','+waste_code FROM formWasteCodeCTE EE
									WHERE  EE.Form_id=E.Form_id  AND  [status] = 'A' AND WasteCode <> 'NONE'  
									AND [status] = 'A' AND [state] = 'TX'
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(4000)')
									, 1, LEN(','), '') AS tx_waste_codes

							FROM formWasteCodeCTE E
							GROUP BY E.Form_id

CREATE TABLE #results (
                i_d INT IDENTITY(1,1), form_id INT, revision_id INT, waste_common_name VARCHAR(50), generator_id INT, generator_name VARCHAR(75)
				, epa_id VARCHAR(12), generator_type_id INT, generator_type VARCHAR(15), customer_id INT, cust_name VARCHAR(75)
				, curr_status_code CHAR(1), ap_expiration_date DATETIME,date_modified DATETIME,display_status VARCHAR(40), copy_source VARCHAR(10)
				, SendSubmitEmailAddress nvarchar(500), IncludeCESQGDocument CHAR(1), profile_id int, sa CHAR(1), sb CHAR(1), sc CHAR(1), sd CHAR(1)
                , se CHAR(1), sf CHAR(1), sg CHAR(1), sh CHAR(1), sl CHAR(1), [at] CHAR(1), lr CHAR(1), id CHAR(1), pl CHAR(1), pb CHAR(1), ul CHAR(1)
                , wi CHAR(1), cn CHAR(1), tl CHAR(1), bz CHAR(1), cr CHAR(1), ra CHAR(1), ds CHAR(1), gl CHAR(1), gk CHAR(1), fb CHAR(1)
				, state_waste_codes VARCHAR(4000), rcra_waste_codes VARCHAR(4000), pa_waste_codes VARCHAR(4000), tx_waste_codes VARCHAR(4000)
				, isLDRAttached BIT -- LDR Attached or not
				, isIllinoisAttached BIT -- Illinois Attached or not				
				, isPharmaAttached BIT -- Pharmaceutical Attached or not
				, isPCBAttached BIT -- PCB Attached or not	
				, isUsedOilAttached BIT -- Used Oil Attached or not	
				, isWasteImportAttached BIT -- Waste Import Attached or not	
				, isCertificationAttached BIT -- Certification Attached or not	
				, isThermalAttached BIT -- Thermal Attached or not
				, isBenzeneAttached BIT -- Benzene Attached or not					
				, isCylinderAttached BIT -- Cylinder Attached or not	
				, isRadioActiveAttached BIT -- RadioActive Attached or not	
				, isDebrisAttached BIT  -- Debris Attached or not)
				, isGeneratorLocationAttached BIT  -- Generator location Attached or not)
				, isGeneratorKnowledgeAttached BIT
				, comments VARCHAR(4000)
				, generator_addr_1 nvarchar(200), generator_city  nvarchar(30), generator_state  nvarchar(20)
				, generator_country  nvarchar(15), generator_zip_code  nvarchar(15), generator_phone  nvarchar(15)
				, gen_mail_addr1 nvarchar(200), gen_mail_city  VARCHAR(40), gen_mail_state  VARCHAR(20)
				, gen_mail_country nvarchar(15), gen_mail_zip nvarchar(15)
				, IsSubmitDocument_Available INT
				, envelope_id nvarchar(100)
				, envelope_datesent datetime
				, isFuelsBlendingAttached BIT -- FuelBlending Attached or not
				, template_formId INT
				)


SELECT * INTO #SectionStatus FROM FormSectionStatus WHERE form_id = @form_id AND revision_id = @revision_id AND isActive=1
 

INSERT #results (form_id, revision_id,waste_common_name, generator_id, generator_name, epa_id,generator_type_id, generator_type
, customer_id, cust_name, curr_status_code, ap_expiration_date,date_modified, display_status, copy_source,SendSubmitEmailAddress
, IncludeCESQGDocument,profile_id,SA,SB,SC,SD,SE,SF,SG,SH,SL,[AT],LR,ID,PL,PB,UL,WI,CN,TL,BZ,CR,RA,DS,GL,GK,FB,state_waste_codes,rcra_waste_codes
, pa_waste_codes,tx_waste_codes,isLDRAttached, isIllinoisAttached, isPharmaAttached, isPCBAttached,isUsedOilAttached, isWasteImportAttached
, isCertificationAttached, isThermalAttached, isBenzeneAttached,isCylinderAttached,isRadioActiveAttached,isDebrisAttached
, isGeneratorLocationAttached,isGeneratorKnowledgeAttached, comments, generator_addr_1, generator_city, generator_state
, generator_country, generator_zip_code, generator_phone, gen_mail_addr1, gen_mail_city, gen_mail_state, gen_mail_country
, gen_mail_zip, IsSubmitDocument_Available, envelope_id, envelope_datesent, isFuelsBlendingAttached, template_formId)


SELECT ISNULL(f.form_id,''), ISNULL(f.revision_id,''), ISNULL(f.waste_common_name,''), ISNULL(f.generator_id,'')
				, ISNULL(coalesce(gn.generator_name, f.generator_name),'') generator_name, ISNULL(coalesce(gn.epa_id, f.epa_id),'') epa_id, ISNULL(f.generator_type_id,'')
				, ISNULL((SELECT TOP 1 g.generator_type FROM GeneratorType g WHERE g.generator_type_id =  f.generator_type_id),'') AS generator_type, ISNULL(f.customer_id,'')
				, ISNULL(coalesce(cn.cust_name, f.cust_name),'') cust_name, ISNULL(f.status,''), ISNULL(null,'') ap_expiration_date, ISNULL(f.date_modified,'')
				, ISNULL(f.display_status_uid,''), ISNULL(f.copy_source,''), ISNULL(@SendSubmitEmailAddress,''), ISNULL(@IncludeCESQGDocument,''),ISNULL(f.profile_id,'')
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SA') --sectionA
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SB') --sectionB
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SC') --sectionC
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SD') --sectionD
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SE') --sectionE
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SF') --sectionF
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SG') --sectionG
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SH') --sectionH
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='SL') -- Facility
				, (SELECT ISNULL(section_status,'') FROM #SectionStatus WHERE section='DA') --DocumentAttachment
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE section='LR'),'') --LDR Attachment
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='ID'),'')--illonisdisposal
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='PL'),'') --PHARMA
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='PB'),'') --PCB
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='UL'),'') --Used Oil
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='WI'),'') --wasteinport
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='CN'),'') --certification
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='TL'),'') --thermal
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='BZ'),'') --Beneze
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='CR'),'') --CR
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='RA'),'') --RADIO
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='DS'),'') --DEBRIS
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE  section='GL'),'') --Generator Location
				, ISNULL((SELECT section_status	FROM #SectionStatus WHERE  section='GK'),'') --Generator Knowledge
				, ISNULL((SELECT section_status FROM #SectionStatus WHERE section='FB'),'')  --Fuel Blending
				, fw.state_waste_codes , fw.rcra_waste_codes, fw.pa_waste_codes , fw.tx_waste_codes 
				,ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'LR'),'') AS isLDRAttached, -- LDR Attached or not
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'ID'),'')  AS isIllinoisAttached, -- Illinois Attached or not				
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'PL'),'')  AS isPharmaAttached, -- Pharmaceutical Attached or not
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'PB'),'')  AS isPCBAttached, -- PCB Attached or not	
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'UL'),'')  AS isUsedOilAttached, -- Used Oil Attached or not	
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'WI'),'')  AS isWasteImportAttached, -- Waste Import Attached or not	
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'CN'),'')  AS isCertificationAttached, -- Certification Attached or not	
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'TL'),'')  AS isThermalAttached, -- Thermal Attached or not
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'BZ'),'')  AS isBenzeneAttached, -- Benzene Attached or not					
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'CR'),'')  AS isCylinderAttached, -- Cylinder Attached or not	
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'RA'),'')  AS isRadioActiveAttached, -- RadioActive Attached or not	
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'DS'),'')  AS isDebrisAttached, -- Debris Attached or not)
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'GL'),'')  AS isGeneratorLocationAttached,  -- GeneratorLocation Attached or not)
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'GK'),'')  AS isGeneratorKnowledgeAttached,  -- Generator Knowledge Attached or not)
				ISNULL(rejectionComment.Comment,'') AS comments,
				ISNULL(gn.generator_address_1,'') AS  generator_address_1,
				ISNULL(gn.generator_city,'') AS  generator_city,
				ISNULL(gn.generator_state,'') AS  generator_state, 
				ISNULL(gn.generator_country,'') AS  generator_country, 
				ISNULL(gn.generator_zip_code,'') AS generator_zip_code,
				ISNULL(gn.generator_phone,'') AS generator_phone,
				ISNULL(gn.gen_mail_addr1,'') AS gen_mail_addr1,
				ISNULL(gn.gen_mail_city,'') AS gen_mail_city,
				ISNULL(gn.gen_mail_state,'') AS gen_mail_state,
				ISNULL(gn.gen_mail_country,'') AS gen_mail_country,
				ISNULL(gn.gen_mail_zip_code,'') AS gen_mail_zip_code,
				@IsSubmitDocument_Available,
				CASE WHEN f.display_status_uid = 8 THEN (SELECT TOP 1 e_signature_envelope_id 
				FROM formsignaturequeue 
				WHERE form_id = f.form_id and revision_id = f.revision_id and [status] = 'sent' ORDER BY date_sent DESC) 
				ELSE '' END envelope_id,	
				CASE WHEN f.display_status_uid = 8 THEN (SELECT TOP 1 date_sent 
															FROM formsignaturequeue 
															WHERE form_id = f.form_id AND revision_id = f.revision_id 
															AND [status] = 'sent' ORDER BY date_sent DESC) 
				ELSE null END envelope_datesent	,
				ISNULL((SELECT isActive FROM #SectionStatus WHERE section = 'FB'),'')  AS isFuelsBlendingAttached, -- Fuel Blending Attached or not
				ISNULL(f.template_form_id,'') AS template_formId
                FROM
                [Plt_AI]..ContactCORFormWCRBucket b
                 LEFT JOIN [Plt_AI]..contact c ON b.contact_id = c.contact_id
				 LEFT JOIN [Plt_AI]..corcontact cr ON b.contact_id = cr.contact_id
				 JOIN [Plt_AI]..FormWCR f ON b.form_id = f.form_id and b.revision_id = f.revision_id
				 LEFT JOIN [Plt_AI]..Customer cn ON f.customer_id = cn.customer_id
                 LEFT JOIN [Plt_AI]..Generator gn ON f.generator_id = gn.generator_id
				 LEFT JOIN #WasteCode_table fw  ON fw.form_id=f.form_id
                 LEFT JOIN [Plt_AI]..generatortype gt ON gn.generator_type_id = gt.generator_type_id
				 OUTER APPLY(SELECT  TOP 1 Comment 
							FROM formnote fn 
							WHERE  fn.status = 'R' AND fn.type = 'EMAIL' 
							AND f.form_id=fn.form_id AND f.revision_id=fn.revision_id ORDER BY date_added DESC) rejectionComment
                WHERE (c.web_userid = @web_userid OR cr.web_userid = @web_userid) AND f.form_id=@form_id AND f.revision_id=@revision_id;
      
-- Get Form Audit detail                                       
WITH CTE_FormWCRStatusAudit AS
(
  SELECT *, NextStatus  = LEAD(date_added) OVER (PARTITION BY form_id,revision_id ORDER BY FormWCRStatusAudit_uid)
  FROM FormWCRStatusAudit WHERE  form_id=@form_id and revision_id=1
)
(SELECT * into #tempDisplayStatus FROM (SELECT 
	(SELECT  display_status FROM  FormDisplayStatus WHERE display_status_uid=cte.display_status_uid) display_status,
	SUM(DATEDIFF(DAY, date_added, ISNULL(NextStatus,GETDATE()))) [Difference]
  FROM CTE_FormWCRStatusAudit cte
   GROUP BY cte.display_status_uid
   ) AS SourceTable PIVOT(AVG([Difference]) FOR [display_status] IN([Draft],
                                                         [Submitted],
                                                         [Rejected]
                                                         )) AS PivotTable)

SELECT (
													 
SELECT r.*, ISNULL(t.[Draft],'') [draft],ISNULL(t.[Submitted],'') [submitted],ISNULL(t. [Rejected],'') [rejected], 
		(SELECT COUNT(*) FROM #results) AS _total_results,
 (SELECT 
 (SELECT * FROM 
 (SELECT  row_number() OVER(PARTITION BY attachment.document_source ORDER BY attachment.date_modified DESC) ro,
		--ISNULL( attachment.document_source,'') AS document_source,
		 CASE WHEN EXISTS(SELECT * 
							FROM plt_image..ScanDocumentType sdt 
							WHERE sdt.type_id = attachment.type_id) 
				THEN (SELECT TOP 1 sdt.type_code 
						FROM plt_image..ScanDocumentType sdt 
						WHERE sdt.type_id = attachment.type_id) ELSE '' END AS document_source,
		  ISNULL(attachment.file_type,'') AS file_type,
		   (SELECT TOP 1 REPLACE(document_type, 'COR ', '') 
				FROM  plt_image..ScanDocumentType sc 
				WHERE (sc.type_code = attachment.document_source) or (sc.type_id = attachment.type_id)) document_type,
		 -- CASE WHEN DocumentAttachment.document_source ='APPRFORM' then
			--'Signed Document V'+convert(nvarchar(10),  row_number() over 
			--(partition by DocumentAttachment.document_source order by  DocumentAttachment.image_id))
		 -- ELSE
			--ISNULL( scType.document_type,'') END document_type,
		  '' AS [db_name],
		  ISNULL( attachment.document_name,'') document_name,
		  --ISNULL( scType.document_type,'') AS document_type,
		 -- ISNULL( attachment.type_code,'') AS type_code,
		  ISNULL( attachment.form_id,'') AS form_id,
		  ISNULL( attachment.revision_id,'') AS revision_id,
		  ISNULL( attachment.added_by,'') AS added_by,
		  ISNULL( attachment.date_added,'') AS date_created,
		  ISNULL( attachment.modified_by,'') AS modified_by,
		  ISNULL( attachment.date_modified,'') AS date_modified,
		  ISNULL((SELECT TOP 1 comment 
					FROM plt_image..scancomment comments 
					WHERE comments.image_id=attachment.image_id),'') AS comment,
		  ISNULL((SELECT TOP 1 DATALENGTH(image_blob) 
					FROM plt_image..scanimage scanimage 
					WHERE scanimage.image_id=attachment.image_id),'') AS document_size,		  
		  ISNULL( attachment.image_id,'') AS document_id
	 FROM plt_image..Scan attachment
	 -- LEFT JOIN plt_image..ScanDocumentType scType ON scType.[type_id]=attachment.[type_id]
	 WHERE 
	  (attachment.form_id = @form_id   AND  attachment.revision_id = @revision_id) 
		OR
		 (
			@form_profile_id IS NOT NULL
			AND profile_id = @form_profile_id
			AND attachment.[type_id] in (SELECT [type_id] FROM Plt_Image..ScanDocumentType WHERE type_code in ('CORSDS','CORLABANAL'))
		 )

	  ) DocumentAttachment
	  WHERE ro=1 OR (ro > 1 AND (document_source NOT LIKE '%cordoc%' and  document_source NOT LIKE '%APPRFORM%'))
	 FOR XML AUTO,TYPE,ROOT ('DocumentAttachments'), ELEMENTS)) FROM #results r--,#tempDisplayStatus

LEFT JOIN #tempDisplayStatus t
    ON 1 =1
ORDER BY i_d
FOR XML RAW (''),TYPE, ELEMENTS)
	 FOR XML RAW (''), ROOT ('FromWCRDetail'), ELEMENTS

DROP TABLE #tempDisplayStatus
END;
GO 

GRANT EXEC ON [dbo].[sp_formWCR_Detail] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_formWCR_Detail]  TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_formWCR_Detail]  TO EQAI 
GO 
