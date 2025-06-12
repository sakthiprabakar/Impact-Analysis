CREATE PROCEDURE sp_reports_workorder_status  
 @debug    int,    -- 0 or 1 for no debug/debug mode  
 @database_list  varchar(8000), -- Comma Separated Company List  
 @customer_id_list Text,   -- Comma Separated Customer ID List - what customers to include  
 @generator_id_list Text,   -- Comma Separated Generator ID List - what generators to include  
 @receipt_id   Text,   -- Receipt ID  
 @project_code  Text,   -- Project Code  
 @start_date1  varchar(20), -- Beginning Start Date  
 @start_date2  varchar(20), -- Ending Start Date  
 @end_date1   varchar(20), -- Beginning End Date  
 @end_date2   varchar(20), -- Ending End Date  
 @contact_id   varchar(100), -- User's Contact ID or 0  
 @session_key  varchar(100) = '', -- unique identifier key to a previously run query's results  
 @row_from   int = 1,   -- when accessing a previously run query's results, what row should the return set start at?  
 @row_to    int = 20   -- when accessing a previously run query's results, what row should the return set end at (-1 = all)?  
AS  
/* ***************************************************************************************************  
sp_reports_workorder_status:  
  
Info:  
 Returns the data for Work Orders.  
 LOAD TO PLT_AI  
   
Examples:  
 exec sp_reports_workorder_status 2, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '888888', '', '', '', '', '', '', '', '10913'  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '10635', '', '', '', '', '', '', '', '0'  
 exec sp_reports_workorder_status 2, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '9550', '', '', '', '', '', '', '', '0'  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '4879', '', '', '', '', '', '', '', '0'  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '4798', '', '', '', '', '', '', '', '0'  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '', '', '', '', '', '', '', '', '10913'  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '', '9583, 2388, 5531, 5771, 6328, 30352, 56986, 62293, 63598, 59942, 61986, 60096, 64719, 60620, 63363, 62975, 63364, 63365, 63366, 63367, 62660, 63473, 63986, 64138,
 63368, 63369, 61850, 63370, 63371, 63372, 62841, 63987, 64150, 62894, 63658, 63373, 63374, 62538, 63988, 64120, 63989, 63990, 64392, 64393, 64130, 63991, 63673, 59946, 63375, 64705, 62948, 63376, 62294, 64011, 64569, 64570, 63377, 64012, 64571, 64142, 63
378, 64013, 63379, 64014, 63380, 63381, 64284, 64285, 64286, 64287, 58521, 63656, 64572, 64015, 64573, 63382, 63383, 64574, 59645, 62684, 63384, 64575, 63385, 64576, 63645, 60601, 63386, 63387, 63388, 64016, 64092, 60807, 63064, 63389, 62749, 64052, 63390
, 63391, 64290, 62738, 64057, 62705, 64017, 64291, 63392, 64578, 64018, 64402, 63393, 64149, 60808, 64579, 63394, 63395, 60611, 62715, 64139, 63396, 64580, 64581, 64019, 63397, 64020, 64021, 62195, 64022, 62487, 64023, 62824, 62833, 62510, 64075, 62689, 6
4024, 62920, 62907, 64025, 62921, 64151, 63664, 60574, 64513, 60573, 63694, 60567, 64111, 64089, 64026, 62962, 62064, 64027, 64028, 64029, 62534, 61846, 1687, 64895, 63398, 64584, 64616, 63674, 64586, 60809, 64587, 63399, 64598, 63400, 62818, 64134, 62899
, 64295, 64296, 64297, 64298, 62999, 64600, 64030, 64137, 64405, 63401, 64031, 63601, 64032, 64603, 64604, 50157, 62295, 62542, 62509, 64669, 62997, 62985, 64617, 63402, 62480, 62196, 11764, 64619, 63403, 62838, 64033, 63404, 62193, 63405, 63406, 64034, 6
4035, 62808, 61794, 61844, 63407, 63408, 63409, 63410, 63411, 63412, 64143, 62755, 64036, 64037, 64038, 63413, 62839, 62229, 59693, 63414, 61992, 64039, 62959, 63415, 63416, 63417, 63418, 64040, 64041, 63419, 63420, 63421, 63422, 63423, 63424, 63425, 6460
5, 62540, 63426, 61847, 63667, 62986, 63427, 60456, 63428, 64129, 58172, 12350, 5414, 60554, 59756, 60524, 57458, 57564, 46011, 60724, 64731, 62520, 44286, 60443, 60618, 59944, 60996, 60455, 60997, 61290, 60385, 62853, 61305, 58491, 61293, 59649, 61000, 6
1493, 60537, 60374, 64868, 64952, 61462, 60377, 64866, 60460, 60100, 59935, 60379, 60458, 61292, 61483, 63705, 63513, 60457, 58292, 60619, 60376, 60461, 62856, 61291, 61296, 61301, 60381, 61778, 61161, 61104, 62253, 61410, 62459, 62109, 63021, 59943, 6202
0, 63902, 61661, 63237, 63512, 63238, 62571, 61664, 63904, 63906, 61912, 63242, 63244, 61807, 63036, 62192, 62397, 62423, 61719, 61444, 63914, 62111, 63916, 61733, 61454, 63921, 61789, 62884, 62493, 64471, 61669, 1144, 63249, 63732, 61443, 63733, 63251, 6
2462, 62497, 61184, 64652, 63925, 63734, 62412, 61877, 62405, 58226, 63624, 60386, 62409, 61453, 59715, 62004, 61627, 60617, 61387, 61721, 62533, 62022, 62112, 61516, 63262, 62114, 62408, 61909, 63936, 63263, 61608, 62095, 61725, 61124, 61966, 62029, 6223
3, 61427, 62855, 63939, 61804, 61881, 63941, 61797, 61999, 62197, 61713, 61188, 62018, 62262, 61167, 64647, 61668, 61125, 61412, 62913, 63269, 63270, 64649, 61180, 59961, 63704, 63701, 61122, 63710, 61190, 61001, 61532, 64887, 62218, 62203, 62893, 61117, 
60623, 61154, 63947, 63272, 61109, 62039, 61611, 61097, 61729, 61088, 61963, 61392, 63273, 61400, 61095, 64055, 64058, 61108, 59335, 62056, 63949, 62125, 61221, 954, 62213, 63684, 63648, 59955, 59648, 62496, 61514, 60459, 59959, 61787, 63951, 61128, 61694
, 61210, 63952, 59958, 63006, 61891, 61214, 59721, 61192, 64656, 62148, 62432, 62249, 61885, 63954, 63449, 63711, 59966, 60621, 61116, 61156, 64640, 61417, 61187, 64653, 59962, 59960, 63744, 61159, 60613, 61607, 61185, 64654, 62254, 64095, 63635, 63685, 6
1451, 62560, 63651, 59192, 63644, 62460, 61732, 61383, 62206, 62038, 62058, 63640, 63668, 64064, 59956, 64056, 61199, 62156, 61191, 64655, 60375, 63669, 61441, 62226, 61132, 64070, 63709, 62199, 61988, 63690, 64071, 61609, 59948, 62268, 63628, 61476, 6142
1, 61962, 64076, 63712, 63280, 61677, 62500, 63282, 63749, 62902, 62050, 62034, 62223, 64067, 59722, 62399, 62256, 61015, 62874, 62676, 60192, 62024, 63284, 61802, 63672, 62097, 61926, 62023, 63958, 62026, 64054, 62463, 62041, 64108, 64081, 63600, 63285, 
59964, 62576, 63286, 61728, 63014, 64072, 59714, 61967, 62434, 63653, 62210, 62220, 64074, 59953, 59957, 61625, 63660, 62145, 61220, 63961, 62124, 62566, 62406, 61905, 63015, 64113, 59951, 63687, 59952, 63686, 62886, 62234, 61795, 64102, 59963, 62404, 614
06, 64112, 61371, 892, 61175, 64650, 61093, 63293, 61678, 63759, 61517, 61982, 61160, 64639, 61686, 64743, 61202, 61875, 61818, 61696, 61657, 62130, 62901, 61115, 62070, 61212, 63004, 62465, 62464, 63661, 63655, 63666, 59950, 64097, 60387, 61070, 61892, 6
1734, 62091, 63108, 62936, 63109, 61127, 61397, 62494, 59965, 61475, 62638, 63593, 64778, 63622, 62172, 62055, 62025, 63770, 61398, 61911, 62491, 62035, 63110, 63773, 62113, 61872, 62014, 62422, 62420, 61825, 62455, 61720, 62889, 62892, 59734, 61913, 6397
4, 63706, 61895, 64093, 64871, 61896, 61405, 62235, 61888, 62232, 62001, 63514, 62570, 62569, 61658, 61990, 61731, 64090, 61893, 58717, 64105, 61730, 62573, 63008, 60551, 61526, 62413, 63583, 61512, 61530, 61189, 63976, 63582, 63977, 62088, 62015, 63780, 
62225, 61091, 63683, 62577, 61716, 61415, 61717, 61623, 64115, 61519, 59736, 60615, 63467, 63783, 64645, 61157, 62568, 61389, 61930, 61922, 62454, 63120, 62017, 60389, 61518, 61699, 62266, 61799, 61433, 62208, 63790, 62150, 62942, 61871, 63794, 63795, 615
27, 63130, 63796, 61223, 61632, 61735, 63019, 58334, 64162, 63797, 62887, 62574, 63136, 63137, 63027, 64756, 62255, 63141, 63048, 62094, 64742, 62215, 62060, 63145, 62222, 63150, 62891, 61879, 61428, 59727, 63153, 63154, 63157, 61785, 62239, 63499, 63158,
 62429, 61928, 63159, 63806, 61610, 62132, 61829, 61059, 59605, 63992, 64088, 63689, 64053, 59949, 61798, 62151, 62890, 63691, 63698, 63996, 63022, 63997, 63998, 63568, 61061, 64000, 64001, 62403, 63708, 63665, 61659, 62881, 62885, 63167, 63168, 62115, 62
037, 63707, 62882, 61890, 63016, 64080, 62448, 61439, 61899, 61671, 61927, 63175, 62499, 61724, 61062, 61366, 59469, 62161, 61674, 60616, 63178, 63818, 62466, 59713, 62505, 61473, 61110, 62237, 61718, 63020, 63185, 59939, 62214, 62068, 61783, 62209, 62224
, 60558, 62085, 61654, 62398, 59738, 61114, 63632, 63012, 61419, 61624, 61426, 61629, 63677, 63688, 63643, 61924, 62103, 64613, 63850, 61391, 63852, 4359, 62116, 62099, 61448, 62108, 62263, 63509, 59725, 62087, 62672, 64735, 61687, 61113, 61168, 64648, 61
100, 61126, 61105, 62146, 63873, 61631, 63023, 62205, 61120, 61455, 62883, 62236, 61722, 61121, 61622, 61471, 62217, 62180, 63878, 61396, 61978, 63032, 1611, 61388, 62219, 61712, 61883, 62187, 61424, 59696, 61064, 62165, 62201, 63208, 61897, 62259, 62359,
 61375, 62063, 63886, 61372, 61173, 62230, 63037, 61169, 64644, 61670, 59635, 61414, 63215, 63216, 61381, 61822, 62174, 62104, 61103, 62036, 62796, 62251, 63220, 1246, 61401, 63227, 63896, 62227, 61993, 63035, 62027, 61714, 63727, 61123, 63011, 59655, 617
23, 62578, 8035, 61545, 2002, 62521, 62923, 62848, 62852, 64714, 64712, 64710, 64682, 50144, 59534, 60373, 61540, 57807, 56908, 50052, 55165, 53275, 62567, 12349, 59549, 53771, 58218, 59552, 57619, 1782, 50068, 58383, 61675, 61690, 67058, 65442, 65466, 66
156, 66540, 65174, 65066, 67330, 66499, 67566, 65104, 65190, 66720, 65488, 66320, 66751, 65057, 66633, 67237, 67190, 67141, 66381, 67586, 67394, 66964, 66342, 65060, 67171, 66158, 66150, 66812, 66965, 65635, 65683, 66702, 66157, 65067, 66379, 65358, 67396
, 65055, 66621, 66905, 65485, 65201, 66299, 66401, 65595, 62106, 65963, 66386, 67680, 66945, 65448, 66154, 67191, 66301, 66599, 67236, 67215, 66624, 67059, 66486, 66678, 66847, 66600, 65416, 65761, 67400, 66091, 67588, 59654, 61528, 61438, 62119, 61531, 6
2430, 61652, 61700, 61693, 61688, 59650, 61697, 59697, 61520, 59732, 64702, 61702, 62842, 59657, 62575, 61701, 62564, 61692, 61985, 51349, 62968, 51347, 51356, 51357, 1981, 47094, 3033, 42011, 7650, 23836, 7271, 55399, 64721, 62169, 60142, 63595, 63602, 6
0612, 63584, 64781, 63567, 64775, 64784, 62442, 63586, 63591, 64780, 63611, 27107, 32488, 6376, 19839, 47055, 64722, 64738, 61486, 61575, 62053, 60577, 61489, 63230, 62189, 62071, 63231, 63901, 62182, 63232, 62067, 63046, 63728, 63233, 63234, 63235, 63236
, 63729, 63239, 63903, 63240, 63905, 62066, 63241, 63040, 63907, 63730, 62912, 62072, 63908, 63243, 63909, 63910, 62177, 63911, 63912, 63913, 63245, 63915, 62523, 63917, 63918, 63919, 63920, 62905, 62173, 63246, 63731, 62178, 62906, 63922, 63247, 63923, 6
3248, 62179, 63250, 62176, 63252, 63453, 63454, 63924, 62851, 63926, 63927, 62652, 63253, 63735, 62544, 63476, 63928, 63254, 63255, 63929, 63930, 63931, 63932, 63256, 63736, 63451, 62519, 63933, 62478, 63257, 63934, 63462, 63258, 63935, 63259, 63260, 6326
1, 63041, 62518, 63264, 63937, 62535, 63265, 63266, 63077, 63267, 62898, 63938, 63940, 62167, 62916, 62846, 63268, 62845, 62530, 61970, 61584, 63480, 63942, 63078, 62904, 63271, 62483, 63079, 63943, 63944, 63945, 63946, 63080, 63459, 62479, 63737, 63738, 
63948, 63739, 62918, 63081, 62545, 63950, 63740, 63082, 63741, 63083, 62657, 63742, 62903, 63953, 63472, 63743, 63464, 63745, 63084, 63274, 63275, 63085, 63746, 63747, 63276, 63086, 63748, 63087, 63277, 64796, 63088, 63955, 63278, 63279, 63089, 63956, 632
81, 62517, 63090, 64704, 63750, 63091, 63283, 63092, 63093, 63957, 63959, 63094, 62917, 63751, 63752, 63095, 63753, 62922, 63096, 63097, 63287, 63098, 62911, 63960, 63754, 63099, 63288, 63100, 63289, 62073, 62074, 63755, 63290, 63101, 62835, 63291, 63756,
 63292, 63962, 62844, 63102, 63963, 63447, 60624, 63033, 63757, 63964, 63457, 63294, 63758, 62190, 63965, 63966, 63103, 62915, 62075, 63967, 63760, 63104, 62513, 63105, 63968, 63106, 63107, 62076, 63295, 63455, 63296, 62175, 63297, 62843, 63298, 63969, 63
970, 63971, 62919, 63299, 63761, 63300, 62485, 63301, 63302, 63303, 62908, 63442, 63440, 63762, 63763, 63764, 63765, 63766, 63767, 63768, 63769, 63771, 63772, 62653, 63439, 62537, 62654, 63111, 63304, 63112, 63305, 63306, 63307, 63972, 63973, 63308, 63309
, 63310, 63311, 62512, 63443, 63312, 63313, 63314, 63774, 63315, 63775, 63316, 63776, 63317, 63318, 63319, 63438, 63481, 63475, 63320, 63321, 64668, 62472, 63322, 63323, 63324, 63325, 63113, 62482, 62900, 63777, 62647, 63326, 62834, 63975, 63327, 63328, 6
3329, 63034, 63114, 63778, 63779, 63330, 62532, 63331, 63332, 63978, 63333, 63115, 63334, 63781, 63979, 63782, 63980, 63981, 63478, 63116, 63982, 62183, 63784, 63335, 63336, 63983, 63117, 63337, 63118, 63119, 63984, 63785, 62910, 63786, 63787, 63788, 6378
9, 63121, 63122, 63123, 63124, 63125, 62529, 63791, 63792, 63458, 63793, 63126, 63127, 63128, 63129, 63131, 63132, 63133, 63134, 62528, 63135, 63798, 63465, 63466, 63138, 63985, 63139, 63140, 63799, 63142, 63800, 63143, 63144, 63146, 63147, 63148, 63149, 
63801, 63802, 63151, 63152, 63461, 63155, 63156, 63803, 63446, 63804, 62527, 62507, 62481, 63805, 63160, 63029, 63807, 62840, 63161, 63338, 63808, 62511, 63993, 63994, 63995, 63162, 63339, 63340, 62909, 63999, 63341, 63163, 63468, 63164, 63342, 63343, 633
44, 63345, 62474, 63165, 63346, 62486, 64002, 64003, 62914, 64004, 63470, 62895, 63809, 63347, 63348, 63166, 63349, 63350, 63351, 64005, 63474, 64006, 64007, 63169, 64008, 63352, 63170, 63810, 63353, 63354, 63355, 62526, 63811, 63812, 64009, 63171, 63356,
 63172, 62651, 63173, 63357, 63358, 63813, 62078, 63814, 62171, 62508, 63359, 64010, 62837, 62159, 63815, 63174, 63360, 63482, 63361, 62646, 63362, 62836, 62181, 62079, 63816, 63176, 63817, 63177, 63179, 63477, 63819, 60309, 63820, 63821, 62160, 63180, 62
290, 62650, 63181, 63182, 63822, 63183, 63184, 62288, 63186, 63187, 62170, 62473, 63823, 63824, 62080, 62069, 63721, 63188, 63825, 63826, 63827, 63828, 63829, 63830, 63831, 63832, 63833, 62484, 63834, 63835, 63836, 63837, 63838, 63839, 63840, 63841, 63842
, 63843, 63844, 63845, 63846, 61942, 63847, 63848, 62292, 63849, 63851, 63469, 63853, 63854, 63855, 63189, 63856, 63857, 63858, 63471, 63859, 63860, 63861, 63862, 62476, 63863, 63864, 63865, 63866, 63867, 63868, 63869, 63870, 63871, 63872, 63190, 62539, 6
3191, 63722, 63192, 62081, 63193, 62477, 63194, 62166, 63445, 63874, 63875, 63195, 63876, 63076, 63196, 63877, 63197, 62896, 63198, 63199, 63028, 64922, 63200, 63201, 63202, 63203, 63204, 63879, 63205, 63045, 63452, 63206, 63460, 63207, 62065, 62525, 6388
0, 63209, 63881, 62649, 62471, 62191, 63210, 63882, 63883, 63211, 63723, 63884, 63885, 63887, 62897, 63888, 63212, 63213, 63031, 63889, 62163, 63214, 62289, 63217, 63890, 63891, 62850, 62847, 63218, 63042, 63219, 63221, 63724, 64768, 63892, 62536, 63893, 
62524, 62541, 63894, 63222, 63725, 63223, 63224, 63225, 63226, 63895, 62164, 62849, 63228, 63726, 63897, 63229, 63898, 63899, 63900, 64798, 64746, 62447, 7108, 64729, 60666, 61242, 9933, 10091, 10256, 11108, 11429, 16498, 17239, 20248, 20249, 20475, 46042
, 29330, 30951, 25410, 26085, 62137, 60384, 57038, 62452, 64182, 64184, 64467, 64185, 64355, 64301, 64469, 60957, 64470, 64357, 64359, 64186, 64187, 64188, 64189, 64190, 60958, 64360, 64361, 64191, 64362, 62098, 64364, 64472, 64473, 64365, 64366, 60882, 6
4368, 64369, 62100, 64370, 64192, 64193, 64371, 64195, 64196, 64197, 60539, 64198, 64476, 60798, 64199, 61302, 60799, 64201, 64203, 64204, 64477, 64205, 64478, 64206, 64479, 64480, 64481, 64482, 64483, 61698, 64484, 64485, 64209, 64372, 64302, 64486, 6448
7, 64210, 60800, 62330, 64213, 64214, 64215, 64488, 64490, 64491, 64373, 64374, 64216, 60786, 64492, 61295, 64493, 64495, 64496, 58876, 64218, 64219, 64375, 64220, 64221, 64222, 64497, 64223, 60992, 62670, 60787, 64225, 64226, 64227, 64228, 64229, 58875, 
64499, 64376, 64231, 64500, 64501, 64232, 61039, 64233, 62135, 64503, 64504, 64505, 64506, 64378, 64235, 64236, 64508, 64509, 64237, 64238, 64514, 64515, 64516, 64517, 64518, 64519, 64520, 64521, 64522, 55485, 64407, 64379, 64240, 64410, 61996, 64411, 644
12, 64242, 64413, 64414, 64246, 64303, 64380, 64415, 64416, 64523, 64525, 64417, 64526, 61303, 64247, 63432, 64420, 64249, 64421, 64250, 64527, 64422, 64423, 58332, 61809, 64382, 60383, 64252, 64304, 64426, 64383, 62127, 64385, 64253, 64254, 64255, 64256,
 60380, 64257, 64386, 64258, 64259, 64260, 2963, 64529, 62326, 64533, 64261, 64262, 64305, 1928, 64535, 64306, 64546, 64387, 64388, 60838, 64307, 64427, 64428, 64536, 64537, 60801, 60802, 64429, 64389, 64308, 64430, 64390, 64391, 60788, 60803, 64431, 6426
3, 64538, 64539, 60789, 64432, 61573, 64541, 64545, 64433, 64266, 64940, 64548, 62727, 64267, 64434, 64268, 64269, 64310, 64311, 64435, 64436, 64312, 64437, 64438, 64439, 64440, 64549, 64270, 64441, 64313, 64166, 64271, 64314, 64315, 64272, 57028, 64550, 
64551, 64442, 64552, 64316, 60804, 58612, 64555, 60805, 64394, 64317, 64556, 64395, 64319, 64557, 64397, 64558, 60806, 64273, 64559, 64560, 64838, 64561, 64562, 64275, 64276, 64277, 59218, 64399, 64563, 64278, 64320, 64564, 64565, 64443, 64321, 64169, 650
02, 64322, 64323, 64324, 64325, 64326, 64444, 60790, 64279, 64280, 64282, 64445, 59227, 64566, 64283, 64568, 64401, 64446, 64171, 64288, 64289, 64447, 64448, 60791, 64577, 60792, 60784, 64582, 64583, 64336, 64337, 64338, 64339, 64340, 64341, 64342, 64343,
 64344, 64345, 64292, 64346, 64347, 62635, 64349, 64350, 64351, 64352, 64449, 64353, 60793, 64450, 60794, 64451, 60795, 64452, 64453, 64454, 60785, 64403, 64293, 64404, 64294, 64602, 64299, 64354, 64406, 64172, 64606, 64458, 64459, 64460, 64461, 64173, 60
796, 64174, 64175, 60797, 64462, 64176, 64177, 64178, 64463, 64464, 60812, 64465, 64179, 64180, 64958, 29643, 54066, 10094, 1919, 1335, 20563, 20367, 63448, 20020, 8531, 20570, 63589, 10519, 8689, 64734, 64769, 58209, 53712, 16788, 14938, 53938, 65151', '
', '', '', '', '', '', '100913'  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '', '', '', '', '', '', '', '', '100913'  
  exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '', '', '', '', '', '', '', '', '100913', '8EFFF47A-DC49-408E-BB14-9E4FBEB0A8A8', 20, 41  
  exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '', '', '', '', '', '', '', '', '100913', '8EFFF47A-DC49-408E-BB14-9E4FBEB0A8A8', 1, -1  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '', '', '7393900, 6180700, 6534500, 6857700', '', '', '', '', '', '0'  
 exec sp_reports_workorder_status 0, '14|0, 14|4, 14|5, 14|6, 14|12, 15|1, 21|0, 24|0', '', '', '7393900, 6180700, 6534500, 6857700', '', '', '', '', '', '100913'  
  
History:  
 09/20/2006 JPB Created - copy of sp_reports_workorders to start with.  
 05/31/2007 JPB Modified from varchar(8000) inputs to Text inputs  
 10/03/2007 JPB  Modified to remove NTSQL* references  
 03/08/2008 JPB Modified to handle profit_ctr_id and profit_ctr_name according to profitcenter.view_on_web rules  
  Addresses bad behavior from sp_reports_list_database: Doesn't use srld anymore  
  Properly renders the "display as" names for profitcenters that report as their parent company  
 12/04/2008  JPB Modified to abort when there's in-specific criteria entered, and return start/end date  
  Added "SET ANSI_WARNINGS OFF" and "SET ANSI_WARNINGS ON" at top and bottom of SP  
  Removed dbo.fn_web_profitctr_display_id handling of profit_ctr_id  
  Added proper paging handling  
 12/08/2008 JPB Modified per Lorraine: Never show records whose status is Void.  
 01/20/2009  JPB Modified to use plt_ai not eqweb/plt_web.  
  Modified to avoid reading Workorders with status of 'X' (as well as 'V')  
 02/18/2009 - RJG - Changed generator to be a LEFT OUTER instead of an INNER JOIn.  
    
  
*************************************************************************************************** */  
SET NOCOUNT ON  
SET ANSI_WARNINGS OFF  
  
  
-- Housekeeping.  Gets rid of old paging records.  
delete from Work_WorkorderListbyStatusResult where dateadd(hh, 8, session_added) < getdate()  
delete from Work_WorkorderDetailResult where dateadd(hh, 8, session_added) < getdate()  
  
