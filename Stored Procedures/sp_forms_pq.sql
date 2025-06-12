
CREATE PROCEDURE sp_forms_pq
	@user varchar(255)
	,@revision_id int
	,@form_id int 
	,@debug int = 0
	,@session_id varchar(12)
	,@ip_address varchar(40) = ''
	,@image_id int
	,@contact_id int = 0
	,@file_location varchar(255) = NULL
	,@profile_id int
	,@process_questions_reply text
	,@profile_blank_reply text
	,@necessary_questions_reply text
	,@customer_stipulations_reply text
AS
/*********************************************************************************
sp_forms_pq

Populates a pq form from parameters

6/20/2011 CRG - Created

*********************************************************************************/

	DECLARE @temp_version int = (SELECT current_form_version FROM FormType where form_type = 'pq')
		,@temp_generator_id int = (SELECT generator_id FROM Profile where profile_id = @profile_id)
		
INSERT INTO [dbo].[FormPQ]
        ( [form_id] ,
          [revision_id] ,
          [form_version_id] ,
          [ref_form_id] ,
          [customer_id] ,
          [status] ,
          [locked] ,
          [source] ,
          [preapproval_key] ,
          [approval_code] ,
          [approval_key] ,
          [company_id] ,
          [profit_ctr_id] ,
          [signing_name] ,
          [signing_company] ,
          [signing_title] ,
          [signing_date] ,
          [date_created] ,
          [date_modified] ,
          [created_by] ,
          [modified_by] ,
          [tracking_id] ,
          [date_form] ,
          [waste_common_name] ,
          [sample_needed] ,
          [MSDS_needed] ,
          [EPA_ID_needed] ,
          [gen_signature_needed] ,
          [waste_code_needed] ,
          [D_code_chart_needed] ,
          [DOT_shipping_name_needed] ,
          [site_history_needed] ,
          [site_map_needed] ,
          [cleanup_plan_needed] ,
          [analysis_needed] ,
          [profile_blank_flag] ,
          [profile_blank_text] ,
          [profile_blank_reply] ,
          [UHC_flag] ,
          [process_description_flag] ,
          [process_description_detail] ,
          [process_questions_flag] ,
          [process_questions_text] ,
          [process_questions_reply] ,
          [necessary_questions_flag] ,
          [necessary_questions_text] ,
          [necessary_questions_reply] ,
          [customer_stipulations_flag] ,
          [customer_stipulations_text] ,
          [customer_stipulations_reply] ,
          [pendings_resolved_flag] ,
          [pendings_resolved_initials] ,
          [pendings_resolved_date] ,
          [cust_name] ,
          [generator_name] ,
          [EPA_ID] ,
          [generator_id] ,
          [gen_mail_addr1] ,
          [gen_mail_addr2] ,
          [gen_mail_addr3] ,
          [gen_mail_addr4] ,
          [gen_mail_addr5] ,
          [gen_mail_city] ,
          [gen_mail_state] ,
          [gen_mail_zip_code] ,
          [profitcenter_epa_id] ,
          [profitcenter_profit_ctr_name] ,
          [profitcenter_address_1] ,
          [profitcenter_address_2] ,
          [profitcenter_address_3] ,
          [profitcenter_phone] ,
          [profitcenter_fax] ,
          [rowguid] ,
          [profile_id]
        )
