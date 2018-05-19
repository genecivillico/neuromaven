#pragma rtGlobals=1		// Use modern global access method.

// functions that operate on spike data 

Function setup1 (num, channelstring)
	variable num
	string channelstring
	
	variable i
	
	edit
	string name
	for (i=0; i < num; i += 1)
	
		name = channelstring+"timestamps_0"+num2str(i+1)
		make/n=10/D $name
		WAVE next = $name
	
		appendtotable next
	
	endfor
	
end

Function pareall (num, channelstring)
	variable num
	string channelstring

	variable i
	
	setdatafolder root:SEdata
	
	string name	
	string nextparedSEfolderID
	
	
	WAVE headrec = $("HI_"+channelstring+"_rAVG_SD3_SEheadrec")
	WAVE headfile = $("HI_"+channelstring+"_rAVG_SD3_SEheadfile")
	WAVE datarec =  $("HI_"+channelstring+"_rAVG_SD3_SEdatarec")
	
	for (i=0; i < num; i += 1)
	
		name = channelstring+"timestamps_0"+num2str(i+1)
		WAVE next = $("root:"+name)
				
		nextparedSEfolderID = name
		
		pareSEdata (headrec, headfile, datarec, next,nextparedSEfolderID)
	
	endfor

end



Function Vpp_amplitude_histogram (SEheadrec, prefix)
	WAVE SEheadrec
	string prefix
	
	variable numrecs = dimsize(SEheadrec,1),i
	make/O/n=(numrecs) $(prefix+"_Vpp_amplitudes")/WAVE=Vpp_amplitudes
	
	Vpp_amplitudes = SEheadrec[8][p] - SEheadrec[10][p]
	
	// this value is in AD counts
	// convert to uVolts
	
	WAVE/T SEheadfile = $(replacestring("SEheadrec",nameofwave(SEheadrec),"SEheadfile"))
	
	variable ADbitvolts = str2num(replacestring("-ADBitVolts ",SEheadfile[15],""))
	// convert to Volts
	Vpp_amplitudes *= ADbitvolts
	
	// convert to uV
	Vpp_amplitudes *= 1000000
		
	// histogram
	make/o/n=1000 $(prefix+"_Vpp_amplitudes_hist")/WAVE=Vpp_amplitudes_hist
	histogram/b={0,1,1000} Vpp_amplitudes Vpp_amplitudes_hist
	
end

// annotated Sept '16
Function pareSEdata (SEheadrec, SEheadfile, SEdatarec, goodtimestamps,SEsuffix)
	WAVE SEheadrec, SEdatarec, goodtimestamps
	WAVE/T SEheadfile
	string SEsuffix
	
	// needed params from headfile
	variable windowsize = str2num(replacestring("-WaveformLength ",SEheadfile[31],""))
	
	string channelprefix = "HI_NIP"
	
	string SEheadrecname = nameofwave(SEheadrec)
	string channelnumberstring = betweenbeforeandafter(SEheadrecname, "HI_NIP", "_")
	string channelstring = channelprefix + channelnumberstring
	
	string newdatafoldername = "SEdata_"+SEsuffix
	setdatafolder root:
	newdatafolder/O/s $newdatafoldername
	
	// get all the time stamps
	getALLtimestampfromsignedints(SEheadrec, channelstring)
	WAVE timestamps = $(channelstring+"_timestamps")
	variable startingnumtimestamps = numpnts(timestamps)

	// create timestamps_ingroup, which is the alltimestamps wave converted to 1 if present in goodtimestamps, 0 if not
	duplicate/o timestamps $(nameofwave(timestamps) + "_ingroup")
	WAVE timestamps_ingroup = $(nameofwave(timestamps) + "_ingroup")
	timestamps_ingroup = (ingroup(timestamps_ingroup[p], goodtimestamps)) ? 1 : 0

	// sum the wave
	Variable numingroup = sum(timestamps_ingroup)

	// create the datarec and headrec output waves using that sum
	make/O/i/n=(numingroup*windowsize) $(channelstring+"_"+SEsuffix+"_SEdatarec") /WAVE=newdatarec
	make/O/i/n=(24,numingroup) $(channelstring+"_"+ SEsuffix+"_SEheadrec") /WAVE=newheadrec
	duplicate/o SEheadfile $(channelstring+"_"+SEsuffix+"_SEheadfile") /WAVE=newheadfile
	
	printf "generating new SE folder with %d timestamps selected from %d timestamps using %s\r", numingroup, startingnumtimestamps,nameofwave(goodtimestamps)

	// populate the datarec and headrec output waves
	variable nextdatarow = 0
	variable nextheadercolumn = 0,i
	for (i=0; i < startingnumtimestamps; i += 1)
		
		if (timestamps_ingroup[i])
			
			// i=0: newdatarec[0,31] = SEdatarec[0-0-->31-0]
			// i=1: newdatarec[32,63] = SEdatarec[32+((32-32)-->32+(63-32)]
			newdatarec[nextdatarow,nextdatarow+windowsize-1] = SEdatarec[i*32+(p-nextdatarow)]
			newheadrec[][nextheadercolumn] = SEheadrec[p][i]
			nextdatarow += windowsize
			nextheadercolumn += 1
		endif
		
		// test
		//print i*32

	endfor	
		
	// run Vpp amplitude histogram on the result
	// Vpp_amplitude_histogram(newheadrec, channelstring)

	killwaves/z  timestamps, timestamps_ingroup
	
	// grab the timestamps wave that was used to make this
	movewave goodtimestamps, $(channelstring+"_timestamps")
	
