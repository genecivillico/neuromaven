#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Function batchrecompute (directorylistwave, rerefPSD, whichanalysis, analysisparameter)
	WAVE/T directorylistwave
	string whichanalysis
	variable analysisparameter,rerefPSD

	variable numdirs = numpnts(directorylistwave),i
	string nextdir, preprocess
	preprocess = "HIpass"
	setdatafolder root:
	
	for (i=0; i < numdirs; i += 1)

		nextdir = directorylistwave[i]
		setdatafolder $("root:"+nextdir)
		WAVE filelist = $(nextdir+"recordings_AG1")
		WAVE updatelist = $(nextdir+"updatelist")
		
		strswitch (whichanalysis)
			case "exclude":

				ComputeOnPSDs (filelist, nextdir, preprocess, updatelist, "HI_NIP1;HI_NIP2;HI_NIP3;HI_NIP4;HI_NIP5;HI_NIP6;HI_NIP7;HI_NIP8;HI_NIP9;HI_NIP10;HI_NIP11;HI_NIP12;HI_NIP13;HI_NIP14;HI_NIP15;HI_NIP16;", rerefPSD, whichanalysis, analysisparameter)

			break
		endswitch


	endfor
	
	setdatafolder root:

end