-- Check to see if there's a @session_key provided with this query, and if that key is valid.  
if datalength(@session_key) > 0 begin  
 if not exists(select distinct session_key from Work_WorkorderListbyStatusResult where session_key = @session_key) begin  
  set @session_key = ''  
  set @row_from = 1  
  set @row_to = 20  
 end  
end  
  
-- If there's still a populated @session key, skip the query - just get the results.  
if datalength(@session_key) > 0 goto returnresults -- Yeah, yeah, goto is evil.  sue me.  
  
  
-- Define the 'today' variable used in the selects  
DECLARE @today varchar(20)  
SET @today = convert(varchar(2), datepart(mm, getdate())) + '/' +   
 convert(varchar(2), datepart(dd, getdate())) + '/' +   
 convert(varchar(4), datepart(yyyy, getdate()))   
  
  
-- Insert text-list values into table variables.  This validates that each element in the list is a valid data type (no sneaking in bad data/commands)  
-- Later learned: Can't use table variables here - have to use #tables because the most efficient filter query below only involves joins/where  
-- clauses that explicitly have values (which means building the string as @sql to execute) and you can't import a table-variable into an exec statement.  
-- Oh the twisted web we weave, when first we learn to optimize for speed.  
  
-- Database List: (expects x|y, x1|y1 format list)  
 create table #database_list (company_id int, profit_ctr_id int)  
 if datalength((@database_list)) > 0 begin  
  declare @scrub table (dbname varchar(10), company_id int, profit_ctr_id int)  
  
  -- Split the input list into the scub table's dbname column  
  insert @scrub select row as dbname, null, null from dbo.fn_SplitXsvText(',', 1, @database_list) where isnull(row, '') <> ''  
  
  -- Split the CO|PC values in dbname into company_id, profit_ctr_id: company_id first.  
  update @scrub set company_id = convert(int, case when charindex('|', dbname) > 0 then left(dbname, charindex('|', dbname)-1) else dbname end) where dbname like '%|%'  
  
  -- Split the CO|PC values in dbname into company_id, profit_ctr_id: profit_ctr_id's turn  
  update @scrub set profit_ctr_id = convert(int, replace(dbname, convert(varchar(10), company_id) + '|', '')) where dbname like '%|%'  
  
  -- Put the remaining, valid (process_flag = 0) scrub table results into #profitcenter_list  
  insert #database_list  
  select distinct company_id, profit_ctr_id from @scrub where company_id is not null and profit_ctr_id is not null  
 end  
  
