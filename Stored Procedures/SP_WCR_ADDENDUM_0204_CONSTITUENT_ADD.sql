/***************************************************************************************
sp_WCR_ADDENDUM_0204_constituent_add
Updates the Constituent info in a WCR Addendum

Input:
	The WWS_ID to update
	The Constituent Name to updated
	The Constituent Flag
	The Constituent Concentration
	Logon of the calling process (customer id, eqai login name, etc)

Used on:
	bis_phthalate
	carbazole
	o_cresol
	p_cresol
	n_decane
	fluoranthene
	n_octadecane
	246_trichlorophenol
	phosphorus
	total_chlor_phen
	pcb
	acidity
	fog
	tss
	bod
	antimony
	arsenic
	cadmium
	chromium
	cobalt
	copper
	cyanide
	iron
	lead
	mercury
	nickel
	silver
	tin
	titanium
	vanadium
	zinc

Returns:
	Nothing

What it does:
	Updates the values of the WCR Record identified by wcr_id, rev, and customer_id.

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE SP_WCR_ADDENDUM_0204_CONSTITUENT_ADD (
	@wws_id int,
	@constituent_name varchar(100),
	@constituent_flag char(1),
	@constituent_concentration float,
	@logon char(10))
AS
	set nocount on
	declare @strSQL varchar(1000)

	set @strSQL = 'update wcr_addendum set wws_' + @constituent_name + '_flag = '''
		+ @constituent_flag + ''', wws_' + @constituent_name + '_actual = '
		+ isnull(convert(varchar(20), @constituent_concentration), 'NULL') + ', date_modified = getdate(), modified_by = '''
		+ @logon + ''''
		+ ' where'
		+ ' wws_id = ' + convert(varchar(20), @wws_id )
	exec(@strSQL)
	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_CONSTITUENT_ADD] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_CONSTITUENT_ADD] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_WCR_ADDENDUM_0204_CONSTITUENT_ADD] TO [EQAI]
    AS [dbo];

