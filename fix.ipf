#pragma rtGlobals=3		// Use modern global access method and strict wave access.


function fix (session, session_fixed)
	WAVE/T session, session_fixed

	variable length = numpnts(session_fixed),i
	
	string year,month,day,hour,minute,second, nextsessionstring
	
	for (i=0; i < length; i += 1)
		nextsessionstring = session[i]
		
		year = nextsessionstring[0,3]
		month = nextsessionstring[4,5]
		day = nextsessionstring[6,7]
		
		hour = nextsessionstring[9,10]
		minute = nextsessionstring[11,12]
		second = nextsessionstring[13,14]
	
	
		session_fixed[i] = (year+"-"+month+"-"+day+"_"+hour+"-"+minute+"-"+second)


	endfor
	
end


Function populatepowerband ()

	WAVE/T session_fixed,preparation,channel
	WAVE powerband0
	variable length = numpnts(session_fixed)

	string nextdatafolder
	variable i
	
	setdatafolder root:

	for (i=0; i < length; i += 1)
		nextdatafolder = ("root:"+preparation[i]+":"+ possiblyQuoteName(session_fixed[i]))
		setdatafolder $nextdatafolder
		
		WAVE nextPSD = $(channel[i]+"_psd")
		
		powerband0[i] = sum(nextPSD, 500,1000)

		WAVE nextPSD = $""
	endfor
	
	setdatafolder root:
	
end


Function populatepowerratio ()

	WAVE/T session_fixed,preparation,channel
	WAVE powerratio
	variable length = numpnts(session_fixed)

	string nextdatafolder
	variable i
	
	setdatafolder root:

	for (i=0; i < length; i += 1)
		nextdatafolder = ("root:"+preparation[i]+":"+ possiblyQuoteName(session_fixed[i]))
		setdatafolder $nextdatafolder
		
		WAVE nextPSD = $(channel[i]+"_psd")
		
		powerratio[i] =  sum(nextPSD, 500,1000)/sum(nextPSD,4000,5000)

		WAVE nextPSD = $""
	endfor
	
	setdatafolder root:
	
end

// assumes waves are already sorted
Function orderedgraph ()

	WAVE/T session_fixed,preparation,channel
	WAVE powerband0
	variable length = numpnts(session_fixed)

	string nextdatafolder
	variable i
	
	display

	for (i=0; i < length; i += 1)

		nextdatafolder = ("root:"+preparation[i]+":"+ possiblyQuoteName(session_fixed[i]))
		setdatafolder $nextdatafolder
				
		WAVE nextsnip = $(channel[i]+"_snip")
		if (WaveExists(nextsnip))
			appendtograph nextsnip
		endif

	endfor
	
	setdatafolder root:sorted_powerratio
end
