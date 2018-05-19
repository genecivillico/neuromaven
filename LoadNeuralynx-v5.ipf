#pragma rtGlobals=1		// Use modern global access method.
#include  <Waves Average>


// updated to v5 September 2013
// now loads 33 lines of header, compensates DSP delay


//	LoadNeuralynxBinaryCSFile(pathName, fileName, channelBaseName, scaleFactor, createTable, createGraph)
//
//	pathName is the name of an Igor symbolic path or "".
//	fileName is one of the following:
//		The name of a file in the folder designated by pathName.
//		A partial path from the folder designated by pathName to the file to be loaded.
//		A full path to the file to be loaded.
//		"" to get an Open File dialog.
//
//	This routine loads Neuralynx "continuously sampled data" files which have a ".Ncs"
//	extension and often contain EEG data. Each file contains that data for one channel.
//
//	NOTE: This requires version 1.25 or later Neuralynx files which start with a 16,384 byte header.
//	Earlier files lack this header.

/// ************ must change subsample number by hand (in loadneuralynxinfo)***************
// ** for digilynx, samplingfrequency = 32552.08367506388.  this # is hard coded.  
// ** for analog, samplingfrequency = 30303  need to change this in the code to load these files

// Add an item to Igor's Load Waves submenu (Data menu)
Menu "Load Waves"   // this creates extra options in the data//load waves folder
	"Load Neuralynx Binary CS File...", DoLoadNeuralynxBinaryCSFile()
	"Load All Neuralynx Binary CS Files In Folder...", loadNL_GC("", "CSC")
End


// load directories within experiment
// current data folder should contain the metadata waves
Function MultiNCSLoadPreprocessSave (startindex, stopindex, mousefolder, experimentnames, channelmatchstring, filter, deletionswave, toptobottom_channellist, pxpsuffix, destinationsubdir)
	WAVE/T  experimentnames, channelmatchstring, filter, deletionswave, toptobottom_channellist
	String pxpsuffix, destinationsubdir, mousefolder
	Variable startindex, stopindex
	
	// check for path
	pathinfo neuralynx
	if (!V_flag)
		abort "path neuralynx does not exist"
	endif
		
	// where are we
	string homefolder = getdatafolder(1)
	
	string baserawdatapath = S_path
	
	// main loop is over inputwaves
	variable numtoprocess = numpnts(experimentnames),i
	
	string nextpathdir
	
	// before we do anything, CHECK to make sure all these experiments exist
	if (!alldirectoriesexist(startindex, stopindex, S_path, mousefolder, experimentnames))
		abort
	endif	

	// for each experiment to load
	for (i=startindex; i <= stopindex; i += 1)
		
		// build path out of raw neuralynx path + date directory
		nextpathdir = S_path + mousefolder + ":" + experimentnames[i]
		newpath/o nextpath, nextpathdir
		
		// make wave references for wave arguments to next function
		// /Z because there won't always be a deletions wave
		WAVE/Z deletions = $(deletionswave[i])
		WAVE toptobottomchannels = $("root:"+toptobottom_channellist[i])
		
		loadNCSdirandsavepxp("nextpath", channelmatchstring[i], filter[i], pxpsuffix, destinationsubdir,deletionswave=deletions, toptobottomwave=toptobottomchannels)
		killpath nextpath

	endfor

end


// load all ncs files in a directory and save out a pxp
// also do various preprocessing

// inputpathname: name of an igor symbolic path to a disk location, created with Misc > New Path or NewPath command.  use "" to prompt dialog
// channelmatchstring: load channels matching this, e.g. "*CSC*"
// filter: "" for no filtering, "HI" to bandpass filter 300-10000, "LO" to bandpassfilter 0.1-30
// deletionswave: list of intervals to delete before preprocessing data.  just use dummy if not using this - WAVE/Z will prevent error
// toptobottomwave: channel numbers arranged top to bottom (for correcting channel order)
// pxpsuffix: string to add to the end of experiment date to create result filename
// preprocesssubdir: last part of path to save result
Function LoadNCSDirAndSavePxp (inputpathname, channelmatchstring,filter, pxpsuffix, preprocesssubdir[,deletionswave,toptobottomwave])
	String inputpathname, channelmatchstring, preprocesssubdir, pxpsuffix, filter
	WAVE/Z deletionswave
	WAVE toptobottomwave
	
	PathInfo rawpxppath
	// just in case this path exists and is set to something else
	if (V_flag)
		killpath rawpxppath
	endif
	
	NewPath/C rawpxppath, ("Macintosh HD:Users:gene:Desktop:PREPROCESSED DATA:"+preprocesssubdir)
	//NewPath/C rawpxppath, ("N-drive:PREPROCESSED DATA:"+preprocesssubdir)
	// NewPath/C rawpxppath, ("NIPEPHYS:PREPROCESSED DATA:"+preprocesssubdir)

	//NewPath/C rawpxppath, ("NIPEPHYS II:PREPROCESSED DATA:"+preprocesssubdir)



	Variable err
	
	// where are we
	string homefolder = getdatafolder(1)
	string referencename,refstatus
	
	// change to root
	setdatafolder root:

	// load everything desired from this folder
	loadNL_GC(inputpathname,channelmatchstring,maxpointstoload=30000000)
	
	// loadNL_GC(inputpathname,channelmatchstring,maxpointstoload=28947967)
	//loadNL_GC(inputpathname,channelmatchstring,maxpointstoload=21926868)
	
	// loadNL_GC(inputpathname,channelmatchstring)
	
	
	RTErrorCheck("checkpoint1")
		
	// just so I have the experiment name in case I want it
	pathinfo $inputpathname
	string experimentdate = parsefilepath(0,S_path,":",1,0) 
	string experimentname = experimentdate + "_"+pxpsuffix +".pxp"
	
	// after this is finished, if there is no data_records directory, nothing was loaded, so no need to save or kill	
	if (!DataFolderExists("data_records"))
		return 0
	endif
	
	string channelprefix = replacestring("*",channelmatchstring,"")
	// this is the place to remap/rename the channels
	if (!ParamIsDefault(toptobottomwave))
		rename_channels(toptobottomwave)
		// we'll be back in root at the end of this
		channelprefix="HI_NIP"
	endif
	
	// do filtering if needed
	if (!stringmatch(filter,""))
		printf "filtering requested on %s\r", experimentname
		variable filterLOWCUT
		variable filterHIGHCUT
			
		if (stringmatch(filter,"HI"))		
			filterLOWCUT = 300
			filterHIGHCUT = 10000
		elseif (stringmatch(filter,"LO"))
			filterLOWCUT = 0.1
			filterHIGHCUT = 30
		endif
		
		setdatafolder root:data_records
		filterALL(filterLOWCUT, filterHIGHCUT, suffix="")
		RTErrorCheck("checkpoint2")
	endif
	
	// do deletions if needed
	if (!ParamIsDefault(deletionswave))
		printf "deletions requested on %s\r", experimentdate
		setdatafolder root:data_records
		deletefrompointlistALL(deletionswave)
	endif
	
	// create average wave (average of all)
	setdatafolder root:data_records
	printf "creating average wave AVG...\r"
	testandaveragematches(channelprefix)
	RTErrorCheck("checkpoint3")
	
	// kill AVGm and SDs if they exist (they are vestigial from older code)
	killwaves/z AVGm, SDs	
	
	refstatus = CARmaker_simple (channelprefix,0.5, 1.5)
	
	if (!stringmatch(refstatus, "same"))
		referencename = refstatus
	else
		printf "error!! raw data somehow already has a reference note\r\r\r\r"
	endif
	
	// before re-referencing, compute raw PSDs
	makeallPSDs(channelprefix,16,"_psd",12000, 95,10*32000,"Welch", 0)
	
	// subtract all matching and add wavenote explaining this
	rereference (channelprefix,16,referencename)
	RTErrorCheck("checkpoint4")
	
	// after re-referencing, compute reref PSDs
	makeallPSDs(channelprefix,16, "_psd_reref",12000, 95,10*32000,"Welch", 0)
	
	// compute and store SDs before blanking
	string SDpost_noblank_name = SDs_batch(channelprefix,"postsub_noblank")
	
	// compute and store blanked SDs (3 and 4, just to be safe)
	string SDpost3SDblankname = blankedSDs_batch(channelprefix,"postsub_3SDblank",3,3)
	RTErrorCheck("checkpoint5")

	string SDpost4SDblankname = blankedSDs_batch(channelprefix,"postsub_4SDblank",4,3)	
	RTErrorCheck("checkpoint6")

	SaveExperiment/C/P=rawpxppath as experimentname
	
	setdatafolder root:
	// clear everything
	killdatafolder/z headers_records
	killdatafolder/z headers_file
	killdatafolder/z data_records

