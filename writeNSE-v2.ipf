#pragma rtGlobals=1		// Use modern global access method.

// main function
// run from within data_records directory of hi-passed preprocessed folder
// v2
// threshold units picked here, but threshold computation now done in MakeSEData
// referencing done in MakeSEData also
Function MakeSpikeEventFile ([channelwavename, referencewavename, sortstring, spikethreshold, fullPathtoOutput])
	String channelwavename, referencewavename, sortstring, fullPathtoOutput
	Variable spikethreshold
	
	setdatafolder root:data_records
	
	if (paramisdefault(channelwavename))
	
		Prompt channelwavename, "Name of data channel", popup, Wavelist("*",";","")
		Prompt referencewavename, "Name of reference channel (leave blank for no re-referencing)", popup, (" ;"+Wavelist("*",";",""))
		Prompt spikethreshold, "Spike threshold (-0.99 < Volts < 0.99 , otherwise SD)"
	
		DoPrompt "Please enter parameters", channelwavename, referencewavename, spikethreshold
		if (V_flag)
			abort
		endif
	
	endif
	
	Variable refNum
	String message = "Specify location and name for .nse file"
	String fileFilters = " All Files:.*;"

	Open/D/F=fileFilters/M=message refNum
	FullPathtoOutput = S_fileName
	
	if (!cmpstr(FullPathtoOutput, ""))
		abort "must select destination location"
	endif
		
	Variable thresholdisVolts = 1
	String thresholdUnits = "V"
	if ((spikethreshold < -0.99) || (spikethreshold > 0.99))
		printf "interpreting threshold as SD...\r"
		thresholdisVolts = 0
		thresholdunits = "SD"
	endif
		
	// THE BELOW VALUES MATCH THE CHEETAH DEFAULTS, BUT CAN BE CHANGED
	Variable discriminationwindow_pts = 32
	Variable alignpoint = 8
	
	// use channelwave to locate and reference recordheaders and fileheader
	WAVE theWave_recordheaders = $("::headers_records:"+channelwavename)
	WAVE theWave_fileheader = $("::headers_file:"+channelwavename)
	
	WAVE channelwave = $channelwavename
	WAVE referencewave = $referencewavename

	String SEnamestring = GenerateSENameString (channelwavename, referencewavename, sortstring, spikethreshold, thresholdunits)
	MakeSEdata_v2(channelwave, referencewave, theWave_recordheaders,theWave_fileheader,discriminationwindow_pts, alignpoint, spikethreshold, thresholdunits,1, SEnamestring, ParseFilePath(0, FullPathtoOutput, ":", 1, 0))

	WAVE SEheader = $(SEnamestring+"_SEheadfile")
	WAVE SErecordheaders = $(SEnamestring+"_SEheadrec")
	WAVE SEspikedata = $(SEnamestring+"_SEdatarec")	
	
	writeNSE(SEheader,SErecordheaders,SEspikedata,fullPathtoOutput)
		
	printf "Wrote file %s\r", fullPathtoOutput
end

// attempting to reverse engineer the .nse file format
// need this in order to rewrite spike event files so as to do spikesorting after preprocessing
// this is going to require bulking up my file I/O skills in IGOR
// fullpathstring needs to be complete path to desired file e.g. "Macintosh HD:Users:nipadmin:Desktop:SE7-reverse.nse"
Function writeNSE (fileheader, recordheaders, waveformdata, fullpathstring)
	WAVE/t fileheader
	WAVE recordheaders, waveformdata
	string fullpathstring

	variable refNum
	// create a new file with Open
	open refNum as fullpathstring
	//print refNum
	
	// first write the header
	// can't write a text wave with FBinRead, so write one line at a time
	variable i,m
	variable numHeaderLines = numpnts(fileheader)
	string nextline
	for (i=0; i < numHeaderlines; i += 1)
		nextline = fileheader[i] + "\n"
		Fbinwrite refNum, nextline
	endfor

	// we want the file position to end up at 16384, so pad until we get there
	// where are we?
	FStatus refnum
	variable paddingbytes = 16384 - V_filepos
	// write one byte to the file
	variable pad = 0	// this is the ^@ sign to match the neuralynx convention
	for (m = 0; m < paddingbytes; m += 1)
		fbinwrite/b=3/f=1 refnum, pad
		FStatus refnum	
	endfor

	// now step through the number of records writing the binary back to the file
	variable j
	variable numrecords = DimSize(recordheaders, 1)
	variable waveformpoints = str2num(replacestring("-WaveformLength ", fileheader[31],""))
	make/O/n=24 temprecordheader
	make/O/n=32 tempwaveform
	for (j=0; j < numrecords; j += 1)
		
		// write the recordheader
		temprecordheader = recordheaders[p][j]
		fbinwrite/B=3/F=2 refNum, temprecordheader
	
		// write the record
		tempwaveform = waveformdata[j*waveformpoints+p]
		fbinwrite/B=3/F=2 refNum, tempwaveform
	
	endfor

	// close the file
	close refNum
	
	// clean up
	killwaves/z temprecordheader, tempwaveform
	
end

