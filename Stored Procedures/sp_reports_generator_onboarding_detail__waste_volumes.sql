
create proc sp_reports_generator_onboarding_detail__waste_volumes (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_generator_onboarding_detail__waste_volumes

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_generator_onboarding_detail__waste_volumes 168770
**************************************************************************** */

	--Waste Volumes
	-- drop table #waste	
	create table #waste(
		description	varchar(100)
		, profile_id	int
		, total_qty	float
		, lbs_or_gal	char(1)
		, lbs_per_gal	float
	)

	-- inserts
	insert #waste
	select 
		p.approval_desc, wss.profile_id, sum(wss.pounds), 'P', 8 
	from WasteSummaryStats wss
	join profile p on wss.profile_id = p.profile_id
	WHERE wss.generator_id = 22313 -- @generator_id
	and wss.profile_id is not null
	group by p.approval_desc, wss.profile_id
	union all
	select
		t.waste_desc, wss.tsdf_approval_id, sum(wss.pounds), 'P', 8
	from WasteSummaryStats wss
	join tsdfapproval t on wss.tsdf_approval_id = t.tsdf_approval_id
	WHERE wss.generator_id = 22313 -- @generator_id
	and wss.tsdf_approval_id is not null and wss.profile_id is null
	group by t.waste_desc, wss.tsdf_approval_id
	
/*	
	SELECT 'Water From Mod. Units Vac.', 1376507, 32604, 'G', 8 union all
	SELECT 'Dober and Water', 742014, 13995, 'G', 8 union all
	SELECT 'Air Compressor Condensate Water and oil', 742009, 9445, 'G', 8 union all
	SELECT 'Used oil', 40580090, 6973, 'G', 8 union all
	SELECT 'Cyclo Cool, Aqua Quinch, Water', 722308, 6500, 'G', 8 union all
	SELECT 'Mod Sand', 1434600, 33875, 'P', 12 union all
	SELECT 'Thinner Rags', 40566699, 11595, 'P', 8 union all
	SELECT 'DRIED PAINT SOLIDS', 778285, 9825, 'P', 9 union all
	SELECT 'Paint Liquid Solid Mix', 698767, 7400, 'P', 9 union all
	SELECT 'Less Than 20% Diesel Mixed With Dober And Water', 1179694, 7000, 'P', 9 union all
	SELECT 'More Than 20% Diesel, Mixed With Dober And Water', 1180283, 5000, 'P', 9 union all
	SELECT 'Absorbent with oil', 40580113, 4645, 'P', 8 union all
	SELECT 'Mixed Oil and Water Based Paint In Cans', 1459904, 3650, 'P', 12 union all
	SELECT 'Mod. Debris', 1435849, 2125, 'P', 12 union all
	SELECT 'Used Oil Filters', 911476, 2000, 'P', 8 union all
	SELECT 'Mod. Pitt Debris Sludge', 1435430, 1925, 'P', 12 union all
	SELECT 'Metal Polish Water OHV', 1392803, 150, 'G', 8 union all
	SELECT 'Diesel Fuel Filter', 1419837, 1175, 'P', 12 union all
	SELECT 'Absorbent and Coolant', 1277548, 1050, 'P', 8 union all
	SELECT 'Metal Dust In Solvent Drum', 751790, 1000, 'P', 12 union all
	SELECT 'Absorbent From Diesel Fuel Cleanup', 1006160, 975, 'P', 9 union all
	SELECT 'Bondo Dust and Debris (Non Haz)', 1085363, 950, 'P', 12 union all
	SELECT 'EXCLUDED SOLVENT CONTAMINATED WIPES', 1057386, 705, 'P', 8 union all
	SELECT 'Sani-Treat', 1392784, 400, 'P', 8 union all
	SELECT 'Insulation', 1394036, 315, 'P', 6 union all
	SELECT 'BONDO SCRAP', 1075659, 300, 'P', 12 union all
	SELECT 'Sealed - Lead acid batteries - universal waste', 1459978, 225, 'P', 12 union all
	SELECT 'Expired RTV Sealant', 1410785, 200, 'P', 12 union all
	SELECT 'Mod. Wipes', 1435449, 160, 'P', 8 union all
	SELECT 'Sherlock Leak Detector', 783215, 150, 'P', 8 union all
	SELECT 'Mixed Loctite (Container In Container)', 1419724, 125, 'P', 9 union all
	SELECT 'Manus Bond 75-AM Industrial Grade (Container in Container)', 1419799, 120, 'P', 12 union all
	SELECT 'NICKEL CADMIUM . NICKEL METAL HYDRIDE BATTERIES', 865507, 105, 'P', 12 union all
	SELECT 'GREASE', 742016, 70, 'P', 9 union all
	SELECT 'ALKALINE BATTERIES', 865355, 68, 'P', 12 union all
	SELECT 'LEAD ACID BATTERIES', 865524, 65, 'P', 8 union all
	SELECT 'Diesel Fuel', 1179448, 60, 'P', 12 union all
	SELECT 'Pipe Shop- Coolant, Cutting Fluid', 1435884, 60, 'P', 8 union all
	SELECT 'Empty Metal Drum (Last Containing Oil)', 1033390, 56, 'P', 9 union all
	SELECT 'Mixed Aerosol Cans (Not Punctured)', 1419859, 50, 'P', 12 union all
	SELECT 'GE Blower Cab Air Filters', 1394007, 40, 'P', 6 union all
	SELECT 'HID / METAL HALIDE / CFL4 BULBS', 865545, 20, 'P', 12 union all
	SELECT 'Empty Poly Drum (Last Containing Sanitrete)', 1033431, 16, 'P', 8 union all
	SELECT 'EMPTY POLY DRUMS (Last Containing Corrosive Liquid)', 1258591, 14, 'P', 8 union all
	SELECT 'Activated Alumina (Desiccant)', 1159703, 10, 'P', 12 union all
	SELECT 'Empty Poly Drums (Last Containing Dober)', 1033355, 5, 'P', 8 union all
	SELECT 'Empty Metal Drum Last Containing Flammable Liquid', 1209951, 5, 'P', 12 union all
	SELECT 'Metal Test Wipes With Acid - OHV', 1394056, 5, 'P', 8 union all
	SELECT 'EMPTY POLY DRUM LAST CONTAINING (Gardoclean)', 1033438, 0, 'P', 8;
*/		
	
	select top 20 rank() over (order by total_qty * (case when lbs_or_gal = 'G' then lbs_per_gal else 1 end) desc) as _rank, total_qty * (case when lbs_or_gal = 'G' then lbs_per_gal else 1 end) as total_shipped_lbs, * from #waste order by total_qty * (case when lbs_or_gal = 'G' then lbs_per_gal else 1 end) desc

 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__waste_volumes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__waste_volumes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_generator_onboarding_detail__waste_volumes] TO [EQAI]
    AS [dbo];