end



// changed!  now calls remap_waves_byorder
Function rename_channels (channelmapwave)
	WAVE channelmapwave
	
	// load in channelmapwave
	
//	NewPath/O channelmap, "Macintosh HD:Users:nipadmin:Documents:SCIENCE:PROJECTS-active:NIP electrophysiology:"
//	string objectstoload = channelmapwavename+";"
//	loaddata/J=objectstoload/P=channelmap "averaged-event-rates.pxp"
	
	setdatafolder root:
	string thewavenames, thenewwavenames
	variable i, numwaves
	// headers_records
	if (datafolderexists("headers_records"))
		setdatafolder headers_records

		// add a character onto the end of each name (this will allow reuse of existing names in the renaming)
		thewavenames = wavelist("*",";","")			
		numwaves = itemsinlist(thewavenames)
		for (i=0; i < numwaves; i += 1)
			movewave $(stringfromlist(i,thewavenames)), $("t"+stringfromlist(i,thewavenames))		
		endfor

		thewavenames = wavelist("*",";","")			
		
		// sort out the wavenames with a bunch of replacements
		thenewwavenames = remap_names_byorder (thewavenames, channelmapwave)
		
		numwaves = itemsinlist(thewavenames)
		for (i=0; i < numwaves; i += 1)
			if (!stringmatch(stringfromlist(i,thenewwavenames), "WRONG*"))
				movewave $(stringfromlist(i,thewavenames)), $(stringfromlist(i,thenewwavenames))		
			else
				killwaves $(stringfromlist(i,thewavenames))
			endif
		endfor
		
		setdatafolder root:
	endif

	// headers_file
	if (datafolderexists("headers_file"))
		setdatafolder headers_file
		
		// add a character onto the end of each name (this will allow reuse of existing names in the renaming)
		thewavenames = wavelist("*",";","")			
		numwaves = itemsinlist(thewavenames)
		for (i=0; i < numwaves; i += 1)
			movewave $(stringfromlist(i,thewavenames)), $("t"+stringfromlist(i,thewavenames))
		endfor
		
		// regenerate list
		thewavenames = wavelist("*",";","")			

		// sort out the wavenames with a bunch of replacements
		thenewwavenames = remap_names_byorder (thewavenames, channelmapwave)
		
		numwaves = itemsinlist(thewavenames)
		for (i=0; i < numwaves; i += 1)
			if (!stringmatch(stringfromlist(i,thenewwavenames), "WRONG*"))
				movewave $(stringfromlist(i,thewavenames)), $(stringfromlist(i,thenewwavenames))	
			else
				killwaves $(stringfromlist(i,thewavenames))
			endif
		endfor

		setdatafolder root:
	endif
		
	// data_records
	if (datafolderexists("data_records"))
		setdatafolder data_records

		// add a character onto the end of each name (this will allow reuse of existing names in the renaming)
		thewavenames = wavelist("*",";","")			
		numwaves = itemsinlist(thewavenames)
		for (i=0; i < numwaves; i += 1)
			movewave $(stringfromlist(i,thewavenames)), $("t"+stringfromlist(i,thewavenames))		
		endfor

		thewavenames = wavelist("*",";","")			
		
		// sort out the wavenames with a bunch of replacements
		thenewwavenames = remap_names_byorder (thewavenames, channelmapwave)
		
		numwaves = itemsinlist(thewavenames)
		for (i=0; i < numwaves; i += 1)
			if (!stringmatch(stringfromlist(i,thenewwavenames), "WRONG*"))
				movewave $(stringfromlist(i,thewavenames)), $(stringfromlist(i,thenewwavenames))		
			else
				killwaves $(stringfromlist(i,thewavenames))
			endif
		endfor		
		
		setdatafolder root:
	endif
end