// goes through an igor wave and extracts the information necessary to write a Neuralynx-style.nse file
// output from this function can be used as input to writeNSE: means we need wave of spikes concatenated together, 2D matrix of record headers, and text wave of fileheader
// run from data_records directory of an experiment that already has the CSC data in it.
// give spike threshold in volts or SD
// data is in AD
Function MakeSEData (theWave, theReferenceWave, theWave_recordheaders,theWave_fileheader,windowpoints, alignpoint, spikethreshold, thresholdunits, SEnamestring, SEfilename)
	WAVE theWave,theWave_recordheaders, theReferenceWave
	WAVE/T theWave_fileheader
	Variable windowpoints, alignpoint, spikethreshold
	String SEnamestring, thresholdunits, SEfilename
		
	string SEname = SEnamestring
	
	// test here for existance of the wave!
	if (!WaveExists(theWave))
		printf "uh-oh.  %s does not exist.\r",nameofwave(thewave)
		abort
	endif
				
	// pull ADBitVolts from fileheader
	Variable ADBitVolts = ADBitVoltsFromCheetahheader(theWave_fileheader), spikethreshold_V, spikethreshold_uV
			
	// do reference subtraction if desired
	duplicate/O theWave wavetoprocess
	if (WaveExists(theReferenceWave))
		redimension/S wavetoprocess
		wavetoprocess -= theReferenceWave
	endif

	// after referencing, if threshold is an SD, compute the SD on the data and set the threshold
	if (!cmpstr(thresholdunits,"SD"))
		wavestats/q wavetoprocess
		// convert threshold to nearest uV, expressed in V, for consistency with previous files and Cheetah-generated SE data
		spikethreshold_V = spikethreshold *V_sdev* ADbitvolts
		spikethreshold_V = (floor(spikethreshold_V*1000000)/1000000)
		
		// now convert back to AD for actual thresholdingS
		spikethreshold = (spikethreshold_V / ADbitvolts)
		
	else
		//if input is V, convert to nearest uV, expressed in V
		spikethreshold_V = (floor(spikethreshold*1000000)/1000000)
		spikethreshold = spikethreshold_V
	endif

	spikethreshold_uV = spikethreshold_V*1000000
	
	printf "Generating spike event file in Neuralynx .nse format for data in %s, referenced to %s, with threshold of %f volts...\r", nameofwave(thewave),nameofwave(thereferencewave),spikethreshold_V
		
	variable recordheaderpoints = 24
	variable recordheaderbytes = 2*recordheaderpoints
	variable recordbytes = 2*windowpoints
	
	// compute recordsize (= numpnts in waveform * 2 + byte length of recordheader which was 48 in my example)
	variable recordsize = recordbytes + recordheaderbytes
	variable minretriggersamples = 0
	variable spikeretriggertime = 0
	
	// write the header (some of this can be copied from the csc load header if it exists)
	string headername = makeSEheader(nameofwave(theWave),theWave_fileheader, SEnamestring, recordsize,windowpoints, alignpoint, spikethreshold_uV,minretriggersamples,spikeretriggertime)
	
	// threshold the wave according to the input threshold
	detectthresh(wavetoprocess, 0, 0, spikethreshold, 1)
			
	WAVE sintwave = $("wavetoprocess_sint")
	// how many spikes found?
	variable numspikes = sintwave[9]
		
	// make waves to hold the "recordheaders" and the waveform data
	make/W/o/n=(24,numspikes) $(SEnamestring+"_SEheadrec")/WAVE=SErecordheaders = 0
	make/W/o/n=(windowpoints*numspikes) $(SEnamestring+"_SEdatarec")/WAVE=SEspikedata = 0

	variable nextthreshtime_ms, nextthreshtime_pt,i,nextpeaktime_pt,nextpeaktime_ms
	variable peak, valley, energy, height, sample4, sample16, sample24, sample28
	make/o/n=(windowpoints) tempspikewave
	//display tempspikewave
	
	// step through threshold-crossings, and for each one...
	for (i=0; i < numspikes; i += 1)
	
		// identify spike
		nextthreshtime_ms = sintwave[10+i]
		nextthreshtime_pt = x2pnt(wavetoprocess,nextthreshtime_ms)
		
		redimension/s tempspikewave
		
		// find peak within windowsize after crossing
		wavestats/q/r=[nextthreshtime_pt, nextthreshtime_pt+(windowpoints-1)] wavetoprocess
		
		nextpeaktime_ms = V_maxloc
		// create temporary spikewave
		// spike waveforms are aligned on peak value
		nextpeaktime_pt = x2pnt(wavetoprocess, nextpeaktime_ms)
		tempspikewave = wavetoprocess[nextpeaktime_pt-7+p]
		
		// back-convert the tempspike into AD counts (need ADbitvolts)
		// (unnecessary now!)
		//tempspikewave /= ADBitvolts
		//redimension/i tempspikewave
		
		// compute the 8 stats which will go into the recordheader
		wavestats/q tempspikewave
		
		// peak: highest value
		peak = V_max
		// valley: lowest value
		valley = V_min
		// energy: rms
		energy = V_rms
		// height: peak-valley
		height = peak-valley
		
		// note- sample numbers are 0-based indices (so "4th" sample is actually the 5th point
		// 4th sample
		sample4 = tempspikewave[4]
		// 16th sample
		sample16 = tempspikewave[16]		
		// 24th sample
		sample24 = tempspikewave[24]
		// 28th sample
		sample28 = tempspikewave[28]

		// convert the timestamp into the right format for the recordheader
		// I guess I finally need to understand this...and now I do
		// is the timestamp the thresh time or the peak time?
		WAVE timestamp_as_signed16 = convertNSEtimestamp(nextpeaktime_ms,theWave_recordheaders)
		
		// populate the recordheader
		
		SErecordheaders[0][i] = timestamp_as_signed16[0]
		SErecordheaders[1][i] = timestamp_as_signed16[1]
		SErecordheaders[2][i] = timestamp_as_signed16[2]
		SErecordheaders[3][i] = timestamp_as_signed16[3]				
		
		killwaves timestamp_as_signed16
		
		SErecordheaders[8][i] = peak
		SErecordheaders[9][i] = (SErecordheaders[8][i] < 0) ? -1 : 0
		SErecordheaders[10][i] = valley
		SErecordheaders[11][i] = (SErecordheaders[10][i] < 0) ? -1 : 0
		SErecordheaders[12][i] = energy
		SErecordheaders[13][i] = (SErecordheaders[12][i] < 0) ? -1 : 0
		SErecordheaders[14][i] = height
		SErecordheaders[15][i] = (SErecordheaders[14][i] < 0) ? -1 : 0
		SErecordheaders[16][i] = sample4
		SErecordheaders[17][i] =(SErecordheaders[16][i] < 0) ? -1 : 0
		SErecordheaders[18][i] = sample16
		SErecordheaders[19][i] =(SErecordheaders[18][i] < 0) ? -1 : 0
		SErecordheaders[20][i] = sample24
		SErecordheaders[21][i] =(SErecordheaders[20][i] < 0) ? -1 : 0
		SErecordheaders[22][i] = sample28
		SErecordheaders[23][i] = (SErecordheaders[22][i] < 0) ? -1 : 0

		redimension/i SErecordheaders
		
		// concatenate the spike points onto the waveform data
		SEspikedata[i*32,((i+1)*32)-1] = tempspikewave[p-i*32]
		// for example, for i=0
		//		SEspikedata[0,31] = tempspikewave[p-0]
		//		SEspikedata[32,63] = tempspikewave[p-32]
				
	endfor
	
	killwaves tempspikewave, sintwave
	killwaves/z wavetoprocess

