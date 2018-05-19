#pragma rtGlobals=1		// Use modern global access method.

// This is a self-contained file which is saved in the pxp ("adopted").  Procedures in here have BATCH appended to the name to prevent name conflicts with existing
// procedures.

// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function fixBATCH (inputpathstring, outputpathstring, actionstring)
	string inputpathstring, outputpathstring, actionstring
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpath, outputpathstring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp")), refstatus
	variable numfiles = itemsinlist(filenamestr),i,carmade
	string nextfilename,somewaves,referencename,referencestring
		
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		loaddata/p=inputpath/r/o=1 nextfilename
		
		// make the needed modifications
		setdatafolder root:
		killwaves/a/z

		// clean up windows and data foldesr
		killtables()
		cleanupfoldersBATCH()

		// intconvert("*HI_NIP*")
		// testandaveragematchesBATCH ("*HI_NIP*", "", "AVG")

		setdatafolder root:data_records

		// kill AVGm if it exists
		killwaves/z AVGm
		
		if (WaveExists(SDs))
			Rename SDs SDs_presubtraction
		endif

		// which reference was used?
		referencestring = note(HI_NIP1)
		if (strlen(referencestring) == 0)
			abort "missing HI_NIP1 - can't determine reference from wavenote"
		endif
		
		referencename = referencestring[1,strlen(referencestring)-1]
		WAVE reference = $referencename
			
		// add the reference back
		unreference ("HI_NIP",16,referencename)

		refstatus = CARmaker_simple ("HI_NIP",0.5, 1.5)
		
		if (stringmatch(refstatus,"same"))
			// no change to ref status
			// no need to recompute blanked SDs.
			// just rereference
			rereference ("HI_NIP",16,referencename)
		else
			referencename = refstatus
			rereference ("HI_NIP",16,referencename)
		
			// compute and store blanked SDs (3 and 4, just to be safe)
			string SDpost3SDblankname = blankedSDs_batch("HI_NIP","postsub_3SDblank",3,3)
			string SDpost4SDblankname = blankedSDs_batch("HI_NIP","postsub_4SDblank",4,3)
		endif
		
		// check for runtime error
		RTErrorCheck(nextfilename)

		// save experiment to outputpath with new name
		saveexperiment/C/P=outputpath as nextfilename
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function BATCH_Do_PostSubSD_noblank (inputpathstring, outputpathstring)
	string inputpathstring, outputpathstring
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpath, outputpathstring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp")), refstatus
	variable numfiles = itemsinlist(filenamestr),i,carmade
	string nextfilename,somewaves,referencename,referencestring
		
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		loaddata/p=inputpath/r/o=1 nextfilename
		
		// make the needed modifications
		setdatafolder root:
		killwaves/a/z

		// clean up windows and data folders
		killtables()
		cleanupfoldersBATCH()

		// kill AVGm if it exists
		killwaves/z AVGm
		
		setdatafolder data_records
		
		// this is old - get rid of it
		killwaves/z SDs_presubtraction, W_sumCols, W_sumRows
		
		// compute and store blanked SDs (3 and 4, just to be safe)
		string SDpost_noblank_name = SDs_batch("HI_NIP","_postsub_noblank")

		// check for runtime error
		RTErrorCheck(nextfilename)

		// save experiment to outputpath with new name
		saveexperiment/C/P=outputpath as nextfilename
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function BATCH_makepresubSD (inputpathstring, outputpathstring)
	string inputpathstring, outputpathstring
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpath, outputpathstring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp")), refstatus
	variable numfiles = itemsinlist(filenamestr),i,carmade
	string nextfilename,somewaves,referencename,referencestring, outputname
		
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		loaddata/p=inputpath/r/o=1 nextfilename
		
		setdatafolder data_records

		// which reference was used?
		referencestring = note(HI_NIP1)
		if (strlen(referencestring) == 0)
			abort "missing HI_NIP1 - can't determine reference from wavenote"
		endif
		
		referencename = referencestring[1,strlen(referencestring)-1]
		WAVE reference = $referencename
			
		// add the reference back
		unreference ("HI_NIP",16,referencename)

		// compute and store raw SDs (3 and 4, just to be safe)
		WAVE SDs = $(SDs_batch("HI_NIP", "_raw"))

		// check for runtime error
		RTErrorCheck(nextfilename)

		// save SD wave to outputpath with new name
		outputname = nextfilename+"SDs"
		
		save/P=outputpath SDs as outputname
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
// add a bunch of new SD computations
//	a) blank at 2SD using same window as before.
//   b) blank at 2,3,4 SD but don't use a window, just blank all data not meeting that criterion
Function BATCH_moreSDs (inputpathstring, outputpathstring)
	string inputpathstring, outputpathstring
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpath, outputpathstring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp")), refstatus
	variable numfiles = itemsinlist(filenamestr),i,carmade
	string nextfilename,somewaves,referencename,referencestring, outputname
		
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		loaddata/p=inputpath/r/o=1 nextfilename
		
		setdatafolder data_records

		// which reference was used?
		referencestring = note(HI_NIP1)
		if (strlen(referencestring) == 0)
			abort "missing HI_NIP1 - can't determine reference from wavenote"
		endif
		
		referencename = referencestring[1,strlen(referencestring)-1]
		WAVE reference = $referencename
			
		// add the reference back
		unreference ("HI_NIP",16,referencename)

		// compute and store raw SDs (3 and 4, just to be safe)
		WAVE SDs = $(SDs_batch("HI_NIP", "_raw"))

		// check for runtime error
		RTErrorCheck(nextfilename)

		// save SD wave to outputpath with new name
		outputname = nextfilename+"SDs"
		
		save/P=outputpath SDs as outputname
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function BATCH_pullinSD (inputpathstring, outputpathstring)
	string inputpathstring, outputpathstring
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpath, outputpathstring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp")), refstatus
	variable numfiles = itemsinlist(filenamestr),i,carmade
	string nextfilename,somewaves,referencename,referencestring, outputname, nextSDfilename
	print filenamestr
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		loaddata/p=inputpath/r/o=1 nextfilename
		printf "loaded all data\r"
		
		setdatafolder data_records
		
		// build SD wave name from pxp name
		nextSDfilename = nextfilename+"SDs"
		
		// load that guy in here
		loadwave/H/P=inputpath nextSDfilename
		printf "added in %s\r", nextSDfilename
		printf "saving...\r"

		saveexperiment/C/P=outputpath as nextfilename
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function BATCH_addPSDs (inputpathstring, outputpathstring)
	string inputpathstring, outputpathstring
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpath, outputpathstring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp")), refstatus
	variable numfiles = itemsinlist(filenamestr),i,carmade,j
	string nextfilename,somewaves,referencename,referencestring, outputname
		
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		loaddata/p=inputpath/r/o=1 nextfilename
		
		setdatafolder data_records

		// which reference was used?
		referencestring = note(HI_NIP1)
		if (strlen(referencestring) == 0)
			abort "missing HI_NIP1 - can't determine reference from wavenote"
		endif
		
		referencename = referencestring[1,strlen(referencestring)-1]
		WAVE reference = $referencename
		
		duplicate/o reference dummy		
		
		string matchingwavenames = wavelist ("*"+"HI_NIP"+"*", ";",""), PSDname, channelname
		variable numwaves = itemsinlist(matchingwavenames),channelnumber
		
		for (j=0; j < numwaves; j += 1)
			
			channelname = StringFromList(j, matchingwavenames)
			WAVE nextchannel = $channelname
			WAVE/T nextchannelheader = $("root:headers_file:"+channelname)
			printf "computing PSD on %s\r", channelname
			PSDname = makePSDonly(nextchannel, "_psd_reref", 12000, ADbitvoltsfromcheetahheader2(nextchannelheader), 10*32000, "Welch", 0)
			
			// now unreference and repeat
			printf "adding %s back to %s\r", channelname, referencename
			dummy = nextchannel[p] + reference[p]			
			printf "recomputing PSD on %s\r", channelname

			PSDname = makePSDonly(dummy,  "_psd", 12000, ADbitvoltsfromcheetahheader2(nextchannelheader), 10*32000, "Welch", 0)
			WAVE dummy_psd
			duplicate/o dummy_psd $(channelname + "_psd")
		endfor

		killwaves/z dummy, dummy_psd, ctmp

		// check for runtime error
		RTErrorCheck(nextfilename)

		cleanupfoldersBATCH()

		// save experiment to outputpath with new name
		saveexperiment/C/P=outputpath as nextfilename
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