Function rename_channels_test (channelmapwave)
	WAVE channelmapwave
	
	// load in channelmapwave
		
	string thewavenames, thenewwavenames
	variable i, numwaves

	thewavenames = wavelist("*",";","")			
	
	// sort out the wavenames with a bunch of replacements
	thenewwavenames = remap_names (thewavenames, channelmapwave)
	
	print thenewwavenames
	numwaves = itemsinlist(thewavenames)
	for (i=0; i < numwaves; i += 1)
		movewave $(stringfromlist(i,thewavenames)), $(stringfromlist(i,thenewwavenames))		
	endfor
	
end

Function/S remap_names(thewavenames, channelmapwave)
	string thewavenames
	wave channelmapwave

	variable i
	string newwavenames = thewavenames
	string nextwavename
	
	variable numwavenames = itemsinlist(thewavenames), endinteger
	// use return_end_integer!!
	
	for (i=0; i < numwavenames; i += 1)
	
		nextwavename = StringFromList(i, thewavenames)
		endinteger = return_end_integer(nextwavename)
		newwavenames = replacestring(nextwavename+";", newwavenames, "HI_NIP"+num2str(channelmapwave[endinteger-1])+";")
	
	endfor
	
	return newwavenames
	
end

Function/S remap_names_byorder(thewavenames, channelmapwave)
	string thewavenames
	wave channelmapwave

	variable i
	string newwavenames = thewavenames
	string nextwavename
	
	variable numwavenames = itemsinlist(thewavenames), endinteger
	// use return_end_integer!!
	
	for (i=0; i < numwavenames; i += 1)
	
		nextwavename = StringFromList(i, thewavenames)
		
		// locate i+1 in the channelmap
		FindValue/i=(i+1) channelmapwave 		
		
		// if it's found
		if (V_value >= 0)
			// replace the current name with a name derived from the position where this was found.		
			newwavenames = replacestring(nextwavename+";", newwavenames, "HI_NIP"+num2str(V_value+1)+";")		
		else
		// otherwise, replace with killstring
			newwavenames = replacestring(nextwavename+";", newwavenames, "WRONG"+num2str(i+1)+";")		
		endif		
		
	endfor
	
	return newwavenames
	
end

//this loads in a whole folder of NL files
// leave pathname = "" for dialogue
// adapted from LoadAllNeuralynxBinaryCSFiles by cw 2/18/08
// further adapted by gc 11/11
Function LoadNL_GC (pathName, matchstring[,maxpointstoload]) 
	String pathName			// Name of an Igor symbolic folder created by Misc->NewPath. "" for dialog.
	String matchstring
	Variable maxpointstoload
	
	//Variable scaleFactor			// Used to convert A/D counts to voltage. 0 for dialog.
	
	Variable err = 0

	// for reference: 30000000 points =~15 minutes of data at 32 kHz
	
	Variable truncate = 0
	if (!ParamIsDefault(maxpointstoload))
		printf "limiting load to first %d data points\r", maxpointstoload	
		truncate = 1
	else
		printf "loading all data... \r\r"
	endif
	
	if (strlen(pathName) == 0)
		String message = "Select a directory containing Neuralynx .ncs files matching "+matchstring
		NewPath/O/M=message NeuralynxDataPath		// This displays a dialog in which you can select a folder
		if (V_flag != 0)
			return V_flag								// -1 means user canceled
		endif
		pathName = "NeuralynxDataPath"
	endif
	printf "HEY\r\r\r"

	String nameOfWaveLoaded, wavesLoaded = ""

	String fileName, filenamestr
	Variable i, numch
	filenamestr = (indexedfile($pathname, -1,".ncs"))
	filenamestr = sortlist (listmatch(filenamestr,"*"+matchstring+"*"),";", 16)
	print filenamestr
	numch = (itemsinlist( filenamestr))
	for (i=0; i<numch; i+=1)
	
		fileName = stringfromlist(i, filenamestr)
		print filename

		nameofwaveLoaded = LoadNeuralynxBinaryCSFile(pathName, fileName)
		
		if (err != 0)
			return err
		endif
		
		wavesLoaded += nameOfWaveLoaded + ";"
				
		// truncate!
		if (truncate)		
			WAVE loadedwave = $("root:data_records:"+nameofwaveLoaded)
			variable length = numpnts(loadedwave)
			if (length > maxpointstoload)
			
				printf "%s has more than %d points; deleting the last %d points\r", nameofwaveloaded, maxpointstoload, (length-maxpointstoload)
				deletepoints/m=0 maxpointstoload, (length-maxpointstoload), loadedwave

			endif
		endif
		
	endfor

End

//this loads in a whole folder of NL files
// leave pathname = "" for dialogue
// adapted from LoadAllNeuralynxBinaryCSFiles by cw 2/18/08
// further adapted by gc 11/11
Function LoadNL_GC2 (pathstring, matchstring[,maxpointstoload]) 
	String pathstring			// Name of an Igor symbolic folder created by Misc->NewPath. "" for dialog.
	String matchstring
	Variable maxpointstoload
	
	//Variable scaleFactor			// Used to convert A/D counts to voltage. 0 for dialog.
	
	Variable err = 0

	// for reference: 30000000 points =~15 minutes of data at 32 kHz
	
	Variable truncate = 0
	if (!ParamIsDefault(maxpointstoload))
		printf "limiting load to first %d data points\r", maxpointstoload	
		truncate = 1
	else
		printf "loading all data... \r\r"
	endif
	
	// make the path here
	if (strlen(pathstring) == 0)
		String message = "Select a directory containing Neuralynx .ncs files matching "+matchstring
		NewPath/O/M=message session_path		// This displays a dialog in which you can select a folder
		if (V_flag != 0)
			return V_flag								// -1 means user canceled
		endif
	else	
		NewPath/O session_path, pathstring
	endif
	
	string pathName = "session_path"

	String nameOfWaveLoaded, wavesLoaded = ""

	String fileName, filenamestr
	Variable i, numch
	filenamestr = (indexedfile($pathname, -1,".ncs"))
	filenamestr = sortlist (listmatch(filenamestr,"*"+matchstring+"*"),";", 16)
	print filenamestr
	numch = (itemsinlist( filenamestr))
	for (i=0; i<numch; i+=1)
	
		fileName = stringfromlist(i, filenamestr)
		print filename

		nameofwaveLoaded = LoadNeuralynxBinaryCSFile(pathName, fileName)
		
		if (err != 0)
			return err
		endif
		
		wavesLoaded += nameOfWaveLoaded + ";"
				
		// truncate!
		if (truncate)		
			WAVE loadedwave = $("root:data_records:"+nameofwaveLoaded)
			variable length = numpnts(loadedwave)
			if (length > maxpointstoload)
			
				printf "%s has more than %d points; deleting the last %d points\r", nameofwaveloaded, maxpointstoload, (length-maxpointstoload)
				deletepoints/m=0 maxpointstoload, (length-maxpointstoload), loadedwave

			endif
		endif
		
		// add a wave 
		
	endfor

