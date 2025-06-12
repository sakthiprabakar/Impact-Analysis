
/***************************************************************************************
sp_wcr_0204_update_section3
Updates the fields in section 3 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	color
	odor
	poc
	consistency
	ph_lte_2
	ph_gt_2_lt_5
	ph_gte_5_lte_10
	ph_gt_10_lt_12_5
	ph_gte_12_5
	ignitability
	waste_contains_spec_hand_none
	free_liquids
	oily_residue
	metal_fines
	biodegradable_sorbents
	amines
	ammonia
	dioxins
	furans
	biohazard
	shock_sensitive_waste
	reactive_waste
	radioactive_waste
	explosives
	pyrophoric_waste
	isocyanates
	asbestos_no_friable
	asbestos_friable
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION3 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@color varchar(25),
	@odor varchar(25),
	@poc char(1),
	@consistency_solid char(1),
	@consistency_dust char(1),
	@consistency_liquid char(1),
	@consistency_sludge char(1),
	@ph_lte_2 char(1),
	@ph_gt_2_lt_5 char(1),
	@ph_gte_5_lte_10 char(1),
	@ph_gt_10_lt_12_5 char(1),
	@ph_gte_12_5 char(1),
	@ignitability char(10),
	@waste_contains_spec_hand_none char(1),
	@free_liquids char(1),
	@oily_residue char(1),
	@metal_fines char(1),
	@biodegradable_sorbents char(1),
	@amines char(1),
	@ammonia char(1),
	@dioxins char(1),
	@furans char(1),
	@biohazard char(1),
	@shock_sensitive_waste char(1),
	@reactive_waste char(1),
	@radioactive_waste char(1),
	@explosives char(1),
	@pyrophoric_waste char(1),
	@isocyanates char(1),
	@asbestos_no_friable char(1),
	@asbestos_friable char(1),
	@logon char(10))
AS
	set nocount on
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	color = @color,
	odor = @odor,
	poc = @poc,
	consistency_solid = @consistency_solid,
	consistency_dust = @consistency_dust,
	consistency_liquid = @consistency_liquid,
	consistency_sludge = @consistency_sludge,
	ph_lte_2 = @ph_lte_2,
	ph_gt_2_lt_5 = @ph_gt_2_lt_5,
	ph_gte_5_lte_10 = @ph_gte_5_lte_10,
	ph_gt_10_lt_12_5 = @ph_gt_10_lt_12_5,
	ph_gte_12_5 = @ph_gte_12_5,
	ignitability = @ignitability,
	waste_contains_spec_hand_none = @waste_contains_spec_hand_none,
	free_liquids = @free_liquids,
	oily_residue = @oily_residue,
	metal_fines = @metal_fines,
	biodegradable_sorbents = @biodegradable_sorbents,
	amines = @amines,
	ammonia = @ammonia,
	dioxins = @dioxins,
	furans = @furans,
	biohazard = @biohazard,
	shock_sensitive_waste = @shock_sensitive_waste,
	reactive_waste = @reactive_waste,
	radioactive_waste = @radioactive_waste,
	explosives = @explosives,
	pyrophoric_waste = @pyrophoric_waste,
	isocyanates = @isocyanates,
	asbestos_no_friable = @asbestos_no_friable,
	asbestos_friable = @asbestos_friable
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev <> @rev
	set nocount off

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION3] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION3] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION3] TO [EQAI]
    AS [dbo];

