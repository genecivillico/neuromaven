#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function MakeMagsqPhaseCoherenceMatrices (prefix, numchans, pointspersegment, overlappoints, windowtype, minoutputresolution, bandstart, bandstop, displayoutput, keeppieces)
	String prefix, windowtype
	variable numchans, bandstart, bandstop, pointspersegment, overlappoints, minoutputresolution, displayoutput, keeppieces
	
	variable i,j
	make/n=(numchans,numchans)/O mscoherencematrix
	make/n=(numchans,numchans)/O phaseshiftmatrix
	
	string prestring, mscohereresultname, phaseshiftresultname
	
	if (displayoutput)
		dowindow/f coherenceoutput
		if (!V_Flag)
			newimage/s=0 mscoherencematrix
			ModifyImage ''#0 ctab= {0,1,Grays,0}
			dowindow/c coherenceoutput
		endif
	endif
	
	// for each channel
	for (i=0; i < numchans; i += 1)
	
		WAVE nextchannelA = $(prefix + num2str(i+1))
	
		// test against all other channels greater than it
		for (j=i+1; j < numchans; j += 1)
			
			WAVE nextchannelB = $(prefix + num2str(j+1))
			print nameofwave(nextchannelA),nameofwave(nextchannelB)
				
			// build destination coherence wave
			prestring = "ch"+replacestring("HI_NIP", nameofwave(nextchannelA),"") + "vsch" + replacestring("HI_NIP", nameofwave(nextchannelB),"") + "_"
			mscohereresultname = prestring + "mscoherence_binned"
			phaseshiftresultname = prestring + "CSphase_binned"
			
			// change doCoherence2 to return the computed wave?
			if (exists(mscohereresultname) != 1)				
				doCoherence2 (nextchannelA, nextchannelB, pointspersegment, overlappoints, windowtype, "", minoutputresolution,0)
			else
				printf "coherence wave %s already exists\r", mscohereresultname
			endif
			
			WAVE nextcoherence = $mscohereresultname
			WAVE nextphase = $phaseshiftresultname

			// extract average values and populate matrices
			mscoherencematrix[i][j] = mean(nextcoherence,bandstart,bandstop)
			phaseshiftmatrix[i][j] = mean(nextphase,bandstart,bandstop)
			
			dowindow/f coherenceoutput
			doupdate
			
			// only keep the constituent coherence waves if called with keeppieces=1
			if (!keeppieces)
				killwaves nextcoherence, nextphase
			endif
			
		endfor
	
	endfor
	
	// mirror matrices across the diagonal
	mscoherencematrix = (mscoherencematrix[p][q] == 0) ? mscoherencematrix[q][p] : mscoherencematrix[p][q]
	phaseshiftmatrix = (phaseshiftmatrix[p][q] == 0) ? phaseshiftmatrix[q][p] : phaseshiftmatrix[p][q]

	// set diagonals to 1 and 0
	mscoherencematrix = (p == q) ? 1 : mscoherencematrix[p][q]	
	phaseshiftmatrix = (p == q) ? 0 : phaseshiftmatrix[p][q]
	
	// prepare keyword-value pairs for storing in the wavenote
	string analysiskeys = "pointspersegment;overlappoints;windowtype;minoutputresolution;bandstart;bandstop;"
	string analysisvalues = num2str(pointspersegment)+";"+num2str(overlappoints)+";"+windowtype+";"+num2str(minoutputresolution)+";"+num2str(bandstart)+";"+num2str(bandstop)+";"
	make/o/n=6 analysiskeyisnumber = {1,1,0,1,1,1}
	
	multiNoteKWV (mscoherencematrix, analysiskeys, analysisvalues, analysiskeyisnumber)
	multiNoteKWV (phaseshiftmatrix, analysiskeys, analysisvalues, analysiskeyisnumber)
	
	return 1
	
end

