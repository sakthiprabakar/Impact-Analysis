	CREATE PROCEDURE [dbo].[sp_CompanySelect] 
	    @company_id int = NULL
/*	
	Description: 
	Selects companies (either all or based on single id)

	Revision History:
	??/01/2009	RJG 	Created
*/		
		
	AS 
	
	SET NOCOUNT ON
	
	DECLARE @tblCompany TABLE (
		company_id int,
		profit_ctr_id int,
		company_name varchar(50)
	)
	INSERT INTO @tblCompany
		SELECT 
		DISTINCT 
			c.company_id, 
			CASE WHEN p.view_on_web = 'C' THEN -1
			ELSE p.profit_ctr_id
			END as profit_ctr_id,
			CASE 
			WHEN p.view_on_web = 'C' THEN c.company_name
			ELSE p.profit_ctr_name
			END company_name
		FROM ProfitCenter p
		INNER JOIN Company c ON p.company_id = c.company_id
		WHERE p.view_on_web IN('P','C') AND p.status ='A' 
		AND c.company_id = COALESCE(@company_id, c.company_id)
		order by company_name
	
	DECLARE @tblProfitCenter TABLE (
		company_id int,
		profit_ctr_id int,
		profit_ctr_name varchar(50)
	)
	
	INSERT INTO @tblProfitCenter
		SELECT DISTINCT
			p.company_id,
			p.profit_ctr_id,
			p.profit_ctr_name
		FROM ProfitCenter p
		INNER JOIN @tblCompany tblCompany ON  p.company_id = tblCompany.company_id
		where p.status = 'A' AND p.view_on_web IN ('P','C')
	
	SELECT * FROM @tblCompany
	SELECT * FROM @tblProfitCenter
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CompanySelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CompanySelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CompanySelect] TO [EQAI]
    AS [dbo];

