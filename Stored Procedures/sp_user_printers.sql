ALTER PROCEDURE dbo.sp_user_printers
	  @user_code 		VARCHAR(8)
	, @connect_type		VARCHAR(10)
	, @printer_container_label	VARCHAR(200)
	, @printer_lab_label	VARCHAR(200)
	, @printer_manifest	VARCHAR(200)
	, @printer_nonhaz_manifest VARCHAR(200)
	, @printer_continuation	VARCHAR(200)
	, @printer_wo		VARCHAR(200)
	, @printer_wo_label	VARCHAR(200)
	, @printer_container_label_mini	VARCHAR(200)
	, @printer_haz_label	VARCHAR(200)
	, @printer_nonhaz_label	VARCHAR(200)
	, @printer_pdf	VARCHAR(200)
	, @printer_fax	VARCHAR(200)
    , @printer_nonrcra_label VARCHAR(200)
    , @printer_universal_label VARCHAR(200)
	, @printer_default	VARCHAR(200)
AS
/**************************************************************************
Filename:	L:\Apps\SQL\EQAI\Plt_AI\sp_user_printers.sql
PB Object(s):	d_sp_user_printers

04/03/2002 JDB	Created to update printers on the users table
03/18/2003 JDB	Modified to update plt_15_ai
11/25/2003 JDB	Modified to update company 17, 18, 21, 22, 23, 24
05/06/2004 JDB	Added continuation printer
11/22/2004 MK	Added pdf and fax printers and renamed "drum" to "container"
02/05/2005 JDB	Changed to use Users table on plt_ai.
10/09/2007 JDB	Modified to use new servers for Test and Dev.  Databases
		no longer have _TEST and _DEV in the names.
05/08/2008 rg   added two new printers: non rcra and unversal
06/03/2020 MPM  DevOps 16147 - Increased "printer" input parameters to VARCHAR(200).
02/17/2021 GDE  DevOps 18098 - Added nonhaz_manifest printer
03/17/2025 SAILAJA  Rally# US142011 - Added printer_default
--Updated by Blair Christensen for Titan 05/21/2025

sp_user_printers 'rik_g', '', '', '', '', '', '', '', '', '', '', '', '','',''
**************************************************************************/
BEGIN
	DECLARE @msg VARCHAR(100)
		  ,	@errorcount	INTEGER

	SET @msg = '';
	SET @errorcount = 0;

	UPDATE dbo.Users 
	   SET printer_container_label = @printer_container_label
	     , printer_lab_label = @printer_lab_label
		 , printer_manifest = @printer_manifest
		 , printer_continuation = @printer_continuation
		 , printer_wo = @printer_wo
		 , printer_wo_label = @printer_wo_label
		 , printer_container_label_mini = @printer_container_label_mini
		 , printer_haz_label = @printer_haz_label
		 , printer_nonhaz_label = @printer_nonhaz_label
		 , printer_pdf = @printer_pdf
		 , printer_fax = @printer_fax
		 , printer_nonrcra_label = @printer_nonrcra_label
		 , printer_universal_label = @printer_universal_label
		 , printer_nonhaz_manifest = @printer_nonhaz_manifest
		 , printer_default = @printer_default
	 WHERE user_code = @user_code;

	IF @@ERROR <> 0 
		BEGIN
			SET @msg = 'Error updating user in Users table'
			SET @errorcount = 1
		END

	SELECT @msg;
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_user_printers] TO [EQAI];
GO

