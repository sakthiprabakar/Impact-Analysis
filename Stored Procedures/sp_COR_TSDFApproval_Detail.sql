USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_COR_TSDFApproval_Detail]
GO
CREATE PROCEDURE [dbo].[sp_COR_TSDFApproval_Detail]
	-- Add the parameters for the stored procedure here
		@web_userid VARCHAR(100),
		@profile_id INT,
		@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
		@generator_id_list varchar(max)=''  /* Added 2019-07-19 by AA */
AS

/*

	COPY & MODIFY of sp_COR_profile_Detail

		  Author       : Vinoth D
		  Created date : 16/03/2023
		  Decription   : Details for Approved Profile

  Input 
   web userid
   profile id (tsdf_approval_id)

  Output 
   Approved TSDFApproval details

   EXEC [plt_ai].[dbo].[sp_COR_TSDFApproval_Detail]  'manand84' , 104747

-- test with this one:
   EXEC [plt_ai].[dbo].[sp_COR_TSDFApproval_Detail]  'all_customers' , 71311

SELECT  * FROM    tsdfapproval WHERE tsdf_approval_id = 71311
SELECT  * FROM    contactcorcustomerbucket WHERE customer_id = 1366

Please add the following logic to support viewing of 3rd party 
profiles (TSDF Approvals) to the Approved Profile Forms Page, 
for when a user clicks ON a TSDF Approval in the list and the 
Detail pane is opened, please display the following items for 
a TSDF Approval.

1. In the header area for the Generator, no change
2. Site Address – No change
3. Mailing Address – No change
4. Remove the “Amend Profile” link for TSDF Approvals.
5. ON the link for the Waste Material Profile Form,
	1. if the TSDF Approval has 1 document scanned and attached 
		that is not void and is set AS a document type of “Profile” 
		display the link to this PDF.  Display the date the scan 
		was added to EQAI.
	2. If the TSDF Approval has more than 1 document scanned and 
		attached that is not void and is set AS a document type 
		of “Profile”, show a list of the forms and the date each 
		was added to EQAI. 
	3. If the TSDF Approval has 0 documents scanned and attached 
		that are not void and are set AS a document type of “Profile”, 
		show the statement of “Please contact your US 
		Ecology Representative.”
6. If the user clicks the “Send” link, prompt first to ask 	the user 
	to include all scans or just the most recent profile and THEN 
	use the same send box and send the selected scanned documents 
	FROM the Waste Profile form prior step.
7. For the “Approval Letter” document, display the TSDF Approval 
	Generator Notification document, if one is scanned.  If one is 
	not, THEN indicate that the user should “Please contact your 
	US Ecology representative for assistance retrieving this 
	document.”  
	1. Send will open the box to send the document to the user.
	2. View will open the document in the screen.

8. In the “Approval Codes” section of the screen, make the following adjustments:

	1. For TSDF Approvals:
	   i.   Don’t show the link to the document ON the far left
	  ii.   In the “Approval Code” column, instead of 
			ProfileQuoteApproval.Approval_code, display 
			the TSDFApproval.TSDFapproval_code

	2. For all approvals (TSDF Approvals and Profiles):
		i.  Show the full address block for the TSDF.
				TSDF Name (EPA ID)
				Address
				City, State, Zip Code, Country
        

  Sample 

   EXEC [plt_ai].[dbo].[sp_COR_TSDFApproval_Detail]  'nyswyn100' , 63420

*/
BEGIN


	CREATE TABLE #results (
				 i_d INT IDENTITY(1,1)
				, profile_id INT
				, approval_desc VARCHAR(50)
				, generator_id INT, generator_name VARCHAR(75), epa_id VARCHAR(12),generator_type VARCHAR(20)
				, generator_addr_1 nvarchar(200), generator_city  nvarchar(30), generator_state  nvarchar(20)
				, generator_country  nvarchar(15), generator_zip_code  nvarchar(15), generator_phone  nvarchar(15)
				, gen_mail_addr1 nvarchar(200), gen_mail_city  VARCHAR(40), gen_mail_state  VARCHAR(20)
				, gen_mail_country nvarchar(15), gen_mail_zip nvarchar(15)
				, customer_id INT, cust_name VARCHAR(75), curr_status_code CHAR(1)
				, ap_expiration_date DATETIME,prices BIT,date_modified DATETIME,display_status VARCHAR(40)
				, copy_source VARCHAR(10),image_id INT
				, tsdf_code	varchar(15)
				, tsdf_name	varchar(40)
				, tsdf_epa_id	varchar(15)
				, tsdf_addr1	varchar(40)
				, tsdf_addr2	varchar(40)
				, tsdf_addr3	varchar(40)
				, tsdf_city		varchar(40)
				, tsdf_state	char(2)
				, tsdf_zip_code	varchar(15)
				, tsdf_country_code	varchar(3)
				,state_waste_codes NVARCHAR(MAX)
				,pa_waste_codes NVARCHAR(MAX)
				,rcra_waste_codes  NVARCHAR(MAX)
				,tx_waste_codes  NVARCHAR(MAX)
  
				
)

DECLARE @WasteCode_table TABLE (
	 TSDF_approval_id INT NOT NULL,
		state_waste_codes  NVARCHAR(MAX)  NULL,
		pa_waste_codes NVARCHAR(MAX)  NULL,
		rcra_waste_codes NVARCHAR(MAX)  NULL,
		tx_waste_codes NVARCHAR(MAX)  NULL
);

