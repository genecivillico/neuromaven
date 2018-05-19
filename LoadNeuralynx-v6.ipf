#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// new path system



	
// load directories within experiment
// current data folder should contain the metadata waves
// outputmode 0: pxp, 1:uxp, 2: justwaves
// stage1extended: 0: some computations on raw data skipped; 1:extra raw computations included
Function MultiNCSLoadPreprocessSave_new (startindex, stopindex, mousefolder, experimentnames, channelmatchstring, filter, deletionswave, toptobottom_channellist, outputmode, stage1extended)
	WAVE/T  experimentnames, channelmatchstring, filter, deletionswave, toptobottom_channellist
	String mousefolder
	Variable startindex, stopindex, outputmode, stage1extended
	
	SVAR Neuralynx_basepathstring = root:Neuralynx_basepathstring
	SVAR HIpassuxp_basepathstring = root:HIpassuxp_basepathstring
	SVAR HIpasspxp_basepathstring = root:HIpasspxp_basepathstring
	SVAR database_basepathstring = root:database_basepathstring

	// deleted all path creation stuff from here because the base paths never get used
		
	// where are we
	string homefolder = getdatafolder(1)
		
	// main loop is over inputwaves
	variable numtoprocess = numpnts(experimentnames),i
	
	string nextinput_pathstring, nextoutput_pathstring
	
	// before we do anything, CHECK to make sure all these experiments exist
	if (!alldirectoriesexist(startindex, stopindex, Neuralynx_basepathstring, mousefolder, experimentnames))
		abort
	endif	

	// for each experiment to load
	for (i=startindex; i <= stopindex; i += 1)
		
		// build input path string out of raw neuralynx path + date directory
		nextinput_pathstring = Neuralynx_basepathstring + mousefolder + ":" + experimentnames[i]
		
		// build output path string too
		if (outputmode == 0)
			nextoutput_pathstring = HIpasspxp_basepathstring + mousefolder
		elseif (outputmode == 1)
			nextoutput_pathstring = HIpassuxp_basepathstring + mousefolder
		elseif (outputmode == 2)
			nextoutput_pathstring = database_basepathstring + mousefolder
		endif
				
		// make wave references for wave arguments to next function
		// /Z because there won't always be a deletions wave
		WAVE/Z deletions = $(deletionswave[i])
		WAVE toptobottomchannels = $("root:"+toptobottom_channellist[i])

		// for packed or unpacked, use older function		
		if (outputmode < 2)	
			//loadNCSdirandsavepxp(nextpathstring, HIpassuxp_pathstring, channelmatchstring[i], filter[i], pxpsuffix, destinationsubdir,deletionswave=deletions, toptobottomwave=toptobottomchannels)
			loadNCSdirandsave(nextinput_pathstring, nextoutput_pathstring, channelmatchstring[i], filter[i], outputmode,deletionswave=deletions, toptobottomwave=toptobottomchannels)
		else
			printf "outputmode is 2; saving out loose waves with new function\r"
			loadNCSdirandsaveoutwaves(nextinput_pathstring,nextoutput_pathstring,channelmatchstring[i],filter[i],stage1extended, deletionswave=deletions, toptobottomwave=toptobottomchannels)
		endif

	endfor

end

// load all ncs files in a directory and save out a uxp
// also do various preprocessing
// computing average OK, but do not rereference!  store as integers

