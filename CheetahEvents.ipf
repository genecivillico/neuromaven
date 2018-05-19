#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Function PlotCheetahTimestampsAsRaster (timestampswave_us)
	WAVE timestampswave_us
	
	string timestamps_ms_name = nameofwave(timestampswave_us)+"_ms"
	if (!waveexists($timestamps_ms_name))
		duplicate timestampswave_us $timestamps_ms_name/WAVE=timestampswave_ms
		timestampswave_ms /= 1000
	else
		WAVE timestampswave_ms = $timestamps_ms_name
	endif
	
	string rastermarkername = nameofwave(timestampswave_us)+"_marks"
	if (!waveexists($rastermarkername))
		make/B/n=(numpnts(timestampswave_us)) $rastermarkername /WAVE=rastermarker
		rastermarker = 1
	else
		WAVE rastermarker = $rastermarkername
	endif
	
	appendtograph/r rastermarker vs timestampswave_ms 
	
	// how many traces on graph?
	variable numtraces = itemsinlist(tracenamelist("",";",1))
	
	modifygraph mode[numtraces-1]=3,marker[numtraces-1]=10,msize[numtraces-1]=10, mrkThick[numtraces-1]=1,rgb[numtraces-1]=(0,0,65535)
	SetAxis right 0,10

end



// written by David Xing summer 2013 FDA
function LoadNeuralynxNEVfile(pathName, fileName)
//open and load in neuralynx event data stored in .nev files. Creates 2 wave for each port,
//one for timestamp and and one for the TTL value. Also saves waves eventid,extras,
//alltimestamps (which contains the timestamps for all events), and eventstrings.
//If a port doesn't have any events, waves for that port won't be created
String pathName
String fileName

if (strlen(pathName) == 0)
		NewPath/O NeuralynxDataPath		// This displays a dialog in which you can select a folder
		if (V_flag != 0)
			return V_flag								// -1 means user canceled
		endif
		pathName = "NeuralynxDataPath"
endif
	
//Open the file
Variable refNum
Open/R/P=$pathName/T=".Nev" refNum as fileName

//files start with a 16384 byte header
Variable headerSize = 16384
variable filepos=headerSize
variable eventnum=0 //keep track of which event we're at

//initiate waves
make/O/D/N=0 alltimestamps
make/O/W/N=0 eventid
make/O/I/N=(0, 8) extras
make/O/T=128/N=0 eventstrings

variable port
variable buffer
string stringbuffer
variable templow
variable temphigh
variable tempTTLvalue

FStatus refNum

do
//read the file

	if (filepos>=V_logEOF) //reached the end of the file
		break
	endif
	
	//add a new point at the end for our waves
	insertpoints/M=0 eventnum, 1, alltimestamps, eventid, extras, eventstrings
	
	//first 6 bytes of an event is packet data that we don't want
	filepos += 6
	FSetPos refNum, filepos
	
	//read timestamp value. Igor can't read 64bit integers, so read 32 bits at a time
	FBinRead/F=3/U/b=3 refNum, templow
	FBinRead/F=3/U/b=3 refNum, temphigh
	buffer = templow + 2^32*temphigh
	//buffer /= 1E6
	alltimestamps[eventnum]=buffer
	filepos += 8
	
	//read eventid data (int16)
	FBinRead/F=2 refNum, buffer
	eventid[eventnum]=buffer
	filepos += 2
	
	//read TTL value (int16)
	FBinRead/F=2/U refNum, buffer
	tempTTLvalue=buffer
	filepos += 2
	
	//next 6 bytes are CRC and dummy data, which we don't need
	filepos += 6
	FSetPos refNum, filepos
	
	//read in extra data (next 8 int32 values, save each value in its own column)
	variable whichextra
	for(whichextra=0; whichextra <  8; whichextra += 1)
		FBinRead/F=3 refNum, buffer
		extras [eventnum] [whichextra] = buffer
	endfor
	filepos += 32
	
	//read eventstring data (128 characters)
	FReadLine/N=128 refNum, stringbuffer
	eventstrings[eventnum]=stringbuffer
	filepos += 128
	
	//Now add the TTLvalue and timestamp to the port waves
	if (strsearch(stringbuffer,"port",33) != -1) //if it's an event from a port
		port=str2num(stringbuffer[39]) //the eventstring should tell us what port it is
		addeventstoportwave(alltimestamps[eventnum],tempTTLvalue,port)
	endif
	
	eventnum += 1
	
while (1)

end

// written by David Xing summer 2013 FDA
Function addeventstoportwave(timestamp,value,port)
//function to add timestamp and TTL value to the specified port wave
	variable timestamp
	variable value
	variable port
	string timestampwavename
	string valuewavename
	
	//get the wave name
	timestampwavename="port" + num2str(port) + "timestamp"
	valuewavename="port" + num2str(port) + "value"
	variable len
	
	//make waves if they don't exist yet, if they do, insert a new point at the end
	if (!waveexists($timestampwavename))
		make/O/D/N=1 $timestampwavename
		make/O/W/U/N=1 $valuewavename
		len = 0
	else
		wavestats/Q $timestampwavename
		len=V_npnts
		insertpoints len, 1, $timestampwavename
		insertpoints len, 1, $valuewavename
	endif
	
	wave timestampwave=$timestampwavename
	wave valuewave=$valuewavename
	
	//add the timestamp and value to the waves
	timestampwave [len]=timestamp
	valuewave [len]=value
end
	