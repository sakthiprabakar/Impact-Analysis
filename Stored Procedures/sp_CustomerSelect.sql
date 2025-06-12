
CREATE PROCEDURE sp_CustomerSelect
	@customer_id_list varchar(1000)
AS
BEGIN

	declare @tblCustomerFilterList table (customer_id int)
	INSERT @tblCustomerFilterList 
		select convert(int, row) 
		from dbo.fn_SplitXsvText(',', 0, @customer_id_list) 
		where isnull(row, '') <> ''	

		SELECT c.*,
		  dbo.fn_customer_territory_list(c.customer_id) AS territory_list,
		  cb.region_id,
		  r.region_desc,
		  t.territory_code,
		  t.territory_desc,
		  cb.NAM_id,
		  u_ae.user_code as ae_user_code,
		  u_ae.user_name as ae_user_name,
		  u_nam.user_name as nam_user_name,
		  u_nam.user_code as nam_user_code,
		  ux_nam.type_id as nam_id
        FROM   customer c
        INNER JOIN @tblCustomerFilterList cl ON c.customer_ID = cl.customer_ID
        LEFT JOIN CustomerBilling cb ON c.customer_ID = cb.customer_id
			and cb.billing_project_id = 0
		LEFT JOIN UsersXEQContact ux_nam ON ux_nam.type_id = cb.NAM_id
			and ux_nam.EQcontact_type IN ('NAM')
		LEFT JOIN Users u_nam ON ux_nam.user_code = u_nam.user_code
		LEFT JOIN UsersXEQContact ux_ae ON cb.territory_code = ux_ae.territory_code
			and ux_ae.EQcontact_type IN ('AE')			
		LEFT JOIN Users u_ae ON ux_ae.user_code = u_ae.user_code
		LEFT JOIN Region r ON cb.region_id = r.region_id
		LEFT JOIN Territory t ON cb.territory_code = t.territory_code
        WHERE c.cust_status = 'A' 
        and cb.billing_project_id = 0
        
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerSelect] TO [EQAI]
    AS [dbo];