Function intconvert (matchstring)
	String matchstring

	setdatafolder root:data_records
		
	string somewaves = Wavelist(matchstring,";","")
	variable numwaves =  itemsinlist(somewaves),i
	
	printf "converting%d waves to int16: %s\r", numwaves,somewaves
	
	variable ADbitvolts
	for (i=0; i < numwaves; i += 1)
		printf "...%s\r", stringfromlist(i,somewaves)
		WAVE nextwave = $(stringfromlist(i,somewaves))
		WAVE/t headerwave = $("root:headers_file:"+stringfromlist(i,somewaves))
		
		ADbitvolts = ADBitVoltsFromCheetahheader(headerwave)
		
		// scale
		nextwave /= ADBitVolts
		
		// set data scale
		setscale d 0,0,"ADcounts" nextwave
		
		// redimension
		redimension/w nextwave

	endfor	
	
	
	// also do averages (don't redimension because they will not be integers)
	if (Waveexists(AVG))
		WAVE AVG
		printf "scaled AVG\r"
		AVG /= ADBitVolts
		setscale d 0,0,"ADcounts" AVG
	endif
	if (Waveexists(AVGm))
		printf "scaled AVGm\r"
		WAVE AVGm
		AVGm /= ADBitVolts
		setscale d 0,0,"ADcounts" , AVGm
	endif	

end


