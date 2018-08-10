#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// aggregate from database

// these functions crawl the Igor database to build analysis outputs that will be saved as part of an Igor pxp.


Function MultiSessionMultiChannel (recordinglist, referencename, oneatatime, thingtocompute,analysisparameters)
	WAVE/T recordinglist
	string referencename, thingtocompute
	variable oneatatime
	WAVE analysisparameters
	
	// subject
	string subject = getdatafolder(0)

	variable numchannels = 16
	variable numrecordings = numpnts(recordinglist)

	make/o/n=(numrecordings,numchannels) output
	// newimage/S=0 output
	// ModifyImage ''#0 ctab= {0,50,YellowHot,0}
	
	// can't do this as a wave assignment because I need to control the dimension order for memory management
	variable i,j
	
	for (i=0; i < numrecordings; i+= 1)
	
		for (j=0; j <  numchannels ; j += 1)
		
			output[i][j] = ComputeFromDatabaseChannels (subject, recordinglist[i], "HI_NIP"+num2str(j+1), referencename, oneatatime, thingtocompute, analysisparameters)
			doupdate
		endfor
		
		// kill whatever reference was loaded for the previous session
		if (WaveExists($referencename))
			killwaves $referencename
			printf "killed  wave %s to clean up for next session\r", referencename
		elseif (WaveExists($"AVG"))
			killwaves $"AVG"
			printf "killed  wave AVG to clean up for next session\r"
		endif
		
	endfor

end


// oneatatime: 0 means need to load all channels before computing something for a single channel. 1 means one channel at a time is enough
// use full path to files - don't need Igor symbolic paths!
// whichanalysis
//	AER_postCAR
//	SD: analysisparameters are [0]: blank yes no; [1]: size of blanked events in SD; [2] window to blank in ms
Function ComputeFromDatabaseChannels (subjectname, sessionname, channelname, referencename, oneatatime, whichanalysis, analysisparameters)
	string subjectname, sessionname, channelname, referencename, whichanalysis
	variable oneatatime
	wave analysisparameters
	
	pathinfo database_path
	if (!V_flag)
		abort "databasepath not specified"
	endif
	
	string database_pathstring = S_path
	
	string fullpathtowave = "", fullpathtoreference = ""
	
	if (oneatatime == 0)
		// load all channels
		// needed only for coherencematrix

	else
	
		WAVE theChannel = $(LoadAndRereferenceFromDatabase (subjectname, sessionname, channelname, referencename))
		if (!waveexists(theChannel))
			printf "missing channel at %s\r", fullpathtowave
		endif	
		
		// compute postsub SDs here for now.  once I decide whether I'm storing references, I can do a load below instead
		wavestats/q theChannel
	
	endif

	//case-switch to figure out what to compute
	//compute
	//return value
	
	channelname = nameofwave(theChannel)
	variable theResult
	
	strswitch(whichanalysis)
						
		case "AER_postCAR":
		
			variable howmanySDs = analysisparameters[0]
		
			// using raw SDs for now, but these were usually computed with the blanking at the same SD level as the desired cutoff
			string whichSD = "_raw" // or = "_postsub_"+num2str(analysisparameter)+"SDblank"
			string fullpathtoSD = database_pathstring + subjectname + ":" + sessionname + ":SDs:SDs" + whichSD		

			Variable SD_thischannel = V_sdev
							
			// get the single value from our channel
			theResult= crossingsSingleLevel(theChannel,1,howmanySDs*SD_thischannel)
							
		break
		
		case "SD":
			
			variable SDblank 			 = analysisparameters[0]	// blank yes=1, no=0
			variable SDblank_eventsize  = analysisparameters[1]	// size of events to blank
			variable SDblankwindow_ms = analysisparameters[2]	// window to blank in ms
			
			if (SDblank)
				theResult = getblankedSD2(theChannel, SDblank_eventsize ,SDblankwindow_ms)
			else	
				WaveStats/Q theChannel
				theResult = V_sdev
			endif
		
		break

	endswitch
	
	// clean up
	killwaves theChannel //, SDlist, channelnumberlist
	
	return theResult

