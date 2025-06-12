USE PLT_AI
GO
DROP PROCEDURE IF EXISTS [sp_Validate_FormWCR]
GO
CREATE PROCEDURE [dbo].[sp_Validate_FormWCR]
	-- Add the parameters for the stored procedure here
	@form_id INTEGER,
	@revision_id INT,
	@edited_Section_Details Nvarchar(200),
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_FormWCR]


	procedure to validate edited sections. 
	
	i.e) Edited sections passed with comma seperated values. 
	Based on the sections the appropriate  section validation stored procedure will be excecuted 

inputs 
	
	@formid
	@revision_ID
	@edited_Section_Details


Samples:
 EXEC [sp_Validate_FormWCR] @form_id,@revision_ID, @edited_Section_Details
 EXEC [sp_Validate_FormWCR] 430235, 1, 'A,B,C,F'

****************************************************************** */


BEGIN
  	

--DECLARE	@form_id INTEGER,
--	    @revision_id INT,
--        @edited_Section_Details Nvarchar(200)
 
-- SET @edited_Section_Details = 'A,B,C,D,E,F,G,H,PB,0,0,0,0,0,0,0,0,0,0,0,0,0'

 

	    IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='A') = 'A'
		  BEGIN
		  print 'A'
		   EXEC sp_Validate_Section_A @form_id, @revision_id
		  END
         IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='B') = 'B'
		  BEGIN
		    PRINT 'B'
		   EXEC sp_Validate_Section_B @form_id, @revision_id
		  END
         IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='C') = 'C'
		  BEGIN
		   print('C')
		   EXEC sp_Validate_Section_C @form_id, @revision_id
		  END
		 IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='D') =  'D'
		  BEGIN
		     PRINT 'D'
		   EXEC sp_Validate_Section_D @form_id, @revision_id
		  END
		 IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='E') = 'E'
		  BEGIN
		      PRINT 'E'
		   EXEC sp_Validate_Section_E @form_id, @revision_id
		  END
		 IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='F') = 'F'
		   BEGIN
		     PRINT 'F'
		   EXEC sp_Validate_Section_F @form_id, @revision_id
		  END
		 IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='G') = 'G'
		  BEGIN
		     PRINT 'G'
		   EXEC sp_Validate_Section_G @form_id, @revision_id
		  END
		 IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='H') = 'H'
		  BEGIN
		     PRINT 'H'
		   EXEC sp_Validate_Section_H @form_id, @revision_id
		  END
          IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='PB') = 'PB'
		  BEGIN
		     PRINT 'PB'
		   EXEC sp_Validate_PCB @form_id , @revision_id,@web_userid
		  END
		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='LR') = 'LR'
		  BEGIN
		   PRINT 'LR VALIDATE'
		   EXEC sp_Validate_LDR @form_id ,@revision_id,@web_userid
		  END
		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='BZ') = 'BZ'
		  BEGIN
		    PRINT 'BZ'
		   EXEC sp_Validate_Benzene @form_id,@revision_id,@web_userid
		  END
		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='CN') = 'CN'
		  BEGIN
		    PRINT 'CN'
		   EXEC sp_Validate_Certificate @form_id,@revision_id,@web_userid
		  END
		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='PL') = 'PL'
		  BEGIN
		    PRINT 'PL'
		   EXEC sp_Validate_Pharmaceutical @form_id,@revision_id,@web_userid
		  END

		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='ID') = 'ID'
		  BEGIN
		   PRINT 'ID'
		   EXEC sp_Validate_IllinoisDisposal @form_id,@revision_id,@web_userid
		  END

		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='TL') = 'TL'
		  BEGIN
		   PRINT 'TL'
		   EXEC sp_Validate_Thermal @form_id,@revision_id,@web_userid
		  END

		  IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='UL') = 'UL'
		  BEGIN
		   PRINT 'UL'
		   EXEC sp_Validate_UsedOil @form_id,@revision_id,@web_userid
		  END

		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='WI') = 'WI'
		  BEGIN
		    PRINT 'WI'
		   EXEC sp_Validate_WasteImport @form_id,@revision_id,@web_userid
		  END
		  
		  IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='CR') = 'CR'
		  BEGIN
		    PRINT 'CR'
		   EXEC sp_Validate_Cylinder @form_id,@revision_id,@web_userid
		  END
		   
		  IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='DS') = 'DS'
		  BEGIN
		    PRINT 'DS'
		   EXEC sp_Validate_Debris @form_id,@revision_id,@web_userid
		  END
		     
          IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='DA') = 'DA'
		  BEGIN
		     PRINT 'DA'
		   EXEC sp_Validate_Section_Document @form_id,@revision_id
		  END

		  IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='RA') = 'RA'
		  BEGIN
		    PRINT 'RA'
		   EXEC sp_Validate_RadioActive @form_id,@revision_id,@web_userid
		  END
		  
		  IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='GL') = 'GL'
		  BEGIN
		    PRINT 'GL'
		   EXEC sp_Validate_GeneratorLocation @form_id,@revision_id
		  END
		   IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='SL') = 'SL'
		  BEGIN
		     PRINT 'SL'
		   EXEC sp_Validate_Section_L @form_id, @revision_id
		  END

		  IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='GK') = 'GK'
		  BEGIN		    
		   EXEC sp_Validate_GeneratorKnowledge_Form @form_id, @revision_id, @web_userid
		  END
	 
		  IF (SELECT [row] from dbo.fn_SplitXsvText(',',1,@edited_Section_Details) where [row]='FB') = 'FB'
		  BEGIN
		   EXEC sp_Validate_FormEcoflo @form_id, @revision_ID, @web_userid
		  END		  
	  EXEC sp_Validate_Status_Update @form_id,@revision_id
 
END

GO

	GRANT EXECUTE ON [dbo].[sp_Validate_FormWCR] TO COR_USER;

GO