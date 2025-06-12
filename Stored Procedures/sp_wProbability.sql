CREATE PROCEDURE sp_wProbability AS
Select Probability, Description from wlkp_Probability
order by Probability
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wProbability] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wProbability] TO [COR_USER]
    AS [dbo];