end

// goes through an igor wave and extracts the information necessary to write a Neuralynx-style.nse file
// output from this function can be used as input to writeNSE: means we need wave of spikes concatenated together, 2D matrix of record headers, and text wave of fileheader
// run from data_records directory of an experiment that already has the CSC data in it.
// give spike threshold in volts or SD
// data is in AD
Function MakeSEData_v2 (theWave, theReferenceWave, theWave_recordheaders,theWave_fileheader,windowpoints, alignpoint, spikethreshold, thresholdunits, preblank, SEnamestring, SEfilename)
	WAVE theWave,theWave_recordheaders, theReferenceWave
	WAVE/T theWave_fileheader
	Variable windowpoints, alignpoint, spikethreshold,preblank
	String SEnamestring, thresholdunits, SEfilename
		
	string SEname = SEnamestring
	
	// test here for existance of the wave!
	if (!WaveExists(theWave))
		printf "uh-oh.  %s does not exist.\r",nameofwave(thewave)
		abort
	endif

	// pull ADBitVolts from fileheader
	Variable ADBitVolts = ADBitVoltsFromCheetahheader(theWave_fileheader), spikethreshold_V, spikethreshold_uV,SD
			
	// do reference subtraction if desired
	duplicate/O theWave wavetoprocess
	if (WaveExists(theReferenceWave))
		redimension/S wavetoprocess
		wavetoprocess -= theReferenceWave
	endif

	// after referencing, if threshold is an SD, compute the SD on the data and set the threshold
	if (!cmpstr(thresholdunits,"SD"))
	
		if (preblank)
			SD = getBlankedSD(wavetoprocess, spikethreshold)
		else
			wavestats/q wavetoprocess
			SD = V_sdev
		endif
		
		// convert threshold to nearest uV, expressed in V, for consistency with previous files and Cheetah-generated SE data
		spikethreshold_V = spikethreshold *SD* ADbitvolts
		spikethreshold_V = (floor(spikethreshold_V*1000000)/1000000)
		
		// now convert back to AD for actual thresholding
		spikethreshold = (spikethreshold_V / ADbitvolts)
		
	else
		//if input is V, convert to nearest uV, expressed in V
		spikethreshold_V = (floor(spikethreshold*1000000)/1000000)
		spikethreshold = spikethreshold_V
	endif

	spikethreshold_uV = spikethreshold_V*1000000
	
	printf "Generating spike event file in Neuralynx .nse format for data in %s, referenced to %s, with threshold of %f volts...\r", nameofwave(thewave),nameofwave(thereferencewave),spikethreshold_V
		
	variable recordheaderpoints = 24
	variable recordheaderbytes = 2*recordheaderpoints
	variable recordbytes = 2*windowpoints
	
	// compute recordsize (= numpnts in waveform * 2 + byte length of recordheader which was 48 in my example)
	variable recordsize = recordbytes + recordheaderbytes
	variable minretriggersamples = 0
	variable spikeretriggertime = 0
	
	// write the header (some of this can be copied from the csc load header if it exists)
	string headername = makeSEheader(nameofwave(theWave),theWave_fileheader, SEnamestring, recordsize,windowpoints, alignpoint, spikethreshold_uV,minretriggersamples,spikeretriggertime)
	
	
	// threshold the wave according to the input threshold
	detectthresh(wavetoprocess, 0, 0, spikethreshold, 1)
			
	WAVE sintwave = $("wavetoprocess_sint")
	// how many spikes found?
	variable numspikes = sintwave[9]
		
	// make waves to hold the "recordheaders" and the waveform data
	make/W/o/n=(24,numspikes) $(SEnamestring+"_SEheadrec")/WAVE=SErecordheaders = 0
	make/W/o/n=(windowpoints*numspikes) $(SEnamestring+"_SEdatarec")/WAVE=SEspikedata = 0

	variable nextthreshtime_ms, nextthreshtime_pt,i,nextpeaktime_pt,nextpeaktime_ms
	variable peak, valley, energy, height, sample4, sample16, sample24, sample28
	make/o/n=(windowpoints) tempspikewave
	//display tempspikewave
	
	// step through threshold-crossings, and for each one...
	for (i=0; i < numspikes; i += 1)
	
		// identify spike
		nextthreshtime_ms = sintwave[10+i]
		nextthreshtime_pt = x2pnt(wavetoprocess,nextthreshtime_ms)
		
		redimension/s tempspikewave
		
		// find peak within windowsize after crossing
		wavestats/q/r=[nextthreshtime_pt, nextthreshtime_pt+(windowpoints-1)] wavetoprocess
		
		nextpeaktime_ms = V_maxloc
		// create temporary spikewave
		// spike waveforms are aligned on peak value
		nextpeaktime_pt = x2pnt(wavetoprocess, nextpeaktime_ms)
		tempspikewave = wavetoprocess[nextpeaktime_pt-7+p]
		
		// back-convert the tempspike into AD counts (need ADbitvolts)
		// (unnecessary now!)
		//tempspikewave /= ADBitvolts
		//redimension/i tempspikewave
		
		// compute the 8 stats which will go into the recordheader
		wavestats/q tempspikewave
		
		// peak: highest value
		peak = V_max
		// valley: lowest value
		valley = V_min
		// energy: rms
		energy = V_rms
		// height: peak-valley
		height = peak-valley
		
		// note- sample numbers are 0-based indices (so "4th" sample is actually the 5th point
		// 4th sample
		sample4 = tempspikewave[4]
		// 16th sample
		sample16 = tempspikewave[16]		
		// 24th sample
		sample24 = tempspikewave[24]
		// 28th sample
		sample28 = tempspikewave[28]

		// convert the timestamp into the right format for the recordheader
		// I guess I finally need to understand this...and now I do
		// is the timestamp the thresh time or the peak time?
		WAVE timestamp_as_signed16 = convertNSEtimestamp(nextpeaktime_ms,theWave_recordheaders)
		
		// populate the recordheader
		
		SErecordheaders[0][i] = timestamp_as_signed16[0]
		SErecordheaders[1][i] = timestamp_as_signed16[1]
		SErecordheaders[2][i] = timestamp_as_signed16[2]
		SErecordheaders[3][i] = timestamp_as_signed16[3]				
		
		killwaves timestamp_as_signed16
		
		SErecordheaders[8][i] = peak
		SErecordheaders[9][i] = (SErecordheaders[8][i] < 0) ? -1 : 0
		SErecordheaders[10][i] = valley
		SErecordheaders[11][i] = (SErecordheaders[10][i] < 0) ? -1 : 0
		SErecordheaders[12][i] = energy
		SErecordheaders[13][i] = (SErecordheaders[12][i] < 0) ? -1 : 0
		SErecordheaders[14][i] = height
		SErecordheaders[15][i] = (SErecordheaders[14][i] < 0) ? -1 : 0
		SErecordheaders[16][i] = sample4
		SErecordheaders[17][i] =(SErecordheaders[16][i] < 0) ? -1 : 0
		SErecordheaders[18][i] = sample16
		SErecordheaders[19][i] =(SErecordheaders[18][i] < 0) ? -1 : 0
		SErecordheaders[20][i] = sample24
		SErecordheaders[21][i] =(SErecordheaders[20][i] < 0) ? -1 : 0
		SErecordheaders[22][i] = sample28
		SErecordheaders[23][i] = (SErecordheaders[22][i] < 0) ? -1 : 0

		redimension/i SErecordheaders
		
		// concatenate the spike points onto the waveform data
		SEspikedata[i*32,((i+1)*32)-1] = tempspikewave[p-i*32]
		// for example, for i=0
		//		SEspikedata[0,31] = tempspikewave[p-0]
		//		SEspikedata[32,63] = tempspikewave[p-32]
				
	endfor
	
	killwaves tempspikewave, sintwave
	killwaves/z wavetoprocess

