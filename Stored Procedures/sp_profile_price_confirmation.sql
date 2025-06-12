USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS sp_profile_price_confirmation
go

CREATE PROCEDURE sp_profile_price_confirmation (
	@profile_id varchar(max)  = ''
	, @first_name	varchar(20) = ''
	, @last_name	varchar(20) = ''
	, @email_address	varchar(100) = ''
	, @purchase_order	varchar(40) = ''
	, @facility_id_list	varchar(max) = ''
) as
/* **********************************************************************************
sp_profile_price_confirmation

Modified by :Prabhu -Bug 58379: Price Confirmation > '$' Character under 'Min Qty' Field


List the prices for a profile for use on COR

05/21/2020 - AM - DevOps:15721 - EQAI-Docusign Price Confirmation showing bundled charges
06/1/2020 - AM - DevOps:15723 - EQAI- Pricing Amt Min QTY
06/7/2020 AM DevOps:16163 - Docusign Price Confirmation - Min. Qty/Amt
03/1/2021 AM DevOps:19106 -	Modified min_qty field logic 
03/02/2022 Allen Campbell DevOps 37866 added IsNull to min_qty field logic
09/26/2023 AM - DevOps:65837 - Modified profile_id from int to varchar to open price confirmation for multiple profiles from customer letters.

select b.profile_id, count(distinct pqa.company_id), count(distinct pqd.bill_unit_code)
 from ContactCorProfileBucket b
 join profilequoteapproval pqa on b.profile_id = pqa.profile_id and pqa.status = 'A'
  join profilequotedetail pqd on b.profile_id = pqd.profile_id and pqa.company_id = pqd.company_id and pqa.profit_ctr_id = pqd.profit_ctr_id
where b.contact_id = 185547
 group by b.profile_id
having  count(distinct pqa.company_id) > 0 and count(distinct pqd.bill_unit_code) > 0

sp_profile_price_confirmation 
	@profile_id	= 195082

select top 200 a.status, p.*, d.*
from profile p
join profilequotedetail d on p.profile_id = d.profile_id and d.status = 'A'
join profilequotedetail a on p.profile_id = a.profile_id and d.company_id = a.company_id and d.profit_ctr_id = a.profit_ctr_id and a.status = 'A'
WHERE d.price = 0
and d.record_type in ('D', 'S', 'T')
and d.record_type = 'S'
and p.ap_expiration_date > getdatE()
and p.curr_status_code = 'A'
and p.profile_id in
(72843, 73767, 73821, 74990, 78983, 80645, 82260, 90549, 90575, 131050, 195082, 210105, 211043, 211126)


SELECT  *  FROM    profile WHERE profile_id = 74990
SELECT  *  FROM    profilequotedetail WHERE profile_id = 74990
SELECT  *  FROM    profilequoteapproval WHERE profile_id = 74990

select quote_id, company_id, profit_ctr_id, approval_code
-- , Plt_AI.dbo.fn_web_profitctr_display_name(company_id, profit_ctr_id) [display_name] 
from ProfileQuoteApproval 
WHERE status = 'A' AND profile_id = 74990

********************************************************************************** */

declare @i_profile_id  varchar(max) = isnull(@profile_id, '')   
 , @i_first_name   varchar(20) = isnull(@first_name, '')  
 , @i_last_name   varchar(20) = isnull(@last_name, '')  
 , @i_email_address  varchar(100) = isnull(@email_address, '')  
 , @i_purchase_order  varchar(40) = isnull(@purchase_order, '')  
 , @i_facility_id_list varchar(max) = isnull(@facility_id_list,'')  

declare @profile_ids table (  
 profile_id bigint  
)  
if @i_profile_id <> ''  
insert @profile_ids  
select convert(bigint, row)  
from dbo.fn_SplitXsvText(',', 1, replace(@i_profile_id, ' ', ',')) 

declare @facility_id table (  
 company_id int,  
 profit_ctr_id int  
)  
if @i_facility_id_list <> ''  
insert @facility_id   
select distinct company_id, profit_ctr_id  
from Profitcenter upc  
join (  
 select row  
 from dbo.fn_SplitXsvText(' ', 1, replace(@i_facility_id_list, ',', ' '))  
 where row is not null  
) x  
on isnull(convert(varchar(2),upc.company_id), '') + '|' + isnull(convert(varchar(2),upc.profit_ctr_id), '') = row  
  