// kill all data folders except headers_records, headers_file, data_records
// Dec2013: fixed to place itself at root level
Function cleanupfoldersBATCH()

	string currentDF = Getdatafolder(1)
	setdatafolder root:

	string folders = datafolderdir(1)
	string thisFolder
	variable i,n 
	n= itemsInList(folders,",")
	
	do
		thisFolder = stringFromList(i,folders,",")
		if(i==0)
			thisFolder = thisFolder[8,strlen(thisFolder)]
		endif
		if(i==(n-1))
			thisFolder = thisFolder[0,(strlen(thisFolder)-3)]
		endif

		if (!(stringmatch(thisFolder,"headers_records") || stringmatch(thisFolder,"headers_file") || stringmatch(thisFolder,"data_records")))
			killDataFolder $thisFolder
		endif

		i+=1
	while (i<n)
	
	setdatafolder currentDF

end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function fixBATCH_SE (inputpathstring, outputpathpxpstring, outputpathnsestring)
	string inputpathstring, outputpathpxpstring,outputpathnsestring
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpathpxp, outputpathpxpstring
	newpath/o outputpathnse, outputpathnsestring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp"))
	variable numfiles = itemsinlist(filenamestr),i
	string nextfilename,somewaves,SEstringlist
	string nextnsepathstring
	
	string newfilename,firstSEstring, refthreshstring
	
	
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		// this will include the SEdata folder if there is one
		loaddata/p=inputpath/r/o=1 nextfilename
		
		// make the needed modifications
		setdatafolder root:
		killwaves/a/z

		// ******************************
		setdatafolder root:data_records
		
		SEstringlist = makeSEdata_all(wavelist("HI_NIP*",";",""),"AVG","ALL",3)
		
		// get one SE string
		firstSEstring = stringfromlist(0,SEstringlist)
		refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]
		
		
		nextnsepathstring = outputpathnsestring +(":"+replacestring("_HI_NIP.pxp",nextfilename,""))		
		newfilename = replacestring("HI_NIP.pxp",nextfilename,(refthreshstring+"SEdata.pxp"))
		writeNSE_all (SEstringlist, nextnsepathstring,"")
		
		// kill out the previous files
		setdatafolder root:
		killdatafolder/z headers_records
		killdatafolder/z headers_file
		killdatafolder/z data_records
							
		// save experiment to outputpath with new name
		saveexperiment/C/P=outputpathpxp as newfilename
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function fixBATCH_SE_v2 (referencetouse, SDcutoff, inputpathstring, outputpathpxpstring, outputpathnsestring)
	string inputpathstring, outputpathpxpstring,outputpathnsestring
	string referencetouse
	variable SDcutoff
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpathpxp, outputpathpxpstring
	newpath/o outputpathnse, outputpathnsestring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp"))
	variable numfiles = itemsinlist(filenamestr),i
	string nextfilename,somewaves,SEstringlist
	string nextnsepathstring
	
	string newfilename,firstSEstring, refthreshstring
	
	
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		// this will include the SEdata folder if there is one
		loaddata/p=inputpath/r/o=1 nextfilename
		
		// make the needed modifications
		setdatafolder root:
		killwaves/a/z

		// ******************************
		setdatafolder root:data_records
		
		SEstringlist = makeSEdata_all_v2(wavelist("HI_NIP*",";",""),referencetouse,"ALL",SDcutoff)
		
		// get one SE string
		firstSEstring = stringfromlist(0,SEstringlist)
		refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]
		
		
		nextnsepathstring = outputpathnsestring +(":"+replacestring("_HI_NIP.pxp",nextfilename,""))		
		newfilename = replacestring("HI_NIP.pxp",nextfilename,(refthreshstring+"SEdata.pxp"))
		writeNSE_all (SEstringlist, nextnsepathstring,"")
		
		// kill out the previous files
		setdatafolder root:
		killdatafolder/z headers_records
		killdatafolder/z headers_file
		killdatafolder/z data_records
							
		// save experiment to outputpath with new name
		saveexperiment/C/P=outputpathpxp as newfilename
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
// if outputpathnsestring == "", don't make .nse
Function fixBATCH_SE_v3 (SDcutoff, inputpathstring, outputpathpxpstring, outputpathnsestring)
	string inputpathstring, outputpathpxpstring,outputpathnsestring
	variable SDcutoff
	
	newpath/o inputpath, inputpathstring
	newpath/o outputpathpxp, outputpathpxpstring
	newpath/o outputpathnse, outputpathnsestring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp"))
	variable numfiles = itemsinlist(filenamestr),i
	string nextfilename,somewaves,SEstringlist
	string nextnsepathstring
	
	string newfilename,firstSEstring, refthreshstring
	
	
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data from it
		// this will include the SEdata folder if there is one
		loaddata/p=inputpath/r/o=1 nextfilename
		
		// make the needed modifications
		setdatafolder root:
		killwaves/a/z

		// ******************************
		setdatafolder root:data_records
		
		SEstringlist = makeSEdata_all_v3(buildlist("HI_NIP",1,16),SDcutoff,"")
		
		// get one SE string
		firstSEstring = stringfromlist(0,SEstringlist)
		refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]
		
		
		nextnsepathstring = outputpathnsestring +(":"+replacestring("_HI_NIP.pxp",nextfilename,""))		
		newfilename = replacestring("HI_NIP.pxp",nextfilename,(refthreshstring+"SEdata.pxp"))
		writeNSE_all (SEstringlist, nextnsepathstring,"")
		
		// kill out the previous files
		setdatafolder root:
		killdatafolder/z headers_records
		killdatafolder/z headers_file
		killdatafolder/z data_records
							
		// save experiment to outputpath with new name
		saveexperiment/C/P=outputpathpxp as newfilename
		
		// kill everything
		setdatafolder root:
		cleardatafoldersBATCH()	
		
	endfor
	