end

// goes through an igor wave and extracts the information necessary to write a Neuralynx-style.nse file
// output from this function can be used as input to writeNSE: means we need wave of spikes concatenated together, 2D matrix of record headers, and text wave of fileheader
// run from data_records directory of an experiment that already has the CSC data in it.
// give spike threshold in volts or SD
// data is in AD
// data is already referenced correctly
// blanked SDs are available
Function MakeSEData_v3 (theWave, referencestring, theWave_recordheaders,theWave_fileheader,windowpoints, alignpoint, spikethreshold, thresholdunits, preblank, SEnamestring, SEfilename)
	WAVE theWave,theWave_recordheaders
	WAVE/T theWave_fileheader
	Variable windowpoints, alignpoint, spikethreshold,preblank
	String SEnamestring, thresholdunits, SEfilename, referencestring
		
	string SEname = SEnamestring
	
	// test here for existance of the wave!
	if (!WaveExists(theWave))
		printf "uh-oh.  %s does not exist.\r",nameofwave(thewave)
		abort
	endif

	// pull ADBitVolts from fileheader
	Variable ADBitVolts = ADBitVoltsFromCheetahheader(theWave_fileheader), spikethreshold_V, spikethreshold_uV,SD

	//  if threshold is an SD, access the correct blanked SD and set the threshold
	if (!cmpstr(thresholdunits,"SD"))
	
		if (preblank)
			// get SD from lookup wave
			WAVE SDwave = $("SDs_" +referencestring+"_"+num2str(spikethreshold)+"SDblank_3ms")
			
			// split for lookup
			make/O/n=(DimSize(SDwave, 0)) SDlist = SDwave[p][0]
			make/O/n=(DimSize(SDwave, 0)) channelnumberlist = SDwave[p][1]				
			
			// lookup SD for this channel
			FindValue/T=0.1/V=(str2num(replacestring("HI_NIP",nameofwave(theWave),""))) channelnumberlist
			Variable SD_thischannel = SDlist[V_Value]
		
			SD = SD_thischannel
		else
			wavestats/q theWave
			SD = V_sdev
		endif
		
		// convert threshold to nearest uV, expressed in V, for consistency with previous files and Cheetah-generated SE data
		spikethreshold_V = spikethreshold *SD* ADbitvolts
		spikethreshold_V = (floor(spikethreshold_V*1000000)/1000000)
		
		// now convert back to AD for actual thresholding
		spikethreshold = (spikethreshold_V / ADbitvolts)
		
	else
		//if input is V, convert to nearest uV, expressed in V
		spikethreshold_V = (floor(spikethreshold*1000000)/1000000)
		spikethreshold = spikethreshold_V
	endif

	spikethreshold_uV = spikethreshold_V*1000000
		
	variable recordheaderpoints = 24
	variable recordheaderbytes = 2*recordheaderpoints
	variable recordbytes = 2*windowpoints
	
	// compute recordsize (= numpnts in waveform * 2 + byte length of recordheader which was 48 in my example)
	variable recordsize = recordbytes + recordheaderbytes
	variable minretriggersamples = 0
	variable spikeretriggertime = 0
	
	// write the header (some of this can be copied from the csc load header if it exists)
	string headername = makeSEheader(nameofwave(theWave),theWave_fileheader, SEnamestring, recordsize,windowpoints, alignpoint, spikethreshold_uV,minretriggersamples,spikeretriggertime)
	
	
	// threshold the wave according to the input threshold
	detectthresh(theWave, 0, 0, spikethreshold, 1)
			
	WAVE sintwave = $(nameofwave(thewave)+"_sint")
	// how many spikes found?
	variable numspikes = sintwave[9]
		
	// make waves to hold the "recordheaders" and the waveform data
	make/W/o/n=(24,numspikes) $(SEnamestring+"_SEheadrec")/WAVE=SErecordheaders = 0
	make/W/o/n=(windowpoints*numspikes) $(SEnamestring+"_SEdatarec")/WAVE=SEspikedata = 0
	
	// make waves to hold the segment peak and peaktopeak values
	make/o/n=(numspikes) $(SEnamestring+"_segpeak1")/WAVE=SEsegpeak1 = 0
 	make/o/n=(numspikes) $(SEnamestring+"_segVpp")/WAVE=SEsegVpp = 0

	variable nextthreshtime_ms, nextthreshtime_pt,i,nextpeaktime_pt,nextpeaktime_ms
	variable peak, valley, energy, height, sample4, sample16, sample24, sample28
	make/o/n=(windowpoints) tempspikewave
	//display tempspikewave
	
	printf "generating spike event data %s from %d level crossings\r",  SEnamestring, numspikes
	
	// step through threshold-crossings, and for each one...
	for (i=0; i < numspikes; i += 1)
	
		// identify spike
		nextthreshtime_ms = sintwave[10+i]
		nextthreshtime_pt = x2pnt(thewave,nextthreshtime_ms)
		
		redimension/s tempspikewave
		
		// find peak within windowsize after crossing
		wavestats/q/r=[nextthreshtime_pt, nextthreshtime_pt+(windowpoints-1)] thewave
		
		nextpeaktime_ms = V_maxloc
		// create temporary spikewave
		// spike waveforms are aligned on peak value
		nextpeaktime_pt = x2pnt(thewave, nextpeaktime_ms)
		tempspikewave = thewave[nextpeaktime_pt-7+p]
		
		// back-convert the tempspike into AD counts (need ADbitvolts)
		// (unnecessary now!)
		//tempspikewave /= ADBitvolts
		//redimension/i tempspikewave
		
		// compute the 8 stats which will go into the recordheader
		wavestats/q tempspikewave
		
		// peak: highest value
		peak = V_max
		// valley: lowest value
		valley = V_min
		// energy: rms
		energy = V_rms
		// height: peak-valley
		height = peak-valley
		
		// note- sample numbers are 0-based indices (so "4th" sample is actually the 5th point
		// 4th sample
		sample4 = tempspikewave[4]
		// 16th sample
		sample16 = tempspikewave[16]		
		// 24th sample
		sample24 = tempspikewave[24]
		// 28th sample
		sample28 = tempspikewave[28]

		// convert the timestamp into the right format for the recordheader
		// I guess I finally need to understand this...and now I do
		// is the timestamp the thresh time or the peak time?
		WAVE timestamp_as_signed16 = convertNSEtimestamp(nextpeaktime_ms,theWave_recordheaders)
		
		// print nextpeaktime_ms
		// populate the recordheader
		
		SErecordheaders[0][i] = timestamp_as_signed16[0]
		SErecordheaders[1][i] = timestamp_as_signed16[1]
		SErecordheaders[2][i] = timestamp_as_signed16[2]
		SErecordheaders[3][i] = timestamp_as_signed16[3]				
		
		//abort
		
		killwaves timestamp_as_signed16
		
		SErecordheaders[8][i] = peak
		SErecordheaders[9][i] = (SErecordheaders[8][i] < 0) ? -1 : 0
		SErecordheaders[10][i] = valley
		SErecordheaders[11][i] = (SErecordheaders[10][i] < 0) ? -1 : 0
		SErecordheaders[12][i] = energy
		SErecordheaders[13][i] = (SErecordheaders[12][i] < 0) ? -1 : 0
		SErecordheaders[14][i] = height
		SErecordheaders[15][i] = (SErecordheaders[14][i] < 0) ? -1 : 0
		SErecordheaders[16][i] = sample4
		SErecordheaders[17][i] =(SErecordheaders[16][i] < 0) ? -1 : 0
		SErecordheaders[18][i] = sample16
		SErecordheaders[19][i] =(SErecordheaders[18][i] < 0) ? -1 : 0
		SErecordheaders[20][i] = sample24
		SErecordheaders[21][i] =(SErecordheaders[20][i] < 0) ? -1 : 0
		SErecordheaders[22][i] = sample28
		SErecordheaders[23][i] = (SErecordheaders[22][i] < 0) ? -1 : 0

		redimension/i SErecordheaders
		
		// concatenate the spike points onto the waveform data
		SEspikedata[i*32,((i+1)*32)-1] = tempspikewave[p-i*32]
		// for example, for i=0
		//		SEspikedata[0,31] = tempspikewave[p-0]
		//		SEspikedata[32,63] = tempspikewave[p-32]
		
		// populate the peak and peak to peak waves 
		SEsegpeak1[i] = getspike_peak (0,tempspikewave,0)
		SEsegVpp[i] = getspike_peaktopeak (0, tempspikewave, 0,15)
				
	endfor
	
	//killwaves tempspikewave, sintwave
	killwaves/z tempspikewave, sintwave, channelnumberlist, f