end


Function/S LoadAndRereferenceFromDatabase (subjectname, sessionname, channelname, referencename)
	String subjectname, sessionname, channelname, referencename

	pathinfo database_path
	if (!V_flag)
		abort "databasepath not specified"
	endif
	
	string database_pathstring = S_path
	string fullpathtowave, fullpathtoreference

	fullpathtowave = database_pathstring + subjectname + ":" + sessionname + ":data_records:" + channelname
	// does wave exist?
	getfilefolderinfo/Q/Z (fullpathtowave+".ibw")
	
	if (V_flag == -43)
		printf "wave not found: %s\r", fullpathtowave
		return ""
	endif

	loadwave/O/Q fullpathtowave
	print fullpathtowave
	WAVE theChannel = $(stringfromlist(0,S_wavenames))
	
	// if reference is not "", load reference		
	if (strlen(referencename) > 0)
		
		// first check if we have already loaded reference!  don't need to load it every time
		
		// is reference already present in the current data folder?
		if (waveexists($referencename))
		
			printf "reference %s already loaded.  reload not needed\r", referencename
			WAVE theReference = $referencename
		
		else
		
			fullpathtoreference = database_pathstring + subjectname+ ":" + sessionname + ":data_records:" + referencename	

			// check if the specified reference exists in file system
			getfilefolderinfo/Q/Z (fullpathtoreference+".ibw")

			if (V_flag == -43)
				printf "specified reference %s not found. trying AVG instead\r", fullpathtoreference
				fullpathtoreference = database_pathstring + subjectname + ":" + sessionname + ":data_records:" + "AVG"		
			else
				fullpathtoreference = database_pathstring + subjectname + ":" + sessionname + ":data_records:" + referencename
			endif			
			
			loadwave/O/Q fullpathtoreference
			WAVE theReference = $(stringfromlist(0,S_wavenames))
		
		endif
		
		// redimension and subtract		
		redimension/S theChannel
		theChannel -= theReference
		
		// next line prevents a lot of mistakes but means we waste time reloading it later
		killwaves theReference

	endif
	
	return nameofwave(theChannel)

end

