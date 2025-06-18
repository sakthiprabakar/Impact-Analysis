USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [sp_Cor_Bulkrenew_Profile_List]
GO

CREATE   PROCEDURE [dbo].[sp_Cor_Bulkrenew_Profile_List]
	
	@profile_count  int = 100,
	@web_userid varchar(100)='all_customers'


AS

	
/* ****************************************************************
		
		Updated By			: Divya Bharathi R  
		Updated On			: 4th Mar 2025 
		Type				: Stored Procedure   
		Object Name			: [sp_Cor_Bulkrenew_Profile_List]  
		Last Change			: Altered the condition in ProfileQuoteApproval to exclude MDI Facility
		Ticket Reference	: DE37954- UAT Bug: Express Renewal > Express Renewal Window is Not Retrieving Valid Candidates for Renewal
		Execution Statement	: exec sp_Cor_Bulkrenew_Profile_List 100, 'all_customers'

*******************************************************************/

-- avoid query plan caching:
begin
declare
    @i_web_userid		varchar(100) = isnull(@web_userid,'all_customers'),
    @i_status_list		varchar(2000) = 'expired,for renewal',   
    @i_page				int = 1,
    @i_perpage			int = @profile_count,
    @i_owner			varchar(5) = 'all',
    @i_email			varchar(100),
    @i_contact_id		int,
    @i_period			varchar(4) = '',
    @i_period_int		int = 0 ,
	@i_totalcount		int= 0
 
 
select top 1 
	@i_contact_id = contact_id
	, @i_email = email
from CORcontact c 
WHERE web_userid = @i_web_userid
and web_userid <> ''
 
select @i_period_int =
	case @i_period
		when 'WW' then datediff(dd, dateadd(ww, -1, getdate()) , getdate())
		when 'QQ' then datediff(dd, dateadd(qq, -1, getdate()) , getdate())
		when 'MM' then datediff(dd, dateadd(mm, -1, getdate()) , getdate())
		when 'YY' then datediff(dd, dateadd(yyyy, -1, getdate()) , getdate())
		when '30' then 30
		when '60' then 60
		else ''
	end

 
 
declare @status table (
	i_status	varchar(40)
)
if isnull(@i_status_list, 'all') <> 'all'
insert @status
select left(row,40)
from dbo.fn_SplitXsvText(',', 1, @i_status_list)
where row is not null
 
 
if isnull(@i_period_int, 0) <=1
	and exists (select 1 from @status where i_status like '%renewal 60%')
	set @i_period_int = 60
 
if isnull(@i_period_int, 0) <=1
	and exists (select 1 from @status where i_status like '%renewal%')
	set @i_period_int = 30
 
--#region USE Profile Search
drop table if exists #TMP;
select 
    profile_id,
	expiration_date,
	_row,
	under_review
    INTO #TMP
from (
    select TOP (@profile_count)
        p.profile_id,
		p.ap_expiration_date expiration_date,
		_row = row_number() over (order by p.ap_expiration_date desc),
		case when	
				(
					p.document_update_status <> 'P'
					OR
					p.document_update_status = 'P' AND p.doc_status_reason in (
						'Rejection in Process', 
						'Amendment in Process', 
						'Renewal in Process',
						'Profile Sync Required',
						'Data Update')
				)
		then 'N' else 'U' end as under_review
    from ContactCORProfileBucket b
    join [Profile] p
        on b.profile_id = p.profile_id
    join Customer cn on p.customer_id = cn.customer_id
    join Generator gn on p.generator_id = gn.generator_id
    left join generatortype gt on gn.generator_type_id = gt.generator_type_id
	where b.contact_id = @i_contact_id
	and p.curr_status_code = 'A'
	and p.inactive_flag <> 'T'
	and p.ap_expiration_date > dateadd(yyyy, -2, getdate())
	and NOT EXISTS (select TOP 1 quote_id from ProfileQuoteApproval pqa where pqa.profile_id = p.profile_id     
	and pqa.status='A' and pqa.company_id = 2 and pqa.profit_ctr_id = 0    
	)
	--and NOT EXISTS (select TOP 1 quote_id from ProfileQuoteApproval pqa where pqa.profile_id = p.profile_id 
	--and pqa.status='A' and pqa.company_id = 22 and pqa.profit_ctr_id = 0
	--)
 
    and 1 = 
		case 
			when @i_owner = 'mine' 
			and (@i_email in (p.added_by /*, p.modified_by */)  or @i_web_userid in (p.added_by /*, p.modified_by */))
			then 1 else 
			case when exists (
				select top 1 1
				from formwcr
				where form_id = p.form_id_wcr
				and (
					@i_email in (formwcr.created_by /*, formwcr.modified_by */)
					or 
					@i_web_userid in (formwcr.created_by /*, formwcr.modified_by */)
				)
				) then 1 else 
					case when @i_owner = 'all' then 1 else 0 end
				end
			end
    and 1 = case when 
				exists (select 1 from @status where i_status like 'For Renewal%')
				and p.ap_expiration_date > getdate() and p.ap_expiration_date <= getdate()+@i_period_int then 1 else
				case when 
					exists (select 1 from @status where i_status = 'Expired')
					and p.ap_expiration_date < getdate() 
					/* -- 6/13/2022, DO-41782
					and not exists (
						select 1 from formWCR fw where fw.profile_id = p.profile_id 
						and isnull(fw.signing_date, getdate()+2) between dateadd(mm, -2, getdate()) and getdate()
					)
					*/
					then 1 else 0 end
			 end									    	
    and 
    (
		 NOT EXISTS(select bn.profile_id from BulkRenewProfile bn where status in ('new','validated') and bn.profile_id = p.profile_id)
	)
 
) x
 
 
insert into BulkRenewProfile (profile_id, status, date_added, added_by, date_modified, modified_by)		
	SELECT    
		profile_id,
		'new',
		getdate(),
		'COR',
		getdate(),
		'COR'
	FROM #TMP 
	ORDER BY _row 	
	 OFFSET @i_perpage * (@i_page - 1) ROWS
		FETCH NEXT @i_perpage ROWS ONLY
	DECLARE @profile_id int
 
	DECLARE bulk_cursor CURSOR FOR
	SELECT profile_id FROM BulkRenewProfile where status = 'New'  
 
	OPEN bulk_cursor
 
	FETCH NEXT FROM bulk_cursor INTO @profile_id
	WHILE @@FETCH_STATUS = 0
	BEGIN
 
		EXEC sp_Validate_ProfileSections @profile_id,'COR'
 
		UPDATE BulkRenewProfile SET STATUS ='Validated' WHERE profile_id = @profile_id
 
	FETCH NEXT FROM bulk_cursor INTO @profile_id
	END
 
	CLOSE bulk_cursor
	DEALLOCATE bulk_cursor;
 
RETURN 0
 
END
GO 

GRANT EXEC ON [dbo].[sp_Cor_Bulkrenew_Profile_List] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_Cor_Bulkrenew_Profile_List]  TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_Cor_Bulkrenew_Profile_List]  TO EQAI 
GO 