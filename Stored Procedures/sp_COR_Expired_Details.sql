-- drop proc sp_COR_Expired_Details
go
CREATE  PROCEDURE [dbo].[sp_COR_Expired_Details]
	  @web_userid VARCHAR(100),@profile_id INT
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	  --,@form_id INT
AS

--declare @web_userid VARCHAR(100)='customer.demo@usecology.com',@profile_id INT=343474




DECLARE  @Generator_id INT,@waste_water_flag CHAR(1),@exceed_ldr_standards CHAR(1),@meets_alt_soil_treatment_stds CHAR(1),@more_than_50_pct_debris CHAR(1),@contains_pcb CHAR(1),
@used_oil CHAR(1),@pharmaceutical_flag CHAR(1),@thermal_process_flag CHAR(1),@origin_refinery CHAR(1),@radioactive_waste CHAR(1),@reactive_other CHAR(1),@biohazard CHAR(1),
@container_type_cylinder CHAR(1),@compressed_gas CHAR(1)


DECLARE @LDR CHAR(1)='N',@VSQG_CESQG_CERTIFICATE CHAR(1)='N',@PCB CHAR(1)='N',@usedoil CHAR(1)='N',@pharmaceutical CHAR(1)='N',@DEBRIS CHAR(1)='N',
@Waste_Import CHAR(1)='N',@THERMAL CHAR(1)='N',@RADIOACTIVEFLAG CHAR(1)='N',@RADIOACTIVE CHAR(1)='N',@compressedgas CHAR(1)='N',@BENZEN CHAR(1)='N';
		Set @Generator_id = (SELECT p.generator_id From profile as p  JOIN Generator as g on   p.generator_id =  g.generator_id  where p.profile_id = @profile_id)

	---LDR 

SELECT @waste_water_flag = waste_water_flag , @exceed_ldr_standards=exceed_ldr_standards,@pharmaceutical_flag=pharmaceutical_flag,@thermal_process_flag=thermal_process_flag,@origin_refinery=origin_refinery,@container_type_cylinder=container_type_cylinder FROM Profile WHERE profile_id = @profile_id
SELECT @biohazard=biohazard,@reactive_other = reactive_other,@meets_alt_soil_treatment_stds=meets_alt_soil_treatment_stds,
@more_than_50_pct_debris=more_than_50_pct_debris,@used_oil=used_oil,@radioactive_waste=radioactive_waste,
@contains_pcb=contains_pcb,@compressed_gas=compressed_gas
 FROM ProfileLab WHERE profile_id = @profile_id

  IF @waste_water_flag = 'W' OR @waste_water_flag = 'N' OR @exceed_ldr_standards = 'T' OR @meets_alt_soil_treatment_stds = 'T' OR @more_than_50_pct_debris = 'T'
   BEGIN
    SET @LDR='Y'
   END

-- LDR END

-- CERTIFICATE
  DECLARE @Generator_Country  VARCHAR(3)
  DECLARE @generator_type_id INT


  SELECT @generator_type_id = generator_type_id ,@Generator_Country = generator_Country FROM Generator where generator_id = @Generator_id

  IF  @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'CESQG' ) OR @generator_type_id = (SELECT generator_type_id  FROM dbo.GeneratorType WHERE generator_type = 'VSQG')
   BEGIN 
    SET @VSQG_CESQG_CERTIFICATE='Y'
   END
-- CERTIFICATE END

-- PCB

  IF @contains_pcb = 'T'
    BEGIN
	 SET @PCB='Y'
	END
-- PCB END  

-- USED OIL 

 IF @used_oil = 'T'
   BEGIN
    SET @usedoil='Y'
   END
-- USED OIL END

--  pharmaceutical

 IF @pharmaceutical_flag = 'T'
	BEGIN
      SET @pharmaceutical='Y'
	END
-- pharmaceutical END

-- DEBRIS

IF @more_than_50_pct_debris = 'T'
 BEGIN 
  SET @DEBRIS='Y'
 END
-- DEBRIS END

-- Waste Import Supplement

IF ISNULL(@Generator_Country,'') != '' AND @Generator_Country NOT IN('USA','VIR','PRI')
  BEGIN
   SET @Waste_Import='Y'
  END

-- Waste Import Supplement END

