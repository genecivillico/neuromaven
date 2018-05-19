#pragma rtGlobals=1		// Use modern global access method.
#pragma rtGlobals=1		// Use modern global access method.

// which channels is a semicolon-separated list of channels to load in
// include reference channel in channels list
Function ComputeOnChannels (recordinglist, referencelist, whichchannels, whichanalysis)
	WAVE/t recordinglist, referencelist
	String whichchannels, whichanalysis

	setdatafolder root:

	// establish Neuralynx data path
	newpath/o rawpxp, "Macintosh HD:Users:nipadmin:Desktop:IGOR DATA"
	
	string referencechannel
	string channeltype
	if (stringmatch(whichchannels, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannels, "*LFP*"))
		channeltype = "LFP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i,j
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring
	
	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	//print pxplist
	
	String channelstoload
	
	for (i=0; i < numrecordings; i += 1)
		
		channelstoload = whichchannels
		
		// might be ""
		referencechannel = referencelist[i]
			
		// nextpxptoload
		nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"

		// test for existence of nextpxpname
		if (findlistitem(nextpxpname, pxplist) < 0)
			printf nextpxpname + " not found\r"
		endif
			
		loaddata/P=rawpxp/S="data_records"/O/J=channelstoload nextpxpname

		if (V_flag == 0)
			printf "could not find %s in %s!\r", channelstoload, nextpxpname
		else	
			// take the reference channel out
			string channelstoprocess = removefromlist(referencechannel, channelstoload)
			Variable numchannelstoprocess = itemsinlist(channelstoprocess)
			// inside the experiment loop, here is a channels loop
			for (j=0; j < numchannelstoprocess; j += 1)				
				
				WAVE theChannel = $(stringfromlist(j, channelstoprocess))
	
				// re-reference if a reference is specified
				if (strlen(referencechannel) > 0)

					WAVE theReference = $referencechannel				
					theChannel -= theReference
					
				endif
						
				strswitch(whichanalysis)
					
					case "crossingsbySD":
		
						WAVE theResult = $(crossingsbySD(theChannel,1, "SDcrossings"))
						//killwaves theResult, theChannel
						
						break
						
					// this is a test case for getting a value for each channel
					case "SD":
						// if this is our first channel
						if (j==0)
							make/O/n=(numchannelstoprocess) theResult
						endif
						
						// get the single value from our channel
						wavestats/q theChannel
						theResult[j] = V_sdev
						killwaves theChannel
						
					case "oneSDallChannels":
						// if this is our first channel
						if (j==0)
							make/O/n=(numchannelstoprocess) theResult
						endif
						
						// get the single value from our channel
						theResult[j] = crossingsSingleComputedSD(theChannel,1,3)
						killwaves theChannel					

				endswitch
			
			endfor
			
			//killwaves theReference
		
		endif
		
		if (i==0)						
			duplicate/o theResult $(whichanalysis+"_all")
			WAVE allResults = $(whichanalysis+"_all")					
		elseif (i == 1)						
			concatenate {theResult}, allResults						
			newimage/s=0 allResults
		else
			concatenate {theResult}, allResults						
		endif		
		
		doupdate
	endfor
		
	matrixtranspose allResults

end

// which channels is a semicolon-separated list of channels to load in
// code will add reference channel to channels list
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
Function ComputeOnChannels3 (recordinglist, mouseID, preprocess, referencelist, whichchannels, whichanalysis, outputprefix)
	WAVE/t recordinglist, referencelist
	String mouseID, preprocess, whichchannels, whichanalysis, outputprefix

	setdatafolder root:

	// establish Neuralynx data path
	newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	
	string referencechannelname
	string channeltype
	if (stringmatch(whichchannels, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannels, "*LFP*"))
		channeltype = "LFP"
	elseif (stringmatch(whichchannels, "*HI_NIP*"))
		channeltype = "HI_NIP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i,j
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	//print pxplist
	
	String channelstoload
	
	for (i=0; i < numrecordings; i += 1)
				
		// might be ""
		referencechannelname = referencelist[i]
		
		channelstoload = whichchannels + referencechannelname + ";"

		// nextpxptoload
		nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"
		
		// test for existence of nextpxpname
		if (findlistitem(nextpxpname, pxplist) < 0)
			printf nextpxpname + " not found\r"
		else
			printf "about to load data from %s ...\r", nextpxpname
		endif
		
		// are we re-referencing?  if so, load reference channel before loop
		if (strlen(referencechannelname) > 0)
			loaddata/Q/P=rawpxp/S="data_records"/O/J=referencechannelname nextpxpname
			WAVE theReference = $referencechannelname		
			if (!Waveexists(theReference))
				printf "uh-oh. %s not loaded from %s\r", nextchannelname, nextpxpname	


				printf "		loaded %s as reference\r", referencechannelname
			endif
			//remove reference channel from list if it's in there
			channelstoload = removefromlist(referencechannelname, channelstoload)
		endif	
		
		Variable numchannelstoprocess = itemsinlist(channelstoload)
		
		for (j=0; j < numchannelstoprocess; j += 1)
			
			nextchannelname = (stringfromlist(j, channelstoload))
				
			loaddata/Q/P=rawpxp/S="data_records"/O/J=nextchannelname nextpxpname
			WAVE theChannel = $nextchannelname
			if (Waveexists(theChannel))

				printf "		loaded %s\r", nextchannelname			
				// re-reference if a reference is specified
				if (strlen(referencechannelname) > 0)
					theChannel -= theReference					
				endif
							
				strswitch(whichanalysis)
						
					case "crossingsbySD":
			
						WAVE theResult = $(crossingsbySD(theChannel,1, "SDcrossings"))
						//killwaves theResult, theChannel
							
						break
							
					// this is a test case for getting a value for each channel
					case "SD":
						// if this is our first channel
						if (j==0)
							make/O/n=(numchannelstoprocess) theResult
						endif
							
						// get the single value from our channel
						wavestats/q theChannel
						theResult[j] = V_sdev
						killwaves theChannel
						
						break
							
					case "oneSDallChannels":
						// if this is our first channel
						if (j==0)
							make/O/n=(numchannelstoprocess) theResult
						endif
							
						// get the single value from our channel
						theResult[j] = crossingsSingleComputedSD(theChannel,1,4)
						killwaves theChannel							

						break

				endswitch
		
			else	
				printf "uh-oh. %s not loaded from %s\r", nextchannelname, nextpxpname	
				theResult[j] = NaN
			endif
			
		endfor
		
		//abort
			
		if (i==0)						
			duplicate/o theResult $(outputprefix+whichanalysis+"_all")
			WAVE allResults = $(outputprefix+whichanalysis+"_all")					
		elseif (i == 1)						
			concatenate {theResult}, allResults						
			display/w=(0,44,470,489)
			appendimage allResults
			SetAxis/A/R left
			modifygraph margin=-1
			if (!cmpstr(whichanalysis, "SD"))
				modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
			else
				modifyimage ''#0 ctab={*,50,YellowHot,0}
			endif
		else
			concatenate {theResult}, allResults						
		endif		
		
		doupdate
	endfor
		
	matrixtranspose allResults
	killwaves theResult
	killwaves/Z theReference

end

// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do
// whichanalysis: AER_allchan, analysis parameter specifies which SD level to use
Function ComputeOnChannels4 (recordinglist, mouseID, preprocess, referencelist, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist, referencelist
	String mouseID, preprocess, whichchannels, whichanalysis
	Variable analysisparameter

	setdatafolder root:

	// establish Neuralynx data path
	// newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)

	newpath/o rawpxp, ("NIPEPHYS:PREPROCESSED DATA:"+preprocess+":"+mouseID)

	pathinfo rawpxp
	
	printf "looking for data in %s\r", S_path
	
	string referencechannelname
	string channeltype
	if (stringmatch(whichchannels, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannels, "*LFP*"))
		channeltype = "LFP"
	elseif (stringmatch(whichchannels, "*HI_NIP*"))
		channeltype = "HI_NIP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i,j
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// initialize this in case it doesn't get used
	string analysisparameterstring = ""
	
	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	//print pxplist
	
	String channelstoload
	
	for (i=0; i < numrecordings; i += 1)
	//for (i=12; i <= 18; i += 1)
		// nextpxptoload
		nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"
		
		// test for existence of nextpxpname
		if (findlistitem(nextpxpname, pxplist) < 0)
			printf nextpxpname + " not found\r"
		else
			printf "about to load data from %s ...\r", nextpxpname
		endif

		// for efficiency, load reference channel once at the beginning
		// might be ""
		referencechannelname = referencelist[i]
		
		// get the reference channel if it's not null
		if (strlen(referencechannelname) > 0)
			loaddata/Q/P=rawpxp/S="data_records"/O/J=referencechannelname nextpxpname
			WAVE theReference = $referencechannelname		
			if (!Waveexists(theReference))
				printf "uh-oh. %s not loaded from %s\r", nextchannelname, nextpxpname	
			else
				printf "		loaded %s as reference\r", referencechannelname
			endif
		endif
		
		Variable numchannelstoprocess = itemsinlist(whichchannels)
		
		for (j=0; j < numchannelstoprocess; j += 1)
			
			nextchannelname = (stringfromlist(j, whichchannels))
			
			// don't repeat the load if the channel is the reference
			if (!stringmatch(nextchannelname,referencechannelname))
				loaddata/Q/P=rawpxp/S="data_records"/O/J=nextchannelname nextpxpname
			endif
		
			WAVE theChannel = $nextchannelname
			if (Waveexists(theChannel))

				printf "		loaded %s\r", nextchannelname			
				// re-reference if a reference is specified
				if (strlen(referencechannelname) > 0)
					theChannel -= theReference					
				endif
							
				strswitch(whichanalysis)
						
					case "AER_allSD":
			
						WAVE theResult = $(crossingsbySD(theChannel,1, "SDcrossings"))
						//killwaves theResult, theChannel
							
						break
							
					// this is a test case for getting a value for each channel
					case "SD":
						// if this is our first channel
						if (j==0)
							make/O/n=(numchannelstoprocess) theResult
						endif
							
						// get the single value from our channel
						wavestats/q theChannel
						theResult[j] = V_sdev
						killwaves theChannel
						
						break
							
					case "AER_allchan":
						// if this is our first channel
						if (j==0)
							make/O/n=(numchannelstoprocess) theResult
						endif
							
						// get the single value from our channel
						theResult[j] = crossingsSingleComputedSD(theChannel,1,analysisparameter)
						killwaves theChannel				
						
						analysisparameterstring = "SD"+num2str(analysisparameter)			

						break

				endswitch
		
			else	
				printf "uh-oh. %s not loaded from %s\r", nextchannelname, nextpxpname	
				theResult[j] = NaN
			endif
			
		endfor
		
		// abort
		
		// build the resultname here
		String resultname = (replacestring("ouse",mouseID,"") + "_r" + referencechannelname + "_" + whichanalysis + "_" + analysisparameterstring)
		
			
		if (i==0)						
			duplicate/o theResult $resultname
			WAVE allResults = $resultname				
		elseif (i == 1)						
			concatenate {theResult}, allResults						
			display/w=(0,44,470,489)
			appendimage allResults
			SetAxis/A/R left
			modifygraph margin=-1
			if (!cmpstr(whichanalysis, "SD"))
				modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
			else
				modifyimage ''#0 ctab={*,50,YellowHot,0}
			endif
		else
			concatenate {theResult}, allResults						
		endif		
		
		doupdate
	endfor
		
	matrixtranspose allResults
	killwaves theResult
	killwaves/Z theReference

end

// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do
// whichanalysis: AER_allchan, analysis parameter specifies which SD level to use
Function ComputeOnChannels5 (recordinglist, mouseID, preprocess, referencelist, updatelist, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist, referencelist
	WAVE updatelist
	String mouseID, preprocess, whichchannels, whichanalysis
	Variable analysisparameter

	//setdatafolder root:

	// establish Neuralynx data path
	
	newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("NIPEPHYS:PREPROCESSED DATA:"+preprocess+":"+mouseID)

	pathinfo rawpxp
	
	printf "looking for data in %s\r", S_path
	
	string referencechannelname
	string channeltype
	if (stringmatch(whichchannels, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannels, "*LFP*"))
		channeltype = "LFP"
	elseif (stringmatch(whichchannels, "*HI_NIP*"))
		channeltype = "HI_NIP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// build the resultname here
	String analysisparameterstring
	if (stringmatch(whichanalysis,"*SD*"))
		analysisparameterstring = "" + num2str(analysisparameter)
	else
		analysisparameterstring = "_SD"+num2str(analysisparameter)
	endif
	
	// if any reference is AVGm use AVGm as referencestring
	findvalue/TEXT=("AVGm") referencelist
	string referencestring
	if (V_value > 0)
		referencestring = "AVGm"
	else
		referencestring = referencelist[0]
	endif
	
	String resultname = (replacestring("ouse",mouseID,"") + "_r" + referencestring + "_" + whichanalysis + analysisparameterstring)
		
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))
	
		// size of dim1 depends on analysis type
		Variable dim1 = (!cmpstr(whichanalysis, "AER_allSD")) ? 9 : itemsinlist(whichchannels)	
		make/n=(numrecordings,dim1)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		if (!cmpstr(whichanalysis, "SD"))
			modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
		else
			modifyimage ''#0 ctab={*,50,YellowHot,0}
		endif
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	//print pxplist
	
	String channelstoload
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"
		
			// test for existence of nextpxpname
			if (findlistitem(nextpxpname, pxplist) < 0)
				printf nextpxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextpxpname
			endif		

			// for efficiency, load reference channel once at the beginning
			// might be ""
			referencechannelname = referencelist[i]
			
			// get the reference channel if it's not null
			if (strlen(referencechannelname) > 0)
				loaddata/Q/P=rawpxp/S="data_records"/O/J=referencechannelname nextpxpname
				WAVE theReference = $referencechannelname		
				if (V_flag < 1)
					// if we were looking for CAR, switch to AVG and try again
					if (stringmatch(referencechannelname, "CAR"))
						printf "CAR requested, but not found.  trying to load AVG instead.\r"
						referencechannelname = "AVG"
						loaddata/Q/P=rawpxp/S="data_records"/O/J=referencechannelname nextpxpname
						WAVE theReference = $referencechannelname		
						if (V_flag < 1)
							printf "uh-oh. %s not loaded from %s. must recompute for this date\r", referencechannelname, nextpxpname	
						endif
					else
						printf "uh-oh. %s not loaded from %s. must recompute for this date\r", referencechannelname, nextpxpname	
					endif
				else
					printf "		loaded %s as reference\r", referencechannelname
				endif
			endif
			
			// load SDs wave just in case I need it
			loaddata/Q/P=rawpxp/S="data_records"/O/J="SDs" nextpxpname
			WAVE SDs
			
			// split it for finding
			make/O/n=(DimSize(SDs, 0)) SDlist = SDs[p][0]
			make/O/n=(DimSize(SDs, 0)) channelnumberlist = SDs[p][1]
			
			Variable numchannelstoprocess = itemsinlist(whichchannels)
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = (stringfromlist(j, whichchannels))
				
					// don't repeat the load if the channel is the reference
				if (!stringmatch(nextchannelname,referencechannelname))
					loaddata/Q/P=rawpxp/S="data_records"/O/J=nextchannelname nextpxpname
				endif
			
				WAVE theChannel = $nextchannelname
				if (Waveexists(theChannel))		

					printf "		loaded %s\r", nextchannelname			
					// re-reference if a reference is specified
					if (strlen(referencechannelname) > 0)
					
						// if theChannel is an integer wave and theReference is not, 
						// redimension theChannel to single float here so that the subtraction will be accurate
						// from Igor help: waveIs16BitInteger = WaveType(wave) & 0x10
						if ((WaveType(theChannel) & 0x10) &&  !(WaveType(theReference) & 0x10))
							Redimension/S theChannel
							printf "redimensioned %s to float to match %s\r", nameofwave(thechannel), nameofwave(theReference)
						endif
					
						theChannel -= theReference					
					endif
					
					Variable ADBitVolts, channelisthereference, referenceisblanked = 0
					strswitch(whichanalysis)
							
						case "AER_allSD":
				
							WAVE theResult = $(crossingsbySD(theChannel,1, "SDcrossings"))
							//killwaves theResult, theChannel
								
							break
								
						// this is a test case for getting a value for each channel
						case "SD":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif

							// get the single value from our channel
							wavestats/q theChannel
							// because data values are stored as integers, need to load the conversion factor to get SD in V
							// do this in a temp folder because the file header has the same name as the data record
							newdatafolder/s temp
							loaddata/Q/P=rawpxp/S="headers_file"/O/J=nextchannelname nextpxpname
							WAVE/T fileheader = $nextchannelname
							FindValue/TEXT="FileVersion" fileheader
							if (V_value < 0)
								// header is 5.5.1 format	
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[14], "")) 
							else
								// if header is 5.6.0 format
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[15], "")) 
							endif
							setdatafolder ::
							killdatafolder temp
														
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						

							theResult[j] = (V_sdev * ADBitVolts)
							
							break
						
						case "SD_nospikes":						
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							// is it the reference?
							if (stringmatch(nextchannelname,referencechannelname))
								channelisthereference = 1
							else
								channelisthereference = 0
							endif
							
							// blank out spikes (if this is not the reference or if it is the reference and we haven't already blanked the reference)
							if (!channelisthereference || (channelisthereference && !referenceisblanked))

								blankoutcrossings_abovebelow(theChannel, analysisparameter,3)
								
								if (channelisthereference)
									referenceisblanked = 1
								endif
								
							endif
							wavestats/q theChannel
							// because data values are stored as integers, need to load the conversion factor to get SD in V
							// do this in a temp folder because the file header has the same name as the data record
							newdatafolder/s temp
							loaddata/Q/P=rawpxp/S="headers_file"/O/J=nextchannelname nextpxpname
							WAVE/T fileheader = $nextchannelname
							FindValue/TEXT="FileVersion" fileheader
							if (V_value < 0)
								// header is 5.5.1 format	
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[14], "")) 
							else
								// if header is 5.6.0 format
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[15], "")) 
							endif
							setdatafolder ::
							killdatafolder temp
														
							if (!channelisthereference)
								killwaves theChannel
							endif						

							theResult[j] = (V_sdev * ADBitVolts)
							print theResult[j]						
						
							break
								
						case "AER_allchan":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
								
							// get the single value from our channel
							theResult[j] = crossingsSingleComputedSD(theChannel,1,analysisparameter)
							
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						
							
							analysisparameterstring = "SD"+num2str(analysisparameter)								

							break
						
						case "AER_all_blnkSD":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							// reference subtraction is already done - need to "reblank" now.
							theSD = getblankedSD(theChannel, analysisparameter)
															
							// get the single value from our channel
							theResult[j] = crossingsSingleLevel(theChannel,1,theSD*analysisparameter)
							
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						
							
							analysisparameterstring = "SD"+num2str(analysisparameter)								
						
							break

					endswitch
		
				else	
					printf "uh-oh. %s not loaded from %s\r", nextchannelname, nextpxpname	
					theResult[j] = NaN
				endif
				
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killwaves/z channellist,SDlist,SDs
		
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end

// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do
// whichanalysis: AER_allchan, analysis parameter specifies which SD level to use
Function ComputeOnChannels_blut (recordinglist, mouseID, preprocess, referencelist, updatelist, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist, referencelist
	WAVE updatelist
	String mouseID, preprocess, whichchannels, whichanalysis
	Variable analysisparameter

	//setdatafolder root:

	// establish Neuralynx data path
	
	//newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	newpath/o rawpxp, ("NIPEPHYS:PREPROCESSED DATA:"+preprocess+":"+mouseID)

	pathinfo rawpxp
	
	printf "looking for data in %s\r", S_path
	
	string referencechannelname
	string channeltype
	if (stringmatch(whichchannels, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannels, "*LFP*"))
		channeltype = "LFP"
	elseif (stringmatch(whichchannels, "*HI_NIP*"))
		channeltype = "HI_NIP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// build the resultname here
	String analysisparameterstring
	if (stringmatch(whichanalysis,"*SD*"))
		analysisparameterstring = "" + num2str(analysisparameter)
	else
		analysisparameterstring = "_SD"+num2str(analysisparameter)
	endif
	
	string referencestring = "HI_NIP16"
	
	String resultname = (replacestring("ouse",mouseID,"") + "_r" + referencestring + "_" + whichanalysis + analysisparameterstring)
		
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))
	
		// size of dim1 depends on analysis type
		Variable dim1 = (!cmpstr(whichanalysis, "AER_allSD")) ? 9 : itemsinlist(whichchannels)	
		make/n=(numrecordings,dim1)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		if (!cmpstr(whichanalysis, "SD"))
			modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
		else
			modifyimage ''#0 ctab={*,50,YellowHot,0}
		endif
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	//print pxplist
	
	String channelstoload
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"
		
			// test for existence of nextpxpname
			if (findlistitem(nextpxpname, pxplist) < 0)
				printf nextpxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextpxpname
			endif		
			
			referencechannelname = "HI_NIP16"
			// load ingredients			
			loaddata/Q/P=rawpxp/S="data_records"/O/J=referencechannelname nextpxpname
			WAVE theReference = $referencechannelname		

			loaddata/Q/P=rawpxp/S="data_records"/O/J="CAR" nextpxpname
			
			// everything fine up to here
			
			if (!WaveExists(CAR))
				loaddata/Q/P=rawpxp/S="data_records"/O/J="AVG" nextpxpname
				WAVE AVG
				theReference += AVG				
			else
				WAVE CAR
				theReference += CAR
			endif
			
			if (V_flag == 1)
				printf "		loaded %s as reference\r", referencechannelname
			endif
			
			Variable numchannelstoprocess = itemsinlist(whichchannels)
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = (stringfromlist(j, whichchannels))
				
					// don't repeat the load if the channel is the reference
				if (!stringmatch(nextchannelname,referencechannelname))
					loaddata/Q/P=rawpxp/S="data_records"/O/J=nextchannelname nextpxpname
				endif
			
				WAVE theChannel = $nextchannelname
				if (Waveexists(theChannel))		

					printf "		loaded %s\r", nextchannelname											
					
					string oldreferencename = note(theChannel)
					oldreferencename = oldreferencename[1,strlen(oldreferencename)-1]
					WAVE oldreference = $oldreferencename
					
					if (cmpstr(nextchannelname, "HI_NIP16"))
						printf "re-adding old reference %s\r", oldreferencename
						theChannel += oldreference
						
						printf "subtracting new reference %s\r", referencechannelname
						theChannel -= theReference
					endif
					
					Variable ADBitVolts, channelisthereference, referenceisblanked = 0
					strswitch(whichanalysis)
							
						case "AER_allSD":
				
							WAVE theResult = $(crossingsbySD(theChannel,1, "SDcrossings"))
							//killwaves theResult, theChannel
								
							break
								
						// this is a test case for getting a value for each channel
						case "SD":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif

							// get the single value from our channel
							wavestats/q theChannel
							// because data values are stored as integers, need to load the conversion factor to get SD in V
							// do this in a temp folder because the file header has the same name as the data record
							newdatafolder/s temp
							loaddata/Q/P=rawpxp/S="headers_file"/O/J=nextchannelname nextpxpname
							WAVE/T fileheader = $nextchannelname
							FindValue/TEXT="FileVersion" fileheader
							if (V_value < 0)
								// header is 5.5.1 format	
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[14], "")) 
							else
								// if header is 5.6.0 format
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[15], "")) 
							endif
							setdatafolder ::
							killdatafolder temp
														
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						

							theResult[j] = (V_sdev * ADBitVolts)
							
							break
						
						case "SD_nospikes":						
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							// is it the reference?
							if (stringmatch(nextchannelname,referencechannelname))
								channelisthereference = 1
							else
								channelisthereference = 0
							endif
							
							// blank out spikes (if this is not the reference or if it is the reference and we haven't already blanked the reference)
							if (!channelisthereference || (channelisthereference && !referenceisblanked))

								blankoutcrossings_abovebelow(theChannel, analysisparameter,3)
								
								if (channelisthereference)
									referenceisblanked = 1
								endif
								
							endif
							wavestats/q theChannel
							// because data values are stored as integers, need to load the conversion factor to get SD in V
							// do this in a temp folder because the file header has the same name as the data record
							newdatafolder/s temp
							loaddata/Q/P=rawpxp/S="headers_file"/O/J=nextchannelname nextpxpname
							WAVE/T fileheader = $nextchannelname
							FindValue/TEXT="FileVersion" fileheader
							if (V_value < 0)
								// header is 5.5.1 format	
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[14], "")) 
							else
								// if header is 5.6.0 format
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[15], "")) 
							endif
							setdatafolder ::
							killdatafolder temp
														
							if (!channelisthereference)
								killwaves theChannel
							endif						

							theResult[j] = (V_sdev * ADBitVolts)
							print theResult[j]						
						
							break
								
						case "AER_allchan":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
								
							// get the single value from our channel
							theResult[j] = crossingsSingleComputedSD(theChannel,1,analysisparameter)
							
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						
							
							analysisparameterstring = "SD"+num2str(analysisparameter)								

							break
						
						case "AER_all_blnkSD":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							// reference subtraction is already done - need to "reblank" now.
							theSD = getblankedSD(theChannel, analysisparameter)
															
							// get the single value from our channel
							theResult[j] = crossingsSingleLevel(theChannel,1,theSD*analysisparameter)
							
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						
							
							analysisparameterstring = "SD"+num2str(analysisparameter)								
						
							break

					endswitch
		
				else	
					printf "uh-oh. %s not loaded from %s\r", nextchannelname, nextpxpname	
					theResult[j] = NaN
				endif
				
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killwaves/z channellist,SDlist,SDs, CAR, AVG
		
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end

// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do
// whichanalysis: AER_allchan, analysis parameter specifies which SD level to use
// v6: assumes structure of HI_pass files is as of mid-September 2012: rCAR or rAVG has already been done to each channel, and each data file contains 
//		SDs_presubtraction, SDs_postsubtraction3SD, SDs_postsubtraction4SD
// changes from v5: got rid of AVGm
Function ComputeOnChannels6 (recordinglist, mouseID, preprocess, updatelist, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist
	WAVE updatelist
	String mouseID, preprocess, whichchannels, whichanalysis
	Variable analysisparameter

	//setdatafolder root:

	// establish Neuralynx data path
	
	newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("NIPEPHYS:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	
	printf "this is computeonchannels6: channels loaded are assumed to have been re-referenced to CAR (or AVG if no channels excluded)\r"

	pathinfo rawpxp
	
	printf "looking for data in %s\r", S_path
	
	string referencechannelname
	string theWaveNote
	string channeltype
	if (stringmatch(whichchannels, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannels, "*LFP*"))
		channeltype = "LFP"
	elseif (stringmatch(whichchannels, "*HI_NIP*"))
		channeltype = "HI_NIP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// build the resultname here
	String analysisparameterstring
	if (stringmatch(whichanalysis,"*SD*"))
		analysisparameterstring = "" + num2str(analysisparameter)
	else
		analysisparameterstring = "_SD"+num2str(analysisparameter)
	endif
		
	String resultname = (replacestring("ouse",mouseID,"") + "_rCAR" + "_" + whichanalysis + analysisparameterstring)
		
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))
	
		// size of dim1 depends on analysis type
		Variable dim1 = (!cmpstr(whichanalysis, "AER_allSD")) ? 9 : itemsinlist(whichchannels)	
		make/n=(numrecordings,dim1)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		if (cmpstr(whichanalysis, "SD"))
			modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
		else
			modifyimage ''#0 ctab={*,50,YellowHot,0}
		endif
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	print pxplist
	
	String channelstoload, SDwavename
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"
		
			// test for existence of nextpxpname
			if (findlistitem(nextpxpname, pxplist) < 0)
				printf nextpxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextpxpname
			endif		
			
			Variable numchannelstoprocess = itemsinlist(whichchannels)
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = (stringfromlist(j, whichchannels))
				
				loaddata/Q/P=rawpxp/S="data_records"/O/J=nextchannelname nextpxpname
			
				WAVE theChannel = $nextchannelname
				if (Waveexists(theChannel))		

					printf "		loaded %s\r", nextchannelname			
					
					// test wavenote to make sure it has been referenced
					theWaveNote = note(theChannel)
					if (!stringmatch(theWaveNote,"rAVG") && !stringmatch(thewavenote,"rCAR"))
						printf "uh-oh.  channel %s from pxp %s does not contain rCAR or rAVG in wavenote.  may not have been referenced.\r", nextchannelname, nextpxpname
						abort
					endif
										
					Variable ADBitVolts, channelisthereference, referenceisblanked = 0
					strswitch(whichanalysis)
							
						case "AER_allSD":
				
							WAVE theResult = $(crossingsbySD(theChannel,1, "SDcrossings"))
							//killwaves theResult, theChannel
								
							break
								
						// this is a test case for getting a value for each channel
						case "SD":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif

							// get the single value from our channel
							wavestats/q theChannel
							// because data values are stored as integers, need to load the conversion factor to get SD in V
							// do this in a temp folder because the file header has the same name as the data record
							newdatafolder/s temp
							loaddata/Q/P=rawpxp/S="headers_file"/O/J=nextchannelname nextpxpname
							WAVE/T fileheader = $nextchannelname
							FindValue/TEXT="FileVersion" fileheader
							if (V_value < 0)
								// header is 5.5.1 format	
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[14], "")) 
							else
								// if header is 5.6.0 format
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[15], "")) 
							endif
							setdatafolder ::
							killdatafolder temp
														
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						

							theResult[j] = (V_sdev * ADBitVolts)
							
							break
						
						case "SD_nospikes":						
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							// is it the reference?
							if (stringmatch(nextchannelname,referencechannelname))
								channelisthereference = 1
							else
								channelisthereference = 0
							endif
							
							// blank out spikes (if this is not the reference or if it is the reference and we haven't already blanked the reference)
							if (!channelisthereference || (channelisthereference && !referenceisblanked))

								blankoutcrossings_abovebelow(theChannel, analysisparameter,3)
								
								if (channelisthereference)
									referenceisblanked = 1
								endif
								
							endif
							wavestats/q theChannel
							// because data values are stored as integers, need to load the conversion factor to get SD in V
							// do this in a temp folder because the file header has the same name as the data record
							newdatafolder/s temp
							loaddata/Q/P=rawpxp/S="headers_file"/O/J=nextchannelname nextpxpname
							WAVE/T fileheader = $nextchannelname
							FindValue/TEXT="FileVersion" fileheader
							if (V_value < 0)
								// header is 5.5.1 format	
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[14], "")) 
							else
								// if header is 5.6.0 format
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[15], "")) 
							endif
							setdatafolder ::
							killdatafolder temp
														
							if (!channelisthereference)
								killwaves theChannel
							endif						

							theResult[j] = (V_sdev * ADBitVolts)
							print theResult[j]						
						
							break
												// this is a test case for getting a value for each channel
						case "SD_postCAR":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif

							// get the single value from our channel
							wavestats/q theChannel
							// because data values are stored as integers, need to load the conversion factor to get SD in V
							// do this in a temp folder because the file header has the same name as the data record
							newdatafolder/s temp
							loaddata/Q/P=rawpxp/S="headers_file"/O/J=nextchannelname nextpxpname
							WAVE/T fileheader = $nextchannelname
							FindValue/TEXT="FileVersion" fileheader
							if (V_value < 0)
								// header is 5.5.1 format	
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[14], "")) 
							else
								// if header is 5.6.0 format
								ADBitVolts =  str2num (ReplaceString("-ADBitVolts",fileheader[15], "")) 
							endif
							setdatafolder ::
							killdatafolder temp
														
							killwaves theChannel

							theResult[j] = (V_sdev * ADBitVolts)
							
							break
								
						case "AER_allchan":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
								
							// get the single value from our channel
							theResult[j] = crossingsSingleComputedSD(theChannel,1,analysisparameter)
							
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						
							
							analysisparameterstring = "SD"+num2str(analysisparameter)								

							break
						
						case "AER_all_blnkSD":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							// reference subtraction is already done - need to "reblank" now.
							theSD = getblankedSD(theChannel, analysisparameter)
															
							// get the single value from our channel
							theResult[j] = crossingsSingleLevel(theChannel,1,theSD*analysisparameter)
							
							if (!stringmatch(nextchannelname,referencechannelname))
								killwaves theChannel
							endif						
							
							analysisparameterstring = "SD"+num2str(analysisparameter)								
						
							break
							
						case "AER_postCAR":
							// if this is our first channel
							if (j==0)
								// make the destination wave
								make/O/n=(numchannelstoprocess) theResult
								
								// get the SD wave we need
								SDwavename = ("SDs_postsub_"+num2str(analysisparameter)+"SDblank")
								loaddata/Q/P=rawpxp/S="data_records"/O/J=(SDwavename) nextpxpname
								WAVE SDs = $SDwavename
							
								// split for lookup
								make/O/n=(DimSize(SDs, 0)) SDlist = SDs[p][0]
								make/O/n=(DimSize(SDs, 0)) channelnumberlist = SDs[p][1]
							
							endif
							
							// lookup SD for this channel
							FindValue/T=0.1/V=(str2num(replacestring("HI_NIP",nextchannelname,""))) channelnumberlist
							Variable SD_thischannel = SDlist[V_Value]
								
							// get the single value from our channel
							theResult[j] = crossingsSingleLevel(theChannel,1,analysisparameter*SD_thischannel)
							
							killwaves theChannel
							
							analysisparameterstring = "SD"+num2str(analysisparameter)								

							break
							
					endswitch
		
				else	
					printf "uh-oh. %s not loaded from %s\r", nextchannelname, nextpxpname	
					theResult[j] = NaN
				endif
				
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killwaves/z channellist,SDlist,SDs
		
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end

// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do
// whichanalysis: powerband, powerbandratio
// analysisparameter is an index into parameter waves
// v6: assumes structure of HI_pass files is as of mid-September 2012: rCAR or rAVG has already been done to each channel, and each data file contains 
//		SDs_presubtraction, SDs_postsubtraction3SD, SDs_postsubtraction4SD
// changes from v5: got rid of AVGm
Function ComputeOnPSDs (recordinglist, mouseID, preprocess, updatelist, whichchannels, reref, whichanalysis, analysisparameter)
	WAVE/t recordinglist
	WAVE updatelist
	String mouseID, preprocess, whichchannels, whichanalysis
	Variable analysisparameter, reref

	//setdatafolder root:

	// establish Neuralynx data path
	
	// newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	newpath/o rawpxp, ("NIPEPHYS:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	
	printf "this is computeonPSDs: channels loaded are assumed to have been re-referenced to CAR (or AVG if no channels excluded)\r"

	pathinfo rawpxp
	
	printf "looking for data in %s\r", S_path
	
	// link in parameter waves at root level
	WAVE maxpower = root:maxpower
	WAVE minpower = root:minpower

	WAVE spikebandLOW = root:spikebandLOW
	WAVE spikebandHIGH = root:spikebandHIGH
	WAVE fakespikebandLOW = root:fakespikebandLOW
	WAVE fakespikebandHIGH = root:fakespikebandHIGH
	WAVE noisebandLOW = root:noisebandLOW
	WAVE noisebandHIGH = root:noisebandHIGH
	WAVE spikebandLOW = root:spikebandLOW
	WAVE falsespikepowercutoff = ROOT:falsespikepowercutoff
	
	
	string referencechannelname
	string theWaveNote
	string channeltype
	if (stringmatch(whichchannels, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannels, "*LFP*"))
		channeltype = "LFP"
	elseif (stringmatch(whichchannels, "*HI_NIP*"))
		channeltype = "HI_NIP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname, nextPSDname

	string rerefstring = ""	
	if (reref)
		rerefstring = "_reref"
	endif
	
	// build the resultname here
	String analysisparameterstring
	analysisparameterstring = num2str(analysisparameter)
		
	String resultname = (replacestring("ouse",mouseID,"") + rerefstring + "_" + whichanalysis + analysisparameterstring)
		
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))
		// size of dim1 depends on analysis type
		Variable dim1 = itemsinlist(whichchannels)	
		make/n=(numrecordings,dim1)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		
		strswitch(whichanalysis)
		
			case "exclude":
			
				ModifyImage ''#0 explicit=1,eval={-3,26205,52428,1},eval={-2,16385,65535,65535},eval={-1,0,0,65535}
			
			break
				
		endswitch
		// change this
		// modifyimage ''#0 ctab={*,50,YellowHot,0}
		
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	print pxplist
	
	String channelstoload
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"
		
			// test for existence of nextpxpname
			if (findlistitem(nextpxpname, pxplist) < 0)
				printf nextpxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextpxpname
			endif		
			
			Variable numchannelstoprocess = itemsinlist(whichchannels)		
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = (stringfromlist(j, whichchannels))
				// turn the channelname into a PSD name
				nextPSDname = nextchannelname + "_psd" + rerefstring				
					
				loaddata/Q/P=rawpxp/S="data_records"/O/J=nextPSDname nextpxpname
			
				WAVE thePSD = $nextPSDname
				if (Waveexists(thePSD))		

					printf "		loaded %s\r", nextPSDname			
										
					strswitch(whichanalysis)
							
						case "powerband":
							// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							// get the single value from our channel
							theResult[j] = sum(thePSD, spikebandLOW[analysisparameter],  spikebandHIGH[analysisparameter])
							
							killwaves thePSD

							break
						
						// powerratio
						//	sets -1 if spikepower is too high
						//	sets -2 if falsepower ratio is too low 
						//	otherwise computes spikepower/noisepower
						
						case "powerratio":
													// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
						
							Variable spikepower, falsespikepower, spiketofalsepowerratio, noisepower, noisepowerratio,falsespikepowercutoffLEVEL
						
							spikepower = sum(thePSD,spikebandLOW[analysisparameter], spikebandHIGH[analysisparameter])
							falsespikepower = sum(thePSD, fakespikebandLOW[analysisparameter], fakespikebandHIGH[analysisparameter])
							spiketofalsepowerratio = spikepower/falsespikepower
							noisepower = sum(thePSD, noisebandLOW[analysisparameter], noisebandHIGH[analysisparameter])
							noisepowerratio = spikepower/noisepower
							
							if (spikepower > maxpower[analysisparameter])
								theresult[j] = -1
							elseif (spiketofalsepowerratio  < 1)
								theresult[j] = -2
							else
								theresult[j] = noisepowerratio
							endif
							
							break
												
						case "falsespikeratio":
													// if this is our first channel
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
						
						
							spikepower = sum(thePSD,spikebandLOW[analysisparameter], spikebandHIGH[analysisparameter])
							falsespikepower = sum(thePSD, fakespikebandLOW[analysisparameter], fakespikebandHIGH[analysisparameter])
							spiketofalsepowerratio = spikepower/falsespikepower
							noisepower = sum(thePSD, noisebandLOW[analysisparameter], noisebandHIGH[analysisparameter])
							noisepowerratio = spikepower/noisepower
							falsespikepowercutoffLEVEL = falsespikepowercutoff[analysisparameter]

							
							if (spikepower > falsespikepowercutoffLEVEL)
								theresult[j] = spiketofalsepowerratio
							else
								theresult[j] = NaN
							endif
							
													
							break

						case "exclude":	
							
							if (j==0)
								make/O/n=(numchannelstoprocess) theResult
							endif
							
							spikepower = sum(thePSD,spikebandLOW[analysisparameter], spikebandHIGH[analysisparameter])
							falsespikepower = sum(thePSD, fakespikebandLOW[analysisparameter], fakespikebandHIGH[analysisparameter])
							spiketofalsepowerratio = spikepower/falsespikepower
							noisepower = sum(thePSD, noisebandLOW[analysisparameter], noisebandHIGH[analysisparameter])
							noisepowerratio = spikepower/noisepower
							falsespikepowercutoffLEVEL = falsespikepowercutoff[analysisparameter]
							
							//printf "spikepower = %.10f\rfalsespikepower = %.10f\r\r", spikepower, falsespikepower
							
							if (spikepower > maxpower[analysisparameter]) 
								theresult[j] = -1
							elseif (spikepower < minpower[analysisparameter])
								theresult[j] = -2
							elseif ((spikepower > falsespikepowercutoffLEVEL) && (spiketofalsepowerratio  < 1.6))
								theresult[j] = -3
							else
								theresult[j] = 0
							endif
						
							break
						
						endswitch
											
				else	
					printf "uh-oh. %s not loaded from %s\r", nextPSDname, nextpxpname	
					theResult[j] = NaN
				endif
				
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killwaves/z channellist,SDlist,SDs
		
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end


// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do
// whichanalysis: AER_allchan, analysis parameter specifies which SD level to use

// this is derived from computeonchannels6
// works with SEdata.pxp files.  they have spike counts.
// should move a lot faster than I'm used to!
// argh/  going to need parallel paths for everything
Function ComputeOnSnippets1 (recordinglist, mouseID, updatelist, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist
	WAVE updatelist
	String mouseID, whichchannels, whichanalysis
	Variable analysisparameter

	//setdatafolder root:

	// establish Neuralynx data path
	
	//newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	
	newpath/o HIpasspxp, ("NIPEPHYS:PREPROCESSED DATA:HIpass:"+mouseID)	
	newpath/o SEdatapxp, ("NIPEPHYS:PREPROCESSED DATA:SEdata postCAR:"+mouseID)	

	
	pathinfo SEdatapxp

	String SEpxpsuffix = "_rCAR_SD4SEdata.pxp"
	String HIpasspxpsuffix = "_HI_NIP.pxp"
	
	printf "looking for data in %s\r", S_path
	
	string theWaveNote

	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// build the resultname here
	String analysisparameterstring
	if (stringmatch(whichanalysis,"*SD*"))
		analysisparameterstring = "" + num2str(analysisparameter) +"_sn"
	else
		analysisparameterstring = "_SD"+num2str(analysisparameter) +"_sn"
	endif
		
	String resultname = (replacestring("ouse",mouseID,"") + "_rCAR" + "_" + whichanalysis + analysisparameterstring)
		
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))	
		// size of dim1 depends on analysis type
		Variable dim1 = (!cmpstr(whichanalysis, "AER_allSD")) ? 9 : itemsinlist(whichchannels)	
		make/n=(numrecordings,dim1)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		if (!cmpstr(whichanalysis, "SD"))
			modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
		else
			modifyimage ''#0 ctab={*,50,YellowHot,0}
		endif
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder
	String SEpxplist = IndexedFile(SEdatapxp, -1, ".pxp"), nextSEpxpname
	print SEpxplist
	
	String HIpasspxplist = IndexedFile(HIpasspxp, -1, ".pxp"),nextHIpasspxpname
	print HIpasspxplist

	String channelstoload, SDwavename
	Variable recordingtime_secs, theCount
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextSEpxpname = recordinglist[i] + SEpxpsuffix
			nextHIpasspxpname = recordinglist[i] + HIpasspxpsuffix
		
			// test for existence of nextpxpnames
			if (findlistitem(nextSEpxpname, SEpxplist) < 0)
				printf nextSEpxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextSEpxpname
			endif

			// test for existence of nextpxpname
			if (findlistitem(nextHIpasspxpname, HIpasspxplist) < 0)
				printf nextHIpasspxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextHIpasspxpname
			endif
			
			// load one channel to get length
			// previously I had loaded the record headers and just multiplied the number of headers by 512 data points, but that won't work
			//	because of occasional manual deletions in the early recordings.
			// loaddata/q/p=HIpasspxp/S="headers_records"/O/J="HI_NIP1" nextHIpasspxpname
			// recordingtime_secs = (dimsize(HI_NIP1,1)*512*0.03125/1000)

			loaddata/q/p=HIpasspxp/S="data_records"/O/J="HI_NIP1" nextHIpasspxpname
			recordingtime_secs = numpnts(HI_NIP1)*dimdelta(HI_NIP1,0)/1000
			
			// load the whole SEdata folder up here (it's small!)
			loaddata/Q/P=SEdatapxp/O/R nextSEpxpname
			

			Variable numchannelstoprocess = itemsinlist(whichchannels)
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = (stringfromlist(j, whichchannels))
			
				WAVE theSEheadrec = $(":SEdata:" + nextchannelname + "_rCAR_SD4_SEheadrec")
				WAVE theSEheadfile = $(":SEdata:" + nextchannelname + "_rCAR_SD4_SEheadfile")

				if (Waveexists(theSEheadrec))		
															
					Variable ADBitVolts, channelisthereference, referenceisblanked = 0
					strswitch(whichanalysis)
							
						case "AER_SEdata":
							// if this is our first channel
							if (j==0)
								// make the destination wave
								make/O/n=(numchannelstoprocess) theResult
							endif
								
							// get the single value from our channel
							
							// already got time up there above
							
							// get count.  (count is the number of spike records, so the size in dim1 of SEheadrec)
							theCount = dimsize(theSEheadrec,1)
							
							theResult[j] = (theCount/recordingtime_secs)
								
							analysisparameterstring = "SD"+num2str(analysisparameter)								

							break
							
					endswitch
		
				else	
					printf "uh-oh. %s not loaded from %s\r", nameofwave(theSEheadrec), nextSEpxpname	
					theResult[j] = NaN
				endif
				
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killdatafolder SEdata
			killwaves HI_NIP1
		
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end

// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do
// whichanalysis: AER_allchan, analysis parameter specifies which SD level to use

// this is derived from computeonchannels6
// works with SEdata.pxp files.  they have spike counts.
// should move a lot faster than I'm used to!
// argh, going to need parallel paths for everything
Function ComputeOnSnippets2 (recordinglist, mouseID, updatelist, whichSEfolder, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist
	WAVE updatelist
	String mouseID, whichchannels, whichanalysis, whichSEfolder
	Variable analysisparameter

	//setdatafolder root:

	// establish Neuralynx data path
	
	//newpath/o rawpxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	//newpath/o rawpxp, ("N-drive:PREPROCESSED DATA:"+preprocess+":"+mouseID)
	
	 newpath/o HIpasspxp, ("NIPEPHYS:PREPROCESSED DATA:HIpass:"+mouseID)	
	 newpath/o SEdatapxp, ("NIPEPHYS:PREPROCESSED DATA:SEdata postCAR:"+mouseID)
	
	//newpath/o HIpasspxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:HIpass:"+mouseID)	
	//newpath/o SEdatapxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:SEdata postCAR:"+mouseID)	

	//newpath/o HIpasspxp, ("NIPEPHYS II:PREPROCESSED DATA:HIpass:"+mouseID)	
	//newpath/o SEdatapxp, ("NIPEPHYS II:PREPROCESSED DATA:SEdata postCAR:"+mouseID)
	
	pathinfo SEdatapxp

	String SEpxpsuffix = "_rCAR_SD4SEdata.pxp"
	String HIpasspxpsuffix = "_HI_NIP.pxp"
	
	printf "looking for data in %s\r", S_path
	
	string theWaveNote

	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// build the resultname here
	String analysisparameterstring
	if (stringmatch(whichanalysis,"*SD*"))
		analysisparameterstring = "" + replacestring(".",num2str(analysisparameter),"p")
	else
		analysisparameterstring = "_SD"+replacestring(".",num2str(analysisparameter),"p")
	endif
		
	String resultname = (replacestring("ouse",mouseID,"") + "_rCAR" + "_" + whichanalysis + analysisparameterstring)
		
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))	
		// size of dim1 depends on analysis type
		Variable dim1 = (!cmpstr(whichanalysis, "AER_allSD")) ? 9 : itemsinlist(whichchannels)	
		make/n=(numrecordings,dim1)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		if (!cmpstr(whichanalysis, "SD"))
			modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
		elseif (stringmatch(whichanalysis,"*AER*"))
			modifyimage ''#0 ctab= {0,50,YellowHot,0}
		elseif  (stringmatch(whichanalysis, "*pctile*"))
			ModifyImage ''#0 ctab= {0,0.000225,Blue,0}
		endif
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder
	String SEpxplist = IndexedFile(SEdatapxp, -1, ".pxp"), nextSEpxpname
	print SEpxplist
	
	String HIpasspxplist = IndexedFile(HIpasspxp, -1, ".pxp"),nextHIpasspxpname
	print HIpasspxplist

	String channelstoload, SDwavename
	Variable recordingtime_secs, theCount
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextSEpxpname = recordinglist[i] + SEpxpsuffix
			nextHIpasspxpname = recordinglist[i] + HIpasspxpsuffix
		
			// test for existence of nextpxpnames
			if (findlistitem(nextSEpxpname, SEpxplist) < 0)
				printf nextSEpxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextSEpxpname
			endif

			// test for existence of nextpxpname
			if (findlistitem(nextHIpasspxpname, HIpasspxplist) < 0)
				printf nextHIpasspxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextHIpasspxpname
			endif
			
			// load one channel to get length
			// previously I had loaded the record headers and just multiplied the number of headers by 512 data points, but that won't work
			//	because of occasional manual deletions in the early recordings.
			// loaddata/q/p=HIpasspxp/S="headers_records"/O/J="HI_NIP1" nextHIpasspxpname
			// recordingtime_secs = (dimsize(HI_NIP1,1)*512*0.03125/1000)

			loaddata/q/p=HIpasspxp/S="data_records"/O/J="HI_NIP1" nextHIpasspxpname
			recordingtime_secs = numpnts(HI_NIP1)*dimdelta(HI_NIP1,0)/1000
			
			// load the whole SEdata folder up here (it's small!)
			loaddata/Q/P=SEdatapxp/O/S=(whichSEfolder)/T=$whichSEfolder nextSEpxpname

			Variable numchannelstoprocess = itemsinlist(whichchannels)
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = (stringfromlist(j, whichchannels))
				
				// reference the stuff we might need
				WAVE theSEheadrec = $(":"+whichSEfolder+":" + nextchannelname + "_rCAR_SD4_SEheadrec")
				WAVE/T theSEheadfile = $(":"+whichSEfolder+":" + nextchannelname + "_rCAR_SD4_SEheadfile")
				WAVE firstpeaks = $(":"+whichSEfolder+":" + nextchannelname + "_rCAR_SD4_segpeak1")
				WAVE peaktopeaks = $(":"+whichSEfolder+":" + nextchannelname + "_rCAR_SD4_segVpp")
				

				if (Waveexists(theSEheadrec))		
															
					Variable ADBitVolts, channelisthereference, referenceisblanked = 0
					ADBitVolts = ADBitVoltsFromCheetahheader2(theSEheadfile)

					strswitch(whichanalysis)
							
						case "AER_SE_count":
							// if this is our first channel
							if (j==0)
								// make the destination wave
								make/O/n=(numchannelstoprocess) theResult
							endif
								
							// get the single value from our channel
							
							// already got time up there above
							
							// get count.  (count is the number of spike records, so the size in dim1 of SEheadrec)
							theCount = dimsize(theSEheadrec,1)
							
							theResult[j] = (theCount)/recordingtime_secs
								
							analysisparameterstring = "SD"+num2str(analysisparameter)								

							break
							
						case "SEpctile":
						
							// if this is our first channel
							if (j==0)
								// make the destination wave
								make/O/n=(numchannelstoprocess) theResult
							endif
								
							// old code to do median or quartile using StatsQuantiles
							// convert firstpeaks and peaktopeaks into Volts
							// firstpeaks *= ADBitVolts
							//peaktopeaks *= ADBitVolts
							//StatsQuantiles/Q peaktopeaks
							//theResult[j] = V_Median
							//theResult[j] = V_Q25
							//analysisparameterstring = "median"
							
							// new code to get any arbitrary %tile
							theResult[j] = (pctile(peaktopeaks,1,analysisparameter))*ADBitVolts						
							
							break
							
					endswitch
		
				else	
					printf "uh-oh. %s not loaded from %s\r", nextchannelname + " SEheadrec", nextSEpxpname	
					theResult[j] = NaN
				endif
				
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killdatafolder $whichSEfolder
			killwaves/Z HI_NIP1
		
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end

// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do

// this is derived from computeonsnippets2
// works with SD waves found in HIpass.pxp files.
// should move a lot faster than I'm used to!

// SDwavechoices are SDs_postsub_3SDblank, SDs_postsub_4SDblank, SDs_postsub_noblank, SDs_raw

Function ComputeOnSDs (recordinglist, mouseID, updatelist, whichSDtype, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist
	WAVE updatelist
	String mouseID, whichSDtype,whichchannels, whichanalysis
	Variable analysisparameter

	//setdatafolder root:

	// establish Neuralynx data path
	
	 newpath/o HIpasspxp, ("NIPEPHYS:PREPROCESSED DATA:HIpass:"+mouseID)	

	// newpath/o HIpasspxp, ("NIPEPHYS II:PREPROCESSED DATA:HIpass:"+mouseID)	

	//newpath/o HIpasspxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:HIpass:"+mouseID)	
	pathinfo HIpasspxp
	
	String HIpasspxpsuffix = "_HI_NIP.pxp"
	
	printf "looking for data in %s\r", S_path
	
	string theWaveNote

	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	variable numchannelstoprocess = itemsinlist(whichchannels)
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// build the resultname herez
	String analysisparameterstring = whichSDtype
	String resultname = (replacestring("ouse",mouseID,"") + "_"+whichSDtype)
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))	
		make/n=(numrecordings,numchannelstoprocess)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder	
	String HIpasspxplist = IndexedFile(HIpasspxp, -1, ".pxp"),nextHIpasspxpname
	print HIpasspxplist

	String channelstoload, SDwavename
	Variable nextchannelnumber, ADbitvolts
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextHIpasspxpname = recordinglist[i] + HIpasspxpsuffix

			// test for existence of nextpxpname
			if (findlistitem(nextHIpasspxpname, HIpasspxplist) < 0)
				printf nextHIpasspxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextHIpasspxpname
			endif
			
			// load the appropriate SD wave
			loaddata/q/p=HIpasspxp/S="data_records"/O/J=(whichSDtype) nextHIpasspxpname
			WAVE theSDs = $whichSDtype
			if (!WaveExists(theSDs))
				printf "uh-oh. don't have the SD wave I thought I'd have\r\r\r\r"
			endif
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = stringfromlist(j, whichchannels)
				
				// also need to load the header
				loaddata/Q/P=HIpasspxp/S="headers_file"/O/J=nextchannelname nextHIpasspxpname
				WAVE/T/Z header = $nextchannelname
				
				if (WaveExists(header))
					ADbitvolts = ADBitVoltsFromCheetahheader2 (header)
				else
					ADbitvolts = NaN
				endif
				nextchannelnumber = str2num(replacestring("HI_NIP",nextchannelname,""))
				
				// if this is our first channel
				if (j==0)
					// make the destination wave
					make/O/n=(numchannelstoprocess) theResult
				endif
				
				// lookup nextchannelnumber in the SDwave
				// dammit, time to write a function for this.
												
				theResult[j] = SDlookup(theSDs,nextchannelnumber,"HI_NIP")*ADbitvolts
				
				killwaves/z $nextchannelname
								
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killwaves theSDs
			
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end


// which channels is a semicolon-separated list of channels to load in
// load and operate on one channel at a time...
// right now result gets named as outputprefix+whichanalysis+"_all" -> must fix!
// whichchannels: list of channels I want data from.  do not include AVG in this list.
// analysis parameter = analysis-specific parameter needed to specify what to do

// this is derived from computeonsnippets2
// works with SD waves found in HIpass.pxp files.
// should move a lot faster than I'm used to!

// SDwavechoices are SDs_postsub_3SDblank, SDs_postsub_4SDblank, SDs_postsub_noblank, SDs_raw