end


Function/S makeSEheader(channelname, fileheader, SEnamestring, recordsize, waveformlength, alignmentpoint, thresh,minretriggersamples,spikeretriggertime)
	wave/t fileheader
	string SEnamestring,channelname
	variable recordsize, waveformlength, alignmentpoint, thresh,minretriggersamples,spikeretriggertime

	make/o/n=46/T $(SEnamestring+"_SEheadfile")
	WAVE/t SEheader = $(SEnamestring+"_SEheadfile")
	
	// Files generated by Cheetah 5.5.1 lack a "-FileVersion" line in their headers
	FindValue/TEXT="FileVersion" fileheader
	if (V_value < 0)
		// header is 5.5.1 format	

		SEheader[0] = fileheader[p]
		SEheader[1] = "## File Name "+ SEnamestring
		SEheader[2] = fileheader[p]
		SEheader[3] = fileheader[p]
		SEheader[4] = fileheader[p]
		SEheader[5] = "## File written by IGOR, not Cheetah"
		SEheader[6] = "-AcqEntName "+SEnamestring
		SEheader[7] = "-FileType NSE"
		SEheader[8] = "-RecordSize "+num2str(recordsize)
		
		SEheader[9,29] = fileheader[p]
		
		SEheader[30] = "-DisabledSubChannels"
		SEheader[31] = "-WaveformLength "+num2str(waveformlength)
		SEheader[32] = "-AlignmentPt "+num2str(alignmentpoint)
		SEheader[33] = "-ThreshVal "+num2str(thresh)
		SEheader[34] = "-MinRetriggerSamples "+num2str(minretriggersamples)
		SEheader[35] = "-SpikeRetriggerTime "+num2str(spikeretriggertime)
		
		SEheader[36] = ""
		
		SEheader[37] = "-Feature Peak 0 0 "
		SEheader[38] = "-Feature Peak 1 0 "
		SEheader[39] = "-Feature Peak 2 0 "
		SEheader[40] = "-Feature Peak 3 0 "
		SEheader[41] = "-Feature NthSample 4 0 4 "
		SEheader[42] = "-Feature NthSample 5 0 16 "
		SEheader[43] = "-Feature NthSample 6 0 24 "
		SEheader[44] = "-Feature NthSample 7 0 28 "
	else
		// header is 5.6.0 format
		
		SEheader[0] = fileheader[p]
		SEheader[1] = "## File Name "+ SEnamestring
		SEheader[2] = fileheader[p]
		SEheader[3] = fileheader[p]
		SEheader[4] = fileheader[p]
		SEheader[5] = "## File written by IGOR, not Cheetah"
		SEheader[6] = "-AcqEntName "+SEnamestring
		SEheader[7] = "-FileType NSE"
		SEheader[8] = "-RecordSize "+num2str(recordsize)
		
		SEheader[9,29] = fileheader[p]
		
		SEheader[30] = "-DisabledSubChannels"
		SEheader[31] = "-WaveformLength "+num2str(waveformlength)
		SEheader[32] = "-AlignmentPt "+num2str(alignmentpoint)
		SEheader[33] = "-ThreshVal "+num2str(thresh)
		SEheader[34] = "-MinRetriggerSamples "+num2str(minretriggersamples)
		SEheader[35] = "-SpikeRetriggerTime "+num2str(spikeretriggertime)
		
		SEheader[36] = ""
		
		SEheader[37] = "-Feature Peak 0 0 "
		SEheader[38] = "-Feature Peak 1 0 "
		SEheader[39] = "-Feature Peak 2 0 "
		SEheader[40] = "-Feature Peak 3 0 "
		SEheader[41] = "-Feature NthSample 4 0 4 "
		SEheader[42] = "-Feature NthSample 5 0 16 "
		SEheader[43] = "-Feature NthSample 6 0 24 "
		SEheader[44] = "-Feature NthSample 7 0 28 "
	
	endif	
		
	return nameofwave(SEheader)
	
