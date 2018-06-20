#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// process in database
// these functions create ibw wave outputs in the Igor database


// template for a processing function

//inputs: correct path to database, list of subjects to process
//
//plan:
//access correct basepath
//
//what inputs do we need?
//build paths needed
//load the things we need
//
//
//do processing
//
//
//
//save outputs 

// do all channels, all recordings, for list of subjects
// subjectstring is either e.g. "mouse6;mouse9;" or "" to indicate ALL
Function Process_Subjects (subjectstring, subjectstringISlist, referencename, channelliststring, whichanalysis, analysisparameters, keepinRAM, saveouttoDB)
	Variable subjectstringISlist
	string subjectstring, referencename, whichanalysis, channelliststring
	WAVE analysisparameters
	variable keepinRAM, saveouttoDB

	if (!subjectstringISlist)
		// in this case subject string is a matchstring
		
		// need database base path
		// e.g. Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:
		SVAR database_basepathstring = root:database_basepathstring

		newpath/O database_path, database_basepathstring
		
		string subjectnames = (indexeddir(database_path, -1,0))
		subjectstring = sortlist (listmatch(subjectnames,"*"+subjectstring+"*"),";", 16)
	
	endif

	variable numsubjects = itemsinlist(subjectstring), i
	string nextsubject

	for (i=0; i < numsubjects; i += 1)
	
		nextsubject = stringfromlist(i, subjectstring)
		// send "" as recordingstring to indicate ALL
		Process_Subject(nextsubject, "", channelliststring, referencename, whichanalysis, analysisparameters,keepinRAM,saveouttoDB)

	endfor
	
	// keep/save code path
	// nothing needed specific to this function.  process subject is instructed what to do.

end

Function Process_Subject(nextsubject, recordingstring, channelliststring, referencename, whichanalysis, analysisparameters,keepinRAM,saveouttoDB)
	string nextsubject, recordingstring, referencename, channelliststring, whichanalysis
	variable keepinRAM,saveouttoDB
	WAVE analysisparameters

	printf "Process_Subject called on %s\r", nextsubject

	// need database base path
	// e.g. Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:
	SVAR database_basepathstring = root:database_basepathstring
	
	variable i,numrecordings
	
	// if recording string is "" then we need a subject path to get a list of the sessions that are in it
	if (stringmatch("",recordingstring))
		
		String subject_pathstring = database_basepathstring + nextsubject + ":"
		Newpath/o subject_path, subject_pathstring		
		recordingstring = (indexeddir(subject_path, -1,0))

	endif
	
	numrecordings = itemsinlist(recordingstring)

	// make a grid
	// grid always gets filled, either with numbers or with error codes.
	// process_session always returns a wavereference to a strip when called by process_subject.
	make/O/N=(numrecordings, 16) $(nextsubject+"_"+whichanalysis)
	WAVE subjectresult = $(nextsubject+"_"+whichanalysis)
	subjectresult = 0
		
	for (i=0; i < numrecordings; i += 1)
	
		WAVE nextstrip = Process_Session(nextsubject, stringfromlist(i,recordingstring), channelliststring, referencename, whichanalysis, analysisparameters, keepinRAM,saveouttoDB)
		if (waveexists(nextstrip))
			subjectresult[i][] = nextstrip[q]
		else
			printf "error with session %s\r", stringfromlist(i,recordingstring)
		endif
		
		doupdate
		
	endfor
	
	if (saveouttoDB)
	
		// save out subject result to correct place in database (note - have never done this before)
		string output_pathstring = recordingstring + whichanalysis + referencename

	endif
	
	if (keepinRAM == 1)
		// change the name if we have to, to prevent overwrites from other subjects

	elseif (keepinRAM == 0)
		// delete subject result
	endif
end

