-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 02/18/2020
-- Description:	To fetch generator list based on labpack flag

-- EXEC sp_labpack_related_generator 'florida sta'
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_related_generator]
	-- Add the parameters for the stored procedure here
	@search			varchar(100) = '',
	@sort			varchar(20) = '',
	@page			int = 1,
	@perpage		int = 200
	
AS
BEGIN

	SET NOCOUNT ON;
	
-- avoid query plan caching:
DECLARE @i_search	varchar(100) = isnull(@search, '')

   --+'	'+ISNULL(EPA_ID,'')+ '	'+ISNULL(generator_address_1,'') as generator_name
	SELECT generator_id ,EPA_ID ,generator_name ,generator_address_1 ,generator_address_2 ,
	generator_address_3 ,generator_address_4 ,generator_address_5 ,
	generator_phone ,gen_mail_name ,gen_mail_addr1 ,gen_mail_addr2 ,gen_mail_addr3 ,gen_mail_addr4 ,
	generator_state ,generator_city ,generator_country ,
	generator_zip_code ,gen_mail_state ,gen_mail_city ,
	Gen_mail_country ,gen_mail_zip_code 
	 FROM generator where generator_id in(
select distinct(gen.generator_id) from WorkOrderHeader woh
--left join customer cus on woh.customer_ID= cus.customer_ID
left join generator gen on woh.generator_id= gen.generator_id and  gen.status='A')
AND @i_search <> '' AND generator_name like '%' + @i_search + '%'
--WHERE @i_search <> '' AND generator_name like '%' + @i_search + '%' and [STATUS]='A'

END