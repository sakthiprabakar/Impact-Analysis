﻿CREATE PROC dbo.AUDIT_prc_RollbackUndo
AS
IF @@TRANCOUNT > 0
  ROLLBACK TRAN
SET IMPLICIT_TRANSACTIONS OFF
DROP TABLE ##UndoLog
DROP TABLE ##UndoColumns
RETURN @@ERROR