End

Function LoadNeuralynxInfo(refNum, timestamp, channelNumber, scalefactor, subsample)
	Variable refNum
	Variable timestamp, channelNumber, scalefactor, subsample
	
	Variable lowOrder, highOrder
	 Variable ADBitVolts, subsamplenum                   //variable/G == global variable
       String ADBitVoltsString, subsamplestring
       variable headerSize
       headerSize=0
       FSetPos refNum, headerSize
       variable i
     
     //  from the original provided function, this is replaced by the do-while below
     //  for(i=0;i<15;i=i+1)
     //  FReadLine refNum, ADBitVoltsString
     //  endfor 
     //  modified: dan 04 august 2008
       do
       FReadLine refNum, ADBitVoltsString
       while(stringmatch(ADBitVoltsString,"*-ADBitVolts*" ) !=1)
       ADBitVoltsString = ReplaceString(" ",ADBitVoltsString, "") //takes out spaces in string
       ADBitVolts = str2num (ReplaceString("-ADBitVolts",ADBitVoltsString, "")) //takes out '-ADBitVolts' and converts
      
       //  from the original provided function, this is replaced by the do-while below
       //for(i=0;i<6;i=i+1)
     //  FReadLine refNum, subsamplestring
     //  endfor
     //  modified: dan 04 august 2008
       // FSetPos refNum, 0
      //  do
      //  	FReadLine refNum, subsamplestring
     //   while(stringmatch(subsamplestring,"*-subsamplinginterleave*" ) !=1||stringmatch(subsamplestring,"*-DspHighCut*" )!=1)
	//Subsamplenum = str2num(replacestring("-subsamplinginterleave ", subsamplestring, ""))
      //manually set because subsamplinginterleave is missing from the file
      Subsamplenum = 3
	
       headerSize=16384
       FSetPos refNum, headerSize
       scaleFactor = ADBitVolts
       subsample=subsamplenum

	//Fstatus refNum;print V_filepos
	// read 32-bit word (4 bytes), little-endian, unsigned
	FBinRead/F=3/U/B=3 refNum, lowOrder
	//Fstatus refNum;print V_filepos
	FBinRead/F=3/U/B=3 refNum, highOrder
	//Fstatus refNum;print V_filepos

	timestamp = lowOrder + 2^32*highOrder
	
	//Print/D lowOrder, highOrder, timestamp			// For debugging only

	timestamp /= 1E6			// Convert from microseconds to seconds
	
	FBinRead/F=3/U/B=3 refNum, channelNumber
	
	//commented out by dan 08/04/08. seemed unused and caused an error, since samplingFrequency doesn't exist
	//FBinRead/F=3/U/B=3 refNum, samplingFrequency 
	
	Print timestamp, channelNumber         	// For debugging only
End

Function GetTimeStamp (refNum, recordnumber, recordsize)
	variable refNum, recordnumber, recordsize
	
	variable loworder, highorder
	
	// don't let this function change the file position
	FStatus refNum
	Variable storefilepos = V_filepos
	
	variable headerSize=16384
	FSetPos refNum, headerSize+(recordnumber)*recordsize

	// read 32-bit word (4 bytes), little-endian, unsigned
	FBinRead/F=3/U/B=3 refNum, lowOrder
	FBinRead/F=3/U/B=3 refNum, highOrder

	//print lowOrder, highOrder

	variable timestamp
	timestamp = lowOrder + 2^32*highOrder

	FSetPos refNum, storefilepos
	
	//Print/D lowOrder, highOrder, timestamp			// For debugging only

	timestamp /= 1E6
	return timestamp
end

Function GetSETimeStamp (refNum, recordnumber, recordsize)
	variable refNum, recordnumber, recordsize
	
	variable loworder, highorder
	
	// don't let this function change the file position
	FStatus refNum
	Variable storefilepos = V_filepos
	
	variable headerSize=16384
	FSetPos refNum, headerSize+(recordnumber)*recordsize

	FBinRead/F=3/U/B=3 refNum, lowOrder
	FBinRead/F=3/U/B=3 refNum, highOrder

	//print lowOrder, highOrder

	variable timestamp
	timestamp = lowOrder + 2^32*highOrder

	FSetPos refNum, storefilepos
	
	//Print/D lowOrder, highOrder, timestamp			// For debugging only

	timestamp /= 1E6
	return timestamp
end

Function GetSETimeStamp_us (refNum, recordnumber, recordsize)
	variable refNum, recordnumber, recordsize
	
	variable loworder, highorder
	
	// don't let this function change the file position
	FStatus refNum
	Variable storefilepos = V_filepos
	
	variable headerSize=16384
	FSetPos refNum, headerSize+(recordnumber)*recordsize

	FBinRead/F=3/U/B=3 refNum, lowOrder
	FBinRead/F=3/U/B=3 refNum, highOrder

	//print lowOrder, highOrder

	variable timestamp
	timestamp = lowOrder + 2^32*highOrder

	FSetPos refNum, storefilepos
	
	//Print/D lowOrder, highOrder, timestamp			// For debugging only

	//timestamp /= 1E6
	return timestamp
end

Function LoadNeuralynxHeader(refNum, lines)
	Variable refNum, lines
	
	Variable lowOrder, highOrder
	 Variable ADBitVolts, subsamplenum                   //variable/G == global variable
       String ADBitVoltsString, subsamplestring
       variable headerSize
       headerSize=0
       FSetPos refNum, headerSize
       variable i
 
 	// header looks to be about thirty lines most of the time
 	make/O/t/n=(lines) header
 	string nextline
 	
 	for (i=0; i < lines; i += 1)
 
	 	FReadLine refNum, nextline
	 	header[i] = nextline
 
 	endfor
 	
End

