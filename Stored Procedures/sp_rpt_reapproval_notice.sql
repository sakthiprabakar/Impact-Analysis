CREATE PROCEDURE sp_rpt_reapproval_notice
	@customer_id	int
,	@generator_id	int
,	@profiles		varchar(max)
,	@debug			TINYINT
,	@record_type	TINYINT
AS
/***************************************************************************************
This sp runs for the Report -> Forms -> 30 day/60 day reapproval notice
Loads to:		PLT_AI
PB Object(s):	d_rpt_reapproval_notice

10/26/2011 SK	Created
08/22/2012 SK	Updated to not return ProfileQuoteApproval information as it will be a nested 
				dw in this report's result set.
10/04/2012 SK   Updated the @profiles variable to varchar(max)
				Added record_type to return different sets of data for the different levels of nest dws on report
11/27/2012 DZ   Added profile_id in the result set for record_type 1
07/16/2013 SK	Added ProfileLab.Benzene to the result set for record_type 1
02/14/2017 MPM	Added the list of approvals to the result set for record_type 1.
02/04/2020 AM  DevOps:18437 Added generatr_id to the approvals loop

sp_rpt_reapproval_notice 21, 00, '54831,76952,78277,79822,80645,81321,81369,171302,174980,175225,175690,187946,218593,241501,241502,263632,264644,266083,268413,269240,302736,304701,305457,305791,313341,317716,319125,319823,320270,321260,321264,321605,322612,322614,326865,327971,328742,330051,331266,332841,334365,334785,334931,335571,336876,340354,340432,340434,340562,341430,342911,343890,343927,343928,343929,344511,345509,348320,348329,348948,348963,349021,349512,349588,349589,349590,349975,349976,350083,350084,350131,350132,350388,350389,350390,350554,350793,350794,350881,351493,351494,351495,351496,351810,352433,352446,352480,352530,352566,352569,352665,352666,352739,352783,352926,352927,352928,353166,353888,353895,353901,353972,353973,353977,354372,354373,354424,354425,354978,355166,355168,355295,355297,355315,355690,356010,356011,356310,356311,356338,356339,356340,356341,356494,368537,368555,369894,369895,369896,369897,369968,369971,370153,370160,370161,371240,371241,371299,371302,371304,371305,371314,371316,371500,371502,371504,371507,371511,371515,371523,371524,371657,371711,371714,371715,371716,371717,371718,371801,371804,372085,372087,372088,372089,372193,372195,372221,372394,373946,374054,374179,374294,374296,374297,374301,374305,374307,374310,374533,374693,374696,374981,375009,375156,375203,375205,375677,375867,376160,376782,376956,376959,377093,377235,377237,377313,377315,377319,378430,378752,378753,378754,378755,379362,379363,379364,379371,379742,380670,380673,381103,381534,381964,381965,382178,382246,382251,382639,382641,382642,382643,382646,382648,382821,382822,383481,383483,383693,383696,383780,384123,384127,384299,384302,384303,384304,386838,387920,388062,388065,388069,388991,388992,389582,389605,390002,390003,390005,390437,390438,391463,391626,391859,395013,395466,395467,395468,395469,395587,397879,397953,399538,401514,401875,403608,403744,403749,403751,406004,406502,406504,406729,407191,407248,407466,407467,408634,408635,408637,408640,408641,408644,408645,408647,408985,409395,409398,409400,410044,411773,411969,411973,412252,413892,413918,413922,416785,416787,417213,418438,418442,418728,418730,418732,418733,418734,421263',1
								  54831,76952,78277,79822,80645,81321,81369,171302,174980,175225,175690,187946,218593,241501,241502,263632,264644,266083,268413,269240,302736,304701,305457,305791,313341,317716,319125,319823,320270,321260,321264,321605,322612,322614,326865,327971,328742,330
sp_rpt_reapproval_notice 4364, 43268, '75812, 251334',1, 1
sp_rpt_reapproval_notice 21, 0, '184918,376812,376823,376826,376828,376839,376897,376902,388373,398597,398598,398606,398610,398612,398613,398615,398617,399373,399374,399375,400400,400405,400407,403664,403666,403667,408486,408489,412085,412330,412332,413638,419877,420291,420295,420297,420300,420303,420308,420312,420313,420316,422971,432123,448628,457123,459290,459692,460721,460732,460801,460809,460816,460824,460851,460857,460859,460860,460864,460867,461978,464005,466448,467729,476465,486903,488688,489626,508402,511191,512202,522931,526350,527354,529393,533418,535741,535750,540929', 0, 1
sp_rpt_reapproval_notice 21, 0, '217112,217114,217116,217117,344501,344502,386007,386008,438286,462646,462647,462655,465917', 0, 1
sp_rpt_reapproval_notice 21, 0, '184918,376812,376823,376826,376828,376839,376897,376902,388373,398597,398598,398606,398610,398612,398613,398615,398617,399373,399374,399375,400400,400405,400407,403664,403666,403667,408486,408489,412085,412330,412332,413638,419877,420291,420295,420297,420300,420303,420308,420312,420313,420316,422971,432123,448628,457123,459290,459692,460721,460732,460801,460809,460816,460824,460851,460857,460859,460860,460864,460867,461978,464005,466448,467729,476465,486903,488688,489626,508402,511191,512202,522931,526350,527354,529393,533418,535741,535750,540929', 0, 1
sp_rpt_reapproval_notice 21, 0, '217112,217114,217116,217117,344501,344502,386007,386008,438286,462646,462647,462655,465917', 0, 1


****************************************************************************************/
DECLARE @approvals_list varchar(max),
        @approval_code	varchar(15),
        @cust_id		int,
        @epa_id			varchar(12),
        @last_cust_id	int,
        @last_epa_id	varchar(12),
        @profile_id		int,
		@generatr_id   int,
		@last_gen_id	int