// do all channels, all recordings, for list of subjects
// recording string is either a list of recording directories or "" to indicate all
// question - should process_sessions be more than one function since more than one kind of thing can get returned?
// return null wave reference if any problem
// pass "" to channelliststring to indicate ALL 
Function/WAVE Process_Session (subjectname, recordingstring, channelliststring, referencename, whichanalysis, analysisparameters, keepinRAM, saveouttoDB)
	string subjectname, recordingstring, referencename, whichanalysis, channelliststring
	Wave analysisparameters
	variable  keepinRAM, saveouttoDB

	printf "    Process_Session called on %s\r", recordingstring

	// need database base path
	// e.g. Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:
	SVAR database_basepathstring = root:neuromaven_resources:pathstrings:database_basepathstring
	String subject_pathstring = database_basepathstring + subjectname + ":"
	
	// if recording string is "" then we need a subject path to get a list of the sessions that are in it
	if (stringmatch("",recordingstring))
		
		Newpath/o subject_path, subject_pathstring		
		recordingstring = (indexeddir(subject_path, -1,0))

	endif
	
	variable i
	
	// this is hard-code needs to be fixed
	string channelmatchstring = "HI_NIP"

	string sessiondata_pathstring = database_basepathstring + subjectname + ":" + recordingstring + ":data_records:"
	// if channelliststring is "", find out how many channels in the session
	if (strlen(channelliststring) == 0)	
		newpath/o sessiondata_path, sessiondata_pathstring
		channelliststring = sortlist(replacestring(".ibw", listmatch(indexedfile(sessiondata_path,-1,".ibw"), channelmatchstring+"*"),""),";",16)
	endif
	
	// if analysis type is anything but 1, go through channels one by one
	variable numchannels = itemsinlist(channelliststring)
	
	// make the strip which will be the return value.  assume 16 channels for now BUT WILL NEED TO FIX THIS
	make/o/n=(numchannels) sessionOutput = 0
	
	if (AnalysisTakesSingleChannelInput(whichanalysis))
		
		for (i=0; i < numchannels; i += 1)

			string nextChannel = StringFromList(i, channelliststring)
			sessionOutput[i] = Process_Single_Channel (subjectname, recordingstring, nextChannel, referencename, whichanalysis, analysisparameters, keepinRAM)	

		endfor
	
	elseif (AnalysisTakesMultiChannelInput (whichanalysis))
		
		WAVE/T PMC_outputnames = Process_Multi_Channels (subjectname, recordingstring, channelliststring, referencename, whichanalysis, analysisparameters, keepinRAM)
		
		if (!waveexists(PMC_outputnames))
			printf "Process_Multi_Channels failed to do %s on subject %s recording %s\rsetting strip to 0\r", whichanalysis, subjectname, recordingstring
			sessionoutput = 0
			return sessionoutput	
		endif
		
		// sessionoutput is a list of the waves created as part of the session processing
		variable numoutputs = numpnts(PMC_outputnames),k

		// for each output
		for (k=0; k < numoutputs; k += 1)
			
			string nextoutputname = PMC_outputnames[k]
			WAVE nextoutput = $nextoutputname

			//  if saveouttoDB, save it out to the right database path
			if (saveouttoDB)
				string sessionoutput_pathstring = database_basepathstring + subjectname + ":" + recordingstring + ":"
				newpath/o sessionoutput_path, sessionoutput_pathstring
				Save/O/P=sessionoutput_path $nextoutputname as (nextoutputname+"_"+referencename)
			endif
				
			if (keepinRAM)
		
				//  rename outputs to be session-specific since they're sticking around. 
				string sessionID = replacestring("-",recordingstring,"")
				sessionID = sessionID[2,strlen(sessionID)-1]
				duplicate/o nextoutput $(nameofwave(nextoutput)+ sessionID)
			
			endif
	
			//  delete it.  at this point it's either duplicated or saved out
			killwaves nextoutput

		endfor
		
		// in this case sessionoutput should be set to all 1s to indicate "success"
		sessionoutput = 1
		
	endif
	
	// if whichanalysis was SD, in addition to returning the value normally, we will also build the special SD wave corresponding to the parameters settings
	//	and we will save it out into the file system and if keepinRAM == 0 we will kill the local copy
	// do this here:
	
	// return is an n-channel strip of numbers, or an n-channel strip of 1s indicating general "success" for the whole session
	return sessionOutput

end