end

// run from data_records directory of an experiment that already has the CSC data in it.
// this will create a directory root:SEdata_ref_threshold and put all the SE data in it.
Function/S MakeSEData_all (datalist, referencewavename, sortstring, spikethreshold)
	String datalist,referencewavename,sortstring
	Variable spikethreshold
	
	variable numchannels = itemsinlist(datalist),i
	String channelwavename, SEnamestring
	String SEnamestrings_all = ""
	
	// THE BELOW VALUES MATCH THE CHEETAH DEFAULTS, BUT CAN BE CHANGED
	Variable discriminationwindow_pts = 32
	Variable alignpoint = 8
	
	Variable thresholdisVolts = 1
	String thresholdUnits = "V"
	if ((spikethreshold < -0.99) || (spikethreshold > 0.99))
		printf "interpreting threshold as SD...\r"
		thresholdisVolts = 0
		thresholdUnits = "SD"
	endif
		
	WAVE referencewave = $referencewavename
	
	// make destination if it doesn't exist
	if (!DataFolderExists("root:SEdata"))
		newdatafolder root:SEdata
	endif

	for (i=0; i < numchannels; i += 1)

		channelwavename = stringfromlist(i,datalist)
		
		// use channelwave to locate and reference recordheaders and fileheader
		WAVE theWave_recordheaders = $("::headers_records:"+channelwavename)
		WAVE theWave_fileheader = $("::headers_file:"+channelwavename)
	
		WAVE channelwave = $channelwavename
	
		// not used here, but will be used eventually if an .nse file is written from these waves
		SEnamestring = GenerateSENameString (channelwavename, referencewavename, sortstring, spikethreshold, thresholdunits)
		makeSEdata(channelwave, referencewave, theWave_recordheaders,theWave_fileheader,discriminationwindow_pts, alignpoint, spikethreshold, thresholdunits, SEnamestring,"")

		WAVE SEheader = $(SEnamestring+"_SEheadfile")
		WAVE SErecordheaders = $(SEnamestring+"_SEheadrec")
		WAVE SEspikedata = $(SEnamestring+"_SEdatarec")

		// move created waves to their final spot
		duplicate/o SEheader, $("root:SEdata:"+nameofwave(SEheader))
		duplicate/o SErecordheaders, $("root:SEdata:"+nameofwave(SErecordheaders))
		duplicate/o SEspikedata, $("root:SEdata:"+nameofwave(SEspikedata))

		killwaves SEheader, SErecordheaders, SEspikedata
		killwaves/z wavetoprocess
		
		SEnamestrings_all += (SEnamestring + ";")

	endfor

	return SEnamestrings_all

