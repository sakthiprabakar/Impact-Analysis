USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [dbo].[sp_ProfileAudit_Duplicates]
GO
/****************************************************************************
sp_ProfileAudit_Duplicates	

	Executed from EQAI ue_save event to remove Profile table's duplicate rows saved to the ProfileAudit table

History:
	 

Example:
	DECLARE lproc_handle_dups PROCEDURE FOR dbo.sp_ProfileAudit_Duplicates
		@profile_id = :ll_profile_id
	
USING itr_share;

EXECUTE lproc_handle_dups;
If itr_share.SQLCode < 0 Then
    MessageBox( "Error Calling lproc_handle_dups", &
    itr_share.SQLErrText, StopSign!)
    Return
End If

FETCH lproc_handle_dups INTO :li_cVetValue;

COMMIT USING itr_share;
CLOSE lproc_handle_dups;
****************************************************************************/	
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_ProfileAudit_Duplicates] (@profile_id INT)
AS
BEGIN
      SET NOCOUNT ON;
 
      --DECLARE THE VARIABLES FOR HOLDING DATA.
      DECLARE @Table_Name VARCHAR(40)
             ,@Column_Name VARCHAR(40)
			 ,@Before_Value VARCHAR(255)
			 ,@After_Value VARCHAR(255)
			 ,@Uniqueidentifier uniqueidentifier
			 ,@ResultValue  INT 
 
      --DECLARE AND SET COUNTER.
      DECLARE @Counter INT
      SET @Counter = 0

      --DECLARE THE CURSOR FOR SELECT QUERY.
      DECLARE cur_audit CURSOR FOR SELECT LTrim(RTrim(a.rowguid)), LTrim(RTrim(a.table_name)), LTrim(RTrim(a.column_name)), LTrim(RTrim(a.before_value)), LTrim(RTrim(a.after_value))
		FROM profileaudit a
		INNER JOIN
			(
 				SELECT MAX(rowguid) AS ID, table_name,column_name,before_value,after_value
	 			FROM profileaudit 
				WHERE profile_id=LTrim(RTrim(@profile_id))
 				AND table_name='profile'
 				GROUP BY table_name,column_name,before_value,after_value  
 				HAVING COUNT(rowguid) > 1
			) b
		ON a.rowguid <> b.ID AND a.table_name=b.table_name AND a.column_name=b.column_name
		WHERE a.profile_id=@profile_id
 
      --OPEN CURSOR.
      OPEN cur_audit
 
      --FETCH THE RECORD INTO THE VARIABLES.
      FETCH cur_audit INTO @Uniqueidentifier,  @table_name,  @Column_Name,  @Before_Value,  @After_Value
 
      --LOOP UNTIL RECORDS ARE AVAILABLE.
      WHILE @@FETCH_STATUS = 0
      BEGIN
             IF @Counter >= 1
             BEGIN
              --DELETE CURRENT RECORD.
				DELETE FROM ProfileAudit
				WHERE rowguid = LTrim(RTrim(@Uniqueidentifier))
				AND profile_id = LTrim(RTrim(@profile_id))	

			 END

             	--INCREMENT COUNTER.
             SET @Counter = @Counter + 1
             --FETCH THE NEXT RECORD INTO THE VARIABLES.
             FETCH NEXT FROM cur_audit INTO  @Uniqueidentifier,  @table_name,  @Column_Name,  @Before_Value,  @After_Value
      END
	  
	 
      CLOSE cur_audit
      DEALLOCATE cur_audit
	  RETURN @Counter
END
GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfileAudit_Duplicates] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfileAudit_Duplicates] TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfileAudit_Duplicates] TO [EQAI]
    AS [dbo];