// ("mouse6", "date-date", "HI_NIP1")
// whichanalysis: "runningpower","PSDgrand","SEdata"
// analysisparameters for each value of whichanalysis: see case blocks below
// deals with two kinds of operations
// 	creating and saving out a wave for each channel, in which case it returns a success/failure
//	computing a number for each channel, in which case it returns the number	
Function Process_Single_Channel (subjectname, sessionname, channelname, referencename, whichanalysis, analysisparameters, keepinRAM)
	string subjectname, sessionname, channelname, whichanalysis, referencename
	variable keepinRAM
	WAVE analysisparameters
	
	setdatafolder root:
	printf "		Process_single_channel called on %s\r", channelname

	// need database base path
	// e.g. Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:
	SVAR database_basepathstring = root:neuromaven_resources:pathstrings:database_basepathstring
	String subject_pathstring = database_basepathstring + subjectname + ":"
	String recording_pathstring = database_basepathstring + subjectname + ":" + sessionname + ":"

	if (!LoadAndRereferenceFromDatabase2 (subjectname, sessionname, channelname, referencename))
		abort "errored out on wave load"
	else
		// everything should be in place now
		WAVE theChannel_datarecords = $("root:data_records:"+channelname)
		WAVE theChannel_fileheader = $("root:headers_file:"+channelname)
		WAVE theChannel_recordheaders = $("root:headers_records:"+channelname)
	endif

	string resultname = ""
	variable numresultwaves = 0
	string output_pathstring = ""
	
	// next few lines are necessary for setting up output paths in the individual cases below
	string referencefoldersuffix
	if (strlen(referencename) == 0)
		referencefoldersuffix = "_RAW"
	else
		referencefoldersuffix =  ("_" + referencename)
	endif

	variable resultnumber = 0

	// create variables and run analysis according to whichanalysis
	strswitch (whichanalysis)

		// debug case *********************	
		case "debug":
			printf "this is not real analysis, just debugging\r"
			resultnumber = enoise(1)
			numresultwaves = 0
		break

		// these next cases are the ones that just compute a value *******************	
		case "AER": // analysis is type that returns a single number per channel		
			resultnumber = ComputeFromDatabaseChannels (subjectname, sessionname, channelname, referencename, 1, whichanalysis, analysisparameters)
			numresultwaves = 0
		break

		case "Vpp": // analysis is type that returns a single number per channel		
			resultnumber = ComputeFromDatabaseChannels (subjectname, sessionname, channelname, referencename, 1, whichanalysis, analysisparameters)
			numresultwaves = 0
		break

		case "power": // analysis is type that returns a single number per channel		
			resultnumber = ComputeFromDatabaseChannels (subjectname, sessionname, channelname, referencename, 1, whichanalysis, analysisparameters)
			numresultwaves = 0
		break

		case "SDsubject": // analysis is type that returns a single number per channel		
			resultnumber = ComputeFromDatabaseChannels (subjectname, sessionname, channelname, referencename, 1, whichanalysis, analysisparameters)
			numresultwaves = 0
		break

		// these next cases result in one wave output per channel *******************	
		case "runningpower":
		
			variable windowlength_s = analysisparameters[0]
			variable window_overlap_pct = analysisparameters[1]
			variable spikebandLOW = analysisparameters[2]
			variable spikebandHIGH = analysisparameters[3]
			printf "received request for %s with parameters %g, %g, %g, %g\r", whichanalysis, windowlength_s, window_overlap_pct, spikebandLOW, spikebandHIGH
			
			WAVE theResult = $(RunningPower (windowlength_s, window_overlap_pct, theChannel_datarecords, spikebandLOW, spikebandHIGH, channelname, 12000, "Welch",0))
			
			// rename theResult as channelname
			duplicate/o theResult $(channelname)
			resultname = channelname
			killwaves theResult
			
			numresultwaves = 1
			output_pathstring = recording_pathstring + whichanalysis + referencefoldersuffix

		break
		
		case "PSDgrand":
			
			variable highcut = analysisparameters[0]
			variable PSDsegmentpoints = analysisparameters[1]			
			string PSDwindowname
			if  (analysisparameters[2] == 0)
				PSDwindowname = "Welch"
			else
				PSDwindowname = ""
			endif
			variable PSDremoveDC = analysisparameters[3]
		
			WAVE theResult = $(makePSDonly(theChannel_datarecords, "_psd", ADbitvoltsfromcheetahheader2(theChannel_fileheader), highcut,PSDsegmentpoints, PSDwindowname, PSDremoveDC))
		
			// rename theResult as channelname
			duplicate/o theResult $(channelname)
			resultname = channelname
			killwaves theResult
			
			numresultwaves = 1
			output_pathstring = recording_pathstring + whichanalysis + referencefoldersuffix

		break
		
		// and this one results in a lot of wave outputs per channel *******************			
		case "SEdata":
		
			variable windowpoints = analysisparameters[0]
			variable alignpoint = analysisparameters[1]
			variable SDlevel = analysisparameters[2]
			variable spikefilter = analysisparameters[3]
			variable timestart_us = analysisparameters[4]
			variable timestop_us = analysisparameters[5]
			variable length_s = trunc((timestop_us-timestart_us)/1000000)
			
			// here is where we put the logic on whether we MakeSE from scratch or pareSE
			// here's what's tricky - the only existing versions of either of these functions assume that what they need is already in the local pxp
			//	in memory.  whatever they need will need to be loaded here.  if it's a "makeSE" situation (i.e. not being pared), we need all the data
			//	the original waves, need to rereference it, etc.  if it's a "paring" situation then we need the waves we're paring from.
			// BUT NOTE: we have actually already loaded and rereferenced the wave data before the case block here.
			//	need to add logic about whether that is actually needed.  isn't needed if we're paring SEdata (only case so far)
			
			// rereferencing has already been handled above
			
			// what are the assumptions about whether we're overwriting?
			// if whatever it is we're making already exists, then we're overwriting

			// build the string that identifies the base SE data we need for what's being requested
			string SEdata_base_pathstring = recording_pathstring + whichanalysis + referencefoldersuffix + "_" + num2str(SDlevel)+"SD_s00"
			string directorysavelist = ""
			string SEdirectory_s00_name = "SEdata_"+referencename+"_"+num2str(SDlevel)+"SD" +"_s00"

			// if SE waves are missing in database
			if (!allSEwavesPresent (SEdata_base_pathstring, channelname))
				
				// then run makeSEdata to generate the base
				// test this condition...
				// make_SE_data
				// 070816: current problem.  we are re-referencing on the fly above, but we can't assume that the matching blanked SDs for that reref have been created.
				//	but we don't know if we need them.
				//		need a new version of makeSEdata(_v4) which is smarter about this.  we tell it what the reference is and whether we want blanking or not.  it checks for existence of blanked SDs for that reference
				//			and creates them if they don't exist. stores them in database so they don't have to be redone again.
				MakeSEData_v3 (theChannel_datarecords, "CAR", theChannel_recordheaders, theChannel_fileheader, 32, 8,  SDlevel, "SD", 0, channelname, "test")

				// what are the outputs?  add them to the save list (with full path from root: of Igor data browser)
				// I am thinking that savedata with /D=1 and /P=$("path:path:") will get us what we want here.
				
				// this should create a "_s00" directory with the right type of name.  make sure it does, then add it to the list of stuff to be saved out
				// actually it doesn't create any directory because we are working one wave at a time here
				// but we should make the directory and move the waves into it.  we should do that below once the stuff has been loaded

				// add it to the output list
				directorysavelist += (SEdirectory_s00_name+";")
				
			else
				// otherwise, they are present in database, so we need to load them into memory
				// arguably if we are in this code path, then it was not necessary to have loaded the whole waves into memory above.  need to figure this out.
				
				// load SE data from database
				variable SEloadsuccess = LoadSEwaves (SEdata_base_pathstring, channelname)
				if (!SEloadsuccess)
					printf "problem loading SEdata for %s from %s\r", channelname, SEdata_base_pathstring
				endif
				
			endif
		
			// now we've got the SEdata waves one way or the other, and we are in the data_records directory

			// build name with SEdata naming convention
			string SEchannelprefix = channelname + referencefoldersuffix + "_" + num2str(SDlevel)+"SD"+"_s00"
			
			// make that directory if it doesn't already exist
			if (!DataFolderExists("::"+SEdirectory_s00_name))
				newdatafolder $("::"+SEdirectory_s00_name)
			endif
			
			// move the SEdata waves, just created or loaded, into it
			moveSEwaves (channelname, "::"+SEdirectory_s00_name+":")
					
			// now we have base SE data for this ref, this threshold, one way or the other
			// next question: does SEparameters require a new spike template?
			// this will be based on the "s00" data which has just been created or loaded
			if (spikefilter > 0)
				// this function is expecting SDs_RAW_4SDblank_3ms in data records folder, but it's not there
				// it needs an SD from the full waveform to set the postbaseline tolerance
				// see note above on makeSEdata_v3.  same thing is needed here.  rather than referencing SDs from the Igor experiment, function needs to check for them and load them from database.
				//	this one in particular should not assume the full waves are loaded.
				//   blargh.  this function was not written to know the mouse number or session number, since it assumes all that stuff is already in memory.
				//		_stage2 version needs to receive all of that so we know what to load
				filter_SEdata_inplace_stage2(recording_pathstring,(referencename+"_"+num2str(SDlevel)+"SD" +"_s00"),referencename+"_"+num2str(SDlevel)+"SD" +"_s"+num2Ncharstring(spikefilter,2),30000,0,25,20)

				// add to save list
				string SEdirectory_s0N_name = "SEdata_"+referencename+"_"+num2str(SDlevel)+"SD" +"_s"+num2Ncharstring(spikefilter,2)
				directorysavelist += (SEdirectory_s0N_name+";")

			endif
			// now we have _s0N, where n is whatever is in analysis slot 3
	
			// WORKS UP TO HERE	

			// next question: are we being asked for a time subinterval?
			//   which set to base this on: _s00 or _s01? my assumption has been that if I'm calling this function with s01 and a time interval, that I want the time interval applied to the s01.
			//	if I wanted the time interval applied to the s00 I could just run it again.
			String intervalsuffix = ""
			if (length_s > 0)
				intervalsuffix = "_" + limit_SEdata_inplace_stage2(SEdirectory_s0N_name, timestart_us,length_s)
				
				// add to save list
				directorysavelist += (SEdirectory_s0N_name+intervalsuffix+";")
			endif
			
			// here's the logic: build the string that identifies what call is asking for
			//output_pathstring = recording_pathstring + whichanalysis + referencefoldersuffix
			output_pathstring = subject_pathstring
			
			// outputpath is already "SEdata"+reference - now add strings for analysisparameters			
			//string outputpathSEsuffix = "_" + num2str(SDlevel)+"SD_s"+num2Ncharstring(spikefilter,2)+"_t"+ base64shortener(num2str(timestart_us))+"_"+num2Ncharstring(length_s,3)
			//output_pathstring += outputpathSEsuffix
			//print output_pathstring

			numresultwaves = itemsinlist(directorysavelist)

		break
		
	endswitch

	// create output path
	newpath/O/C outputpath, output_pathstring

	// save out	
	if (numresultwaves == 1)
		// save runningoutput to output path as xxxxxx.ibw
		Save/O/P=outputpath $(resultname)
	elseif (numresultwaves > 1)
		// borrow method from NCSload function
		setdatafolder root:
		newdatafolder output
		
		variable j
		string nextfolder
		for (j=0; j < numresultwaves; j+=1)
			nextfolder = StringFromList(j, directorysavelist)
			// for everything in savedirectory list, move to output
			movedatafolder $nextfolder, :output:
		endfor
		
		setdatafolder output
		// then do a savedata/D=1/O ("mix-in" mode with overwrite)
		savedata/D=1/O/P=outputpath/R sessionname
	endif
	
	setdatafolder root:
	
	// clean up
	setdatafolder root:
	killdatafolder/Z headers_file
	killdatafolder/Z headers_records
	killdatafolder/Z data_records

	if (!keepinRAM)
		killdatafolder/Z output
	endif
	
	// this is the case where we care about the number
	if (numresultwaves == 0)
		return resultnumber
	else
		return 1 // completed
	endif
	