-- THERMAL 

IF @thermal_process_flag = 'T'
BEGIN
  SET @THERMAL='Y'
END
-- THERMAL END

-- BENZEN

IF @origin_refinery = 'T'
 BEGIN
  SET @BENZEN='Y'
 END
-- BENZEN END

-- RADIOACTIVE

IF @radioactive_waste = 'T' OR @reactive_other = 'T' OR	@biohazard = 'T' OR @container_type_cylinder = 'T'
  BEGIN 
	SET @RADIOACTIVEFLAG='Y'
  END
-- RADIOACTIVE END

--Compressed Gas Cylinder 

IF @container_type_cylinder = 'T' OR @compressed_gas = 'T'
  BEGIN 
	SET @compressedgas='Y'
  END
-- Compressed Gas Cylinder  END
--DECLARE  @isAttach_LDR CHAR(1)
--	, @isAttach_ID CHAR(1)
--	, @isAttach_PMS CHAR(1)
--	, @isAttach_UL CHAR(1)
--	, @isAttach_WI CHAR(1)
--	, @isAttach_CN CHAR(1)
--	, @isAttach_TR CHAR(1)
--	, @isAttach_BZ CHAR(1);

	CREATE TABLE #results (
	  i_d INT IDENTITY(1,1)
	, profile_id INT
	, approval_desc VARCHAR(50)
	,generator_id INT, generator_name VARCHAR(75), epa_id VARCHAR(12),generator_type VARCHAR(20), 
customer_id INT, cust_name VARCHAR(75), curr_status_code CHAR(1)
, ap_expiration_date DATETIME,prices char(1),date_modified DATETIME,display_status VARCHAR(40), copy_source VARCHAR(10)
	--, SA CHAR(1)
	--, SB CHAR(1)
	--, SC CHAR(1)
	--, SD CHAR(1)
	--, SE CHAR(1)
	--, SF CHAR(1)
	--, SG CHAR(1)
	--, SH CHAR(1)
	--, LDR CHAR(1)
	--, ID CHAR(1)
	--, PMS CHAR(1)
	--, UL CHAR(1)
	--, WI CHAR(1)
	--, CN CHAR(1)
	--, TR CHAR(1)
	--, BZ CHAR(1)
)
--SELECT * INTO #SectionStatus FROM FormSectionStatus where form_id = @form_id AND isActive=1

--	SET @isAttach_LDR=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE section='LR')

--	SET @isAttach_ID=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE  section='ID')

--	SET @isAttach_PMS=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE  section='PB')

--	SET @isAttach_UL=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE  section='UL')

--	SET @isAttach_WI=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE section='WI')

--	SET @isAttach_CN=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE  section='CN')

--	SET @isAttach_TR=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE section='TR')

