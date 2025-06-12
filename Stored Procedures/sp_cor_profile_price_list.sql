--drop proc sp_cor_profile_price_list
go

create proc sp_cor_profile_price_list (
	@web_userid	varchar(100) = ''
	, @profile_id	int
	, @approval_code	varchar(15) = ''
	, @facility_id_list	varchar(max) = ''
	, @show_prices	bit = 1
	, @status  char(1) = ''  
) as
/* **********************************************************************************
sp_cor_profile_price_list

List the prices for a profile for use on COR

03/1/2021 AM DevOps:19106 -	Modified min_qty field logic 
Modified by :Prabhu - Bug 70161: COR2>Pricing Approval Letter> Add status as new parameter

select b.profile_id, count(distinct pqa.company_id), count(distinct pqd.bill_unit_code)
 from ContactCorProfileBucket b
 join profilequoteapproval pqa on b.profile_id = pqa.profile_id and pqa.status = 'A'
  join profilequotedetail pqd on b.profile_id = pqd.profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id
where b.contact_id = 185547
 group by b.profile_id
having  count(distinct pqa.company_id) > 0 and count(distinct pqd.bill_unit_code) > 0

sp_cor_profile_price_list 
	@web_userid	= 'nyswyn100'
	, @profile_id	= 585165
	, @approval_code = ''
	, @show_prices = 1

	select * from ContactCORProfileBucket
	where contact_id = 11289
	and prices = 'T'


	
********************************************************************************** */

declare	@i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_contact_id	int
	, @i_profile_id		int = isnull(@profile_id, -9999999)
	, @i_approval_code	varchar(15) = isnull(@approval_code, '')
	, @i_facility_id_list	varchar(max) = isnull(@facility_id_list,'')
	, @i_show_prices	bit = isnull(@show_prices, 1)
	, @i_allow_prices	char(1) = 'F'
    , @i_status char(1) = isnull(@status, '')  

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
, price_code VARCHAR(50) NULL 
,	comment			VARCHAR(8000)	NULL
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
WHERE (@i_status = '' OR PQA.status = 'A')
 AND PQA.profile_id = @i_profile_id



	select @i_allow_prices = prices from ContactCORProfileBucket
	where contact_id = @i_contact_id
	and profile_id = @i_profile_id

	
	SELECT
	                Profile.profile_id
	,               Profile.ap_expiration_date
	,				upc.company_id
	,				upc.profit_ctr_id
	,				upc.name
	,				upc.epa_id as profit_center_epa_id
	,				PQA.approval_code
	,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQA.sr_type_code else null end as sr_type_code
	,				case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.quote_id else null end as quote_id
	,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.sequence_id else null end as sequence_id
	--,				PQD.hours_free_loading
	--,               PQD.hours_free_unloading
	--,               PQD.demurrage_price
	--,               PQD.unused_truck_price
	--,               PQD.lay_over_charge
	,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.record_type else null end as record_type
	,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.bill_unit_code else null end as bill_unit_code
	,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then 
      case @i_allow_prices when 'T' then case when PQD.price = 0 then 'TBD' else format(PQD.price, '$#,##0.#0##') end when 'O' then case when PQD.orig_customer_price = 0 then 'TBD' else format(PQD.orig_customer_price, '$#,##0.#0##') end else null end end 
as price  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.surcharge_price else null end as surcharge_price  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.bill_method else null end as bill_method  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.service_desc else null end as service_desc  
 --,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.min_quantity else null end as min_quantity  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 and PQD.min_qty_total_amt_flag = 'Q' then 'Q' else 'A' end as min_quantity_type 
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 and PQD.min_qty_total_amt_flag = 'Q' then PQD.min_quantity else PQD.min_total_amount end as min_quantity  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then ProfitCenter.surcharge_flag else null end as surcharge_flag  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then Product.fuel_flag else null end as fuel_flag  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then Product.price else null end AS product_price   
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then Product.price_override_flag else null end as price_override_flag  
 ,    case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then   
      case when PQD.record_type in ('T', 'S') then pqd.service_desc  
      else  
       case when PQA.sr_type_code = 'E' then  
        case when ProfitCenter.surcharge_flag = 'T' then 'Treatment and Disposal - Surcharge Exempt'  
        else 'Treatment and Disposal'  
        end  
       else  
        case when PQA.sr_type_code = 'H' then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0######') + ' Hazardous Surcharge per unit'  
        else  
         case when PQA.sr_type_code = 'P' then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0######') + ' Perpetual Care Surcharge per unit'  
         else 'Treatment and Disposal'  
         end  
        end  
       end  
      end  
     else  
      null  
     end as price_description  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.currency_code else null end as currency_code  
 ,    comments.comment  
 ,  comments.price_code
 FROM Profile  
 INNER JOIN ProfileQuoteDetail PQD   
                 ON PQD.profile_id = Profile.profile_id  
 INNER JOIN ProfileQuoteApproval PQA   
                 ON PQA.profile_id = Profile.profile_id  
                 AND PQA.company_id = PQD.company_id  
                 AND PQA.profit_ctr_id = PQD.profit_ctr_id  
 INNER JOIN ProfitCenter   
                 ON PQA.profit_ctr_id = ProfitCenter.profit_ctr_id  
                 AND PQA.company_id = ProfitCenter.company_ID  
 INNER JOIN USE_ProfitCenter upc on upc.company_id = pqd.company_id  
  and upc.profit_ctr_id = pqd.profit_ctr_id  
 LEFT OUTER JOIN Product  
                 ON Product.product_id = PQD.product_id  
 LEFT OUTER JOIN #comments comments  
  ON comments.profile_id = PQD.profile_id  
  AND comments.company_id = PQD.company_id  
  AND comments.profit_ctr_id = PQD.profit_ctr_id  
  
 WHERE Profile.profile_id = @i_profile_id  
                 --AND PQD.company_id = 2  
                 --AND PQD.profit_ctr_id = 0  
                 AND (@i_status = '' OR PQA.status = 'A')
                 AND PQD.record_type IN ('S', 'T')  
                 AND (PQD.fee_exempt_flag = 'F' OR PQD.fee_exempt_flag IS NULL)  
                 AND(PQD.bill_method <> 'B' OR PQD.bill_method IS NULL)
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
  
 UNION  
  SELECT  
                 Profile.profile_id  
 ,               Profile.ap_expiration_date  
 ,    upc.company_id  
 ,    upc.profit_ctr_id  
 ,    upc.name  
 ,    upc.epa_id as profit_center_epa_id  
 ,    PQA.approval_code  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQA.sr_type_code else null end as sr_type_code  
 ,    case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.quote_id else null end as quote_id  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.sequence_id else null end as sequence_id  
 --,  PQD.hours_free_loading  
 --,               PQD.hours_free_unloading  
 --,               PQD.demurrage_price  
 --,               PQD.unused_truck_price  
 --,               PQD.lay_over_charge  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.record_type else null end as record_type  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.bill_unit_code else null end as bill_unit_code  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then case @i_allow_prices when 'T' then case when PQD.price = 0 then 'TBD' else format(PQD.price, '$#,##0.#0##') end when 'O' then case when PQD.orig_customer_price = 0 then '