Function assembleCARyesno (recordinglist, mouseID, updatelist, CARyesnoname, whichchannels, whichanalysis, analysisparameter)
	WAVE/t recordinglist
	WAVE updatelist
	String mouseID, CARyesnoname,whichchannels, whichanalysis
	Variable analysisparameter

	//setdatafolder root:

	// establish Neuralynx data path
	
	// newpath/o HIpasspxp, ("NIPEPHYS:PREPROCESSED DATA:HIpass:"+mouseID)	

	newpath/o HIpasspxp, ("NIPEPHYS II:PREPROCESSED DATA:HIpass:"+mouseID)	

	//newpath/o HIpasspxp, ("Macintosh HD:Users:nipadmin:Desktop:PREPROCESSED DATA:HIpass:"+mouseID)	
	pathinfo HIpasspxp
	
	String HIpasspxpsuffix = "_HI_NIP.pxp"
	
	printf "looking for data in %s\r", S_path
	
	string theWaveNote

	variable numrecordings = numpnts(recordinglist),i,j,channelnumber,theSD
	variable numchannelstoprocess = itemsinlist(whichchannels)
	string nextpxpname, objectstoload, channeltoload, referencetoload, reportstring, nextchannelname
	
	// build the resultname herez
	String analysisparameterstring = CARyesnoname
	String resultname = (replacestring("ouse",mouseID,"") + "_"+CARyesnoname)
	// does the resultwave exist?
	WAVE/Z allresults = $resultname
	if (!WaveExists($resultname))	
		make/n=(numrecordings,numchannelstoprocess)/o $resultname /WAVE=allresults
	else
		// if it does exist, check whether it has enough rows and lengthen if it does not.
		variable resultsrows = DimSize(allresults,0)
		if (resultsrows < numrecordings)
			insertpoints/m=0 resultsrows, numrecordings-resultsrows, allresults
		endif
	endif 

	// does the window exist?
	string windowname = resultname + "_w"
	dowindow/f $windowname
	if (!V_flag)
		display/w=(0,44,470,489)
		appendimage allResults
		SetAxis/A/R left
		modifygraph margin=-1,noLabel=2,axThick=0
		modifyimage ''#0 ctab= {1e-05,5e-05,Green,0}
		dowindow/c $windowname
		doupdate
	endif

	// generate current list of pxp folder	
	String HIpasspxplist = IndexedFile(HIpasspxp, -1, ".pxp"),nextHIpasspxpname
	print HIpasspxplist

	String channelstoload, SDwavename
	Variable nextchannelnumber, ADbitvolts
	
	for (i=0; i < numrecordings; i += 1)

		if (updatelist[i])

			nextHIpasspxpname = recordinglist[i] + HIpasspxpsuffix

			// test for existence of nextpxpname
			if (findlistitem(nextHIpasspxpname, HIpasspxplist) < 0)
				printf nextHIpasspxpname + " not found\r"
			else
				printf "about to load data from %s ...\r", nextHIpasspxpname
			endif
			
			// load the appropriate CARyesno wave
			loaddata/q/p=HIpasspxp/S="data_records"/O/J=(CARyesnoname) nextHIpasspxpname
			WAVE CARyesno = $CARyesnoname
			if (!WaveExists(CARyesno))
				printf "uh-oh. don't have the SD wave I thought I'd have\r\r\r\r"
			endif
			
			for (j=0; j < numchannelstoprocess; j += 1)
				
				nextchannelname = stringfromlist(j, whichchannels)
				nextchannelnumber = str2num(replacestring("HI_NIP",nextchannelname,""))
				
				// if this is our first channel
				if (j==0)
					// make the destination wave
					make/O/n=(numchannelstoprocess) theResult
				endif
				
				// lookup nextchannelnumber in the CARyesno wave												
				theResult[j] = SDlookup(CARyesno,nextchannelnumber,"HI_NIP")
				
				killwaves/z $nextchannelname
								
			endfor

			// now that set of channels is processed, transpose the result and plug it in
			variable resultlength = dimsize(theResult,0)
			redimension/n=(1,resultlength) theResult
			allresults[i][] = theResult[q]
			doupdate
			
			killwaves CARyesno
			
		else
	
			printf "not updating data for %s...\r", recordinglist[i]

		endif

	endfor

end



Function getblankedSD (theData, SDlevelforpreblank)
	WAVE theData
	Variable SDlevelforpreblank
	
	duplicate/o theData maskedwave

	blankoutcrossings_abovebelow(maskedwave, SDlevelforpreblank,3)

	wavestats/q maskedwave
	killwaves/z maskedwave
	
	return V_sdev
end

Function getblankedSD2 (theData, SDlevelforpreblank, blankingwindow_ms)
	WAVE theData
	Variable SDlevelforpreblank,blankingwindow_ms
	
	duplicate/o theData maskedwave
	Wavestats/q maskedwave

	redimension/S maskedwave
	blankoutcrossings_abovebelow2(maskedwave, SDlevelforpreblank, blankingwindow_ms)	
		
	wavestats/q maskedwave
	killwaves/z maskedwave
	
	return V_sdev
end

Function blankoutcrossings_abovebelow(theData, SDthreshold, blankingwindow_ms)
	WAVE theData
	Variable SDthreshold, blankingwindow_ms

	blankoutcrossings (theData, SDthreshold)
	blankoutcrossings (theData, -1*SDthreshold)

end


Function blankoutcrossings_abovebelow2 (theData, SDthreshold, blankingwindow_ms)
	WAVE theData
	Variable SDthreshold, blankingwindow_ms

	blankoutcrossings2 (theData, SDthreshold,blankingwindow_ms)
	blankoutcrossings2 (theData, -1*SDthreshold,blankingwindow_ms)

end

// no redimensioning, no deleting points
Function blankoutcrossings2 (theData, SDthreshold,blankingwindow_ms)
	WAVE theData
	variable SDthreshold, blankingwindow_ms
	
	Wavestats/Q theData
	detectthresh(theData,0,0,SDthreshold*V_sdev,1)
	WAVE sintwave = $(nameofwave(theData)+"_sint")
		
	printf "blanking out %d ms windows containing crossings above %d SD\r", BLANKINGWINDOW_ms, SDthreshold
	
	// points 10 and following of the sintwave contain the level crossing times
	// we need to find the window starts and ends
	variable numsints = numpnts (sintwave),i
	
	make/n=(numsints)/o windowstarts, windowstops
	variable nextthreshtime_ms, nextthreshtime_pt
	
	for (i=10; i < numsints; i += 1)
		
		nextthreshtime_ms = sintwave[i]
		nextthreshtime_pt = x2pnt(theData,nextthreshtime_ms)
		
		// find the minimum following the level crossing
		wavestats/q/r=(nextthreshtime_ms, nextthreshtime_ms+BLANKINGWINDOW_ms) theData
		
		windowstarts[i] = V_maxloc - BLANKINGWINDOW_ms
		windowstops[i] = V_maxloc + BLANKINGWINDOW_ms
	
	endfor
	
	// do the blanking to NaN
	for (i=10; i < numsints; i += 1)
	
		theData[x2pnt(theData, windowstarts[i]),x2pnt(theData,windowstops[i])]= NaN
	
	endfor
	
	killwaves windowstarts, windowstops, sintwave
	
end


Function blankoutcrossings (theData, SDthreshold)
	WAVE theData
	variable SDthreshold
	
	Wavestats/Q theData
	detectthresh(theData,0,0,SDthreshold*V_sdev,1)
	WAVE sintwave = $(nameofwave(theData)+"_sint")
	
	variable BLANKINGWINDOW_ms = 3
	
	printf "blanking out %d ms windows containing crossings above %d SD\r", BLANKINGWINDOW_ms, SDthreshold
	
	// points 10 and following of the sintwave contain the level crossing times
	// we need to find the window starts and ends
	variable numsints = numpnts (sintwave),i
	
	make/n=(numsints)/o windowstarts, windowstops
	variable nextthreshtime_ms, nextthreshtime_pt
	
	for (i=10; i < numsints; i += 1)
		
		nextthreshtime_ms = sintwave[i]
		nextthreshtime_pt = x2pnt(theData,nextthreshtime_ms)
		
		// find the minimum following the level crossing
		wavestats/q/r=(nextthreshtime_ms, nextthreshtime_ms+BLANKINGWINDOW_ms) theData
		
		windowstarts[i] = V_maxloc - BLANKINGWINDOW_ms
		windowstops[i] = V_maxloc + BLANKINGWINDOW_ms
	
	endfor
	
	redimension/S theData
	// do the blanking to NaN
	for (i=10; i < numsints; i += 1)
	
		theData[x2pnt(theData, windowstarts[i]),x2pnt(theData,windowstops[i])]= NaN
	
	endfor
	
	// remove NaNs	
	//
	RemoveNaNs(theData)
	redimension/W theData
	
	killwaves windowstarts, windowstops, sintwave
	
end



// return scalar
Function crossingsSingleComputedSD(theData,rate,SDthreshold)
	WAVE theData
	variable rate
	variable SDthreshold
	
	Wavestats/Q theData
	
	Variable count = crossingsSingleLevel (theData, rate, SDthreshold*V_sdev)
	return count
end

// return scalar
Function crossingsSingleLevel (theData, rate, level)
	WAVE theData
	variable rate
	variable level

	detectthresh(theData,0,0,level,1)
	WAVE sintwave = $(nameofwave(theData)+"_sint")
	
	variable count
	
	if (rate)
		Variable recordingduration_secs = numpnts(theData)*dimdelta(theData,0)/1000
		count = sintwave[9]/recordingduration_secs
	else
		count = sintwave[9]
	endif

	killwaves sintwave
	
	return count
	
end

// range from 2-10 SD
// rate=0:just count crossings, =1:divide by length of recording in seconds
Function/S crossingsbySD (theData, rate, resultbasename)
	WAVE theData
	variable rate
	string resultbasename
	
	wavestats/q theData
	variable nextSD = 2, numfound
	make/o/n=9 $(resultbasename + nameofwave(theData)) = NaN
	WAVE outputwave = $(resultbasename + nameofwave(theData))
	setscale/p x, 2,1,outputwave

	for (nextSD=2; nextSD <= 10; nextSD += 1)	

		//print nextSD
	
		detectthresh(theData,0,0,nextSD*V_sdev,1)
		WAVE sintwave = $(nameofwave(theData)+"_sint")
		numfound = sintwave[9]
		outputwave[x2pnt(outputwave,nextSD)] = numfound
		
	endfor
			
	if (rate)
		Variable recordingduration_secs = numpnts(theData)*dimdelta(theData,0)/1000
		outputwave /= recordingduration_secs
		setscale/i d,0,0,"Hz", outputwave
	endif
	
	return (nameofwave(outputwave))
	
end


