
CREATE PROCEDURE sp_forms_ldrdetail
	@form_id				int
	, @revision_id			int
	, @page_number			int
	, @manifest_line_item	int
	, @waste_water_flag		char(3) = NULL	--<ww_or_nww, char(3),>
	, @ldr_subcategory_id	varchar(80) = NULL		--<subcategory, varchar(80),>
	, @waste_managed_id		int = NULL
	, @approval_code		varchar(40)
	, @company_id			int
	, @profit_ctr_id		int
	, @profile_id			int
  
AS

/*********************************************************************************
sp_forms_ldrdetail

10/22/2013 JPB	sp_forms_ldrdetail created from sp_forms_ldr as web gains ability to put multiple
				approvals on 1 ldr form.
*********************************************************************************/

declare @tsdf_code varchar(15)
declare @generator_id int
DECLARE @ldrversion int

SELECT @tsdf_code = tsdf_code
FROM TSDF
WHERE eq_company = @company_id 
AND eq_profit_ctr = @profit_ctr_id
AND eq_flag = 'T' 
AND TSDF_status = 'A'
		
SELECT @generator_id = generator_id 
FROM FormLDR 
where form_id = @form_id 
and profit_ctr_id = @profit_ctr_id

SELECT @ldrversion = current_form_version FROM FormType where form_type = 'LDR'

IF EXISTS (SELECT * FROM [FormLDRDetail] WHERE form_id = @form_id AND revision_id = @revision_id and page_number = @page_number and manifest_line_item = @manifest_line_item) 
	begin
	DELETE FROM [FormLDRDetail] WHERE form_id = @form_id AND revision_id = @revision_id and page_number = @page_number and manifest_line_item = @manifest_line_item
	DELETE FROM [FormXApproval] WHERE form_id = @form_id AND revision_id = @revision_id and company_id = @company_id and profit_ctr_id = @profit_ctr_id and approval_code = @approval_code
	DELETE FROM [FormXWasteCode] WHERE form_id = @form_id AND revision_id = @revision_id and page_number = @page_number and line_item = @manifest_line_item
	DELETE FROM [FormXConstituent] WHERE form_id = @form_id AND revision_id = @revision_id and page_number = @page_number and line_item = @manifest_line_item
	DELETE FROM FormLDRSubcategory WHERE form_id = @form_id AND revision_id = @revision_id and page_number = @page_number and manifest_line_item = @manifest_line_item
	end
		
INSERT INTO [dbo].[FormLDRDetail] (
	[form_id]
	, [revision_id]
	, [form_version_id]
	, [page_number]
	, [manifest_line_item]
	, [ww_or_nww]
	, [subcategory]
	, [manage_id]
	, [approval_code]
	, [approval_key]
	, [company_id]
	, [profit_ctr_id]
	, [profile_id]
)
SELECT DISTINCT 
	@form_id				--<form_id, int,>
	, @revision_id			--<revision_id, int,>
	, FormType.current_form_version --<form_version_id, int,>
	, @page_number		--<page_number, int,>
	, @manifest_line_item		--<manifest_line_item, int,>
	, @waste_water_flag	--<ww_or_nww, char(3),>
	, @ldr_subcategory_id AS subcategory
	, @waste_managed_id	AS manage_id
	, PQA.approval_code			--<approval_code, varchar(40),>
	, Profile.profile_id			--<approval_key, int,>
	, PQA.company_id				--<company_id, int,>
	, PQA.profit_ctr_id			--<profit_ctr_id, int,>
	, Profile.profile_id			--<profile_id, int,>
FROM Profile  
inner join FormType on form_type='ldr'
inner join ProfileQuoteApproval PQA on Profile.profile_id = PQA.profile_id  
WHERE Profile.curr_status_code = 'A'  
AND profile.profile_id = @profile_id
AND pqa.company_id = @company_id
and PQA.profit_ctr_id = @profit_ctr_id


INSERT INTO [dbo].[FormXApproval]
	([form_type]
	,[form_id]
	,[revision_id]
	,[company_id]
	,[profit_ctr_id]
	,[profile_id]
	,[approval_code]
	,[profit_ctr_name]
	,[profit_ctr_EPA_ID])
