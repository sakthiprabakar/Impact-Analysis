USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_cust_recovery_fee]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_rpt_cust_recovery_fee] (@cust_id_from INT, @cust_id_to INT) 
AS   
/***************************************************************************************  
PB Object : r_rpt_customer_recovery_fee

7/10/2024 Prakash US116969 Initial version.  
****************************************************************************************/  
BEGIN 
	WITH 
	cbt_es AS  (SELECT cbt.customer_id, 
					cbt.billing_project_id, 
					cbt.customer_billing_territory_code AS es_territory_code, 
					t.territory_desc AS es_territory_desc, 
					ISNULL(users.user_name,'None Assigned') AS es_ae_name
				FROM CustomerBillingTerritory cbt   
				LEFT JOIN Territory t ON cbt.customer_billing_territory_code = t.territory_code  
				LEFT JOIN usersxeqcontact uxc ON cbt.customer_billing_territory_code = uxc.territory_code 	
						AND uxc.eqcontact_type = 'AE'
				LEFT JOIN users ON uxc.user_code = users.user_code       
				WHERE cbt.businesssegment_uid = 1 
				AND cbt.customer_billing_territory_primary_flag = 'T'),   
	
	cbt_fis AS  (SELECT cbt.customer_id, 
					cbt.billing_project_id, 
					cbt.customer_billing_territory_code AS fis_territory_code, 
					t.territory_desc AS fis_territory_desc, 
					ISNULL(users.user_name, 'None Assigned') AS fis_ae_name  
				FROM CustomerBillingTerritory cbt 
				LEFT JOIN Territory t ON cbt.customer_billing_territory_code = t.territory_code     
				LEFT JOIN usersxeqcontact uxc ON cbt.customer_billing_territory_code = uxc.territory_code 
					 AND uxc.eqcontact_type = 'AE' 
				LEFT JOIN users ON uxc.user_code = users.user_code      
				WHERE cbt.businesssegment_uid = 2 
				AND cbt.customer_billing_territory_primary_flag = 'T'), 
				
	cbxc AS (SELECT c.name AS contact_name,   
					c.email AS contact_email_address,
					cbxc.customer_id,
					cbxc.billing_project_id,
					ROW_NUMBER() OVER (PARTITION BY cbxc.customer_id, cbxc.billing_project_id 
					                   ORDER BY cbxc.customer_id, cbxc.billing_project_id, cbxc.contact_id) AS rownum    
			FROM CustomerBillingXContact cbxc
			LEFT JOIN Contact c ON cbxc.contact_id = c.contact_id   
			WHERE cbxc.invoice_copy_flag = 'T')   

	SELECT DISTINCT       
			c.date_added,       
			c.customer_id,       
			c.AX_customer_id,       
			c.customer_type,       
			c.bill_to_cust_name,       
			c.cust_name,   
			cb.billing_project_id,       
			cb.project_name AS billing_project_name,   
			csr.user_name AS internal_contact,   
			cb.ensr_flag,  
			cbxc.contact_name,   
			cbxc.contact_email_address,   
			cbt_es.ES_territory_code,   
			cbt_es.ES_territory_desc,   
			cbt_es.ES_AE_name,   
			cbt_fis.FIS_territory_code,   
			cbt_fis.FIS_territory_desc,   
			cbt_fis.FIS_AE_name,   
			IsNull(c.msg_customer_flag, 'F') AS msg_customer_flag,
			IsNUll(c.retail_customer_flag, 'F') AS retail_customer_flag,       
			IsNull(c.national_account_flag, 'F') AS national_account_flag,     
			c.eq_company,       
			c.eq_profit_ctr,   
			c.cust_status,   
			cb.status   
	FROM Customer c   
	JOIN CustomerBilling cb ON c.customer_id = cb.customer_id   
	LEFT JOIN Territory t ON cb.territory_code = t.territory_code   
	LEFT JOIN cbxc ON cb.billing_project_id = cbxc.billing_project_id 
		 AND cb.customer_id = cbxc.customer_id AND cbxc.rownum <= 3 
	LEFT JOIN UsersXEQContact csrx on cb.customer_service_id = csrx.type_id             
		 AND csrx.eqcontact_type = 'CSR'   
	LEFT JOIN Users csr on csrx.user_code = csr.user_code  
	LEFT JOIN cbt_es ON cb.customer_id = cbt_es.customer_id  
		 AND cb.billing_project_id = cbt_es.billing_project_id 
	LEFT JOIN cbt_fis ON cb.customer_id = cbt_fis.customer_id  
		 AND cb.billing_project_id = cbt_fis.billing_project_id
	WHERE c.cust_status IN ('A', 'I')   
	AND cb.status = 'A' 
	AND cb.customer_id Between @cust_id_from and @cust_id_to 
END 
GO

GRANT EXECUTE on [dbo].[sp_rpt_cust_recovery_fee] TO EQAI
GO