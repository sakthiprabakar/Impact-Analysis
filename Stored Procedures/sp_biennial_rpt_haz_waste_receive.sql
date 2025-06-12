

create procedure sp_biennial_rpt_haz_waste_receive
@biennial_id int,
@report_mode varchar(10) = 'volume' -- volume or waste_code

/*
	05-16-2011 - RJG - Created.  This report is a friendly version of the generator data shown in the biennial data (haz waste volumes, units by generator)
	
	Example:
	exec sp_bienneial_rpt_haz_waste_receive 15, 'volume'
	exec sp_bienneial_rpt_haz_waste_receive 15, 'waste_code'
*/

AS

if object_id('tempdb..#tmp') is not null drop table #tmp
if object_id('tempdb..#tmp_2') is not null drop table #tmp_2

--declare @biennial_id int = 254


SELECT 
--biennial_id,
--data.generator_name,
--data.generator_state,
--data.generator_epa_id,
--'state_epa_id???' as generator_state_epa_id,
--data.approval_code,
--data.management_code,
--data.waste_consistency,
--COALESCE(lbs_haz_actual, lbs_haz_estimated, 0) as lbs_haz,
--COALESCE(gal_haz_actual, gal_haz_estimated, 0) as gal_haz,
--COALESCE(yard_haz_actual, yard_haz_estimated, 0) as yard_haz,
cast(0.00 as float) as volume_total,
	--/*
	--if only actual yards is present and not actual gals use actual yards
	--IF only actual gals is present  and not actual yards use actual gals
	--If both are present - If consistency contains "Liquid' use gals else use yards
	--*/
	--RIGHT(space(10) + ISNULL(convert(varchar(10),  
	--	(
	--		SELECT 
	--		ISNULL(SUM(CASE WHEN ISNULL(data.yard_haz_actual,0) <> 0 and ISNULL(data.gal_haz_actual,0) = 0 then data.yard_haz_actual
	--			when ISNULL(data.gal_haz_actual,0) <> 0 and ISNULL(data.yard_haz_actual,0) = 0 then data.gal_haz_actual
	--			when ISNULL(data.gal_haz_actual,0) <> 0 and ISNULL(data.yard_haz_actual,0) = 0 and data.waste_consistency LIKE '%LIQUID%' THEN data.gal_haz_actual
	--			else data.yard_haz_actual
	--		END),0)
	--		FROM EQ_Extract..BiennialReportSourceData tmp_sd
	--		WHERE tmp_sd.approval_code = data.approval_code
	--		AND tmp_sd.management_code = data.management_code
	--		AND tmp_sd.biennial_id = data.biennial_id
	--		GROUP BY tmp_sd.biennial_id, tmp_sd.approval_code, tmp_sd.management_code,
	--		data.biennial_id, data.approval_code, data.management_code
	--	)
	--),''), 10) as volume,
	CASE 
		WHEN ISNULL(data.yard_haz_actual,0) <> 0 and ISNULL(data.gal_haz_actual,0) = 0 then 'YARD' -- 2 = yards
		when ISNULL(data.gal_haz_actual,0) <> 0 and ISNULL(data.yard_haz_actual,0) = 0 then 'GAL' -- 1 = gallons
		when ISNULL(data.gal_haz_actual,0) <> 0 and ISNULL(data.yard_haz_actual,0) = 0 and data.waste_consistency LIKE '%LIQUID%' THEN 'GAL' -- 1 = gallons
		else 'YARD'
	end as volume_unit_of_measure
	,data.*
	
INTO #tmp	
--SUM(COALESCE(lbs_haz_actual, lbs_haz_estimated, 0)) as lbs_haz,
--SUM(COALESCE(gal_haz_actual, gal_haz_estimated, 0)) as gal_haz,
--SUM(COALESCE(yard_haz_actual, yard_haz_estimated, 0)) as yard_haz
FROM EQ_Extract..BiennialReportSourceData data 
where 1=1
and biennial_id = @biennial_id
--and generator_epa_id = 'AZR000004192'

--SELECT * FROM #tmp

--SELECT * FROM BiennialReportSourceData where biennial_id = 251

