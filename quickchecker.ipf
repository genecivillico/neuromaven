#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Function quickchecker(SDs, RMSlowfactor, RMShighfactor)
	WAVE SDs
	Variable RMSlowfactor, RMShighfactor

	// compute the average SD
	imagetransform sumallcols SDs
	WAVE W_sumcols
	Variable averageRMS = W_sumcols[0]/16
	Variable RMSlowcut = averageRMS*RMSlowfactor
	Variable RMShighcut = averageRMS*RMShighfactor
	
	WAVE CARyesno
	// check for pre-existing CARyesno
	if (WaveExists(CARyesno))
		duplicate CARyesno CARyesno_prev
	endif
	
	duplicate/o SDs CARyesno
	CARyesno[][0] = ((SDs[p][0] > RMSlowcut) && (SDs[p][0] < RMShighcut)) ? 1 : 0
	imagetransform sumallcols CARyesno
	
	variable excludes = dimsize(CARyesno,0) - W_sumcols[0]
	
	killwaves W_sumcols
	return excludes
	
end