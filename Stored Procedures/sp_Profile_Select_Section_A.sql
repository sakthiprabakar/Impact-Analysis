
CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_A]
	@profileid int
AS

/* ******************************************************************

	Updated By		: Sathiyamoorthi
	Updated On		: 30th July 2020
	Type			: Stored Procedure
	Object Name		: [sp_Profile_Select_Section_A]


	Procedure to select Section A related fields 

inputs 
	
	@profileid
	


Samples:
 EXEC [sp_Profile_Select_Section_A] @profileid
 EXEC [sp_Profile_Select_Section_A] 501693

****************************************************************** */

BEGIN

	SELECT ISNULL(p.generator_id,'') AS generator_id, 
	ISNULL(g.generator_name,'') AS generator_name ,
	ISNULL(g.generator_address_1,'') as generator_address1,
    ISNULL(g.generator_address_2 , '') as generator_address2,
    ISNULL(g.generator_address_3,'') as generator_address3, 
	ISNULL(g.generator_address_4,'') as generator_address4,
    ISNULL(g.generator_city, '') as generator_city,
	ISNULL(g.generator_state, '') as generator_state ,
    ISNULL(g.generator_zip_code,'') as generator_zip ,
	ISNULL(g.generator_country,'') as generator_country ,
	ISNULL(g.generator_phone, '') as generator_phone,
	ISNULL(g.gen_mail_name,'') as gen_mail_name,
	ISNULL(g.gen_mail_addr1,'') as gen_mail_address1,
	ISNULL(g.gen_mail_addr2, '') as gen_mail_address2,
    ISNULL(g.gen_mail_addr3,'') as gen_mail_address3, 
    ISNULL(g.gen_mail_addr4,'') as gen_mail_address4, 
	ISNULL(g.gen_mail_city,'') as gen_mail_city ,
	ISNULL(g.gen_mail_state,'') as gen_mail_state ,
	ISNULL(g.gen_mail_zip_code,'') as gen_mail_zip ,
	ISNULL(g.gen_mail_country,'') as gen_mail_country ,
	--ISNULL(contact.contact_name,'') as tech_contact_name ,
	--ISNULL(contact.contact_phone,'') as tech_contact_phone ,
 --   ISNULL(contact.contact_email, '') as tech_cont_email,
	ISNULL(g.generator_type_id,'') as generator_type_ID,
	ISNULL(g.EPA_ID,'') as EPA_ID,	
	ISNULL(CAST(g.NAICS_code as nvarchar(100)),'') as NAICS_code, 
	ISNULL((SELECT CONCAT(naics.NAICS_code,' - ',naics.[description]) FROM NAICSCode naics where naics.NAICS_code=g.NAICS_code and g.NAICS_code > 0),'') as description ,
	 ISNULL(g.state_id,'') as state_id ,
	 ISNULL(p.po_required_from_form,'') as po_required,
     ISNULL(p.purchase_order_from_form,'') as purchase_order,
	 isnull(p.customer_id,'') as customer_id,
	--ISNULL(contact.contact_name,'') as inv_contact_name,
	--ISNULL(contact.contact_phone,'') as inv_contact_phone ,
	--ISNULL(contact.contact_email,'') as inv_contact_email,
	 ISNULL(cus.bill_to_cust_name,'') as cust_name,
	ISNULL(cus.bill_to_addr1,'') as cust_addr1 ,
	ISNULL(cus.bill_to_addr2,'') as cust_addr2, 
	ISNULL(cus.bill_to_addr3,'') as cust_addr3,
	ISNULL(cus.bill_to_addr4,'') as cust_addr4,
    ISNULL(cus.bill_to_city,'') as cust_city,
	ISNULL(cus.bill_to_state,'') as cust_state , 
	ISNULL(cus.bill_to_zip_code,'') as cust_zip ,
	--ISNULL(cus.bill_to_country,'') as bill_to_country 
	ISNULL(cus.bill_to_country,'') as cust_country ,
	ISNULL(tech_contact.contact_name,'') as tech_contact_name ,
	CASE LTRIM(tech_contact.contact_phone) when '' then tech_contact.contact_mobile  ELSE Isnull(tech_contact.Contact_phone,tech_contact.contact_mobile) END AS tech_contact_phone,
	--ISNULL(tech_contact.contact_phone,'') as tech_contact_phone , 
	ISNULL(tech_contact.contact_email, '') as tech_cont_email,
	ISNULL(invoice_contact.contact_name,'') as inv_contact_name,
	CASE LTRIM(invoice_contact.contact_phone) when '' then invoice_contact.contact_mobile  ELSE Isnull(invoice_contact.Contact_phone,invoice_contact.contact_mobile) END AS inv_contact_phone,
	ISNULL(invoice_contact.contact_phone,'') as inv_contact_phone ,	
	ISNULL(invoice_contact.contact_email,'') as inv_contact_email
	From profile as p
	JOIN Generator as g on   p.generator_id =  g.generator_id  
	--LEFT JOIN ProfileContact as contact ON p.profile_id =  contact.profile_id   
	OUTER APPLY(SELECT TOP 1 * FROM ProfileContact as contact WHERE p.profile_id =  contact.profile_id  AND contact.contact_type='Technical' )tech_contact
	OUTER APPLY(SELECT TOP 1 * FROM ProfileContact as contact WHERE p.profile_id =  contact.profile_id  AND contact.contact_type='Invoicing' )invoice_contact
    JOIN Customer AS cus on p.customer_id = cus.customer_ID 
	where p.profile_id = @profileid
  FOR XML RAW ('SectionA'), ROOT ('ProfileModel'), ELEMENTS

END

GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_A] TO COR_USER;

GO