end

// based on pareSEdata, except with the computation of all timestamps deleted.  eventually this function should be called by what is now "pareSEdata"
Function subsetSEdata (SEheadrec, SEheadfile, SEdatarec, timestamps_ingroup, newSEfoldername)
	WAVE SEheadrec, SEdatarec, timestamps_ingroup
	WAVE/T SEheadfile
	string newSEfoldername
	
	// needed params from headfile
	variable windowsize = str2num(replacestring("-WaveformLength ",SEheadfile[31],""))
	
	string channelprefix = "HI_NIP"
	
	string SEheadrecname = nameofwave(SEheadrec)
	string channelnumberstring = betweenbeforeandafter(SEheadrecname, "HI_NIP", "_")
	string channelstring = channelprefix + channelnumberstring
	
	setdatafolder root:
	newdatafolder/O/s $newSEfoldername
		
	// this is original number
	variable startingnumtimestamps = numpnts(timestamps_ingroup)

	// this will be new number
	Variable numingroup = sum(timestamps_ingroup)

	// create the datarec and headrec output waves using that sum to size them
	make/O/i/n=(numingroup*windowsize) $(channelstring+"_SEdatarec") /WAVE=newdatarec
	make/O/i/n=(24,numingroup) $(channelstring+"_SEheadrec") /WAVE=newheadrec
	duplicate/o SEheadfile $(channelstring +"_SEheadfile") /WAVE=newheadfile
	
	printf "generating new SE folder with %d timestamps selected from %d timestamps using %s\r", numingroup, startingnumtimestamps,nameofwave(timestamps_ingroup)

	// index into the new datarec and headrec output waves
	variable nextdatarow = 0
	variable nextheadercolumn = 0,i
	for (i=0; i < startingnumtimestamps; i += 1)
		
		if (timestamps_ingroup[i])
			
			// i=0: newdatarec[0,31] = SEdatarec[0-0-->31-0]
			// i=1: newdatarec[32,63] = SEdatarec[32+((32-32)-->32+(63-32)]
			newdatarec[nextdatarow,nextdatarow+windowsize-1] = SEdatarec[i*32+(p-nextdatarow)]
			newheadrec[][nextheadercolumn] = SEheadrec[p][i]
			nextdatarow += windowsize
			nextheadercolumn += 1
		endif
		
		// test
		//print i*32

	endfor	
		
end

Function ingroup(value, theGRoup)
	Variable value
	Wave theGroup
	
	findvalue/V=(value) theGroup
	
	return (V_value >= 0)
end


// removes 0s which show up for some reason
Function halfit (thewave)
	wave thewave
	
	duplicate/o thewave temp
	
	make/O/D/n=(DimSize(thewave, 0)/2) $(nameofwave(thewave))/WAVE=newwave
	
	newwave = temp[p*2]
	
	deletetail(newwave)
	
	killwaves temp
	
	
end

Function deletetail(newwave)
	WAVE newwave
	
	variable last = (numpnts(newwave) - 1),i
	for(i=last; i > 0; i -= 1)	
		if (newwave[i] > 0)		
			break		
		endif
	endfor
	
	deletepoints/m=0 i+1, numpnts(newwave)-i+1, newwave
	
end


Function averagewindow (inputwave,windowsize)
	wave inputwave
	variable windowsize
	
	
	// these will hold the results
	make/o/n=(windowsize) theAverage
	make/o/n=(windowsize) theSD
	
	variable numsamplesperwindowpoint = (dimsize(inputwave,0)/windowsize)
	variable i,j
		
	// make a wave for every point of the window
	
	for (i=0; i < windowsize; i += 1)
	
		make/o/n=(numsamplesperwindowpoint) $("windowpoint"+num2str(i))/WAVE=nextwindowpoint
		
		
		nextwindowpoint = inputwave[(p*32)+i]
	
	endfor
		
	// loop through the point waves, do stats, plug into output
	for (j=0; j < windowsize; j += 1)
	
		wavestats/q $("windowpoint"+num2str(j))
	
		theAverage[j] = V_avg
		theSD[j] = V_sdev
	
		killwaves/z $("windowpoint"+num2str(j))
		doupdate
	endfor
	
	
	// for display, make the plus/minus
	duplicate/o theAverage theAverageplusSD
	duplicate/o theAverage theAverageminusSD
