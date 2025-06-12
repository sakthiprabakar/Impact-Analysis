CREATE PROCEDURE sp_populate_form_NTN
	@form_id		int,
	@profile_id		int,
	@added_by		varchar(60)
AS
/***************************************************************************************
Populates FORMNORMTENORM tables with data from Profile
Loads to:	PLT_AI
Filename:	L:\IT Apps\SQL\EQAI\sp_populate_form_NTN.sql
PB Object(s): d_rpt_form_norm

05/25/2012 SK created
08/09/2012 SK Updated to use the correct names for Profile Fields
				
sp_populate_form_NTN , 24575, SK
Select * from FormNormtenorm where form_id = 
select * from FormXApproval where form_id = 
****************************************************************************************/
SET NOCOUNT ON

DECLARE	
	@revision_id	int,
	@status			char(1),
	@locked			char(1),
	@source			char(1),
	@current_form_version_id	int
	
SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'NORMTENORM'

INSERT INTO FormNormTenorm
SELECT	
	@form_id,
	@revision_id,
	@current_form_version_id,
	@status,
	@locked,
	@source,
	NULL,
	NULL,
	@profile_id,
	NULL,
	P.generator_id,
	Generator.EPA_ID,
	Generator.generator_name,
	Generator.generator_address_1,
	Generator.generator_address_2,
	Generator.generator_address_3,
	Generator.generator_address_4,
	Generator.generator_address_5,
	Generator.generator_city,
	Generator.generator_state,
	Generator.generator_zip_code,
	Generator.gen_mail_name,
	Generator.gen_mail_addr1,
	Generator.gen_mail_addr2,
	Generator.gen_mail_addr3,
	Generator.gen_mail_addr4,
	Generator.gen_mail_addr5,
	Generator.gen_mail_city,
	Generator.gen_mail_state,
	Generator.gen_mail_zip_code,
	PL.NORM,
	PL.TENORM,
	P.norm_disposal_restriction_exempt,
	P.norm_nuclear_reg_state_license,
	P.gen_process,
	P.shipping_volume_unit_other,
	P.shipping_dates,
	NULL AS signing_name,
	NULL AS signing_company,
	NULL AS signing_title,
	NULL AS signing_date,
	GETDATE() AS date_created,
	GETDATE() AS date_modified,
	@added_by,
	@added_by,
	NULL,
	NULL
FROM Profile P
INNER JOIN Generator 
	ON P.generator_id = Generator.generator_id
INNER JOIN ProfileLab PL
	ON PL.profile_id = P.profile_id	
	AND PL.type = 'A'
WHERE P.profile_id = @profile_id
	AND P.curr_status_code IN ('A','H','P')
	
/******* Populate FormXApproval for this formID ****/
INSERT INTO FormXApproval
SELECT
	'NORMTENORM',
	@form_id,
	@revision_id,
	PQA.company_id,
	PQA.profit_ctr_id,
	@profile_id,
	PQA.approval_code,
	ProfitCenter.profit_ctr_name,
	ProfitCenter.EPA_ID,
	NULL,
	NULL,
	NULL
FROM ProfileQuoteApproval PQA
JOIN ProfitCenter
	ON ProfitCenter.company_ID = PQA.company_id
	AND ProfitCenter.profit_ctr_ID = PQA.profit_ctr_id
WHERE PQA.profile_id = @profile_id	
AND PQA.status = 'A'	
AND ((PQA.company_id = 2 AND PQA.profit_ctr_id = 0) 
		OR (PQA.company_id = 3 AND PQA.profit_ctr_id = 0))
		
/******* Populate FormXUnit for this formID ****/	
INSERT INTO dbo.FormXUnit
SELECT
	'NORMTENORM',
    @form_id,
	@revision_id,
	PSU.bill_unit_code,
	PSU.quantity
FROM dbo.ProfileShippingUnit PSU
WHERE PSU.profile_id = @profile_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_NTN] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_NTN] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_NTN] TO [EQAI]
    AS [dbo];

