
/*******************************************************
** sp_rpt_customer_waste_information_by_approval.sql
** 
** Takes customer number or list of customer numbers and returns 
** information about the DOT and RCRA wastes. Also can 
** filter by profile and approval status, generator, generator 
** site type and profile expiration date range.
**
** CRG - 03/19/2012 - Created
** DZ  - 12/05/2012 - Added RQ
** 
** 
** EX.
EXEC sp_rpt_customer_waste_information_by_approval 
	@user_code = 'RICH_G', 
	@permission_id = 89, 
	@start_date = '1/1/2011', 
	@end_date = '1/10/2011 '

EXEC sp_rpt_customer_waste_information_by_approval 
	@user_code=N'RICH_G',
	@customers='10877',
	@permission_id=89,
	@approval_status='A',
	@profile_status=N'A,C,H,P,R,W', 
	@start_date = NULL, 
	@end_date = NULL
	
*******************************************************/

CREATE PROCEDURE sp_rpt_customer_waste_information_by_approval
	@start_date datetime  -- profile expiration
	,@end_date datetime  -- profile expiration
	,@approvals varchar(max) = NULL -- approval codes list
	,@customers varchar(max) = NULL -- customer ids list
	,@generators varchar(max) = NULL -- generators ids list
	,@generator_site_type varchar(100) = NULL -- generator site type
	,@approval_status char(1) = NULL --(a = active, i = inactive, null both)
	,@profiles varchar(max) = NULL -- profile ids list
	,@user_code	varchar(20) --user code for permissions
	,@permission_id int --report perm id
	,@profile_status varchar(20) = 'A, APRC, C, H, NEW, R, V' -- profile status
AS

--approval codes
create table #approvals (
	approval_code varchar(100)
)

insert #approvals
select row
from dbo.fn_SplitXsvText(',', 0, @approvals)

--profile ids
create table #profiles (
	profile_id int
)

insert into #profiles
	select row
	from dbo.fn_SplitXsvText(',', 0, @profiles)

--customer ids
create table #customers (
	customer_id int
)

IF @customers IS NULL BEGIN
	insert #customers
		select DISTINCT sc.customer_id 
	FROM SecuredCustomer sc  (nolock)
		WHERE sc.user_code = @user_code and sc.permission_id = @permission_id
END
ELSE BEGIN
	insert #customers
	select DISTINCT sc.customer_id 
	from dbo.fn_SplitXsvText(',', 0, @customers) fnc
		INNER JOIN SecuredCustomer sc  (nolock) ON sc.customer_id = fnc.row
			WHERE sc.user_code = @user_code and sc.permission_id = @permission_id
END

--generator ids
create table #generators (
	generator_id int
)

IF @generators IS NULL BEGIN
	insert #generators
		select DISTINCT sg.generator_id 
	FROM SecuredGenerator sg  (nolock)
		WHERE sg.user_code = @user_code and sg.permission_id = @permission_id
END
ELSE BEGIN
	insert #generators
	select DISTINCT sg.generator_id  
	from dbo.fn_SplitXsvText(',', 0, @generators) fng
		INNER JOIN SecuredGenerator sg  (nolock) ON sg.generator_id = fng.row
			WHERE sg.user_code = @user_code	and sg.permission_id = @permission_id
END	


--profile status codes
create table #profile_status_codes (
	code VARCHAR(5)
)

insert #profile_status_codes
select row
from dbo.fn_SplitXsvText(',', 0, @profile_status)

--select
SELECT DISTINCT P.customer_id
	,P.orig_customer_id
	,C.cust_name
	,G.EPA_ID
	,G.generator_name
	,P.generator_id
	,PQA.company_id
	,PQA.profit_ctr_id
	,P.curr_status_code
	,PQA.STATUS
	,PQA.approval_code
	,P.approval_desc
	,P.UN_NA_flag
	,P.UN_NA_number
	,P.DOT_shipping_name
	,P.ap_expiration_date
	,P.ERG_number
	,P.ERG_suffix
	,P.hazmat
	,P.hazmat_class
	,P.package_group
	,P.RCRA_haz_flag
	,P.subsidiary_haz_mat_class
	,P.reportable_quantity_flag
	,(CASE WHEN P.waste_code = 'NONE' THEN NULL ELSE P.waste_code END) AS 'primary_waste_code'
	,(SELECT dbo.fn_approval_sec_waste_code_list (P.profile_id, 'P')) AS 'secondary_waste_codes'
FROM PROFILE P
LEFT JOIN Customer C ON P.customer_id = C.customer_ID
LEFT JOIN Generator G ON P.generator_id = G.generator_id
INNER JOIN ProfileQuoteApproval PQA ON P.profile_id = PQA.profile_id
INNER JOIN ProfileWasteCode PWC ON P.profile_id = PWC.profile_id
WHERE 
	--check customer permissions and selected customer
	EXISTS (select 1 as 'exists' from #customers tempc where tempc.customer_id = P.customer_id OR tempc.customer_id = P.orig_customer_id) 
	--check generator permissions and selected generator
	AND EXISTS (SELECT 1 as 'exists' FROM #generators tempg where tempg.generator_id = P.generator_id)
	AND (@approvals is NULL OR EXISTS (select 1 as 'exists' from #approvals tempa where tempa.approval_code = pqa.approval_code)) 
	AND (@profiles is NULL OR EXISTS (select 1 as 'exists' from #profiles tempp where tempp.profile_id = p.profile_id)) 
	AND (ISNULL(p.ap_expiration_date,(dateadd(d, 1, @end_date))) BETWEEN @start_date AND @end_date)
	AND (@generator_site_type IS NULL OR g.site_type = @generator_site_type)
	AND (@approval_status IS NULL OR PQA.STATUS = @approval_status)
	AND (@profile_status IS NULL OR EXISTS (select 1 as 'exists' from #profile_status_codes where code = P.tracking_type))

--Drop tables
DROP TABLE #approvals
DROP TABLE	#generators
DROP TABLE #customers
DROP TABLE #profiles
DROP TABLE #profile_status_codes

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_waste_information_by_approval] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_waste_information_by_approval] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_customer_waste_information_by_approval] TO [EQAI]
    AS [dbo];