Function LoadAndRereferenceFromDatabase2 (subjectname, sessionname, channelname, referencename)
	String subjectname, sessionname, channelname, referencename

	// need database base path
	// e.g. Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:
	SVAR database_basepathstring = root:neuromaven_resources:pathstrings:database_basepathstring
	String subject_pathstring = database_basepathstring + subjectname + ":"
	String recording_pathstring = database_basepathstring + subjectname + ":" + sessionname + ":"

	// generate paths to load data and headers for the channel, and check for existence of all 3 file paths and 3 files
	string data_records_pathstring = recording_pathstring + "data_records:" 
	newpath/O data_records, data_records_pathstring
	string fullpathtodatarecordswave = data_records_pathstring + channelname
	// does file exist?
	getfilefolderinfo/Q/Z (fullpathtodatarecordswave+".ibw")	
	if (V_flag == -43)
		printf "data records wave not found at %s\r", fullpathtodatarecordswave
		return 0
	endif
	
	string headers_records_pathstring = recording_pathstring + "headers_records:" 
	newpath/O headers_records, headers_records_pathstring
	string fullpathtoheadersrecordswave =  headers_records_pathstring + channelname
	// does file exist?
	getfilefolderinfo/Q/Z (fullpathtoheadersrecordswave+".ibw")	
	if (V_flag == -43)
		printf "headers records wave not found at %s\r", fullpathtoheadersrecordswave
		return 0
	endif
	
	string headers_file_pathstring = recording_pathstring + "headers_file:" 
	newpath/O headers_file, headers_file_pathstring
	string fullpathtoheadersfilewave = headers_file_pathstring + channelname
	// does file exist?
	getfilefolderinfo/Q/Z (fullpathtoheadersfilewave+".ibw")	
	if (V_flag == -43)
		printf "header file wave not found at %s\r", fullpathtoheadersfilewave
		return 0
	endif
			
	// set up data folders in the pxp	

	// make data folder for file headers
	if (!DataFolderExists("headers_file"))
		newdatafolder headers_file
	endif	
	// make data folder for record headers
	if (!DataFolderExists("headers_records"))
		newdatafolder headers_records
	endif
	// make data folder for data records
	if (!DataFolderExists("data_records"))
		newdatafolder data_records
	endif

	// bring in the channel and its file header and record headers  
	string filename = channelname + ".ibw"
	// load file header
	setdatafolder root:headers_file
	loadwave/O/P=headers_file filename
	WAVE theChannel_fileheader = $(stringfromlist(0,S_wavenames))

	// load record headers
	setdatafolder root:headers_records
	loadwave/O/P=headers_records filename
	WAVE theChannel_recordheaders = $(stringfromlist(0,S_wavenames))
	
	// load data records
	setdatafolder root:data_records
	loadwave/O/P=data_records filename
	
	WAVE theChannel = $channelname

	//loadwave/O/Q fullpathtowave
	//print fullpathtowave
	//WAVE theChannel = $(stringfromlist(0,S_wavenames))
	
	// if reference is not "", load reference		
	if (strlen(referencename) > 0)
		
		string fullpathtoreference
		
		// first check if we have already loaded reference!  don't need to load it every time
		
		// is reference already present in the current data folder?
		if (waveexists($referencename))
		
			printf "reference %s already loaded.  reload not needed\r", referencename
			WAVE theReference = $referencename
		
		else
		
			fullpathtoreference = database_basepathstring + subjectname+ ":" + sessionname + ":data_records:" + referencename	

			// check if the specified reference exists in file system
			getfilefolderinfo/Q/Z (fullpathtoreference+".ibw")

			if (V_flag == -43)
				printf "specified reference %s not found. trying AVG instead\r", fullpathtoreference
				fullpathtoreference = database_basepathstring + subjectname + ":" + sessionname + ":data_records:" + "AVG"		
			else
				fullpathtoreference = database_basepathstring + subjectname + ":" + sessionname + ":data_records:" + referencename
			endif			
			
			loadwave/O/Q fullpathtoreference
			WAVE theReference = $(stringfromlist(0,S_wavenames))
		
			// redimension and subtract		
			redimension/S theChannel
			theChannel -= theReference

			// next line prevents a lot of mistakes but means we waste time reloading it later
			killwaves theReference
		
		endif
	
	endif
	
	return 1 // for success

end


Function/S LoadRawChannelsfromDatabase(subjectname, sessionname, channelprefix, start, stop)
	string subjectname, sessionname, channelprefix
	variable start, stop

	variable i, successcount = 0
	string channelname
	string wavesloaded = ""
	for (i=start; i <= stop; i += 1)
		channelname = channelprefix + num2str(i)
		if (LoadRawChannelfromDatabase (subjectname, sessionname, channelname))
			successcount += 1
			wavesloaded += (channelname+";")
		endif

	endfor
	printf "successfully loaded %s\r", wavesloaded
	return wavesloaded
end


Function LoadRawChannelfromDatabase (subjectname, sessionname, channelname)
	String subjectname, sessionname, channelname

	SVAR database_basepathstring = root:database_basepathstring
	string fullpathtowave = database_basepathstring + subjectname +":"+sessionname+":data_records:"+channelname
	//print fullpathtowave
	loadwave/O fullpathtowave
	if (V_flag != 1)
		printf "failed to load %s\r", fullpathtowave
		return 0
	endif

	return 1
end