SELECT DISTINCT
	'LDR'					--<form_type, char(10),>
	, @form_id				--<form_id, int,>
	, @revision_id			--<revision_id, int,>
	, PQA.company_ID			--<company_id, int,>
	, PQA.profit_ctr_id		--<profit_ctr_id, int,>
	, Profile.profile_id		--<profile_id, int,>
	, PQA.approval_code		--<approval_code, varchar(15),>
	, ProfitCenter.profit_ctr_name		--<profit_ctr_name, varchar(50),>
	, ProfitCenter.EPA_ID		--<profit_ctr_EPA_ID, varchar(12),>
FROM Profile
inner join ProfileQuoteApproval PQA 
	on Profile.profile_id = PQA.profile_id
inner join FormLDR 
	on FormLDR.form_id = @form_id 
	and FormLDR.revision_id = @revision_id 
	and FormLDR.company_id = PQA.company_id 
	and FormLDR.profit_ctr_id = PQA.profit_ctr_id
inner join ProfitCenter 
	on PQA.profit_ctr_id = ProfitCenter.profit_ctr_id 
	and PQA.company_id = ProfitCenter.company_id 
WHERE 
	profile.profile_id = @profile_id
	AND pqa.company_id = @company_id
	AND pqa.profit_ctr_id = @profit_ctr_id

			
INSERT INTO [dbo].[FormXWasteCode] (
	[form_id]
	, [revision_id]
	, [page_number]
	, [line_item]
	, [waste_code]
	, [specifier]
	, [waste_code_uid]
)
SELECT
	@form_id						--<form_id, int,>
	, @revision_id				--<revision_id, int,>
	, @page_number							--<page_number, int,>
	, @manifest_line_item							--<line_item, int,>
	, waste_code                -- ,ProfileWasteCode.waste_code --<waste_code, char(4),>
	, 'LDR'						--<specifier, varchar(30),>
	, waste_code_uid              --,ProfileWasteCode.waste_code_uid
FROM dbo.fn_tbl_manifest_waste_codes('profile', @profile_id, @generator_id, @tsdf_code) 
WHERE ISNULL(use_for_storage,0) = 1
	AND display_name <> 'NONE'        -- from ProfileWasteCode  


INSERT INTO [dbo].[FormXConstituent] (
	[form_id]
	, [revision_id]
	, [page_number]
	, [line_item]
	, [const_id]
	, [const_desc]
	, [concentration]
	, [unit]
	, [uhc]
	, [specifier]
)
SELECT   
	@form_id
	, @revision_id
	, @page_number							--<page_number, int,>
	, @manifest_line_item							--<line_item, int,>
	, ProfileConstituent.const_id
	, Constituents.const_desc
	, ProfileConstituent.concentration
	, ProfileConstituent.unit
	, ProfileConstituent.uhc  
	, 'LDR' 
FROM ProfileConstituent  
inner join Constituents on ProfileConstituent.const_id = Constituents.const_id 
WHERE ProfileConstituent.uhc = 'T'  
	AND ProfileConstituent.profile_id = @profile_id

-- Populate FormLDRSubcategory

insert FormLDRSubcategory
select
	@form_id as form_id
	, @revision_id as revision_id
	, @page_number							--<page_number, int,>
	, @manifest_line_item							--<line_item, int,>
	, PLS.ldr_subcategory_id
from
	ProfileLDRSubcategory PLS
where
	PLS.profile_id = @profile_id
		
/*

10/23/13 - JPB - We can't do this automatically anymore, this might not be the last ldrdetail record to be added.
		
		EXEC Plt_Image..sp_DocProcessing_formview_insert
			@image_id			= @image_id,
			@report				= 'LDR',
			@company_id			= NULL,
			@profit_ctr_id		= NULL,
			@form_id			= @form_id,
			@revision_id		= @revision_id,
			@form_version_id	= @ldrversion,
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
			@generator_id		= @generator_id
*/
			

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldrdetail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldrdetail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldrdetail] TO [EQAI]
    AS [dbo];