// this one works - delete when new one works
Function ComputeOnSingleChannel (recordinglist, whichchannel, referencechannel)
	WAVE/t recordinglist
	String whichchannel, referencechannel

	setdatafolder root:

	// establish Neuralynx data path
	newpath/o rawpxp, "Macintosh HD:Users:nipadmin:Desktop:IGOR DATA"
		
	string channeltype
	if (stringmatch(whichchannel, "*CSC*"))
		channeltype = "CSC"
	elseif (stringmatch(whichchannel, "*LFP*"))
		channeltype = "LFP"
	else
		channeltype = "BB"
	endif
	
	variable numrecordings = numpnts(recordinglist),i
	string nextpxpname, objectstoload, channeltoload, referencetoload
	
	// generate current list of pxp folder
	String pxplist = IndexedFile(rawpxp, -1, ".pxp")
	//print pxplist
	
	for (i=0; i < numrecordings; i += 1)
			
		// load the channel of interest and the reference channel
		objectstoload = whichchannel +";" + referencechannel +";"
		nextpxpname = recordinglist[i] + "_" + channeltype + ".pxp"
		channeltoload = whichchannel
		referencetoload = referencechannel

		// test for existence of nextpxpname
		if (findlistitem(nextpxpname, pxplist) < 0)
			// not found in list - if we are looking for a CSC or LFP, check for BB instead
			printf channeltype + " not found\r"
			if (findlistitem(replacestring(channeltype,nextpxpname,"BB"),pxplist) < 0)
				printf "BB not found either\r"
			else
				nextpxpname = recordinglist[i] +"_BB.pxp"	
				objectstoload = replacestring(channeltype, objectstoload,"BB")
				channeltoload = replacestring(channeltype, channeltoload, "BB")
				referencetoload = replacestring(channeltype, referencetoload, "BB")			
			endif
		endif
			
		loaddata/P=rawpxp/S="data_records"/O/J=objectstoload nextpxpname
		if (V_flag == 0)
			printf "no objects loaded!"
		else	
				
			// re-reference
			WAVE theChannel = $channeltoload
			WAVE theReference = $referencetoload
		
			// if we wanted CSC and we got BB, do the high pass filter here
			if (stringmatch(whichchannel,"*CSC*") && stringmatch(channeltoload, "*BB*"))

				filterf1(nameofwave(theChannel),300,10000)
				WAVE theChannel = $(channeltoload+"f")
				filterf1(nameofwave(theReference), 300,10000)
				WAVE theReference = $(referencetoload+"f")
				
			endif
		
			// special case - the named file here is already referenced
			if (stringmatch ("2011-10-27_14-00-04_BB.pxp", nextpxpname))
				printf "triggered special case - no reference!!\r"
			else
				theChannel -= theReference
			endif

			WAVE theResult = $(crossingsbySD(theChannel,1, "blut"))

	
			
		endif
		doupdate
	endfor
	
	
	// handle concatenation out here
	
	
	matrixtranspose allResults

end


// this function rearranges the 2D matrix along its second dimension according to channelorderwave
Function fixchannelorder (channelorderwave, matrix)
	wave channelorderwave, matrix
	
	
	duplicate/o matrix matrix_temp
	
	matrix[][] = matrix_temp[p][channelorderwave[q]-1]
	
	
	killwaves matrix_temp
	
end




Function fix030612 (matrix,mode)
	wave matrix
	variable mode
	
	make/o/n=16 newindices
	
	duplicate/o matrix temp
	
	if (mode == 0)
		matrix[][9] = temp[p][15]
		matrix[][7] = temp[p][7]
		matrix[][11] = temp[p][13]
		matrix[][5] = temp[p][11]
				
		matrix[][8] = temp[p][9]
		matrix[][6] = temp[p][3]		
		matrix[][15] = temp[p][5]
		matrix[][1] = temp[p][1]
		
		matrix[][10] = temp[p][4]
		matrix[][4] = temp[p][0]		
		matrix[][13] = temp[p][8]
		matrix[][3] = temp[p][2]
		
		matrix[][12] = temp[p][12]	
		matrix[][2] = temp[p][10]
		matrix[][14] = temp[p][14]
		matrix[][0] = temp[p][6]
	endif


	killwaves temp

end

Function updatepostimplantdays(mousetodatematchwave)
	WAVE/T mousetodatematchwave
	
	variable numexpts = dimsize(mousetodatematchwave,0),i
	string nextexpt, recwavename
	for (i=0; i < numexpts; i += 1)
	
		if (strlen(mousetodatematchwave[i][0]))
			nextexpt = mousetodatematchwave[i][0]
			
			recwavename = "root:mouse"+nextexpt+":mouse"+nextexpt+"recordings_AG1"
			WAVE/T recordingswave = $(recwavename)
			
			if (waveexists(recordingswave))
				make/n=(numpnts(recordingswave))/O $("mouse"+nextexpt+"postimplantday")/WAVE=postimplantday
				postimplantday = daysbetween(mousetodatematchwave[i][1],recordingswave[p])
			else
				printf "%s not found\r", recwavename
			endif
		endif
	
	
	endfor
	
end

// put each row of a matrix up on a line plot
Function multiline (matrix, xwave, startnew)
	WAVE matrix, xwave
	variable startnew	
	
	if (startnew)
		display
	endif
		
	variable numrows = dimsize(matrix,1),i
	
	for (i=0; i < numrows; i += 1)
		
		appendtograph matrix[][i] vs xwave
	
	endfor
	
end


//
Function bandtrack (datamatrix, bandmatrix)
	WAVE datamatrix, bandmatrix	

	imagetransform sumallrows bandmatrix
	WAVE W_sumrows
	variable bandthickness = (W_sumrows[0])
	
	variable length = dimsize(datamatrix,0), i
	
	WAVE bandstarts = $(extractbandstart(bandmatrix))
	
	make/o/n=(length, bandthickness) bands

	//populate bandmatrix using bandstarts and datamatrix
	//for (i=0; i < length; i += 1)
	
		bands[][] = datamatrix[p][bandstarts[p]+q]

		//bands[i][0] = datamatrix[i][bandstarts[0],bandstarts[0]+3]


	//endfor
	
end

Function plotbandcenter (bandmatrix)
	WAVE bandmatrix
	
	// this function gets us the band starts
	WAVE bandstartwave = $(extractbandstart(bandmatrix))
	redimension/s bandstartwave

	// sum bandmatrix to get width
	imagetransform sumallrows bandmatrix
	wavestats/q W_sumrows

	variable bandwidth = V_max

	// convert bandstartwave into bandcenters in pixels
	bandstartwave = (bandstartwave[p]+(bandwidth)/2)
	
	// convert to um from surface
	bandstartwave *= 100
	
	killwaves W_sumrows

end

Function/s extractbandstart (bandmatrix)
	WAVE bandmatrix
	
	make/O/B/n=(dimsize(bandmatrix,0)) result	
	make/O/B/n=(dimsize(bandmatrix,1)) temp
	
	variable i
	
	for (i=0; i < dimsize(bandmatrix,0); i += 1)
	
		temp = bandmatrix[i][p]
		findvalue/i=1 temp
		//print V_value
		result[i] = V_value
	endfor
	
	killwaves temp
	return nameofwave(result)
end


// averages the rows of a matrix, ignoring anything < 0 or NaN (and adjusting the denominator per row)
// also generates an SD wave
Function AverageSelected (matrix,[ ROImatrix])
	wave matrix, ROImatrix
	
	duplicate/o matrix temp2d temp2dcount
	
	if (paramisdefault(ROImatrix))
		temp2dcount = ((numtype(matrix[p][q]) == 2) || (matrix[p][q] < 0)) ? 0 : 1
	else
		temp2dcount = ((numtype(matrix[p][q]) == 2) || (matrix[p][q] < 0) || (ROImatrix[p][q] ==0)) ? 0 : 1
	endif		
	
	temp2d = (temp2dcount[p][q]) ? matrix[p][q] : 0
	
	imagetransform sumallrows temp2dcount
	duplicate/o W_sumrows temprowcount
	imagetransform sumallrows temp2d
	WAVE W_sumrows
	duplicate/o W_sumrows avgvalues
	avgvalues /= temprowcount
	
	// now convert temp2d to squared differences from avg
	
	temp2d[][] = (temp2d[p][q] > 0) ? (temp2d[p][q] - avgvalues[p])^2 : 0
	
	imagetransform sumallrows temp2d
	WAVE W_sumrows
	duplicate/o W_sumrows avgsqdiffs
	avgsqdiffs = sqrt(avgsqdiffs/(temprowcount[p]-1))
	
	killwaves temp2d, temp2dcount, temprowcount
	
end


Function statswave (wavenames, stat)
	string wavenames, stat
	
	variable numwaves = itemsinlist(wavenames),i
	make/o/n=(numwaves) theStat
	for (i=0; i < numwaves; i += 1)
	
		WAVE nextwave = $(StringFromList(i, wavenames))
		wavestats/q nextwave
		theStat[i] = V_rms
		
		printf "%s SD = %d\r",nameofwave(nextwave), V_rms

	
	endfor
end

Function CARmaker (matchstring, SDthresh, SDblankwindow_ms, RMSlowfactor, RMShighfactor)
	variable RMSlowfactor, RMShighfactor, SDthresh, SDblankwindow_ms
	string matchstring
	
	string matchingwavenames = wavelist ("*"+matchstring+"*", ";","")
	variable numwaves = itemsinlist(matchingwavenames),i,channelnumber
	variable carmade = 0
	
	WAVE SDs_presubtraction = $(blankedSDs_batch(matchstring, "presubtraction", SDthresh,SDblankwindow_ms))
	
	// compute the average SD
	imagetransform sumallcols SDs_presubtraction
	WAVE W_sumcols
	Variable averageRMS = W_sumcols[0]/numwaves
	Variable RMSlowcut = averageRMS*RMSlowfactor
	Variable RMShighcut = averageRMS*RMShighfactor
	
	duplicate/o SDs_presubtraction CARyesno
	CARyesno[][0] = ((SDs_presubtraction[p][0] > RMSlowcut) && (SDs_presubtraction[p][0] < RMShighcut)) ? 1 : 0

	// assemble list of waves to include in average, and do average
	string avglist = "",nextname
	for (i=0; i < numwaves; i += 1)
	
		if (CARyesno[i][0])
			nextname = matchstring+num2str(SDs_presubtraction[i][1])+";"
			avglist += nextname
		endif
		
	endfor
	
	print avglist
	
	// only make the CAR if there are some yeses in yesno
	if (numwaves != itemsinlist(avglist))
		printf "creating more selective CAR wave...\r"
		fWaveAverage_smallNbigwaves(avglist, "", 0, 0, "CAR", "")
		WAVE CAR
		noteKWV (CAR,"AVGof",avglist,0)
		carmade = 1
	endif
	
	// clean up
	
	killwaves/z W_sumrows, W_sumcols, maskedwave
	
	return carmade
end


