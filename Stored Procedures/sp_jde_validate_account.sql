
--CREATE PROCEDURE sp_jde_validate_account (
--	@account_number varchar(29),
--	@exists_in_jde int output,
--	@is_postable int output
--)
--AS
--/***************************************************************
--Loads to:	Plt_AI

--Validates if a given JDE GL Account exists, and is postable.

--03/14/2013 RB	Created

--****************************************************************/
--declare @posting_edit char(1),
--	@business_unit varchar(12),
--	@object_account varchar(5),
--	@subsidiary varchar(5),
--	@i int,
--	@j int

---- default to not exists, not postable
--set @exists_in_jde = 0
--set @is_postable = 0

---- if there is a subsidiary as part of the account, strip it off
--set @i = charindex('-',@account_number,1)
--set @j = charindex('-',@account_number,@i+1)

--if @j > 0
--begin
--	set @subsidiary = substring(@account_number,@j+1,datalength(@account_number)-@j)
--	set @account_number = substring(@account_number,1,@j-1)
--end

---- extract business unit and object account
--if @i > 0
--begin
--	set @business_unit = substring(@account_number,1,@i-1)
--	set @object_account = substring(@account_number,@i+1,datalength(@account_number)-@i)
--end
--else
--begin
--	set @business_unit = LEFT(@account_number,datalength(@account_number)-5)
--	set @object_account = RIGHT(@account_number,5)
--end
--set @business_unit = replicate(' ',12 - datalength(@business_unit)) + @business_unit

---- look for account
--if exists (select 1 from JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
--		where business_unit_GMMCU = isnull(@business_unit,'')
--		and object_account_GMOBJ = isnull(@object_account,'')
--		and subsidiary_GMSUB = isnull(@subsidiary,''))
--begin
--	set @exists_in_jde = 1

--	select @posting_edit = ltrim(rtrim(posting_edit_GMPEC))
--	from JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
--	where business_unit_GMMCU = isnull(@business_unit,'')
--	and object_account_GMOBJ = isnull(@object_account,'')
--	and subsidiary_GMSUB = isnull(@subsidiary,'')

	
--	if isnull(@posting_edit,'N') in ('','L')
--		set @is_postable = 1
--end

--return 0

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jde_validate_account] TO [EQAI_LINKED_SERVER]
--    AS [dbo];


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jde_validate_account] TO [EQAI]
--    AS [dbo];

