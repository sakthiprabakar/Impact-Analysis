/***************************************************************************************
sp_wcr_0204_update_section8
Updates the fields in section 8 of the WCR.

Input:
	The WCR_ID to update
	The REV to update
	The Customer ID associated with this WCR
	pcb_concentration
	pcb_source_concentration_gr_50
	processed_into_non_liquid
	processd_into_nonlqd_prior_pcb
	pcb_non_lqd_contaminated_media
	pcb_manufacturer
	pcb_article_decontaminated
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_0204_UPDATE_SECTION8 (
	@wcr_id int,
	@rev int,
	@customer_id int,
	@pcb_concentration varchar(10),
	@pcb_source_concentration_gr_50 char(1),
	@processed_into_non_liquid char(1),
	@processd_into_nonlqd_prior_pcb varchar(10),
	@pcb_non_lqd_contaminated_media char(1),
	@pcb_manufacturer char(1),
	@pcb_article_decontaminated char(1),
	@logon char(10))
AS
	set nocount off
	update wcr set
	date_modified = getdate(),
	modified_by = @logon,
	active = 'T',
	pcb_concentration = @pcb_concentration ,
	pcb_source_concentration_gr_50 = @pcb_source_concentration_gr_50 ,
	processed_into_non_liquid = @processed_into_non_liquid ,
	processd_into_nonlqd_prior_pcb = @processd_into_nonlqd_prior_pcb ,
	pcb_non_lqd_contaminated_media = @pcb_non_lqd_contaminated_media ,
	pcb_manufacturer = @pcb_manufacturer ,
	pcb_article_decontaminated = @pcb_article_decontaminated
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev = @rev

	update wcr set
	active = 'F'
	where ((@customer_id is not null and customer_id = @customer_id) or (@customer_id is null and customer_id is null and logon = @logon))
	and wcr_id = @wcr_id
	and rev <> @rev
	set nocount on
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION8] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION8] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_0204_UPDATE_SECTION8] TO [EQAI]
    AS [dbo];

