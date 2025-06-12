USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS sp_idem_solid_waste_inbound
GO

CREATE PROCEDURE [dbo].[sp_idem_solid_waste_inbound]
    @receipt_start_date datetime = NULL,
    @receipt_end_date datetime = NULL,
    @copc_list varchar(4000) = NULL, -- '14|6'
    @user_code varchar(100) =  NULL,
    @permission_id int = NULL
AS
/* **********************************************************************************  

 Author  : Prabhu  
 Updated On : 10-JUL-2024  
 Type  : Store Procedure   
 Object Name : [dbo].[sp_idem_solid_waste_inbound]

 Ticket      : Task 17683
 Description : IDEM Solid Waste Inbound
  
   sp_idem_solid_waste_inbound  
      @receipt_start_date = '1/1/2023'
      , @receipt_end_date = '5/30/2024'
      , @copc_list = '14|6'
      , @user_code = 'jonathan'
      , @permission_id = 353

********************************************************************************** */  
BEGIN
    
    DECLARE @start_date DATETIME = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);  
    DECLARE @i_receipt_start_date DATETIME = ISNULL(@receipt_start_date, @start_date);  
    DECLARE @i_receipt_end_date DATETIME = ISNULL(@receipt_end_date, DATEADD(DAY, -1, DATEADD(MONTH, 1, @start_date)));  

	IF DATEPART(hh, @i_receipt_start_date) = 0
    SET @i_receipt_end_date = @i_receipt_end_date + 0.99999

  
    DROP TABLE IF EXISTS #tbl_profit_center_filter;
    CREATE TABLE #tbl_profit_center_filter (
        company_id int,
        profit_ctr_id int
    );

     IF ISNULL(@copc_list, '') <> 'ALL'
    BEGIN
        INSERT INTO #tbl_profit_center_filter (company_id, profit_ctr_id)
        SELECT DISTINCT 
            secured_copc.company_id, 
            secured_copc.profit_ctr_id 
        FROM 
            SecuredProfitCenter secured_copc (NOLOCK)
        INNER JOIN 
            dbo.fn_SplitXsvText(',', 0, @copc_list) AS selected_copc
            ON secured_copc.company_id = LTRIM(RTRIM(SUBSTRING(selected_copc.row, 1, CHARINDEX('|', selected_copc.row) - 1)))
            AND secured_copc.profit_ctr_id = LTRIM(RTRIM(SUBSTRING(selected_copc.row, CHARINDEX('|', selected_copc.row) + 1, LEN(selected_copc.row) - CHARINDEX('|', selected_copc.row))))
        WHERE 
            secured_copc.permission_id = @permission_id
            AND secured_copc.user_code = @user_code;
    END
    ELSE
    BEGIN
        INSERT INTO #tbl_profit_center_filter (company_id, profit_ctr_id)
        SELECT DISTINCT 
            secured_copc.company_id, 
            secured_copc.profit_ctr_id
        FROM 
            SecuredProfitCenter secured_copc (NOLOCK)
        WHERE 
            secured_copc.permission_id = @permission_id
            AND secured_copc.user_code = @user_code;
    END

       ;WITH rh AS (
        SELECT 
            r.receipt_id, 
            r.line_id, 
            r.company_id, 
            r.profit_ctr_id,
            r.receipt_date, 
            r.customer_id, 
            r.receipt_status, 
            r.fingerpr_status,
            r.manifest, 
            r.manifest_flag, 
            r.manifest_form_type, 
            r.manifest_page_num,
            r.manifest_line, 
            r.manifest_quantity, 
            r.manifest_unit, 
            r.profile_id,
            r.generator_id, 
            r.treatment_id
        FROM 
            receipt r
        JOIN 
            #tbl_profit_center_filter f 
            ON r.company_id = f.company_id AND r.profit_ctr_id = f.profit_ctr_id
        WHERE 
            r.trans_mode = 'I'
            AND r.receipt_status NOT IN ('V', 'R')
            AND r.fingerpr_status NOT IN ('V', 'R')
            AND r.trans_type = 'D'
            AND r.receipt_date BETWEEN @i_receipt_start_date AND @i_receipt_end_date
    )
    SELECT 
        dbo.fn_receipt_weight_line(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id) AS line_weight,
        g.EPA_ID, 
        g.generator_name, 
        g.generator_id, 
        g.generator_state, 
        c.county_name,
        p.approval_desc,
        r.company_id, 
        r.profit_ctr_id, 
        r.receipt_id, 
        r.line_id, 
        r.receipt_date, 
        r.customer_id, 
        r.receipt_status, 
        r.fingerpr_status, 
        r.manifest, 
        r.manifest_flag, 
        r.manifest_form_type, 
        r.manifest_page_num, 
        r.manifest_line, 
        r.manifest_quantity, 
        r.manifest_unit,
        t.treatment_id, 
        t.wastetype_category, 
        t.wastetype_description, 
        t.disposal_service_desc, 
        t.treatment_process_process
    FROM 
        rh r
    JOIN 
        generator g ON r.generator_id = g.generator_id
    LEFT OUTER JOIN 
        county c ON g.generator_county = c.county_code AND c.state = g.generator_state
    JOIN 
        profile p ON r.profile_id = p.profile_id
    JOIN 
        treatment t ON r.treatment_id = t.treatment_id AND r.company_id = t.company_id AND r.profit_ctr_id = t.profit_ctr_id
    ORDER BY 
        r.receipt_date, 
        r.company_id, 
        r.profit_ctr_id, 
        r.receipt_id, 
        r.line_id;

    -- Drop temporary table
    DROP TABLE IF EXISTS #tbl_profit_center_filter;
END;
GO

GRANT EXECUTE ON sp_idem_solid_waste_inbound TO eqweb, eqai, cor_user;
GO