TBD' else format(PQD.orig_customer_price, '$#,##0.#0##') end else null end end as price  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.surcharge_price else null end as surcharge_price  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.bill_method else null end as bill_method  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.service_desc else null end as service_desc  
 --,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.min_quantity else null end as min_quantity  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 and PQD.min_qty_total_amt_flag = 'Q' then 'Q' else 'A' end as min_quantity_type 
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 and PQD.min_qty_total_amt_flag = 'Q' then PQD.min_quantity else PQD.min_total_amount end as min_quantity  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then ProfitCenter.surcharge_flag else null end as surcharge_flag  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then Product.fuel_flag else null end as fuel_flag  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then Product.price else null end as product_price  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then Product.price_override_flag else null end as price_override_flag  
 ,    case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then   
  case when PQD.record_type in ('T', 'S') then pqd.service_desc  
  else  
   case when PQA.sr_type_code = 'E' then  
    case when ProfitCenter.surcharge_flag = 'T' then 'Treatment and Disposal - Surcharge Exempt'  
    else 'Treatment and Disposal'  
    end  
   else  
    case when PQA.sr_type_code = 'H' then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0######') + ' Hazardous Surcharge per unit'  
    else  
     case when PQA.sr_type_code = 'P' then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0######') + ' Perpetual Care Surcharge per unit'  
     else 'Treatment and Disposal'  
     end  
    end  
   end  
  end   
 end as price_description  
 ,               case when @i_allow_prices in ('T', 'O') and @i_show_prices = 1 then PQD.currency_code else null end as currency_code  
 , comments.comment 
 ,comments.price_code
 FROM Profile  
 INNER JOIN ProfileQuoteDetail PQD   
                 ON PQD.profile_id = Profile.profile_id  
                 AND (PQD.bill_method <> 'B' OR PQD.bill_method IS NULL)  
 INNER JOIN ProfileQuoteApproval PQA   
                 ON PQA.profile_id = Profile.profile_id  
                 AND PQA.company_id = PQD.company_id  
                 AND PQA.profit_ctr_id = PQD.profit_ctr_id  
 INNER JOIN ProfitCenter   
                 ON PQA.profit_ctr_id = ProfitCenter.profit_ctr_id  
                 AND PQA.company_id = ProfitCenter.company_ID  
 INNER JOIN USE_ProfitCenter upc on upc.company_id = pqd.company_id  
  and upc.profit_ctr_id = pqd.profit_ctr_id  
 LEFT OUTER JOIN Product  
                 ON Product.product_id = PQD.product_id  
  
 LEFT OUTER JOIN #comments comments  
  ON comments.profile_id = PQD.profile_id  
  AND comments.company_id = PQD.company_id  
  AND comments.profit_ctr_id = PQD.profit_ctr_id  
  
 WHERE Profile.profile_id = @i_profile_id  
                 --AND PQD.company_id = 2  
                 --AND PQD.profit_ctr_id = 0  
                 AND (@i_status = '' OR PQA.status = 'A') 
                 AND PQD.record_type = 'D'  
                 AND (PQD.fee_exempt_flag = 'F' OR PQD.fee_exempt_flag IS NULL)  
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
order by profile_id, upc.name, sequence_id, bill_unit_code  
  
GO
GRANT EXECUTE on sp_cor_profile_price_list to COR_USER
GO
GRANT EXECUTE on sp_cor_profile_price_list to EQWEB
GO
GRANT EXECUTE on sp_cor_profile_price_list to EQAI
