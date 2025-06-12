
CREATE PROCEDURE sp_forms_cc
	@user varchar(255)
	,@purchase_order varchar(255)
	,@release varchar(255)
	,@revision_id int
	,@form_id int
	,@debug int = 0
	,@profile_id int
	,@session_id varchar(12)
	,@ip_address varchar(40) = ''
	,@image_id int = 0
	,@contact_id int = 0
	,@copc_list varchar(max) = ''
	,@file_location varchar(255) = NULL
AS
/*********************************************************************************
10/25/2011 CRG Changed SP to use FormXApproval instead of storing approval info in 
	the form table
10/14/2011 CRG	Created
11/6/2012 SK	Updated for Energy Surcharge issue
12/14/2012 JPB	Modified the #comments population SP to match sp_populate_form_cc
	This will fix a bug where comments were not being reproduced from the web site.
05/02/2013 JPB	waste_code_uid added
11/13/2013	JPB	Commented out the docproc call at the end.  That should get called separately.
				Also added image_id default of 0
11/15/2013	JPB	Added deletes ahead of the other tables' inserts
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(255) to @copc_list varchar(max)
sp_forms_cc - Creates customer confirmation from web.

sp_forms_cc 'jonathan', '', '', 

SELECT TOP 10 * FROM FormCC order by form_id desc
SELECT TOP 10 * FROM FormCCDetail order by form_id desc

	INSERT INTO [dbo].[FormCCDetail]
           ([form_id]
           ,[revision_id]
           ,[form_version_id]
           ,[approval_key]
           ,[quotedetail_sequence_id]
           ,[quotedetail_record_type]
           ,[quotedetail_service_desc]
           ,[approval_sr_type_code]
           ,[profitcenter_surcharge_flag]
           ,[quotedetail_surcharge_price]
           ,[quotedetail_hours_free_unload]
           ,[quotedetail_hours_free_loading]
           ,[quotedetail_demurrage_price]
           ,[quotedetail_unused_truck_price]
           ,[quotedetail_lay_over_charge]
           ,[quotedetail_bill_method]
           ,[quotedetail_price]
           ,[quotedetail_bill_unit_code]
           ,[quotedetail_min_quantity]
           ,[date_created]
           ,[date_modified]
           ,[created_by]
           ,[modified_by]
           ,[rowguid]
           ,[company_id]
           ,[profit_ctr_id]
           ,[ref_sequence_id]
           )
		SELECT 
			@form_id  		--(<form_id, int,>
			,@revision_id 	--,<revision_id, int,>
			,FormType.current_form_version 	--,<form_version_id, int,>
			,Profile.profile_id  			--,<approval_key, int,>
			,PQD.sequence_id 				--,<quotedetail_sequence_id, int,>
			,PQD.record_type 				--,<quotedetail_record_type, char(1),>
			,PQD.service_desc 				--,<quotedetail_service_desc, varchar(60),>
			,PQA.sr_type_code 				--,<approval_sr_type_code, char(1),>
			,ProfitCenter.surcharge_flag 	--,<profitcenter_surcharge_flag, char(1),>
			,PQD.surcharge_price 			--,<quotedetail_surcharge_price, float,>
			,PQD.hours_free_unloading 		--,<quotedetail_hours_free_unload, int,>
			,PQD.hours_free_loading 		--,<quotedetail_hours_free_loading, int,>
			,PQD.demurrage_price 			--,<quotedetail_demurrage_price, float,>
			,PQD.unused_truck_price 		--,<quotedetail_unused_truck_price, float,>
			,PQD.lay_over_charge 		--,<quotedetail_lay_over_charge, float,>
			,PQD.bill_method 			--,<quotedetail_bill_method, char(1),>
			,PQD.price				--,<quotedetail_price, float,>
			,PQD.bill_unit_code 	--,<quotedetail_bill_unit_code, varchar(4),>
			,PQD.min_quantity 		--,<quotedetail_min_quantity, float,>
			,GETDATE() 		--,<date_created, datetime,>
			,GETDATE()		--,<date_modified, datetime,>
			,@user AS created_by 	--,<created_by, varchar(60),>
			,@user AS modified_by	--,<modified_by, varchar(60),>
			,NEWID() 	--,<rowguid, uniqueidentifier,>
			,pqa.company_id		--,<company_id, int,>
			,pqa.profit_ctr_id		--,<profit_ctr_id, int,>)
			,pqd.ref_sequence_id
		FROM Profile
		inner join FormType on form_type='cc'
		INNER JOIN ProfileQuoteDetail pqd
			ON Profile.profile_id = pqd.profile_id
			AND pqd.status = 'A'
			AND pqd.record_type IN ('S', 'T')
			AND ISNULL(pqd.fee_exempt_flag, 'F') = 'F'
			AND (IsNull(pqd.bill_method, '') <> 'B' OR (IsNull(pqd.bill_method, '') = 'B' AND pqd.show_cust_flag = 'T'))
		INNER JOIN ProfileQuoteApproval pqa
			ON pqd.profile_id = pqa.profile_id
			   AND pqd.company_id = pqa.company_id
			   AND pqd.profit_ctr_id = pqa.profit_ctr_id
		INNER JOIN ProfitCenter
			ON pqd.profit_ctr_id = ProfitCenter.profit_ctr_id
			   AND pqd.company_id = ProfitCenter.company_ID
		WHERE Profile.curr_status_code = 'a'  
			AND FormType.form_type = 'cc'
			AND profile.profile_id = @profile_id
			AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)
UNION ALL
		SELECT 
			@form_id  		--(<form_id, int,>
			,@revision_id 	--,<revision_id, int,>
			,FormType.current_form_version 	--,<form_version_id, int,>
			,Profile.profile_id  			--,<approval_key, int,>
			,PQD.sequence_id 				--,<quotedetail_sequence_id, int,>
			,PQD.record_type 				--,<quotedetail_record_type, char(1),>
			,PQD.service_desc 				--,<quotedetail_service_desc, varchar(60),>
			,PQA.sr_type_code 				--,<approval_sr_type_code, char(1),>
			,ProfitCenter.surcharge_flag 	--,<profitcenter_surcharge_flag, char(1),>
			,PQD.surcharge_price 			--,<quotedetail_surcharge_price, float,>
			,PQD.hours_free_unloading 		--,<quotedetail_hours_free_unload, int,>
			,PQD.hours_free_loading 		--,<quotedetail_hours_free_loading, int,>
			,PQD.demurrage_price 			--,<quotedetail_demurrage_price, float,>
			,PQD.unused_truck_price 		--,<quotedetail_unused_truck_price, float,>
			,PQD.lay_over_charge 		--,<quotedetail_lay_over_charge, float,>
			,PQD.bill_method 			--,<quotedetail_bill_method, char(1),>
			,PQD.price				--,<quotedetail_price, float,>
			,PQD.bill_unit_code 	--,<quotedetail_bill_unit_code, varchar(4),>
			,PQD.min_quantity 		--,<quotedetail_min_quantity, float,>
			,GETDATE() 		--,<date_created, datetime,>
			,GETDATE()		--,<date_modified, datetime,>
			,@user AS created_by 	--,<created_by, varchar(60),>
			,@user AS modified_by	--,<modified_by, varchar(60),>
			,NEWID() 	--,<rowguid, uniqueidentifier,>
			,pqa.company_id		--,<company_id, int,>
			,pqa.profit_ctr_id		--,<profit_ctr_id, int,>)
			,pqd.ref_sequence_id
		FROM Profile 
		inner join FormType on form_type='cc'
		INNER JOIN ProfileQuoteDetail pqd
			ON Profile.profile_id = pqd.profile_id
			AND pqd.status = 'A'
			AND pqd.record_type = 'D'
			AND ISNULL(pqd.fee_exempt_flag, 'F') = 'F'
			AND IsNull(pqd.bill_method, '') <> 'B'
		INNER JOIN ProfileQuoteApproval pqa
			ON pqd.profile_id = pqa.profile_id
			   AND pqd.company_id = pqa.company_id
			   AND pqd.profit_ctr_id = pqa.profit_ctr_id
		INNER JOIN ProfitCenter
			ON pqd.profit_ctr_id = ProfitCenter.profit_ctr_id
			   AND pqd.company_id = ProfitCenter.company_ID
		WHERE Profile.curr_status_code = 'a'  
			AND FormType.form_type = 'cc'
			AND profile.profile_id = @profile_id
			AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)



*********************************************************************************/

