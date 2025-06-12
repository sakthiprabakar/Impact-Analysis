drop proc if exists sp_ce_get_waste_list
go
CREATE PROCEDURE [dbo].[sp_ce_get_waste_list]
	@customer_id	varchar(15),
	@facility_search	varchar(max),
	@page				int = 1,
    @perpage			int = 100,
	@totalcount int OUT
AS
-- =============================================
-- Author:		SENTHIL KUMAR I
-- Create date: 05/27/20222
-- Description:	To retive waste id & waste desc
/*
 DECLARE @totalcount INT 
 EXEC sp_ce_get_waste_list 'C027836','USEI',1,10, @totalcount OUT
 SELECT @totalcount

 DECLARE @totalcount INT 
 EXEC sp_ce_get_waste_list 'C026112,C027836','USEI,COMPLETEREC',1,10, @totalcount OUT
 SELECT @totalcount

  DECLARE @totalcount INT 
 EXEC sp_ce_get_waste_list 'C026112','COMPLETEREC',1,10, @totalcount OUT
 SELECT @totalcount
 */
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	-- avoid query plan caching:
	DECLARE
	@i_facility_search		varchar(max) = isnull(@facility_search, ''),
	@i_customer_id	varchar(max) = isnull(@customer_id, ''),
	@i_page				int = isnull(@page, 1),
    @i_perpage			int = isnull(@perpage, 20)

	DECLARE @customer table (
	ax_customer_id	varchar(20)
	)
	INSERT @customer 
	select row
	from dbo.fn_SplitXsvText(' ', 1, replace(@i_customer_id, ',', ' '))
	where row is not null

	DECLARE @tsdf TABLE (
		tsdf_code	varchar(15),
		eq_company int,
		eq_profit_Ctr int
	)
	

	INSERT @tsdf 
	SELECT DISTINCT tsdf_code,eq_company,eq_profit_Ctr
	FROM TSDF
	join (
	select row
	from dbo.fn_SplitXsvText(' ', 1, replace(@i_facility_search, ',', ' '))
	where row is not null
	) x
	on isnull(tsdf.tsdf_code, '') like '%' + x.row + '%'	
	WHERE tsdf_status = 'A'; --and isnull(eq_flag, 'F') = 'T'; --AND tsdf.tsdf_code=@i_facility_search;
	WITH
		cteWasteProfile (profile_id, approval_desc)--,tsdf_code
	  AS
	  (
		SELECT
		DISTINCT 
			p.profile_id,
			p.approval_desc
			--facility.tsdf_code
		FROM ContactCORProfileBucket b
		JOIN [Profile] p ON b.profile_id = p.profile_id
		LEFT join Customer cn on p.customer_id = cn.customer_id
		--OUTER APPLY(select fac.tsdf_code from ProfileQuoteApproval pqaf
		--			join @tsdf fac on pqaf.company_id = fac.eq_company
		--				and pqaf.profit_ctr_id = fac.eq_profit_ctr
		--			where pqaf.profile_id = p.profile_id
		--			and pqaf.status = 'A') facility
		WHERE  b.ap_expiration_date>= getdate()  AND b.curr_status_code='A' AND
		(
			cn.ax_customer_id IN(select ax_customer_id from @customer)
		)
		AND
		(
				@i_facility_search <> ''
				and
				exists (
					select 1 from ProfileQuoteApproval pqaf
					join @tsdf fac on pqaf.company_id = fac.eq_company
						and pqaf.profit_ctr_id = fac.eq_profit_ctr
					where pqaf.profile_id = p.profile_id
					and pqaf.status = 'A' AND fac.eq_profit_ctr IS NOT NULL AND fac.eq_company IS NOT NULL
				)
		)
		UNION ALL
		SELECT 
		DISTINCT 
		 ta.tsdf_approval_id profile_id,
			ta.waste_desc approval_desc
			from tsdfapproval ta  (nolock)
			join tsdf (nolock)
			on ta.tsdf_code = tsdf.tsdf_code
			left join Customer cn on ta.customer_id = cn.customer_id
			WHERE  ta.TSDF_approval_expire_date>= getdate()   AND
		(
				cn.ax_customer_id IN(select ax_customer_id from @customer)
		) 
		AND @i_facility_search <> ''
			and
			exists
			(
				select 1 from @tsdf where tsdf_code = ta.tsdf_code
			)
		)SELECT ROW_NUMBER() OVER(ORDER BY profile_id) AS row_num,* INTO #tempProfile FROM cteWasteProfile
		SELECT @totalcount=COUNT(*) FROM #tempProfile 
	
		SELECT *,@totalcount total_count FROM #tempProfile WHERE row_num BETWEEN ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
	

	DROP TABLE #tempProfile
END

GO

GRANT EXECUTE ON [dbo].[sp_ce_get_waste_list] TO COR_USER;

GO