end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
// if outputpathnsestring == "", don't make .nse
// makes a new set of spike event files from an old set
// saturation level:30000, saturationtolerance:0, baselinewindow_pct:25, maxspikewidth_pts:20
Function filter_SEdata (inputpathstring, HIpasspathstring, outputpathpxpstring, outputpathnsestring,SEfoldersuffix, saturationlevel, saturationtolerance,baselinewindow_pct,maxspikewidth_pts)
	string inputpathstring, HIpasspathstring, outputpathpxpstring,outputpathnsestring, SEfoldersuffix
	Variable  saturationlevel, saturationtolerance,baselinewindow_pct,maxspikewidth_pts
	
	newpath/o inputpath, inputpathstring
	newpath/o inputpathHIpass, HIpasspathstring
	newpath/o outputpathpxp, outputpathpxpstring
	newpath/o outputpathnse, outputpathnsestring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp"))
	print filenamestr
	variable numfiles = itemsinlist(filenamestr),i,j
	string nextfilename,somewaves,SEstringlist
	string nextnsepathstring
	
	string newfilename,firstSEstring, refthreshstring,nextfilenameHIpass
		
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
		print nextfilename
		nextfilenameHIpass= replacestring("_rCAR_SD4SEdata.pxp",nextfilename,"_HI_NIP.pxp")
	
		// load all the data from it
		// this will include the SEdata folder if there is one
		loaddata/p=inputpath/r/o=1 nextfilename
		
		// OK, now we've got a blank experiment with an SEdata folder
		// inside the SEdata folder are sets of SEdatarec, SEheadrec, SEfilehead or whatever, for each channel
		setdatafolder SEdata		
		
		// also load matching SD data from HIpass wave
		loaddata/p=inputpathHIpass/S="data_records"/J="SDs_postsub_4SDblank"/r/o=1 nextfilenameHIpass
		WAVE SDs = root:SEdata:SDs_postsub_4SDblank
		
		// split for later lookup
		make/O/n=(DimSize(SDs, 0)) SDlist = SDs[p][0]
		make/O/n=(DimSize(SDs, 0)) channelnumberlist = SDs[p][1]

		// going to need to load 
		
		// make a list of the datarec waves and use it as an index
		string datarecs = Wavelist("*_SEdatarec",";",""), nextdatarecname, prefix,nextheaderrecname, nextheaderfilename,channelname
		variable numdatarecs = itemsinlist(datarecs)
		variable SD
		
		// for each datarec wave, run selecttimestamps_twolists, and make sure its output is tagged correctly
		for (j=0; j < numdatarecs; j += 1)
		
			nextdatarecname = StringFromList(j, datarecs)
			nextheaderrecname = replacestring("_SEdatarec",nextdatarecname,"_SEheadrec")
			nextheaderfilename = replacestring("_SEdatarec",nextdatarecname,"_SEheadfile")
			
			WAVE nextdatarec = $nextdatarecname
			WAVE nextheaderrec = $nextheaderrecname
			WAVE nextheaderfile = $nextheaderfilename
			
			prefix = replacestring("_SEdatarec",nextdatarecname,"")
			
			// parse channel name out of prefix
			channelname = betweenbeforeandafter(prefix,"HI_NIP","_rCAR")
			
			// use channel name to get SD
			FindValue/T=0.1/V=(str2num(channelname)) channelnumberlist
			Variable theSD = SDlist[V_Value]		
		
			// this will create zeroes and ones
			selecttimestamps_twolists(prefix, "",saturationlevel, saturationtolerance,(65535*baselinewindow_pct/100)/2,theSD,maxspikewidth_pts)
			WAVE zeroes = $(prefix+"_zeroes")
			WAVE ones = $(prefix+"_ones")
			
			// convert ones into a timestamps list which can be fed to pareSEdata
			make/O/D/n=(numpnts(ones)) $(prefix+"ones_ts")/WAVE=ones_timestamps = getONEtimestampfromsignedints(nextheaderrec,ones[p])

			pareSEdata (nextheaderrec, nextheaderfile, nextdatarec,ones_timestamps,SEfoldersuffix)

			// now we are in the new SE folder - need to get back to the old one
			setdatafolder root:SEdata
						
			// move outputs of selecttimestamps into new SEdata folder
			movewave $(prefix+"_segpeak1"), $("::SEdata"+SEfoldersuffix+":"+prefix+"_segpeak1") 
			movewave $(prefix+"_segVpp"),$("::SEdata" + SEfoldersuffix+":"+prefix+"_segVpp")
			movewave $(prefix+"_ones"), $("::SEdata" + SEfoldersuffix+":"+prefix+"_ones")
			movewave $(prefix+"_zeroes"), $("::SEdata" + SEfoldersuffix+":"+prefix+"_zeroes")
			
		endfor
		
		// get one SE string
		// firstSEstring = stringfromlist(0,SEstringlist)
		// refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]		
		
		//nextnsepathstring = outputpathnsestring +(":"+replacestring("_HI_NIP.pxp",nextfilename,""))		
		newfilename = nextfilename
		// writeNSE_all (SEstringlist, nextnsepathstring)
		
		// kill out the previous files
		setdatafolder root:
		killdatafolder/z headers_records
		killdatafolder/z headers_file
		killdatafolder/z data_records
							
		// save experiment to outputpath with new name
		saveexperiment/C/P=outputpathpxp as newfilename
		
		// kill everything
		setdatafolder root:
		killwaves/a/z
		
		cleardatafoldersBATCH()	
		
	endfor
	