// inputpathname: name of an igor symbolic path to a disk location, created with Misc > New Path or NewPath command.  use "" to prompt dialog
// channelmatchstring: load channels matching this, e.g. "*CSC*"
// filter: "" for no filtering, "HI" to bandpass filter 300-10000, "LO" to bandpassfilter 0.1-30
// deletionswave: list of intervals to delete before preprocessing data.  just use dummy if not using this - WAVE/Z will prevent error
// toptobottomwave: channel numbers arranged top to bottom (for correcting channel order)
// pxpsuffix: string to add to the end of experiment date to create result filename
// preprocesssubdir: last part of path to save result
Function LoadNCSDirAndSave (inputpathstring, outputpathstring, channelmatchstring,filter, packed, [,deletionswave,toptobottomwave])
	String inputpathstring, outputpathstring, channelmatchstring,filter
	Variable packed
	WAVE/Z deletionswave
	WAVE toptobottomwave
	
	Variable err

	// where are we
	string homefolder = getdatafolder(1)
	string referencename,refstatus
	
	// change to root
	setdatafolder root:

	// load everything desired from this folder
	loadNL_GC2(inputpathstring,channelmatchstring,maxpointstoload=30000000)
	// loadNL_GC(inputpathstring,channelmatchstring,maxpointstoload=28947967)
	// loadNL_GC(inputpathstring,channelmatchstring,maxpointstoload=21926868)
	// loadNL_GC(inputpathstring,channelmatchstring)
	
	RTErrorCheck("checkpoint1")

	// just so I have the experiment name in case I want it
	string experimentdate = parsefilepath(0,inputpathstring,":",1,0) 
	
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
		printf "filtering requested on %s\r", experimentdate
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
	
	// data waves are still integers; AVG is an FP64
	
	RTErrorCheck("checkpoint3")
	
	// kill AVGm and SDs if they exist (they are vestigial from older code)
	killwaves/z AVGm, SDs	
	
	refstatus = CARmaker_simple (channelprefix, 0.5, 1.5)
	// at this point we now have SDs_raw (FP32) and CAR (FP64)
	
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

	// datafolders will become file system folders if we save to uxp, so file everything properly here.
	// create folder for PSDs and move them there
	newdatafolder PSDs_grand
	movematching ("*_psd*", ":PSDs_grand:")
	
	// create folder for SDs and move them there
	newdatafolder SDs
	movematching ("SDs_*", ":SDs:")

	string experimentname
	NewPath/C/O outputpath, outputpathstring

	if (packed)
		experimentname = experimentdate +".pxp"
		SaveExperiment/C/P=outputpath as experimentname
	else
		experimentname = experimentdate +".uxp"
		SaveExperiment/C/P=outputpath/F={0,"",1}  as experimentname
	endif
	
	setdatafolder root:
	// clear everything
	killdatafolder/z headers_records
	killdatafolder/z headers_file
	killdatafolder/z data_records
	killdatafolder/z PSDs_grand
	killdatafolder/z SDs

end

// load all ncs files in a directory and save out waves into file system
// starting new version of this because most preprocessing should now be done separately (except for taking the average which can be done here since everything's already in memory
// this is just the converter

