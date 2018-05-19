#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1		// Use modern global access method


// this function sets up a new blank environment
Function InitializeNeuroMAVENenvironment ()

	setdatafolder root:
	newdatafolder/o/S neuromaven_resources
	
	// set up suffixes, inputtype, outputtype ***************************************
	
	make/n=5/t/o SEsuffixes = {"SEheadfile","SEheadrec","SEdatarec","segpeak1","segVpp"}
	make/n=9/o outputtype = {1,1,3,3,0,0,2,0,0}	
	make/n=9/o inputtype = {0,0,0,1,0,0,1,0,0}
	
	setdimlabel 0,0, runningpower, outputtype,inputtype
	setdimlabel 0,1, PSD_grand, outputtype,inputtype
	setdimlabel 0,2, SEdata, outputtype,inputtype
	setdimlabel 0,3, coherencematrix, outputtype,inputtype
	setdimlabel 0,4, SD, outputtype,inputtype
	setdimlabel 0,5, AER, outputtype,inputtype
	setdimlabel 0,6, SDsubject, outputtype,inputtype
	setdimlabel 0,7, Vpp, outputtype,inputtype
	setdimlabel 0,8, power, outputtype,inputtype

	// set up pathstrings ***************************************

	newdatafolder/o/S pathstrings
	String/G NMdrives_list = "C;Macintosh HD;Untitled;"
	String/G database_basepathstring = "Macintosh HD:Users:Santiago:Desktop:analysis:database:"
	String/G Neuralynx_basepathstring = "Macintosh HD:Users:Santiago:Desktop:RAW DATA:Neuralynx:"
	
	// set up channelmaps ***************************************
	setdatafolder root:neuromaven_resources
	newdatafolder/o/S channelmaps

	make/O/I/n=16 CM16mapFINAL_CSCorder = p+1
	make/O/I/n=16 CM16_filters_AG1_CSCorder = {9,8,10,7,13,4,12,5,15,2,16,1,14,3,11,6}
	make/O/I/n=16 TDT16_ZC16_filters_v4 = 16-p
	make/O/I/n=16 TDT16_OMN_FINAL2 = p+1

	make/O/I/n=16 CM16_ZC16_initial = {10,8,12,6,9,7,16,2,11,5,14,4,13,3,15,1}
	make/O/I/n=16 CM16_ZC16_filters_FINAL = {1,2,3,4,5,6,-1,8,9,10,11,12,13,14,15,16}
	make/O/I/n=16 CM16_ZC16_filters_v4 = {10,8,12,6,9,7,16,2,11,5,14,4,13,3,15,1}

	make/O/I/n=16 CM16_map_CSCorder = {1,2,3,4,9,10,7,8,13,14,15,16,11,12,5,6}
	make/O/I/n=16 CM16_map_v2_CSCorder = {1,2,3,4,9,10,7,8,13,14,15,16,11,12,5,6}

	make/O/I/n=8 FMA_OMN = p+1
	make/O/I/n=16 BLACKROCK_OMN = p+1
	
	setdatafolder root:
	
end