;with tsdfWasteCodeCTE AS  
   (  
     SELECT p.TSDF_approval_id AS TSDF_approval_id,p.waste_code_uid, display_name waste_code,haz_flag,[status],
			P.waste_code WasteCode,waste_type_code,[state],waste_code_origin
		FROM dbo.WasteCode WasteCodes  
		LEFT JOIN TSDFApprovalWasteCode P ON P.waste_code_uid=WasteCodes.waste_code_uid
		WHERE p.TSDF_approval_id=@profile_id
	
    )  
 INSERT INTO @WasteCode_table 
 SELECT  E.TSDF_approval_id,	STUFF(( SELECT ','+[state]+'-'+RTrim(LTrim(waste_code)) FROM tsdfWasteCodeCTE EE
									WHERE  EE.TSDF_approval_id=E.TSDF_approval_id  AND [status] = 'A'  AND WasteCode <> 'NONE'
										AND waste_code_origin = 'S'  AND [state] <> 'TX' AND [state] <> 'PA'
										ORDER BY [state],RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS state_waste_codes,

									STUFF(( SELECT ','+waste_code FROM tsdfWasteCodeCTE EE
									WHERE  EE.TSDF_approval_id=E.TSDF_approval_id  AND [status] = 'A'  
									AND waste_code_origin = 'S' AND [state] = 'PA'
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS pa_waste_codes,

									STUFF(( SELECT ','+waste_code FROM tsdfWasteCodeCTE EE
									WHERE  EE.TSDF_approval_id=E.TSDF_approval_id AND [status] = 'A' 
									AND WasteCode <> 'NONE' AND waste_code_origin = 'F' AND haz_flag = 'T' 
									AND waste_type_code IN ('L', 'C')
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS rcra_waste_codes,

									STUFF(( SELECT TOP 1 ','+waste_code FROM tsdfWasteCodeCTE EE
									WHERE  EE.TSDF_approval_id=E.TSDF_approval_id  AND  [status] = 'A' 
									AND WasteCode <> 'NONE'  AND [status] = 'A' AND [state] = 'TX'
									ORDER BY RTrim(LTrim(waste_code))
									FOR XML PATH(''), TYPE).value('text()[1]','nvarchar(max)')
									, 1, LEN(','), '') AS tx_waste_codes

							FROM tsdfWasteCodeCTE E
							GROUP BY E.TSDF_approval_id

 
INSERT #results (profile_id, approval_desc,generator_id, generator_name, epa_id, generator_type, 
customer_id, cust_name, curr_status_code, ap_expiration_date,prices,date_modified, copy_source, display_status
,generator_addr_1, generator_city, generator_state, generator_country, generator_zip_code, generator_phone
,gen_mail_addr1, gen_mail_city, gen_mail_state, gen_mail_country, gen_mail_zip
	, tsdf_code	
	, tsdf_name	
	, tsdf_epa_id	
	, tsdf_addr1	
	, tsdf_addr2	
	, tsdf_addr3	
	, tsdf_city		
	, tsdf_state	
	, tsdf_zip_code	
	, tsdf_country_code
	, state_waste_codes
	, pa_waste_codes 
	, rcra_waste_codes 
	, tx_waste_codes  

)
SELECT
        ta.tsdf_approval_id,
		ta.waste_desc,
		gn.generator_id,
		gn.generator_name,
		gn.epa_id,
		gt.generator_type,
		cn.customer_id,
		cn.cust_name,
		ta.TSDF_approval_status,
		ta.TSDF_approval_expire_date,
		0 AS prices,		
		ta.date_modified,
		null AS copy_source,
		CASE WHEN ta.TSDF_approval_expire_date > getdate() THEN 
					'Approved'
				ELSE
						'Expired'
				END,				
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
		gn.gen_mail_zip_code

		, tsdf.tsdf_code	
		, tsdf.tsdf_name	
		, tsdf.tsdf_epa_id	
		, tsdf.tsdf_addr1	
		, tsdf.tsdf_addr2	
		, tsdf.tsdf_addr3	
		, tsdf.tsdf_city		
		, tsdf.tsdf_state	
		, tsdf.tsdf_zip_code	
		, tsdf.tsdf_country_code
		, state_waste_codes
		, pa_waste_codes 
		, rcra_waste_codes 
		, tx_waste_codes

		FROM tsdfapproval ta  (NOLOCK)
		JOIN tsdf (NOLOCK)
			on ta.tsdf_code = tsdf.tsdf_code
			AND tsdf.tsdf_status = 'A'
			AND ISNULL(tsdf.eq_flag, 'F') = 'F'
		JOIN Customer cn ON ta.customer_id = cn.customer_id
		JOIN Generator gn ON ta.generator_id = gn.generator_id
		left JOIN generatortype gt ON gn.generator_type_id = gt.generator_type_id
		LEFT JOIN @WasteCode_table D ON D.TSDF_approval_id=TA.TSDF_approval_id
		WHERE ta.tsdf_approval_id = @profile_id


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
				FROM plt_image..Scan (NOLOCK) DocumentAttachment
				JOIN plt_image..ScanDocumentType sdt ON sdt.[type_id] = DocumentAttachment.[type_id] 
				AND sdt.view_on_web = 'T'
				WHERE 
					  DocumentAttachment.tsdf_approval_id = @profile_id
					  AND DocumentAttachment.view_on_web = 'T'
					  AND sdt.document_type in ('Profile','Generator Notification','WCR') --Profile,WCR ->  
					  --Waste/Material Profile Form document, Generator Notification -> approval letter document
					  AND DocumentAttachment.status = 'A') attachment

				FOR XML RAW ('DocumentAttachment'),TYPE,ROOT ('DocumentAttachment'), ELEMENTS)) FROM #results r
				FOR XML RAW (''),TYPE, ELEMENTS)
				FOR XML RAW (''), ROOT ('Profile'), ELEMENTS


--ORDER BY i_d

DROP TABLE #results

END

GO
GRANT EXECUTE ON [dbo].[sp_COR_TSDFApproval_Detail] TO COR_USER;
GO