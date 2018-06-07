#pragma rtGlobals=1		// Use modern global access method.

// NeuroMAVEN 0.6 master include file

// requires useful utilites (uu) package
#include "::uu:uuinclude"

#include ":initialize"
#include ":writeNSE-v2"
#include ":loadNeuralynx-v5"
#include ":loadNeuralynx-v6"
#include ":NIPpanelprocs"
#include ":superfreeq-v1"
#include ":NIPutils-v2"
#include ":NIPprocs-v3"
#include ":SEdata_procs"
#include ":batchfixbig"
#include ":cheetahEvents"
#include ":coherencepolish"
#include ":processindatabase3"
#include ":aggregatefromdatabase"



Menu "Macros"
	"Make Spike Event File"
end


Menu "NeuroMAVEN"
	"Initialize neuroMAVEN environment"
	"Show NM Paths Panel/2"
end