
CREATE PROCEDURE sp_forms_ldr
	@form_id			int
	, @revision_id		int
	, @customer_id		int
	, @generator_id		int
	, @docManifest		varchar(255)
    , @company_id		int
    , @profit_ctr_id	int
	, @user				varchar(255)
AS

/*********************************************************************************
05/14/2012 CRG Forms are being changed to go from new -> sign. You wont have to save/view seperately
	The SP should save the form and just return the image ID to the application.
10/25/2011 CRG Changed SP to use FormXApproval instead of storing approval info in 
	the form table
10/17/2011 CRG	Created
05/02/2013 JPB	waste_code_uid column added
10/22/2013 JPB	Rewrite to separately handle FormLDR and FormLDRDetail now that web is changing
				to handle multiple approvals per LDR (1 approval per ldrdetail)
11/15/2013	JPB	Added deletes ahead of the inserts

*********************************************************************************/

IF EXISTS (SELECT * FROM [FormLDR] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormLDR] WHERE form_id = @form_id AND revision_id = @revision_id

IF EXISTS (SELECT * FROM [FormLDRDetail] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormLDRDetail] WHERE form_id = @form_id AND revision_id = @revision_id

IF EXISTS (SELECT * FROM [FormXWasteCode] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormXWasteCode] WHERE form_id = @form_id AND revision_id = @revision_id

IF EXISTS (SELECT * FROM [FormXConstituent] WHERE form_id = @form_id AND revision_id = @revision_id)
	DELETE FROM [FormXConstituent] WHERE form_id = @form_id AND revision_id = @revision_id

INSERT INTO [dbo].[FormLDR] (
	[form_id]
	,[revision_id]
	,[form_version_id]
	,[customer_id_from_form]
	,[customer_id]
	,[app_id]
	,[status]
	,[locked]
	,[source]
	,[company_id]
	,[profit_ctr_id]
	,[date_created]
	,[date_modified]
	,[created_by]
	,[modified_by]
	,[generator_name]
	,[generator_epa_id]
	,[generator_address1]
	,[generator_city]
	,[generator_state]
	,[generator_zip]
	,[manifest_doc_no]
	,[generator_id]
	,[generator_address2]
	,[generator_address3]
	,[generator_address4]
	,[generator_address5]
	,[profitcenter_epa_id]
	,[profitcenter_profit_ctr_name]
	,[profitcenter_address_1]
	,[profitcenter_address_2]
	,[profitcenter_address_3]
	,[profitcenter_phone]
	,[profitcenter_fax]
	,[rowguid]  
)
SELECT
	@form_id
	, @revision_id
	, FormType.current_form_version 	--	<form_version_id int>
	, NULL as customer_id_from_form  	--	<customer_id_from_form int>
	, @customer_id  	--	<customer_id int>
	, NULL as app_id  	--	<app_id varchar(20)>
	, 'A' 	--	<status char(1)>
	, 'U' 	--	<locked char(1)>
	, 'W' 	--	<source char(1)>
	, ProfitCenter.company_id
	, ProfitCenter.profit_ctr_id
	, GETDATE()	--	<date_created datetime>
	, GETDATE()   	--	<date_modified datetime>
	, @user 	--	<created_by varchar(60)>
	, @user  --	<modified_by varchar(60)>
	, Generator.generator_name 	--	<generator_name varchar(40)>
	, Generator.EPA_ID 	--	<generator_epa_id varchar(12)>
	, Generator.generator_address_1 	--	<generator_address1 varchar(40)>
	, Generator.generator_city	--	<generator_city varchar(40)>
	, Generator.generator_state 	--	<generator_state varchar(2)>
	, Generator.generator_zip_code 	--	<generator_zip varchar(10)>
	, @docManifest   	--	<manifest_doc_no varchar(20)>
	, Generator.generator_id 	--	<generator_id int>
	, Generator.generator_address_2 	--	<generator_address2 varchar(40)>
	, Generator.generator_address_3  	--	<generator_address3 varchar(40)>
	, Generator.generator_address_4   	--	<generator_address4 varchar(40)>
	, Generator.generator_address_5   	--	<generator_address5 varchar(40)>
	, ProfitCenter.epa_id				--	<profitcenter_epa_id varchar(12)>
	, ProfitCenter.profit_ctr_name		--	<profitcenter_profit_ctr_name varchar(50)>
	, ProfitCenter.address_1  	--	<profitcenter_address_1 varchar(40)>
	, ProfitCenter.address_2  	--	<profitcenter_address_2 varchar(40)>
	, ProfitCenter.address_3  	--	<profitcenter_address_3 varchar(40)>
	, ProfitCenter.phone  	--	<profitcenter_phone varchar(14)>
	, ProfitCenter.fax	--	<profitcenter_fax varchar(14)>
	, newid() --<rowguid, uniqueidentifier,>
FROM ProfitCenter
LEFT JOIN Generator on generator.generator_id = @generator_id
JOIN FormType ON FormType.form_type = 'LDR'
WHERE ProfitCenter.company_id = @company_id
AND ProfitCenter.profit_ctr_id = @profit_ctr_id
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_ldr] TO [EQAI]
    AS [dbo];

