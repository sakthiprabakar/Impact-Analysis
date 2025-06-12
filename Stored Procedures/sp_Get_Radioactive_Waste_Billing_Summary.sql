DROP PROCEDURE IF EXISTS [dbo].[sp_Get_Radioactive_Waste_Billing_Summary]; 
GO

CREATE PROCEDURE [dbo].[sp_Get_Radioactive_Waste_Billing_Summary]
    @copc_list      VARCHAR(4000) = 'ALL',  -- Moved copc_list to the first parameter
    @date_from      DATETIME,  
    @date_to        DATETIME,  
    @user_code      VARCHAR(20),
    @permission_id  INT
AS
BEGIN
    /***************************************************************************************
    Author: Prabhu  
    Updated On: 05-Dec-2024  
    Type: Stored Procedure   
    Object Name: [dbo].[sp_Get_Radioactive_Waste_Billing_Summary]

    Ticket: Task 95703
    Description: EQAI revenue report for all radioactive waste received.

    Example execution:
        EXEC [dbo].[sp_Get_Radioactive_Waste_Billing_Summary]
        @copc_list = 'ALL',
        @date_from = '10/1/2022',
        @date_to = '10/1/2024',
        @user_code = 'jonathan',
        @permission_id = 363;

    ************************************************************************************************/

    SET NOCOUNT ON;

    -- Declare variables for date range
    DECLARE @start_date DATETIME = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);
    DECLARE 
        @i_date_start DATETIME = ISNULL(@date_from, @start_date),
        @i_date_end   DATETIME = ISNULL(@date_to, DATEADD(DAY, -1, DATEADD(MONTH, 1, @start_date)));

     IF DATEPART(HOUR, @i_date_end) = 0
    BEGIN
        SET @i_date_end = DATEADD(SECOND, 0.99999, @i_date_end);
    END

    -- Declare a temporary table to store filtered profit center data
    DROP TABLE IF EXISTS #tbl_profit_center_filter;
    CREATE TABLE #tbl_profit_center_filter (
        company_id INT,
        profit_ctr_id INT
    );

    -- Insert profit center data based on the copc_list filter
    IF @copc_list <> 'ALL'
    BEGIN
        INSERT INTO #tbl_profit_center_filter (company_id, profit_ctr_id)
        SELECT secured_copc.company_id, secured_copc.profit_ctr_id
        FROM dbo.SecuredProfitCenter AS secured_copc WITH (NOLOCK)
        INNER JOIN (
            SELECT 
                RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|', row) - 1))) AS company_id,
                RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|', row) + 1, LEN(row) - (CHARINDEX('|', row) - 1)))) AS profit_ctr_id
            FROM dbo.fn_SplitXsvText(',', 0, @copc_list)
            WHERE ISNULL(row, '') <> ''
        ) AS selected_copc
        ON secured_copc.company_id = selected_copc.company_id
        AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
        AND secured_copc.permission_id = @permission_id
        AND secured_copc.user_code = @user_code;
    END
    ELSE
    BEGIN
        INSERT INTO #tbl_profit_center_filter (company_id, profit_ctr_id)
        SELECT secured_copc.company_id, secured_copc.profit_ctr_id
        FROM dbo.SecuredProfitCenter AS secured_copc WITH (NOLOCK)
        WHERE secured_copc.permission_id = @permission_id
        AND secured_copc.user_code = @user_code;
    END

    -- Create temporary table for Secured Customers
    DROP TABLE IF EXISTS #Secured_Customer;
    SELECT DISTINCT customer_id, cust_name 
    INTO #Secured_Customer    
    FROM SecuredCustomer sc
    WHERE sc.user_code = @user_code    
      AND sc.permission_id = @permission_id;    

    -- Drop #rad_profiles if it already exists
    DROP TABLE IF EXISTS #rad_profiles;

    SELECT DISTINCT profile_id
    INTO #rad_profiles
    FROM profilelab pl
    WHERE pl.radioactive_waste = 'T' 
      AND pl.type = 'A';

    -- Select the billing summary data
    SELECT 
        b.company_id, 
        b.profit_ctr_id, 
        pc.profit_ctr_name, 
        b.customer_id, 
        c.cust_name, 
        c.customer_type, 
        b.generator_id, 
        b.generator_name, 
        b.profile_id, 
        b.approval_code,
        SUM(b.total_extended_amt) AS 'Total Amt Billed'
    FROM billing b WITH (NOLOCK)
    JOIN customer c WITH (NOLOCK) 
        ON b.customer_id = c.customer_id
    JOIN #Secured_Customer sc
        ON b.customer_id = sc.customer_id
    JOIN #tbl_profit_center_filter pc_filter
        ON b.company_id = pc_filter.company_id
        AND b.profit_ctr_id = pc_filter.profit_ctr_id
    JOIN profitcenter pc WITH (NOLOCK) 
        ON b.company_id = pc.company_id 
        AND b.profit_ctr_id = pc.profit_ctr_id
    WHERE b.profile_id IN (SELECT profile_id FROM #rad_profiles)
      AND b.billing_date BETWEEN @i_date_start AND @i_date_end
      AND b.invoice_id IS NOT NULL
    GROUP BY 
        b.company_id, 
        b.profit_ctr_id, 
        pc.profit_ctr_name, 
        b.customer_id, 
        c.cust_name, 
        c.customer_type, 
        b.generator_id, 
        b.generator_name, 
        b.profile_id, 
        b.approval_code
    ORDER BY 
        b.company_id, 
        b.profit_ctr_id, 
        pc.profit_ctr_name, 
        b.customer_id, 
        c.cust_name, 
        c.customer_type, 
        b.generator_id, 
        b.generator_name, 
        b.profile_id, 
        b.approval_code;

    -- Drop temporary table for radioactive profiles
    DROP TABLE IF EXISTS #rad_profiles;

END;
GO

GO
GRANT EXEC ON [dbo].[sp_Get_Radioactive_Waste_Billing_Summary] TO COR_USER
GO
GRANT EXECUTE ON [dbo].[sp_Get_Radioactive_Waste_Billing_Summary]  TO EQWEB 
GO
GRANT EXECUTE ON [dbo].[sp_Get_Radioactive_Waste_Billing_Summary]  TO EQAI 
GO