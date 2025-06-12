
CREATE PROCEDURE sp_PopulateCRMFacilityList 
AS
/***************************************************************************************
Populates the CRMFacilityList table with information from the ProfitCenter table.
For use by the ReportInfo SSIS packages, in order to parse out addresses of the
EQAI profit centers.

Loads on PLT_AI

01/07/2016 JDB	Created.
04/12/2016 JDB	Commented out the join to PhoneListLocation when retrieving from
				ProfitCenter.  Added name fix for the two Detroit locations.

EXEC sp_PopulateCRMFacilityList;

SELECT * FROM CRMFacilityList ORDER BY FACILITY_NAME;
****************************************************************************************/
BEGIN
	IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'CRMFacilityList') AND TYPE IN (N'U'))
	BEGIN
		TRUNCATE TABLE CRMFacilityList;

		INSERT INTO CRMFacilityList
		SELECT 'EQAI' AS FACILITY_SOURCE
			, CONVERT(int, NULL) AS FACILITY_LOCATION
			, ProfitCenter.company_id AS FACILITY_COMPANY
			, ProfitCenter.profit_ctr_id AS FACILITY_PROFIT_CENTER
			--, COALESCE(PhoneListLocation.name, ProfitCenter.profit_ctr_name) AS FACILITY_NAME_OLD
			, UPPER(ProfitCenter.profit_ctr_name) AS FACILITY_NAME
			, UPPER(ISNULL(ProfitCenter.EPA_ID, '')) AS FACILITY_EPA_ID
			, UPPER(ISNULL(ProfitCenter.address_1, '')) AS FACILITY_ADDRESS_1
			, UPPER(ISNULL(ProfitCenter.address_2, '')) AS FACILITY_ADDRESS_2
			, UPPER(ISNULL(ProfitCenter.address_3, '')) AS FACILITY_ADDRESS_3
			, UPPER(CONVERT(nvarchar(50), '')) AS FACILITY_CITY
			, UPPER(CONVERT(nvarchar(2), '')) AS FACILITY_STATE
			, UPPER(CONVERT(nvarchar(15), '')) AS FACILITY_ZIP
			, 'USA' AS FACILITY_COUNTRY
			, CONVERT(nvarchar(255), NULL) AS CSZ
		FROM ProfitCenter
		--LEFT OUTER JOIN PhoneListLocation ON PhoneListLocation.company_id = ProfitCenter.company_ID
		--	AND PhoneListLocation.profit_ctr_id = ProfitCenter.profit_ctr_ID
		WHERE ProfitCenter.status = 'A'
		AND ProfitCenter.company_id NOT IN (16, 18, 28)
		AND NOT (ProfitCenter.company_id = 14 AND ProfitCenter.profit_ctr_id = 11)
		AND NOT (ProfitCenter.company_id = 21 AND ProfitCenter.profit_ctr_id = 2)
		AND NOT (ProfitCenter.company_id = 21 AND ProfitCenter.profit_ctr_id = 3)
		AND NOT (ProfitCenter.company_id = 22 AND ProfitCenter.profit_ctr_id = 1)
		ORDER BY ProfitCenter.company_id, ProfitCenter.profit_ctr_id;

		-- Added 4/12/16 to name the two Detroit facilities in a consistent manner.
		UPDATE CRMFacilityList SET FACILITY_NAME = 'U.S. ECOLOGY DETROIT (SOUTH)' WHERE FACILITY_COMPANY = 21 AND FACILITY_PROFIT_CENTER = 0
		UPDATE CRMFacilityList SET FACILITY_NAME = 'U.S. ECOLOGY DETROIT (NORTH)' WHERE FACILITY_COMPANY = 41 AND FACILITY_PROFIT_CENTER = 0

		UPDATE CRMFacilityList SET FACILITY_ADDRESS_1 = UPPER(FACILITY_ADDRESS_1), FACILITY_ADDRESS_2 = UPPER(FACILITY_ADDRESS_2), FACILITY_ADDRESS_3 = UPPER(FACILITY_ADDRESS_3);
		UPDATE CRMFacilityList SET FACILITY_ADDRESS_2 = REPLACE(FACILITY_ADDRESS_2, 'Michigan', 'MI');
		UPDATE CRMFacilityList SET FACILITY_ADDRESS_2 = REPLACE(FACILITY_ADDRESS_2, 'Georgia', 'GA');

		UPDATE CRMFacilityList SET CSZ = FACILITY_ADDRESS_2 
		WHERE (((CRMFacilityList.FACILITY_ADDRESS_2) IS NOT NULL 
		AND (CRMFacilityList.FACILITY_ADDRESS_2) NOT LIKE ''
		AND (CRMFacilityList.FACILITY_ADDRESS_2) NOT LIKE 'UNITED %' 
		AND (CRMFacilityList.FACILITY_ADDRESS_2) NOT LIKE 'us%') 
		AND (CRMFacilityList.FACILITY_ADDRESS_3 LIKE ''  OR CRMFacilityList.FACILITY_ADDRESS_3 IS NULL OR 
		CRMFacilityList.FACILITY_ADDRESS_3  LIKE 'UNITED %' 
		OR (CRMFacilityList.FACILITY_ADDRESS_3) LIKE 'us%') );

		UPDATE CRMFacilityList SET CSZ = FACILITY_ADDRESS_3 
		WHERE ((CRMFacilityList.FACILITY_ADDRESS_3) IS NOT NULL 
		AND (CRMFacilityList.FACILITY_ADDRESS_3) NOT LIKE ''
		AND (CRMFacilityList.FACILITY_ADDRESS_3) NOT LIKE 'UNITED %' 
		AND (CRMFacilityList.FACILITY_ADDRESS_3) NOT LIKE 'us%');

		UPDATE CRMFacilityList 
		SET FACILITY_ZIP = LTRIM(SUBSTRING (CSZ, LEN(CSZ)+1- CHARINDEX(' ' ,REVERSE(REPLACE(CSZ,'-',''))), LEN(CSZ))) 
		WHERE ISNUMERIC (SUBSTRING (REVERSE(REPLACE(CSZ,'-','')),1,4)) = 1;



		UPDATE CRMFacilityList 
		SET FACILITY_CITY= CASE 
			WHEN CHARINDEX(',',CSZ)> 0 THEN SUBSTRING(CSZ, 1, CONVERT(integer, CHARINDEX(',',CSZ))-1) 
			END
		, FACILITY_STATE = CASE 
			WHEN CHARINDEX(',',CSZ)> 0 THEN 
			LTRIM(REPLACE(SUBSTRING(CSZ,
			LEN(SUBSTRING(CSZ, 1, CONVERT(integer, CHARINDEX(',',CSZ))))+1,
			LEN(CSZ)),
			LTRIM(SUBSTRING (CSZ, LEN(CSZ)+1-CONVERT (int,CHARINDEX(' ',REVERSE(REPLACE(CSZ,'-','')))),
			LEN(CSZ))),''))
			END
		WHERE CSZ IS NOT NULL;


		UPDATE CRMFacilityList SET FACILITY_ADDRESS_2 =  ''
		WHERE (((CRMFacilityList.FACILITY_ADDRESS_2) IS NOT NULL 
		AND (CRMFacilityList.FACILITY_ADDRESS_2) NOT LIKE ''
		AND (CRMFacilityList.FACILITY_ADDRESS_2) NOT LIKE 'UNITED %' 
		AND (CRMFacilityList.FACILITY_ADDRESS_2) NOT LIKE 'us%') 
		AND (CRMFacilityList.FACILITY_ADDRESS_3 LIKE ''  OR CRMFacilityList.FACILITY_ADDRESS_3 IS NULL OR 
		CRMFacilityList.FACILITY_ADDRESS_3  LIKE 'UNITED %' 
		OR (CRMFacilityList.FACILITY_ADDRESS_3) LIKE 'us%') );

		UPDATE CRMFacilityList SET FACILITY_ADDRESS_3 = ''
		WHERE ((CRMFacilityList.FACILITY_ADDRESS_3) IS NOT NULL 
		AND (CRMFacilityList.FACILITY_ADDRESS_3) NOT LIKE ''
		AND (CRMFacilityList.FACILITY_ADDRESS_3) NOT LIKE 'UNITED %' 
		AND (CRMFacilityList.FACILITY_ADDRESS_3) NOT LIKE 'us%');

		UPDATE CRMFacilityList SET FACILITY_ADDRESS_3 = ''
		WHERE CRMFacilityList.FACILITY_ADDRESS_3 IS NULL;
	END
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_PopulateCRMFacilityList] TO [CRM_SERVICE]
    AS [dbo];
GO

GRANT EXECUTE ON [dbo].[sp_PopulateCRMFacilityList] TO DATATEAM_SVC
GO