// inputpathstring: file system path as a string (can reference global strings)
// channelmatchstring: load channels matching this, e.g. "*CSC*"
// filter: "" for no filtering, "HI" to bandpass filter 300-10000, "LO" to bandpassfilter 0.1-30
// deletionswave: list of intervals to delete before preprocessing data.  just use dummy if not using this - WAVE/Z will prevent error
// toptobottomwave: channel numbers arranged top to bottom (for correcting channel order)
// stage1extended: 0: some computations on raw data skipped; 1:extra raw computations included
Function LoadNCSDirAndSaveOutWaves(inputpathstring, outputpathstring, channelmatchstring,filter, stage1extended, [,deletionswave,toptobottomwave])
	String inputpathstring, outputpathstring, channelmatchstring,filter
	WAVE/Z deletionswave
	WAVE toptobottomwave
	variable stage1extended
	
	Variable err

	// where are we
	string homefolder = getdatafolder(1)
	string referencename,refstatus
	
	// change to root
	setdatafolder root:

	// just so I have the experiment name in case I want it
	string experimentdate = parsefilepath(0,inputpathstring,":",1,0) 

	// load everything desired from this folder
	loadNL_GC2(inputpathstring,channelmatchstring,maxpointstoload=30000000)
	// loadNL_GC(inputpathstring,channelmatchstring,maxpointstoload=28947967)
	// loadNL_GC(inputpathstring,channelmatchstring,maxpointstoload=21926868)
	// loadNL_GC(inputpathstring,channelmatchstring)
	
	RTErrorCheck("checkpoint1")

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
		printf "filtering requested on %s\r", experimentdate
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
	
	// data waves are still integers; AVG is an FP32
	
	RTErrorCheck("checkpoint3")
	
	// do batch SDs
	WAVE SDs = $(SDs_batch(channelprefix, "RAW_noblank"))
	
	// doing new references - keeping this here for now
	refstatus = CARmaker_simple (channelprefix,0.5, 1.5)
	// at this point we now have SDs_raw (FP32) and CAR (FP32)
		
	if (!stringmatch(refstatus, "same"))
		referencename = refstatus
	else
		printf "error!! raw data somehow already has a reference note\r\r\r\r"
	endif
	
	// as long as we've got all waves in memory, do batch processing of anything we'll want done for raw files
	
	// if extended stage 1
	if (stage1extended)
		WAVE SDs_RAW_3SD = $(blankedSDs_batch (channelprefix, "RAW_3SDblank_3ms", 3, 3))
		WAVE SDs_RAW_4SD = $(blankedSDs_batch (channelprefix, "RAW_4SDblank_3ms", 4, 3))
	
		// if extended stage 1, compute batch PSDs - keeping this here for now
		makeallPSDs(channelprefix,16,"_psd",12000, 95,10*32000,"Welch", 0)
	endif
	
	// compute batch running powers
	makeallrunningpower(channelprefix, 16, "_runningpower", 1, 0.2, 0.1, 10000,  12000, "Welch", 0)
	
	if (stage1extended)
		// make spike event data structure
		// spikethreshold = 2, means keep everything 2 SD above mean
		print channelprefix
		MakeSEData_all_v3 (buildlist(channelprefix,1,16), 3, "RAW")
		// this creates a folder called e.g. SEdata_RAW_3SD_ALL
	
		// apply the spike template sort
		// "_sort1" paramaters: saturation level:30000, saturationtolerance:0, baselinewindow_pct:25, maxspikewidth_pts:20
		filter_SEdata_inplace ("RAW_3SD_s00","RAW_3SD_s01", 30000, 0,25,20)
		// this creates a folder called e.g. SEdata_RAW_3SD_s01
	endif
	
	RTErrorCheck("checkpoint4")
	
	setdatafolder root:data_records
	
	// datafolders will become file system folders if we save to uxp, so file everything properly here.
	
	// argh need to make sure waves are named with just channel name.  no prefixes.
	// that means create them in data folders or rename them after moving to data folders argh.
	
	// create folder for runningpowers and move them there
	newdatafolder runningpower_RAW
	movematching ("*_runningpower", ":runningpower_RAW:")
	cleanupchannelnames ("runningpower_RAW","HI_NIP")
	
	// SE data is already in folders but need to remember to move it to output

	string experimentname
	NewPath/C/O outputpath, outputpathstring
	
	// not saving experiment, saving data!

	// create folders for things whose functions don't make folders, and move them there
	newdatafolder SDs
	movematching ("SDs_*", ":SDs:")

	if (stage1extended)
		// create folder for PSDs and move them there
		newdatafolder PSD_grand_RAW
		movematching ("*_psd*", ":PSD_grand_RAW:")
		cleanupchannelnames ("PSD_grand_RAW", "HI_NIP")
	endif

	// create output data folder
	setdatafolder root:
	newdatafolder output

	movedatafolder headers_file, :output:
	movedatafolder headers_records, :output:
	movedatafolder data_records, :output:
	
	setdatafolder output

	movedatafolder :data_records:runningpower_RAW, :
	movedatafolder :data_records:SDs, :

	if (stage1extended)
		movedatafolder :SEdata_RAW_3SD_s00, :
		movedatafolder :SEdata_RAW_3SD_s01, :
		movedatafolder :data_records:PSD_grand_RAW, :
	endif
	
	savedata/O/D=1/L=3/P=outputpath/R experimentdate

	setdatafolder root:
	// clear everything
	killdatafolder/z output

end