Function LoadNeuralynxData(refNum, channelName, numDataRecords)
	Variable refNum
	String channelName
	Variable numDataRecords

	// Initially we will load all of the data, including the timestamp, channel number, sampling frequency
	// and numValidSamples as two-byte signed data. Then we will strip out the non-data bytes.
	
	// This is the number of two-byte points needed to hold the timestamp, channel number,
	// sampling frequency and numValidSamples values for one record.
	Variable numInfoPoints = 10
	make/n=(10,numDataRecords)/O recordheaders
	
	// Number of two-byte points needed to hold all records.
	Variable numPoints = numDataRecords * (numInfoPoints + 512)

	// Load everything into a temporary wave.
	Make/O/N=(numPoints)/W, tempNeuralynxData
	FBinRead/B=3 refNum, tempNeuralynxData					// Read all of the data.
	
	// The real output wave will contain just the sample data.
	numPoints = numDataRecords * 512
	Make/O/N=(numPoints)/W $channelName
	Wave cw = $channelName									// Create reference to wave created by Make.
	
	// Now sort the wheat from the chaff.
	Variable numValidSamples = 512, totalValidSamples = 0
	Variable startInputPoint = 0, startOutputPoint = 0
	Variable i

	for(i=0; i<numDataRecords; i+=1)
		//printf "timestamp = %.6f\r", GetTimeStamp (refNum, i, 1044)
		numValidSamples = tempNeuralynxData[startInputPoint+8]
		totalValidSamples += numValidSamples
		cw[startOutputPoint, startOutputPoint+numValidSamples-1] = tempNeuralynxData[startInputPoint+numInfoPoints+p-startOutputPoint]
		recordheaders[][i] = tempNeuralynxdata[startinputpoint+p]

		startInputPoint += numInfoPoints + numValidSamples
		startOutputPoint += numValidSamples
		
	endfor
	
//	try
//		Redimension/N=(totalValidSamples) cw; abortonRTE
//	catch		
//		close refNum
//		printf "aborted while loading channel %s\r", channelName
//		abort
//	endtry

	KillWaves/Z tempNeuralynxData
End

Function LoadNeuralynxSEData(refNum, channelName, numDataRecords, DataPointsPerRecord)
	Variable refNum
	String channelName
	Variable numDataRecords, datapointsperRecord

	// Initially we will load all of the data, including the timestamp, channel number, sampling frequency
	// and numValidSamples as two-byte signed data. Then we will strip out the non-data bytes.
	
	// This is the number of two-byte points needed to hold the timestamp, channel number,
	// sampling frequency and numValidSamples values for one record.
	Variable numInfoPoints = 24
	make/n=(24,numDataRecords)/O recordheaders
	
	// Number of two-byte points needed to hold all records.
	Variable numPoints = numDataRecords * (numInfoPoints + DataPointsPerRecord)

	// Load everything into a temporary wave.
	Make/O/N=(numPoints)/W, tempNeuralynxData
	FBinRead/B=3 refNum, tempNeuralynxData					// Read all of the data.

	FSetpos refNum, 16384
	Fstatus refnum
	
	// The real output wave will contain just the sample data.
	numPoints = numDataRecords * datapointsperRecord
	Make/O/N=(numPoints)/W $channelName
	Wave cw = $channelName									// Create reference to wave created by Make.
	
	// Now sort the wheat from the chaff.
	Variable numValidSamples = datapointsperRecord, totalValidSamples = 0
	Variable startInputPoint = 0, startOutputPoint = 0
	Variable i

	for(i=0; i<numDataRecords; i+=1)
		//printf "timestamp = %.6f\r", GetTimeStamp (refNum, i, 1044)
		//numValidSamples = tempNeuralynxData[startInputPoint+8]
		numValidsamples = 32 
		totalValidSamples += numValidSamples
		cw[startOutputPoint, startOutputPoint+numValidSamples-1] = tempNeuralynxData[startInputPoint+numinfopoints+p-startOutputPoint]
		recordheaders[][i] = tempNeuralynxdata[startinputpoint+p]

		startInputPoint += numInfoPoints + numValidSamples
		startOutputPoint += numValidSamples
		
	endfor
	
	// extract timestamps to a wave
	make/D/o/n=(numdatarecords) timestamps = GetSETimeStamp_us (refNum, p, 112)
	
	
	//Redimension/N=(totalValidSamples) cw

	//KillWaves/Z tempNeuralynxData
End

