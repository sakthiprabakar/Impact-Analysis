


/* ******************************************************************
  Updated By       : Meenachi
  Updated On date  : 11th Feb 2019
  Decription       : Details for SectionC ContainerSize AutoComplete Lookup
  Type             : Stored Procedure
  Object Name      : [spSectionCLookup_ContainerSize]


  Select SectionC ContainerSize AutoComplete Lookup columns Values  (Part of form wcr AutoComplete box)
 

  Inputs 
	searchText
 
  Samples:
	 EXEC [dbo].[spSectionCLookup_ContainerSize] 'B1'

****************************************************************** */
create PROCEDURE [dbo].[spSectionCLookup_ContainerSize]

@searchText varchar(200)=''
AS
BEGIN
IF(@searchText!='')
BEGIN

	-- RQ -UN/NA #
	

		   SELECT bill_unit_code, bill_unit_desc FROM BillUnit WHERE container_flag = 'T' AND disposal_flag = 'T'
		   AND (bill_unit_code LIKE '%'+@searchText+'%' OR bill_unit_desc LIKE '%'+@searchText+'%')
	
	 
END
END