end


// check progress by monitoring output folder
// optionally clear input folder as it moves along
// if outputpathnsestring == "", don't make .nse
// makes a new set of spike event files from an old set
// "_sort1" paramaters: saturation level:30000, saturationtolerance:0, baselinewindow_pct:25, maxspikewidth_pts:20
Function filter_SEdata_inplace (input_SEfoldersuffix, output_SEfoldersuffix, saturationlevel, saturationtolerance,baselinewindow_pct,maxspikewidth_pts)
	string input_SEfoldersuffix, output_SEfoldersuffix
	Variable saturationlevel, saturationtolerance,baselinewindow_pct,maxspikewidth_pts
	
	// inside the SEdata folder are sets of SEdatarec, SEheadrec, SEfilehead or whatever, for each channel
	setdatafolder $("root:SEdata_"+input_SEfoldersuffix)		
	
	string channelprefix = "HI_NIP"
	
	variable j
		
	// also load matching SD data from HIpass wave
	WAVE SDs = root:data_records:SDs_RAW_4SDblank_3ms
		
	// split for later lookup
	make/O/n=(DimSize(SDs, 0)) SDlist = SDs[p][0]
	make/O/n=(DimSize(SDs, 0)) channelnumberlist = SDs[p][1]

	// make a list of the datarec waves and use it as an index
	string datarecs = Wavelist("*_SEdatarec",";",""), nextdatarecname, inputSEdataname,outputSEdataname,nextheaderrecname, nextheaderfilename,channelname,channelstring
		
	variable numdatarecs = itemsinlist(datarecs)
	variable SD
	
	// for each datarec wave, run selecttimestamps_twolists, and make sure its output is tagged correctly
	for (j=0; j < numdatarecs; j += 1)

		nextdatarecname = StringFromList(j, datarecs)
		nextheaderrecname = replacestring("_SEdatarec",nextdatarecname,"_SEheadrec")
		nextheaderfilename = replacestring("_SEdatarec",nextdatarecname,"_SEheadfile")
		
		WAVE nextdatarec = $nextdatarecname
		WAVE nextheaderrec = $nextheaderrecname
		WAVE nextheaderfile = $nextheaderfilename
		
		inputSEdataname = replacestring("_SEdatarec",nextdatarecname,"")
		outputSEdataname = replacestring(input_SEfoldersuffix, inputSEdataname,output_SEfoldersuffix)
		
		// parse channel name out of prefix
		channelstring = betweenbeforeandafter(inputSEdataname,"HI_NIP","_")
		channelname = channelprefix + channelstring
		print channelname
		
		// use channel name to get SD
		FindValue/T=0.1/V=(str2num(channelname)) channelnumberlist
		Variable theSD = SDlist[V_Value]		
		
		// this will create zeroes and ones
		selecttimestamps_twolists(inputSEdataname, outputSEdataname, saturationlevel, saturationtolerance,(65535*baselinewindow_pct/100)/2,theSD,maxspikewidth_pts)
		WAVE zeroes = $(outputSEdataname+"_zeroes")
		WAVE ones = $(outputSEdataname+"_ones")
		
		// convert ones into a timestamps list which can be fed to pareSEdata
		make/O/D/n=(numpnts(ones)) $(outputSEdataname+"ones_ts")/WAVE=ones_timestamps = getONEtimestampfromsignedints(nextheaderrec,ones[p])
		pareSEdata (nextheaderrec, nextheaderfile, nextdatarec,ones_timestamps,output_SEfoldersuffix)

		// now we are in the new SE folder - need to get back to the old one
		setdatafolder $("root:SEdata_"+input_SEfoldersuffix)		
						
		// move outputs of selecttimestamps into new SEdata folder
		movewave $(outputSEdataname+"_segpeak1"), $("::SEdata_"+output_SEfoldersuffix+":"+outputSEdataname+"_segpeak1") 
		movewave $(outputSEdataname+"_segVpp"),$("::SEdata_" + output_SEfoldersuffix+":"+outputSEdataname+"_segVpp")
		movewave $(outputSEdataname+"_ones"), $("::SEdata_" + output_SEfoldersuffix+":"+outputSEdataname+"_ones")
		movewave $(outputSEdataname+"_zeroes"), $("::SEdata_" + output_SEfoldersuffix+":"+outputSEdataname+"_zeroes")
		
	endfor
		
	// get one SE string
	// firstSEstring = stringfromlist(0,SEstringlist)
	// refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]		
	
	//nextnsepathstring = outputpathnsestring +(":"+replacestring("_HI_NIP.pxp",nextfilename,""))		
	// newfilename = nextfilename
	// writeNSE_all (SEstringlist, nextnsepathstring)
	
	// kill out the previous files

