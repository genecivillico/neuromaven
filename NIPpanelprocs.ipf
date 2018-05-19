#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function ShowNMPathsPanel() : Panel
	
	dowindow/f NMpathspanel
	dowindow/k NMpathspanel

	NewPanel /W=(751,602,1622,718) as "NeuroMAVEN Paths"
	SetDrawLayer UserBack
	SetDrawEnv fillfgc= (53951,44866,43360)
	DrawRect 11,8,862,106
	SetDrawEnv fsize= 16
	DrawText 270,36,"and edit to complete path (entering a drive here will override drive selection at left)"
	SetDrawEnv fsize= 16
	DrawText 102,36,"select drive"
	SetVariable Neuralynx_setvar,pos={268.00,43.00},size={450.00,20.00},bodyWidth=450,proc=UpdateDataPathStrs_SetVariable,title=" "
	SetVariable Neuralynx_setvar,font="Tahoma",fSize=14
	SetVariable Neuralynx_setvar,value= root:neuromaven_resources:pathstrings:Neuralynx_basepathstring,styledText= 1
	PopupMenu Neuralynx_popup,pos={21.00,43.00},size={234.00,23.00},bodyWidth=150,proc=UpdateDataPathStrsPopupmenu,title="\\Z18Neuralynx"
	PopupMenu Neuralynx_popup,mode=2,popvalue="NIPEPHYS II",value= #"root:neuromaven_resources:pathstrings:NMdrives_list"
	PopupMenu database_popup,pos={27.00,76.00},size={228.00,23.00},bodyWidth=150,proc=UpdateDataPathStrsPopupmenu,title="\\Z18database"
	PopupMenu database_popup,fSize=24
	PopupMenu database_popup,mode=3,popvalue="Macintosh HD",value= #"root:neuromaven_resources:pathstrings:NMdrives_list"
	SetVariable database_setvar,pos={268.00,76.00},size={450.00,20.00},bodyWidth=450,proc=UpdateDataPathStrs_SetVariable,title=" "
	SetVariable database_setvar,font="Tahoma",fSize=14
	SetVariable database_setvar,value= root:neuromaven_resources:pathstrings:database_basepathstring,styledText= 1
	Dowindow/C NMpathspanel
	
EndMacro