CREATE TABLE #comments (  
 profile_id  INT  NULL  
, company_id  INT  NULL  
, profit_ctr_id INT  NULL
, price_code VARCHAR(50) NULL 
, comment   VARCHAR(8000) NULL  
)  
  
declare @CARRIAGE_RETURN varchar(5) = CHAR(13) + CHAR(10)  
  
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
  AND PQA.profile_id in ( select profile_id from @profile_ids  ) 

select * from (   
SELECT  
 ' header fields begin here. they are only shown once on a price confirmation ' as header_marker ,  
 right('000000' + convert(varchar(20), Customer.customer_id), 6) as customer_id,  
 'ENVIRONMENTAL MANAGER' as addressee,  
 Customer.cust_name,  
 Customer.cust_addr1,  
 Customer.cust_city,  
 Customer.cust_state,  
 Customer.cust_zip_code,  
 Customer.cust_country,  
 @i_first_name signature_first_name,  
 @i_last_name signature_last_name,  
 @i_email_address signature_email_address,  
 @i_purchase_order purchase_order,  
 profile.purchase_order_from_form,  
 Generator.generator_name,  
 Generator.epa_id generator_epa_id,  
 profile.approval_desc,  
 ( SELECT replace(dbo.fn_profile_waste_code_list(Profile.profile_id , 'P'), 'NONE', '') ) as waste_code,  
 ' detail header fields begin here. they are shown once per unique profit_ctr_name ' as detail_header_marker ,  
 PQA.approval_code,  
 convert(date, Profile.ap_expiration_date) ap_expiration_date,  
 upc.profit_ctr_name,  
 upc.epa_id facility_epa_id,  
 ' detail fields begin here. they are shown once per type_of_service ' as detail_marker ,  
 case when PQD.record_type in ('T') then pqd.service_desc  
  when PQD.record_type in ('S') AND IsNull(PQD.bill_method,'') = 'B' then 'Includes ' + pqd.service_desc  
  when PQD.record_type in ('S') AND IsNull(PQD.bill_method,'') <> 'B' then  pqd.service_desc  
 else  
  case when PQA.sr_type_code = 'E' then  
   case when ProfitCenter.surcharge_flag = 'T' then 'Treatment and Disposal - Surcharge Exempt'  
   else 'Treatment and Disposal'  
   end  
  else  
   case when PQA.sr_type_code = 'H' 
   then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0##') + ' Hazardous Surcharge per unit'  
   else  
    case when PQA.sr_type_code = 'P' 
	then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0##') + ' Perpetual Care Surcharge per unit'  
    else 'Treatment and Disposal'  
    end  
   end  
  end  
 end as type_of_service,  
 case when Product.price_override_flag = 'T' and PQD.price = 0 then 'TBD' WHEN IsNull(PQD.bill_method,'') = 'B' 
 then null else format(PQD.price, '$#,##0.#0##') end as price,  
 case when  IsNull(PQD.bill_method,'') = 'B' then null else PQD.bill_unit_code end as bill_unit_code ,  
 --case WHEN isnull(convert(varchar(20),PQD.min_quantity),'N/A') = 'N/A' then 'N/A' when PQD.bill_method = 'B' 
 --then null else convert(varchar(20), isnull (PQD.min_quantity, '')) + ' ' + isnull (PQD.bill_unit_code,'') end as min_quantity,  
 --case when PQD.min_qty_total_amt_flag = 'Q' then PQD.min_quantity else PQD.min_total_amount end as min_quantity,  
 case when IsNull(PQD.min_qty_total_amt_flag,'Q') = 'Q' then 'Q' else 'A' end as min_quantity_type,
 case when IsNull(PQD.min_qty_total_amt_flag,'Q') = 'Q' then PQD.min_quantity else PQD.min_total_amount end as min_quantity,  
 service_info = (  
  select top 1   
  ltrim(rtrim(  
  '' +  
  case when isnull(PQD2.hours_free_unloading, -1) > -1 
  then 'Hours Free Unloading: ' + convert(varchar(4), pqd2.hours_free_unloading) + '  ' else '' end +  
  case when isnull(PQD2.hours_free_loading, -1) > -1 
  then 'Hours Free Loading: ' + convert(varchar(4), pqd2.hours_free_loading) + '  ' else '' end +  
  case when isnull(PQD2.demurrage_price, -1) > -1 
  then 'Demurrage is ' + format(pqd2.demurrage_price, '$#,##0.#0##') + ' per hour after two free hours loading and unloading.  ' else '' end +  
  case when isnull(PQD2.unused_truck_price, -1) > -1 
  then 'Trucks ordered and not used are ' + format(pqd2.unused_truck_price, '$#,##0.#0##') + ' per truck.  ' else '' end +  
  case when isnull(PQD2.lay_over_charge, -1) > -1 
  then 'Layovers are ' + format(pqd2.lay_over_charge, '$#,##0.#0##') + ' per day per truck.  ' else '' end  
 ))  
  from profileQuoteDetail pqd2  
  WHERE pqd2.profile_id = pqd.profile_id  
  and pqd.quote_id = pqd.quote_id  
  and pqd2.company_id = pqd.company_id  
  and pqd2.profit_ctr_id = pqd.profit_ctr_id  
  and pqd2.sequence_id = pqd.sequence_id  
  and pqd2.record_type in ('D', 'S', 'T')  
  and isnull(pqd2.bill_method, '') <> 'B'  
 ),  
 ' detail footer fields begin here. They are shown once per unique profit_ctr_name ' as detail_footer_marker ,  
 comments.comment,  
 ' undisplayed fields begin here' as undisplayed_marker ,  
 profile.profile_id,  
 pqd.company_id,  
 pqd.profit_ctr_id,  
 PQD.record_type,  
 PQD.sequence_id,
 comments.price_code
/*  
 ,               PQA.sr_type_code as sr_type_code  
 ,    PQD.quote_id as quote_id  
 ,               PQD.sequence_id as sequence_id  
 ,    PQD.hours_free_loading  
 ,               PQD.hours_free_unloading  
 ,               PQD.demurrage_price  
 ,               PQD.unused_truck_price  
 ,               PQD.lay_over_charge  
 ,               PQD.record_type as record_type  
 ,               PQD.surcharge_price as surcharge_price  
 ,               PQD.bill_method as bill_method  
 ,    PQD.bill_quantity_flag  
 ,    PQD.status  
 ,               PQD.service_desc as service_desc  
 ,               PQD.min_quantity as min_quantity  
 ,               ProfitCenter.surcharge_flag as surcharge_flag  
 ,               Product.fuel_flag as fuel_flag  
 ,               Product.price AS product_price   
 ,               Product.price_override_flag as price_override_flag  
 ,      
   PQD.primary_price_flag,  
   PQD.bulk_flag,  
   PQD.orig_customer_price,  
   PQD.resource_class_code,  
   has_comment = IsNull((SELECT COUNT(*) FROM ProfileQuoteDetailDesc  
   WHERE PQD.quote_id = ProfileQuoteDetailDesc.quote_id  
   AND PQD.company_id = ProfileQuoteDetailDesc.company_id  
   AND PQD.profit_ctr_id = ProfileQuoteDetailDesc.profit_ctr_id  
   AND ProfileQuoteDetailDesc.record_type = 'D'  
   AND ProfileQuoteDetailDesc.sequence_id = 0),0) ,  
   0 as count_price_adjustment,  
   PQA.sr_type_code,  
   ProfitCenter.surcharge_flag,  
   CONVERT(char(1),'') as screen_access,  
   PQD.customer_cost,  
   Customer.customer_cost_flag,  
   split_price_count = (select count(*) from profilequotedetail pqd_s where pqd_s.quote_id = PQD.quote_id and pqd_s.company_id = PQD.company_id 
   and pqd_s.profit_ctr_id = PQD.profit_ctr_id and pqd_s.bill_method = 'B' and ((pqd_s.ref_sequence_id = PQD.seque
nce_id and pqd_s.bill_quantity_flag in ('P','U') or pqd_s.ref_sequence_id = 0 and pqd_s.bill_quantity_flag = 'L'))),  
   split_percent_count = 0, /*(select count(*) from profilequotedetail pqd_s where pqd_s.quote_id = PQD.quote_id and pqd_s.company_id = PQD.company_id 
   and pqd_s.profit_ctr_id = PQD.profit_ctr_id and pqd_s.ref_sequence_id = PQD.sequence_id and pqd_s.bill_m
ethod = 'B' and pqd_s.bill_quantity_flag = 'P'),*/  
   split_record_total = convert(numeric(10,4),isnull(PQD.price,0)) - (select convert(numeric(10,4),sum(isnull(pqd_s.price,0))) 
   from profilequotedetail pqd_s where pqd_s.quote_id = PQD.quote_id and pqd_s.company_id = PQD.company_id and pqd_s.profit_ctr_id 
= PQD.profit_ctr_id and pqd_s.ref_sequence_id = PQD.sequence_id and pqd_s.bill_method = 'B' and pqd_s.bill_quantity_flag in ('P','U')),  
   PQD.show_cust_flag,  
   PQD.currency_code,  
*/     
 FROM Profile  
 INNER JOIN ProfileQuoteDetail PQD   
                 ON PQD.profile_id = Profile.profile_id  
 INNER JOIN ProfileQuoteApproval PQA   
                 ON PQA.profile_id = Profile.profile_id  
                 AND PQA.company_id = PQD.company_id  
                 AND PQA.profit_ctr_id = PQD.profit_ctr_id  
                 AND PQA.status = 'A'  
 INNER JOIN ProfitCenter   
                 ON PQA.profit_ctr_id = ProfitCenter.profit_ctr_id  
                 AND PQA.company_id = ProfitCenter.company_ID  
 INNER JOIN ProfitCenter upc on upc.company_id = pqd.company_id  
  and upc.profit_ctr_id = pqd.profit_ctr_id  
 LEFT OUTER JOIN Product  
                 ON Product.product_id = PQD.product_id  
 INNER JOIN Customer ON (Profile.customer_id = Customer.customer_id)  
 INNER JOIN Generator ON (Profile.generator_id = Generator.generator_id)  
 LEFT OUTER JOIN #comments comments  
  ON comments.profile_id = PQD.profile_id  
  AND comments.company_id = PQD.company_id  
  AND comments.profit_ctr_id = PQD.profit_ctr_id  
 WHERE Profile.profile_id in ( select profile_id from @profile_ids  ) 
                 --AND PQD.company_id = 2  
                 --AND PQD.profit_ctr_id = 0  
                 AND PQD.status = 'A'  
                 AND PQD.record_type IN ('S', 'T')  
                 AND ISNULL(PQD.fee_exempt_flag, 'F') = 'F'  
                 AND (IsNull(pqd.bill_method, '') <> 'B' OR (IsNull(pqd.bill_method, '') = 'B' AND pqd.show_cust_flag = 'T') )  
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
 ' header fields begin here. they are only shown once on a price confirmation ' as header_marker ,  
 right('000000' + convert(varchar(20), Customer.customer_id), 6) as customer_id,  
 'ENVIRONMENTAL MANAGER' as addressee,  
 Customer.cust_name,  
 Customer.cust_addr1,  
 Customer.cust_city,  
 Customer.cust_state,  
 Customer.cust_zip_code,  
 Customer.cust_country,  
 @i_first_name signature_first_name,  
 @i_last_name signature_last_name,  
 @i_email_address signature_email_address,  
 @i_purchase_order purchase_order,  
 profile.purchase_order_from_form,  
 Generator.generator_name,  
 Generator.epa_id generator_epa_id,  
 profile.approval_desc,  
 ( SELECT replace(dbo.fn_profile_waste_code_list(Profile.profile_id , 'P'), 'NONE', '') ) as waste_code,  
 ' detail header fields begin here. they are shown once per unique profit_ctr_name ' as detail_header_marker ,  
 PQA.approval_code,  
 convert(date, Profile.ap_expiration_date) ap_expiration_date,  
 upc.profit_ctr_name,  
 upc.epa_id facility_epa_id,  
 ' detail fields begin here. they are shown once per type_of_service ' as detail_marker ,  
 case when PQD.record_type in ('T') then pqd.service_desc  
  when PQD.record_type in ('S') AND IsNull(PQD.bill_method,'') = 'B' then 'Includes ' + pqd.service_desc  
  when PQD.record_type in ('S') AND IsNull(PQD.bill_method,'') <> 'B' then  pqd.service_desc  
 else  
  case when PQA.sr_type_code = 'E' then  
   case when ProfitCenter.surcharge_flag = 'T' then 'Treatment and Disposal - Surcharge Exempt'  
   else 'Treatment and Disposal'  
   end  
  else  
   case when PQA.sr_type_code = 'H' 
   then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0##') + ' Hazardous Surcharge per unit'  
   else  
    case when PQA.sr_type_code = 'P' 
	then 'Treatment and Disposal - Additional ' + FORMAT(PQD.surcharge_price, '$#,##0.#0##') + ' Perpetual Care Surcharge per unit'  
    else 'Treatment and Disposal'  
    end  
   end  
  end  
 end as type_of_service,  
 case when Product.price_override_flag = 'T' and PQD.price = 0 then 'TBD' 
 WHEN IsNull(PQD.bill_method,'') = 'B' then null else format(PQD.price, '$#,##0.#0##') end as price,  
 case when  IsNull(PQD.bill_method,'') = 'B' then null else PQD.bill_unit_code end as bill_unit_code ,  
 --case WHEN isnull(convert(varchar(20),PQD.min_quantity),'N/A') = 'N/A' then 'N/A' when PQD.bill_method = 'B' 
 --then null else convert(varchar(20), isnull ( PQD.min_quantity, '')) + ' ' + isnull (PQD.bill_unit_code,'') end as min_quantity,  
 --case when PQD.min_qty_total_amt_flag = 'Q' then PQD.min_quantity else PQD.min_total_amount end as min_quantity,  
 case when IsNull(PQD.min_qty_total_amt_flag,'Q') = 'Q' then 'Q' else 'A' end as min_quantity_type,
 case when IsNull(PQD.min_qty_total_amt_flag,'Q') = 'Q' then PQD.min_quantity else PQD.min_total_amount end as min_quantity,  
 service_info = (  
  select top 1   
  ltrim(rtrim(  
  '' +  
  case when isnull(pqd2.hours_free_unloading, -1) > -1 
  then 'Hours Free Unloading: ' + convert(varchar(4), pqd2.hours_free_unloading) + '  ' else '' end +  
  case when isnull(PQD2.hours_free_loading, -1) > -1 
  then 'Hours Free Loading: ' + convert(varchar(4), pqd2.hours_free_loading) + '  ' else '' end +  
  case when isnull(PQD2.demurrage_price, -1) > -1 
  then 'Demurrage is ' + format(pqd2.demurrage_price, '$#,##0.#0##') + ' per hour after two free hours loading and unloading.  ' else '' end +  
  case when isnull(PQD2.unused_truck_price, -1) > -1 
  then 'Trucks ordered and not used are ' + format(pqd2.unused_truck_price, '$#,##0.#0##') + ' per truck.  ' else '' end +  
  case when isnull(PQD2.lay_over_charge, -1) > -1 
  then 'Layovers are ' + format(pqd2.lay_over_charge, '$#,##0.#0##') + ' per day per truck.  ' else '' end  
 ))  
  from profileQuoteDetail pqd2  
  WHERE pqd2.profile_id = pqd.profile_id  
  and pqd.quote_id = pqd.quote_id  
  and pqd2.company_id = pqd.company_id  
  and pqd2.profit_ctr_id = pqd.profit_ctr_id  
  and pqd2.sequence_id = pqd.sequence_id  
  and pqd2.record_type in ('D', 'S', 'T')  
  and isnull(pqd2.bill_method, '') <> 'B'  
 ),  
 ' detail footer fields begin here. They are shown once per unique profit_ctr_name ' as detail_footer_marker ,  
 comments.comment,  
 ' undisplayed fields begin here' as undisplayed_marker ,  
 profile.profile_id,  
 pqd.company_id,  
 pqd.profit_ctr_id,  
 PQD.record_type,  
 PQD.sequence_id,
 comments.price_code
/*  
 ,               PQA.sr_type_code as sr_type_code  
 ,    PQD.quote_id as quote_id  
 ,               PQD.sequence_id as sequence_id  
 ,    PQD.hours_free_loading  
 ,               PQD.hours_free_unloading  
 ,               PQD.demurrage_price  
 ,               PQD.unused_truck_price  
 ,               PQD.lay_over_charge  
 ,               PQD.record_type as record_type  
 ,               PQD.surcharge_price as surcharge_price  
 ,               PQD.bill_method as bill_method  
 ,    PQD.bill_quantity_flag  
 ,    PQD.status  
 ,               PQD.service_desc as service_desc  
 ,               PQD.min_quantity as min_quantity  
 ,               ProfitCenter.surcharge_flag as surcharge_flag  
 ,               Product.fuel_flag as fuel_flag  
 ,               Product.price AS product_price   
 ,               Product.price_override_flag as price_override_flag  
 ,      
   PQD.primary_price_flag,  
   PQD.bulk_flag,  
   PQD.orig_customer_price,  
   PQD.resource_class_code,  
   has_comment = IsNull((SELECT COUNT(*) FROM ProfileQuoteDetailDesc  
   WHERE PQD.quote_id = ProfileQuoteDetailDesc.quote_id  
   AND PQD.company_id = ProfileQuoteDetailDesc.company_id  
   AND PQD.profit_ctr_id = ProfileQuoteDetailDesc.profit_ctr_id  
   AND ProfileQuoteDetailDesc.record_type = 'D'  
   AND ProfileQuoteDetailDesc.sequence_id = 0),0) ,  
   0 as count_price_adjustment,  
   PQA.sr_type_code,  
   ProfitCenter.surcharge_flag,  
   CONVERT(char(1),'') as screen_access,  
   PQD.customer_cost,  
   Customer.customer_cost_flag,  
   split_price_count = (select count(*) from profilequotedetail pqd_s where pqd_s.quote_id = PQD.quote_id and pqd_s.company_id = PQD.company_id and pqd_s.profit_ctr_id = PQD.profit_ctr_id and pqd_s.bill_method = 'B' and ((pqd_s.ref_sequence_id = PQD.seque
nce_id and pqd_s.bill_quantity_flag in ('P','U') or pqd_s.ref_sequence_id = 0 and pqd_s.bill_quantity_flag = 'L'))),  
   split_percent_count = 0, /*(select count(*) from profilequotedetail pqd_s where pqd_s.quote_id = PQD.quote_id and pqd_s.company_id = PQD.company_id and pqd_s.profit_ctr_id = PQD.profit_ctr_id and pqd_s.ref_sequence_id = PQD.sequence_id and pqd_s.bill_m
ethod = 'B' and pqd_s.bill_quantity_flag = 'P'),*/  
   split_record_total = convert(numeric(10,4),isnull(PQD.price,0)) - (select convert(numeric(10,4),sum(isnull(pqd_s.price,0))) from profilequotedetail pqd_s where pqd_s.quote_id = PQD.quote_id and pqd_s.company_id = PQD.company_id and pqd_s.profit_ctr_id 
= PQD.profit_ctr_id and pqd_s.ref_sequence_id = PQD.sequence_id and pqd_s.bill_method = 'B' and pqd_s.bill_quantity_flag in ('P','U')),  
   PQD.show_cust_flag,  
   PQD.currency_code,  
*/     
FROM Profile  
 INNER JOIN ProfileQuoteDetail PQD   
                 ON PQD.profile_id = Profile.profile_id  
                 AND IsNull(PQD.bill_method, '') <> 'B'  
 INNER JOIN ProfileQuoteApproval PQA   
                 ON PQA.profile_id = Profile.profile_id  
                 AND PQA.company_id = PQD.company_id  
                 AND PQA.profit_ctr_id = PQD.profit_ctr_id  
                 AND PQA.status = 'A'  
 INNER JOIN ProfitCenter   
                 ON PQA.profit_ctr_id = ProfitCenter.profit_ctr_id  
                 AND PQA.company_id = ProfitCenter.company_ID  
 INNER JOIN ProfitCenter upc on upc.company_id = pqd.company_id  
  and upc.profit_ctr_id = pqd.profit_ctr_id  
 LEFT OUTER JOIN Product  
        ON Product.product_id = PQD.product_id  
 INNER JOIN Customer ON (Profile.customer_id = Customer.customer_id)  
 INNER JOIN Generator ON (Profile.generator_id = Generator.generator_id)  
 LEFT OUTER JOIN #comments comments  
  ON comments.profile_id = PQD.profile_id  
  AND comments.company_id = PQD.company_id  
  AND comments.profit_ctr_id = PQD.profit_ctr_id  
 WHERE Profile.profile_id in ( select profile_id from @profile_ids ) 
                 --AND PQD.company_id = 2  
                 --AND PQD.profit_ctr_id = 0  
                 AND PQD.status = 'A'  
                 AND PQD.record_type = 'D'  
                 AND ISNULL(PQD.fee_exempt_flag, 'F') = 'F'  
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
) x       
order by profile_id, profit_ctr_name, case record_type  
when 'D' then 1 when 'T' then 2 when 'S' then 3 else 4 end  
, sequence_id, bill_unit_code

GO
GRANT EXECUTE on sp_profile_price_confirmation to COR_USER
GO
GRANT EXECUTE on sp_profile_price_confirmation to EQWEB
GO
GRANT EXECUTE on sp_profile_price_confirmation to EQAI