//	
	theAverageplusSD += theSD
	theAverageminusSD -= theSD
	
	display theAverageminusSD, theAverageplusSD, theAverage
	ModifyGraph mode(theAverageminusSD)=7,lsize(theAverageminusSD)=0.25;DelayUpdate
	ModifyGraph hbFill(theAverageminusSD)=4,toMode(theAverageminusSD)=1;DelayUpdate
	ModifyGraph lsize(theAverageplusSD)=0.25
	
	//big
	setaxis left -9000, 11000
	
	modifygraph nolabel=1,axthick=0
end

Function massivetracedisplay (wavetodisplay)
	WAVE wavetodisplay
	
	variable windowsize = 32, i
	variable numdisplays = numpnts(wavetodisplay)/32
	
	variable shiftincrement = windowsize*dimdelta(wavetodisplay,0)
	
	display
	for (i=0; i < numdisplays; i += 1)
		appendtograph wavetodisplay
		
		modifygraph offset[i] = {-1*i*shiftincrement,0}
	
	endfor
	
	setaxis bottom 0,31
end

Function displayallspikes (SEdatarec, windowsize)
	WAVE SEdatarec
	variable windowsize
	
	string windowname = Getdatafolder(0)
	
	display
	variable numsnippets = numpnts(SEdatarec)/windowsize,i

	for (i=0; i < numsnippets; i += 1)

		make/o/n=(windowsize) $("s_"+num2str(i))
		WAVE nextsnip = $("s_"+num2str(i))
		nextsnip= SEdatarec[i*32+p]
		appendtograph nextsnip

	endfor
	modifygraph lsize=0.2,rgb=(0,0,0)
	dowindow/c $windowname

end

Function batch_displayallspikes (windowsize)
	variable windowsize
	
	setdatafolder root:
	// list data folders	
	string theFolders = folderlist ("mouse*", ";", "")
	variable numfolders = itemsinlist(theFolders),i
	string nextfoldername, nextwavename
	
	// iterate through data folders
	for (i=0; i < numfolders; i += 1)
	
		nextfoldername = stringfromlist(i, theFolders)
		print nextfoldername
	
		// change to data folder
		setdatafolder $nextfoldername
		
		// find the data rec wave (there should be only one)
		nextwavename = wavelist("*datarec","","")
		WAVE nextwave = $nextwavename
		
		// displayallspikes on it
		displayallspikes(nextwave,windowsize)
	
		setdatafolder root:
		
	endfor
	
end

// selectpass = 1
Function selecttimestamps (prefix, selectpass, saturationthreshold,saturationtolerance,prebaselinetolerance, postbaselinetolerance,paresuffix)
	string prefix,paresuffix
	variable prebaselinetolerance, postbaselinetolerance,selectpass,saturationthreshold,saturationtolerance
	
	WAVE SEheadfile = $(prefix+"_SEheadfile")
	WAVE SEheadrec = $(prefix+"_SEheadrec")
	WAVE SEdatarec = $(prefix+"_SEdatarec")
	
	variable datalength = numpnts(SEdatarec)
	
	make/n=(datalength/32)/o segmentpasses_saturation = 0
	make/n=(datalength/32)/o segmentpasses_jumptest = 0
	make/n=(datalength/32)/o segmentpasses_spikefilter = 0
	make/n=(datalength/32)/o segmentpasses = 0

	variable i
	
	// hop along datarec,1 segment at a time
	// need to fix this so it doesn't retest once something fails
	for (i=0; i <= (datalength-32); i += 32)
	
		
		segmentpasses_saturation[i/32] = saturationtest(SEdatarec,saturationthreshold,saturationtolerance,i,i+31)
		//segmentpasses_saturation[i/32] = peaktest(SEdatarec,i,i+31)
		
		// if it fails on saturation, we're done
		if (!segmentpasses_saturation[i/32])		
			//printf "segment starting at %d fails on saturation\r", i			
		else
			// if passes saturation, do jumptest
			segmentpasses_jumptest[i/32] = jumptest(SEdatarec,10000,i,i+31)
			// if fails, we're done
			if (!segmentpasses_jumptest[i/32])	
				//printf "segment starting at %d fails on jumptest\r", i			
			else			
				// if it passes, do spikefilter
				segmentpasses_spikefilter[i/32] = spikefiltertest3 (SEdatarec, prebaselinetolerance, postbaselinetolerance, i, i+31)
				
				// if it fails, we're done
				if (!segmentpasses_spikefilter[i/32])		
					//printf "segment starting at %d fails on spikefilter\r", i			
				else
					// if it passes, we've passed everything!
					segmentpasses[i/32] = 1
				endif
			endif
		endif
		
		if (!mod(i/32,1000))
			print i
		endif
	endfor
			
	// now we have a yes/no wave describing the saturation
	printf "%d segments passed out of %d total segments\r", sum(segmentpasses),numpnts(segmentpasses)
	
	//abort
	
	// make list of all timestamps
	getalltimestampfromsignedints(SEheadrec,"good")
	WAVE good_timestamps
	
	// convert this into a list of good timestamps and hand that off to pareSEdata
	if (selectpass)
		good_timestamps = (segmentpasses[p]) ? good_timestamps[p] : nan
	else
		good_timestamps = (!segmentpasses[p]) ? good_timestamps[p] : nan
	endif	
	
	removenans(good_timestamps) 
	
	pareSEdata (SEheadrec, SEheadfile, SEdatarec, good_timestamps,paresuffix)

