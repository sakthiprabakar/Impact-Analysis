USE [PLT_AI]
GO

CREATE PROCEDURE [dbo].[sp_Validate_Section_L]
	-- Add the parameters for the stored procedure here
		@formid INT,
		@Revision_ID int
AS


/* ******************************************************************

	Updated By		: Vinoth D
	Updated On		: 02-12-2022
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_L]


	Procedure to validate Section Facility required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID

Samples:
 EXEC [sp_Validate_Section_L] @form_id,@revision_ID
 EXEC [sp_Validate_Section_L] 600945, 1

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  	DECLARE @FormStatusFlag varchar(1) = 'Y'
	DECLARE @routing_facility NVARCHAR(5)
	DECLARE @modified_by NVARCHAR(60)
	Declare @approval_code nvarchar(20)
	Declare @profile_id int
	
	SELECT TOP 1 @routing_facility = routing_facility, 
	@modified_by = modified_by, 
	@approval_code = approval_code,
	@profile_id = profile_id
	--,
	--@formid = form_id,
	--@Revision_ID = revision_id
	FROM FormWCR Where form_id = @formid AND revision_id = @Revision_ID

	drop table if exists #t_approvalcodes
	CREATE Table #t_approvalcodes(approval_code nvarchar(30), profile_id int, form_id int, revision_id int)

	declare @noofapprovalcodes int =0;
	if(isnull(@approval_code, '') <> '')
	begin
		insert into #t_approvalcodes
		exec cor_db.dbo.sp_cor_user_profile_approvalcode @approval_code,'', @formid, @Revision_ID

		SET @noofapprovalcodes= (
		
		select count(approval_code) from plt_ai.dbo.formwcr Where approval_code = @approval_code and profile_id not in (select profile_id from #t_approvalcodes)
	 )
	end

	IF(@routing_facility IS NULL OR @routing_facility = '' OR @noofapprovalcodes > 1)
	BEGIN
		SET @FormStatusFlag='P'
	END

	--IF NOT EXISTS(SELECT * FROM FormXUSEFacility WHERE form_id=@formid AND revision_id=@Revision_ID)
	--BEGIN
	--	SET @FormStatusFlag='P'
	--END

		-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND SECTION ='SL'))
	BEGIN
		INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'SL',@FormStatusFlag,getdate(),@modified_by,getdate(),@modified_by,1)
	END
	ELSE 
	BEGIN
		UPDATE FormSectionStatus SET section_status = @FormStatusFlag WHERE FORM_ID = @formid AND SECTION = 'SL'
	END

END


GO

GRANT EXECUTE ON [dbo].[sp_Validate_Section_L] TO COR_USER;

GO