CREATE TABLE #comments (
	profile_id		INT		NULL
,	company_id		INT		NULL
,	profit_ctr_id	INT		NULL
,	comment			VARCHAR(8000)	NULL
)

declare @CARRIAGE_RETURN varchar(5) = CHAR(13) + CHAR(10)

create table #copc(
	company_id int,
	profit_ctr_id int
)

INSERT #copc 
    SELECT 
      RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
      RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
    from dbo.fn_SplitXsvText(',', 0, @copc_list) 
    where isnull(row, '') <> ''     

IF EXISTS (SELECT * FROM FormCC WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM FormCC WHERE form_id = @form_id AND revision_id = @revision_id

INSERT INTO [dbo].[FormCC]
           ([form_id]
           ,[revision_id]
           ,[form_version_id]
           ,[customer_id]
           ,[status]
           ,[locked]
           ,[source]
           ,[approval_code]
           ,[approval_key]
           ,[company_id]
           ,[profit_ctr_id]
           ,[signing_name]
           ,[signing_company]
           ,[signing_title]
           ,[signing_date]
           ,[date_created]
           ,[date_modified]
           ,[created_by]
           ,[modified_by]
           ,[customer_cust_name]
           ,[customer_cust_addr1]
           ,[customer_cust_addr2]
           ,[customer_cust_addr3]
           ,[customer_cust_addr4]
           ,[customer_cust_addr5]
           ,[customer_cust_city]
           ,[customer_cust_state]
           ,[customer_cust_zip_code]
           ,[customer_cust_fax]
           ,[contact_id]
           ,[contact_name]
           ,[company_company_name]
           ,[profitcenter_profit_ctr_name]
           ,[profitcenter_address_1]
           ,[profitcenter_address_2]
           ,[profitcenter_address_3]
           ,[profitcenter_phone]
           ,[profitcenter_fax]
           ,[profitcenter_epa_id]
           ,[profitcenter_scheduling_phone]
           ,[company_ins_surcharge_percent]
           ,[approval_ap_expiration_date]
           ,[generator_generator_name]
           ,[approval_approval_desc]
           ,[wastecode_waste_code_desc]
           ,[wastecode_waste_code]
           ,[secondary_waste_code_list]
           ,[approval_ots_flag]
           ,[generator_epa_id]
           ,[generator_id]
           ,[QuoteDetailDesc_description]
           ,[purchase_order]
           ,[release]
           ,[profile_id]
           ,[ensr_applied_flag]
           ,[rowguid])
     SELECT
			@form_id				--<form_id, int,>
           ,@revision_id			--<revision_id, int,>
           ,current_form_version	--<form_version_id, int,>
           ,Profile.customer_id		--<customer_id, int,>
           ,'A'						--<status, char(1),>
           ,'U'						--<locked, char(1),>
           ,'A'						--<source, char(1),>
           ,NULL					--<approval_code, varchar(15),>
           ,Profile.profile_id		--<approval_key, int,>
           ,NULL					--<company_id, int,>
           ,NULL					--<profit_ctr_id, int,>
           ,NULL					--<signing_name, varchar(40),>
           ,NULL					--<signing_company, varchar(40),>
           ,NULL					--<signing_title, varchar(40),>
           ,NULL					--<signing_date, datetime,>
           ,GETDATE()				--<date_created, datetime,>
           ,GETDATE()				--<date_modified, datetime,>
           ,@user				--<created_by, varchar(60),>
           ,@user				--<modified_by, varchar(60),>
           ,Customer.cust_name		--<customer_cust_name, varchar(40),>
           ,Customer.cust_addr1		--<customer_cust_addr1, varchar(40),>
           ,Customer.cust_addr2		--<customer_cust_addr2, varchar(40),>
           ,Customer.cust_addr3		--<customer_cust_addr3, varchar(40),>
           ,Customer.cust_addr4		--<customer_cust_addr4, varchar(40),>
           ,Customer.cust_addr5		--<customer_cust_addr5, varchar(40),>
           ,Customer.cust_city		--<customer_cust_city, varchar(40),>
           ,Customer.cust_state		--<customer_cust_state, varchar(2),>
           ,Customer.cust_zip_code		--<customer_cust_zip_code, varchar(15),>
           ,Customer.cust_fax		--<customer_cust_fax, varchar(10),>
           ,NULL					--<contact_id, int,>
           ,NULL					--<contact_name, varchar(40),>
           ,NULL					--<company_company_name, varchar(35),>
           ,NULL					--<profitcenter_profit_ctr_name, varchar(50),>
           ,NULL					--<profitcenter_address_1, varchar(40),>
           ,NULL					--<profitcenter_address_2, varchar(40),>
           ,NULL					--<profitcenter_address_3, varchar(40),>
           ,NULL					--<profitcenter_phone, varchar(14),>
           ,NULL					--<profitcenter_fax, varchar(14),>
           ,NULL					--<profitcenter_epa_id, varchar(12),>
           --,ProfitCenter.scheduling_phone			--<profitcenter_scheduling_phone, varchar(14),>
           --,Company.insurance_surcharge_percent		--<company_ins_surcharge_percent, money,>
           ,NULL
           ,NULL
           ,Profile.ap_expiration_date				--<approval_ap_expiration_date, datetime,>
           ,Generator.generator_name				--<generator_generator_name, varchar(40),>
           ,Profile.approval_desc					--<approval_approval_desc, varchar(50),>
           ,WasteCode.waste_code_desc			--<wastecode_waste_code_desc, varchar(60),>
           ,NULL				--<wastecode_waste_code, varchar(4),>
           ,NULL --(dbo.fn_sec_waste_code_list(Profile.Profile_id))--<secondary_waste_code_list, text,>
           ,Profile.OTS_flag					--<approval_ots_flag, char(1),>
           ,Generator.EPA_ID					--<generator_epa_id, varchar(12),>
           ,Profile.generator_id				--<generator_id, int,>
           --,ProfileQuoteDetailDesc.description	--<QuoteDetailDesc_description, text,>
           ,NULL
           ,@purchase_order						--<purchase_order, varchar(20),>
           ,@release							--<release, varchar(20),>
           ,Profile.profile_id					--<profile_id, int,>
			--,(CASE CustomerBilling.ensr_flag 	--<ensr_applied_flag, char(1),>
			--		WHEN 'P' THEN 
			--			CASE isnull(PQA.ensr_exempt, 'F') 
			--				WHEN 'T' THEN 'F' 
			--				WHEN 'F' THEN 'T' 
			--			END 
			--		ELSE CustomerBilling.ensr_flag 
			-- END)
			,NULL
			,NEWID() 
	FROM Profile 
			--inner join ProfileQuoteApproval PQA on Profile.profile_id = PQA.profile_id 
			left join CustomerBilling on Profile.customer_id = CustomerBilling.customer_id AND CustomerBilling.billing_project_id = 0
			left join Customer on Profile.customer_id = customer.customer_id 
			left join Generator on Profile.generator_id = Generator.generator_id 
			--left join ProfitCenter on PQA.profit_ctr_id = ProfitCenter.profit_ctr_id and PQA.Company_id = ProfitCenter.Company_id 
			left join WasteCode on Profile.waste_code_uid = WasteCode.waste_code_uid
			--left join Company on PQA.Company_id = Company.Company_id 
			--left join ProfileQuoteDetailDesc on Profile.profile_id = ProfileQuoteDetailDesc.profile_id 
				--and ProfileQuoteDetailDesc.company_id = PQA.company_id 
				--and ProfileQuoteDetailDesc.profit_ctr_id = PQA.profit_ctr_id
			JOIN dbo.FormType ON dbo.FormType.form_type = 'CC'
		WHERE 1=1
			AND Profile.curr_status_code = 'A'  
			AND Profile.profile_id = @profile_id

	IF EXISTS (SELECT * FROM [FormXWasteCode] WHERE form_id = @form_id AND revision_id = @revision_id)
		DELETE FROM [FormXWasteCode] WHERE form_id = @form_id AND revision_id = @revision_id

	INSERT INTO [Plt_AI].[dbo].[FormXWasteCode]
           ([form_id]
           ,[revision_id]
           ,[page_number]
           ,[line_item]
           ,[waste_code]
           ,[specifier]
           ,[waste_code_uid])
     SELECT
           @form_id			--(<form_id, int,>
           ,@revision_id	--,<revision_id, int,>
           ,1				--,<page_number, int,>
           ,1				--,<line_item, int,>
           ,waste_code		--,<waste_code, char(4),>
           ,'CC'			--,<specifier, varchar(30),>)
           ,waste_code_uid
        FROM ProfileWasteCode
           WHERE profile_id = @profile_id

		-- get comments
		INSERT  INTO #comments
		SELECT DISTINCT
			PQD.profile_id
		,   PQD.company_id
		,   PQD.profit_ctr_id
		,   comment = (ISNULL(d.description, '') + CASE d.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END +
					   ISNULL(t.description, '') + CASE t.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END + ISNULL(s.description, '')
					   )
		FROM ProfileQuoteApproval PQA
		JOIN ProfileQuoteDetail PQD
			ON PQA.profile_id = PQD.profile_id
			AND PQA.quote_id = PQD.quote_id
			AND PQD.status = 'A'
		LEFT OUTER JOIN ProfileQuoteDetailDesc d
			ON d.profile_id = PQD.profile_id
			   AND d.company_id = PQD.company_id
			   AND d.profit_ctr_id = PQD.profit_ctr_id
			   AND d.quote_id = PQD.quote_id
			   AND d.record_type = 'D'
		LEFT OUTER JOIN ProfileQuoteDetailDesc t
			ON t.profile_id = PQD.profile_id
			   AND t.company_id = PQD.company_id
			   AND t.profit_ctr_id = PQD.profit_ctr_id
				AND t.quote_id = PQD.quote_id
			   AND t.record_type = 'T'
		LEFT OUTER JOIN ProfileQuoteDetailDesc s
			ON s.profile_id = PQD.profile_id
			   AND s.company_id = PQD.company_id
			   AND s.profit_ctr_id = PQD.profit_ctr_id
			   AND s.quote_id = PQD.quote_id
			   AND s.record_type = 'S'
		WHERE PQA.status = 'A'
		 AND PQA.profile_id = @profile_ID
 

		IF EXISTS (SELECT * FROM [FormXApproval] WHERE form_id = @form_id AND revision_id = @revision_id)
			DELETE FROM [FormXApproval] WHERE form_id = @form_id AND revision_id = @revision_id

		INSERT INTO [dbo].[FormXApproval]
           ([form_type]
           ,[form_id]
           ,[revision_id]
           ,[company_id]
           ,[profit_ctr_id]
           ,[profile_id]
           ,[approval_code]
           ,[profit_ctr_name]
           ,[profit_ctr_EPA_ID]
           ,[insurance_surcharge_percent]
           ,[ensr_exempt]
           ,[quotedetail_comment]
           )
     SELECT DISTINCT
           'CC'					--<form_type, char(10),>
           ,@form_id					--<form_id, int,>
           ,@revision_id			--<revision_id, int,>
           ,PQA.company_ID	--<company_id, int,>
           ,PQA.profit_ctr_id		--<profit_ctr_id, int,>
           ,p.profile_id		--<profile_id, int,>
           ,PQA.approval_code		--<approval_code, varchar(15),>
           ,ProfitCenter.profit_ctr_name		--<profit_ctr_name, varchar(50),>
           ,ProfitCenter.EPA_ID		--<profit_ctr_EPA_ID, varchar(12),>
			,	CASE CB.insurance_surcharge_flag 
					WHEN 'T' THEN IsNull(Company.insurance_surcharge_percent, 0.00)
					WHEN 'F' THEN 0.00
					ELSE (CASE PQA.insurance_exempt WHEN 'T' THEN 0.00 ELSE IsNull(Company.insurance_surcharge_percent, 0.00) END)
				END AS insurance_surcharge_percent
			,	CASE CB.ensr_flag 
					WHEN 'T' THEN 'F'
					WHEN 'F' THEN 'T'
					ELSE (CASE PQA.ensr_exempt WHEN 'T' THEN 'T' ELSE 'F' END)
				END AS ensr_exempt
			,	X.comment
    FROM Profile P
		INNER JOIN ProfileQuoteApproval PQA
			ON PQA.profile_id = P.profile_id
			AND PQA.status = 'A'
		INNER JOIN CustomerBilling CB
			ON CB.customer_id = P.customer_id
			AND CB.billing_project_id = ISNULL(PQA.billing_project_id, 0)
		inner join ProfitCenter on PQA.profit_ctr_id = ProfitCenter.profit_ctr_id and PQA.company_id = ProfitCenter.company_id 
		INNER JOIN Company
			ON Company.company_id = PQA.company_id
		LEFT OUTER JOIN #comments X
			ON X.profile_id = PQA.profile_id
			AND X.company_id = PQA.company_id
			AND X.profit_ctr_id = PQA.profit_ctr_id
	WHERE 
		P.profile_id = @profile_id
		AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)

	IF EXISTS (SELECT * FROM [FormCCDetail] WHERE form_id = @form_id AND revision_id = @revision_id)
		DELETE FROM [FormCCDetail] WHERE form_id = @form_id AND revision_id = @revision_id

	INSERT INTO [dbo].[FormCCDetail]
           ([form_id]
           ,[revision_id]
           ,[form_version_id]
           ,[approval_key]
           ,[quotedetail_sequence_id]
           ,[quotedetail_record_type]
           ,[quotedetail_service_desc]
           ,[approval_sr_type_code]
           ,[profitcenter_surcharge_flag]
           ,[quotedetail_surcharge_price]
           ,[quotedetail_hours_free_unload]
           ,[quotedetail_hours_free_loading]
           ,[quotedetail_demurrage_price]
           ,[quotedetail_unused_truck_price]
           ,[quotedetail_lay_over_charge]
           ,[quotedetail_bill_method]
           ,[quotedetail_price]
           ,[quotedetail_bill_unit_code]
           ,[quotedetail_min_quantity]
           ,[date_created]
           ,[date_modified]
           ,[created_by]
           ,[modified_by]
           ,[rowguid]
           ,[company_id]
           ,[profit_ctr_id]
           ,[ref_sequence_id]
           )
		SELECT 
			@form_id  		--(<form_id, int,>
			,@revision_id 	--,<revision_id, int,>
			,FormType.current_form_version 	--,<form_version_id, int,>
			,Profile.profile_id  			--,<approval_key, int,>
			,PQD.sequence_id 				--,<quotedetail_sequence_id, int,>
			,PQD.record_type 				--,<quotedetail_record_type, char(1),>
			,PQD.service_desc 				--,<quotedetail_service_desc, varchar(60),>
			,PQA.sr_type_code 				--,<approval_sr_type_code, char(1),>
			,ProfitCenter.surcharge_flag 	--,<profitcenter_surcharge_flag, char(1),>
			,PQD.surcharge_price 			--,<quotedetail_surcharge_price, float,>
			,PQD.hours_free_unloading 		--,<quotedetail_hours_free_unload, int,>
			,PQD.hours_free_loading 		--,<quotedetail_hours_free_loading, int,>
			,PQD.demurrage_price 			--,<quotedetail_demurrage_price, float,>
			,PQD.unused_truck_price 		--,<quotedetail_unused_truck_price, float,>
			,PQD.lay_over_charge 		--,<quotedetail_lay_over_charge, float,>
			,PQD.bill_method 			--,<quotedetail_bill_method, char(1),>
			,PQD.price				--,<quotedetail_price, float,>
			,PQD.bill_unit_code 	--,<quotedetail_bill_unit_code, varchar(4),>
			,PQD.min_quantity 		--,<quotedetail_min_quantity, float,>
			,GETDATE() 		--,<date_created, datetime,>
			,GETDATE()		--,<date_modified, datetime,>
			,@user AS created_by 	--,<created_by, varchar(60),>
			,@user AS modified_by	--,<modified_by, varchar(60),>
			,NEWID() 	--,<rowguid, uniqueidentifier,>
			,pqa.company_id		--,<company_id, int,>
			,pqa.profit_ctr_id		--,<profit_ctr_id, int,>)
			,pqd.ref_sequence_id
		FROM Profile
		inner join FormType on form_type='cc'
		INNER JOIN ProfileQuoteDetail pqd
			ON Profile.profile_id = pqd.profile_id
			AND pqd.status = 'A'
			AND pqd.record_type IN ('S', 'T')
			AND ISNULL(pqd.fee_exempt_flag, 'F') = 'F'
			AND (IsNull(pqd.bill_method, '') <> 'B' OR (IsNull(pqd.bill_method, '') = 'B' AND pqd.show_cust_flag = 'T'))
		INNER JOIN ProfileQuoteApproval pqa
			ON pqd.profile_id = pqa.profile_id
			   AND pqd.company_id = pqa.company_id
			   AND pqd.profit_ctr_id = pqa.profit_ctr_id
		INNER JOIN ProfitCenter
			ON pqd.profit_ctr_id = ProfitCenter.profit_ctr_id
			   AND pqd.company_id = ProfitCenter.company_ID
		WHERE Profile.curr_status_code = 'a'  
			AND FormType.form_type = 'cc'
			AND profile.profile_id = @profile_id
			AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)
