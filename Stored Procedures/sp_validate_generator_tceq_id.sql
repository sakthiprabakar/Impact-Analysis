Create PROCEDURE [dbo].sp_validate_generator_tceq_id 
	@tceq_id			varchar(5)
,	@return_code	    int	    OUTPUT
,   @return_msg         varchar(MAX) OUTPUT

AS
/* 

NAME:    sp_validate_generator_tceq_id
PURPOSE: Validate in state (Texas) generator TCEQ_ID

REVISIONS:
Ver Date       Author          Description
--- ---------- --------------- ------------------------------------
 1  11/7/2018  JAG             A transact sql version of the DP_VALIDATE_GENERATOR_TCEQ_ID 
                               Oracle procedure written by Allen Campbell.
							   
*/
Declare

   @c_numeric varchar(10)    = '0123456789',
   @c_xxx_suffix varchar(47) = '01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16'
   
     
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	select @return_code = 0
	select @return_msg = NULL
	
	IF Len(@tceq_id) <> 5 
	 Begin
		select @return_code = 1
		select @return_msg = 'Please review the format of the generator state ID. For the state of Texas, the state ID should be in one of the following formats: (1) 5 digits, (2) H + 4 digits, (3) XXX + 2 digits, (4) RRGEN or (5) CESQG.'
 
	  END
	ELSE
       if @tceq_id NOT IN ( 'RRGEN' ,'CESQG' ) AND ISNUMERIC(@tceq_id) = 0 
         IF NOT 
          (
            (         
              SUBSTRING(@tceq_id,1,3) = 'XXX' and  
              CHARINDEX( SUBSTRING(@tceq_id,4,4), @c_xxx_suffix) > 0
            )
            
           OR
            
            (
             ( 
              SUBSTRING(@tceq_id,1,1) = 'H' and
              CHARINDEX( SUBSTRING(@tceq_id,2,1), @c_numeric) > 0 and
              CHARINDEX( SUBSTRING(@tceq_id,3,1), @c_numeric) > 0
             )
             AND 
             (
              CHARINDEX( SUBSTRING(@tceq_id,4,1), @c_numeric) > 0 and
              CHARINDEX( SUBSTRING(@tceq_id,5,1), @c_numeric) > 0
             )
           )
           
          )
           Begin
	      
             select @return_code = 1
		    
            	  
             select @return_msg = 'Please review the format of the generator state ID. For the state of Texas, the state ID should be in one of the following formats: (1) 5 digits, (2) H + 4 digits, (3) XXX + 2 digits, (4) RRGEN or (5) CESQG.'

           END
		   
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_validate_generator_tceq_id] TO [EQAI]
    AS [dbo];
GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_validate_generator_tceq_id] TO PUBLIC
    AS [dbo];
GO
