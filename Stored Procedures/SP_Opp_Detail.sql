Create Procedure SP_Opp_Detail (
	@Opp_id				int,
	@include_audit_log	char(1) = 'F'
)
AS
/************************************************************
Procedure    : SP_Opp_Detail
Database     : PLT_AI*
Created      : Tue May 02 12:30:00 EST 2006 - Jonathan Broome
Description  : Returns info from Opp tables on a specific Opp_id

02/01/2008 JPB Created
12/22/2010	RJG Modified for Opportunity Rewrite
4/19/2011	RJG added territory and ae listing to output

sp_Opp_Detail 4237
************************************************************/

	SELECT
      Opp.*
      ,cb.territory_code AS customer_territory_code
      ,t.territory_desc
      ,ae_user_code = (SELECT TOP 1 ux.user_code FROM CustomerBilling x 
			JOIN UsersXEQContact ux ON ux.territory_code = x.territory_code
				and x.billing_project_id = 0
				and ux.EQcontact_type = 'AE'
			where x.customer_id = Opp.customer_id
			)
      ,ae_user_name = (SELECT TOP 1 u.user_name FROM CustomerBilling x 
			JOIN UsersXEQContact ux ON ux.territory_code = x.territory_code
				and x.billing_project_id = 0
				and ux.EQcontact_type = 'AE'
			JOIN Users u ON ux.user_code = u.user_code
			where x.customer_id = Opp.customer_id
			)			
      --,ae.user_code AS ae_user_code
      --,ae.user_name AS ae_user_name
    FROM   Opp
           LEFT JOIN CustomerBilling cb
             ON opp.customer_id = cb.customer_id
                AND cb.billing_project_id = 0
           LEFT JOIN Territory t ON cb.territory_code = t.territory_code
			and cb.billing_project_id = 0
           --LEFT OUTER JOIN UsersXEQContact uxeq_ae
           --  ON cb.territory_code = uxeq_ae.territory_code
           --     AND cb.billing_project_id = 0
           --     AND uxeq_ae.EQcontact_type = 'AE'
           --LEFT JOIN Users ae
           --  ON uxeq_ae.user_code = ae.user_code
           --     AND uxeq_ae.EQcontact_type = 'ae'
    WHERE  opp.opp_id = @opp_id 
    
    
	

	select *, 
		right('00' + convert(varchar(2), company_id), 2) + '-' + right('00' + convert(varchar(2), profit_ctr_id), 2) as copc 
	from OppFacility 	
	where opp_id = @opp_id
	
	SELECT * FROM OppFacilityMonthSplit WHERE opp_id = @Opp_id
	
	select 
		u.user_name, u.title, oc.* 
	from OppContact oc
/*	
		inner join UsersXEQContact x 
			on oc.type_code = x.eqcontact_type and oc.type_id = x.type_id
		inner join Users u 
			on x.user_code = u.user_code
*/			
		inner join Users u 
			on oc.user_code = u.user_code
	where opp_id = @opp_id
	
	select * from OppPartner 	where opp_id = @opp_id

	select 
		ot.*,
		oc.comment,
		oc.added_by as c_added_by,
		oc.date_added as c_date_added
	from OppTracking ot 
		left outer join OppComment oc 
			on ot.opp_id = oc.opp_id and ot.opptrack_id = oc.opptrack_id
	where ot.opp_id = @opp_id
	order by 
		ot.opp_id, ot.opptrack_id desc, ot.sequence_id desc, oc.date_added
	
	select * from OppAudit 		where opp_id = @opp_id 
	and 1 = 
	CASE 
		WHEN @include_audit_log = 'F' THEN 0
		ELSE 1
	END
	
	DECLARE @current_primary_id int 
	SELECT @current_primary_id = primary_opp_id FROM Opp where Opp_id = @Opp_id
	
	SELECT a.*,
	(CASE WHEN a.primary_opp_id = a.opp_id THEN 'T'
		ELSE 'F'
	END
	) as primary_related_opp_flag
	 FROM Opp a 
		INNER JOIN Opp b ON 1=1
		AND a.Opp_id = b.Opp_id
		AND a.primary_opp_id = @current_primary_id
	ORDER BY primary_related_opp_flag DESC
	
	--AND a.Opp_id <> a.primary_opp_id
		
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Detail] TO [EQAI]
    AS [dbo];