end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
// if outputpathnsestring == "", don't make .nse
// makes a new set of spike event files from an old set
// "_sort1" paramaters: saturation level:30000, saturationtolerance:0, baselinewindow_pct:25, maxspikewidth_pts:20
// differences between this and the one without the _stage2 suffix:
//		this one looks up SD wave in the database
//		in order to be able to do that, it needs to know subjectname and sessionname
Function filter_SEdata_inplace_stage2 (recording_pathstring, input_SEfoldersuffix, output_SEfoldersuffix, saturationlevel, saturationtolerance,baselinewindow_pct,maxspikewidth_pts)
	string input_SEfoldersuffix, output_SEfoldersuffix, recording_pathstring
	Variable saturationlevel, saturationtolerance,baselinewindow_pct,maxspikewidth_pts
	
	// inside the SEdata folder are sets of SEdatarec, SEheadrec, SEfilehead or whatever, for each channel
	setdatafolder $("root:SEdata_"+input_SEfoldersuffix)		
	
	string channelprefix = "HI_NIP"
	
	variable j
		
	// also load matching SD data from HIpass wave
	// WAVE SDs = root:data_records:SDs_RAW_4SDblank_3ms
	// load in the SD data we want, which is, for example, here:
	// build path to SD directory using basepaths, subjectname, sessionname
	String SDs_fullpath =  recording_pathstring + "SDs:SDs_RAW_noblank.ibw"
	loadwave SDs_fullpath
	WAVE SDs = SDs_RAW_noblank
			
	// split for later lookup
	make/O/n=(DimSize(SDs, 0)) SDlist = SDs[p][0]
	make/O/n=(DimSize(SDs, 0)) channelnumberlist = SDs[p][1]
	
	// make a list of the datarec waves and use it as an index
	string datarecs = Wavelist("*_SEdatarec",";",""), nextdatarecname, inputSEdataname,outputSEdataname,nextheaderrecname, nextheaderfilename,channelname,channelstring		
	variable numdatarecs = itemsinlist(datarecs)
	variable SD
	
	// step through datarecs
	for (j=0; j < numdatarecs; j += 1)
	
		nextdatarecname = StringFromList(j, datarecs)
		nextheaderrecname = replacestring("_SEdatarec",nextdatarecname,"_SEheadrec")
		nextheaderfilename = replacestring("_SEdatarec",nextdatarecname,"_SEheadfile")
		
		WAVE nextdatarec = $nextdatarecname
		WAVE nextheaderrec = $nextheaderrecname
		WAVE nextheaderfile = $nextheaderfilename
	
		inputSEdataname = replacestring("_SEdatarec",nextdatarecname,"")
		outputSEdataname = replacestring(input_SEfoldersuffix, inputSEdataname,output_SEfoldersuffix)
		
		// parse channel name out of prefix
		channelstring = betweenbeforeandafter(inputSEdataname,"HI_NIP","_")
		channelname = channelprefix + channelstring
		print channelname
		
		// use channel name to get SD
		FindValue/T=0.1/V=(str2num(channelname)) channelnumberlist
		Variable theSD = SDlist[V_Value]		
			
		// this will create zeroes and ones
		selecttimestamps_twolists(inputSEdataname, outputSEdataname, saturationlevel, saturationtolerance,(65535*baselinewindow_pct/100)/2,theSD,maxspikewidth_pts)
		WAVE zeroes = $(outputSEdataname+"_zeroes")
		WAVE ones = $(outputSEdataname+"_ones")
		
		// convert ones into a timestamps list which can be fed to pareSEdata
		make/O/D/n=(numpnts(ones)) $(outputSEdataname+"ones_ts")/WAVE=ones_timestamps = getONEtimestampfromsignedints(nextheaderrec,ones[p])
		
		pareSEdata (nextheaderrec, nextheaderfile, nextdatarec,ones_timestamps,output_SEfoldersuffix)

		// now we are in the new SE folder - need to get back to the old one
		setdatafolder $("root:SEdata_"+input_SEfoldersuffix)		
						
		// move outputs of selecttimestamps into new SEdata folder
		movewave $(outputSEdataname+"_ones"), $("::SEdata_" + output_SEfoldersuffix+":"+outputSEdataname+"_ones")
		movewave $(outputSEdataname+"_zeroes"), $("::SEdata_" + output_SEfoldersuffix+":"+outputSEdataname+"_zeroes")
		
	endfor
		
	// get one SE string
	// firstSEstring = stringfromlist(0,SEstringlist)
	// refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]		
	
	//nextnsepathstring = outputpathnsestring +(":"+replacestring("_HI_NIP.pxp",nextfilename,""))		
	// newfilename = nextfilename
	// writeNSE_all (SEstringlist, nextnsepathstring)
	
	// kill out the previous files