--UPDATE #tmp SET UNIT_OF_MEASURE = 
--	CASE 
--		WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 then 'YARD' -- 2 = yards
--		when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 then 'GAL' -- 1 = gallons
--		when ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 and sd.waste_consistency LIKE '%LIQUID%' THEN 'GAL' -- 1 = gallons
--		else 'YARD'
--	end
--	FROM EQ_Extract..BiennialReportSourceData SD
--	WHERE 
--	SD.TRANS_MODE = 'I'
--	AND sd.approval_code = #tmp.approval_code
--	and SD.generator_epa_id = #tmp..generator_epa_id
--	and #tmp.biennial_id = @biennial_id
	




/*
	if only actual yards is present and not actual gals use actual yards
	IF only actual gals is present  and not actual yards use actual gals
	If both are present - If consistency contains "Liquid' use gals else use yards
	*/
SELECT 
biennial_id,
UPPER(data.generator_name) as generator_name,
data.generator_state,
data.generator_epa_id,
data.approval_code,
data.management_code,
--data.waste_consistency,
data.EPA_form_code,
data.EPA_source_code,
--ISNULL(data.waste_consistency,'') as waste_consistency,
--SUM(COALESCE(lbs_haz_actual, lbs_haz_estimated, 0)) as lbs_haz,
--SUM(COALESCE(gal_haz_actual, gal_haz_estimated, 0)) as gal_haz,
--SUM(COALESCE(yard_haz_actual, yard_haz_estimated, 0)) as yard_haz,	
--SUM(data.yard_haz_estimated),
		CONVERT(float,(SELECT 
			ISNULL(
				SUM(
					CASE WHEN ISNULL(data.yard_haz_actual,0) <> 0 and ISNULL(data.gal_haz_actual,0) = 0 then data.yard_haz_actual
					when ISNULL(data.gal_haz_actual,0) <> 0 and ISNULL(data.yard_haz_actual,0) = 0 then data.gal_haz_actual
					when ISNULL(data.gal_haz_actual,0) <> 0 and ISNULL(data.yard_haz_actual,0) = 0 and data.waste_consistency LIKE '%LIQUID%' THEN data.gal_haz_actual
					else data.yard_haz_actual
				END
			),0)
			FROM EQ_Extract..BiennialReportSourceData tmp_sd
			WHERE tmp_sd.approval_code = data.approval_code
			AND tmp_sd.management_code = data.management_code
			AND tmp_sd.biennial_id = data.biennial_id
			GROUP BY tmp_sd.biennial_id, tmp_sd.approval_code, tmp_sd.management_code,
			data.biennial_id, data.approval_code, data.management_code)
		) as volume,
volume_unit_of_measure	
INTO #tmp_2
FROM #tmp data
GROUP BY biennial_id,
data.generator_name,
data.generator_state,
data.generator_epa_id,
data.approval_code,
data.management_code,
ISNULL(data.waste_consistency,''),
volume_unit_of_measure,
data.EPA_form_code,
data.EPA_source_code

if (@report_mode = 'volume')
begin	
SELECT
	biennial_id,
	UPPER(data.generator_name) as generator_name,
	data.generator_state,
	data.generator_epa_id,
	data.approval_code,
	data.management_code,
	data.EPA_form_code,
	data.EPA_source_code,
	volume_unit_of_measure,
	SUM(volume) as volume
FROM #tmp_2 data
group by
	biennial_id,
	UPPER(data.generator_name),
	data.generator_state,
	data.generator_epa_id,
	data.approval_code,
	data.management_code,
	volume_unit_of_measure,
	data.EPA_form_code,
	data.EPA_source_code,
	volume_unit_of_measure
end





if @report_mode = 'waste_code'
begin
	SELECT * FROM 
	(

		SELECT distinct data.approval_code, src.waste_code FROM EQ_Extract..BiennialReportSourceWasteCode	src
			join #tmp data ON src.receipt_id = data.receipt_id
				and src.company_id = data.Company_id
				AND src.line_id = data.line_id
				and src.sequence_id = data.sequence_id
				and src.container_id = data.container_id
			where src.biennial_id = @biennial_id

		UNION

		SELECT distinct data.approval_code, src.waste_code FROM EQ_Extract..BiennialReportSourceWasteCode	src
			join #tmp data ON src.enviroware_manifest_document = data.enviroware_manifest_document
			and src.enviroware_manifest_document_line = data.enviroware_manifest_document_line
		where src.biennial_id = @biennial_id	

	) tbl
	order by approval_code
end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_rpt_haz_waste_receive] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_rpt_haz_waste_receive] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_rpt_haz_waste_receive] TO [EQAI]
    AS [dbo];

