USE [PLT_AI]
GO
/***************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_GeneratorLocation_insert_update]
GO
CREATE PROCEDURE [dbo].[sp_GeneratorLocation_insert_update]
       @Data XML,		
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS     
/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 26th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_GeneratorLocation_insert_update]
	
	Updated By   : Ranjini C
    Updated On   : 08-AUGUST-2024
    Ticket       : 93217
    Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 


	Procedure to insert update generator location 

inputs 
	
	@Data
	@form_id
	@revision_id


Samples:
 EXEC [sp_GeneratorLocation_insert_update] @Data,@formId,@revisionId
 EXEC [sp_GeneratorLocation_insert_update]  '<SectionA>

<IsEdited>A</IsEdited>
<generator_id>34</generator_id>
<generator_name>Sathik Ali</generator_name>
<generator_address1>3701 gjh</generator_address1>
<generator_address2>3701 WEST</generator_address2>
<generator_address3>3701 WEST MORRI</generator_address3>
<generator_address4>3701 WEST MORRIS NEW STREET</generator_address4>
<generator_city>INDIANAPOLIS</generator_city>
<generator_country></generator_country>
<generator_state>IN</generator_state>
<generator_zip>46241</generator_zip>
<gen_mail_address1>MORRIS STREET</gen_mail_address1>
<gen_mail_address2>STREET</gen_mail_address2>
<gen_mail_address3>3701 WEST MORRIS STREET</gen_mail_address3>
<gen_mail_address4></gen_mail_address4>
<gen_mail_name>WEST</gen_mail_name>
<gen_mail_city>INDIANAPOLIS</gen_mail_city>
<gen_mail_state>IN</gen_mail_state>
<gen_mail_zip>46241</gen_mail_zip>
<gen_mail_country>BHS</gen_mail_country>
<tech_contact_id>1</tech_contact_id>
<tech_contact_name>A</tech_contact_name>
<tech_contact_phone>A</tech_contact_phone>
<tech_cont_email>A</tech_cont_email>
<generator_type_ID>1 </generator_type_ID>
<EPA_ID>INR000125120</EPA_ID>
<NAICS_code>1</NAICS_code>
<customer_id>1 </customer_id>
<state_id>A</state_id>
<po_required>A</po_required>
<inv_contact_name>A</inv_contact_name>
<inv_contact_id></inv_contact_id>
<inv_contact_phone>A</inv_contact_phone>
<inv_contact_email>A</inv_contact_email>
<cust_name>EQ INDUSTRIAL SERVICES INC INDIANAPOLIS</cust_name>
<cust_addr1>2650 N SHADELAND</cust_addr1>
<cust_addr2>2650 N SHADELAND</cust_addr2>
<cust_addr3>2650 N SHADELAND</cust_addr3>
<cust_addr4></cust_addr4>
<cust_city></cust_city>
<cust_state>IN</cust_state>
<cust_zip></cust_zip>
<cust_country>BHS</cust_country>
</SectionA>',427709,1 
***********************************************************************/ 
    BEGIN
	IF NOT EXISTS(SELECT form_id FROM FormAddGeneratorLocation WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
	BEGIN
	DECLARE @sequenceNext INT
	EXEC @sequenceNext = sp_sequence_next 'form.form_id'	
	  INSERT INTO FormAddGeneratorLocation(  
	               form_id ,
				   revision_id,
				   wcr_id,
				   wcr_rev_id,
				   locked ,
				   generator_id ,
				   generator_name ,
				   generator_address1,
			   	   generator_address2 ,
				   generator_address3 ,
				   generator_address4 ,	  
				   generator_city ,	
				   generator_phone ,
				   generator_state ,
				   generator_zip ,
				   generator_country ,
				   gen_mail_address1 ,
				   gen_mail_address2 ,
			       gen_mail_address3 ,
				   gen_mail_address4,
				   gen_mail_city ,
				   gen_mail_state,
				   gen_mail_zip,
				   gen_mail_country,
				   tech_contact_id,
				   tech_contact_name,
				   tech_contact_phone,
				   tech_cont_email,
				   generator_type_ID,
				   EPA_ID ,
				   NAICS_code ,
				   state_id ,
				   po_required,
				   purchase_order,
				   customer_id,
				   cust_name ,
				   cust_addr1 ,
				   cust_addr2,
				   cust_addr3 ,
				   cust_addr4,
				   cust_city ,
				   cust_state,
				   cust_zip,
				   cust_country,
				   inv_contact_id ,
				   inv_contact_name,
				   inv_contact_phone,
				   inv_contact_email,
				   cert_physical_matches_profile ,
				   certification_flag,
				   --tclp_total =p.v.value('tclp_total[1]','CHAR(1)'),				  
				   date_created ,
				   date_modified ,
				   created_by ,
				   modified_by )
			  SELECT	
			  	   form_id = @sequenceNext,
				   revision_id = 1,
				   wcr_id=@form_id,
				   wcr_rev_id=@revision_id,
				   locked = 'U',
				   generator_id = p.v.value('generator_id[1]','int'),
				   generator_name = p.v.value('generator_name[1]','varchar(40)'),
				   generator_address1 = p.v.value('generator_address1[1]','varchar(40)'),
			   	   generator_address2 = p.v.value('generator_address2[1]','varchar(40)'),
				   generator_address3 = p.v.value('generator_address3[1]','varchar(40)'),
				   generator_address4 = p.v.value('generator_address4[1]','varchar(40)'),	  
				   generator_city = p.v.value('generator_city[1]','varchar(40)'),	
				   generator_phone = p.v.value('generator_phone[1]','varchar(10)'),
				   generator_state = p.v.value('generator_state[1]','CHAR(2)'),
				   generator_zip  = p.v.value('generator_zip[1]','varchar(10)'),
				   generator_country = p.v.value('generator_country[1]','VARCHAR(3)'),
				   gen_mail_address1 = p.v.value('gen_mail_address1[1]','varchar(40)'),
				   gen_mail_address2 = p.v.value('gen_mail_address2[1]','varchar(40)'),
			       gen_mail_address3 = p.v.value('gen_mail_address3[1]','varchar(40)'),
				   gen_mail_address4= p.v.value('gen_mail_address4[1]','varchar(40)'),
				   gen_mail_city =  p.v.value('gen_mail_city[1]','varchar(40)'),
				   gen_mail_state=  p.v.value('gen_mail_state[1]','varchar(2)'),
				   gen_mail_zip=  p.v.value('gen_mail_zip[1]','varchar(10)'),
				   gen_mail_country=  p.v.value('gen_mail_country[1]','VARCHAR(3)'),
				   tech_contact_id=  p.v.value('tech_contact_id[1]','INT'),
				   tech_contact_name=  p.v.value('tech_contact_name[1]','VARCHAR(40)'),
				   tech_contact_phone=  p.v.value('tech_contact_phone[1]','VARCHAR(20)'),
				   tech_cont_email=  p.v.value('tech_cont_email[1]','VARCHAR(50)'),
				   generator_type_ID=  p.v.value('generator_type_ID[1]','INT'),
				   EPA_ID = p.v.value('EPA_ID[1]','varchar(12)'),
				   NAICS_code = p.v.value('NAICS_code[1]','int'),
				   state_id =  p.v.value('EPA_ID[1]','varchar(40)'),
				   po_required=  p.v.value('EPA_ID[1]','char(1)'),
				   purchase_order= p.v.value('EPA_ID[1]','varchar(20)'),
				   customer_id= p.v.value('EPA_ID[1]','INT'),
				   cust_name = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr1 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr2 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr3 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr4 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_city = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_state = p.v.value('EPA_ID[1]','VARCHAR(2)'),
				   cust_zip = p.v.value('EPA_ID[1]','VARCHAR(10)'),
				   cust_country = p.v.value('EPA_ID[1]','VARCHAR(3)'),
				   inv_contact_id = p.v.value('EPA_ID[1]','INT'),
				   inv_contact_name= p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   inv_contact_phone = p.v.value('EPA_ID[1]','VARCHAR(20)'),
				   inv_contact_email = p.v.value('EPA_ID[1]','VARCHAR(50)'),
				   cert_physical_matches_profile = p.v.value('EPA_ID[1]','CHAR(1)'),
				   certification_flag = p.v.value('EPA_ID[1]','CHAR(1)'),
				   --tclp_total =p.v.value('tclp_total[1]','CHAR(1)'),				  
				   date_created = GETDATE(),
				   date_modified = GETDATE(),
				   created_by = @web_userid,
				   modified_by = @web_userid
			  FROM
				  @Data.nodes('GeneratorLocation')p(v)
				  END
     ELSE
	  BEGIN
        UPDATE  FormAddGeneratorLocation 			 
        SET  
		          generator_id = p.v.value('generator_id[1]','int'),
				   generator_name = p.v.value('generator_name[1]','varchar(40)'),
				   generator_address1 = p.v.value('generator_address1[1]','varchar(40)'),
			   	   generator_address2 = p.v.value('generator_address2[1]','varchar(40)'),
				   generator_address3 = p.v.value('generator_address3[1]','varchar(40)'),
				   generator_address4 = p.v.value('generator_address4[1]','varchar(40)'),	  
				   generator_city = p.v.value('generator_city[1]','varchar(40)'),	
				   generator_phone = p.v.value('generator_phone[1]','varchar(10)'),
				   generator_state = p.v.value('generator_state[1]','CHAR(2)'),
				   generator_zip  = p.v.value('generator_zip[1]','varchar(10)'),
				   generator_country = p.v.value('generator_country[1]','VARCHAR(3)'),
				   gen_mail_address1 = p.v.value('gen_mail_address1[1]','varchar(40)'),
				   gen_mail_address2 = p.v.value('gen_mail_address2[1]','varchar(40)'),
			       gen_mail_address3 = p.v.value('gen_mail_address3[1]','varchar(40)'),
				   gen_mail_address4= p.v.value('gen_mail_address4[1]','varchar(40)'),
				   gen_mail_city =  p.v.value('gen_mail_city[1]','varchar(40)'),
				   gen_mail_state=  p.v.value('gen_mail_state[1]','varchar(2)'),
				   gen_mail_zip=  p.v.value('gen_mail_zip[1]','varchar(10)'),
				   gen_mail_country=  p.v.value('gen_mail_country[1]','VARCHAR(3)'),
				   tech_contact_id=  p.v.value('tech_contact_id[1]','INT'),
				   tech_contact_name=  p.v.value('tech_contact_name[1]','VARCHAR(40)'),
				   tech_contact_phone=  p.v.value('tech_contact_phone[1]','VARCHAR(20)'),
				   tech_cont_email=  p.v.value('tech_cont_email[1]','VARCHAR(50)'),
				   generator_type_ID=  p.v.value('generator_type_ID[1]','INT'),
				   EPA_ID = p.v.value('EPA_ID[1]','varchar(12)'),
				   NAICS_code = p.v.value('NAICS_code[1]','int'),
				   state_id =  p.v.value('EPA_ID[1]','varchar(40)'),
				   po_required=  p.v.value('EPA_ID[1]','char(1)'),
				   purchase_order= p.v.value('EPA_ID[1]','varchar(20)'),
				   customer_id= p.v.value('EPA_ID[1]','INT'),
				   cust_name = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr1 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr2 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr3 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_addr4 = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_city = p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   cust_state = p.v.value('EPA_ID[1]','VARCHAR(2)'),
				   cust_zip = p.v.value('EPA_ID[1]','VARCHAR(10)'),
				   cust_country = p.v.value('EPA_ID[1]','VARCHAR(3)'),
				   inv_contact_id = p.v.value('EPA_ID[1]','INT'),
				   inv_contact_name= p.v.value('EPA_ID[1]','VARCHAR(40)'),
				   inv_contact_phone = p.v.value('EPA_ID[1]','VARCHAR(20)'),
				   inv_contact_email = p.v.value('EPA_ID[1]','VARCHAR(50)'),
				   cert_physical_matches_profile = p.v.value('EPA_ID[1]','CHAR(1)'),
				   certification_flag = p.v.value('EPA_ID[1]','CHAR(1)'),
				   --tclp_total =p.v.value('tclp_total[1]','CHAR(1)'),				  
				   --date_created = GETDATE(),
				   date_modified = GETDATE(),
				  -- created_by = p.v.value('created_by[1]','varchar(60)'),
				   modified_by = @web_userid
        FROM
        @Data.nodes('GeneratorLocation')p(v) WHERE wcr_id = @form_id and wcr_rev_id=  @revision_id
		END		
       END
  GO
GRANT EXECUTE ON [dbo].[sp_GeneratorLocation_insert_update]  TO COR_USER;
GO
/************************************************************************************************************/