-- Customer IDs:  
 create table #Customer_id_list (customer_id int)  
 if datalength((@customer_id_list)) > 0 begin  
  Insert #Customer_id_list  
  select convert(int, row)  
  from dbo.fn_SplitXsvText(',', 0, @customer_id_list)  
  where isnull(row, '') <> ''  
 end  
  
-- Generator IDs:  
 create table #generator_id_list (generator_id int)  
 if datalength((@generator_id_list)) > 0 begin  
  Insert #generator_id_list  
  select convert(int, row)  
  from dbo.fn_SplitXsvText(',', 0, @generator_id_list)  
  where isnull(row, '') <> ''  
 end  
  
-- Workorder IDs:  
 create table #workorder_id_list (workorder_id int)  
 if datalength((@receipt_id)) > 0 begin  
  Insert #workorder_id_list  
  select convert(int, row)  
  from dbo.fn_SplitXsvText(',', 0, @receipt_id)  
  where isnull(row, '') <> ''  
 end  
  
-- Project Codes:  
 create table #Project_Code_list (project_code varchar(15))  
 if datalength((@Project_Code)) > 0 begin  
  Insert #Project_Code_list  
  select rtrim(left(row, 15))  
  from dbo.fn_SplitXsvText(',', 1, @Project_Code)  
  where isnull(row, '') <> ''  
 end  
  
