#pragma rtGlobals=1		// Use modern global access method.

// fittype 0: gauss
// fittype 1: poly
Function bandfinder (aerplot, interpfactor, fittype, fitparam, newbandcenters)
	WAVE aerplot
	variable interpfactor,fittype,fitparam,newbandcenters

	variable numrecordings = dimsize(aerplot,0),i,j
	variable numchannels = dimsize(aerplot,1)

	make/O/n=(numrecordings, numchannels*interpfactor) fitcurves
	make/O/n=(numrecordings, numchannels*interpfactor) output

	make/O/n=(numrecordings) bandcenters
	make/O/n=(numchannels) maskwave = 1
	maskwave[11,15] = 0
	
	if (newbandcenters)
	
		if (fittype == 0)
			print "using gaussian fit"
		else
			printf "using poly fit with degree %d\r", fitparam
		endif		

		for (i=0; i < numrecordings; i += 1)	

			// extract from aerplot
			imagetransform/G=(i) getrow aerplot
			WAVE W_extractedrow		

			// do curvefit
			if (fittype == 0)
				CurveFit/q/L=((numchannels-1)*interpfactor+1) /NTHR=0 gauss W_ExtractedRow /D
			elseif (fittype == 1)
				CurveFit/q/L=((numchannels-1)*interpfactor+1) /NTHR=0 poly fitparam, W_ExtractedRow /D
			endif
			
			//CurveFit/M=(maskwave)/q/L=(numchannels*interpfactor) /NTHR=0 gauss,  W_ExtractedRow /D
			WAVE fit_W_extractedrow
			
			// drop result into fitcurves
			fitcurves[i][] = fit_W_extractedrow[q]
			
			Wavestats/q fit_W_extractedrow
			// find half-max center point
			bandcenters[i] = halfmaxcenter(fit_W_extractedrow)
			
			//bandcenters[i] = V_maxloc
		endfor
	
		// discretize bandcenters to the nearest 0.1
	
		roundwave(bandcenters, 0)	
		duplicate/o bandcenters bandshifts
		bandshifts = bandcenters[p] - bandcenters[0]

	else
	
		WAVE bandshifts
		
	endif
	
	output[][] = aerplot[p][floor((q/10)+bandshifts[p])]
	
	// set blank zones in output to NaN
	for (j=0; j < numrecordings; j += 1)
	
		// down shift
		if (bandshifts[j] < 0)
			//print j, bandshifts[j]*interpfactor
			output[j][0,-1*bandshifts[j]*interpfactor] = NaN
		elseif (bandshifts[j] > 0)
			output[j][numchannels*10 - bandshifts*10, numchannels*10] = NaN
		endif
	
	endfor
	
end

Function justshift (inputplot, interpfactor, shiftwave)
	WAVE inputplot, shiftwave
	variable interpfactor
	
	variable numrecordings = dimsize(inputplot,0),i,j
	variable numchannels = dimsize(inputplot,1)

	make/O/n=(numrecordings, numchannels*interpfactor) output

	output[][] = inputplot[p][floor((q/10)+shiftwave[p])]

	// set blank zones in output to NaN
	for (j=0; j < numrecordings; j += 1)
	
		// down shift
		if (shiftwave[j] < 0)
			//print j, bandshifts[j]*interpfactor
			output[j][0,-1*shiftwave[j]*interpfactor] = NaN
		elseif (shiftwave[j] > 0)
			output[j][numchannels*10 - shiftwave*10, numchannels*10] = NaN
		endif
	
	endfor

end

// nearest integer
Function halfmaxcenter(theTrace)
	wave theTrace
	
	wavestats/q theTrace
	
	// different case if the max is at one of the ends
	
	variable halflevel = V_max - (V_max-V_min)/2
	
	// first do the other one though	
	FindLevel/Q/EDGE=1/R=(0,V_maxloc) theTrace, halflevel
	variable early = (!V_flag) ? V_levelX : 0
	
	FindLevel/Q/EDGE=2/R=(V_maxloc,) theTrace, halflevel
	//print V_levelX
	variable late = (!V_flag) ? V_levelX : pnt2x(theTrace, numpnts(theTrace)-1)
	
	// findlevel from max going forward
	
	// return (x1+x2)/2
	
	return (early+late)/2
	
end

// round a wave using sscanf
Function roundwave (theWave, decimalplaces)
	WAVE theWave
	variable decimalplaces
	
	variable length = numpnts(theWave),i
	make/O/n=(length)/T theWave_text
	string dummystring

	for (i=0; i < length; i += 1)
		sprintf dummystring,"%."+num2str(decimalplaces)+"f\r", theWave[i]
		theWave[i] = str2num(dummystring)
	endfor
end

Function averageprofile (map, startP, endP)
	WAVE map
	variable startP, endP
	
	duplicate/o map temp
	
	temp[0,startP-1] = 0
	temp[endP+1,dimsize(map,0)-1] = 0
	imagetransform sumallcols temp
	WAVE W_sumcols
	
	W_sumcols /= ((endP-startP)+1)
	
	
	
	
	killwaves temp
end 