USE [PLT_AI]

GO
DROP PROCEDURE IF EXISTS [sp_COR_ProfileFormWCR_Count]
GO

CREATE PROCEDURE [dbo].[sp_COR_ProfileFormWCR_Count]
    @web_userid VARCHAR(100)
AS
/* ******************************************************************
---- Author:		Samson
---- Create date:	14th Apirl,2025
---- Description:	US147846 Create API to retrieve COR2 Waste Profiles count information
-- EXEC [dbo].[sp_COR_ProfileFormWCR_Count]  @web_userid='nyswyn100'

****************************************************************** */
BEGIN
    SET NOCOUNT ON;

    if OBJECT_ID('tempdb..#temp_forms') is not null drop table #temp_forms;

    -- Temporary table for WCR Forms
    CREATE TABLE #temp_forms (
        form_id int,
        revision_id int,
        profile_id int,
        approval_code varchar(4000),
        status char(1),
        display_status varchar(60),
        waste_common_name varchar(50),
        generator_id int,
        generator_name varchar(75),
        generator_type varchar(20),
        epa_id varchar(12),
        site_type varchar(40),
        customer_id int,
        cust_name varchar(75),
        date_modified datetime,
        created_by varchar(100),
        modified_by varchar(100),	
        copy_source varchar(10),
        tsdf_type varchar(10),
        edit_allowed char(1),
        _row int,
        totalcount int
    );

    INSERT INTO #temp_forms(
    form_id,
    revision_id,
    profile_id,
    approval_code,
    status,
    display_status,
    waste_common_name,
    generator_id,
    generator_name,
    generator_type,
    epa_id,
    site_type,
    customer_id,
    cust_name,
    date_modified,
    created_by,
    modified_by,
    copy_source,
    tsdf_type,
    edit_allowed,
    _row,
    totalcount
)
EXEC sp_COR_FormWCR_List 
    @web_userid = @web_userid,
    @status_list = 'all',
    @page = 1,
    @perpage = 999999999;

    if OBJECT_ID('tempdb..#temp_profiles') is not null drop table #temp_profiles;
    -- Temporary tables for Profiles
    CREATE TABLE  #temp_profiles(
        profile_id int,
        approval_code_list varchar(4000),
        pro_name varchar(50),
        generator_id int,
        gen_by varchar(75),
        Generator_EPA_ID varchar(12),
        site_type varchar(40),
        RCRA_status varchar(20),
        updated_date datetime,
        customer_id int,
        updated_by varchar(100),
        expired_date datetime,
        profile varchar(100),
        status varchar(40),
        reapproval_allowed char(1),
        inactive_flag char(1),
        waste_code_list varchar(max),
        document_update_status char(1),
        tsdf_type varchar(10),
        totalcount int
    );

    if OBJECT_ID('tempdb..#temp_profiles_under_review') is not null drop table #temp_profiles_under_review;
    CREATE TABLE  #temp_profiles_under_review(
        profile_id int,
        approval_code_list varchar(4000),
        pro_name varchar(50),
        generator_id int,
        gen_by varchar(75),
        Generator_EPA_ID varchar(12),
        site_type varchar(40),
        RCRA_status varchar(20),
        updated_date datetime,
        customer_id int,
        updated_by varchar(100),
        expired_date datetime,
        profile varchar(100),
        status varchar(40),
        reapproval_allowed char(1),
        inactive_flag char(1),
        waste_code_list varchar(max),
        document_update_status char(1),
        tsdf_type varchar(10),
        totalcount int
    );

    -- Insert into #temp_profiles (non-under-review)
    INSERT INTO #temp_profiles (
        profile_id,
        approval_code_list,
        pro_name,
        generator_id,
        gen_by,
        Generator_EPA_ID,
        site_type,
        RCRA_status,
        updated_date,
        customer_id,
        updated_by,
        expired_date,
        profile,
        status,
        reapproval_allowed,
        inactive_flag,
        waste_code_list,
        document_update_status,
        tsdf_type,
        totalcount
    )
    EXEC sp_COR_Profile_List
        @web_userid = @web_userid,
        @status_list = 'Approved,For Renewal,Expired',
        @page = 1,
        @perpage = 999999999;

    -- Insert into #temp_profiles_under_review
    INSERT INTO #temp_profiles_under_review
    (
        profile_id,
        approval_code_list,
        pro_name,
        generator_id,
        gen_by,
        Generator_EPA_ID,
        site_type,
        RCRA_status,
        updated_date,
        customer_id,
        updated_by,
        expired_date,
        profile,
        status,
        reapproval_allowed,
        inactive_flag,
        waste_code_list,
        document_update_status,
        tsdf_type,
        totalcount
    )
    EXEC sp_COR_Profile_List
        @web_userid = @web_userid,
        @status_list = 'Approved,For Renewal,Expired',
        @page = 1,
        @perpage = 999999999,
        @under_review = 'U';

    -- Final JSON output
   SELECT 
(
    SELECT 
        (SELECT COUNT(*) FROM #temp_forms WHERE display_status = 'Pending Customer Response') AS pending_action,
        (SELECT COUNT(*) FROM #temp_forms WHERE display_status = 'Draft') AS draft,
        (SELECT COUNT(*) FROM #temp_forms WHERE display_status IN ('Ready For Submission', 'Pending Signature')) AS pending_signature,
        (SELECT COUNT(*) FROM #temp_forms WHERE display_status IN ('Submitted', 'Accepted')) AS submitted,
        (SELECT COUNT(*) FROM #temp_profiles_under_review WHERE status IN ('Approved', 'For Renewal', 'Expired')) AS in_review,
        (SELECT COUNT(*) FROM #temp_profiles WHERE status = 'For Renewal') AS expiring_soon,
        (SELECT COUNT(*) FROM #temp_profiles WHERE status = 'Expired') AS expired,
        (SELECT COUNT(*) FROM #temp_profiles WHERE status = 'Approved') AS approved
    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
) AS profile_counts;

DROP TABLE #temp_forms;
DROP TABLE #temp_profiles;
DROP TABLE #temp_profiles_under_review;

END

GRANT EXEC ON [dbo].[sp_COR_ProfileFormWCR_Count] TO COR_USER;

GO