-- Abort early if there's just nothing to do here (no criteria given.  Criteria is required)  
-- May need to revise this list, if some of them are always given, but meaningless.  
 if datalength(ltrim(rtrim(isnull(@contact_id, '')))) = 0 return  
  
 if 0 -- just for nicer formatting below...  
  + (select count(*) from #customer_id_list)  
  + (select count(*) from #generator_id_list)  
  + (select count(*) from #workorder_id_list)  
  + (select count(*) from #Project_Code_list)  
  + datalength(ltrim(rtrim(isnull(@start_date1, ''))))  
  + datalength(ltrim(rtrim(isnull(@start_date2, ''))))  
  + datalength(ltrim(rtrim(isnull(@end_date1, ''))))  
  + datalength(ltrim(rtrim(isnull(@end_date2, ''))))  
  + datalength(ltrim(rtrim(isnull(@contact_id, ''))))  
 = 0 return  
  
 set @session_key = newid()  
 declare @sql varchar(8000)  
 declare @groupby varchar(1000)  
 create table #access_filter (company_id int, profit_ctr_id int, workorder_id int, contact_link char(1))  
  
 if @contact_id <> '0' begin -- non-associate version:  
  
  set @sql = 'insert #access_filter  
   select w.company_id, w.profit_ctr_id, w.workorder_id, min(w.contact_link)  
   from (  
   /* Directly Assigned customers via contactxref: */  
   select work.company_id, work.profit_ctr_id, work.workorder_id, ''C'' as contact_link  
   from workorderheader work  
   inner join contactxref x on work.customer_id = x.customer_id  
   where x.contact_id = ' + @contact_id + ' and x.status = ''A'' and x.web_access = ''A'' and x.type = ''C''  
   union  
   /* Directly Assigned generators via contactxref: */  
   select work.company_id, work.profit_ctr_id, work.workorder_id, ''G'' as contact_link  
   from workorderheader work  
   inner join contactxref x on work.generator_id = x.generator_id  
   where x.contact_id = ' + @contact_id + ' and x.status = ''A'' and x.web_access = ''A'' and x.type = ''G''  
   union  
   /* Indirectly Assigned generators via customergenerator related generators to contactxref related customers: */  
   select work.company_id, work.profit_ctr_id, work.workorder_id, ''G'' as contact_link  
   from workorderheader work  
   inner join customergenerator cg on work.generator_id = cg.generator_id  
   inner join contactxref x on cg.customer_id = x.customer_id  
   where x.contact_id = ' + @contact_id+ ' and x.status = ''A'' and x.web_access = ''A'' and x.type = ''C''  
   ) w  
   inner join workorderheader w2 on w2.workorder_id = w.workorder_id and w2.company_id = w.company_id and w2.profit_ctr_id = w.profit_ctr_id  
   inner join company co on w2.company_id = co.company_id  
   inner join profitcenter p on w2.company_id = p.company_id and w2.profit_ctr_id = p.profit_ctr_id  
   '  
  -- Only include inner joins to these tables if they have data (= a restriction) to add to the query...  
  if (select count(*) from #workorder_id_list) > 0  
   set @sql = @sql + ' inner join #workorder_id_list wil on w2.workorder_id = wil.workorder_id '  
  
  if (select count(*) from #customer_id_list) > 0  
   set @sql = @sql + ' inner join #customer_id_list cil on w2.customer_id = cil.customer_id '  
  
  if (select count(*) from #generator_id_list) > 0  
   set @sql = @sql + ' inner join #generator_id_list gil on w2.generator_id = gil.generator_id '  
  
  if (select count(*) from #Project_Code_list) > 0  
   set @sql = @sql + ' inner join #Project_Code_list pcl on w2.project_code = pcl.project_code '  
  
  if (select count(*) from #database_list) > 0  
   set @sql = @sql + ' inner join #database_list dl on w2.company_id = dl.company_id and w2.profit_ctr_id = dl.profit_ctr_id '  
  
  set @sql = @sql + '  
   where 1=1 /* where-slug */  
   AND co.view_on_web = ''T'' AND p.status = ''A'' AND p.view_on_web IN (''C'', ''P'') AND p.view_workorders_on_web = ''T''  
   AND w2.workorder_status NOT IN(''V'',''T'')
  '  
  
  set @groupby = ' GROUP BY w.company_id, w.profit_ctr_id, w.workorder_id '  
  
 end else begin  -- Associates version (associates don't have the "only see invoiced" requirement that non-associates do, so this query is much simpler)  
  
  set @sql = '  
  insert #access_filter  
  select w2.company_id, w2.profit_ctr_id, w2.workorder_id, ''A'' as contact_link  
  from workorderheader w2  
  inner join profitcenter p on w2.company_id = p.company_id and w2.profit_ctr_id = p.profit_ctr_id  
  inner join company co on w2.company_id = co.company_id   
  '  
    
  -- Only include inner joins to these tables if they have data (= a restriction) to add to the query...  
  if (select count(*) from #workorder_id_list) > 0  
   set @sql = @sql + ' inner join #workorder_id_list wil on w2.workorder_id = wil.workorder_id '  
  
  if (select count(*) from #customer_id_list) > 0  
   set @sql = @sql + ' inner join #customer_id_list cil on w2.customer_id = cil.customer_id '  
  
  if (select count(*) from #generator_id_list) > 0  
   set @sql = @sql + ' inner join #generator_id_list gil on w2.generator_id = gil.generator_id '  
  
  if (select count(*) from #Project_Code_list) > 0  
   set @sql = @sql + ' inner join #Project_Code_list pcl on w2.project_code = pcl.project_code '  
  
  if (select count(*) from #database_list) > 0  
   set @sql = @sql + ' inner join #database_list dl on w2.company_id = dl.company_id and w2.profit_ctr_id = dl.profit_ctr_id '  
  
  set @sql = @sql + '  
  WHERE 1=1 /* where-slug */  
  AND w2.workorder_status NOT IN (''V'', ''X'',''T'')  
  AND co.view_on_web = ''T''  
  AND p.status = ''A''  
  AND p.view_on_web IN (''C'', ''P'')  
  AND p.view_workorders_on_web = ''T''  
  '  
  
  set @groupby = ' GROUP BY w2.company_id, w2.profit_ctr_id, w2.workorder_id'  
  
 end  
  
 -- These conditions apply to both versions (associate/non-associate) of the query:  
 if datalength(ltrim(@start_date1)) > 0  
  set @sql = replace(@sql, '/* where-slug */', ' AND w2.start_date >= ''' + @start_date1 + ''' /* where-slug */')  
  
 if datalength(ltrim(@start_date2)) > 0  
  set @sql = replace(@sql, '/* where-slug */', ' AND w2.start_date <= ''' + @start_date2 + ''' /* where-slug */')  
  
 if datalength(ltrim(@end_date1)) > 0  
  set @sql = replace(@sql, '/* where-slug */', ' AND w2.end_date >= ''' + @end_date1 + ''' /* where-slug */')  
  
 if datalength(ltrim(@end_date2)) > 0  
  set @sql = replace(@sql, '/* where-slug */', ' AND w2.end_date <= ''' + @end_date2 + ''' /* where-slug */')  
  
 -- Execute the sql that popoulates the #access_filter table.  
 if @debug > 0 select @sql + @groupby  
  
 exec(@sql + @groupby)  
   
 exec('create index af_idx on #access_filter (workorder_id, company_id, profit_ctr_id)')  
  
--print (@sql + @groupby)  
--return  
  
-- Query (gets real WorkroderHeader data, inner joined to #access_filter to limit the rows the user is allowed to see):  
 INSERT Work_WorkorderListbyStatusResult (  
  customer_id,  
  cust_name,  
  receipt_id,  
  company_id,  
  profit_ctr_id,  
  project_name,  
  generator_name,  
  epa_id,  
  status,  
  start_date,  
  end_date,  
  condition,  
  profit_ctr_name,  
  session_key,  
  session_added  
 )  
 SELECT DISTINCT  
  h.customer_id,  
  c.cust_name,  
  h.workorder_id,  
  h.company_id,  
  h.profit_ctr_id,  
  h.project_name,  
  g.generator_name,  
  g.epa_id,  
  h.workorder_status,  
  h.start_date,  
  h.end_date,  
  case when start_date > @today then 'Scheduled' else  
   case when end_date < @today then 'Complete' else  
    case when start_date <= @today and end_date >= @today then 'In Progress' else 'Unknown' end  
   end  
  end as condition,  
  dbo.fn_web_profitctr_display_name(h.company_id, h.profit_ctr_id) as profit_ctr_name,  
  @session_key as session_key,  
  getdate() as session_added  
 FROM  
  #access_filter af  
  inner join workorderheader h on h.workorder_id = af.workorder_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id  
  inner join customer c on h.customer_id = c.customer_id  
  LEFT OUTER JOIN generator g on h.generator_id = g.generator_id  
  inner join profitcenter p on h.company_id = p.company_id and h.profit_ctr_id = p.profit_ctr_id  
  inner join company co on h.company_id = co.company_id  
 WHERE 1=1  
--  AND h.workorder_status NOT IN ('X', 'V')  
  AND co.view_on_web = 'T'  
  AND p.view_on_web in ('P', 'C')  
  AND p.status = 'A'  
  AND p.view_workorders_on_web = 'T'  
 ORDER BY h.company_id, h.profit_ctr_id, h.customer_id, h.workorder_id desc  
    
  
returnresults: -- Re-queries with an existing session_key that passes validation end up here.  So do 1st runs (with an empty, now brand-new session_key)  
  
 if datalength(@session_key) > 0 begin  
  declare @start_of_results int, @end_of_results int  
  select @start_of_results = min(row_num)-1, @end_of_results = max(row_num) from Work_WorkorderListbyStatusResult where session_key = @session_key  
  set nocount off  
  select  
   customer_id, cust_name, receipt_id, company_id, profit_ctr_id, project_name, generator_name, epa_id,  
   status, start_date, end_date, condition, profit_ctr_name, session_key, session_added,  
   row_num - @start_of_results as row_number,  
   @end_of_results - @start_of_results as record_count  
  from Work_WorkorderListbyStatusResult  
  where session_key = @session_key  
  and row_num >= @start_of_results + @row_from  
  and row_num <= case when @row_to = -1 then @end_of_results else @start_of_results + @row_to end  
  order by row_num  
  
  return  
 end  
  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS ON  

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorder_status] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorder_status] TO [COR_USER]
    AS [dbo];


