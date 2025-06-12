drop proc if exists sp_ce_get_tsdf_list
go
CREATE PROCEDURE [dbo].[sp_ce_get_tsdf_list]
	@tsdfcode NVARCHAR(50) = NULL
AS
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 05/13/2022
-- Description:	To retrive active TSDF list
-- EXEC sp_ce_get_tsdf_list '7'
-- EXEC sp_ce_get_tsdf_list ''
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements. 
	SET NOCOUNT ON;
	IF @tsdfcode ='' 
	BEGIN
	SET @tsdfcode = NULL
	END

	--Temp table creation for TSDF
	DECLARE @tempTsdf TABLE (TSDF_code VARCHAR(15), TSDF_status char(1),TSDF_name varchar(40),
	TSDF_addr1 VARCHAR(100),TSDF_addr2 VARCHAR(40),TSDF_addr3 VARCHAR(40),
	TSDF_EPA_ID VARCHAR(15),TSDF_phone VARCHAR(20),TSDF_city VARCHAR(40),
	TSDF_state VARCHAR(2),TSDF_zip_code VARCHAR(15),facility_type VARCHAR(10),
	rowguid uniqueidentifier,eq_flag char(1), company_ID int, profit_ctr_ID int,
	profit_ctr_name nvarchar(250), facility VARCHAR(10))
	
   -- Insert EQAI Tsdf
	INSERT INTO @tempTsdf 
		SELECT	TSDF_code,
		TSDF_status,
		TSDF_name,
		TSDF_addr1,
		TSDF_addr2,
		TSDF_addr3,
		TSDF_EPA_ID,
		TSDF_phone,
		TSDF_city,
		TSDF_state,
		TSDF_zip_code,
		facility_type,
		rowguid,
		eq_flag,
		pc.company_ID, 
		pc.profit_ctr_ID, 
		pc.profit_ctr_name,
		'EQAI' facility
FROM TSDF 
left outer join profitcenter pc

       on TSDF.eq_company = pc.company_ID

              and TSDF.eq_profit_ctr = pc.profit_ctr_ID

WHERE TSDF.tsdf_status = 'A' AND (@tsdfcode IS NULL OR TSDF_code =@tsdfcode)
UNION ALL
Select *,  null as facility_type, null as rowguid, null as eq_flag,
null as company_ID, null as profit_ctr_ID, null as profit_ctr_name,
'AESOP' as facility
from COR_DB..AESOPSites
	--BEGIN --Aesop facility
	--	 INSERT INTO @tempTsdf 
	--	VALUES ('7','A', 'US ECOLOGY NEVADA, INC.','HWY 95 11 MILES S. OF BEATTY',NULL,NULL,
	--	'NVT330010000','8002393943','BEATTY','NV','89003',NULL,NULL,NULL,NULL, NULL, NULL, 'AESOP'),
	--		('9','A', 'US ECOLOGY TEXAS, INC.','3277 COUNTY ROAD 69  P.O. BOX 307',NULL,NULL,
	--	'NVT330010000','8002423209','ROBSTOWN','TX','78380',NULL,NULL,NULL,NULL, NULL, NULL,'AESOP'),
	--		('15','A', 'US ECOLOGY IDAHO, INC.','20400 LEMLEY ROAD  ',NULL,NULL,
	--	'IDD073114654','8002741516','GRAND VIEW','ID','83624',NULL,NULL,NULL,NULL, NULL, NULL,'AESOP'),
	--		('100','A', 'US ECOLOGY CORPORATE','Lakepointe Centre I  300 E Mallard Dr,Suite 300',NULL,NULL,
	--	NULL,'8005905220','BOISE','ID','83706',NULL,NULL,NULL,NULL, NULL, NULL,'AESOP'),
	--		('25','A', 'US ECOLOGY MICHIGAN, INC.','6520 GEORGIA ST.  ',NULL,NULL,
	--	'MID074259565','3135717140','DETROIT','MI','48211',NULL,NULL,NULL,NULL, NULL, NULL,'AESOP')
	--END

SELECT * FROM @tempTsdf WHERE tsdf_status = 'A' AND (@tsdfcode IS NULL OR TSDF_code =@tsdfcode)
END

