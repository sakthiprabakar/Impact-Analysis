
Create Procedure sp_get_profile_info (
	@id 		int
)
/* ***********************************************************
Procedure    : sp_get_profile_info
Database     : Plt_ai 
Created      : May 9 2012 - CRG

Description  : Get profile info for the web form pages. Used in 
	Form_Helpers.Profile class.

History:
	05/09/2012 CRG	Created
	07/18/2013 JPB	Added pwc. prefix in waste code select of sequence_id to avoid ambiguity
		during Texas Waste Code update (a sequence_id was added to WasteCode)
	08/01/2013 JPB	Modified for TX Waste Codes
	10/7/2013	JPB	Modified WasteCode select to get display_name and description from the WasteCode table.

Examples:
	sp_get_profile_info 224327

*********************************************************** */
AS

declare @generator_id INT, @customer_id INT

SELECT 
	@generator_id = generator_id
	,@customer_id = customer_id
	FROM profile
		WHERE profile_id = @id
		
SELECT top(1) * from Profile where profile_id = @id

SELECT top(1) * FROM Generator where generator_id = @generator_id

SELECT top(1) * FROM Customer WHERE customer_ID = @customer_id

SELECT pwc.profile_id, pwc.primary_flag, pwc.waste_code_uid, wc.display_name as waste_code, wc.waste_code_desc, pwc.added_by, pwc.date_added, pwc.rowguid, pwc.sequence_id, pwc.sequence_flag 
	FROM ProfileWasteCode pwc 
	INNER JOIN WasteCode wc ON wc.waste_code_uid = pwc.waste_code_uid and wc.status = 'A'
	WHERE profile_id = @id
	ORDER BY pwc.sequence_id, wc.display_name;


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_profile_info] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_profile_info] TO [COR_USER]
    AS [dbo];