Function/S LoadNeuralynxBinaryCSFile(pathName, fileName) 
	String pathName			// Igor symbolic path name or "" for dialog.
	String fileName				// file name, partial path and file name, or full path or "" for dialog.
	
	Variable err
	
	string nameOfWaveLoaded = ""

	// This puts up a dialog if the pathName and fileName do not specify a file.
	String message = "Select a Neuralynx binary CS file"
	Variable refNum
	Open/R/Z=2/P=$pathName/M=message/T=".Ncs" refNum as fileName
	
	// Save outputs from Open in a safe place.
	err = V_Flag
	String fullPath = S_fileName

	if (err != 0)
		return "User cancelled" //err			// -1 means user canceled.
	endif
	
	Printf "Loading Neuralynx binary CS data from \"%s\"\r", fullPath
	
	Variable headerSize = 16384			// Size of header in version 1.25 and later files
	FSetPos refNum, headerSize
	
	FStatus refNum
	Variable numDataBytes =  V_logEOF - headerSize
	
	if (numDataBytes == 0)
		printf "no data!\r"
		return "0"	
	endif
	
	Variable numDataRecords = trunc(numDataBytes / 1044)	// Each record contains 20 bytes of information followed by 1024 bytes of data.
	
	// Load the first timestamp value
	Variable timestamp, samplingFrequency, scalefactor, subsample
	
	// this function sets the values of all these variables (they are all being passed by reference)
	// GC changing name to LoadNeuralynxHeader because I want to get everything and store it
	
	// change for v5 of this ipf - now loading 33 lines because the headers got longer in Cheetah 5.6
	LoadNeuralynxHeader(refNum, 33)
	WAVE/T header
	
	// what do I need from the header
	// need to parse out subsample, timestamp, channelNumber, scalefactor, subsample
	String channelname, headersamplerate
	Variable ADBitVolts, DSPdelaycompensation, DSPdelay_us
	
	// Files generated by Cheetah 5.5.1 lack a "-FileVersion" line in their headers
	FindValue/TEXT="FileVersion" header
	if (V_value < 0)
		// header is 5.5.1 format	
		channelname = replacestring("\r",replacestring("-AcqEntName ",header[6], ""),"")
		ADBitVolts =  str2num (ReplaceString("-ADBitVolts",header[14], "")) 
		headersamplerate = replacestring("-SamplingFrequency ",header[12],"")
		DSPdelaycompensation = stringmatch(header[28], "*Enabled*")
		DSPdelay_us = str2num(replacestring("-DspFilterDelay_µs ", header[29],""))
		// clean up header by deleting extra loaded lines
		deletepoints 30,3,header
	else
		// if header is 5.6.0 format
		channelname = replacestring("\r",replacestring("-AcqEntName ",header[17], ""),"")
		ADBitVolts =  str2num (ReplaceString("-ADBitVolts",header[15], "")) 
		headersamplerate = replacestring("-SamplingFrequency ",header[13],"")
		DSPdelaycompensation = stringmatch(header[31], "*Enabled*")
		DSPdelay_us = str2num(replacestring("-DspFilterDelay_µs ", header[32],""))
	endif
	// test sample rate here
	
	// clean up the channelname
	channelname = cleanstring(channelname)
	
	// first time stamp is in seconds?
	variable firsttimestamp = gettimestamp(refnum, 0,1044)
	variable secondtimestamp = gettimestamp(refnum, 1,1044)
	
	printf "%16f\r", firsttimestamp
		
	// for debugging
	//variable m
	//for (m=0; m < 10; m += 1)
	//	variable test = gettimestamp(refnum,m,1044)
	//endfor
	
	Variable timestamp_diff = secondtimestamp - firsttimestamp 
	Variable sampleratecheck = (1000000/(timestamp_diff / 512))/1E6
	
	printf "sample rate determined empirically from first two records = %f\r", sampleratecheck
	printf "sample rate specified in header = %s\r", headersamplerate
		
	// for older Cheetah analog system
	// samplingfrequency = 30303/subsample
	
	// sample rate is an open question - figure this out.
	
	// for original Digilynx digital system
	// samplingfrequency = 32552.08367506388/subsample
	
	// for Digilynx digital system November 2011
	// verify this...
	
	// what is subsample??
	subsample = 1

	 samplingfrequency = 32000/subsample
	
	FSetPos refNum, headerSize												// Go back to start of data
		
	LoadNeuralynxData(refNum, channelName, numDatarecords)				
	Wave loadedwave = $channelName												// Create reference to wave created by LoadNeuralynxData.
       print "channelName: "+channelName
       
       WAVE recordheaders
       
       // we are not doing this anymore!  save time and disk space by storing data as 16-bit int rather than 32-bit single float
	//Redimension/S loadedwave		// Change to floating point so we can represent data in volts.
	//loadedwave *= ADBitVolts 		// Scale into volts.
	//print ADBitVolts

	nameOfWaveLoaded = channelName
	
	// next few lines added fall 2013
	// if DSPdelay_us is nonzero and DSPdelaycompensation is Disabled, apply a shift here
	
	// firsttimestamp is in seconds
	Variable wavestarttime_ms = firsttimestamp*1000
	if (DSPdelay_us > 0)
		if (!DSPdelaycompensation)
			wavestarttime_ms = (firsttimestamp*1000 - DSPdelay_us) // last term should be DSPdelay_us/1000
			printf "first time stamp logged as %16.0f us but header indicates uncompensated DSP delay of %d us\r  starting %s wave at x = %16f ms\r\r", firsttimestamp*1000000, DSPdelay_us, channelName, wavestarttime_ms
		else
			wavestarttime_ms = (firsttimestamp*1000)
			printf "first time stamp logged as %16.0f us; header indicates DSP delay of %d us has been compensated in time stamps\r  starting %s wave at x =%16f ms\r\r", firsttimestamp*1000000, DSPdelay_us, channelName, wavestarttime_ms
		endif			
	endif
	
	// gc changed start to 0 (fall 2011)
	// then changed back to first timestamp (fall 2013) for lining up with events
	SetScale/P x, wavestarttime_ms, (1/samplingFrequency)*1000, "ms", loadedwave  // cw changed to ms (from s) 10/30/08
	//SetScale d, 0, 0, "V", loadedwave													    // Note that the data units are volts (not anymore! -gc)

	Close refNum

	// three waves have been created: file header, record headers, and record data
	// create folders for these if they don't exist
	
	// these waves may end up saved out as individual files.  use wavenote to associate them with their proper recording
	// for the case of Neuralynx the last piece of the path is the folder ID
	
	pathinfo session_path
	string experimentdate = parsefilepath(0,S_path,":",1,0) 
 
	noteKWV (recordheaders, "Cheetah_recID", experimentdate, 0)
	noteKWV (header, "Cheetah_recID", experimentdate,0)
	noteKWV ($channelname, "Cheetah_recID", experimentdate, 0)

	// move header to headers directory (create it if it doesn't exist)
	if (!datafolderexists("root:headers_records"))
		newdatafolder root:headers_records
	endif
	movewave recordheaders $("root:headers_records:"+channelname)

	// move header to headers directory (create it if it doesn't exist)
	if (!datafolderexists("root:headers_file"))
		newdatafolder root:headers_file
	endif
	movewave header $("root:headers_file:"+channelname)

	// move header to headers directory (create it if it doesn't exist)
	if (!datafolderexists("root:data_records"))
		newdatafolder root:data_records
	endif
	movewave $channelname $("root:data_records:"+channelname)

	return channelName			// Zero signifies no error.	
End

