CREATE PROCEDURE [dbo].[sp_rpt_transporter_fee_pa_electronic]
    @date_from			datetime, 
	@date_to			datetime,
	@customer_id_from	int,
	@customer_id_to		int,
	@manifest_from		varchar(15),
	@manifest_to		varchar(15),
	@EPA_ID			    varchar(15)
,	@work_order_status	char(1)
AS
/***********************************************************************
PA Hazardous Waste Transporter Fee - Electronic Version

Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\Plt_AI\Procedures\sp_rpt_transporter_fee_pa_electronic.sql
PB Object(s):	r_transporter_fee_pa_electronic
		
11/08/2013 AM	Created - 
07/15/2014 JDB	Modified the 4 weight fields to include a decimal point and one decimal place,
				because the reporting guidelines specify that, "All numeric fields must include one decimal place,
				even if it is a "0"."
08/20/2014 JDB	Changed the #tmp to be named #tmpsp, because the stored procedure that this executes
				(sp_rpt_transporter_fee_pa) also has a #tmp, and in that one we added a new part_of_union column 
				that this procedure didn't like when it was doing the insert into it.  
01/24/2017 MPM	Lengthened #tmpsp.waste_code to varchar(100).
05/01/2017 MPM	Added "Work Order Status" as a retrieval argument.  Work Order Status will be either C (Completed, Accepted or Submitted)
				or S (Submitted Only).

sp_rpt_transporter_fee_pa_electronic  '9/1/2013', '9/5/2013', 1, 999999, '010332446JJK', '010332450JJK', 'PAD010154045', 'S'

***********************************************************************/
BEGIN

DECLARE @lines	int

-- This will determine the line#'s per page, in future if we need to change line#'s per page then we can just change this number.  	
set @lines = 10

SET NOCOUNT ON

-- Create temp table tmp
CREATE TABLE #tmpsp (line_number		int		IDENTITY,
	 workorder_id		int         NOT NULL,
	 company_id   		int			NOT NULL,
	 profit_ctr_id		int			NOT NULL,
	 manifest			varchar (15)NULL,
	 manifest_page_num	int       NULL,   
	 manifest_line		int       NULL,   
	 transporter_code   varchar (15)NULL,
	 transporter_EPA_ID varchar (15)NULL,
	 transporter_addr1  varchar (40)NULL,
	 transporter_addr2  varchar (40)NULL,
	 transporter_addr3  varchar (40)NULL,
	 transporter_city  varchar (40)NULL,
	 transporter_state varchar (2)NULL,
	 transporter_zip_code varchar (15)NULL,
	 transporter_country varchar (10)NULL,
	 transporter_contact varchar (40)NULL,
	 transporter_contact_phone varchar (20)NULL,
	 pa_license_num varchar(10),
	 quantity_used int       NULL,
	 bill_unit_code varchar (4)NULL,
	 manifest_quantity int   NULL,
	 manifest_unit varchar (4) NULL,
	 customer_id int NULL,
     TSDF_code varchar (15)NULL,
     TSDF_approval_code varchar (40)NULL,
     waste_stream varchar (10)NULL,
     generator_id int NULL,
	 EPA_ID varchar(15)NULL,
	 waste_code varchar (100)NULL,
	 treatment_method varchar (10)NULL,
	 fee_treat_dispose float       NULL,
	 fee_recycle float       NULL,
	 fee_exempt float       NULL,
	 cust_name varchar (40) NULL,
	 tons_treat_dispose float       NULL,
	 tons_recycle float       NULL,
	 tons_exempt float       NULL,
	 tons_total float       NULL,
	 end_date datetime NULL )
	 
-- Create #return tmp table to insert description
CREATE TABLE #return (
	line_id		int,
	description	varchar (1500)	)
	
-- call sp to insert data into #tmpsp 	
INSERT INTO #tmpsp 
EXECUTE sp_rpt_transporter_fee_pa
		@date_from,
		@date_to,
		@customer_id_from,
		@customer_id_to,
		@manifest_from,
		@manifest_to,
		@EPA_ID,
		@work_order_status
		
-- build result description from #tmpsp 
INSERT INTO #return (line_id, description) 
      select line_number,    
      cast( #tmpsp.transporter_EPA_ID as varchar) + ','  
    + cast((case when #tmpsp.line_number > @lines 
				  then #tmpsp.line_number - (@lines * ((#tmpsp.line_number-1)/@lines)) 
				  else #tmpsp.line_number end) AS VARCHAR) + ',' 
	+ cast(((#tmpsp.line_number -1 )/@lines + 1) AS VARCHAR) + ',' 
	+ cast(case when datepart(mm, #tmpsp.end_date) in (1,2,3) then 1
	            when datepart(mm, #tmpsp.end_date) in (4,5,6) then 2
				when datepart(mm, #tmpsp.end_date) in (7,8,9) then 3 
				when datepart(mm, #tmpsp.end_date) in (10,11,12) then 4
				end AS varchar) + ','
	+ cast(datepart(yyyy, #tmpsp.end_date) as varchar) + ','
	
	--+ cast(isnull( #tmpsp.tons_exempt,0) as varchar) + ','
	--+ cast(isnull( #tmpsp.tons_recycle,0) as varchar) + ','
	--+ cast(isnull( #tmpsp.tons_total,0) as varchar) + ','
	--+ cast(isnull( #tmpsp.tons_treat_dispose,0) as varchar) + ','
	
	+ CAST(ISNULL( #tmpsp.tons_exempt,0) AS varchar) 
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_exempt) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_recycle, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_recycle) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_total, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_total) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ CAST(ISNULL( #tmpsp.tons_treat_dispose, 0) AS varchar)
		-- Add a ".0" to the end of the number if it doesn't already have a decimal; spec requires all numbers to have decimals
		+ CASE CHARINDEX('.', #tmpsp.tons_treat_dispose) WHEN 0 THEN '.0' ELSE '' END 
		+ ','
	+ cast( #tmpsp.manifest as varchar) + ',' 
	+ cast( #tmpsp.manifest_page_num as varchar) + ',' 
	+ cast( #tmpsp.manifest_line as varchar) 
	    FROM #tmpsp order by #tmpsp.manifest,#tmpsp.manifest_line
	       
-- send result set with description 
SELECT #return.description
FROM #tmpsp (NOLOCK)
INNER JOIN #return (NOLOCK)
	ON #tmpsp.line_number = #return.line_id
ORDER BY  #tmpsp.manifest, #tmpsp.manifest_line
	
DROP TABLE #tmpsp
DROP TABLE #return
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_transporter_fee_pa_electronic] TO [EQAI]
    AS [dbo];

