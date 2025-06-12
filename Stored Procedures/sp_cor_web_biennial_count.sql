--  
drop proc sp_COR_web_biennial_count
go

CREATE PROC sp_COR_web_biennial_count (
	@web_userid			varchar(100)
	, @generator_id_list	varchar(max)=''
	, @receipt_start_date	datetime
	, @receipt_end_date	datetime
	, @report_level		char(1)	-- 'S'ummary or 'D'etail
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */ 
) AS
/* ********************************************************************
sp_COR_web_biennial_count
	Customer Service designated "biennial" report for web users.
	Not necessarily a REAL "biennial" report, but similar info.

History
	08/02/2013 JPB	Created
	01/10/2014 JPB	Modified per discussion with CS about weight methods & labels.
	02/26/2018 JPB	GEM-48410: Modified to use standard functions for weight/description
					Modified with accurate filter against voided receipt lines
	10/07/2019 MPM  DevOps 11618: Added logic to filter the result set
					using optional input parameter @customer_id_list.


Samples
SELECT  * FROM  receipt WHERE profile_id = 491824 and receipt_date between '1/1/2017' and '12/31/2017 23:59'

sp_COR_web_biennial_count 
-- sp_COR_web_biennial_list
	@web_userid			= 'nyswyn100'
	, @generator_id_list	= ''
	, @receipt_start_date	= '1/1/2017'
	, @receipt_end_date		= '1/1/2021'
	, @report_level		= 'D'
	
sp_COR_web_biennial_count 
	@web_userid			= 'thames'
	, @generator_id_list	= ''
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = ''

sp_COR_web_biennial_count 
	@web_userid			= 'thames'
	, @generator_id_list	= '137729'
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = '14164'

sp_COR_web_biennial_count 
	@web_userid			= 'thames'
	, @generator_id_list	= ''
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = '14164'

sp_COR_web_biennial_count 
	@web_userid			= 'thames'
	, @generator_id_list	= '137729'
	, @receipt_start_date	= '1/1/2018'
	, @receipt_end_date		= '10/07/2019'
	, @report_level		= 'D'	
	, @customer_id_list = ''

select generator_id from customergenerator where customer_id = 888880
union
select generator_id from profile where customer_id = 888880
	
SELECT  *  FROM    generator where generator_name = 'AMAZON DMO1'	
******************************************************************** */

/*
-- Debuggging
declare
	@web_userid			varchar(100) = 'nyswyn100'
	, @customer_id_list varchar(max)='15622'  /* Added 2019-07-17 by AA */ 
	, @generator_id_list	varchar(max)='168428'
	, @receipt_start_date	datetime = '1/1/2018'
	, @receipt_end_date	datetime = '3/30/2020'
	, @report_level		char(1)	= 'D' -- 'S'ummary or 'D'etail

*/

declare
	@i_web_userid			varchar(100)	= isnull(@web_userid, '')
	, @i_generator_id_list	varchar(max)	= isnull(@generator_id_list, '')
    , @i_customer_id_list	varchar(max)	= isnull(@customer_id_list, '')
	, @i_date_start			datetime		= convert(date, @receipt_start_date)
	, @i_date_end			datetime		= convert(date, @receipt_end_date)
	, @i_report_level		char(1)			= isnull(@report_level, 'S')
	, @i_contact_id			int

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999


	declare @outd table (
		Generator_Name	varchar(255)
		, Generator_EPA_ID	varchar(255)
		, Generator_Address varchar(max)
		, Generator_City	varchar(40)
		, Generator_State	varchar(2)
		, Generator_Zip_Code	varchar(15)
		, Generator_County	varchar(40)
		, Site_Code	varchar(20)
		, Profile_ID	int
		, Approval_Code	varchar(255)
		, Waste_Description	varchar(max)
		, Facility_Name	varchar(255)
		, Facility_EPA_ID	varchar(255)
		, Pickup_Date datetime
		, Receipt_Date datetime
		, Manifest	varchar(255)
		, Manifest_Line	varchar(255)
		, Federal_Waste_Codes	varchar(max)
		, State_Waste_Codes		varchar(max)
		, [Hazardous/Non-Hazardous]	varchar(255)
		, EPA_Source_Code	varchar(255)
		, EPA_Form_Code	varchar(255)
		, Management_Code	varchar(255)
		, Total_Pounds	float
		, Weight_Method	varchar(255)
		, Note varchar(1000)
		, [DO NOT DISPLAY customer_id] int
		, [DO NOT DISPLAY orig_customer_id] int
		, [DO NOT DISPLAY orig_customer_id_list] varchar(max)
		, [DO NOT DISPLAY generator_id] int
	)

	declare @outs table (
		Generator_Name	varchar(255)
		, Generator_EPA_ID	varchar(255)
		, Generator_Address varchar(max)
		, Generator_City	varchar(40)
		, Generator_State	varchar(2)
		, Generator_Zip_Code	varchar(15)
		, Generator_County	varchar(40)
		, Site_Code	varchar(20)
		, Profile_ID	int
		, Approval_Code	varchar(255)
		, Waste_Description	varchar(max)
		, Facility_Name	varchar(255)
		, Facility_EPA_ID	varchar(255)
		, Federal_Waste_Codes	varchar(max)
		, State_Waste_Codes		varchar(max)
		, [Hazardous/Non-Hazardous]	varchar(255)
		, EPA_Source_Code	varchar(255)
		, EPA_Form_Code	varchar(255)
		, Management_Code	varchar(255)
		, Total_Pounds	float
		, Weight_Method	varchar(255)
		, Note varchar(1000)
	)

if @report_level = 'D' 
begin

	insert @outd
	exec sp_COR_web_biennial_list
		@web_userid			= @i_web_userid
		, @generator_id_list	= @i_generator_id_list
		, @receipt_start_date	= @i_date_start
		, @receipt_end_date	= @i_date_end
		, @report_level		= @i_report_level
		, @customer_id_list = @i_customer_id_list

	select count(*) from @outd

end
	
if @report_level = 'S'
begin

	insert @outs
	exec sp_COR_web_biennial_list
		@web_userid			= @i_web_userid
		, @generator_id_list	= @i_generator_id_list
		, @receipt_start_date	= @i_date_start
		, @receipt_end_date	= @i_date_end
		, @report_level		= @i_report_level
		, @customer_id_list = @i_customer_id_list

	select count(*) from @outs
end

RETURN 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_web_biennial_count] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_web_biennial_count] TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_web_biennial_count] TO [EQAI]
    AS [dbo];