Function/WAVE BuildReferenceMatrix2 (prefix, numchans, pointspersegment, overlappoints, windowtype, minoutputresolution, bandstart, bandstop, mscoherethresh, phasethresh)
	String prefix, windowtype
	variable numchans, bandstart, bandstop, pointspersegment, overlappoints, minoutputresolution, mscoherethresh, phasethresh
		
	string referencematrixname = "refmatrix"+num2str(mscoherethresh)+"_"+num2str(phasethresh)
	make/n=(numchans,numchans)/O $referencematrixname
	WAVE refmatrix = $referencematrixname
	
	variable success = MakeMagsqPhaseCoherenceMatrices ("HI_NIP", 16, pointspersegment, overlappoints, windowtype, minoutputresolution, bandstart, bandstop,0,1)
	WAVE mscoherencematrix, phaseshiftmatrix
		
	// remove sign from phaseshiftmatrix
	phaseshiftmatrix = abs(phaseshiftmatrix)

	//threshold coherence matrix at level sent in to function
	imagethreshold/t=(mscoherethresh) mscoherencematrix
	WAVE M_imagethresh
	duplicate/o M_imagethresh mscohere_thresh

	// /I for invert here, because high values should map to exclusion for phase
	imagethreshold/t=(phasethresh)/I phaseshiftmatrix
	duplicate/o M_imagethresh phaseshift_thresh

	// don't want diagonals for either of these (virtual references should not include the wave itself)
	mscohere_thresh = (p == q) ? 0 : mscohere_thresh[p][q]
	phaseshift_thresh = (p == q) ? 0 : phaseshift_thresh[p][q]
	
	// so now we've got mscohere and phase matrices set to 255 if yes, 0 if no.
	// master matrix is everybody who is yes in both places (i.e. a no in either place is disqualifying
	
	refmatrix = ((mscohere_thresh[p][q] == 255)	&& (phaseshift_thresh[p][q] == 255)) ? 255 : 0
	
	killwaves M_imagethresh
	
	return refmatrix
	
end

Function BuildReferenceMatrix (prefix, numchans, bandstart, bandstop, mscoherethresh, phasethresh)
	String prefix
	variable numchans, mscoherethresh, bandstart, bandstop, phasethresh
	
	variable i,j
	make/n=(numchans,numchans)/O mscoherencematrix
	make/n=(numchans,numchans)/O phaseshiftmatrix
	
	string prestring, mscohereresultname, phaseshiftresultname
	
	string referencematrixname = "refmatrix"+num2str(mscoherethresh)+"_"+num2str(phasethresh)
	make/n=(numchans,numchans)/O $referencematrixname
	WAVE refmatrix = $referencematrixname
	
	newimage/s=0 mscoherencematrix
	ModifyImage ''#0 ctab= {0,1,Grays,0}
	dowindow/c coherenceoutput
	
	// for each channel
	for (i=0; i < numchans; i += 1)
	
		WAVE nextchannelA = $(prefix + num2str(i+1))
	
		// test against all other channels greater than it
		for (j=i+1; j < numchans; j += 1)
			
			WAVE nextchannelB = $(prefix + num2str(j+1))
			print nameofwave(nextchannelA),nameofwave(nextchannelB)
				
			// build destination coherence wave
			prestring = "ch"+replacestring("HI_NIP", nameofwave(nextchannelA),"") + "vsch" + replacestring("HI_NIP", nameofwave(nextchannelB),"") + "_"
			mscohereresultname = prestring + "mscoherence_binned"
			phaseshiftresultname = prestring + "CSphase_binned"
			
			// change doCoherence2 to return the computed wave?
			if (exists(mscohereresultname) != 1)				
				doCoherence2 (nextchannelA, nextchannelB, 320000, 32000, "Hamming", "", 100,1)
			else
				printf "coherence wave %s already exists\r", mscohereresultname
			endif
			
			WAVE nextcoherence = $mscohereresultname
			WAVE nextphase = $phaseshiftresultname

			// extract average values and populate matrices
			mscoherencematrix[i][j] = mean(nextcoherence,bandstart,bandstop)
			phaseshiftmatrix[i][j] = mean(nextphase,bandstart,bandstop)
			
			dowindow/f coherenceoutput
			doupdate
			
		endfor
	
	endfor
	
	// mirror matrices across the diagonal
	mscoherencematrix = (mscoherencematrix[p][q] == 0) ? mscoherencematrix[q][p] : mscoherencematrix[p][q]
	phaseshiftmatrix = (phaseshiftmatrix[p][q] == 0) ? phaseshiftmatrix[q][p] : phaseshiftmatrix[p][q]

	// set diagonals to 1 and 0
	mscoherencematrix = (p == q) ? 1 : mscoherencematrix[p][q]	
	phaseshiftmatrix = (p == q) ? 0 : phaseshiftmatrix[p][q]
	
	// remove sign from phaseshiftmatrix
	phaseshiftmatrix = abs(phaseshiftmatrix)

	//threshold coherence matrix at level sent in to function
	imagethreshold/t=(mscoherethresh) mscoherencematrix
	WAVE M_imagethresh
	duplicate/o M_imagethresh mscohere_thresh

	// /I for invert here, because high values should map to exclusion for phase
	imagethreshold/t=(phasethresh)/I phaseshiftmatrix
	duplicate/o M_imagethresh phaseshift_thresh

	// don't want diagonals for either of these (virtual references should not include the wave itself)
	mscohere_thresh = (p == q) ? 0 : mscohere_thresh[p][q]
	phaseshift_thresh = (p == q) ? 0 : phaseshift_thresh[p][q]
	
	// so now we've got mscohere and phase matrices set to 255 if yes, 0 if no.
	// master matrix is everybody who is yes in both places (i.e. a no in either place is disqualifying
	
	refmatrix = ((mscohere_thresh[p][q] == 255)	&& (phaseshift_thresh[p][q] == 255)) ? 255 : 0
	
	killwaves M_imagethresh
		