SELECT  @form_id , -- form_id - int
          @revision_id, -- revision_id - int
          @temp_version, -- form_version_id - int
          ref_form_id, -- ref_form_id - int
          customer_id, -- customer_id - int
          status, -- status - char(1)
          'A', -- locked - char(1)
          'W', -- source - char(1)
          preapproval_key, -- preapproval_key - int
          approval_code, -- approval_code - varchar(15)
          approval_key, -- approval_key - int
          company_id, -- company_id - int
          profit_ctr_id, -- profit_ctr_id - int
          NULL, -- signing_name - varchar(40)
          NULL, -- signing_company - varchar(40)
          NULL, -- signing_title - varchar(40)
          NULL,  -- signing_date - datetime
          GETDATE(), -- date_created - datetime
          GETDATE(), -- date_modified - datetime
          @user, -- created_by - varchar(60)
          @user, -- modified_by - varchar(60)
          tracking_id, -- tracking_id - int
          date_form, -- date_form - datetime
          waste_common_name, -- waste_common_name - varchar(50)
          sample_needed, -- sample_needed - char(1)
          MSDS_needed, -- MSDS_needed - char(1)
          EPA_ID_needed, -- EPA_ID_needed - char(1)
          gen_signature_needed, -- gen_signature_needed - char(1)
          waste_code_needed, -- waste_code_needed - char(1)
          D_code_chart_needed, -- D_code_chart_needed - char(1)
          DOT_shipping_name_needed, -- DOT_shipping_name_needed - char(1)
          site_history_needed, -- site_history_needed - char(1)
          site_map_needed, -- site_map_needed - char(1)
          cleanup_plan_needed, -- cleanup_plan_needed - char(1)
          analysis_needed, -- analysis_needed - char(1)
          profile_blank_flag, -- profile_blank_flag - char(1)
          profile_blank_text, -- profile_blank_text - text
          @profile_blank_reply, -- profile_blank_reply - text
          UHC_flag, -- UHC_flag - char(1)
          process_description_flag, -- process_description_flag - char(1)
          process_description_detail, -- process_description_detail - char(1)
          process_questions_flag, -- process_questions_flag - char(1)
          process_questions_text, -- process_questions_text - text
          @process_questions_reply , -- process_questions_reply - text
          necessary_questions_flag, -- necessary_questions_flag - char(1)
          necessary_questions_text, -- necessary_questions_text - text
          @necessary_questions_reply, -- necessary_questions_reply - text
          customer_stipulations_flag, -- customer_stipulations_flag - char(1)
          customer_stipulations_text, -- customer_stipulations_text - text
		  @customer_stipulations_reply, -- customer_stipulations_reply - text
          pendings_resolved_flag, -- pendings_resolved_flag - char(1)
          NULL, -- pendings_resolved_initials - varchar(10)
          NULL, -- pendings_resolved_date - datetime
          cust_name, -- cust_name - varchar(40)
          generator_name, -- generator_name - varchar(40)
          EPA_ID, -- EPA_ID - varchar(12)
          generator_id, -- generator_id - int
          gen_mail_addr1, -- gen_mail_addr1 - varchar(40)
          gen_mail_addr2, -- gen_mail_addr2 - varchar(40)
          gen_mail_addr3, -- gen_mail_addr3 - varchar(40)
          gen_mail_addr4, -- gen_mail_addr4 - varchar(40)
          gen_mail_addr5, -- gen_mail_addr5 - varchar(40)
          gen_mail_city, -- gen_mail_city - varchar(40)
          gen_mail_state, -- gen_mail_state - varchar(2)
          gen_mail_zip_code, -- gen_mail_zip_code - varchar(15)
          profitcenter_epa_id, -- profitcenter_epa_id - varchar(12)
          profitcenter_profit_ctr_name, -- profitcenter_profit_ctr_name - varchar(50)
          profitcenter_address_1, -- profitcenter_address_1 - varchar(40)
          profitcenter_address_2, -- profitcenter_address_2 - varchar(40)
          profitcenter_address_3, -- profitcenter_address_3 - varchar(40)
          profitcenter_phone, -- profitcenter_phone - varchar(14)
          profitcenter_fax, -- profitcenter_fax - varchar(14)
          NEWID(), -- rowguid - uniqueidentifier
          profile_id  -- profile_id - int
        FROM dbo.FormPQ WHERE form_id = @form_id AND revision_id = (SELECT MAX(revision_id) FROM FormPQ WHERE form_id = @form_id)
        
		
		EXEC Plt_Image..sp_DocProcessing_formview_insert
			@image_id			= @image_id,
			@report				= 'pq',
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
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_pq] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_pq] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_pq] TO [EQAI]
    AS [dbo];

