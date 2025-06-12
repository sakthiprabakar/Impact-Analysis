
CREATE PROCEDURE [dbo].[sp_COR_Request_AdminAccess] (

    @web_userid            varchar(100)

) as


/* *******************************************************************

  Author       : Prabhu
  Created date : 08-May-2019
  Decription   : This procedure is used to Eamil Template List

  inputs 
	
	web_userid 


Samples:

 exec sp_COR_Request_AdminAccess   @web_userid = 'nyswyn100'

******************************************************************* */

BEGIN

SET NOCOUNT ON;

DECLARE
     
	  @i_web_userid  varchar(100) = @web_userid

    , @i_contact_id    int

Declare @foo table (

        customer_id    int NOT NULL

    )

SET @i_contact_id = (select contact_id  from Contact where web_userid = @i_web_userid)
    
INSERT  @foo

SELECT  

        x.customer_id

FROM   ContactCORCustomerBucket x (nolock) 

JOIN Contact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid

WHERE

    x.contact_id = @i_contact_id


Declare  @customer_ids  varchar(max) ;

SELECT  
        @customer_ids = stuff((
        SELECT ','+convert(varchar(10),customer_id)
        FROM  @foo
        for xml path (''), type).value('.','nvarchar(max)')
      ,1,1,'')


    SELECT

         c.contact_id

        ,c.name

        ,c.contact_type

        ,c.Phone

        ,c.title

        ,c.contact_company

        ,c.contact_addr1
		
		,c.contact_city
		
		,c.contact_state
		
		,c.contact_zip_code

        ,c.email

		,c.contact_country

        ,@customer_ids as customer_id

     FROM  Contact c

  WHERE contact_id=@i_contact_id

    ORDER BY c.name


RETURN  0

END

GO

GRANT EXEC ON [dbo].[sp_COR_Request_AdminAccess] TO COR_USER;

GO

















