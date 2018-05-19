#pragma rtGlobals=3		// Use modern global access method and strict wave access.



// fPowerSpectralDensity_gc() returns the  name of the created PSD wave.
//
// modified GC 2/2014 from wavemetrics function.  difference is that the suffix for the destination wave is specified as an argument, rather than being automatically "_psd"

//  WM function notes:
//  Version 1.9: the global variable V_ENBW can be used to compute the linear spectrum:
//	WAVE w_psd = $fPowerSpectralDensity(w, npsd, windowname, removeDC)
//	NVAR V_ENBW = V_ENBW
//
//	Duplicate/O w_psd, w_linearSpectrum
//	w_linearSpectrum = sqrt(w_psd * V_ENBW).
//
//  Note: The linear spectral density, in V/sqrt(Hz)  if the input it is Volts, is simply sqrt(w_psd)
//
Function/S fPowerSpectralDensity_gc(w, npsd, outputsuffix, windowname, removeDC)
	Wave w
	Variable npsd			// SegLen - the number of input points in each segment, must be even
	String outputsuffix
	String windowName		// one of "Square;Hann;Parzen;Welch;Hamming;BlackmanHarris3;KaiserBessel"
	Variable removeDC		// 0 to leave the DC component in the PSD result, 1 to remove it.
	
	Variable nsrc= numpnts(w)
	if( npsd > nsrc )
		npsd= nsrc
	endif
	String destw=NameOfWave(w)+outputsuffix
	String srctmp=NameOfWave(w)+"_tmp"
	String winw=NameOfWave(w)+"_psdWin"
	
	Make/O/N=(npsd/2+1) $destw= 0
	WAVE psd= $destw
	
	Make/O/N=(npsd) $srctmp,$winw
	WAVE tmp= $srctmp
	WAVE win= $winw
	win= 1
	
	Variable winNorm
	strswitch( windowName )	// one of "Square;Hann;Parzen;Welch;Hamming;BlackmanHarris3;KaiserBessel"
		default:
		case "Square":
			winNorm= 1
			break
		case "Hann":
			Hanning win
			// winNorm=0.375		//  theoretical avg squared value
			WaveStats/Q win
			winNorm= V_rms*V_rms	// actual value is more accurate than a theoretical value.
			break
		case "Parzen":
			winNorm= Parzen(win)
			break
		case "Welch":
			winNorm= Welch(win)
			break
		case "Hamming":
			winNorm= Hamming(win)
			break
		case "BlackmanHarris3":
			winNorm= BlackmanHarris3(win)
			break
		case "KaiserBessel":
			winNorm= KaiserBessel(win)
			break
	endswitch

	// Compute Equivalent noise bandwidth as per [1], equation 22.
	WaveStats/Q/M=0 win
	Variable s1 	= V_sum
	Variable s2 = winNorm * npsd	// s2 is the sum of the squares of the window values
	Variable fs= 1/deltax(w)
	Variable/G V_ENBW= fs * s2 / (s1*s1) // Output via global variable!				

	// Optionally remove DC component from the entire wave.
	// This perhaps should be done for each segment, instead.
	Variable dc= 0
	if( removeDC )	// boolean
		WaveStats/Q/M=0 w
		dc= V_Avg
	endif

	Variable psdFirst= 0
	Variable psdOffset= npsd/2
	Variable nsegs
	for( nsegs= 0; psdFirst+npsd <= nsrc; nsegs += 1, psdFirst += psdOffset)
		Duplicate/O/R=[psdFirst,psdFirst+npsd-1] w, tmp
		tmp = (tmp-dc) * win
		FFT/DEST=ctmp tmp	// result is a one-sided spectrum of complex values
		psd += magsqr(ctmp)	// summed Fourier power of one-sided spectrum
								// (we're missing all negative frequency powers except for the Nyquist frequency)
	endfor
	CopyScales/P ctmp, psd
	KillWaves/Z ctmp
	// transform seconds in to Hz, etc, just like the FFT else remove units
	String newUnits=WaveUnits(psd,0)
	String oldUnits=WaveUnits(w, 0)
	if( CmpStr(oldUnits,newUnits )== 0 )	// FFT didn't modify the units, we try a little harder
		strswitch( oldUnits )
			case "s":
			case "sec":
			case "secs":
				newUnits= "Hz"
				break
			case "seconds":
				newUnits= "Hertz"
			case "m":
				newUnits= "1/m"
			case "cm":
				newUnits= "1/cm"
				break	
			default:
				newUnits=""
				break	
		endswitch
	endif
	SetScale x, leftx(psd), rightx(psd), newUnits, psd
	// normalize the sum of PSDs
	Variable deltaF= deltax(psd)			// deltaF is the frequency bin width
	Variable norm= 2 / (npsd * npsd * nsegs * winNorm * deltaF)
	psd *= norm
	// Explanation of norm values:
	//	* 2				 		total power = magnitude^2(-f) + magnitude^2(f), and we've only accumulated magnitude^2(f)
	//  / (npsd * npsd * nsegs)	converts to average power
	//	/ winNorm				compensates for power lost by windowing the time data.
	//	/ deltaF					converts power to power density (per Hertz)

	psd[0] /= 2			// we're not missing 1/2 the power of DC bin from the two-sided FFT, restore original value
	psd[npsd/2] /= 2	// there aren't two Nyquist bins, either.

	// Parseval's theorem (power in time-domain = power in frequency domain)
	// is satisfied if you compare:
	// time-domain average power ("mean squared amplitude" in Numerical Recipies) = 1/N * sum(t=0...N-1) w[t]^2
	// frequency-domain average power= deltaf * sum(f=0...npsd/2) destw[f]^2
	
	KillWaves/Z tmp, win
	
	return NameOfWave(psd)	// in the current data folder
