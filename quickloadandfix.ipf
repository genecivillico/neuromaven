#pragma rtGlobals=3		// Use modern global access method and strict wave access.



Function quick (list)
	WAVE/T list
	
	variable num = numpnts(list),i
	string nextAVG, nextCAR
	
	for (i=1; i < num; i += 1)
	
		nextAVG = "Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:mouse9:" + list[i] + ":data_records:AVG.ibw"
		loadwave/O nextavg
		WAVE AVG
		redimension/s AVG
		
		nextCAR = "Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:mouse9:" + list[i] + ":data_records:CAR.ibw"
		loadwave/O nextCAR
		WAVE CAR
		redimension/s CAR
		
		saveexperiment

	endfor

end