UNION ALL
		SELECT 
			@form_id  		--(<form_id, int,>
			,@revision_id 	--,<revision_id, int,>
			,FormType.current_form_version 	--,<form_version_id, int,>
			,Profile.profile_id  			--,<approval_key, int,>
			,PQD.sequence_id 				--,<quotedetail_sequence_id, int,>
			,PQD.record_type 				--,<quotedetail_record_type, char(1),>
			,PQD.service_desc 				--,<quotedetail_service_desc, varchar(60),>
			,PQA.sr_type_code 				--,<approval_sr_type_code, char(1),>
			,ProfitCenter.surcharge_flag 	--,<profitcenter_surcharge_flag, char(1),>
			,PQD.surcharge_price 			--,<quotedetail_surcharge_price, float,>
			,PQD.hours_free_unloading 		--,<quotedetail_hours_free_unload, int,>
			,PQD.hours_free_loading 		--,<quotedetail_hours_free_loading, int,>
			,PQD.demurrage_price 			--,<quotedetail_demurrage_price, float,>
			,PQD.unused_truck_price 		--,<quotedetail_unused_truck_price, float,>
			,PQD.lay_over_charge 		--,<quotedetail_lay_over_charge, float,>
			,PQD.bill_method 			--,<quotedetail_bill_method, char(1),>
			,PQD.price				--,<quotedetail_price, float,>
			,PQD.bill_unit_code 	--,<quotedetail_bill_unit_code, varchar(4),>
			,PQD.min_quantity 		--,<quotedetail_min_quantity, float,>
			,GETDATE() 		--,<date_created, datetime,>
			,GETDATE()		--,<date_modified, datetime,>
			,@user AS created_by 	--,<created_by, varchar(60),>
			,@user AS modified_by	--,<modified_by, varchar(60),>
			,NEWID() 	--,<rowguid, uniqueidentifier,>
			,pqa.company_id		--,<company_id, int,>
			,pqa.profit_ctr_id		--,<profit_ctr_id, int,>)
			,pqd.ref_sequence_id
		FROM Profile 
		inner join FormType on form_type='cc'
		INNER JOIN ProfileQuoteDetail pqd
			ON Profile.profile_id = pqd.profile_id
			AND pqd.status = 'A'
			AND pqd.record_type = 'D'
			AND ISNULL(pqd.fee_exempt_flag, 'F') = 'F'
			AND IsNull(pqd.bill_method, '') <> 'B'
		INNER JOIN ProfileQuoteApproval pqa
			ON pqd.profile_id = pqa.profile_id
			   AND pqd.company_id = pqa.company_id
			   AND pqd.profit_ctr_id = pqa.profit_ctr_id
		INNER JOIN ProfitCenter
			ON pqd.profit_ctr_id = ProfitCenter.profit_ctr_id
			   AND pqd.company_id = ProfitCenter.company_ID
		WHERE Profile.curr_status_code = 'a'  
			AND FormType.form_type = 'cc'
			AND profile.profile_id = @profile_id
			AND EXISTS(SELECT top 1 1 from #copc where #copc.company_id = PQA.company_id AND #copc.profit_ctr_id = PQA.profit_ctr_id)

/*		

-- 2013/12/12 - per Smita:
I think the sp_forms_cc or whichever one inserts records from ProfileQuoteDetail to FormCCdetail 
needs to change to only insert bundled records where ProfileQuoteDetail.print_on_pc_flag = æTÆ


-- 2013/11/13 - This really ought to be callable on its own, with just form_id & revision_id

		DECLARE @temp_version int = (SELECT current_form_version FROM FormType where form_type = 'CC')
		,@temp_generator_id int = (SELECT generator_id FROM Profile where profile_id = @profile_id)

		EXEC Plt_Image..sp_DocProcessing_formview_insert
			@image_id			= @image_id,
			@report				= 'CC',
			@company_id			= NULL,
			@profit_ctr_id		= NULL,
			@form_id			= @form_id,
			@revision_id		= @revision_id,
			@form_version_id	= @temp_version,
			@approval_code		= NULL,
			@profile_id			= @profile_id,
			@file_location		= @file_location,
			@contact_id			= @contact_id,
			@server_flag		= 'S',
			@app_source			= 'WEB',
			@print_pdf			= 1,
			@ip_address			= @ip_address,
			@session_id			= @session_id,
			@added_by			= @user,
			@generator_id		= @temp_generator_id
*/			

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_cc] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_cc] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_cc] TO [EQAI]
    AS [dbo];