end


Function saturationtest (wavetotest, threshold, tolerance, start, stop)
	WAVE wavetotest
	variable threshold, start, stop, tolerance
	
	variable length = numpnts(wavetotest),i, count = 0
	
	for(i=start; i <=stop; i+=1)
	
		if ((wavetotest[i] > threshold) || (wavetotest[i] < threshold*-1))
			count += 1
		endif
		
		if (count > tolerance)
			return 0
		endif	
	
	endfor
	
	return 1
	
end

Function jumptest (wavetotest, jumpthreshold, start, stop)
	WAVE wavetotest
	variable jumpthreshold, start, stop
	
	variable length = numpnts(wavetotest),i, count = 0
	
	for(i=start+1; i <= stop; i+=1)
	
		if ((wavetotest[i] - wavetotest[i-1]) > jumpthreshold)
			return 0
		endif

	endfor
	
	return 1
	
end

Function peaktest (wavetotest, start, stop)
	WAVE wavetotest
	variable start, stop
	
	variable length = numpnts(wavetotest),i, count = 0
	
	wavestats/r=[start,stop]/Q wavetotest
	
	return (V_maxloc == (start+7))
	
end

Function spikestarttest (wavetotest, tolerance, start, stop)
	WAVE wavetotest
	Variable tolerance,start,stop
	
	variable length = numpnts(wavetotest),i, count = 0
	
	// test for prebaseline within +/- 1 tolerance
	// median, or average?  length?
	wavestats/R=[start,start+3]/Q wavetotest
	if ((V_avg < -1*tolerance) || (V_avg > 1*tolerance))
		return 0
	endif
	
	return 1
	
end

Function spikefiltertest (wavetotest, prebaselinetolerance, postbaselinetolerance, start, stop)
	WAVE wavetotest
	Variable prebaselinetolerance, postbaselinetolerance,start,stop
	
	variable length = numpnts(wavetotest),i, count = 0
	
	// test for prebaseline within +/- 1 prebaselinetolerance
	wavestats/R=[start,start+3]/Q wavetotest
	 if ((V_avg < -1*prebaselinetolerance) || (V_avg > 1*prebaselinetolerance))
		return 0
	 endif
	Variable baseline = V_avg
	
	// find peak
	wavestats/q/R=[start,stop] wavetotest
	
	if ((V_max - baseline) < 2*postbaselinetolerance)
		return 0
	endif
	
	// if passed prebaseline test, then start at peak and walk forward, if we cross below baseline + 1SD then we pass, return 1
	for (i=(V_maxloc+1); i < stop; i += 1)
	
		if (wavetotest[i] < (baseline + 1*postbaselinetolerance))
			return 1
		endif
	
	endfor
	
	// if we make it out of for loop, that means we passed baseline but failed post-test
	return 0
	
end

// require spike to return to baseline + 1SD before point 20
// and after that, don't allow it to cross baseline + 2SD in the other direction again
Function spikefiltertest2 (wavetotest, prebaselinetolerance, postbaselinetolerance, start, stop)
	WAVE wavetotest
	Variable prebaselinetolerance, postbaselinetolerance,start,stop
	
	variable length = numpnts(wavetotest),i, count = 0, fallpoint
	
	// test for prebaseline within +/- 1 prebaselinetolerance
	wavestats/R=[start,start+3]/Q wavetotest
	 if ((V_avg < -1*prebaselinetolerance) || (V_avg > 1*prebaselinetolerance))
		return 0
	endif
	Variable baseline = V_avg
	
	// find peak
	wavestats/q/R=[start,stop] wavetotest
	
	if ((V_max - baseline) < 2*postbaselinetolerance)
		return 0
	endif
	
	// if passed prebaseline test, then start at peak and walk forward, if we cross below baseline + 1SD then we pass, return 1
	for (i=(V_maxloc+1); i < (start+20); i += 1)
	
		if (wavetotest[i] < (baseline + 1*postbaselinetolerance))
			fallpoint = i
			break
		endif
	
	endfor
	
	// now start at fallpoint and make sure we don't go back above baseline + 2SD
	for (i=fallpoint; i <= stop; i += 1) 
	
		if (wavetotest[i] > (baseline + 2*postbaselinetolerance))
			return 0
		endif
	endfor
	
	// if we make it out of for loop, that means we passed!
	return 1
	
