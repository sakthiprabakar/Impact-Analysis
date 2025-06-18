CREATE OR ALTER PROCEDURE dbo.sp_COR_FormWCR_List  
	  @web_userid  VARCHAR(100)
	, @status_list VARCHAR(4000) = 'all'
	, @search   VARCHAR(100) = ''
	, @adv_search  VARCHAR(4000) = ''
	, @generator_size  VARCHAR(75) = ''
	, @generator_name  VARCHAR(75) = ''
	, @generator_site_type VARCHAR(4000) = ''
	, @form_id   VARCHAR(4000) = '' -- Can take a CSV list
	, @waste_common_name VARCHAR(50) = ''
	, @epa_waste_code  VARCHAR(4000) = '' -- Can take a CSV list
	, @copy_status VARCHAR(10) = ''
	, @sort   VARCHAR(20) = 'Modified Date'
	, @page   INTEGER = 1
	, @perpage  INTEGER = 20
	, @excel_output INTEGER = 0 
	, @customer_id_list VARCHAR(4000) = ''  /* Added 2019-07-19 by AA */  
	, @generator_id_list VARCHAR(4000) = ''  /* Added 2019-07-19 by AA */  
	, @owner   VARCHAR(5) = 'all' /* 'mine' or 'all' */  
	, @period    VARCHAR(4) = '' /* WW, MM, QQ, YY, 30 or 60 days */  
	, @tsdf_type   VARCHAR(10) = 'All'  /* 'USE' or 'Non-USE' or 'ALL' */  
	, @haz_filter   VARCHAR(20) = 'All'  /* 'All', 'RCRA', 'Non-RCRA', 'State', 'Non-Reg' */  
