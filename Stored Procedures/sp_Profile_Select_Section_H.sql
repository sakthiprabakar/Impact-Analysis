SE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Profile_Select_Section_H]    Script Date: 20-05-2022 11:50:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_H]

     @profile_id INT 

AS

/* ******************************************************************

	Updated By		: Mubarak
	Updated On		: 24th May 2022
	Type			: Stored Procedure
	Object Name		: [sp_Profile_Select_Section_H]



****************************************************************** */
BEGIN

	declare  @rev_id int
	declare @form_id int
	select top 1 @form_id = form_id_wcr from Profile where profile_id = @profile_id
	Select top 1 @rev_id =revision_id from FormWCR where  form_id = @form_id order by revision_id desc

	--select top 1 form_id_wcr,* from Profile where profile_id = '730931'
	declare @signing_name varchar(40)
	declare @signing_title varchar(40)
	declare @signing_company varchar(40)
	declare @signed_on_behalf_of char(1)
	--select @form_id, @rev_id

	select @signing_name = signing_name,@signing_title= signing_title,
	@signing_company = signing_company,@signed_on_behalf_of = signed_on_behalf_of from FormWCR
	where  form_id = @form_id and  revision_id = @rev_id 

    SELECT  ISNULL(specific_technology_requested,'') AS specific_technology_requested ,
    ISNULL(requested_technology,'') AS requested_technology ,
    ISNULL(thermal_process_flag,'') AS thermal_process_flag ,
    ISNULL(other_restrictions_requested,'') AS  other_restrictions_requested,
	ISNULL(GETDATE(),'') AS signing_date,
	(   select FormXUSEFacility.*,(
			
	SELECT Top 1  upc.name as  profit_ctr_name
		FROM ProfitCenter pc
		--JOIN tsdf ts on pc.company_id=ts.eq_company and ts.eq_profit_ctr = pc.profit_ctr_id and ts.TSDF_Status='A'
		join USE_Profitcenter upc on pc.company_id = upc.company_id and pc.profit_ctr_id = upc.profit_ctr_id
		WHERE status = 'A' AND
		waste_receipt_flag = 'T' 
		and upc.company_id=FormXUSEFacility.company_id and upc.profit_ctr_id=FormXUSEFacility.profit_ctr_id) AS profit_ctr_name
		
    from ProfileUSEFacility FormXUSEFacility where FormXUSEFacility.profile_id=@profile_id
	 FOR XML AUTO,TYPE,ROOT ('FacilityList'), ELEMENTS)
    --,ISNULL(signing_name,'') AS signing_name
    --,ISNULL(signing_title,'') AS signing_title ,
    --ISNULL(signing_company,'') AS signing_company
    --,ISNULL(signing_date,'') AS signing_date
    --,
    --(SELECT *
    -- FROM FormXUSEFacility
    -- WHERE  form_id = @formId
    -- FOR XML AUTO,TYPE,ROOT ('FacilityList'), ELEMENTS)
    --select PrintName,Title,CertifiedDate from ProfileCertificationRef
    from Profile
    where profile_id = @profile_id
    FOR XML RAW ('SectionH'), ROOT ('ProfileModel'), ELEMENTS

END

GO

GRANT EXEC ON [dbo].[sp_Profile_Select_Section_H] TO COR_USER;

GO
