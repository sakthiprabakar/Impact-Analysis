DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_EEC_fee]
GO


CREATE PROCEDURE [dbo].[sp_rpt_EEC_fee]
   @user_code VARCHAR(20),
    @permission_id INT
AS
BEGIN
    /***************************************************************************************
     Author: Prabhu  
     Updated On: 09-Apr-2024  
     Type: Stored Procedure   
     Object Name: [dbo].[sp_rpt_EEC_fee]

     Ticket: Task 82004
     Description: "Extract - Revenue" section and name the report "Environmental, Energy, Compliance Fee by Customer".

     Example execution:
         EXEC sp_rpt_EEC_fee  
             @user_code = 'jonathan',
             @permission_id = 353;

SELECT  * FROM    CustomerBillingFRFRate WHERE customer_id = 156 and billing_project_id = 7427  
        
    ****************************************************************************************/

   SET NOCOUNT ON;

     SET NOCOUNT ON;

    IF @user_code = ''
        SET @user_code = NULL;

	create table #SecuredCustomer (
		customer_id  int
	)

	insert #SecuredCustomer
	select distinct customer_id
	from SecuredCustomer
	where user_code = @user_code
	and permission_id = @permission_id

     SELECT 
        C.cust_status,
        C.customer_ID,
        C.ax_invoice_customer_id,
        C.d365_customer_classification_group,
        C.eq_flag,
        C.msg_customer_flag,
        C.retail_customer_flag,
        C.national_account_flag,
        C.customer_type,
        C.cust_name,
        C.cust_addr1,
        C.cust_city,
        C.cust_state,
        C.cust_zip_code,
        C.cust_country,
        C.bill_to_addr1,
        C.bill_to_city,
        C.bill_to_state,
        C.bill_to_zip_code,
        C.bill_to_country,
        CB.billing_project_id,
        CB.project_name,
        CBF.date_effective,
        CBF.apply_fee_flag,
        u.user_name as exemption_approved_by,
        ERF.exemption_reason,
        CBF.date_exempted,
        CBF.added_by,
        CBF.date_added,
        CBF.modified_by,
        CBF.date_modified
    FROM CUSTOMER C
	JOIN #SecuredCustomer sc on C.customer_id = sc.customer_id
    JOIN CustomerBilling CB ON CB.customer_ID = C.customer_ID
    INNER JOIN CustomerBillingFRFRate CBF ON CBF.customer_ID = C.customer_ID
		and CBF.billing_project_id = CB.billing_project_id
    LEFT JOIN ERFFRFExemptionReason ERF ON ERF.ERF_FRF_exemption_reason_uid = CBF.exemption_reason_uid
    LEFT JOIN CustomerBillingPO cbo ON CB.customer_ID = cbo.customer_ID
                                      AND CB.billing_project_id = cbo.billing_project_id
    LEFT  JOIN users u ON u.user_code = CBF.exemption_approved_by


    ORDER BY 
        C.customer_ID,
        CB.billing_project_id,
        CBF.date_added;
END

GO

GRANT EXECUTE ON sp_rpt_EEC_fee TO EQWEB, COR_USER, EQAI;
GO