end

// check progress by monitoring output folder
// optionally clear input folder as it moves along
// if outputpathnsestring == "", don't make .nse
// makes a new set of spike event files from an old set
// "_sort1" paramaters: saturation level:30000, saturationtolerance:0, baselinewindow_pct:25, maxspikewidth_pts:20
// differences between this and the one without the _stage2 suffix:
//		this one looks up SD wave in the database
//		in order to be able to do that, it needs to know subjectname and sessionname
Function/S limit_SEdata_inplace_stage2 (input_SEfoldersuffix, timestart_us, length_s)
	string input_SEfoldersuffix
	Variable timestart_us, length_s
	
	// inside the SEdata folder are sets of SEdatarec, SEheadrec, SEfilehead or whatever, for each channel
	setdatafolder $("root:"+input_SEfoldersuffix)		
	
	string channelprefix = "HI_NIP"
	string timestring = base64shortener(num2str(timestart_us) + "_" + num2str(length_s))
	string newSEfoldername = input_SEfoldersuffix + "_" + timestring
	
	variable j

	// make a list of the datarec waves and use it as an index
	string headrecs = Wavelist("*_SEheadrec",";",""), nextdatarecname, inputSEdataname,outputSEdataname,nextheaderrecname, nextheaderfilename,channelname,channelstring
		
	variable numheadrecs = itemsinlist(headrecs)
	
	// for each datarec wave, run selecttimestamps_twolists, and make sure its output is tagged correctly
	for (j=0; j < numheadrecs; j += 1)

		nextheaderrecname = StringFromList(j, headrecs)
		nextdatarecname = replacestring("_SEheadrec",nextheaderrecname,"_SEdatarec")
		nextheaderfilename = replacestring("_SEheadrec",nextheaderrecname,"_SEheadfile")
		
		WAVE nextheaderrec = $nextheaderrecname
		WAVE nextdatarec = $nextdatarecname
		WAVE nextheaderfile = $nextheaderfilename
		
		inputSEdataname = replacestring("_SEdatarec",nextdatarecname,"")
		outputSEdataname = replacestring(input_SEfoldersuffix, inputSEdataname,newSEfoldername)
		
		// parse channel name out of prefix
		channelstring = betweenbeforeandafter(nextdatarecname,"HI_NIP","_")
		channelname = channelprefix + channelstring
		print channelname	
	
		getALLtimestampfromsignedints(nextheaderrec, "all")
		// now we've got all the timestamps
		WAVE all_timestamps
		// break it into zeroes and ones following same steps in selecttimestamps_twolists
		
		// make zeroes and ones list that can be fed to pareSEdata
		//  FIX!  These need to be channelname+"_ones"
		duplicate/o all_timestamps $(channelname+"_ingroup")/WAVE=timestamps_ingroup

		// zero out timestamps that are not in the desired range
		timestamps_ingroup = ((all_timestamps[p] > timestart_us) && (all_timestamps[p] < (timestart_us + length_s*1000000))) ? 1 : 0
		redimension/B timestamps_ingroup
		
		
		subsetSEdata (nextheaderrec, nextheaderfile, nextdatarec,timestamps_ingroup,newSEfoldername)

		// now we are in the new SE folder - need to get back to the old one
		setdatafolder $("root:" + input_SEfoldersuffix)		
						
		// move outputs of selecttimestamps into new SEdata folder
		movewave timestamps_ingroup, $("::" + newSEfoldername+":"+channelname+"_ingroup")
		
	endfor
		
	// get one SE string
	// firstSEstring = stringfromlist(0,SEstringlist)
	// refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]		
	
	//nextnsepathstring = outputpathnsestring +(":"+replacestring("_HI_NIP.pxp",nextfilename,""))		
	// newfilename = nextfilename
	// writeNSE_all (SEstringlist, nextnsepathstring)
	
	// kill out the previous files
	
	return timestring

end

// work from SEdata files and make new nse files
Function batchwritenewNSEs (SEdatapathstring, SEfoldersuffix, outputpathnsestring)
	string SEdatapathstring, SEfoldersuffix, outputpathnsestring
	
	newpath/o inputpath, SEdatapathstring
	newpath/o outputpathnse, outputpathnsestring
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(inputpath, -1,".pxp"))
	print filenamestr
	variable numfiles = itemsinlist(filenamestr),i,j
	string nextfilename,somewaves,SEstringlist
	string nextnsepathstring
	
	string newfilename,firstSEstring, refthreshstring
		
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
		print nextfilename
	
		// load all the data from it
		// this will include the SEdata folder if there is one
		loaddata/p=inputpath/r/o=1 nextfilename
		
		// OK, now we've got a blank experiment with an SEdata folder
		// inside the SEdata folder are sets of SEdatarec, SEheadrec, SEfilehead or whatever, for each channel
		setdatafolder $("root:SEdata"+SEfoldersuffix)
		
		//generate name list
		SEstringlist = replacestring("_SEdatarec",Wavelist("*_SEdatarec",";",""),"")
		
		// get one SE string
		 firstSEstring = stringfromlist(0,SEstringlist)
		 refthreshstring = firstSEstring[strsearch(firstSEstring,"_r",0)+1,strlen(firstSEstring)-1]		
		
		nextnsepathstring = outputpathnsestring +(":"+nextfilename[0,18])		
		newfilename = nextfilename
		
		writeNSE_all (SEstringlist, nextnsepathstring,SEfoldersuffix)
		
		// kill out the previous files
		setdatafolder root:
		killdatafolder/z headers_records
		killdatafolder/z headers_file
		killdatafolder/z data_records

		// kill everything
		setdatafolder root:
		killwaves/a/z
		
		cleardatafoldersBATCH()	
		
	endfor
	