// returns a string refstatus = "same", "CAR", "AVG"
Function/S CARmaker_simple (matchstring, RMSlowfactor, RMShighfactor)
	variable RMSlowfactor, RMShighfactor
	string matchstring
	
	string matchingwavenames = wavelist ("*"+matchstring+"*", ";","")
	variable numwaves = itemsinlist(matchingwavenames),i,channelnumber
	variable differences = 0
	string refstatus
	
	if (waveexists(SDs_RAW_noblank))
		WAVE SDs = SDs_RAW_noblank
	else
		WAVE SDs = $(SDs_batch(matchstring, "RAW_noblank"))
	endif
	
	// compute the average SD
	// fixing this because it doesn't work well with NaNs
	make/n=(dimsize(SDs,0))/O justSDs
	justSDs = SDs[p][0]
	Wavestats justSDs
	Variable averageRMS = V_avg
	Variable RMSlowcut = averageRMS*RMSlowfactor
	Variable RMShighcut = averageRMS*RMShighfactor
	
	// check for pre-existing CARyesno
	if (WaveExists(CARyesno))
		duplicate CARyesno CARyesno_prev
	endif
	
	duplicate/o SDs CARyesno
	CARyesno[][0] = ((SDs[p][0] > RMSlowcut) && (SDs[p][0] < RMShighcut)) ? 1 : 0
	imagetransform sumallcols CARyesno
	WAVE W_sumcols
	variable excludes = dimsize(CARyesno,0) - W_sumcols[0]

	// no _prev wave means we haven't worked on this before.  set differences to 1 to CAR will be computed
	if (!WaveExists(CARyesno_prev))
		differences = 1
	else	
		// if CARyesno_prev exists, check for difference between CARyesno and CARyesno_prev,
		// if differences is 0 then we won't do anything!	
		CARyesno_prev = (CARyesno[p][q] == CARyesno_prev[p][q]) ? 0 : 1
		imagetransform sumallrows CARyesno_prev
		differences = sum(W_sumrows,-inf,inf)
	endif

	if (differences == 0)

		printf "no quarrel with CAR inclusions - no recompute needed\r"
		refstatus = "same"			

	else
		
		// assemble list of waves to include in average, and do average
		string avglist = "",nextname
		for (i=0; i < numwaves; i += 1)
	
			if (CARyesno[i][0])
				nextname = matchstring+num2str(SDs[i][1])+";"
				avglist += nextname
			endif
		
		endfor
	
		print avglist
	
		// only make the CAR if there are some nos in yesno
		if (excludes > 0)
			printf "creating more selective CAR wave...\r"
			fWaveAverage_smallNbigwaves(avglist, "", 0, 0, "CAR", "")
			WAVE CAR
			// cut size in half - no need for double precision
			Redimension/S CAR
			noteKWV (CAR,"AVGof",avglist,0)
			refstatus = "CAR"
		else
			refstatus = "AVG"
		endif
		// clean up

		killwaves/z W_sumrows, W_sumcols, maskedwave, CARyesno_prev, justSDs

	endif

	return refstatus

end

Function NEO (theData, delta_ms)
	Wave theData
	Variable delta_ms
	
	Variable delta_pnts = floor(delta_ms/dimdelta(theData,0))
	Variable length = numpnts(theData)
	
	duplicate/o theData $(nameofwave(theData)+"NEO")/WAVE=NEO
	redimension/d NEO	
	NEO[delta_pnts,length-delta_pnts] = (theData[p])^2 - (theData[p-delta_pnts] * theData[p+delta_pnts])
	
End

Function rereference (matchstring, numwaves, referencename)
	String matchstring, referencename
	variable numwaves
	
	variable i,channelnumber
	
	WAVE reference = $referencename
	string nextchannelname
	
	for (i=0; i < numwaves; i += 1)
		
		nextchannelname = matchstring + num2str(i+1)
		WAVE nextchannel = $nextchannelname
		
		if (waveexists(nextchannel))
		
			printf "subtracting %s from %s...\r", referencename,nextchannelname
			nextchannel = nextchannel[p] - reference[p]
		
			NoteKWV (nextchannel, "REREF", ("r"+referencename), 0)

		else
			printf "missing wave %s\r", nextchannelname
		endif
	endfor
	
end

Function unreference (matchstring, numwaves, referencename)
	String matchstring, referencename
	variable numwaves
	
	variable i,channelnumber
	
	WAVE reference = $referencename
	string nextchannelname

	for (i=0; i < numwaves; i += 1)
		
		nextchannelname = matchstring + num2str(i+1)
		WAVE nextchannel = $nextchannelname
		
		if (Waveexists(nextchannel))

			printf "adding %s back to %s...\r", referencename, (matchstring + num2str(i+1))
			nextchannel = nextchannel[p] + reference[p]
		
			NoteKWV (nextchannel, "REREF", "", 0)

		else
			printf "missing wave %s\r", nextchannelname
		endif	
	endfor

end

Function/S blankedSDs_batch (matchstring, SDwavesuffix, SDblankthresh, SDblankwindow_ms)
	string matchstring, SDwavesuffix
	Variable SDblankthresh, SDblankwindow_ms

	string matchingwavenames = buildlist (matchstring,1,16)
	variable numwaves = itemsinlist(matchingwavenames),i,channelnumber

	make/O/n=(numwaves,2) $("SDs_"+SDwavesuffix)/WAVE=SDs
	//edit SDs
	Variable CARmade = 0
	
	for (i=0; i < numwaves; i += 1)
		
		WAVE nextchannel = $(StringFromList(i, matchingwavenames))	
		channelnumber = str2num(replacestring(matchstring,StringFromList(i, matchingwavenames),""))
		
		if (!WaveExists(nextchannel))
			SDs[i][0] = NaN
		else
			SDs[i][0] = getblankedSD2(nextchannel, SDblankthresh,SDblankwindow_ms)
		endif
		
		SDs[i][1] = channelnumber
		doupdate
	
	endfor
	
	return ("SDs_"+SDwavesuffix)
end

// changing this to work properly 120712
Function/S SDs_batch (matchstring, SDwavesuffix)
	string matchstring, SDwavesuffix

	string matchingwavenames = buildlist (matchstring,1,16)
	variable numwaves = itemsinlist(matchingwavenames),i,channelnumber
	
	printf "computing SDs for waves matching %s, with no blanking. saving result as SDs%s\r",matchstring, SDwavesuffix
	
	string nameofresult = "SDs_"+SDwavesuffix

	make/O/n=(numwaves,2) $(nameofresult)/WAVE=SDs
	
	for (i=0; i < numwaves; i += 1)
		
		WAVE nextchannel = $(StringFromList(i, matchingwavenames))	
		channelnumber = str2num(replacestring(matchstring,StringFromList(i, matchingwavenames),""))

		if (!WaveExists(nextchannel))
			SDs[i][0] = NaN
		else
			Wavestats/q nextchannel		
			SDs[i][0] = V_sdev
		endif
	
		SDs[i][1] = channelnumber
		doupdate
	
	endfor

	return (nameofresult)
end


Function CARmaker_bad (matchstring, SDthresh, RMSlowfactor, RMShighfactor)
	variable RMSlowfactor, RMShighfactor, SDthresh
	string matchstring
	
	string matchingwavenames = wavelist ("*"+matchstring+"*", ";","")
	variable numwaves = itemsinlist(matchingwavenames),i,channelnumber
	
	make/O/n=(numwaves,2) SDs
	
	for (i=0; i < numwaves; i += 1)
		
		WAVE nextchannel = $(StringFromList(i, matchingwavenames))		
		channelnumber = str2num(replacestring(matchstring,StringFromList(i, matchingwavenames),""))
		if (i==0)
			make/o/n=(numpnts(nextchannel)) maskedwave
		endif
		
		maskedwave = nextchannel[p]
		blankoutcrossings_abovebelow(maskedwave, SDthresh,3)
		
		wavestats/q maskedwave
		SDs[i][0] = V_sdev
		SDs[i][1] = channelnumber
	
	endfor
	
	// compute the average SD
	imagetransform sumallcols SDs
	WAVE W_sumcols
	Variable averageRMS = W_sumcols[0]/numwaves
	Variable RMSlowcut = averageRMS*RMSlowfactor
	Variable RMShighcut = averageRMS*RMShighfactor
	
	duplicate/o SDs CARyesno
	CARyesno[][0] = ((SDs[p][0] > RMSlowcut) && (SDs[p][0] < RMShighcut)) ? 1 : 0

	// assemble list of waves to include in average, and do average
	string avglist = "",nextname
	for (i=0; i < numwaves; i += 1)
	
		if (CARyesno[i][0])
			nextname = matchstring+num2str(SDs[i][1])+";"
			avglist += nextname
		endif
		
	endfor
	
	print avglist
	
	// only make the CAR if there are some yeses in yesno
	if (numwaves != itemsinlist(avglist))
		printf "creating more selective CAR wave...\r"
		fWaveAverage_smallNbigwaves(avglist, "", 0, 0, "CAR", "")
		WAVE CAR
		Note/k CAR, avglist	
	endif
	
	// clean up
	
	killwaves/z W_sumrows, W_sumcols, maskedwave
end


Function channelcount_bythreshold (theMatrix, prefix, thresholdstart, thresholdstop)
	wave theMatrix
	string prefix
	variable thresholdstart, thresholdstop


	variable NUMSTEPS = 10,i
	string nextname
	
	variable length = dimsize(thematrix,0)
	
	
	display
	for (i=thresholdstart; i <= thresholdstop; i += (thresholdstop-thresholdstart)/10)

		nextname = prefix+"_count_"+num2str(i)

		imagethreshold/T=(i) theMatrix
		WAVE M_imagethresh
		M_imagethresh = (M_imagethresh[p][q] == 255) ? 1 : 0
		
		imagetransform sumallrows M_imagethresh
		duplicate/o W_sumrows $nextname
		appendtograph $nextname

	endfor

	


end


Function BuildSpectralReference ()

	// make 2 index waves: toomuchpower, falsepower, OUT
	// OUT means out for rerefernece, OUT for data
	
	// go through all channels
	// for each channel:
		// is total power > cutoff?
		// toomuchpower = 1
		// OUT =1

		// is falsepowerratio > cutoff
		// falsepower = 1
	// endfor
	
	// do we have any false power problems? (is sum(falsepower) > 0)
	// if yes:
		// construct average of all of them
		
		// for each of them
			// subtract the average
			// ask again: is falsepowerratio > cutoff
			// if YES
			//		OUT = 1

	// else no:

	// build average from all waves where OUT == 0

end

Function quickAER (SEsuffix)
	String SEsuffix

	WAVE AER_SD4_cohpol	 
	WAVE firstchannel = root:data_records:HI_NIP1
	variable recordingtime_secs = numpnts(firstchannel)*dimdelta(firstchannel,0)/1000
	print recordingtime_secs
	
	variable i
	
	for (i=0; i < 15; i += 1)
	
		WAVE nextSEheadrec = $("root:SEdata"+SEsuffix+":HI_NIP"+num2str(i+1)+"_rCAR_SD4_SEheadrec")
	
		AER_SD4_cohpol[i] = dimsize(nextSEheadrec,1)/recordingtime_secs
	
	endfor

end

Function quickpctile (SEsuffix, percentile)
	String SEsuffix
	variable percentile
	
	WAVE Vpp_cohpol
	WAVE/T theSEheadfile = $("root:SEdata"+SEsuffix+":HI_NIP1_rCAR_SD4_SEheadfile")
	Variable ADbitvolts = ADBitVoltsFromCheetahheader2(theSEheadfile)

	variable i
	
	for (i=0; i < 16; i += 1)
	
		WAVE nextpeaktopeak = $("root:SEdata"+SEsuffix+":HI_NIP"+num2str(i+1)+"_rCAR_SD4_segVpp")
	
		Vpp_cohpol[i] = (pctile(nextpeaktopeak,1,percentile))*ADBitVolts		
	
	endfor

end

Function quickspikeband ()


	WAVE spikeband_cohpol

	variable i
	
	for (i=0; i < 16; i += 1)
	
		WAVE nextPSD = $("HI_NIP"+num2str(i+1)+"_PSD_cohref")
	
		spikeband_cohpol[i] = sum(nextPSD,500,1000)
		doupdate
	
	endfor

end