Function BuildNIPPathsPanel_old() : Panel
	
	dowindow/f NIPpathspanel
	dowindow/k NIPpathspanel

	NewPanel /W=(826,458,1744,835) as "NIPpanel"
	SetDrawLayer UserBack
	SetDrawEnv fillfgc= (53951,44866,43360)
	DrawRect 1,3,912,372
	SetDrawEnv fsize= 16
	DrawText 403,32,"manual entry overrides stems at left"
	SetDrawEnv fsize= 16
	DrawText 138,32,"path stems"
	SetVariable Neuralynx_setvar,pos={401,39},size={450,20},bodyWidth=450,proc=updatepaths,title=" "
	SetVariable Neuralynx_setvar,font="Tahoma",fSize=14
	SetVariable Neuralynx_setvar,value= Neuralynx_basepathstring,styledText= 1
	SetVariable HIpasspxp_setvar,pos={401,76},size={450,20},bodyWidth=450,proc=updatepaths,title=" "
	SetVariable HIpasspxp_setvar,font="Tahoma",fSize=14
	SetVariable HIpasspxp_setvar,value= HIpasspxp_basepathstring,styledText= 1
	SetVariable HIpassuxp_setvar,pos={401,112},size={450,20},bodyWidth=450,proc=updatepaths,title=" "
	SetVariable HIpassuxp_setvar,font="Tahoma",fSize=14
	SetVariable HIpassuxp_setvar,value= HIpassuxp_basepathstring,styledText= 1
	SetVariable SEdata_setvar,pos={401,151},size={450,20},bodyWidth=450,proc=updatepaths,title=" "
	SetVariable SEdata_setvar,font="Tahoma",fSize=14
	SetVariable SEdata_setvar,value= SEdata_basepathstring,styledText= 1
	SetVariable nse_setvar,pos={401,185},size={450,20},bodyWidth=450,proc=updatepaths,title=" "
	SetVariable nse_setvar,font="Tahoma",fSize=14
	SetVariable nse_setvar,value= nse_basepathstring,styledText= 1
	PopupMenu Neuralynx_popup,pos={50,38},size={338,24},bodyWidth=250,proc=UpdateDataPathStrsPopupmenu,title="\\Z18Neuralynx"
	PopupMenu Neuralynx_popup,mode=3,popvalue="Macintosh HD:Users:gene:Desktop",value= #"root:NIPdrives_list"
	PopupMenu HIpasspxp_popup,pos={48,73},size={340,24},bodyWidth=250,proc=UpdateDataPathStrsPopupmenu,title="\\Z18HIpasspxp"
	PopupMenu HIpasspxp_popup,fSize=24
	PopupMenu HIpasspxp_popup,mode=3,popvalue="Macintosh HD:Users:gene:Desktop",value= #"root:NIPdrives_list"
	PopupMenu SEdata_popup,pos={80,149},size={308,22},bodyWidth=250,proc=UpdateDataPathStrsPopupmenu,title="\\Z18SEdata"
	PopupMenu SEdata_popup,font="Tahoma",fSize=18
	PopupMenu SEdata_popup,mode=3,popvalue="Macintosh HD:Users:gene:Desktop",value= #"root:NIPdrives_list"
	PopupMenu HIpassuxp_popup,pos={48,110},size={340,24},bodyWidth=250,proc=UpdateDataPathStrsPopupmenu,title="\\Z18HIpassuxp"
	PopupMenu HIpassuxp_popup,mode=3,popvalue="Macintosh HD:Users:gene:Desktop",value= #"root:NIPdrives_list"
	PopupMenu nse_popup,pos={105,183},size={283,24},bodyWidth=250,proc=UpdateDataPathStrsPopupmenu,title="\\Z18nse"
	PopupMenu nse_popup,mode=3,popvalue="Macintosh HD:Users:gene:Desktop",value= #"root:NIPdrives_list"
	PopupMenu database_popup,pos={56,238},size={332,24},bodyWidth=250,proc=UpdateDataPathStrsPopupmenu,title="\\Z18database"
	PopupMenu database_popup,fSize=24
	PopupMenu database_popup,mode=3,popvalue="Macintosh HD:Users:gene:Desktop",value= #"root:NIPdrives_list"
	SetVariable HIpasspxp_setvar1,pos={401,241},size={450,20},bodyWidth=450,proc=updatepaths,title=" "
	SetVariable HIpasspxp_setvar1,font="Tahoma",fSize=14
	SetVariable HIpasspxp_setvar1,value= database_basepathstring,styledText= 1
	
	Dowindow/C NIPpathspanel
EndMacro



Function UpdateDataPathStrsPopupmenu (ctrlName,popNum,popStr) : PopupmenuControl
	String ctrlName
	Variable popNum	// which item is currently selected (1-based)
	String popStr		// contents of current popup item as string

	// the control name tells me which variable to update
	string stringtoupdate = replacestring("_popup",ctrlName, "_basepathstring")
		
	SVAR pathstring = $("root:neuromaven_resources:pathstrings:"+stringtoupdate)

	// get drive string
	string drivestring = popStr
	
	string extrafolderlevelstring
	if (stringmatch(ctrlname, "*Neuralynx*"))
		extrafolderlevelstring = "RAW DATA:"
	else
		extrafolderlevelstring = "PREPROCESSED DATA:"
	endif
	
	pathstring = drivestring + ":" + extrafolderlevelstring + replacestring("_popup", CtrlName, "") + ":"
	
end



Function UpdateDataPathStrs_SetVariable(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName		// name of variable
	
	// the control name tells me which variable to update
	string stringtoupdate = replacestring("_setvar",ctrlName, "_basepathstring")

	SVAR pathstring = $("root:neuromaven_resources:pathstrings:"+stringtoupdate)
	pathstring = varStr

	string drivename = stringfromlist(0,varStr,":")
	// add drivename to list if it wasn't there already
	
	SVAR drivelist = root:neuromaven_resources:pathstrings:NMdrives_list
	if (findlistitem(drivename,drivelist) == -1)
		drivelist = addlistitem(drivename, drivelist)
		PopupMenu Neuralynx_popup mode=1
	endif

end

Function updatepaths(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum	// value of variable as number
	String varStr		// value of variable as string
	String varName		// name of variable
	
	String/G $ctrlname
	printf "yada yada\r"
	printf  "%s\r", ctrlname

end