end


Function testandaveragematchesBATCH (matchstring, exclude, AVGname)
	string matchstring, exclude, AVGname
	
		string somewaves = Wavelist(matchstring,";","")
		variable numwaves =  itemsinlist(somewaves),i
		
		printf "computing average for%d waves: %s\r", numwaves,somewaves
		WAVE firstwave = $(stringfromlist(0,somewaves))
		
		// the below line was a bug! leaving it here until I can figure out what it affected.
		//duplicate/o firstwave AVG
		
		printf "%s\r",stringfromlist(0,somewaves)
		variable length = numpnts(firstwave)
		
		// build in a couple of tests here
		if (numwaves != 16)
			printf "YIKES\rnumber of waves is not 16\r\r"
		endif
	
		for (i=1; i < numwaves; i += 1)
			printf "...+ %s\r", stringfromlist(i,somewaves)
			WAVE nextwave = $(stringfromlist(i,somewaves))
			if (numpnts(nextwave) != length)
				printf "NOTE\r\r\rlength of %s does not match length of %s\r", nameofwave(nextwave), nameofwave(firstwave)
			endif
		endfor	

		variable numexcludes = itemsinlist(exclude)
		string nextexclude
		variable k
		for (k=0; k< numexcludes; k += 1)
			nextexclude = StringFromList(k, exclude)
			printf "removing %s from list\r", nextexclude
			somewaves = RemoveListItem(WhichListItem(nextexclude, somewaves), somewaves)		
		endfor

		printf "included in average %s:\r%s\r", avgname, somewaves
		//fWaveAverage(somewaves, "", 0, 0, avgname, "")
		fWaveAverage_smallNbigwaves(somewaves, "", 0, 0, avgname, "")

end


// check progress by monitoring output folder
// optionally clear input folder as it moves along
Function batchdeletejunk ()
	
	// how many files in inputpath?
	string filenamestr = (indexedfile(HIpass_corrected, -1,".pxp"))
	variable numfiles = itemsinlist(filenamestr),i
	string nextfilename
	
	// for each
	for (i=0; i < numfiles; i += 1)
	
		nextfilename = stringfromlist(i, filenamestr)
	
		// load all the data  from it
		loaddata/p=HIpass_corrected/r/o=1 nextfilename

		// delete all this junk
		killwaves/z root:BB4
		killdatafolder/z nextmouse8

		// save experiment to outputpath with new name
		saveexperiment/C/P=HIpass_junkdeleted as nextfilename		
		
	endfor

end

//--------------------------------------------------------
// clears all data folders in current experiment, along with waves and variables (except those directly in root)
// from Chris Hempel
function clearDataFoldersBATCH()
string folders = datafolderdir(1)
string thisFolder
variable i,n 
n= itemsInList(folders,",")
closeAllBATCH()
do
	thisFolder = stringFromList(i,folders,",")
	if(i==0)
		thisFolder = thisFolder[8,strlen(thisFolder)]
	endif
	if(i==(n-1))
		thisFolder = thisFolder[0,(strlen(thisFolder)-3)]
	endif
	killDataFolder $thisFolder
	//killvariables /A /Z
	//killstrings/A /Z
	i+=1
while (i<n)
End

//----------------------------------------------------
// closes all graphs, tables, layouts, notebooks, panels and XOP target windows
// from Chris Hempel
function closeAllBATCH()
	string windowName
	do
		windowName=WinName(0,1)
		if (cmpstr(windowName, "")==0)
			break
		endif
		doWindow /K $windowName
	while (1)
	do
		windowName=WinName(0,2)
		if (cmpstr(windowName, "")==0)
			break
		endif
		doWindow /K $windowName
	while (1)
	do
		windowName=WinName(0,4)
		if (cmpstr(windowName, "")==0)
			break
		endif
		doWindow /K $windowName
	while (1)
	do
		windowName=WinName(0,16)
		if (cmpstr(windowName, "")==0)
			break
		endif
		doWindow /K $windowName
	while (1)
	do
		windowName=WinName(0,64)
		if (cmpstr(windowName, "")==0)
			break
		endif
		doWindow /K $windowName
	while (1)
	do
		windowName=WinName(0,4096)
		if (cmpstr(windowName, "")==0)
			break
		endif
		doWindow /K $windowName
	while (1)
end