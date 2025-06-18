USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_hub_po_balance_report]
GO

CREATE PROCEDURE [dbo].[sp_hub_po_balance_report]
    @customer_id INT = NULL,
    @customer_type VARCHAR(20) = NULL,
    @transaction_date_start DATETIME = NULL,
    @transaction_date_end DATETIME = NULL,
    @user_code VARCHAR(20) = NULL,    
    @permission_id INT,
	@purchase_order VARCHAR(20) = NULL,
	@release_code VARCHAR(20) = NULL,
	@invoice_code VARCHAR(16) = NULL,
	@receipt_id int= NULL,
	@status_code_list varchar(20), --'I,S,N,H',
	@trans_source_list VARCHAR(20) -- 'R, W'
AS
BEGIN

/***************************************************************************************
    Author: Prabhu  
    Updated On: 04-Sep-2024  
    Type: Stored Procedure   
    Object Name: [dbo].[sp_hub_po_balance_report]

    Ticket: Task US121721
    Description: New Purchase Order Balance Report for EQAI customers in the HUB.

    Example execution:
    EXEC [dbo].[sp_hub_po_balance_report]  
    ---@customer_id = 602305,
    @customer_type = '*Any*',
    @transaction_date_start = '2024-05-28',
    @transaction_date_end = '2025-03-01',
    @user_code = 'JONATHAN',
    @permission_id = 353,
    @purchase_order = '173671257',
    @release_code = '',
    @invoice_code = '1062642',
    @receipt_id = NULL,
    @status_code_list = 'I',
    @trans_source_list = 'R,W';

    SELECT  customer_type, count(*) FROM    customer GROUP BY customer_type order by count(*) desc
   ****************************************************************************************/

    SET NOCOUNT ON;

	 DECLARE @status_code TABLE (i_status CHAR(1));

    -- Populate @status_code table if not 'all'  	
		IF (@status_code_list is not null and @status_code_list <> '')
	begin
        INSERT INTO @status_code (i_status)
        SELECT LEFT(row, 1)
        FROM dbo.fn_SplitXsvText(',', 1, @status_code_list)
        WHERE row IS NOT NULL;
	end
	else 	 
	begin
		set  @status_code_list = null
	end

	DECLARE @trans_source TABLE (i_trans_source CHAR(1));

    -- Populate @trans_source table if not 'all'  
    IF (@trans_source_list IS NOT NULL AND @trans_source_list <> '')
    begin
        INSERT INTO @trans_source (i_trans_source)
        SELECT LEFT(row, 1)
        FROM dbo.fn_SplitXsvText(',', 1, @trans_source_list)
        WHERE row IS NOT NULL;
    end
    else
    begin
        SET @trans_source_list = NULL
    end

		if (@customer_type = '*Any*') SET @customer_type = null

		if (@purchase_order = '') set @purchase_order = null
		if (@release_code = '')   set @release_code = null
		if (@invoice_code = '')   set @invoice_code = null
	
    IF @user_code = ''
        SET @user_code = NULL;

   -- Declare variables for date range
    DECLARE @start_date DATETIME = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0);
    DECLARE 
        @i_date_start DATETIME = ISNULL(@transaction_date_start, @start_date),
        @i_date_end   DATETIME = ISNULL(@transaction_date_end, DATEADD(DAY, -1, DATEADD(MONTH, 1, @start_date)));

     IF DATEPART(HOUR, @i_date_end) = 0
    BEGIN
        SET @i_date_end = DATEADD(SECOND, 0.99999, @i_date_end);
    
    END

      Drop Table If Exists #SecuredCustomer

    -- Create #SecuredCustomer temporary table
    SELECT 
        sc.customer_id, 
        c.cust_name,
        c.ax_customer_id
    INTO #SecuredCustomer
    FROM SecuredCustomer sc
    JOIN Customer c ON sc.customer_ID = c.customer_ID
    WHERE sc.user_code = @user_code
    AND sc.permission_id = @permission_id
    AND (@customer_type IS NULL OR c.customer_type = @customer_type)
    AND (@customer_id IS NULL OR @customer_id = 0 OR c.customer_id = @customer_id);

     -- SELECT  * FROM    #SecuredCustomer

    CREATE INDEX idx_secured_customer ON #SecuredCustomer(customer_id);

    -- Common Table Expressions (CTEs) for different types of contacts
    WITH cb AS (
        SELECT 
            c.customer_id,
            c.ax_customer_id,
            c.cust_name,
            cb.billing_project_id,
            cb.project_name,
            cb.PO_required_flag,
			cb.customer_service_id,
            cbpo.status,
            cbpo.PO_type,
            cbpo.purchase_order,
            cbpo.PO_description,
			cbpo.release,
            cbpo.start_date,
            cbpo.expiration_date,
            cbpo.PO_amt
        FROM #SecuredCustomer c 
        INNER JOIN CustomerBilling cb ON c.customer_id = cb.customer_id
        INNER JOIN CustomerBillingPO cbpo ON cb.customer_id = cbpo.customer_id 
            AND cb.billing_project_id = cbpo.billing_project_id
		 WHERE (cbpo.purchase_order = ISNULL(@purchase_order, cbpo.purchase_order))
           AND (cbpo.release = ISNULL(@release_code, cbpo.release))
    ),
    cb_contact AS ( --- could be multiple per customer_id, billing_project_id or none
        SELECT 
            cb.customer_id,
            cb.billing_project_id,
            case when cbxc.contact_id is not null 
            then 'A-Invoice Contact' 
            else
           case when x.primary_contact = 'T' then 'B-Primary Contact' else 'ZZZ-Any Contact' end
           end AS contact_type,
            c.contact_id,
            c.name,
            c.email,
            case when cbxc.contact_id is not null 
            then 0
            else
            case when x.primary_contact = 'T' then 1000 else 10000 end
            end + row_number() over (partition by cb.customer_id, cb.billing_project_id order by c.contact_id) as contact_order
        FROM cb
        left JOIN Contactxref x 
            ON cb.customer_id = x.customer_id
            AND x.type = 'C'
            and x.status = 'A'
        left JOIN CustomerBillingXContact cbxc 
            ON cb.customer_id = cbxc.customer_id
            AND cb.billing_project_id = cbxc.billing_project_id
            AND cbxc.attn_name_flag = 'T'
        left JOIN Contact c
            ON coalesce(cbxc.contact_id, x.contact_id, -999999) = c.contact_id
            AND c.contact_status = 'A'
    ),
          contact_reduction as (
          select cb.customer_id, cb.billing_project_id, min(cb.contact_order) min_contact_order
          from cb_contact cb
          GROUP BY cb.customer_id, cb.billing_project_id
		  )
    -- Main query selecting the final report
    SELECT 
        cb.customer_id AS EQAI_Customer_ID,
        cb.ax_customer_id AS D365_Customer_ID,
        cb.cust_name,
        cb.billing_project_id,
        cb.project_name,
        CASE 
            WHEN ISNULL(cb.PO_required_flag, '') IN ('Y', 'T') THEN 'Y'
            ELSE 'N'
        END AS PO_Required_Flag,
        CASE 
            WHEN cb.status IN ('A') THEN 'Y'
            ELSE 'N'
        END AS PO_Status,
        co.contact_order,
        co.contact_type,
        co.name AS Contact_Name,
        co.email AS Contact_Email,
		cb.status,
        cb.PO_type,
        cb.purchase_order,
        cb.PO_description,
		cb.release,
        cb.start_date,
        cb.expiration_date,
        cb.PO_amt,
        @transaction_date_end AS Invoice_Date_Range_Start,
        @transaction_date_end AS Invoice_Date_Range_End,
        MIN(b.invoice_date) AS First_Invoice_Date,
        MAX(b.invoice_date) AS Last_Invoice_Date,
        SUM(b.total_extended_amt) AS Sum_Billed_Amt,
        cb.PO_amt - SUM(b.total_extended_amt) AS PO_Balance_Remaining_Calculated,
        CASE 
            WHEN cb.PO_amt > 0 THEN 
                ((cb.PO_amt - SUM(b.total_extended_amt)) / cb.PO_amt) * 100.00 
            ELSE -100
        END AS PO_Balance_Percent_Remaining_Calculated,
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.line_id,
		b.billing_date AS TransactionDate,
		b.status_code AS TransactionStatus,
		b.invoice_code,
		b.invoice_date,
		b.total_extended_amt,
		CONCAT(bd.AX_Dimension_5_Part_1, '', bd.AX_Dimension_5_Part_2) AS D365ProjectID,
		csr.user_name AS InternalContact,
		COALESCE((
        SELECT SUM(BillingDetail.extended_amt)
        FROM Billing AS SubBilling
        JOIN BillingDetail 
            ON SubBilling.receipt_id = BillingDetail.receipt_id
            AND SubBilling.company_id = BillingDetail.company_id
            AND SubBilling.profit_ctr_id = BillingDetail.profit_ctr_id
            AND SubBilling.trans_source = BillingDetail.trans_source
            AND SubBilling.billing_uid = BillingDetail.billing_uid 
        JOIN BillingType
            ON BillingDetail.billingtype_uid = BillingType.billingtype_uid
        WHERE SubBilling.customer_id = cb.customer_id
          AND SubBilling.purchase_order = cb.purchase_order
          AND SubBilling.status_code IN ('H', 'S', 'N', 'I')
         AND (@release_code IS NULL OR ISNULL(SubBilling.release_code, '') = ISNULL(@release_code, ''))
    ), 0) AS AmountUsed
    FROM cb
    join contact_reduction cr 
      on cb.customer_ID = cr.customer_ID and cb.billing_project_id = cr.billing_project_id
    join cb_contact co
      on cb.customer_ID = co.customer_ID and cb.billing_project_id = co.billing_project_id and cr.min_contact_order = co.contact_order
    LEFT JOIN Billing b 
        ON cb.customer_id = b.customer_id AND cb.purchase_order = b.purchase_order 
		AND (@invoice_code IS NULL OR b.invoice_code = @invoice_code)
        AND (@receipt_id IS NULL OR b.receipt_id = @receipt_id) 
		AND (@status_code_list is null or b.status_code in (select i_status from @status_code))
		AND (@trans_source_list is null or b.trans_source in (select i_trans_source from @trans_source))
		AND  (b.billing_date BETWEEN @i_date_start AND @i_date_end)  
    LEFT JOIN BillingComment bc
	On b.receipt_id = bc.receipt_id
	AND b.company_id = bc.company_id
	AND b.profit_ctr_id = bc.profit_ctr_id
	AND b.trans_source = bc.trans_source
      	LEFT JOIN BillingDetail bd 
        ON b.billing_uid = bd.billing_uid
		LEFT JOIN usersxeqcontact csrx 
        ON cb.customer_service_id = csrx.type_id
        AND csrx.eqcontact_type = 'CSR'
       LEFT JOIN users csr 
        ON csrx.user_code = csr.user_code
        GROUP BY 
        cb.customer_id,
        cb.ax_customer_id,
        cb.cust_name,
        cb.billing_project_id,
        cb.project_name,
        cb.PO_required_flag,
        cb.status,
        co.contact_order,
        co.contact_type,
        co.name,
        co.email,
        cb.PO_type,
        cb.purchase_order,
        cb.PO_description,
		cb.release,
        cb.start_date,
        cb.expiration_date,
        cb.PO_amt,
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.line_id,
		b.billing_date,
		b.status_code,
		b.invoice_code,
		b.invoice_date,
		b.total_extended_amt,
		bd.AX_Dimension_5_Part_1,
        bd.AX_Dimension_5_Part_2,
		csr.user_name 
    ORDER BY 
        cb.customer_id,
        cb.ax_customer_id,
        cb.cust_name,
        cb.billing_project_id,
        cb.project_name,
        cb.purchase_order,
        cb.start_date,
        cb.expiration_date,
        co.contact_type,
        co.name;

    -- Drop temporary table
    DROP TABLE #SecuredCustomer;
END;
GO


GRANT EXECUTE ON [dbo].[sp_hub_po_balance_report] TO eqweb, eqai, cor_user;
GO







 