SET NOCOUNT ON

CREATE TABLE #tmp_profiles (profile_id	int NULL)
EXEC sp_list @debug, @profiles, 'NUMBER', '#tmp_profiles'

--IF @debug = 1 
--BEGIN
--	Select profile_id FROM #tmp_profiles
--END

IF @record_type = 1 
BEGIN

    CREATE TABLE #tmp_approvals (
		profile_id	int,
		customer_id int,
		EPA_id varchar(12),
		approval_code varchar(15),
	    generator_id int,
		approvals_list varchar(max)
	)
	
	insert into #tmp_approvals
	SELECT DISTINCT pqa.profile_id, p.customer_id, g.epa_id, pqa.approval_code,p.generator_id, null
	  FROM ProfileQuoteApproval pqa
	  INNER JOIN #tmp_profiles
		ON pqa.profile_id = #tmp_profiles.profile_id
	  INNER JOIN Profile p
	    ON pqa.profile_id = p.profile_id
	   AND pqa.status = 'A'
	   AND pqa.approval_code IS NOT NULL
	  INNER JOIN Generator g
	    ON g.generator_id = p.generator_id

--select * from #tmp_approvals
--ORDER BY customer_id, EPA_id, approval_code

	DECLARE approvals_cursor CURSOR
	    FOR SELECT approval_code, customer_id, EPA_id, profile_id, generator_id
	          FROM #tmp_approvals
	      ORDER BY customer_id, EPA_id, approval_code
	   
	OPEN approvals_cursor
	   
	FETCH NEXT FROM approvals_cursor
		INTO @approval_code, @cust_id, @epa_id, @profile_id, @generatr_id
	   
	select @last_cust_id = @cust_id
	select @last_epa_id = @epa_id
	select @last_gen_id = @generatr_id
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		if  @epa_id = @last_epa_id and @last_gen_id = @generatr_id -- and @cust_id = @last_cust_id 
		begin
			if LEN(@approvals_list) > 0
				SELECT @approvals_list = @approvals_list + ', ' + @approval_code
			else
				SELECT @approvals_list = @approval_code
		end
		else
		begin
		
			update #tmp_approvals
			   set approvals_list = @approvals_list
			 where --customer_id = @last_cust_id and
			    epa_id = @last_epa_id
				and generator_id = @last_gen_id
				
			select @approvals_list = @approval_code
			if @last_cust_id <> @cust_id select @last_cust_id = @cust_id
			if @last_epa_id <> @epa_id select @last_epa_id = @epa_id
			if @last_gen_id <> @generatr_id select @last_gen_id = @generatr_id
			
		end

	    FETCH NEXT FROM approvals_cursor
		    INTO @approval_code, @cust_id, @epa_id, @profile_id, @generatr_id
    END
	   
	CLOSE approvals_cursor
	   
	DEALLOCATE approvals_cursor

	-- Do final update of #tmp_approvals
	update #tmp_approvals
	   set approvals_list = @approvals_list
	 where --customer_id = @last_cust_id and
	    epa_id = @last_epa_id
		and generator_id = @last_gen_id

--select * from #tmp_approvals
--ORDER BY customer_id, generator_id, approval_code
	 
	SELECT DISTINCT
		Customer.customer_id
	,	Customer.cust_name
	,	Contact.name AS contact_name
	,	Customer.cust_addr1
	,	Customer.cust_addr2
	,	Customer.cust_addr3
	,	Customer.cust_addr4
	,	Customer.cust_city
	,	Customer.cust_state
	,	Customer.cust_zip_code
	,	Customer.cust_fax
	,	Generator.generator_id
	,	Generator.generator_name
	,	Generator.EPA_ID
	,	Generator.TAB
	,	Profile.profile_id
	,	ProfileLab.benzene
	,	#tmp_approvals.approvals_list
	FROM Profile
	INNER JOIN Customer 
		ON Customer.customer_id = Profile.customer_id
	INNER JOIN Generator 
		ON Generator.generator_id = Profile.generator_id
	INNER JOIN ProfileLab
		ON ProfileLab.profile_id = Profile.profile_id
		AND ProfileLab.type = 'A'
	LEFT OUTER JOIN ContactXRef
		ON ContactXRef.customer_id = Customer.customer_ID
		AND dbo.ContactXRef.primary_contact = 'T'
	LEFT OUTER JOIN dbo.Contact
		ON dbo.ContactXRef.contact_id = dbo.Contact.contact_ID
	INNER JOIN #tmp_profiles
		ON Profile.profile_id = #tmp_profiles.profile_id
    INNER JOIN #tmp_approvals
        ON Profile.profile_id = #tmp_approvals.profile_id
	--WHERE Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
	ORDER BY Customer.customer_id,
			 Generator.EPA_ID
END
ELSE
BEGIN
	SELECT 
		Profile.profile_id
	,	Customer.customer_id
	,	Profile.generator_id
	,	WasteCode.waste_code_desc 
	,	Profile.approval_desc
	,	Profile.ap_expiration_date
	FROM Profile
	INNER JOIN Customer 
		ON Customer.customer_id = Profile.customer_id
	INNER JOIN Generator 
		ON Generator.generator_id = Profile.generator_id
	LEFT OUTER JOIN WasteCode
		ON WasteCode.waste_code = Profile.waste_code	
	LEFT OUTER JOIN Contact 
		ON Contact.contact_id = Profile.contact_id
	WHERE Profile.profile_id IN (Select profile_id FROM #tmp_profiles )
		AND Profile.customer_id = @customer_id
		AND Profile.generator_id = @generator_id
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_reapproval_notice] TO [EQAI]
    AS [dbo];

