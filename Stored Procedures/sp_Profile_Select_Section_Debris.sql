CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_Debris](
	
		 @profileId INT
				

)
AS


/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_Debris]

	Description	: 
                  Procedure to get Section Debris profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_Debris] 893442

*************************************************************************************/
BEGIN
SELECT
        
		  --ISNULL( WCR.signing_name,'') AS signing_name,
		  --ISNULL( WCR.signing_title,'') AS signing_title,
		  --ISNULL( WCR.signing_date,'') AS signing_date,
		  --ISNULL( WCR.signing_date,'') AS signing_date,
		  --ISNULL( Debris.form_id,'') AS form_id,
		  --ISNULL( Debris.revision_id,'') AS revision_id,
		  --ISNULL( Debris.wcr_id,'') AS wcr_id,
		  --ISNULL( Debris.wcr_rev_id,'') AS wcr_rev_id,
		  --ISNULL( Debris.locked,'') AS locked,
		  ISNULL( Debris.debris_certification_flag,'') AS debris_certification_flag,
		  ISNULL(GETDATE(),'') AS signing_date
		  --ISNULL( Debris.created_by,'') AS created_by,
		  --ISNULL( Debris.date_created,'') AS date_created,
		  --ISNULL( Debris.modified_by,'') AS modified_by,
		  --ISNULL( Debris.date_modified,'') AS date_modified
		  
		   
		FROM  Profile AS Debris 
	 --JOIN  FormWCR AS WCR ON Debris.form_id =WCR.form_id

	WHERE 

		profile_Id = @profileId 
		

	FOR XML RAW ('Debris'), ROOT ('ProfileModel'), ELEMENTS
END
		
	  GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_Debris] TO COR_USER;

GO


