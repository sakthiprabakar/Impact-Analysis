USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_GetUserSecuredProfitCenters]
GO

CREATE PROCEDURE [dbo].[sp_GetUserSecuredProfitCenters] 
    @user_id       INT = NULL,
    @user_code     VARCHAR(20) = NULL,
    @permission_id INT = NULL,
    @action_id     INT = 2,  
    @CompanyID VARCHAR(4000) = NULL
AS
/* ******************************************************************
    Author           : Prabhu 
    Create date      : 03-06-25
    Type             : Stored Procedure
    Ticket           : US152127
    Object Name      : [sp_GetUserSecuredProfitCenters]

    Exec sp_GetUserSecuredProfitCenters 1206,'RICH_G',89,2,'14,15,12,2'
	  
  ***********************************************************************/
BEGIN
    SET NOCOUNT ON;

     IF @user_code IS NULL
    BEGIN
        SELECT @user_code = user_code
        FROM users
        WHERE user_id = @user_id;
    END

    -- Resolve user_id if not provided
    IF @user_id IS NULL
    BEGIN
        SELECT @user_id = user_id
        FROM users
        WHERE user_code = @user_code;
    END

       IF (@action_id IS NULL OR @action_id = '')
        SET @action_id = 2;

        SELECT DISTINCT
        secured_copc.permission_id,
        secured_copc.company_id,
        secured_copc.profit_ctr_id,
        secured_copc.profit_ctr_name,
        secured_copc.waste_receipt_flag,
        secured_copc.workorder_flag,
        CAST(secured_copc.company_id AS VARCHAR(20)) + '|' + CAST(secured_copc.profit_ctr_id AS VARCHAR(20)) AS copc_key,
        RIGHT('00' + CONVERT(VARCHAR, secured_copc.company_id), 2) + '-' +
        RIGHT('00' + CONVERT(VARCHAR, secured_copc.profit_ctr_ID), 2) + ' ' +
        secured_copc.profit_ctr_name AS profit_ctr_name_with_key
    FROM SecuredProfitCenterForGroups secured_copc WITH (NOLOCK)
	INNER JOIN (
        SELECT TRY_CAST(RTRIM(LTRIM(row)) AS INT) AS company_id
        FROM dbo.fn_SplitXsvText(',', 0, @CompanyID)
        WHERE ISNULL(row, '') <> '' AND TRY_CAST(RTRIM(LTRIM(row)) AS INT) IS NOT NULL
    ) AS company_ids
        ON secured_copc.company_id = company_ids.company_id
        WHERE secured_copc.user_id = @user_id
      AND secured_copc.permission_id = @permission_id
      AND secured_copc.action_id = @action_id;
END;
GO
GRANT EXECUTE ON [sp_GetUserSecuredProfitCenters] TO EQWEB, COR_USER, EQAI
GO