end

// prereference includes the channel - have to compensate for this
Function ProcessAndSubtractPrereference (channel, prereference, numinprereference)
	WAVE channel, prereference
	variable numinprereference

	duplicate/O prereference WORKINGREFERENCE

	// prepare WORKINGREFERENCE as follows:
 	WORKINGREFERENCE -= (channel/numinprereference) // i.e. 11 for family1
       // this leaves 10 channels that have been divided by 11
       // so in one step we want to multiply by 11 and divide by 10
       WORKINGREFERENCE *= (numinprereference/(numinprereference - 1))

	channel -= WORKINGREFERENCE
	
end

// build re-average references 
// assumes the raw waves are out, saved as .ibw in a separate file system directory called experimentname + " RAW"

// strategy
// Write code to handle one channel at a time
// When constructing average, load each component, add it/numchans to the working reference, then kill it. Saves memory and makes it possible to build up all reref'd channels in pxp. 

// next write a wrapper for this function which does it for all 16
// thresholdmatrix is 255  for yes, 0 for no

// load as "_RAW"
// load reference components as "_RAW" (they each get killed)
// move to "notRAW" so it doesn't conflict with future ones coming in
Function RereferenceFromNewVirtual (channelnametemplate, channelnumber, thresholdmatrix)
	WAVE thresholdmatrix
	string channelnametemplate
	variable channelnumber
	
	string channelname = replacestring("XX", channelnametemplate, num2str(channelnumber))
	
	string currentexperimentname = IgorInfo(1)
	pathinfo home
	string pathtorawtraces = S_path + currentexperimentname + " RAW:"
	print pathtorawtraces
	newpath/O rawtracespath, pathtorawtraces
	
	string pathtocurrent 
	string pathtoraw, nextcomponentname
	
	// load in the raw wave
	loadwave/W/A/P=rawtracespath (channelname+".ibw")
	
	WAVE channel = $(channelname)
	WAVE workingreference

	if (!WaveExists(workingreference))
		duplicate/o channel workingreference
		redimension/S workingreference 
	endif	

	workingreference = 0
	doupdate

	// get the channelnumber
	variable thresholdmatrixsize = dimsize(thresholdmatrix,0)
	variable i
 
 	// sum along the matrix to figure out how many ones we have
 	imagetransform sumallcols thresholdmatrix
 	WAVE W_Sumcols
 	variable numinreference = W_sumcols[channelnumber-1]/255
 	printf "%d in reference\r", numinreference
 
	//  step along the matrix
	for (i=0; i < thresholdmatrixsize; i += 1)
		
		// for each yes encountered
		if (thresholdmatrix[channelnumber-1][i]  == 255)
			printf "HI_NIP%d is IN\r", i+1
			
			nextcomponentname = replacestring("XX",channelnametemplate, num2str(i+1))
			
			// load this wave
			loadwave/A=tempcomponent/P=rawtracespath (nextcomponentname +".ibw")

			WAVE nextcomponent = $nextcomponentname
			redimension/s nextcomponent
			
			// add its fractional piece to the workingreference
			workingreference += nextcomponent/numinreference
			doupdate
			// in a future version we could check if this is going to be used in next round
			killwaves nextcomponent
					
		endif
	
	endfor
	
	// now reference is built
	redimension/S channel
	
	channel = channel[p] - workingreference[p]
	
	killwaves workingreference
	
	movewave channel, $(replacestring("_RAW", channelname, ""))
	
end

Function RelocateWaves (foldersuffix, template, start, stop)
	string foldersuffix, template
	Variable start, stop
	
	// make a folder in the file system at the level where my current experiment is
	// make a path to that folder
	// save the traces to that place with the relocate option

	string currentexperimentname = IgorInfo(1)
	pathinfo home

	string pathtorawtraces = S_path + currentexperimentname + " " + foldersuffix + ":"
	print pathtorawtraces
	newpath/C/O rawtracespath, pathtorawtraces

	Save/B/O/P=rawtracespath buildlist2(template,start,stop)
	
	// delete 'em
	
	ExecuteCmdOnList("killwaves/z %s", buildlist2(template,start,stop))
end

Function RereferenceFromNewVirtuals (channelnametemplate, start, stop, thresholdmatrix)
	string channelnametemplate
	variable start, stop
	wave thresholdmatrix

	// make sure there is not one of these left over
	killwaves/z workingreference

	string channelname

	variable i
	for (i=start; i <= stop; i+= 1)
	
		RereferenceFromNewVirtual (channelnametemplate, i, thresholdmatrix)

	endfor
	
end