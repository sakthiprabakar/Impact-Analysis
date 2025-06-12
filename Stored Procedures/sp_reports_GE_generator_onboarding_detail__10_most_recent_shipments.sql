
create proc sp_reports_GE_generator_onboarding_detail__10_most_recent_shipments (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_detail__10_most_recent_shipments

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_GE_generator_onboarding_detail__10_most_recent_shipments 168770
**************************************************************************** */

	--Waste Volumes
	-- drop table #waste	
	create table #waste(
		Shipment_Date		datetime
		, Manifest_Number	varchar(20)
		, Line				int
		, Profile			int
		, ProductDesc		varchar(100)
		, Haz_Non_Haz		varchar(20)
		, Quantity			float
		, Unit				varchar(20)
		, Number_of_Containers	int
		, Container_Type	varchar(20)
		, TSDF				varchar(100)
		, City				varchar(40)
		, State				varchar(20)
	)

	-- inserts
	insert #waste
	select '8/17/2017', '006150429SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 4.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/15/2017', '006115319SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 2175.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/15/2017', '006115320SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 1450.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/15/2017', '006115336SKS', 1, 742014, 'Dober and Water', 'Non-Haz', 275.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/10/2017', '006054179SKS', 1, 150135, 'AQUEOUS SOLUTION PARTS WASHER  NHZW', 'Non-Haz', 75.00, 'G   ', 3, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006057190SKS', 1, 150135, 'AQUEOUS SOLUTION PARTS WASHER  NHZW', 'Non-Haz', 15.00, 'G   ', 1, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150343SKS', 1, 1434600, 'Mod Sand', 'Non-Haz', 3900.00, 'P   ', 13, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150343SKS', 2, 1394036, 'Insulation', 'Non-Haz', 100.00, 'P   ', 2, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150343SKS', 3, 1435849, 'Mod. Debris', 'Non-Haz', 275.00, 'P   ', 1, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150344SKS', 1, 40580113, 'Absorbent with oil', 'Non-Haz', 225.00, 'P   ', 3, 'DM', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/10/2017', '006150344SKS', 2, 1033431, 'Empty Poly Drum (Last Containing Sanitrete)', 'Non-Haz', 4.00, 'P   ', 4, 'DF', 'La Porte, TX Facility', 'La Porte', 'TX' union all 
	select '8/8/2017', '006114692SKS', 1, 742009, 'Air Compressor Condensate Water and oil', 'Non-Haz', 500.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/8/2017', '006114692SKS', 2, 742014, 'Dober and Water', 'Non-Haz', 250.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' union all 
	select '8/8/2017', '006115318SKS', 1, 1376507, 'Water From Mod. Units Vac.', 'Non-Haz', 1650.00, 'G   ', 1, 'TT', 'Phillip Services Corp - Dallas', 'Dallas', 'TX' ; 
	
	select * from #waste ORDER BY shipment_date desc
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__10_most_recent_shipments] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__10_most_recent_shipments] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__10_most_recent_shipments] TO [EQAI]
    AS [dbo];

