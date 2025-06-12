
CREATE PROCEDURE sp_rpt_steers_validation_report
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from		datetime
,	@date_to		datetime
AS
/***************************************************************************************
r_steers_validation

04/17/2018 AM	Created
05/23/2018 AM   Modified state_id logic
06/20/2018 AM  EQAI-51442 - STEERS Validation Report Additions. Added more validation checks.
05/22/2020 MPM	DevOps 14433 - Added DISTINCT keyword to subquery to avoid error. 

sp_rpt_steers_validation_report 29, 0,  '1/1/2018', '3/1/2018'

sp_rpt_steers_validation_report 46, 0,  '5/23/2018' ,'5/24/2018' 

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE 
	@debug 				int,
	@valid		    varchar (4000),
	@tx_waste_code_count int,
	@federal_waste_code_count int,
	@tx_waste_code_not_steers_count int,
	@receipt_id int,
	@line_id  int,
	@display_name varchar (10),
	@industrial_flag char (1)
	
CREATE TABLE #validation  (
	generator_state_id varchar(40),
	generator_id int,
	generator_epa_id	varchar(12),
	generator_state		varchar(2),
	transporter_state_id varchar(40),
	transporter_code varchar(15),
	transporter_EPA_ID	varchar(15),
	receipt_id		int,
	line_id int,
	tx_display_name varchar(10)
	)
	
CREATE TABLE #validationall  (
	issues varchar(4000) Null
)

Insert into #validation
SELECT 
    --g.state_id,
    CASE when g.generator_state = 'TX'
     THEN g.state_id
     else
        ( select trlc.tx_out_of_state_generator_code 
        from  TexasReportingLocationCode trlc
        where g.generator_state = trlc.state_code )
     end as state_id ,
    g.generator_id,
	g.EPA_ID,
	g.generator_state,    
	trid.transporter_state_id,
	tr.transporter_code,
	tr.transporter_EPA_ID,
	r.receipt_id,
	r.line_id,
	tx_display_name = (Select DISTINCT wc.display_name from ReceiptWasteCode rwc 
					join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid 
					where wc.state = 'TX' 
					and rwc.company_id = @company_id 
					and rwc.profit_ctr_id = @profit_ctr_id 
					and rwc.receipt_id = r.receipt_id
					and rwc.line_id = r.line_id
					and wc.STEERS_reportable_flag = 'T' )
from receipt r 
	join generator g
		on r.generator_id = g.generator_id
	join tsdf t
		on t.eq_company = @company_id
		and t.eq_profit_ctr = @profit_ctr_id
		and t.tsdf_status = 'A'
		and t.eq_flag = 'T'
		and t.tsdf_state = 'TX' 
	join transporter tr
		on r.hauler = tr.transporter_code
	left outer join TransporterXStateID trid
		on tr.transporter_code = trid.transporter_code
		and trid.transporter_state = 'TX'
	join treatment trt
		on r.treatment_id = trt.treatment_id
		and r.company_id = trt.company_id
		and r.profit_ctr_id = trt.profit_ctr_id
where 
	r.receipt_date between @date_from AND @date_to
	and r.company_id = @company_id
	and r.profit_ctr_id = @profit_ctr_id
	and r.receipt_status not in ('V', 'R')  
	and r.trans_mode = 'I'  
	and r.trans_type = 'D'  
	and (  --check for the presence of a STEERS reportable waste code
		select count(*) 
		from ReceiptWasteCode rwc 
		join wastecode wc 
		on rwc.waste_code_uid = wc.waste_code_uid 
		where wc.state = 'TX' 
		and rwc.company_id = r.company_id 
		and rwc.profit_ctr_id = r.profit_ctr_id 
		and rwc.receipt_id = r.receipt_id 
		and rwc.line_id = r.line_id
		and wc.STEERS_reportable_flag = 'T') > 0
	--Added for Gemini 51443
	--this next condition is to exclude receipt lines where the generator industrial flag = 'F' and the Texas code ends in a '1' and there are no Federal waste codes
	and not (g.industrial_flag <> 'T'
		and (  --check for the presence of a STEERS reportable waste code ending in '1'
			select count(*) 
				from ReceiptWasteCode rwc 
				join wastecode wc 
				on rwc.waste_code_uid = wc.waste_code_uid 
				where wc.state = 'TX' 
				and rwc.company_id = r.company_id 
				and rwc.profit_ctr_id = r.profit_ctr_id 
				and rwc.receipt_id = r.receipt_id 
				and rwc.line_id = r.line_id
				and wc.STEERS_reportable_flag = 'T'
				and Right(wc.display_name, 1) = '1' ) > 0 
		and  ( --check that the line has no federal waste codes
				select count(*) 
					from ReceiptWasteCode rwc 
					join wastecode wc 
					on rwc.waste_code_uid = wc.waste_code_uid 
					where  rwc.company_id = r.company_id 
					and rwc.profit_ctr_id = r.profit_ctr_id 
					and rwc.receipt_id = r.receipt_id 
					and rwc.line_id = r.line_id
					and  wc.waste_code_origin = 'F' ) = 0   
		)
order by r.receipt_date 

insert into  #validationall
 ( issues ) select Distinct 'Generator State ID is missing for Generator ' + CONVERT ( varchar (10),generator_id ) + '.'
 from #validation
 where #validation.generator_state_id is null 
 
insert into  #validationall
 ( issues ) select Distinct 'Transporter State ID is missing for Transporter Code ' + transporter_code + '.'
 from #validation
 where #validation.transporter_state_id is null 
 
insert into  #validationall
 ( issues ) select Distinct 'Transporter EPA ID is not 12 characters long for Transporter Code ' + transporter_code + '.'
 from #validation
 where Len (#validation.transporter_EPA_ID)  <> 12 

 DECLARE waste_code_validation_Cursor CURSOR FOR
	 SELECT receipt_id, line_id 
	 FROM #validation
	 
	 OPEN waste_code_validation_Cursor
	 
	 FETCH NEXT FROM waste_code_validation_Cursor INTO @receipt_id, @line_id
	 WHILE @@FETCH_STATUS = 0
		BEGIN
		 SELECT @tx_waste_code_count = (Select Count(*) from ReceiptWasteCode rwc 
							join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid 
						where wc.state = 'TX' 
						and rwc.company_id = @company_id 
						and rwc.profit_ctr_id = @profit_ctr_id 
						and rwc.receipt_id = @receipt_id
						and rwc.line_id = @line_id
						and wc.STEERS_reportable_flag = 'T'
						and Right(wc.display_name, 1) = '1' ),
			@federal_waste_code_count = ( Select Count(*)from ReceiptWasteCode rwc 
							join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid 
						where rwc.company_id = @company_id  
						and rwc.profit_ctr_id = @profit_ctr_id 
						and rwc.receipt_id =  @receipt_id
						and rwc.line_id = @line_id
						and wc.waste_code_origin = 'F'),
			@tx_waste_code_not_steers_count = (Select Count(*) from ReceiptWasteCode rwc 
							join wastecode wc on rwc.waste_code_uid = wc.waste_code_uid 
						where wc.state = 'TX' 
						and rwc.company_id = @company_id 
						and rwc.profit_ctr_id = @profit_ctr_id 
						and rwc.receipt_id = @receipt_id
						and rwc.line_id = @line_id
						and wc.STEERS_reportable_flag = 'F' ),
			@industrial_flag  = ( select industrial_flag from generator g where g.generator_id = #validation.generator_id )
		  FROM #validation 
		 
	      	 insert into  #validationall
			 ( issues ) select Distinct 'Receipt ' +  CONVERT ( varchar (2), @company_id ) + '-' + CONVERT ( varchar (2), @profit_ctr_id) + '-' 
			       + CONVERT ( varchar (10), @receipt_id ) + '-' + CONVERT ( varchar (3),  @line_id ) +
			        ': Texas waste code ends in a 1 but federal hazardous codes exist.'
			 from #validation
			 where ( @tx_waste_code_count > 0 AND @federal_waste_code_count > 0 )
             
			insert into  #validationall
			( issues ) select Distinct'Receipt ' + CONVERT ( varchar (2), @company_id ) + '-' + CONVERT ( varchar (2), @profit_ctr_id) + '-' 
			    + CONVERT ( varchar (10),@receipt_id   ) + '-' + CONVERT ( varchar (3),  @line_id  ) + 
			    ': Texas waste code is not set as STEERS reportable but federal hazardous codes exist.'
			from #validation
			where @federal_waste_code_count > 0 AND @tx_waste_code_not_steers_count > 0 

 		    insert into  #validationall
			( issues ) select Distinct'Receipt ' + CONVERT ( varchar (2), @company_id ) + '-' + CONVERT ( varchar (2), @profit_ctr_id) + '-' 
			    + CONVERT ( varchar (10),@receipt_id   ) + '-' + CONVERT ( varchar (3),  @line_id  ) + 
			    'Receipt {company id}-{profit_ctr_id}-{receipt_id}-{line_id}: Texas waste code is not set as STEERS reportable and the generator is not industrial but federal hazardous codes exist.'
            from #validation
			where @federal_waste_code_count > 0 AND @tx_waste_code_not_steers_count > 0 and @industrial_flag <> 'T' 
			

			FETCH NEXT FROM waste_code_validation_Cursor INTO @receipt_id, @line_id 
		END		

		CLOSE waste_code_validation_Cursor
		DEALLOCATE waste_code_validation_Cursor
             
insert into  #validationall
( issues ) select Distinct 'Receipt ' + CONVERT ( varchar (2), @company_id ) + '-' + CONVERT ( varchar (2), @profit_ctr_id) + '-' 
   + CONVERT ( varchar (10), #validation.receipt_id  ) + '-' + CONVERT ( varchar (3),  #validation.line_id  ) + 
     ': CESQ Texas waste code assigned but the generator EPA ID is not TXCESQG or the generator state is not CESQ.'
from #validation
where (  Left( #validation.tx_display_name,4) = 'CESQ' AND #validation.generator_epa_id <> 'TXCESQG' AND  left ( #validation.generator_state_id,4) <> 'CESQ'  )

insert into  #validationall
( issues )
        ( Select Distinct dbo.fn_epa_id_validate (a.generator_epa_id) + a.generator_epa_id 
		from #validation a
		where generator_epa_id is not null 
		and  dbo.fn_epa_id_validate (a.generator_epa_id)  <> 'Valid' )
   	
select * from #validationall


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_steers_validation_report] TO [EQAI]
    AS [dbo];