end


//****************** merge everything down there with above function


//	
//			if (stringmatch(whichanalysis, "SD"))
//			
//				// make result wave
//				make/O/n=(numchannels, 2) theResult
//			
//				// for loop that calls computefromdatabasechannel, with new case for SD
//				for (j=0; j < numchannels; j += 1)
//
//					nextchannelname = stringfromlist(j, channellist)
//	
//					theResult[j][0] = ComputeFromDatabaseChannels (subjectname, nextsessionname, nextchannelname, referencename, 1, whichanalysis, analysisparameters)
//					theResult[j][1] = j+1
//					doupdate	
//
//				endfor
//
//				// determine output path
//				if (stringmatch(whichanalysis, "*SD*"))
//					// output path is SDs
//					String SD_pathstring = database_basepathstring + subjectname + ":" + nextsessionname + ":SDs:"
//					Newpath/o SD_path, SD_pathstring							
//				endif		
//		
//				// rename and save result
//				variable SDblank 			 = analysisparameters[0]	// blank yes=1, no=0
//				variable SDblank_eventsize  = analysisparameters[1]	// size of events to blank
//				variable SDblankwindow_ms = analysisparameters[2]	// window to blank in ms
//		
//				string blankstring, SDsuffix
//				if (SDblank)
//					blankstring = num2str(SDblank_eventsize)+"SDblank_" + num2str(SDblankwindow_ms) + "ms"
//				else
//					blankstring = "noblank"		
//				endif
//			
//				string referencestring = referencename
//				if (strlen(referencename) == 0)
//					referencestring = "RAW"
//				endif
//			
//				SDsuffix = "_"+referencestring+"_"+blankstring
//			
//				duplicate/o theResult $("SDs"+SDsuffix)
//				killwaves theResult
//			
//				Save/O/P=SD_path $("SDs"+SDsuffix)
//
//
//			endif
//
//
//		endfor
//		
//	endif
//	
//end