AS
/*
	Updated by Blair Christensen for Titan 05/27/2025
*/
BEGIN  
	DECLARE @i_web_userid VARCHAR(100) = ISNULL(@web_userid, '')
		  , @i_status_list  VARCHAR(4000) = ISNULL(@status_list, '')
		  , @i_search    VARCHAR(100) = ISNULL(@search, '')
		  , @i_adv_search   VARCHAR(4000) = ISNULL(@adv_search, '')
		  , @i_generator_size  VARCHAR(75) = ISNULL(@generator_size, '')
		  , @i_generator_name  VARCHAR(75) = ISNULL(@generator_name, '')
		  , @i_generator_site_type  VARCHAR(4000) = ISNULL(@generator_site_type, '')
		  , @i_form_id   VARCHAR(4000) = ISNULL(@form_id, '')
		  , @i_waste_common_name VARCHAR(50) = 
				CASE WHEN ISNULL(@waste_common_name, '') = '' THEN '' 
					 ELSE '%' + REPLACE(ISNULL(@waste_common_name, ''), ' ', '%') + '%'
				 END  
		  , @i_epa_waste_code  VARCHAR(4000) = ISNULL(@epa_waste_code, '')
		  , @i_copy_status  VARCHAR(10) = ISNULL(@copy_status, '')
		  , @i_sort    VARCHAR(20) = ISNULL(@sort, '')
		  , @i_page    INTEGER = ISNULL(@page, 1)
		  , @i_perpage   INTEGER = ISNULL(@perpage, 20)
		  , @i_totalcount  INTEGER
		  , @i_owner    VARCHAR(5) = ISNULL(@owner, 'all')
		  , @i_contact_id  INTEGER
		  , @i_customer_id_list VARCHAR(4000) = ISNULL(@customer_id_list, '')
		  , @i_generator_id_list VARCHAR(4000) = ISNULL(@generator_id_list, '')
		  , @i_email VARCHAR(100)
		  , @i_period    VARCHAR(4) = ISNULL(@period, '')
		  , @i_period_int   INTEGER = 0
		  , @i_period_date  DATETIME
		  , @i_excel_output  INTEGER = ISNULL(@excel_output, 0)
		  , @i_tsdf_type  VARCHAR(10) = ISNULL(@tsdf_type, 'USE')
		  , @i_haz_filter  VARCHAR(20) = ISNULL(@haz_filter, 'All')
		  ;

	-- setup defaults, internals, etc.  
	SELECT TOP 1 @i_contact_id = ISNULL(contact_id, -1)  
	     , @i_email = email
	  FROM dbo.CORcontact
	 WHERE web_userid = @i_web_userid; 
  
	SET @i_period_int = CASE @i_period  
			WHEN 'WW' THEN DATEDIFF(dd, DATEADD(ww, -1, GETDATE()) , GETDATE())  
			WHEN 'QQ' THEN DATEDIFF(dd, DATEADD(qq, -1, GETDATE()) , GETDATE())  
			WHEN 'MM' THEN DATEDIFF(dd, DATEADD(mm, -1, GETDATE()) , GETDATE())  
			WHEN 'YY' THEN DATEDIFF(dd, DATEADD(yyyy, -1, GETDATE()) , GETDATE())  
			WHEN '30' THEN 30  
			WHEN '60' THEN 60  
			ELSE ''  
		END  
  
	SET @i_period_date = CASE @i_period   
			WHEN 'WW' THEN DATEADD(ww, -1, GETDATE())   
			WHEN 'MM' THEN DATEADD(m, -1, GETDATE())   
			WHEN 'QQ' THEN DATEADD(qq, -1, GETDATE())   
			WHEN 'YY' THEN DATEADD(yyyy, -1, GETDATE())   
			WHEN '30' THEN DATEADD(dd, (-1 * @i_period_int), GETDATE())  
			WHEN '60' THEN DATEADD(dd, (-1 * @i_period_int), GETDATE())  
			ELSE '1/1/1801'  
		END  
  
	IF ISNUMERIC(@i_period) = 1
		BEGIN
			SET @i_period_int = CONVERT(INTEGER, @i_period)
		END
  
	IF @i_status_list = 'all'
		BEGIN
			SET @i_status_list = 'Draft,Ready For Submission,Submitted,Pending Customer Response,Pending Signature,CS Created,Accepted,Approved'
		END
   
	IF @i_sort NOT IN ('Generator Name', 'Profile Number', 'Waste Common Name', 'RCRA Status', 'Modified Date')
		BEGIN
			SET @i_sort = ''
		END
  
	CREATE TABLE #statusSet (display_status VARCHAR(60));
	INSERT INTO #statusSet (display_status)
	SELECT row FROM dbo.fn_SplitXsvText(',', 1, @i_status_list) WHERE row IS NOT NULL
	 UNION
	SELECT display_status
	  FROM dbo.FormDisplayStatus
	 WHERE @i_status_list in ('', 'all');
  
	IF EXISTS (SELECT 1 FROM #statusSet WHERE display_status = 'Submitted')
		BEGIN
			INSERT INTO #statusSet (display_status) VALUES ('Approved');
		END

	CREATE TABLE #generatorsize (generator_type VARCHAR(20));
	IF @i_generator_size <> ''
		BEGIN
			INSERT INTO #generatorsize (generator_type)
			SELECT LEFT(row, 20)  
			  FROM dbo.fn_SplitXsvText(',', 1, @i_generator_size);
		END
 
	CREATE TABLE #form_ids (form_id INTEGER);
	IF @i_form_id <> ''
		BEGIN
			INSERT INTO #form_ids (form_id)
			SELECT CONVERT(INTEGER, row)  
			  FROM dbo.fn_SplitXsvText(',', 1, @i_form_id)  
			 WHERE ISNUMERIC(row) = 1  
			   AND row NOT LIKE '%.%';
		END
 
	CREATE table #wastecodes (waste_code VARCHAR(10));
	IF @i_epa_waste_code <> ''
		BEGIN
			INSERT INTO #wastecodes (waste_code)
			SELECT LEFT(row, 10)  
			  FROM dbo.fn_SplitXsvText(',', 1, @i_epa_waste_code)
		END
 
	CREATE table #customer (customer_id INTEGER);
	IF @i_customer_id_list <> ''
		BEGIN
			INSERT INTO #customer (customer_id)
			SELECT CONVERT(INTEGER, row)
			  FROM dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
			 WHERE row IS NOT NULL;
		END
  
	CREATE TABLE #generator (generator_id INTEGER);
	IF @i_generator_id_list <> ''
		BEGIN
			INSERT INTO #generator (generator_id)
			SELECT CONVERT(INTEGER, row)
			  FROM dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
			 WHERE row IS NOT NULL;
		END
  
	CREATE TABLE #generatorsitetype (site_type VARCHAR(40))
	IF @i_generator_site_type <> ''
		BEGIN
			INSERT INTO #generatorsitetype (site_type)
			SELECT LEFT(row, 40)  
			  FROM dbo.fn_SplitXsvText(',', 1, @i_generator_site_type)  
			 WHERE row IS NOT NULL;
		END
  
	CREATE TABLE #period_data (form_id INTEGER  
		 , revision_id INTEGER  
		 , date_added DATETIME  
		 , display_status_uid INTEGER  
		 );
	IF @i_period <> ''
		BEGIN
			INSERT INTO #period_data (form_id, revision_id, date_added, display_status_uid)
			SELECT y.form_id, y.revision_id, y.date_added, y.display_status_uid  
			  FROM dbo.FormWCRStatusAudit y  
				   JOIN (SELECT fa.form_id, fa.revision_id, MAX(fa.FormWCRStatusAudit_uid) as max_uid  
						   FROM dbo.ContactCORFormWCRBucket b
							    JOIN FormWCRStatusAudit fa on b.form_id = fa.form_id
									 AND b.revision_id = fa.revision_id  
						  WHERE b.contact_id = @i_contact_id  
						  GROUP BY fa.form_id, fa.revision_id  
						) x on x.form_id = y.form_id
						AND x.revision_id = y.revision_id
						AND x.max_uid = y.FormWCRStatusAudit_uid  
			 WHERE y.date_added >= @i_period_date;
		END  
   
	-- baby steps toward identifying keys & easily stored info to speed queries coming after...  
	DROP TABLE IF EXISTS #tempFormKeys;
	CREATE TABLE #tempFormkeys (form_id INTEGER
		 , revision_id INTEGER
		 , display_status_uid INTEGER
		 , customer_id INTEGER
		 , generator_id INTEGER
		 , profile_id INTEGER
		 , waste_common_name VARCHAR(50)
		 , generator_name VARCHAR(75)
		 , generator_type VARCHAR(20)
		 , epa_id VARCHAR(12)
		 , cust_name VARCHAR(75)
		 , signing_date DATETIME
		 , tsdf_type VARCHAR(10)
		 );

	WITH MaxRevisions AS (
			SELECT contact_id, form_id, MAX(revision_id) AS max_revision_id
			  FROM dbo.ContactCORFormWCRBucket
			 WHERE contact_id = @i_contact_id
			 GROUP BY contact_id, form_id
		 )
	   , FilteredForms AS (
			SELECT f.form_id, f.revision_id, f.display_status_uid, f.customer_id, f.generator_id
				 , f.profile_id, f.waste_common_name, f.generator_name, gt.generator_type
				 , f.EPA_ID, f.cust_name, f.signing_date, 'USE' AS tsdf_type
			  FROM dbo.ContactCORFormWCRBucket b
				   JOIN MaxRevisions m ON b.contact_id = m.contact_id
						AND b.form_id = m.form_id
						AND b.revision_id = m.max_revision_id
				   JOIN dbo.FormWCR f ON b.form_id = f.form_id
						AND b.revision_id = f.revision_id
			  LEFT JOIN GeneratorType gt ON f.generator_type_id = gt.generator_type_id
				   JOIN FormDisplayStatus pds ON f.display_status_uid = pds.display_status_uid
			 WHERE b.contact_id = @i_contact_id
			   AND pds.display_status IN (SELECT display_status FROM #statusSet)
			   AND ((@i_owner = 'mine' AND @i_email IN (f.created_by) OR @i_web_userid IN (f.created_by)) OR @i_owner = 'all')
			   AND (@i_copy_status = '' OR f.copy_source = @i_copy_status)
			   AND (@i_form_id = '' OR f.form_id IN (SELECT form_id FROM #form_ids))
			   AND (@i_waste_common_name = '' OR f.waste_common_name LIKE @i_waste_common_name)
			   AND (@i_customer_id_list = '' OR f.customer_id IN (SELECT customer_id FROM #customer))
			   AND (@i_generator_id_list = '' OR f.generator_id IN (SELECT generator_id FROM #generator))
			   AND (
					(f.display_status_uid = 1
						AND f.signing_date IS NULL
						AND (f.profile_id IS NULL 
							OR (f.profile_id IS NOT NULL 
								AND f.copy_source IN ('Amendment', 'Renewal', 'csnew', 'resubmited'))
							   )
							)
						 OR f.display_status_uid <> 1
					)
			   AND f.form_id > 0
		 )
	INSERT INTO #tempFormKeys (form_id, revision_id, display_status_uid, customer_id, generator_id, profile_id
		 , waste_common_name, generator_name, generator_type, epa_id, cust_name, signing_date, tsdf_type)
	SELECT form_id, revision_id, display_status_uid, customer_id, generator_id, profile_id
		 , waste_common_name, generator_name, generator_type, epa_id, cust_name, signing_date, tsdf_type
	  FROM FilteredForms;

	DROP TABLE IF EXISTS #tempFormKeys2;
	CREATE TABLE #tempFormkeys2 (form_id INTEGER
		 , revision_id INTEGER
		 , display_status_uid INTEGER
		 , customer_id INTEGER
		 , generator_id INTEGER
		 , profile_id INTEGER
		 , waste_common_name VARCHAR(50)
		 , generator_name VARCHAR(75)
		 , epa_id VARCHAR(12)
		 , cust_name VARCHAR(75)
		 , signing_date DATETIME
		 , [status] CHAR(1)
		 , date_modified DATETIME
		 , created_by VARCHAR(60)
		 , modified_by VARCHAR(60)
		 , copy_source VARCHAR(10)
		 , display_status VARCHAR(60)
		 , site_type VARCHAR(40)
		 , generator_type VARCHAR(20)
		 , tsdf_type VARCHAR(10)
		 );
  
	WITH CTE_SearchResults AS (
			SELECT f.form_id, f.revision_id, f.display_status_uid, f.customer_id, f.generator_id
				 , f.profile_id, f.waste_common_name
				 , COALESCE(gn.generator_name, f.generator_name) AS generator_name
				 , f.epa_id, f.cust_name, f.signing_date, w.[status]
				 , w.date_modified, w.created_by, w.modified_by, ISNULL(w.copy_source, 'new') AS copy_source
				 , pds.display_status, gn.site_type, ISNULL(gt.generator_type, 'N/A') AS generator_type
				 , f.tsdf_type
				 , CONVERT(VARCHAR(20), f.form_id) + ' ' + CONVERT(VARCHAR(20), f.form_id) + '-' + CONVERT(VARCHAR(20), f.revision_id) 
					+ ' ' + ISNULL(CONVERT(VARCHAR(20), f.profile_id), '') + ' ' + ISNULL(f.waste_common_name, '')
					+ ' ' + COALESCE(gn.generator_name, f.generator_name, '') + ' ' + COALESCE(gn.epa_id, f.epa_id, '')
					+ ' ' + COALESCE(cn.cust_name, f.cust_name, '')
					+ ' ' + ISNULL((SELECT SUBSTRING((
						SELECT ', ' + ISNULL(approval_code, '')  
						  FROM dbo.ProfileQuoteApproval q
						 WHERE q.profile_id = f.profile_id  
						   AND f.profile_id IS NOT NULL  
						   AND q.[status] = 'A'  
						   FOR XML PATH('')
						), 2, 20000)
					), '') AS full_text
			  FROM #tempFormKeys f
				   JOIN dbo.FormWCR w ON f.form_id = w.form_id
						AND f.revision_id = w.revision_id
				   JOIN dbo.FormDisplayStatus pds ON f.display_status_uid = pds.display_status_uid
			  LEFT JOIN dbo.Customer cn ON f.customer_id = cn.customer_id
			  LEFT JOIN dbo.Generator gn ON f.generator_id = gn.generator_id
			  LEFT JOIN dbo.GeneratorType gt ON COALESCE(gn.generator_type_id, NULLIF(w.generator_type_id, 0)) = gt.generator_type_id
			  LEFT JOIN #period_data pd ON f.form_id = pd.form_id
						AND f.revision_id = pd.revision_id
						AND f.display_status_uid = pd.display_status_uid
			 WHERE NOT EXISTS (SELECT TOP 1 template_form_id FROM FormWCRTemplate WHERE template_form_id = f.form_id)
		)
	INSERT INTO #tempFormKeys2 (form_id, revision_id, display_status_uid, customer_id, generator_id
		 , profile_id, waste_common_name, generator_name, epa_id, cust_name, signing_date, [status]
		 , date_modified, created_by, modified_by, copy_source, display_status, site_type, generator_type, tsdf_type)
	SELECT sr.form_id, sr.revision_id, sr.display_status_uid, sr.customer_id, sr.generator_id
		 , sr.profile_id, sr.waste_common_name, sr.generator_name, sr.epa_id, sr.cust_name, sr.signing_date, sr.[status]
		 , sr.date_modified, sr.created_by, sr.modified_by, sr.copy_source, sr.display_status, sr.site_type, sr.generator_type, sr.tsdf_type
	  FROM CTE_SearchResults sr
	 WHERE (@i_search = '' OR sr.full_text LIKE '%' + @i_search + '%')
       AND (@i_generator_size = '' OR (@i_generator_size <> '' AND sr.generator_type IN (SELECT generator_type FROM #generatorsize)))
	   AND (@i_generator_name = '' OR (@i_generator_name <> '' AND sr.generator_name LIKE '%' + REPLACE(@i_generator_name, ' ', '%') + '%'))
	   AND (@i_epa_waste_code = '' OR (@i_epa_waste_code <> '' AND EXISTS (
                SELECT 1 
                  FROM dbo.FormXWasteCode pwc
                       JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid 
                 WHERE pwc.form_id = sr.form_id  
                   AND pwc.revision_id = sr.revision_id
				   AND wc.display_name IN (SELECT waste_code FROM #wastecodes)))
		   )
	   AND (@i_haz_filter IN ('All', '')
			OR (@i_haz_filter IN ('rcra') AND EXISTS (
                SELECT 1 
                  FROM dbo.FormXWasteCode pwc
					   JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
                WHERE pwc.form_id = sr.form_id  
                  AND pwc.revision_id = sr.revision_id
				  AND wc.waste_code_origin = 'F'  
                  AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U'))
			   )
			OR (@i_haz_filter IN ('non-rcra') AND NOT EXISTS (
                SELECT 1 
                  FROM dbo.FormXWasteCode pwc
                       JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
                 WHERE pwc.form_id = sr.form_id  
                  AND pwc.revision_id = sr.revision_id
				  AND wc.waste_code_origin = 'F'
				  AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U'))
			   )
			OR (@i_haz_filter IN ('state') AND EXISTS (
                SELECT 1
                  FROM dbo.FormXWasteCode pwc
					   JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
                 WHERE pwc.form_id = sr.form_id  
                   AND pwc.revision_id = sr.revision_id
				   AND wc.waste_code_origin = 'S')
				AND NOT EXISTS (
                SELECT 1
                  FROM dbo.FormXWasteCode pwc
					   JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
                 WHERE pwc.form_id = sr.form_id  
                   AND pwc.revision_id = sr.revision_id
				   AND wc.waste_code_origin = 'F'
				   AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U'))
			   )
			OR (@i_haz_filter IN ('non-regulated', 'non', 'Non-Reg') AND NOT EXISTS (
                SELECT 1 
                  FROM dbo.FormXWasteCode pwc
					   JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
                 WHERE pwc.form_id = sr.form_id  
                   AND pwc.revision_id = sr.revision_id
				   AND wc.waste_code_origin IN ('S', 'F'))
			   )
		   )
	   AND (@i_generator_site_type = '' 
			OR (@i_generator_site_type <> '' AND sr.site_type IN (SELECT site_type FROM #generatorsitetype))
		   )
	   AND (@i_period = '' OR (@i_period <> '' AND EXISTS (SELECT 1 FROM #period_data  WHERE form_id = sr.form_id)))
	   ;
  
	DROP TABLE IF EXISTS #tempPendingList;
	CREATE TABLE #tempPendingList (_id INTEGER NOT NULL IDENTITY(1,1)
		 , form_id INTEGER
		 , revision_id INTEGER
		 , profile_id INTEGER
		 , approval_code VARCHAR(2000)	--
		 , [status] CHAR(1)
		 , display_status VARCHAR(30)	--
		 , waste_common_name VARCHAR(50)
		 , generator_id INTEGER
		 , generator_name VARCHAR(75)
		 , generator_type VARCHAR(20)
		 , epa_id   VARCHAR(12)
		 , site_type  VARCHAR(40)
		 , customer_id  INTEGER
		 , cust_name  VARCHAR(75)
		 , date_modified DATETIME
		 , created_by  VARCHAR(100)
		 , modified_by  VARCHAR(100)
		 , copy_source  VARCHAR(10)
		 , tsdf_type  VARCHAR(10)
		 , edit_allowed CHAR(1)
		 , _row INTEGER
		 , totalcount INTEGER
		 );
	INSERT INTO #tempPendingList (form_id, revision_id, profile_id, approval_code, [status]
		 , display_status
		 , waste_common_name, generator_id, generator_name, generator_type
		 , epa_id, site_type, customer_id, cust_name, date_modified, created_by, modified_by
		 , copy_source, tsdf_type, edit_allowed, _row, totalcount)  
	SELECT form_id, revision_id, profile_id, approval_code, [status]
		 , CASE WHEN display_status = 'Approved' AND profile_id IS NOT NULL
						AND profile_id IS NOT NULL AND ap_expiration_date < GETDATE()   
				     THEN 'Accepted'   
				ELSE display_status   
			END as display_status
		 , waste_common_name, generator_id, generator_name, generator_type
		 , epa_id, site_type, customer_id, cust_name, date_modified, created_by, modified_by
		 , copy_source, tsdf_type, edit_allowed, _row, 0 AS totalcount   
	  FROM (SELECT tf.form_id, tf.revision_id, tf.profile_id
				 , CASE WHEN tf.profile_id IS NULL THEN NULL
						ELSE (SELECT SUBSTRING((SELECT '<br/>' + ISNULL(pqa.approval_code, '')
									+ ' : ' + ISNULL(CONVERT(VARCHAR(2), use_pc.company_id), '')
									+ '|' + ISNULL(CONVERT(VARCHAR(2), use_pc.profit_ctr_id), '')
									+ ' : ' + ISNULL(use_pc.[name], '')
								FROM dbo.ProfileQuoteApproval pqa
								     JOIN dbo.USE_ProfitCenter use_pc on pqa.company_id = use_pc.company_id
										  AND pqa.profit_ctr_id = use_pc.profit_ctr_id  
							   WHERE pqa.profile_id = tf.profile_id
								 AND pqa.[status] = 'A'
							   ORDER BY use_pc.[name]
								 FOR XML PATH, TYPE).value('.[1]', 'VARCHAR(2000)'), 6, 20000)
							)
					END as approval_code
				 , tf.[status], tf.display_status
				 , tf.waste_common_name, tf.generator_id, tf.generator_name as generator_name, tf.generator_type
				 , tf.epa_id, tf.site_type, tf.customer_id, tf.cust_name, tf.date_modified, tf.created_by
				 , (SELECT TOP 1 CONCAT(first_name, ' ', last_name) FROM dbo.Contact where web_userid = tf.modified_by) as modified_by
				 , tf.copy_source, tf.tsdf_type, 'T' as edit_allowed, p.ap_expiration_date --tf.signing_date
				 ,  _row = row_number() OVER (ORDER BY CASE WHEN @i_sort = 'Generator Name' THEN tf.generator_name END ASC
													 , CASE WHEN @i_sort = 'Profile Number' THEN tf.form_id END ASC
													 , CASE WHEN @i_sort = 'Waste Common Name' THEN tf.waste_common_name END ASC
													 , CASE WHEN @i_sort = 'RCRA Status' THEN tf.generator_type END ASC
													 , CASE WHEN @i_sort in ('', 'Modified Date') THEN tf.date_modified END DESC)
			  FROM #tempFormKeys2 tf
			  LEFT JOIN dbo.[Profile] p on tf.profile_id = p.profile_id and tf.profile_id IS NOT NULL
			 WHERE 1 = CASE WHEN p.profile_id IS NOT NULL AND p.curr_status_code NOT IN ('R', 'C', 'H', 'V') THEN 1
							WHEN p.profile_id IS NULL THEN 1
							ELSE 0
						END
			) y
	 WHERE CASE WHEN display_status = 'Approved' AND profile_id IS NOT NULL AND ap_expiration_date < GETDATE() THEN 'Accepted'
				ELSE display_status
			END not in ('Approved')
	   AND @i_tsdf_type in ('USE', 'ALL');
  
	-- Now add results from TSDF Approvals  
	WITH HazFilter AS (
			SELECT ta.TSDF_approval_id
			  FROM dbo.TSDFApproval ta
				   JOIN dbo.TSDF ON ta.tsdf_code = tsdf.tsdf_code
			  LEFT JOIN dbo.TSDFApprovalWasteCode pwc ON ta.TSDF_approval_id = pwc.TSDF_approval_id
			  LEFT JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
			 WHERE @i_haz_filter IN ('All', '')
			    OR (@i_haz_filter IN ('rcra') AND wc.waste_code_origin = 'F' AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U'))
				OR (@i_haz_filter IN ('non-rcra') AND (wc.waste_code_origin != 'F' OR LEFT(wc.display_name, 1) NOT IN ('D', 'F', 'K', 'P', 'U')))
		 )
	   , EpaWasteCodeFilter AS (
			SELECT pwc.TSDF_approval_id
			  FROM dbo.TSDFApprovalWasteCode pwc
				   JOIN dbo.WasteCode wc ON pwc.waste_code_uid = wc.waste_code_uid
			 WHERE wc.display_name IN (SELECT waste_code FROM #wastecodes)
		 )
	INSERT INTO #tempPendingList (form_id, revision_id, profile_id
		 , approval_code, [status], display_status, waste_common_name
		 , generator_id, generator_name, generator_type, epa_id, site_type, customer_id, cust_name
		 , date_modified, created_by, modified_by, copy_source, tsdf_type, edit_allowed
		 , _row, totalcount)
	SELECT NULL AS form_id, NULL AS revision_id, ta.tsdf_approval_id AS profile_id
		 , ISNULL(ta.tsdf_approval_code, '') + ' : ' + ISNULL(TSDF.tsdf_name, '') AS approval_code
		 , ta.TSDF_approval_status AS [status], 'Pending' AS display_status, ta.waste_desc AS waste_common_name
		 , ta.generator_id, gn.generator_name, gt.generator_type, gn.epa_id, gn.site_type, ta.customer_id, cn.cust_name
		 , ta.date_modified, ta.added_by, ta.modified_by, NULL AS copy_source, 'Non-USE' AS tsdf_type, 'F' AS edit_allowed
		 , ROW_NUMBER() OVER (ORDER BY CASE WHEN @i_sort = 'Generator Name' THEN gn.generator_name END ASC
									 , CASE WHEN @i_sort = 'Profile Number' THEN ta.tsdf_approval_id END ASC
									 , CASE WHEN @i_sort = 'Waste Common Name' THEN ta.waste_desc END ASC
									 , CASE WHEN @i_sort = 'RCRA Status' THEN gt.generator_type END ASC
									 , CASE WHEN @i_sort IN ('', 'Modified Date') THEN ta.date_modified END DESC) AS _row
		 , 0 AS total_count
	  FROM dbo.TSDFApproval ta
		   JOIN dbo.TSDF ON ta.tsdf_code = TSDF.tsdf_code
		   JOIN dbo.Customer cn ON ta.customer_id = cn.customer_id
		   JOIN dbo.Generator gn ON ta.generator_id = gn.generator_id
	  LEFT JOIN dbo.GeneratorType gt ON gn.generator_type_id = gt.generator_type_id
	 WHERE TSDF.tsdf_status = 'A'
	   AND TSDF.eq_flag = 'F'
	   AND (ta.customer_id IN (SELECT customer_id FROM dbo.ContactCORCustomerBucket WHERE contact_id = @i_contact_id)
			OR ta.generator_id IN (SELECT generator_id FROM dbo.ContactCORGeneratorBucket WHERE contact_id = @i_contact_id AND direct_flag = 'D'))
	   AND @i_tsdf_type IN ('Non-USE', 'ALL')
	   AND ta.current_approval_status <> 'COMP'
	   AND ta.TSDF_approval_status = 'A'
	   AND ta.TSDF_approval_expire_date > DATEADD(yyyy, -2, GETDATE())
	   AND (@i_search = '' 
			OR (@i_search <> '' AND CONVERT(VARCHAR(20), ta.tsdf_approval_id) 
									+ ' ' + ta.waste_desc + ' ' + gn.generator_name + ' ' + gn.epa_id + ' ' + cn.cust_name 
									+ ' ' + ISNULL(ta.tsdf_approval_code, '') LIKE '%' + REPLACE(@i_search, ' ', '%') + '%')
		   )
	   AND (@i_generator_size = ''
			OR (@i_generator_size <> '' AND gt.generator_type IN (SELECT generator_type FROM #generatorsize)))
	   AND (@i_generator_name = ''
			OR (@i_generator_name <> '' AND gn.generator_name LIKE '%' + REPLACE(@i_generator_name, ' ', '%') + '%'))
	   AND (@i_waste_common_name = '' OR (@i_waste_common_name <> '' AND ta.waste_desc LIKE '%' + REPLACE(@i_waste_common_name, ' ', '%') + '%'))
	   AND (@i_epa_waste_code = ''
			OR (@i_epa_waste_code <> '' AND EXISTS (SELECT 1 FROM EpaWasteCodeFilter ef WHERE ef.TSDF_approval_id = ta.TSDF_approval_id))
		   )
	   AND (@i_haz_filter IN ('All', '')
			OR (@i_haz_filter <> '' AND EXISTS (SELECT 1 FROM HazFilter hf WHERE hf.TSDF_approval_id = ta.TSDF_approval_id))
		   )
	   AND (@i_customer_id_list = '' OR (@i_customer_id_list <> '' AND ta.customer_id IN (SELECT customer_id FROM #customer)))
	   AND (@i_generator_id_list = '' OR (@i_generator_id_list <> '' AND ta.generator_id IN (SELECT generator_id FROM #generator)))
	   AND (@i_generator_site_type = '' OR (@i_generator_site_type <> '' AND gn.site_type IN (SELECT site_type FROM #generatorsitetype)))
	;

	-- _row is now incorrectly numbered from multiple inserts.  Fix it.  
	UPDATE #tempPendingList
	   SET _row = n._row  
	  FROM #tempPendingList o   
	  JOIN (SELECT _id,  _row = ROW_NUMBER() OVER (ORDER BY
								CASE WHEN @i_sort = 'Generator Name' THEN generator_name END ASC
							  , CASE WHEN @i_sort = 'Profile Number' THEN
										  CASE WHEN profile_id IS NOT NULL THEN profile_id
											   ELSE form_id
										   END
								 END ASC
							  , CASE WHEN @i_sort = 'Waste Common Name' THEN waste_common_name END ASC
							  , CASE WHEN @i_sort = 'RCRA Status' THEN generator_type END ASC
							  , CASE WHEN @i_sort in ('', 'Modified Date') THEN date_modified END DESC)   
			  FROM #tempPendingList) n on o._id = n._id;
  
	-- offshore wants the total count as a field in the results.  okay.  
	UPDATE #tempPendingList
	   SET totalcount = (SELECT COUNT(totalcount) FROM #tempPendingList);
  
	-- output.  Not excel (w/paging) first, THEN excel version later.  
	IF @excel_output = 0
		BEGIN
			SELECT form_id, revision_id, profile_id, approval_code, [status], display_status
				 , waste_common_name, generator_id, generator_name, generator_type, epa_id, site_type
				 , customer_id, cust_name, date_modified, created_by, modified_by
				 , copy_source, tsdf_type, edit_allowed, _row, totalcount    
			  FROM #tempPendingList
			 WHERE _row BETWEEN ((@i_page-1) * @i_perpage ) + 1 AND (@i_page * @i_perpage)  
			 ORDER BY _row;
		END
	ELSE
		BEGIN
			-- Export to Excel
			SELECT form_id, revision_id, profile_id, approval_code, [status], display_status
				 , waste_common_name, generator_id, generator_name, generator_type, epa_id, site_type
				 , customer_id, cust_name, date_modified, created_by, modified_by
				 , copy_source, tsdf_type, _row, totalcount
			  FROM #tempPendingList
			 ORDER BY _row;
		END
  
	DROP TABLE #statusSet;
	DROP TABLE #generatorsize
	DROP TABLE #form_ids;
	DROP TABLE #generator;
	DROP TABLE #generatorsitetype;
	DROP TABLE #period_data;
	DROP TABLE #tempFormkeys;
	DROP TABLE #tempFormkeys2;
	DROP TABLE #tempPendingList;

	RETURN 0;
END;
GO

GRANT EXEC ON [dbo].[sp_COR_FormWCR_List] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_List]  TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_List]  TO EQAI 
GO 