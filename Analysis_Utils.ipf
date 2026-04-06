#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <Waves Average>

//====================================================
//   LOGGER
//====================================================

Function InitLogger()
    // Crea carpeta y wave solo si no existen
    DFREF dfr = root:logging
    
    if (DataFolderRefStatus(dfr) == 0)
    	  print "folder test"
        NewDataFolder/O root:logging
    endif

    // Asegurar wave de texto root:logging:messages
    Wave/T/Z w = root:logging:messages
    if (!WaveExists(w))
        Make/O/T/N=0 root:logging:messages
    endif
End

Function LogMessage(msg, level)
    String msg, level

    InitLogger()
    Wave/T w = root:logging:messages

    InsertPoints numpnts(w), 1, w
    w[numpnts(w)-1] = date() + " " + time() + "\t[" + level + "] " + msg
End

Function LogInfo(msg)
    String msg
    LogMessage(msg, "INFO")
End

Function LogWarn(msg)
    String msg
    LogMessage(msg, "WARN")
End

Function LogError(msg)
    String msg
    LogMessage(msg, "ERROR")
End


//====================================================
//   PANEL DE CONSOLA
//====================================================

Window LogConsole() : Panel
    PauseUpdate; Silent 1

    InitLogger()

    NewPanel/K=1 /W=(1845,1000,2545,1420) as "Log console"
	 
    ListBox logList,pos={10,10},size={530,300}
    ListBox logList,listWave=root:logging:messages
    ListBox logList,mode=1,selRow=-1

    Button btnSave,pos={10,320},size={90,22},title="Save log",proc=LogButtonProc
    Button btnClear,pos={110,320},size={90,22},title="Clear",proc=LogButtonProc
    Button btnClose,pos={210,320},size={90,22},title="Close",proc=LogButtonProc
End

Window Main_panel() : Panel
    // Cierra un panel viejo con el mismo nombre, si existe
    DoWindow/K TabPanel

    // Crea panel
    NewPanel/K=0/N=TabPanel/W=(753,68,1031,393) as "Nanion Analysis"

    // --- TabControl ---
    TabControl tb,pos={15,15},size={250,250},proc=TabProc
    TabControl tb,tabLabel(0)="Organize"
    TabControl tb,tabLabel(1)="Ramp",value=0
    TabControl tb,tabLabel(2)="IV",value=0

    // --- Controles pestaña 0 ("Settings") ---
	 Button btnorder,pos={24.00,45.00},size={100.00,20.00},proc=LogButtonProc,title="Organize data", disable = 0


    // --- Controles pestaña 1 ("More Settings") ---
    Button btnStim,pos={24.00,45.00},size={100.00,20.00},proc=LogButtonProc,title="Plot Stim", disable = 1
	 Button btnRamp,pos={24.00,75.00},size={100.00,20.00},proc=LogButtonProc,title="Ramp Analysis", disable = 1
	 Button btnplotamp,pos={24.00,105.00},size={100.00,20.00},proc=LogButtonProc,title="Amp Analysis", disable = 1

	// --- Controles pestaña 2 ("More Settings") ---
	Button btnIV,pos={24.00,45.00},size={100.00,20.00},proc=LogButtonProc,title="IV Analisis", disable = 1
	Button btnIVgraph,pos={24.00,75.00},size={100.00,20.00},proc=LogButtonProc,title="IV graph", disable = 1
End

Function TabProc(tca) : TabControl
    STRUCT WMTabControlAction &tca
	Variable tabNum = 0
	
    switch (tca.eventCode)
        case 2: // Mouse up: el usuario hizo click en una pestaña
            tabNum = tca.tab   // número de pestaña activa (0, 1, ...)

            Variable isTab0 = (tabNum == 0)
            Variable isTab1 = (tabNum == 1)
            Variable isTab2 = (tabNum == 2)

            // Controles que viven en la pestaña 0: "Settings"
            ModifyControl btnorder disable = !isTab0    // Hide if not Tab 0


            // Controles que viven en la pestaña 1: "More Settings"
            ModifyControl btnStim disable = !isTab1    // Hide if not Tab 1
            ModifyControl btnRamp disable = !isTab1    // Hide if not Tab 1
            ModifyControl btnplotamp disable = !isTab1    // Hide if not Tab 1
            
            ModifyControl btnIV disable = !isTab2    // Hide if not Tab 2
            ModifyControl btnIVgraph disable = !isTab2
            break
    endswitch

    return 0
End
	
EndMacro

Function LogButtonProc(ctrlName) : ButtonControl
    String ctrlName

    strswitch(ctrlName)

        case "btnSave":
            PathInfo home
            String fname = "igor_log_"+ReplaceString(":", time(), "-") + ".txt"
            Save/T root:logging:messages as (S_path + fname)
            Print "Log guardado en: ", S_path+fname
            break

        case "btnClear":
            Redimension/N=0 root:logging:messages
            Print "Log limpiado."
            break

        case "btnClose":
            DoWindow/K LogConsole
            break
            
        case "btnorder":
        		prefix_detector()
        		break
        
       case "btnStim":
        		plot_stim()
        		break
        		
       case "btnRamp":
       		menu_tempresponse()
       		break
       		
       case "btnplotamp":
       		plot_amp("raw")
       		break
       		
       case "btnIV":
       		AnalizarIVporCanal()
       		break
       		
       case "btnIVgraph":		
       		IV_graph()
       		break

    endswitch

    return 0
End

// actua como retrieve y set de variables globales, para retrieve var_value = 0
Function nvar_storer(var_name, var_value, folder) 
    string var_name
    variable var_value
    string folder
    
    string packages_path = folder+"Packages"
    NewDataFolder/O $(folder+"Packages")
    string path_tovar= (packages_path+":"+var_name)
    
    if (var_value == 0)  	
    	Variable nVal = NumVarOrDefault(path_tovar,0)
    		if (nVal == 0)
    			Prompt nVal, (var_name +" no declarada, ingresa el valor:")
    			DoPrompt "Error de variable", nVal
    		else
    			//print "valor: "+num2str(nVal)
    		endif
    else
     Variable/G $(path_tovar) = var_value
     nVal = var_value
    endif
    
    return nVal
End

Function/S svar_storer(var_name, var_value, folder)
    String var_name, var_value, folder

    string path_tovar = folder+"Packages:"+var_name
    NewDataFolder/O $(folder+"Packages")

    SVAR/Z old = $(path_tovar)
    String oldVal

    if (SVAR_Exists(old))
        oldVal = old
    else
        oldVal = "Null"
    endif

    String/G $(path_tovar) = var_value
	 oldVal = var_value
	 
    return oldVal
End

Function/S ParentFolder(path, level)
    String path
    variable level //busca dependiendo en que nivel de subcarpeta te encuentres
    String noEnd = RemoveEnding(path, ":")  // quita ":" final

    Variable n = ItemsInList(noEnd, ":")
    if (n <= 1)
        // estamos en root: o algo similar
        return "root:"
    endif

    String out = ""
    Variable i
    // tomamos todos menos el level-esimo
    for (i = 0; i < n-level; i += 1)
        out += StringFromList(i, noEnd, ":") + ":"
    endfor

    return out
End

Function/S FolderNameFromPath(path)
    String path
    String p = RemoveEnding(path, ":")
    Variable n = ItemsInList(p, ":")
    return StringFromList(n-1, p, ":")
End

Function svar_check(ask)
string ask
Svar asking = $ask
if (!Svar_Exists(asking))
    Print "ERROR: Wave_prefix no encontrado"
    return 0
endif
End