Function/S LoadNeuralynxBinarySEFile(pathName, fileName) 
	String pathName			// Igor symbolic path name or "" for dialog.
	String fileName				// file name, partial path and file name, or full path or "" for dialog.
	
	Variable err
	
	string nameOfWaveLoaded = ""

	// This puts up a dialog if the pathName and fileName do not specify a file.
	String message = "Select a Neuralynx .nse file"
	Variable refNum
	Open/R/Z=2/P=$pathName/M=message/T=".nse" refNum as fileName
	
	// Save outputs from Open in a safe place.
	err = V_Flag
	String fullPath = S_fileName

	if (err != 0)
		return "User cancelled" //err			// -1 means user canceled.
	endif
	
	Printf "Loading Neuralynx binary NSE data from \"%s\"\r", fullPath
	
	FStatus refNum

	Variable headerSize = 16384			// Size of header in version 1.25 and later files
		
	Variable numDataBytes =  V_logEOF - headersize
	
	if (numDataBytes == 0)
		printf "no data!\r"
		return "0"	
	endif

		
	LoadNeuralynxHeader(refNum, 46)
	WAVE/T header

	Variable recordsize = str2num (ReplaceString("-RecordSize",header[8], "")) 
	Variable numDataRecords = trunc(numDataBytes / recordsize )
		
	// need to parse out subsample, timestamp, channelNumber, scalefactor, subsample
	String channelname = replacestring("\r",replacestring("-AcqEntName ",header[6], ""),"")
	
	Variable ADBitVolts =  str2num (ReplaceString("-ADBitVolts",header[14], "")) 
	Variable datapointsperRecord = 	str2num (ReplaceString("-WaveformLength",header[31], "")) 
	
	//FSetpos refNum, 16432
	FSetpos refNum, 16384
	fstatus refnum
	LoadNeuralynxSEData(refNum, channelName, numDatarecords, DatapointsperRecord)				
	//FSetpos refNum, 16384

	// add 2*24 bytes to header position
	//FSetpos refNum, 16432

	FSetpos refNum, 16384

	// Load everything into a temporary wave.
	//Make/O/N=(1000)/W, tempNeuralynxData
	// this works!!
	//fstatus refnum
	//FBinRead/B=3 refNum, tempNeuralynxData					// Read all of the data.

	//Wave loadedwave = $channelName												// Create reference to wave created by LoadNeuralynxData.
       //print "channelName: "+channelName
       
       //WAVE recordheaders
       
	//Redimension/S loadedwave		// Change to floating point so we can represent data in volts.
	//loadedwave *= ADBitVolts 		// Scale into volts.
	//print ADBitVolts

	//nameOfWaveLoaded = channelName
	
	//SetScale/P x, timestamp*1000, (1/samplingFrequency)*1000, "ms", loadedwave  // cw changed to ms (from s) 10/30/08
	//SetScale d, 0, 0, "V", loadedwave													    // Note that the data units are volts
	
	//Print timestamp, samplingFrequency

	Close refNum

	// three waves have been created: file header, record headers, and record data
	// create folders for these if they don't exist
		
	// move header to headers directory (create it if it doesn't exist)
//	if (!datafolderexists("root:headers_records"))
//		newdatafolder root:headers_records
//	endif
//	movewave recordheaders $("root:headers_records:"+channelname)
//
//	// move header to headers directory (create it if it doesn't exist)
//	if (!datafolderexists("root:headers_file"))
//		newdatafolder root:headers_file
//	endif
//	movewave header $("root:headers_file:"+channelname)
//
//	// move header to headers directory (create it if it doesn't exist)
//	if (!datafolderexists("root:data_records"))
//		newdatafolder root:data_records
//	endif
//	movewave $channelname $("root:data_records:"+channelname)
//
//	return channelName			// Zero signifies no error.	
End

/// this just loads 1 wave
Function DoLoadNeuralynxBinaryCSFile()
	String nameOfWaveLoaded
	nameOfWaveLoaded = "freshLoad"
	
	LoadNeuralynxBinaryCSFile("", "")
End



// function to detect thresholds in the style of WaveCalc, but more transparently
// enter everything in ms
//from cristin via gene, in genehist.ipf
//modified to inculde chunks option by dan 7/22/2008

Function detectthreshDAN(trace, epochstart, epochend, lower, deadtime, chunks)
	Wave trace
	Variable epochstart, epochend, lower, deadtime, chunks
	
	Variable length = numpnts(trace), i
	
	// pointnumber * scalefactor = ms	
	Variable scalefactor = DimDelta(trace,0)
		
	// (ms / scalefactor) = pointnumber
	epochstart /= scalefactor
	epochend /= scalefactor
	
	if (epochend == 0)
		epochend = numpnts(trace)-1
	endif 
	
	string timestampsName = nameOfwave(trace)+"_tStamps"
	KillWaves/Z $timestampsName
	
	for(i=0; i<chunks; i+=1)
	epochend =length/chunks + epochend*i //figure out the length of the chunk
	String newname = nameOfwave(trace) + "_sint"+num2str(i)
	Make/O/N=10 $newname
	WAVE sint = $newname
	
	Variable nextspot = 10
	
	FindLevels/edge=1/D=$newname/M=(deadtime)/R=[epochstart,epochend] trace, lower  //find threshold crossings
	
	
	concatenate/KILL {sint}, $timestampsName //add the timestamps from this chunk to the timestamps from previous chunks
	epochstart = epochend+1
	endfor
	
	
//	String infoName = nameOfwave(trace) + "_sint_info"
//	Make/O/N=6 $infoName
//	WAVE sint_info = $infoName
//	sint_info[0] = scalefactor
//	sint_info[1] = epochstart
//	sint_info[2] = epochend
//	sint_info[3] = lower
//	sint_info[8] = deadtime
//	sint_info[9] = V_LevelsFound
	
	wave tStamps = $timestampsName
	//tStamps *=1E6
end






//no goodXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
function danCreateStimSet(responseWave, timestampWave)
wave timestampWave, responseWave
variable i

string responseWaveName = nameofwave(responseWave)
NewDataFolder/S $responseWaveName

for(i=0;i<numpnts(timestampWave); i+=1)
string responseName = responseWaveName+"_"+num2str(i)
Duplicate/O/R=(timestampWave[i], timestampWave[i]+ deltaX(responseWave)*10000) responseWave, $responseName
endfor 

setdatafolder root:
end

// for each experiment in each folder in DirListWave
// load all channels matching matchstring
// save out pxp with subdir extension
Function PreprocessExperiments (DirListWave, matchstring, destinationsubdir)
	WAVE/T DirListWave
	String matchstring,destinationsubdir
	
	variable numdates = numpnts(DirListWave), i
	
	// need the global path to the neuralynx data
	NewPath/O neuralynx, "Macintosh HD:Users:nipadmin:Desktop:RAW DATA:neuralynx:"
	PathInfo neuralynx
	string neuralynxfilepath = S_path
	string newfilepath,nextpathname
	
	// each directory is a path
	for (i=0; i < numdates; i += 1)

		newfilepath = neuralynxfilepath+ DirListWave[i]
		
		//make a path to it
		nextpathname = ("p"+ replacestring("-",DirListWave[i],""))
		newpath $nextpathname, newfilepath

		// pass the path to multidirload
		multidirload(nextpathname, matchstring, channelmapwave, destinationsubdir)
		
		// don't leave all these paths lying around
		killpath $nextpathname
	
	endfor
	
