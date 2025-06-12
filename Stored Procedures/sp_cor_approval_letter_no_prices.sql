-- drop proc sp_cor_approval_letter_no_prices
go

create proc sp_cor_approval_letter_no_prices (
	@web_userid	varchar(100) = ''
	, @profile_id	int
	, @approval_code	varchar(15) = ''
	, @facility_id_list	varchar(max) = ''
) as
/* **********************************************************************************
sp_cor_approval_letter_no_prices

List the prices for a profile for use on COR


select b.profile_id, count(distinct pqa.company_id), count(distinct pqd.bill_unit_code)
 from ContactCorProfileBucket b
 join profilequoteapproval pqa on b.profile_id = pqa.profile_id and pqa.status = 'A'
  join profilequotedetail pqd on b.profile_id = pqd.profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id
where b.contact_id = 185547
 group by b.profile_id
having  count(distinct pqa.company_id) > 0 and count(distinct pqd.bill_unit_code) > 0

sp_cor_approval_letter_no_prices 
	@web_userid	= 'nyswyn100'
	, @profile_id	= 478788
	, @approval_code = ''
	
********************************************************************************** */

declare	@i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_contact_id	int
	, @i_profile_id		int = isnull(@profile_id, -9999999)
	, @i_approval_code	varchar(15) = isnull(@approval_code, '')
	, @i_facility_id_list	varchar(max) = isnull(@facility_id_list,'')
	, @i_show_prices	bit = 0
	, @i_allow_prices	bit = 0

select top 1 @i_contact_id = contact_id
from CORcontact where web_userid = @i_web_userid

declare @facility_id table (
	company_id	int,
	profit_ctr_id	int
)
if @i_facility_id_list <> ''
insert @facility_id 
select distinct company_id, profit_ctr_id
from USE_Profitcenter upc
join (
	select row
	from dbo.fn_SplitXsvText(' ', 1, replace(@i_facility_id_list, ',', ' '))
	where row is not null
) x
on isnull(convert(varchar(2),upc.company_id), '') + '|' + isnull(convert(varchar(2),upc.profit_ctr_id), '') = row

CREATE TABLE #comments (
	profile_id		INT		NULL
,	company_id		INT		NULL
,	profit_ctr_id	INT		NULL
,   price_code VARCHAR(50) NULL 
,   comment   VARCHAR(8000) NULL  
)

declare	@CARRIAGE_RETURN varchar(5) = CHAR(13) + CHAR(10)

insert #comments
SELECT DISTINCT
	PQD.profile_id
,   PQD.company_id
,   PQD.profit_ctr_id
,   P.price_code
,   comment = (ISNULL(d.description, '') + CASE d.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END +
			   ISNULL(t.description, '') + CASE t.description WHEN NULL THEN '' ELSE @CARRIAGE_RETURN END + ISNULL(s.description, '')
			   )
FROM ProfileQuoteApproval PQA
JOIN ProfileQuoteDetail PQD
	ON PQA.profile_id = PQD.profile_id
	AND PQA.quote_id = PQD.quote_id
	AND PQD.status = 'A'
LEFT OUTER JOIN ProfileQuoteDetailDesc d
	ON d.profile_id = PQD.profile_id
	   AND d.company_id = PQD.company_id
	   AND d.profit_ctr_id = PQD.profit_ctr_id
	   AND d.quote_id = PQD.quote_id
	   AND d.record_type = 'D'
LEFT OUTER JOIN ProfileQuoteDetailDesc t
	ON t.profile_id = PQD.profile_id
	   AND t.company_id = PQD.company_id
	   AND t.profit_ctr_id = PQD.profit_ctr_id
		AND t.quote_id = PQD.quote_id
	   AND t.record_type = 'T'
LEFT OUTER JOIN ProfileQuoteDetailDesc s
	ON s.profile_id = PQD.profile_id
	   AND s.company_id = PQD.company_id
	   AND s.profit_ctr_id = PQD.profit_ctr_id
	   AND s.quote_id = PQD.quote_id
	   AND s.record_type = 'S'
	   LEFT OUTER JOIN  PriceCode P
	ON P.price_code_uid =PQA.price_code_uid
WHERE PQA.status = 'A'
 AND PQA.profile_id = @i_profile_id


--if exists (
--	select 1 from ContactCORProfileBucket
--	where contact_id = @i_contact_id
--	and profile_id = @i_profile_id
--	and prices = 1
--) 
--	set @i_allow_prices = 1

	
	SELECT
	                Profile.profile_id
	,               Profile.ap_expiration_date
	,				Profile.approval_desc
	,				upc.company_id
	,				upc.profit_ctr_id
	,				upc.name
	,				upc.epa_id as profit_center_epa_id
	,				PQA.approval_code
	,				cust.cust_name
	,				cust.bill_to_addr1
	,				cust.bill_to_addr2
	,				cust.bill_to_addr3
	,				cust.bill_to_addr4
	,				cust.bill_to_addr5
	,				cust.bill_to_city
	,				cust.bill_to_state
	,				cust.bill_to_zip_code
	,				cust.bill_to_country
	,				g.generator_name
	,				g.generator_address_1
	,				g.generator_address_2
	,				g.generator_address_3
	,				g.generator_address_4
	,				g.generator_address_5
	,				g.generator_city
	,				g.generator_state
	,				g.generator_zip_code
	,				g.epa_id as generator_epa_id
	,				comments.comment
	,               comments.price_code
	,				dbo.fn_profile_waste_code_list (Profile.profile_id, 'X')  as waste_code_list
	FROM Profile
	INNER JOIN ProfileQuoteApproval PQA 
	                ON PQA.profile_id = Profile.profile_id
	                AND PQA.status = 'A'
	INNER JOIN ProfitCenter 
	                ON PQA.profit_ctr_id = ProfitCenter.profit_ctr_id
	                AND PQA.company_id = ProfitCenter.company_ID
	INNER JOIN USE_ProfitCenter upc on upc.company_id = pqa.company_id
		and upc.profit_ctr_id = pqa.profit_ctr_id
	INNER JOIN Customer cust
					on profile.customer_id = cust.customer_id
	INNER JOIN Generator g
					on profile.generator_id = g.generator_id
	LEFT OUTER JOIN #comments comments
		ON comments.profile_id = PQA.profile_id
		AND comments.company_id = PQA.company_id
		AND comments.profit_ctr_id = PQA.profit_ctr_id

	WHERE Profile.profile_id = @i_profile_id
	                AND (@i_approval_code = '' OR (@i_approval_code <> '' and @i_approval_code = pqa.approval_code))
					and
					(
						@i_facility_id_list = ''
						or
						(
							@i_facility_id_list <> ''
							and
							exists (
								select 1 from @facility_id fac 
									where pqa.company_id = fac.company_id
									and pqa.profit_ctr_id = fac.profit_ctr_id
							)
						)
					)	

order by Profile.profile_id, upc.name

GO
GRANT EXECUTE on sp_cor_approval_letter_no_prices to COR_USER
GO
GRANT EXECUTE on sp_cor_approval_letter_no_prices to EQWEB
GO
GRANT EXECUTE on sp_cor_approval_letter_no_prices to EQAI

