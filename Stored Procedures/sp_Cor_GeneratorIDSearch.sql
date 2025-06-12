
--DROP PROCEDURE [dbo].[sp_Cor_GeneratorIDSearch] 
--GO

CREATE PROCEDURE [dbo].[sp_Cor_GeneratorIDSearch] 
	-- Add the parameters for the stored procedure here
	@web_userid varchar(100), 
	@generator_search varchar(40),
    @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
AS
/* ****************************************************************
sp_Cor_GeneratorIDSearch

List the generators available to a user

09/27/2019 MPM  DevOps 11571: Added logic to filter the result set
				using optional input parameter @generator_id_list.

sp_Cor_GeneratorIDSearch 'erindira7', 'Amazon'
sp_Cor_GeneratorIDSearch 'erindira7', 'Amazon', '123934, 123936'

**************************************************************** */
DECLARE @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

Select * 
from Cor_db..GeneratorName gn
where gn.generator_id in (select * from dbo.fn_COR_GeneratorID_Search(@web_userid, @generator_search))
and
	(
        @i_generator_id_list = ''
        or
        (
			@i_generator_id_list <> ''
			and
			gn.generator_id in (select generator_id from @generator)
		)
	)

GO

GRANT EXECUTE ON [dbo].[sp_Cor_GeneratorIDSearch] TO COR_USER;
GO