End


// returns the frequency at which the cumulative power spectrum of theWave crossed the requested pctile
Function pctilepower (theWave, pctile)
	WAVE theWave
	variable pctile

	variable putmeback = 0
	//if input wave scaling is in ms, fix to seconds
	if (stringmatch(waveunits(theWave,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(theWave,0)/1000), (dimdelta(theWave,0)/1000), "s",theWave
		putmeback = 1
	endif
	
	// periodo (add window?)
	DSPperiodogram theWave
	WAVE W_periodogram

	// turn into cumulative
	Integrate W_periodogram/D=theresult
	
	// drop resolution
	// get x-label of the last point
	Variable lastx = pnt2x(W_Periodogram, numpnts(W_Periodogram)-1)
	
	make/n=(lastx) result_1Hzresolution
	setscale/p x,0,1,"Hz", result_1Hzresolution
	result_1Hzresolution = theresult[x2pnt(theresult,p)]
	
	// normalize
	result_1Hzresolution /= (result_1Hzresolution[numpnts(result_1Hzresolution)-1])

	// find level
	findlevel/Q/EDGE=1 result_1Hzresolution, pctile/100
	
	// put the input wave back the way I found it
	if (putmeback)	
		setscale/p x (dimoffset(theWave,0)*1000), (dimdelta(theWave,0)*1000), "ms",theWave	
	endif
	
	//killwaves theresult, W_periodogram
	
	return V_levelX
	
end

// returns the frequency at which the cumulative power spectrum of theWave crossed the requested pctile
Function makeperiodogram (theWave, highcut, ADbitvolts,pctile)
	WAVE theWave
	variable ADbitvolts, pctile,highcut

	variable putmeback = 0
	//if input wave scaling is in ms, fix to seconds
	if (stringmatch(waveunits(theWave,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(theWave,0)/1000), (dimdelta(theWave,0)/1000), "s",theWave
		putmeback = 1
	endif
	
	// periodo (add window?)
	DSPperiodogram theWave
	WAVE W_periodogram
	
	if (WaveExists ($(nameofwave(theWave) +"_per")))
		killwaves $(nameofwave(theWave) +"_per")
	endif
		
	rename W_periodogram $(nameofwave(theWave)+"_per")
	
	WAVE W_per = $(nameofwave(theWave)+"_per")
	
	// truncate the periodogram to the frequencies of interest
	variable lastpoint = x2pnt(W_per, highcut)
	deletepoints lastpoint+1, numpnts(W_per)-lastpoint+1, W_per
	
	// turn the periodogram into Volts^2 by multiplying by ADBitVolts^2
	W_per *= (ADbitvolts)^2
	
	// periodogram is going to have half the number of points as the input wave
	// what should the rebin factor be?
	// I'd prefer 1000, but not if it gives me less than one point per Hz
	// just do 1000 for now
	
	rebin (W_per,1000)
	WAVE W_periodogram_rebin = $(nameofwave(theWave)+"_per_rebin")

	// turn into cumulative
	Integrate W_periodogram_rebin/D=$(nameofwave(theWave)+"_per_rebin_cumu")
	WAVE cumuperiodogram = $(nameofwave(theWave)+"_per_rebin_cumu")
	
	// normalize
	duplicate/O cumuperiodogram  $(nameofwave(theWave)+"_per_rebin_cumu_norm")
	WAVE cumuperidogram_norm =   $(nameofwave(theWave)+"_per_rebin_cumu_norm")
	
	cumuperidogram_norm /= (cumuperidogram_norm[numpnts(cumuperidogram_norm)-1])

	// find level
	findlevel/Q/EDGE=1 cumuperidogram_norm, pctile/100
	
	// put the input wave back the way I found it
	if (putmeback)	
		setscale/p x (dimoffset(theWave,0)*1000), (dimdelta(theWave,0)*1000), "ms",theWave	
	endif
	
	
	// report
	printf "%s\r", nameofwave(theWave)
	printf "total magnitude up to 12 kHz = %10f\r", cumuperiodogram[numpnts(cumuperiodogram)-1]
	printf " freeq95 = %f\r", V_LevelX
	printf "percent3000Hz = %f\r", cumuperidogram_norm(3000)
	
end

// returns the frequency at which the cumulative power spectrum of theWave crossed the requested pctile
Function makePSD(theWave, highcut, ADbitvolts,pctile, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
	WAVE theWave
	variable ADbitvolts, pctile,highcut,PSDsegmentpoints, PSDremoveDC
	string PSDwindowname

	variable putmeback = 0
	//if input wave scaling is in ms, fix to seconds
	if (stringmatch(waveunits(theWave,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(theWave,0)/1000), (dimdelta(theWave,0)/1000), "s",theWave
		putmeback = 1
	endif
	
	// periodo (add window?)
	WAVE W_PSD = $(fPowerSpectralDensity(theWave, PSDsegmentpoints, PSDwindowname, PSDremoveDC))
	
	// truncate the periodogram to the frequencies of interest
	variable lastpoint = x2pnt(W_PSD, highcut)
	deletepoints lastpoint+1, numpnts(W_PSD)-lastpoint+1, W_PSD
	
	// turn the periodogram into Volts^2 by multiplying by ADBitVolts^2
	W_PSD *= (ADbitvolts)^2
	
	SetScale d 0,0,"V^2", W_PSD
	
	// periodogram is going to have half the number of points as the input wave
	// what should the rebin factor be?
	// I'd prefer 1000, but not if it gives me less than one point per Hz
	// just do 1000 for now

	// turn into cumulative
	Integrate W_PSD/D=$(nameofwave(W_PSD)+"_cumu")
	WAVE cumuperiodogram = $(nameofwave(W_PSD)+"_cumu")
	
	// normalize
	duplicate/O cumuperiodogram  $(nameofwave(theWave)+"_cumu_norm")
	WAVE cumuperidogram_norm =   $(nameofwave(theWave)+"_cumu_norm")
	
	cumuperidogram_norm /= (cumuperidogram_norm[numpnts(cumuperidogram_norm)-1])
	SetScale d 0,0,"", cumuperidogram_norm

	// find level
	findlevel/Q/EDGE=1 cumuperidogram_norm, pctile/100
	
	// put the input wave back the way I found it
	if (putmeback)	
		setscale/p x (dimoffset(theWave,0)*1000), (dimdelta(theWave,0)*1000), "ms",theWave	
	endif
		
	// report
	printf "%s\r", nameofwave(theWave)
	printf "total magnitude up to 12 kHz = %10e\r", cumuperiodogram[numpnts(cumuperiodogram)-1]
	printf "freeq95 = %f\r", V_LevelX
	printf "percent3000Hz = %f\r", cumuperidogram_norm(3000)
	
end

// returns the frequency at which the cumulative power spectrum of theWave crossed the requested pctile
Function/S makePSDonly(theWave, namesuffix, ADbitvolts, highcut, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
	WAVE theWave
	variable ADbitvolts,PSDsegmentpoints, PSDremoveDC, highcut
	string PSDwindowname,namesuffix

	variable putmeback = 0
	//if input wave scaling is in ms, fix to seconds
	if (stringmatch(waveunits(theWave,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(theWave,0)/1000), (dimdelta(theWave,0)/1000), "s",theWave
		putmeback = 1
	endif
	
	// periodo (add window?)
	string PSDname = fPowerSpectralDensity_gc(theWave, PSDsegmentpoints, namesuffix,PSDwindowname, PSDremoveDC)
	WAVE W_PSD = $PSDname
	
	// truncate the periodogram to the frequencies of interest
	variable lastpoint = x2pnt(W_PSD, highcut)
	deletepoints lastpoint+1, numpnts(W_PSD)-lastpoint+1, W_PSD
	
	// turn the periodogram into Volts^2 by multiplying by ADBitVolts^2
	W_PSD *= (ADbitvolts)^2
	
	SetScale d 0,0,"V^2", W_PSD

	// put the input wave back the way I found it
	if (putmeback)	
		setscale/p x (dimoffset(theWave,0)*1000), (dimdelta(theWave,0)*1000), "ms",theWave	
	endif
	
	return PSDname
		
end

Function makeallPSDs(matchstring, numwaves, namesuffix, highcut, pctile, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
	string matchstring, namesuffix,PSDwindowname
	variable highcut,pctile,PSDsegmentpoints, PSDremoveDC, numwaves
	
	variable i
	string nextchannelname,nextPSDname
	
	for (i=0; i < numwaves; i += 1)
		
		nextchannelname = matchstring + num2str(i+1)
		WAVE nextchannel = $nextchannelname
		
		if (WaveExists(nextchannel))
		
			// get ADbitvolts here
			WAVE/T nextchannelheader = $("root:headers_file:"+nextchannelname)
		
			printf "computing PSD from %s...\r", nextchannelname
			nextPSDname = makePSDonly(nextchannel, namesuffix, ADbitvoltsfromcheetahheader2(nextchannelheader), highcut, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
		
		else
			printf "missing wave %s\r", nextchannelname
		endif
				
	endfor

end

// using the same value of ADbitvolts for everywhere
Function getwavemakePSD (channelname, highcut, ADbitvolts, pctile, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
	string channelname
	variable highcut, ADbitvolts, pctile, PSDsegmentpoints, PSDremoveDC
	string PSDwindowname
	
	string preprocess = "HIpass"
	string mouseID = uptowhatever(afterwhatever(getdatafolder(1),"root:"),":",searchfrontwards=1)
	
	print mouseID
	
	// need a path
	newpath/o rawpxp, ("NIPEPHYS:PREPROCESSED DATA:"+preprocess+":"+mouseID)

	string nextpxpname = replacestring("'",getdatafolder(0) +"_HI_NIP.pxp","")
	
	loaddata/Q/P=rawpxp/S="data_records"/O/J=channelname nextpxpname

	makePSD($channelname, highcut, ADbitvolts,pctile, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
	
	killwaves $channelname

end

Function cumunormPSD(PSDwave)
	WAVE PSDwave	
	
	
	duplicate/o $nameofwave(PSDwave) $(replacestring("_psd",nameofwave(PSDwave) ,"_psd_RAW"))
	WAVE PSDraw = $(replacestring("_psd",nameofwave(PSDwave) ,"_psd_RAW"))
	killwaves PSDwave
			
	integrate PSDraw/D=$(nameofwave(PSDraw)+"_cu")
	WAVE PSDraw_cumu = $(nameofwave(PSDraw)+"_cu")	
	
	duplicate/o PSDraw_cumu $(nameofwave(PSDraw_cumu)+"_n")
	WAVE PSDraw_cumu_norm = $(nameofwave(PSDraw_cumu)+"_n")
	
	PSDraw_cumu_norm /= PSDraw_cumu_norm[numpnts(PSDraw_cumu_norm)-1]	
	SetScale d 0,0,"", PSDraw_cumu_norm
		
end

Function doCoherence (wave1, wave2, pointspersegment, overlappoints, window, namesuffix, outputresolution_Hz)
	WAVE wave1,wave2
	variable pointspersegment, overlappoints, outputresolution_Hz
	string window,namesuffix
	
	string prestring = "ch"+replacestring("HI_NIP", nameofwave(wave1),"") + "vsch" + replacestring("HI_NIP", nameofwave(wave2),"") + "_"

	variable putmeback1, putmeback2,putdimensionback1,putdimensionback2 = 0
	//if input wave scaling is in ms, fix to seconds
	if (stringmatch(waveunits(wave1,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(wave1,0)/1000), (dimdelta(wave1,0)/1000), "s",wave1
		putmeback1 = 1
	endif
	
	if (stringmatch(waveunits(wave2,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(wave2,0)/1000), (dimdelta(wave2,0)/1000), "s",wave2
		putmeback2 = 1
	endif
	
	if (WaveType(wave1) != 2)
		redimension/s wave1
		putdimensionback1 = 1
	endif

	if (WaveType(wave2) != 2)
		redimension/s wave2
		putdimensionback2 = 1
	endif
	
	// compute the cross-spectral density
	//DSPperiodogram/COHR/SEGN={(pointspersegment),(overlappoints)} wave1, wave2
	DSPperiodogram/COHR/SEGN={(pointspersegment),(overlappoints)} wave1, wave2
	WAVE W_periodogram
	
	// break out into full-resolution magnitude and phase
	MatrixOP/O mscoherence=magsqr(W_Periodogram)
	WAVE mscoherence
	
	MatrixOP/O crossspectralphase=phase(W_Periodogram)
	WAVE crossspectralphase

	// bin these into desired resolution and scale appropriately
	variable frequencyrange = dimoffset(W_periodogram,0)+numpnts(W_periodogram)*dimdelta(W_periodogram,0)
	variable fullresdelta =  dimdelta(W_periodogram,0)
	variable scalefactor = outputresolution_Hz/fullresdelta
	
	variable outputpoints = frequencyrange/outputresolution_Hz
	make/o/n=(outputpoints) $(prestring+"mscoherence_binned") /WAVE=mscoherence_binned
	make/o/n=(outputpoints) $(prestring+"CSphase_binned") /WAVE=CSphase_binned

	setscale/p x 0,outputresolution_Hz, "Hz", mscoherence_binned, CSphase_binned

	mscoherence_binned = sum(mscoherence,p*scalefactor, (p+1)*scalefactor-1)/scalefactor
	csphase_binned = sum(crossspectralphase,p*scalefactor, (p+1)*scalefactor-1)/scalefactor
	
	// put the input wave back the way I found it
	if (putmeback1)	
		setscale/p x (dimoffset(wave1,0)*1000), (dimdelta(wave1,0)*1000), "ms",wave1	
	endif
	
	if (putmeback2)	
		setscale/p x (dimoffset(wave2,0)*1000), (dimdelta(wave2,0)*1000), "ms",wave2	
	endif
	
	if (putdimensionback1)
		redimension/w wave1
	endif
	
	if (putdimensionback2)
		redimension/w wave2
	endif
		
	
	// display
	string windowname = "coherence_"+prestring
	dowindow/f $windowname
	if (!V_flag)
	
		display mscoherence_binned;
		setaxis left 0,1
		appendtograph/r CSphase_binned
		setaxis right -0.1,0.1
		ModifyGraph lsize=0.5
		ModifyGraph rgb[0]=(0,0,0),rgb[1]=(0,0,65535)
		dowindow/c $windowname
		
	endif
		
	// cleanup
	//killwaves W_periodogram, mscoherence, crossspectralphase
	
end

Function doCoherence2 (wave1, wave2, pointspersegment, overlappoints, windowtype, namesuffix, minoutputresolution_Hz,displayresults)
	WAVE wave1,wave2
	variable pointspersegment, overlappoints, minoutputresolution_Hz, displayresults
	string windowtype,namesuffix
	
	string prestring = "ch"+replacestring("HI_NIP", nameofwave(wave1),"") + "vsch" + replacestring("HI_NIP", nameofwave(wave2),"") + "_"

	// if waves differ in length by < 10%, truncate one to match the other (and note it to log)
	//	by more than 10%, return an error code
	variable wave1length = numpnts(wave1)
	variable wave2length = numpnts(wave2)
	variable reclengthdifference = wave1length - wave2length
	
	if (abs(reclengthdifference) > 0)
	
		variable fractionaldifference = (reclengthdifference > 0 ) ? reclengthdifference/wave1length : -1*reclengthdifference/wave2length
		
		// HARD-CODED 10% LIMIT
		if (fractionaldifference < 0.1)
			printf "expected equal length waves but %s and %s differ in length by less than 10 percent\rtruncating the shorter one before running DSPPeriodogram\r", nameofwave(wave1), nameofwave(wave2)
			equalizewavelengths(wave1, wave2)
		else
			printf "uh-oh. expected equal length waves but %s and %s differ in length by more than 10 percent\rcould not run doCoherence2\r", nameofwave(wave1), nameofwave(wave2)
			return 0
		endif
	endif
	
	// even when lengths are fixed sometimes the x-scaling is off for some reason?
	variable wave1xoffset = dimoffset(wave1,0)
	variable wave2xoffset = dimoffset(wave2,0)
	if (abs(wave1xoffset-wave2xoffset) > 0)
		printf "\r  detected x-scaling offset difference of %d between %s and %s\rsetting them both to the lower value to allow DSPperiodogram to proceed\r", (wave1xoffset-wave2xoffset), nameofwave(wave1), nameofwave(wave2)
		if (wave1xoffset < wave2xoffset)
			setscale/p x, wave1xoffset, dimdelta(wave2,0), wave2
		elseif (wave2xoffset < wave1xoffset)
			setscale/p x, wave2xoffset, dimdelta(wave1,0), wave1
		endif
	endif

	variable putmeback1, putmeback2,putdimensionback1,putdimensionback2 = 0
	//if input wave scaling is in ms, fix to seconds
	if (stringmatch(waveunits(wave1,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(wave1,0)/1000), (dimdelta(wave1,0)/1000), "s",wave1
		putmeback1 = 1
	endif
	
	if (stringmatch(waveunits(wave2,0),"ms"))		
		// reduce start and delta by a factor of 1000
		setscale/p x (dimoffset(wave2,0)/1000), (dimdelta(wave2,0)/1000), "s",wave2
		putmeback2 = 1
	endif
	
	if (WaveType(wave1) != 2)
		redimension/s wave1
		putdimensionback1 = 1
	endif

	if (WaveType(wave2) != 2)
		redimension/s wave2
		putdimensionback2 = 1
	endif
	
	// compute the cross-spectral density
	//DSPperiodogram/COHR/SEGN={(pointspersegment),(overlappoints)} wave1, wave2
	
	if (strlen(windowtype) == 0)
		DSPperiodogram/COHR/SEGN={(pointspersegment),(overlappoints)}  wave1, wave2
	else	
		//print "hey\r"
		
		//DSPperiodogram/COHR/Win=Hamming/SEGN={(pointspersegment),(overlappoints)}  wave1, wave2
	
		string cmd = "DSPperiodogram/COHR/Win="+windowtype+"/SEGN={("+num2str(pointspersegment)+"),("+num2str(overlappoints)+")}  "+nameofwave(wave1)+","+nameofwave(wave2)
		execute cmd
	endif
	
	//DSPperiodogram/COHR/Win=Hamming/SEGN={(pointspersegment),(overlappoints)}  wave1, wave2

	WAVE W_periodogram
	WAVE W_bias
	
	// matrixOP does not support wavescaling, so get wave scaling info here in order to reapply it after MatrixOP
	variable W_periodogram_offset = dimoffset(W_periodogram,0)
	variable W_periodogram_delta = dimdelta(W_periodogram,0)
	
	// break out into full-resolution magnitude and phase
	MatrixOP/O mscoherence=magsqr(W_Periodogram)
	WAVE mscoherence
	
	MatrixOP/O crossspectralphase=phase(W_Periodogram)
	WAVE crossspectralphase
	
	setscale/p x, W_periodogram_offset, W_periodogram_delta, mscoherence, crossspectralphase

	// new plan for binning the periodogram output
	
	//  FACT: you can't specify the exact output resolution and the input sampling rate and the window size.
	//  not all of these things are compatible given that this is not properly understood as a continuous function.
	//  what we can do is treat the input as a minimum.  we will bin at least to that level and it may be a little more, depending on things

	// number of points in the window sets the output wave number of points
	// sampling rate in the window sets the output range
		
	// get the range and delta of the periodogram output
	variable frequencyrange = dimoffset(W_periodogram,0)+numpnts(W_periodogram)*dimdelta(W_periodogram,0)
	variable fullresdelta =  dimdelta(W_periodogram,0)
	
	// key question: how does the fullresdelta compare to the requested resolution?
	if (minoutputresolution_Hz	 <= fullresdelta)
		printf "min resolution requested is finer than or equal to the periodogram output - sticking with periodogram output resolution\r"
	endif
	
	// otherwise outputresolution is > fullresdelta
	// find whole number multiple of fullresdelta that gets us over outputresolution
	variable scalefactor = ceil(minoutputresolution_Hz/fullresdelta)
	variable actualoutputresolution = scalefactor*fullresdelta
	
	printf "periodogram output resolution is %g\r  scaling to %g to get over minimum requested\r  scalefactor of %d\r", fullresdelta, actualoutputresolution,scalefactor
	
	// e.g. if fullresdelta is 0.8 and min output resolution is 2
	// scale factor is 3 and actual output resolution is 2.4
	
	// so. divide the frequency range by my desired bin size and take the floor (so that we exclude the remainder) - 
	variable outputpoints = floor(numpnts(W_periodogram)/scalefactor)
	variable outputscale = actualoutputresolution
	
	make/o/n=(outputpoints) $(prestring+"mscoherence_binned") /WAVE=mscoherence_binned
	make/o/n=(outputpoints) $(prestring+"CSphase_binned") /WAVE=CSphase_binned

	setscale/p x 0,outputscale, "Hz", mscoherence_binned, CSphase_binned
	
	// now we can do the wave assignment.  since destination index controls the assignment we won't have remainder
	 mscoherence_binned = sum(mscoherence,pnt2x(mscoherence,p*scalefactor), pnt2x(mscoherence,(p+1)*scalefactor - 1))/scalefactor
	 csphase_binned = sum(crossspectralphase,pnt2x(mscoherence,p*scalefactor), pnt2x(mscoherence,(p+1)*scalefactor - 1))/scalefactor
	
	//mscoherence_binned = sum(mscoherence,
	
	
	// put the input wave back the way I found it
	if (putmeback1)	
		setscale/p x (dimoffset(wave1,0)*1000), (dimdelta(wave1,0)*1000), "ms",wave1	
	endif
	
	if (putmeback2)	
		setscale/p x (dimoffset(wave2,0)*1000), (dimdelta(wave2,0)*1000), "ms",wave2	
	endif
	
	if (putdimensionback1)
		redimension/w wave1
	endif
	
	if (putdimensionback2)
		redimension/w wave2
	endif
		
	
	// display
	if (displayresults)
		string windowname = "coherence_"+prestring
		dowindow/f $windowname
		if (!V_flag)
		
			display mscoherence_binned;
			setaxis left 0,1
			appendtograph/r CSphase_binned
			setaxis right -0.1,0.1
			ModifyGraph lsize=0.5
			ModifyGraph rgb[0]=(0,0,0),rgb[1]=(0,0,65535)
			dowindow/c $windowname
		
		endif
	endif
	
	// cleanup
	killwaves W_periodogram, W_bias, mscoherence, crossspectralphase
	
	return 1
	
end

// makeallPSDs(matchstring, numwaves, namesuffix, highcut, pctile, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
Function makeallRunningPower(matchstring, numwaves, namesuffix, windowlength_s, window_overlap_pct, spikebandLOW, spikebandHIGH,  highcut, PSDwindowname, PSDremoveDC)
	string matchstring, namesuffix,PSDwindowname
	variable highcut, PSDremoveDC, numwaves, windowlength_s, window_overlap_pct, spikebandLOW, spikebandHIGH
	
	variable i
	string nextchannelname,nextrunningpowername
	
	for (i=0; i < numwaves; i += 1)
		
		nextchannelname = matchstring + num2str(i+1)
		WAVE nextchannel = $nextchannelname
		
		if (WaveExists(nextchannel))
		
			// get ADbitvolts here
			WAVE/T nextchannelheader = $("root:headers_file:"+nextchannelname)
		
			printf "computing runningpower from %s...\r", nextchannelname
			nextrunningpowername = runningpower(windowlength_s, window_overlap_pct, nextchannel, spikebandLOW, spikebandHIGH, namesuffix, highcut, PSDwindowname, PSDremoveDC)
		
		else
			printf "missing wave %s\r", nextchannelname
		endif
				
	endfor

end

Function/S RunningPower (windowlength_s, window_overlap_pct, theWave, spikebandLOW, spikebandHIGH, namesuffix, highcut, PSDwindowname, PSDremoveDC)
	Variable  spikebandLOW, spikebandHIGH, windowlength_s, window_overlap_pct, highcut, PSDremoveDC
	Wave thewave	
	string PSDwindowname,namesuffix
	
	variable overlap_length_s = windowlength_s*window_overlap_pct
	
	variable windowlength_pts = windowlength_s/(dimdelta(theWave,0)/1000)
	variable overlap_length_pts = overlap_length_s/(dimdelta(thewave,0)/1000)

	WAVE/T headerwave = $("::headers_file:"+nameofwave(thewave))
	variable ADbitvolts = ADBitVoltsFromCheetahheader2 (headerwave)
	
	
	variable length = numpnts(thewave)
	variable length_s = length*dimdelta(thewave,0)/1000

	// how many points in output, assuming no overlap?
	// variable numwindows = floor(length_s/windowlength_s),i, center
	
	// how many points in output, accounting for overlap?
	variable numwindows = floor((length - overlap_length_pts)/(windowlength_pts - overlap_length_pts)),i,center
	

	// make the output
	make/n=(numwindows)/O $(nameofwave(theWave) +namesuffix)
	WAVE runningoutput = $(nameofwave(theWave)+namesuffix)
	Note runningoutput, ("WINDOWLENGTH_S:"+num2str(windowlength_s)+";WINDOW_OVERLAP_PCT:"+num2str(window_overlap_pct)+";SPIKEBANDLOW:"+num2str(spikebandLOW)+";SPIKEBANDHIGH:"+num2str(spikebandHIGH)+";PSDWINDOWNAME:"+PSDwindowname+";PSDremoveDC:"+num2str(PSDremoveDC)+";")
	
	// make the segment holder and scale it in ms
	make/O/n=(windowlength_pts) segmentholder
	setscale/p x, 0, dimdelta(thewave,0), "ms", segmentholder
	string PSDname
	
	// for each point in output
	for (i=0; i < numwindows; i += 1)

		center = windowlength_pts/2 + i*(windowlength_pts-overlap_length_pts)
		segmentholder = theWave[(center - windowlength_pts/2) + p]

		// PSDname = makePSDonly(nextchannel, "_psd_reref", 12000, ADbitvoltsfromcheetahheader2(nextchannelheader),95, 10*32000, "Welch", 0)
		// makePSDonly(theWave, namesuffix, ADbitvolts, highcut, PSDsegmentpoints, PSDwindowname, PSDremoveDC)
		PSDname  = makePSDonly(segmentholder, "test", ADbitvolts, 12000, windowlength_pts, "Welch", 0)
		
		WAVE nextPSD = $PSDname
		runningoutput[i] = sum(nextPSD, spikebandlow, spikebandhigh)
		
		doupdate
		
		WAVE nextPSD = $""
	endfor
	
	// set output scaling so that each point is at the center of the range it's computed from
	// need offset from the input wave
	variable waveoffset = DimOffset(theWave, 0)
	
	setscale/p x, waveoffset +(windowlength_s*1000)/2, (windowlength_s - windowlength_s*window_overlap_pct)*1000, "ms", runningoutput
	
	// kill the segment holder
	
	return nameofwave(runningoutput)
	
end


Function EvaluateRunningPower (windowlength_s, window_overlap_pct, theWave, spikebandLOW, spikebandHIGH, thresh)
	Variable windowlength_s, window_overlap_pct, spikebandLOW, spikebandHIGH, thresh
	WAVE theWave
	
	string runningpowername = RunningPower (windowlength_s, window_overlap_pct, theWave, spikebandLOW, spikebandHIGH, "yuyu", 12000, "Welch", 0)
	WAVE runningpower = $runningpowername
	
	duplicate/o runningpower runningpower_thresh
	
	runningpower_thresh[] = (runningpower[p] > thresh) ? 1 : 0

	variable numabove = sum(runningpower_thresh)
	return numabove/numpnts(runningpower)


end

