#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function/S MakeNewConcatenatedSet (measurementvalue)
	string measurementvalue

	make/n=0/T/O subject, session, channel, reference
	make/n=0/O start, stop , $(measurementvalue + "_cat")
	WAVE measurement = $(measurementvalue + "_cat")

	return (measurementvalue + "_cat")

end



Function catfromdatabase_channels (subjectname, sessionname, channelstring, channelstringISlist, referencename, whichanalysis, makenewset)
	string subjectname, sessionname, channelstring, whichanalysis, referencename
	Variable channelstringISlist, makenewset

	string whichanalysis_catname

	if (makenewset)
		whichanalysis_catname = makenewconcatenatedSet (whichanalysis)
		WAVE analysis_cat = $whichanalysis_catname
	endif

	WAVE/T subject, session, channel, reference
	WAVE start, stop

	if (!channelstringISlist)

		// in this case channel string is a matchstring

		// need database base path
		// e.g. Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:
		SVAR database_basepathstring = root:database_basepathstring
		String recording_pathstring = database_basepathstring + subjectname + ":" + sessionname + ":"

		// this generates input paths
		string data_records_pathstring = recording_pathstring + "data_records:" 
		newpath/O data_records, data_records_pathstring
		
		string filenames = (indexedfile(data_records, -1,".ibw"))
		channelstring = sortlist (listmatch(filenames,"*"+channelstring+"*"),";", 16)

	endif	

	channelstring = replacestring(".ibw",channelstring,"")
	variable numchannels = itemsinlist(channelstring),i
	string channelname = ""
	string theNote
	variable pointstoadd, firstnewpoint, lastnewpoint, nextpoint, windowlength_ms
	
	for (i=0; i < numchannels; i += 1)
	
		channelname = stringfromlist(i, channelstring)
		
		// load the right measurement wave for this channel (running power for now)
		// shouldn't need anything but the waves themselves - can build up path here:
		
		string fullpathtomeasurementwave = database_basepathstring + subjectname+ ":" + sessionname + ":"+whichanalysis+"_"+referencename+":"+channelname

		// check if the specified reference exists in file system
		getfilefolderinfo/Q/Z (fullpathtomeasurementwave+".ibw")

		if (V_flag == -43)
			printf "specified wave %s not found.\r", fullpathtomeasurementwave
			abort
		endif		
		
		loadwave/O fullpathtomeasurementwave
		
		WAVE nextmeasurementwave = $(stringfromlist(0,S_wavenames))
	
		// next point of the concatenated wave
		nextpoint = (numpnts(analysis_cat) == 0) ? 0 : numpnts(analysis_cat)
	
		// how many points does newly loaded wave have?
		pointstoadd = numpnts(nextmeasurementwave)
		lastnewpoint = nextpoint+pointstoadd - 1
		
		// insert that many points into subject, session, channel, start, stop waves
		
		insertpoints nextpoint, pointstoadd, analysis_cat, subject, session, channel, reference, start, stop 

		// argh....I see the problem.  we have center points for running power wave segments but we can't know their duration without knowing either the window size or the % overlap
		// hard coding it to 500 for now
		// going to need code that finds that data.  or, actually, that data is going to need to be stored in the waves.
		// FIX THIS!  can add later too.  if I fix it in the code now, then any future running power waves will have it.  and all current waves have the same values so those can be defaults

		// if runningpower has a wavenote, read the windowlength out of it
		// if it doesn't, windowlength is 1 second.
		
		theNote = note(nextmeasurementwave)
		
		if (strlen(theNote) > 0)
			windowlength_ms = 1000*(str2num(StringByKey("WINDOWLENGTH_S", theNote)))
		else
			// handles earlier cases in which there was no wavenote and windowlength was always 1000 ms
			windowlength_ms = 1000
		endif
		print windowlength_ms
	
		subject[nextpoint,lastnewpoint] = subjectname
		session[nextpoint,lastnewpoint] = sessionname
		channel[nextpoint,lastnewpoint] = channelname
		reference[nextpoint,lastnewpoint] = referencename
		analysis_cat[nextpoint, lastnewpoint] = nextmeasurementwave[p-nextpoint]
		start[nextpoint,lastnewpoint] = (pnt2x(nextmeasurementwave,p-nextpoint) - windowlength_ms/2)
		stop[nextpoint,lastnewpoint] = (pnt2x(nextmeasurementwave,p-nextpoint) + windowlength_ms/2)
		
	endfor
	
	killwaves nextmeasurementwave

end

// get the 2 second of data referred to by row number in my big table
Function getsnoppet (row)
	variable row
	
	WAVE/T subject, session, channel, reference
	WAVE start, stop, runningpower_cat
	
	string subjectname = subject[row]
	string sessionname = session[row]
	string channelname = channel[row]
	string referencename = reference[row]
	variable starttime = start[row]
	variable stoptime = stop[row]
	
	// get the channel referred to here
	SVAR database_basepathstring = root:database_basepathstring

	string fullpathtowave = database_basepathstring + subjectname+ ":" + sessionname + ":data_records:"+channelname
	// check if the specified wave exists in file system
	getfilefolderinfo/Q/Z (fullpathtowave+".ibw")

	if (V_flag == -43)
		printf "specified wave %s not found.\r", fullpathtowave
		abort
	endif		

	// it exists, so load it
	loadwave/O fullpathtowave
	WAVE theChannel = $(stringfromlist(0,S_wavenames))

	
	// note gonna need to also get the header so wave can be converted to V
	// problem here: header and wave have same name
	string fullpathtoheader = database_basepathstring + subjectname+ ":" + sessionname + ":headers_file:"+channelname
	newdatafolder/s/o tmp_snoppet
	loadwave/O fullpathtoheader
	WAVE theHeader = $(stringfromlist(0,S_wavenames))
	// now we have the header
	variable ADBitVolts = ADBitVoltsFromCheetahHeader2(theHeader)
	setdatafolder ::

	// if reference not "RAW", load reference and re-reference
	if (!stringmatch(referencename, "RAW"))
	
		string fullpathtoreference = database_basepathstring + subjectname+ ":" + sessionname + ":data_records:" + referencename	

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
	
	endif
	
	// duplicate out the subrange
	duplicate/R=(starttime, stoptime) theChannel $( "snoppet_row" + num2str(row))

	// killwaves theChannel	
	killdatafolder tmp_snoppet
	
	
end