end

// require spike to return to baseline + 1SD before point 20
// and after that, don't allow it to cross baseline + 2SD in the other direction again
Function spikefiltertest3 (wavetotest, prebaselinetolerance, postbaselinetolerance, start, stop)
	WAVE wavetotest
	Variable prebaselinetolerance, postbaselinetolerance,start,stop
	
	variable length = numpnts(wavetotest),i, count = 0, fallpoint
	
	// test for prebaseline within +/- 1 prebaselinetolerance
	wavestats/R=[start,start+1]/Q wavetotest
	 if ((V_avg < -1*prebaselinetolerance) || (V_avg > 1*prebaselinetolerance))
		return 0
	endif
	Variable baseline = V_avg
	
	// find peak
	wavestats/q/R=[start,stop] wavetotest
	
	if ((V_max - baseline) < 2*postbaselinetolerance)
		return 0
	endif

	// two independent FindLevels tests - don't depend on results of each other
	
	// this one first because interval is shorter
	// FindLevel after peak - look for fall crossing of baseline + 1tolerance between peak and 20, if NOT found return 0
	FindLevel/Q/EDGE=2/R=[V_maxloc,start+20] wavetotest, (baseline + 1*postbaselinetolerance)
	if (V_flag)
		return 0
	endif
		
	// FindLevel after peak - look for rise crossing of baseline + 2tolerance after peak if found return 0
	FindLevel/Q/EDGE=1/R=[V_maxloc,stop] wavetotest, (baseline + 2*postbaselinetolerance)
	if (!V_flag)
		return 0
	endif
	
	// if we haven't returned a zero yet, that means we passed!
	return 1
	
end

Function spikefiltertest4 (wavetotest, prebaselinetolerance, postbaselinetolerance, maxspikewidth_pts, start, stop)
	WAVE wavetotest
	Variable prebaselinetolerance, postbaselinetolerance,start,stop, maxspikewidth_pts
	
	variable length = numpnts(wavetotest),i, count = 0, fallpoint
	
	// test for prebaseline within +/- 1 prebaselinetolerance
	wavestats/R=[start,start+1]/Q wavetotest
	 if ((V_avg < -1*prebaselinetolerance) || (V_avg > 1*prebaselinetolerance))
		return 0
	endif
	Variable baseline = V_avg
	
	// find peak
	wavestats/q/R=[start,stop] wavetotest
	
	if (V_maxloc != (start+7))
		return 0
	endif
	
	// peak has to be high enough above baseline
	variable peak = (V_max - baseline)
	if (peak < 2*postbaselinetolerance)
		return 0
	endif

	// find peak width
	// search backwards from peak for peak/2
	Findlevel/q/EDGE=1/R=[V_maxloc,start] wavetotest, (baseline+peak/2)
	Variable halfheight_rising = V_levelX
	if (V_flag)
		return 0
	endif
		
	// this one first because interval is shorter
	// FindLevel after peak - look for fall crossing of baseline + 1tolerance between peak and 20, if NOT found return 0
	Findlevel/q/EDGE=2/R=[V_maxloc,halfheight_rising+maxspikewidth_pts] wavetotest, (baseline+peak/2)
	Variable halfheight_falling = V_levelX
	if (V_flag)
		return 0
	endif

	variable spikewidth = halfheight_falling - halfheight_rising
	if (spikewidth > maxspikewidth_pts)
		return 0
	endif
		
	// FindLevel after peak - look for rise crossing of baseline + 2tolerance after peak if found return 0
	FindLevel/Q/EDGE=1/R=[V_maxloc,stop] wavetotest, (baseline + 2*postbaselinetolerance)
	if (!V_flag)
		return 0
	endif
	
	// if we haven't returned a zero yet, that means we passed!
	return 1
	
end