Function/wave Process_Multi_Channels (subjectname, recordingstring, channelliststring, referencename, whichanalysis, analysisparameters, keepinRAM)
	string channelliststring, whichanalysis, subjectname, recordingstring, referencename
	WAVE analysisparameters
	variable keepinRAM
	
	variable resultnumber = 0
	
	string output_pathstring, recording_pathstring, referencefoldersuffix
	
	// create variables and run analysis according to whichanalysis
	strswitch (whichanalysis)

		// debug case *********************	
		case "debug":
			printf "this is not real analysis, just debugging\r"
			resultnumber = enoise(1)
		break
		
		case "coherencematrix":
		
			// make variables from analysisparameters wave
			variable pointspersegment = analysisparameters[0]
			variable overlappoints = analysisparameters[1]
			string windowtype
			if  (analysisparameters[2] == 0)
				windowtype = "Hamming"
			else
				windowtype = ""
			endif
			variable minoutputresolution = analysisparameters[3]
			variable coherencebandstart = analysisparameters[4]
			variable coherencebandstop = analysisparameters[5]
		
			// going to need all waves here - assumes RAW for now
			string wavesloaded = LoadRawChannelsfromDatabase (subjectname, recordingstring, "HI_NIP",1,16)
			// then run this
			// this function returns mscoherence but also created a phase one
			variable success = MakeMagsqPhaseCoherenceMatrices ("HI_NIP", 16, pointspersegment, overlappoints, windowtype, minoutputresolution, coherencebandstart,coherencebandstop,0,0)
			WAVE mscoherencematrix, phaseshiftmatrix
			if (Exists("sessionoutput_names") == 1)
				killwaves $("sessionoutput_names")
			endif
			if (success)
				make/t/o sessionoutput_names = {"mscoherencematrix","phaseshiftmatrix"}
			endif
			
			// clean up! - delete loaded in waves
			killwavelist (wavesloaded)
			
		break
		
		case "newreference":
			printf "this is not real analysis, just debugging\r"
			resultnumber = enoise(1)
		break
	
	endswitch

	setdatafolder root:
	
	// clean up
	setdatafolder root:
	killdatafolder/Z headers_file
	killdatafolder/Z headers_records
	killdatafolder/Z data_records

	if (!keepinRAM)
		killdatafolder/Z output
	endif
	
	if (success)
		return sessionoutput_names
	else
		return $""
	endif
end