end

// run from data_records directory of an experiment that already has the CSC data in it.
// this will create a directory root:SEdata_ref_threshold and put all the SE data in it.
Function/S MakeSEData_all_v2 (datalist, referencewavename, sortstring, spikethreshold)
	String datalist,referencewavename, sortstring
	Variable spikethreshold
	
	variable numchannels = itemsinlist(datalist),i
	String channelwavename, SEnamestring
	String SEnamestrings_all = ""
	
	// THE BELOW VALUES MATCH THE CHEETAH DEFAULTS, BUT CAN BE CHANGED
	Variable discriminationwindow_pts = 32
	Variable alignpoint = 8
	
	Variable thresholdisVolts = 1
	String thresholdUnits = "V"
	if ((spikethreshold < -0.99) || (spikethreshold > 0.99))
		printf "interpreting threshold as SD...\r"
		thresholdisVolts = 0
		thresholdUnits = "SD"
	endif
		
	WAVE referencewave = $referencewavename
	
	// make destination if it doesn't exist
	if (!DataFolderExists("root:SEdata"))
		newdatafolder root:SEdata
	endif

	for (i=0; i < numchannels; i += 1)

		channelwavename = stringfromlist(i,datalist)
		
		// use channelwave to locate and reference recordheaders and fileheader
		WAVE theWave_recordheaders = $("::headers_records:"+channelwavename)
		WAVE theWave_fileheader = $("::headers_file:"+channelwavename)
	
		WAVE channelwave = $channelwavename
	
		// not used here, but will be used eventually if an .nse file is written from these waves
		SEnamestring = GenerateSENameString (channelwavename, referencewavename, sortstring, spikethreshold, thresholdunits)
		makeSEdata(channelwave, referencewave, theWave_recordheaders,theWave_fileheader,discriminationwindow_pts, alignpoint, spikethreshold, thresholdunits, SEnamestring,"")

		WAVE SEheader = $(SEnamestring+"_SEheadfile")
		WAVE SErecordheaders = $(SEnamestring+"_SEheadrec")
		WAVE SEspikedata = $(SEnamestring+"_SEdatarec")

		// move created waves to their final spot
		duplicate/o SEheader, $("root:SEdata:"+nameofwave(SEheader))
		duplicate/o SErecordheaders, $("root:SEdata:"+nameofwave(SErecordheaders))
		duplicate/o SEspikedata, $("root:SEdata:"+nameofwave(SEspikedata))

		killwaves SEheader, SErecordheaders, SEspikedata
		killwaves/z wavetoprocess
		
		SEnamestrings_all += (SEnamestring + ";")

	endfor

	return SEnamestrings_all

end

// run from data_records directory of an experiment that already has the CSC data in it.
// this will create a directory root:SEdata_ref_threshold and put all the SE data in it.
Function/S MakeSEData_all_v3 (datalist, spikethreshold, referencestring)
	String datalist, referencestring
	Variable spikethreshold
	
	variable numchannels = itemsinlist(datalist),i
	String channelwavename, SEnamestring
	String SEnamestrings_all = ""
	
	// THE BELOW VALUES MATCH THE CHEETAH DEFAULTS, BUT CAN BE CHANGED
	Variable discriminationwindow_pts = 32
	Variable alignpoint = 8
	
	Variable thresholdisVolts = 1
	String thresholdUnits = "V"
	if ((spikethreshold < -0.99) || (spikethreshold > 0.99))
		printf "interpreting threshold as SD...\r"
		thresholdisVolts = 0
		thresholdUnits = "SD"
	endif

	string SEfolderstring = "SEdata_"+referencestring+"_"+num2str(spikethreshold)+thresholdunits +"_s00"
		
	// make destination if it doesn't exist
	if (!DataFolderExists("root:SEdata"))
		newdatafolder $("root:"+SEfolderstring)
	endif

	for (i=0; i < numchannels; i += 1)

		channelwavename = stringfromlist(i,datalist)
		
		// use channelwave to locate and reference recordheaders and fileheader
		WAVE theWave_recordheaders = $("::headers_records:"+channelwavename)
		WAVE theWave_fileheader = $("::headers_file:"+channelwavename)
	
		WAVE channelwave = $channelwavename
	
		// not used here, but will be used eventually if an .nse file is written from these waves
		SEnamestring = GenerateSENameString (channelwavename, referencestring, "s00",spikethreshold, thresholdunits)
		makeSEdata_v3(channelwave, referencestring, theWave_recordheaders,theWave_fileheader,discriminationwindow_pts, alignpoint, spikethreshold, thresholdunits, 1, SEnamestring,"")

		WAVE SEheader = $(SEnamestring+"_SEheadfile")
		WAVE SErecordheaders = $(SEnamestring+"_SEheadrec")
		WAVE SEspikedata = $(SEnamestring+"_SEdatarec")

		WAVE SEsegVpp = $(SEnamestring+"_segVpp")
		WAVE SEsegpeak1 = $(SEnamestring+"_segpeak1")

		// move created waves to their final spot
		duplicate/o SEheader, $("root:" + SEfolderstring + ":"+nameofwave(SEheader))
		duplicate/o SErecordheaders, $("root:"+SEfolderstring + ":" +nameofwave(SErecordheaders))
		duplicate/o SEspikedata, $("root:"+SEfolderstring + ":" + nameofwave(SEspikedata))
		
		duplicate/o SEsegVpp, $("root:"+SEfolderstring + ":" + nameofwave(SEsegVpp))
		duplicate/o SEsegpeak1, $("root:"+SEfolderstring + ":" + nameofwave(SEsegpeak1))


		killwaves SEheader, SErecordheaders, SEspikedata, SEsegVpp, SEsegpeak1
		killwaves/z wavetoprocess
		
		SEnamestrings_all += (SEnamestring + ";")

	endfor

	return SEnamestrings_all