// second peak OK
// V_maxloc not at [7] OK
Function spikefiltertest5 (wavetotest, prebaselinetolerance, postbaselinetolerance, maxspikewidth_pts, start, stop)
	WAVE wavetotest
	Variable prebaselinetolerance, postbaselinetolerance,start,stop, maxspikewidth_pts
	
	variable length = numpnts(wavetotest),i, count = 0, fallpoint
	
	
	// is baseline within tolerance?
	wavestats/R=[start,start+1]/Q wavetotest
	if ((V_avg < -1*prebaselinetolerance) || (V_avg > 1*prebaselinetolerance))
		return 0
	endif

	variable peak = getspike_peak (0, wavetotest, start)
	if (peak == 0)
		return 0
	endif	

	variable peaktopeak = getspike_peaktopeak (0, wavetotest, start, start+15)

	// check for peak high enough above baseline. if pass, continue.	
	if (peak < 1*postbaselinetolerance)	
		// if positive peak fails on its own, it can still be saved by negative peak
		if (peaktopeak < 2*postbaselinetolerance)
			return 0
		endif
	endif

	// find peak width
	// search backwards from peak for peak/2
	
	// get baseline as average of first two points
	wavestats/R=[start,start+1]/Q wavetotest
	variable baseline = V_avg

	wavestats/q/R=[start,start+15] wavetotest
	Findlevel/q/EDGE=1/R=[V_maxloc,start] wavetotest, (baseline+peak/2)
	Variable halfheight_rising = V_levelX
	if (V_flag)
		return 0
	endif
		
	// this one first because interval is shorter
	// FindLevel after peak - look for fall crossing of baseline + 1tolerance between peak and 20, if NOT found return 0
	Findlevel/q/EDGE=2/R=[V_maxloc,halfheight_rising+maxspikewidth_pts] wavetotest, (baseline+peak/2)
	Variable halfheight_falling = V_levelX
	if (V_flag)
		return 0
	endif

	variable spikewidth = halfheight_falling - halfheight_rising
	if (spikewidth > maxspikewidth_pts)
		return 0
	endif
	
	// if we haven't returned a zero yet, that means we passed!
	WAVE stats
	stats = {peak, peaktopeak}
	return 1
	
end

// only one method for now, but is it the right one?
Function getspike_peak (method, wavetotest, start)
	variable method, start
	WAVE wavetotest
	
	switch (method)
	
		case 0:
			// baseline is avg of first two points		
			wavestats/R=[start,start+1]/Q wavetotest

			Variable baseline = V_avg
	
			// find peak, restricted to first half
			wavestats/q/R=[start,start+15] wavetotest
	
			variable peak = (V_max - baseline)			
			return peak
		
			break
	
	endswitch

end

// only one method for now, but is it the right one?
Function getspike_peaktopeak (method, wavetotest, start, stop)
	variable method, start, stop
	WAVE wavetotest
		
	switch (method)
	
		case 0:
		
			wavestats/q/R=[start,stop] wavetotest
			variable firstmax = V_max

			// find minimum, after peak	
			wavestats/q/R=[V_maxloc,stop] wavetotest
			variable negpostpeak = V_min

			variable peaktopeak = (firstmax - negpostpeak)
			return peaktopeak
		
			break
	
	endswitch
	
end	

// selectpass = 1
// selecttimestamps_twolists is a terrible name for this function.
// here's how this thing works (I think - writing this 5 years after I wrote the function)
//	works from the SEdatarec wave which is all the 32-point spikes concatenated together
//	segment numbers used here are basically the ith waveform in that wave.  it creates two lists of indices based on that numbering scheme.
//	those lists are converted into timestamps by the calling function
Function selecttimestamps_twolists(inputprefix, outputprefix,saturationthreshold,saturationtolerance,prebaselinetolerance, postbaselinetolerance, maxspikewidth_pts)
	string inputprefix, outputprefix
	variable prebaselinetolerance, postbaselinetolerance,saturationthreshold,saturationtolerance,maxspikewidth_pts
	
	WAVE SEheadfile = $(inputprefix+"_SEheadfile")
	WAVE SEheadrec = $(inputprefix+"_SEheadrec")
	WAVE SEdatarec = $(inputprefix+"_SEdatarec")
	
	variable datalength = numpnts(SEdatarec)
	
	make/n=(datalength/32)/o $(outputprefix+"_satpass")/WAVE=segmentpasses_saturation = 0
	make/n=(datalength/32)/o $(outputprefix+"_jumppass")/WAVE=segmentpasses_jumptest = 0
	make/n=(datalength/32)/o $(outputprefix+"_spkpass")/WAVE=segmentpasses_spikefilter = 0
	make/n=(datalength/32)/o $(outputprefix+"_segpass")/WAVE=segmentpasses = 0
	
	make/O/n=2 stats
	make/n=(datalength/32)/o $(outputprefix+"_segpeak1")/WAVE=segmentfirstpeak = 0
	make/n=(datalength/32)/o $(outputprefix+"_segVpp")/WAVE=segmentpeaktopeak = 0
	
	variable i
	
	// hop along datarec,1 segment at a time
	// need to fix this so it doesn't retest once something fails
	for (i=0; i <= (datalength-32); i += 32)	
		
		segmentpasses_saturation[i/32] = saturationtest(SEdatarec,saturationthreshold,saturationtolerance,i,i+31)
		//segmentpasses_saturation[i/32] = peaktest(SEdatarec,i,i+31)
		
		// if it fails on saturation, we're done
		if (!segmentpasses_saturation[i/32])		
			//printf "segment starting at %d fails on saturation\r", i			
		else
			// if passes saturation, do jumptest
			segmentpasses_jumptest[i/32] = jumptest(SEdatarec,10000,i,i+31)
			// if fails, we're done
			if (!segmentpasses_jumptest[i/32])	
				//printf "segment starting at %d fails on jumptest\r", i			
			else			
				// if it passes, do spikefilter
				segmentpasses_spikefilter[i/32] = spikefiltertest5 (SEdatarec, prebaselinetolerance, postbaselinetolerance,maxspikewidth_pts, i, i+31)
				
				// if it fails, we're done
				if (!segmentpasses_spikefilter[i/32])		
					//printf "segment starting at %d fails on spikefilter\r", i			
				else
					// if it passes, we've passed everything!
					segmentpasses[i/32] = 1
					
					// stats wave was populated by spikefilter
					segmentfirstpeak[i/32] = stats[0]
					segmentpeaktopeak[i/32] = stats[1]
					
				endif
			endif
		endif
		