end

// load directories within experiment
Function MultiDirLoad (inputpathname, matchstring, channelmapwave, destinationsubdir)
	String inputpathname, matchstring, destinationsubdir
	WAVE channelmapwave

	// how many folders are in here?
	string dirlist = (IndexedDir(inputpathName, -1, 0))
	
	variable numdirs = itemsinlist(dirlist),i
	string nextdir, nextdirpath

	for (i =0; i < numdirs; i += 1)
	
		// return full path
		nextdirpath = indexeddir(inputpathname, i,1)
		newpath/o nextpath, nextdirpath
				
		//loadNCSdirandsavepxp("nextpath", matchstring, channelmapwave, destinationsubdir)
		killpath nextpath

	endfor

end

// given a time in ms,
// turn it into a 64-bit binary number
// then break that into 4 binary chunks
// convert each of those into a signed 16-bit integer
// return a wave reference to the 4 point wave containing this
Function/wave convertNSEtimestamp (time_ms, CSC_recordheaders)
	Variable time_ms
	WAVE CSC_recordheaders
	
	// convert to us
	variable time_us = time_ms*1000,i
	
	// right here, use CSC_recordheaders to compute timestamp offset in us and add it to our number
	variable timestampoffset_us = gettimestampfromsignedints(CSC_recordheaders,0)
	
	// 21 Oct 2016: WHY is the above line happening??  what is the point of this?
	//	I know why this is here.  It's from when I used to artificially set every recording to start at 0.  threshold crossings obtained from that wave
	//	would be zero-based.  In order to index them back into "neuralynx time" for reverse engineering the nse file, they needed to be added to the timestamp offset present in the record headers
	//	ugh.  this means all SEdata computed before 21 Oct and not fixed have the wrong offsets.  ugh ugh. but this is not too bad bc only my test files have these.


	// *****
	// time_us += timestampoffset_us
	// removed this oct 2016 see above
	
	make/o/w/n=4 foursigned16ints = 0
	
	// convert to binary string
	string time_us_binary
	sprintf time_us_binary,"%b",time_us
	 
	 variable numbinarydigits = strlen(time_us_binary)
	 // pad it out to 64 digits
	 if (numbinarydigits < 64)
	 
		do
			time_us_binary = "0" + time_us_binary
		while (strlen(time_us_binary) < 64)
	
	endif
	
	// now I have 64 digits
	//printf "%s\r", time_us_binary
	
	// leftmost - most significant
	String first = time_us_binary[0,15]
	String second = time_us_binary[16,31]
	String third = time_us_binary[32,47]
	String fourth = time_us_binary[48,63]
	// rightmost - least significant
	
	//printf "%s\r%s\r %s\r%s\r", first, second,third, fourth
	
	
	// fourth should be interpreted as -10549
	// third should be interpreted as 3634
	// second should be interpreted as 1
	// first should be interpreted as 0
	
	foursigned16ints[0] = binary2int(fourth,1)
	foursigned16ints[1] = binary2int(third,1)
	foursigned16ints[2] = binary2int(second,1)
	foursigned16ints[3] = binary2int(first,1)
	
	return foursigned16ints

end

Function gettimestampfromsignedints(CSC_recordheaders, index)
	WAVE CSC_recordheaders
	Variable index
	
	string bigbinary = ""
	string nextbinary
	variable i, nextsignedint, numbinarydigits
	
	for (i=0; i < 4; i += 1)
		nextsignedint = CSC_recordheaders[i][index]
		// convert to binary
		
		sprintf nextbinary, "%b", abs(nextsignedint)
		
		numbinarydigits = strlen(nextbinary)

		// pad it out to 16 digits
	 	if (numbinarydigits < 16)
			do
				nextbinary = "0" + nextbinary
			while (strlen(nextbinary) < 16)		
		endif 
		
		if (nextsignedint < 0)
			nextbinary = twoscomplement(nextbinary)
		endif
		
		bigbinary = nextbinary + bigbinary	
	
	endfor
	
	variable result = binary2int(bigbinary,0)
	return result
end

//
Function getALLtimestampfromsignedints(CSC_recordheaders, prefix)
	WAVE CSC_recordheaders
	string prefix
	
	string bigbinary = ""
	string nextbinary
	variable i, nextsignedint, numbinarydigits,j
	
	variable numrecords = DimSize(CSC_recordheaders, 1)
	make/o/D/n=(numrecords) $(prefix+"_timestamps") = 0
	WAVE timestamps = $(prefix+"_timestamps")
	
	for (j=0; j < numrecords; j += 1)
		bigbinary = ""
		for (i=0; i < 4; i += 1)
			nextsignedint = CSC_recordheaders[i][j]
			// convert to binary
			
			sprintf nextbinary, "%b", abs(nextsignedint)
			
			numbinarydigits = strlen(nextbinary)	

			// pad it out to 16 digits
	 		if (numbinarydigits < 16)
				do
					nextbinary = "0" + nextbinary
				while (strlen(nextbinary) < 16)		
			endif 
			
			if (nextsignedint < 0)
				nextbinary = twoscomplement(nextbinary)
			endif
		
			bigbinary = nextbinary + bigbinary	
	
		endfor
		
		variable result = binary2int(bigbinary,0)
		
		timestamps[j] = result
		//doupdate
		//printf "%.f\r", result
		
		if (!mod(j,1000))
			//print j
		endif
		
	endfor
		
end


Function getONEtimestampfromsignedints(recordheadersmatrix,whichone)
	WAVE recordheadersmatrix
	variable whichone
	
	string bigbinary = ""
	string nextbinary
	variable i, nextsignedint, numbinarydigits
	
	for (i=0; i < 4; i += 1)
		nextsignedint = recordheadersmatrix[i][whichone]
		// convert to binary
		
		sprintf nextbinary, "%b", abs(nextsignedint)
		
		numbinarydigits = strlen(nextbinary)

		// pad it out to 16 digits
	 	if (numbinarydigits < 16)
			do
				nextbinary = "0" + nextbinary
			while (strlen(nextbinary) < 16)		
		endif 
		
		if (nextsignedint < 0)
			nextbinary = twoscomplement(nextbinary)
		endif
		
		bigbinary = nextbinary + bigbinary	
	
	endfor
	
	variable result = binary2int(bigbinary,0)
	return result
	
end