end


Function/S GenerateSENameString (channelname, referencename, sortstring, threshold, thresholdunits)
	string channelname, referencename, sortstring, thresholdunits
	variable threshold
	
	if (stringmatch(thresholdunits,"V"))
	
		// convert threshold to uV and round to nearest integer
		threshold *= 1000000
		threshold = floor(threshold)
		thresholdunits = "uV"
	
	endif
	
	string thresholdstring = num2str(threshold)
	
	string SEstring = channelname+"_"+referencename+"_"+thresholdstring +thresholdunits +"_" + sortstring
	
	return SEstring
	
end

// returncode:0 send channel back
// returncode:1 send reference back
// returncode:2 send threshold back
Function/S ParseSENameString (SEnamestring, returncode)
	string SEnamestring
	variable returncode
	
	variable reffirstchar = strsearch(SEnamestring,"_r",0) + 1
	variable reflastchar = strsearch(SEnamestring,"_",reffirstchar+1) - 1
	
	variable threshfirstchar = strsearch(SEnamestring, "_", reflastchar+1) + 1

	
	switch(returncode)	// numeric switch
		case 0:		// execute if case matches expression
		
			return SEnamestring[0,reffirstchar-2]

		case 1:
			
			return SEnamestring[reffirstchar,reflastchar]
			
		case 2:
		
			return SEnamestring[threshfirstchar,strlen(SEnamestring)-1]

	endswitch
			
	
end


// wrapper function for batch saving out nse files
// receives SEstringlist.  create sets of three SEspikedata 
Function writeNSE_all (SEstringlist, outputpathnsestring, SEfoldersuffix)
	string SEstringlist, outputpathnsestring,SEfoldersuffix

	variable i
	variable numstrings = itemsinlist(SEstringlist)
	string SEnamestring,filename

	setdatafolder $("root:SEdata"+SEfoldersuffix)

	for (i=0; i < numstrings; i += 1)
	
		SEnamestring = StringFromList(i, SEstringlist)
		
		WAVE SEheader = $(SEnamestring+"_SEheadfile")
		WAVE SErecordheaders = $(SEnamestring+"_SEheadrec")
		WAVE SEspikedata = $(SEnamestring+"_SEdatarec")

		newpath/Q/c/o NSEwritepath, outputpathnsestring
		filename = outputpathnsestring + ":" +  SEnamestring+".nse"
				
		writeNSE (SEheader, SErecordheaders, SEspikedata, filename)

	endfor

end

// writes SEdata to neuralynx spike event format (.nse file)
// right now assumes SEdata is present in the Igor file.  Eventually will need to add capability to load if it isn't already there.
// this one is always saveouttodb because the whole point of it is to write binaries out to Igor
Function writeNSE_to_database (datafoldername, subjectname, recordingstring)
	string datafoldername, subjectname, recordingstring

	printf "    writeNSE_to_database called on %s\r", datafoldername

	// need database base path
	// e.g. Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:database:
	SVAR database_basepathstring = root:neuromaven_resources:pathstrings:database_basepathstring
	String subject_pathstring = database_basepathstring + subjectname + ":"
	
	variable i
		
	// this is hard-code needs to be fixed
	string channelmatchstring = "HI_NIP"

	string SEdata_pathstring = database_basepathstring + subjectname + ":" + recordingstring + ":" + datafoldername + ":"
	
	// change to datafolder
	setdatafolder $("root:"+datafoldername)

	for (i=0; i < 16; i += 1)

			string nextprefix = channelmatchstring + num2str(i+1)

			string nextfileheadername = nextprefix+"_SEheadfile"
			WAVE nextfileheader = $nextfileheadername
			if (!waveexists(nextfileheader))
				printf "missing input %s\r", nextfileheadername
			endif
			
			string nextrecordheadername = nextprefix+"_SEheadrec"
			WAVE nextrecordheader = $nextrecordheadername
			if (!waveexists(nextrecordheader))
				printf "missing input %s\r", nextrecordheadername
			endif

			string nextdatarecordname = nextprefix+"_SEdatarec"
			WAVE nextdatarecord = $nextdatarecordname
			if (!waveexists(nextdatarecord))
				printf "missing input %s\r", nextdatarecordname
			endif
			
			writeNSE (nextfileheader, nextrecordheader, nextdatarecord, SEdata_pathstring+nextprefix+".nse")

	endfor

end