//		if (!mod(i/32,1000))
//			print i
//		endif
	endfor
			
	// now we have a yes/no wave describing the saturation
	printf "%d segments passed out of %d total segments\r", sum(segmentpasses),numpnts(segmentpasses)	
	
	// duh.  just use segmentpasses to index into SEdatarec
	// not quite that simple.  need to generate lists of indices for 1 and 0
	// how else to do random selection from each list?
	variable numpasses = sum(segmentpasses)
	
	make/o/n=(numpnts(segmentpasses)) $(outputprefix+"_ones") /WAVE=ones = (segmentpasses[p]) ? p : nan
	make/o/n=(numpnts(segmentpasses)) $(outputprefix+"_zeroes") /WAVE=zeroes = (!segmentpasses[p]) ? p : nan
	
	segmentfirstpeak = (segmentfirstpeak[p] == 0) ? NaN : segmentfirstpeak[p]
	segmentpeaktopeak = (segmentpeaktopeak[p] == 0) ? NaN : segmentpeaktopeak[p]
		
	removenans(ones)
	removenans(zeroes)
	removenans(segmentfirstpeak)
	removenans(segmentpeaktopeak)
	
	killwaves/z stats, segmentpasses_saturation,segmentpasses_jumptest, segmentpasses_spikefilter, segmentpasses
	
end

Function updatesets (SEdatarec,set1,set2,num)
	WAVE SEdatarec, set1,set2
	variable num

	// draw set from zeroes
	drawrandomset(set2, num,"zeroesdraw")
	WAVE zeroesdraw
	
	// draw set from ones
	drawrandomset(set1,num,"onesdraw")
	WAVE onesdraw
	
	// check for window and if it exists, clear it of traces
	string windowname = getdatafolder(0)
	dowindow/f $windowname 
	if (V_flag)		
		cleartraces()			
	else
		// if it doesn't, make it
		display
		dowindow/C $windowname
	endif
	
	displayset(set2,zeroesdraw,SEdatarec,1,1)
	displayset(set1,onesdraw,SEdatarec,0,1)
	
end

// draw howmany elements from sourcewave and store in wave called drawsetname
Function drawrandomset (sourcewave, howmany, drawsetname)
	WAVE sourcewave
	string drawsetname
	variable howmany	

	string prefix = nameofwave(sourcewave)+"draw"
	//clean up from previous runs
	killmatch (prefix+"*")

	variable i,test,next
	
	variable numpossibles = numpnts(sourcewave)

	// if howmany is more than sourcewave, edit it down!
	if (howmany > numpossibles)
		howmany = numpossibles
	endif

	make/i/n=(howmany)/o $drawsetname/WAVE=drawset = 0

	// if howmany was more than or equal to sourcewave, no drawings necessary, just set drawset equal to its index
	if (howmany == numpossibles)
		drawset = sourcewave[p]
		return 1
	endif
	
	for (i=0; i < howmany; i += 1)
		
		// draw a value from the possibilities
		test = sourcewave[floor(enoise(numpossibles/2) + numpossibles/2)]
		
		// see if it's in the wave already
		findvalue/i=(test) drawset
		
		// if it is, back i up by 1 to try again
		if (V_value >= 0)
			i-=1
		else
		// if it isn't yet, store it and go on
			next = test
			drawset[i] = next
		endif	
	
	endfor
	
end

// set contains a list of indices
// data contains data
//    index into indexwave for each number given in set, then use those indices to index into SEdata display according to color (startnew graph if startnew==1)
Function displayset (set, setdraw, data, color,appendtraces)
	wave set,setdraw,data
	variable color,appendtraces
	
	if (!appendtraces)
		display		
	endif
	
	string formattedrealindex
	string prefix = nameofwave(set)+"draw"
	variable howmany = numpnts(setdraw)
	
	// now make and append thedrawset
	// number waves according to the drawset index, but store the real index in the note
	variable lasttrace,i
	for (i=0; i < howmany; i += 1)
		make/o/n=32 $(prefix+num2str(i))/WAVE=nextwave
		sprintf formattedrealindex, "%9.f",(set[i]*32)
		note nextwave, formattedrealindex
		
		nextwave = data[setdraw[i]*32+p]
		appendtograph nextwave
		lasttrace = (itemsinlist(tracenamelist("",";",1))-1)
		if (color)
			modifygraph rgb($nameofwave(nextwave))=(65535,0,0)
		else
			modifygraph rgb($nameofwave(nextwave))=(0,65535,0)
		endif		
	
	endfor