--	SET @isAttach_BZ=(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
--	FROM #SectionStatus WHERE  section='BZ')

	insert #results (profile_id, approval_desc,generator_id, generator_name, epa_id, generator_type, 
customer_id, cust_name, curr_status_code, ap_expiration_date,prices,date_modified, copy_source
--,SA,SB,SC,SD,SE,SF,SG,SH--,LDR,ID,PMS,UL,WI,CN,TR,BZ
)

	select 
	
		p.profile_id,
		p.approval_desc,
		p.generator_id,
		gn.generator_name,
		gn.epa_id,
		gt.generator_type,
		p.customer_id,
		cn.cust_name,
		p.curr_status_code,
		p.ap_expiration_date,
		b.prices,
		p.date_modified,
		null as copy_source
	--	,
	--	(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SA'),--sectionA
	--(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SB'),--sectionB
	--(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SC'),--sectionC
	--(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SD'),--sectionD
	--(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SE'),--sectionE
	--(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SF'),--sectionF
	--(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SG'),--sectionG
	--(SELECT IIF(COUNT(*) = 1,'Y', 'N')  
	--FROM #SectionStatus WHERE section_status = 'Y' AND section='SH')--,--sectionH
	from ContactCORProfileBucket b
	join CORcontact c on b.contact_id = c.contact_id
		and c.web_userid = @web_userid
	join [Profile] p
		on b.profile_id = p.profile_id
	join Customer cn on p.customer_id = cn.customer_id
	join Generator gn on p.generator_id = gn.generator_id
		left join generatortype gt on gn.generator_type_id = gt.generator_type_id
		WHERE c.web_userid = @web_userid and p.profile_id=@profile_id 
		--AND CONVERT(DATE, ap_expiration_date,103) < CONVERT(DATE, GETDATE(),103)
	 
	-- if(@isAttach_LDR ='Y')
	--UPDATE #results SET LDR=(SELECT section_status FROM  #SectionStatus WHERE section='LR')

	--if(@isAttach_ID ='Y')
	--UPDATE #results SET ID=(SELECT section_status FROM  #SectionStatus WHERE section='ID')

	--if(@isAttach_PMS ='Y')
	--UPDATE #results SET PMS=(SELECT section_status FROM  #SectionStatus WHERE section='PB')

	--if(@isAttach_UL ='Y')
	--UPDATE #results SET UL=(SELECT section_status FROM  #SectionStatus WHERE section='UL')

	--if(@isAttach_WI ='Y')
	--UPDATE #results SET WI=(SELECT section_status FROM  #SectionStatus WHERE section='WI')

	--if(@isAttach_CN ='Y')
	--UPDATE #results SET CN=(SELECT section_status FROM  #SectionStatus WHERE section='CN')

	--if(@isAttach_TR ='Y')
	--UPDATE #results SET TR=(SELECT section_status FROM  #SectionStatus WHERE section='TR')

	--if(@isAttach_BZ ='Y')
	--UPDATE #results SET BZ=(SELECT section_status FROM  #SectionStatus WHERE section='BZ')

	SELECT 
	profile_id,
		approval_desc,
		generator_id,
		generator_name,
		epa_id,
		generator_type,
		customer_id,
		cust_name,
		curr_status_code,
		ap_expiration_date,
		prices,
		date_modified,
		null as copy_source,
		@compressedgas AS IsCylinderAttached,@RADIOACTIVEFLAG AS IsRadioActiveAttached,@BENZEN AS IsBenzeneAttached,@THERMAL AS IsThermalAttached,@Waste_Import AS IsWasteImportAttached
,@DEBRIS AS IsDebrisAttached,@pharmaceutical  AS IsPharmaAttached ,@usedoil AS IsUsedOilAttached,@PCB AS IsPCBAttached,@VSQG_CESQG_CERTIFICATE AS IsCertificationAttached,@LDR AS IsLDRAttached
--	,ISNULL(LDR,'N') LDR,  @isAttach_LDR isAttachLDR,ISNULL(ID,'N') ID, @isAttach_ID isAttachID,ISNULL(PMS,'N') PMS,@isAttach_PMS isAttachPMS,ISNULL(UL,'N') UL,@isAttach_UL isAttachUL
--,ISNULL(WI,'N') WI,@isAttach_WI isAttachWI,ISNULL(CN,'N') CN,@isAttach_CN isAttachCN,ISNULL(TR,'N') TR,@isAttach_TR isAttachTR,
--@isAttach_BZ isAttachBZ 

FROM  #results ORDER BY i_d


DROP TABLE #results
-- ;with cte as
--(
--select fs.display_status as display_status,b.display_status as display_status_count,case when b.display_status is null then 0 end as nullcount
-- from FormDisplayStatus  fs Left outer join #TMP b ON (fs.display_status = b.display_status)
-- )
-- select display_status,count(display_status) as display_status_count INTO #tmpStatus from cte where nullcount is null
-- group by display_status
-- union
-- select display_status,nullcount from cte where nullcount=0 
--		SELECT (SELECT
--    (SELECT  *  FROM #TMP  FOR XML PATH(''), TYPE) AS 'approveList',
--    (select display_status , display_status_count  from #tmpStatus   FOR XML PATH(''), TYPE) AS 'displayStatus'
--FOR XML PATH(''), ROOT('ProfileApporvedList')) as Result

 --drop table #TMP
 --drop table #tmpStatus
--RETURN 0

--select  top 1 form_id_wcr, * from profile where form_id_wcr is not null

--select profile_id, * from formwcr where form_id=427681

--select * from formsectionstatus

GO

GRANT EXECUTE ON [dbo].[sp_COR_Expired_Details] TO COR_USER;

GO
