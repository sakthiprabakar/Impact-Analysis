
CREATE PROCEDURE sp_rpt_stock_container_detail_review_approval_info
	@company_id					int
,	@profit_ctr_id 				int
,	@receipt_id					int
,	@line_id					int
,	@container_id				int
AS
/***************************************************************************************
02/05/2018 MPM	Created
04/24/2018 MPM	Added air permit status code

sp_rpt_stock_container_detail_review_approval_info 42, 0, 0, 3008, 3008
sp_rpt_stock_container_detail_review_approval_info 44, 0, 0, 7, 7
sp_rpt_stock_container_detail_review_approval_info 44, 0, 0, 6, 6
sp_rpt_stock_container_detail_review_approval_info 21, 0, 0, 298856, 298856

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #approval_info (
	approval_code			varchar(15)		NULL,
	profile_id				int				NULL,
	DOT_shipping_name		varchar(255)	NULL,
	hand_instruct			text			NULL,
	approval_comments		text			NULL,
	lab_comments			text			NULL,
	container_comments		text			NULL,
	consistency				varchar(50)		NULL,
	color					varchar(25)		NULL,
	CCVOC					float			NULL,
	DDVOC					float			NULL,
	pH_from					float			NULL,
	pH_to					float			NULL,
	air_permit_status_code	varchar(10)		NULL,
	air_permit_flag			char(1)			NULL
)

insert into #approval_info
select distinct 
	r.approval_code, 
	p.profile_id, 
	p.DOT_shipping_name, 
	null,
	null,
	null,
	null,
	pl.consistency, 
	pl.color, 
	pl.CCVOC, 
	pl.DDVOC, 
	pl.pH_from, 
	pl.pH_to,
	a.air_permit_status_code,
	isnull(pc.air_permit_flag, 'F')
from dbo.fn_container_source_receipt(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id) containers
join Receipt r (nolock)
	ON r.company_id = containers.company_id 
	AND r.profit_ctr_id = containers.profit_ctr_id 
	AND r.receipt_id = containers.receipt_id 
	AND r.line_id = containers.line_id
join Profile p (nolock)
	ON p.profile_id = r.profile_id
join ProfileLab pl (nolock)
	on pl.profile_id = p.profile_id
	and pl.type = 'A'
join ProfileQuoteApproval pqa (nolock)
	on pqa.company_id = @company_id
	and pqa.profit_ctr_id = @profit_ctr_id
	and pqa.profile_id = r.profile_id
	and pqa.approval_code = r.approval_code
left outer join AirPermitStatus a (nolock)
	on a.air_permit_status_uid = pqa.air_permit_status_uid
join ProfitCenter pc (nolock)
	on pc.company_ID = r.company_id
	and pc.profit_ctr_ID = r.profit_ctr_id
	
update #approval_info
	set hand_instruct = p.hand_instruct,
		approval_comments = p.approval_comments,
		lab_comments = p.lab_comments
  from #approval_info a
  join Profile p
  on p.profile_id = a.profile_id

update #approval_info	
	set container_comments = cc.comment
	from ContainerComment cc
		where cc.company_id = @company_id
		and cc.profit_ctr_id = @profit_ctr_id
		and cc.receipt_id = @receipt_id
		and cc.line_id = @line_id
		and cc.container_id = @container_id
		
select approval_code, 
	profile_id, 
	DOT_shipping_name, 
	hand_instruct,
	approval_comments,
	lab_comments,
	container_comments,
	consistency, 
	color, 
	CCVOC, 
	DDVOC, 
	pH_from, 
	pH_to,
	air_permit_status_code,
	air_permit_flag
from #approval_info
order by approval_code
		
GRANT EXECUTE ON sp_rpt_stock_container_detail_review_approval_info TO EQAI

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_stock_container_detail_review_approval_info] TO [EQAI]
    AS [dbo];