end

Function interleave (numeach)
	variable numeach
	
	display

	variable i,numtraces
	string traces
	for (i=0; i < numeach; i += 1)
	
		appendtograph $("onesdraw"+num2str(i))		
		appendtograph $("zeroesdraw"+num2str(i))
		
		traces = tracenamelist("",";",1)
		numtraces = itemsinlist(traces)
		
		modifygraph rgb($StringFromList(numtraces-2,traces)) = (0,65535,0)
		modifygraph rgb($StringFromList(numtraces-1,traces)) = (65535,0,0)
		
	endfor
end


Function update_all_sets (num)
	variable num

	setdatafolder root:
	WAVE/T setlist
	variable numsets = numpnts(setlist),i
	string SEdatarecname
	for (i=0; i < numsets; i += 1)
		setdatafolder(setlist[i])
		 SEdatarecname = "HI_NIP"+afterwhatever(getdatafolder(0),"_NIP")+"_rCAR_SD4_SEdatarec"
		updatesets($SEdatarecname,ones, zeroes,num)		
		
		setdatafolder root:
	endfor

end

Function recompute_and_update_all_sets (SDwavename, maxwidth_pts,num)
	variable num
	variable maxwidth_pts
	string SDwavename

	setdatafolder root:
	WAVE/T setlist
	variable numsets = numpnts(setlist),i
	string SEdatarecname, prefix
	
	for (i=0; i < numsets; i += 1)
		setdatafolder(setlist[i])
		
		SEdatarecname = "HI_NIP"+afterwhatever(getdatafolder(0),"_NIP")+"_rCAR_SD4_SEdatarec"

		prefix=replacestring("_SEdatarec",SEdatarecname,"")
		
		// find my SD
		WAVE SDs = $SDwavename
							
		// split for lookup
		make/O/n=(DimSize(SDs, 0)) SDlist = SDs[p][0]
		make/O/n=(DimSize(SDs, 0)) channelnumberlist = SDs[p][1]
		
		FindValue/T=0.1/V=(str2num(afterwhatever(getdatafolder(0),"_NIP"))) channelnumberlist
		Variable theSD = SDlist[V_Value]		
		
		selecttimestamps_twolists(prefix, "",30000,0,8000,theSD,maxwidth_pts);
		
		updatesets($SEdatarecname,$(prefix+"_ones"), $(prefix+"_zeroes"),num)		
		doupdate
		setdatafolder root:
	endfor

end

// deal with possible non-existance of folder as just one of several "no"s for allSEwavesPresent.
Function allSEwavesPresent (pathstring, channelname)
	string pathstring, channelname
	
	WAVE/T SEsuffixes = root:neuromaven_resources:SEsuffixes
	variable i
	string nextstring
	
	//getfilefolderinfo/Q/Z SEdata_base_pathstring

	for (i=0; i < 5; i += 1)
		nextstring = pathstring+":"+channelname+"_"+replacestring("SEdata_",parsefilepath(0,pathstring,":",1,0),"")+"_"+SEsuffixes[i]+".ibw"
		print nextstring
		getfilefolderinfo/Q/Z nextstring
		// if file not found we're done
		if (V_flag != 0)
			return 0
		endif
	endfor
	
	// if we got through the for loop then everything's present
	return 1
	
end

// deal with possible non-existance of folder as just one of several "no"s for allSEwavesPresent.
Function loadSEwaves (pathstring, channelname)
	string pathstring, channelname
	
	WAVE/T SEsuffixes = root:neuromaven_resources:SEsuffixes
	variable i
	string nextstring
	
	//getfilefolderinfo/Q/Z SEdata_base_pathstring

	for (i=0; i < 5; i += 1)
		nextstring = pathstring+":"+channelname+"_"+replacestring("SEdata_",parsefilepath(0,pathstring,":",1,0),"")+"_"+SEsuffixes[i]+".ibw"

		loadwave nextstring
		// if wave not loaded we're done
		if (V_flag == 0)
			return 0
		endif
	endfor
	
	// if we got through the for loop then everything loaded
	return 1
	
end

Function moveSEwaves (SEchannelprefix, destinationstring)
	string SEchannelprefix, destinationstring
	
	WAVE/T SEsuffixes = root:neuromaven_resources:SEsuffixes
	variable i
	string nextstring
	
	//getfilefolderinfo/Q/Z SEdata_base_pathstring

	for (i=0; i < 5; i += 1)

		nextstring = SEchannelprefix+"_"+SEsuffixes[i]
		movewave $nextstring, $destinationstring

	endfor

end	