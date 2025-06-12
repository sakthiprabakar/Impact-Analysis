
--create procedure sp_jdesync_ube_check_for_error
--	@user varchar(10),
--	@tickler_date int,
--	@tickler_time int,
--	@job_number int
--as

--declare @count int,
--		@error_msg varchar(max)

--select @count = COUNT(*)
--from JDEPPATMessageControlFile_F01131 f (nolock)
--join JDEMMultiLevelMessage_F01131M fm (nolock)
--	on f.serial_number_ZZSERK = fm.parent_serial_number_ZMPSRK
--	and fm.template_ID_ZMTMPI <> '01DAW'	--This is a Warning for duplicate Address record
--where f.template_ID_ZZTMPI = 'LM0022'			--Workflow message that identifies a batch in error
--and f.user_ID_ZZUSER = @user
--and f.tickler_date_ZZDTI = @tickler_date		--This would be field ACTDATE in F986110
--and f.time_last_updated_ZZUPMT = @tickler_time	--This would be field TMLAAT in F986110

--if @count > 0
--	set @error_msg = 'UBE Job #' + isnull(CONVERT(varchar(10),@job_number),'?') + ' produced errors in JDE.'

--select ISNULL(@error_msg,'') as error_msg

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jdesync_ube_check_for_error] TO [EQAI_LINKED_SERVER]
--    AS [dbo];

