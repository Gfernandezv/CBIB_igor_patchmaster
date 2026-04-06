#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//====================================================
//   MANJEO DE DATOS
//====================================================

Function expFitRsCm(w, x) : FitFunc
    Wave w
    Variable x
    return w[0] * exp(-x / w[1]) + w[2]
End

Function start_panels()
	Execute "LogConsole()"
	Execute "Main_panel()"
end

Function prefix_detector()

// ------------------------------------------------------------
// Function: prefix_detector
// Purpose : Solicita y registra el prefijo de ondas a procesar.
// Inputs  : Prefijo ingresado por el usuario.
// Output  : Guarda `Wave_prefix` en la carpeta Packages y
//           desencadena la organización inicial del experimento.
// Notes   : Depende de la estructura de carpetas activa.
// ------------------------------------------------------------

	string prefix
	Prompt prefix, "🪪 Escribe el prefijo de las ondas a procesar:"
	DoPrompt "Wave selector", prefix
	if (V_Flag)
		Print "❌ Operación cancelated by user."
		return 0
	endif

	// Verificar si hay ondas con el prefijo
	String list = WaveList((prefix + "*"), ";", "")
	if (ItemsInList(list) < 1)
		Abort "⚠️ No se encontraron ondas que comiencen con: " + prefix
	endif
	
	// guardar el prefijo en la carpeta correspondiente
	string packages_path = (getdataFolder(1))+"Packages"
	NewDataFolder/O $(packages_path)
	String/G $(packages_path+":"+"Wave_prefix") = prefix  // Global si necesitas reutilizarlo
	
	sorting_hat(prefix)   

End

Function tempresponse(basal_i,peak_f,temp,chanexp)

// ------------------------------------------------------------
// Function: tempresponse
// Purpose : Analiza respuestas a rampas térmicas, calcula amplitudes
//           corregidas por drift y estima propiedades pasivas.
// Inputs  : basal_i, peak_f, temp, chanexp
// Output  : Waves `<chanexp>_fitpeak_<temp>` y `<chanexp>_pasives_<temp>`
//           en la carpeta Analysis.
// Notes   : Requiere `Wave_prefix` definido previamente. Utiliza
//           ventanas y constantes actualmente ajustadas al protocolo.
// ------------------------------------------------------------

    Variable basal_i,peak_f,temp
    string chanexp
    Variable i
    String list, wave_Name, canalStr, unidadY
	 

    variable t_ini=basal_i, t_fin=0//basal_f
    	LogInfo("ajuste basal entre tiempos = " + num2str(t_ini) + " s y " + num2str(t_fin) + " s")
		LogInfo("buscando peak entre tiempos = " + num2str(peak_f-0.005) + " s y " + num2str(peak_f) + " s")
	
	string current_folder = getdataFolder(1)
		Svar/Z traces_prefix =  $(ParentFolder(getdatafolder(1), 2)+"Packages:Wave_prefix")
		
	string traces_folder = (current_folder+"Trace")
	string analysis_folder = (current_folder+"Analysis")

		NewDataFolder/O $(analysis_folder)
		
	Variable analisis_status = nvar_storer("analisis_status", 1, current_folder)
			
	setdataFolder(traces_folder)
	
		
	list = wavelist((traces_prefix+"*"),";","")
	variable n=itemsInList(list)
	string stemp=num2str(temp)
	Variable cm, tau, rs
	Variable center, left, right
	
    // Crear onda de promedio basal
    
	 Make/O/N=(n,3) $(analysis_folder+":"+chanexp+"_fitpeak_"+stemp) = NaN // 0 para ajuste inicial, 1 para ajuste al rededor de 0 y 2 para sin ajuste
    Wave Netpeak = $(analysis_folder+":"+chanexp+"_fitpeak_"+stemp)
	 Make/O/D/N=(n,3) $(analysis_folder+":"+chanexp+"_pasives_"+stemp)
    Wave pasives = $(analysis_folder+":"+chanexp+"_pasives_"+stemp)
    
    // Obtener la unidad del eje Y desde la primera onda
    WAVE w0 = $StringFromList(0, list)
    make/N=(numpnts(w0))/O fit
    unidadY = WaveUnits(w0, 1)
    SetScale y, 0, 1, unidadY, Netpeak

    for (i = 0; i < n; i += 1)

        WAVE w = $(StringFromList(i, list))
        string drift_name = (StringFromList(i, list)+"_drift")
        duplicate/O w, $drift_name
        wave drift_w = $drift_name
    // -------------------------------------------------
    // DRIFT sustraction:
    // Calcula el drift como el promedio de los primeros 10ms y lo corrige
    // -------------------------------------------------
    		variable drift= mean(w, 0.001, 0.011)
    		drift_w -= drift
    		
    // -------------------------------------------------
    // Modo ajuste lineal al primer segmento de rampa:
    // Netpeak=0
    // -------------------------------------------------

		   Duplicate/O/FREE drift_w, fit
			CurveFit/Q/X=1 line w(t_ini+0.002,t_ini+0.042)
			wave W_coef

			fit = W_coef[0]+W_coef[1]*x

			fit = w - fit
		  	Netpeak[i][0] = mean(fit,(peak_f-0.003), (peak_f-0.001)) // promedio de los ultimos 3 ms en onda ajustada
		
		// -------------------------------------------------
    // Modo ajuste lineal al al segmento cercano a 0mv:
    // Netpeak=1
    // -------------------------------------------------        
    //En desarrollo

        
    // -------------------------------------------------
    // Modo sin ajuste lineal:
    // Netpeak=2
    // ------------------------------------------------- 

        Netpeak[i][2] = mean(drift_w, (peak_f-0.003), (peak_f-0.001))

//para debugg
//print nameofWave(drift_w)+" "+num2str(t_ini+0.002)+" "+num2str(t_ini+0.042)+" "+num2str(peak_f-0.003)+" "+num2str(peak_f-0.001)+" "+num2str(mean(fit,(peak_f-0.003), (peak_f-0.001)))+" "+num2str(mean(w, (peak_f-0.003), (peak_f-0.001)))
      
        
        [cm, tau, rs] = pasivas(drift_w, 100, (peak_f+0.0006), (peak_f+0.025)) //entre 0.6 y 25ms luego del pulso
        pasives[i][0] = cm                              // Cm (pF)
		  pasives[i][1] = tau                             // Tau (ms)
		  pasives[i][2] = rs                              // Rs (MΩ)
        
		  SetDimLabel 1, 0, pF, pasives
		  SetDimLabel 1, 1, ms, pasives
		  SetDimLabel 1, 2, MOhm, pasives   
	  killwaves drift_w	       
    endfor

// Analisis de la onda de peaks, posible punto para evaluacion de pasivos.    

FindPeak/Q Netpeak
	if (V_flag != 0)
		LogInfo("⛔ No se encontraron peaks")
	else
		LogInfo(" Peak encontrado de: "+num2str(V_PeakVal)+"en la onda :"+num2str(V_PeakLoc))
	endif
		
killwaves/z fit, W_coef, W_sigma
setdataFolder current_folder
End


//====================================================
//   IV PROCEDURES
//====================================================

Function/S GetListOfFolders()
    String list
    list = DataFolderDir(1)   // Devuelve: "FOLDERS:Chan1,Chan2,Chan3;"
    list = removeListItem(0, list, ":") // Quitar "FOLDERS:"
    list = ReplaceString(",", list, ";")   // Cambiar comas por punto y coma
    return list
End

Function AnalizarIVporCanal() 
// ------------------------------------------------------------
// Function: AnalizarIVporCanal
// Purpose : Extrae corriente, voltaje y parámetros pasivos desde un
//           protocolo IV basado en pulsos cuadrados.
// Inputs  : Usa el prefijo almacenado y la estructura actual del experimento.
// Output  : Wave `IV_Results` en la carpeta Analysis.
// Notes   : Contiene tiempos e índices hardcodeados para el protocolo actual.
// ------------------------------------------------------------

    Variable cm, tau, rs
    
    String currentDF = GetDataFolder(1)	
    	string Swaves_prefix = (ParentFolder(getdatafolder(1), 2)+"Packages:Wave_prefix")
		svar_check(Swaves_prefix)
		Svar/Z traces_prefix = $Swaves_prefix
		
   string traces_folder = (currentDF+"Trace")
   string stim_folder = (currentDF+"Stim")
	string analysis_folder = (currentDF+"Analysis")

	
	setdataFolder(traces_folder)
   String Traces_list = wavelist((traces_prefix+"*"),";","")	

	setdataFolder(stim_folder)
	String Stim_list = wavelist((traces_prefix+"*"+"Amp"),";","")	
	variable n=itemsInList(Traces_list)
	
	NewDataFolder/O/S $(analysis_folder)
	
	Make/O/N=(n,5) $(analysis_folder + ":IV_Results") = NaN 
   Wave IV_res = $(analysis_folder + ":IV_Results")
   
   variable i
   setdataFolder(analysis_folder)
   
   for (i = 0; i < n; i += 1)
   	
   	WAVE i_trace = $(traces_folder + ":" + StringFromList(i, Traces_list))	
   	WAVE i_amp = $(stim_folder + ":" + StringFromList(i, Stim_list))	
   	
   	String drift_name = (traces_folder + ":" + StringFromList(i, Traces_list)+"_drift")
			duplicate/O i_trace, $drift_name		
      	wave drift_w = $drift_name   	//K
      	
   	variable drift= mean(i_trace, 0.001, 0.011)
    	drift_w -= drift
    	
    	[cm, tau, rs] = pasivas(drift_w, i_amp[4], (0.249+0.003), (0.249+0.006))	//hardcoded para el tipo de estimulo
    	
    						//Wave to work
   	IV_res[i][0] = mean(drift_w,(0.247), (0.249))		// tiempos hardcoded, por ahora
   	IV_res[i][1] = i_amp[4]		// solo sirve para pulsos cuadrados por ahora, por lo que esta hardcoded la amplitud
   	IV_res[i][2] = cm
   	IV_res[i][3] = tau
   	IV_res[i][4] = rs
   	
   	SetDimLabel 1, 0, A, IV_res
		SetDimLabel 1, 1, V, IV_res
		SetDimLabel 1, 2, F, IV_res
		SetDimLabel 1, 3, s, IV_res
		SetDimLabel 1, 4, Ohm, IV_res
		
   	Killwaves/Z drift_w    
    endfor
    
SetDataFolder $currentDF
End


//====================================================
//   PASIVAS
//====================================================

function [Variable Cm_pF, Variable tau_ms, Variable Rs_MOhm] pasivas(wave I, Variable deltaV, Variable tStart, Variable tEnd)
//==============================================================
// Function: pasivas
//--------------------------------------------------------------
// Objetivo:
//   Estimar propiedades pasivas de una célula a partir del 
//   componente capacitivo de una onda de corriente (respuesta
//   a un paso de voltaje).
//
// Entradas:
//   - wave I       : onda de corriente (amperes)
//   - deltaV       : amplitud del salto de voltaje (mV)
//   - tStart       : inicio del segmento a ajustar (s)
//   - tEnd         : fin del segmento a ajustar (s)
//
// Salidas:
//   - Cm_pF        : Capacitancia de membrana (pF)
//   - tau_ms       : Constante de tiempo del ajuste exponencial (ms)
//   - Rs_MOhm      : Resistencia en serie (MΩ)
//
// Método:
//   1. Se recorta la onda entre tStart y tEnd (Itrans)
//   2. Se genera un eje de tiempo en ms (ttrans)
//   3. Se ajusta un modelo exponencial simple:
//        I(t) = A * exp(-t / tau) + offset
//   4. A partir del ajuste se calcula:
//        Rs = ΔV / I0         (I0 en nA)
//        Rtot = ΔV / offset         (offset en nA)
//        Rm = Rtot - Rs         
//        Cm = tau / Rs        (en pF)
//
// Notas:
//   - La corriente debe estar en amperes (verificar escala).
//   - deltaV debe estar en milivoltios.
//   - Asegúrate de tener definida la función expFitRsCm:
//
//        Function expFitRsCm(x, a)
//            return a[0] * exp(-x / a[1]) + a[2]
//        End
//
//==============================================================

	//print nameofWave(I)
	duplicate /O/R=(tStart, tEnd) I, Itrans

	Variable dt = DimDelta(I, 0) * 1000     // ms
	Make/O/N=(numpnts(Itrans)) ttrans
	SetScale/P x, 0, dt, "", ttrans
	ttrans = p * dt
	
	Make/O/N=3 coef_fit_rs
	coef_fit_rs[0] = Itrans[0] - Itrans[numpnts(Itrans)-1]   // A ~ I0 - Iss
	coef_fit_rs[1] = 1                                        // tau ~ 1 ms
	coef_fit_rs[2] = Itrans[numpnts(Itrans)-1]               // offset ~ Iss
	
	FuncFit/Q expFitRsCm coef_fit_rs Itrans /X=ttrans
	
	// Parámetros del fit
	Variable A_A     = coef_fit_rs[0]
	tau_ms           = coef_fit_rs[1]
	Variable Iss_A   = coef_fit_rs[2]                         // Iss = offset
	
	// Corrientes clave
	Variable I0_A    = A_A + Iss_A                            // I0 = A + Iss
	Variable I0_nA   = abs(I0_A  * 1e9)
	Variable Iss_nA  = abs(Iss_A * 1e9)
	
	Variable eps = 1e-9
	Rs_MOhm    = abs(deltaV) / max(I0_nA, eps)       // mV / nA
	Variable Rtot_MOhm  = abs(deltaV) / max(Iss_nA, eps)      // mV / nA
	Variable Rm_MOhm    = max(Rtot_MOhm - Rs_MOhm, 0)
	Variable Rpar_MOhm  = (Rs_MOhm * Rm_MOhm) / max(Rs_MOhm + Rm_MOhm, eps)
	
	Cm_pF = (tau_ms / max(Rpar_MOhm, eps)) * 1000             // τ(ms)/Rpar(MΩ) = nF → pF
	
	killwaves/Z ttrans, Itrans, coef_fit_rs
	return [Cm_pF, tau_ms, Rs_MOhm]   // (opcion: devuelve también Rm_MOhm)

	
end


//====================================================
//   ORGANIZACION DE ONDAS
//====================================================

Function sorting_hat(prefix)
    String prefix
    String sufs = "_Amp;_Dur;*"
    Variable k

    // Primera fase
    for (k=0; k<ItemsInList(sufs); k+=1)
        first_phase(prefix, StringFromList(k, sufs))
    endfor

    // Segunda fase
    for (k=0; k<ItemsInList(sufs); k+=1)
        second_phase(prefix, StringFromList(k, sufs))
    endfor
End


Function first_phase(prefix, sufix)
string prefix, sufix

   Variable i, ind
	String current_folder = GetDataFolder(1), signal_folder, exp_folder
    
   strswitch(sufix)
    case "_Dur":
    case "_Amp":
    		ind = 2
    		break
    case "*":
    		ind = 1
    		break
	endswitch

	String pattern = prefix + "*" + sufix
	String list = WaveList(pattern, ";", "")
	Variable n = ItemsInList(list)
	
	if (n == 0)
		LogError("No se encuentran ondas con prefijo " + sufix)
      return 0
   endif

	String wave_name, valStr, folderName

//=== PRIMERA SEPARACIÓN: POR CANAL ===
	for (i=0; i<n; i+=1)
		wave_name = StringFromList(i, list)
			
// Extraer canal del nombre
		Variable pos = (ItemsInList(wave_name, "_")) - ind
		valStr = StringFromList(pos, wave_name, "_")
		folderName = current_folder + "chan_" + valStr
		
 //Crear carpeta si falta
		if (!DataFolderExists(folderName))
    		NewDataFolder/O $folderName
		endif
	
		MoveWave $wave_name, $(folderName+":")
	endfor


end	

Function second_phase(prefix, sufix)
string prefix, sufix

   Variable i, j, ind
	String current_folder = GetDataFolder(1), signal_folder, exp_folder
		
    //=== SEGUNDA FASE: ya dentro de carpetas por canal ===
    String folderList = DataFolderDir(1)     // lista de subcarpetas
    folderList = StringFromList(1, folderList, ":")  // quitar root info
    folderList = StringFromList(0, folderList, ";")
    Variable nFolders = ItemsInList(folderList, ",")
	 String pattern = prefix + "*" + sufix, wave_name, valStr
	 
   strswitch(sufix)
    case "_Dur":
    case "_Amp":
    		ind = 4
    		signal_folder = "Stim"
    		break
    case "*":
    		ind = 3
    		signal_folder = "Trace"
    		break
	endswitch
		
    for (i = 0; i < nFolders; i += 1)

        String folderNameShort = StringFromList(i, folderList, ",")
        String folderPath = current_folder + folderNameShort + ":"
        SetDataFolder $folderPath

        String traces = WaveList(pattern,";","")
        Variable nTr = ItemsInList(traces)

        for (j=0; j<nTr; j+=1)
            wave_name = StringFromList(j, traces)

            Variable pos2 = ItemsInList(wave_name, "_") - ind
            valStr = StringFromList(pos2, wave_name, "_")

            String exp_target = folderPath + "exp_" + valStr
				//print exp_target, (exp_target + ":"+signal_folder)
				
            if (!DataFolderExists(exp_target))
                NewDataFolder/O $exp_target
            endif

            if (!DataFolderExists(exp_target + ":"+signal_folder))
                NewDataFolder/O $(exp_target + ":"+signal_folder)
            endif

             MoveWave $wave_name, $(exp_target + ":"+signal_folder+":")
        endfor

        SetDataFolder current_folder
    endfor
	
End

//====================================================
//   GRAFICAS
//====================================================

Function IV_graph()

    string current_folder = GetDataFolder(1)        // Carpeta actual
    string res_folder = current_folder + "Analysis" // Se parte desde la carpeta de experimento
    string windows_name = "IV_graph"
    variable to

    // Validar y cargar wave IV_Results
    SetDataFolder res_folder
    string IV_traces = WaveList("*IV_Results*", ";", "")
    
    if (ItemsInList(IV_traces) == 0)
        LogError("No se encuentran ondas IV_Results en: " + res_folder)
        SetDataFolder current_folder
        return 0
    endif
    
    Wave IV_trace = $(res_folder + ":" + StringFromList(0, IV_traces))
    to = DimSize(IV_trace, 0)
    
    if (to == 0)
        LogError("IV_Results está vacía")
        SetDataFolder current_folder
        return 0
    endif

    // Extraer columnas de la wave 2D a waves 1D para graficar
    Make/O/N=(to) $(res_folder + ":IV_voltage"), $(res_folder + ":IV_current")
    Wave xw = $(res_folder + ":IV_voltage")
    Wave yw = $(res_folder + ":IV_current")

    xw[] = IV_trace[p][1]   // columna 1 = amplitud (voltaje)
    yw[] = IV_trace[p][0]   // columna 0 = corriente

    // Crear o traer al frente la ventana
    if (!WinType(windows_name))
        Display/K=1/N=$windows_name/W=(200,200,700,500) as windows_name
        
    else
        DoWindow/F $windows_name
    endif

    AppendToGraph yw vs xw
	 ModifyGraph mode=4,marker=19,lstyle=3
	 
    LogInfo("Se agregan ondas de experimento: " + res_folder)

    SetDataFolder current_folder
    
End


Function plot_stim()
	string current_folder = getdataFolder(1)	//Carpeta actual
	string stim_folder = current_folder + "Stim"		//se parte desde la carpeta de experimento
	string windows_name = "stimu_graph", cmd
	variable i
	SetdataFolder stim_folder
	
	string x_traces = WaveList("*_Dur",";","")
	string y_traces = WaveList("*_Amp",";","")
	
if (!wintype(windows_name))   // no existe
    Display/K=1/N=$windows_name /W=(200,200,700,500) as windows_name
else
    DoWindow/F $windows_name
endif

    Variable n = min(ItemsInList(x_traces), ItemsInList(y_traces))
    
   if (n == 0)
		LogError("No se encuentran ondas de estimulo")
      return 0
   endif
   
    for (i=0; i<n; i+=1)
        Wave xw = $(StringFromList(i, x_traces))
        Wave yw = $(StringFromList(i, y_traces))
        AppendToGraph yw vs xw
    endfor
    
	LogInfo("se agregan ondas de experimento: "+stim_folder)

	setdataFolder current_folder
End

Function plot_trace()
	string current_folder = getdataFolder(1)	//Carpeta actual
	string trace_folder = current_folder + "Trace:"		//se parte desde la carpeta de experimento
	string windows_name = "trace_graph"
	variable i, level = 2
	
	string parent = ParentFolder(current_folder, level)
   SVAR/Z w_prefix = $(parent+"Packages:"+"Wave_prefix")
	//print parent
	SetdataFolder trace_folder

	string y_traces = WaveList((w_prefix+"*"),";","")
	
if (!wintype(windows_name))   // no existe
    Display/K=1/N=$windows_name /W=(200,200,700,500) as windows_name
else
    DoWindow/F $windows_name
endif

    Variable n = (ItemsInList(y_traces))
    
   if (n == 0)
		LogError("No se encuentran ondas de respuesta")
      return 0
   endif

   
    for (i=0; i<n; i+=1)
        Wave yw = $(StringFromList(i, y_traces))
        AppendToGraph yw
    endfor
    
	LogInfo("se grafican ondas de experimento: "+trace_folder)

	setdataFolder current_folder
End

Function plot_amp(mode)
	string mode //raw, norm,smth

//Directorio de carpetas
	string current_folder = getdataFolder(1)					//Carpeta actual
	string trace_folder = current_folder + "Analysis:"		//se parte desde la carpeta analysis	
	string packages_folder = current_folder + "Packages:"	//Almacen de variables
	
	string graph_mode = StrVarOrDefault((packages_folder+"graph_mode"), mode)
	string windows_name = "Norm_graph", title
	variable i, col_index
	Nvar/Z temp = $(packages_folder+"ramp_temp")
	SetdataFolder trace_folder
	
	string y_traces, y_wave_name, wbase_name = ("*_fitpeak_"+num2str(temp))
	
	strswitch (mode)		// el modo no esta incluido en el panel y puede ser activado de forma manual para debug
		case "raw":
		y_traces = WaveList((wbase_name),";","")
		y_wave_name = (StringFromList(0, y_traces))
		title = "Raw graphs"
		break
		
		case "norm":
		y_traces = WaveList((wbase_name+"_norm"),";","")
		y_wave_name = (StringFromList(0, y_traces))
		title = "Norm graphs"
		break
		
		case "smth":
		y_traces = WaveList((wbase_name+"_norm_smth"),";","")
		y_wave_name = (StringFromList(0, y_traces))
		title = "smooth graphs"
		break
	endswitch
	
	Wave w = $y_wave_name	
	MakeTwoPanels_plot_amp(w, title)

//    
//	LogInfo("se grafican ondas norm de experimento: "+trace_folder)

	setdataFolder current_folder
End

Function MakeTwoPanels_plot_amp(w, title)
    Wave w
    string title

    // Extraer columnas
    Duplicate/O/R=[][0] w w_col0
    Duplicate/O/R=[][1] w w_col1
    Duplicate/O/R=[][2] w w_col2

	if (wintype("Fig1"))   // no existe
		killWindow/Z Fig1
	endif
		
    NewPanel /K=1 /W=(50,100,1310,500) as title
    DoWindow/C Fig1
    
	 DrawText 180,30,"Fit mode 0"
	 DrawText 545,30,"Fit mode 1 (under construction)"
	 DrawText 1025,30,"Fit mode 2"
	 
	 
    Display /HOST=Fig1 /N=Amp0 /W=(10,50,410,350) w_col0
    Display /HOST=Fig1 /N=Amp1 /W=(430,50,830,350) w_col1 
    Display /HOST=Fig1 /N=Amp2 /W=(850,50,1250,350) w_col2

	 Cursor/H=2/L=1 A, w_col2,(rightx(w_col2)-leftx(w_col2))*0.1
	 Cursor/H=2/L=1 B, w_col2,(rightx(w_col2)-leftx(w_col2))*0.9
    ShowInfo/W=Fig1
    
	Button store_amp,pos={1139.00,361.00},size={100.00,20.00},title="Store amp",proc=AmpButtonProc
	 
End

Function AmpButtonProc(ctrlName) : ButtonControl
    String ctrlName
				
	variable A_value = vcsr (A)
	variable B_value = vcsr (B)
	findamp (A_value, B_value)
    
End

function findamp(amp_ini, amp_fin)	//on work
	variable amp_ini, amp_fin
	
	string current_folder = getdataFolder(1)
	string analysis_folder = (current_folder+"Analysis")
	string packages = (current_folder+"Packages")
		setdataFolder $packages
		
	Svar/Z chan = chanexp
   Nvar/Z temp = ramp_temp
   amp_ini = nvar_storer("amp_ini", amp_ini, current_folder)
   amp_fin = nvar_storer("amp_fin", amp_fin, current_folder)
   
	Svar/Z traces_prefix =  $(ParentFolder(getdatafolder(1), 3)+"Packages:Wave_prefix")
   String mut_name = FolderNameFromPath(ParentFolder(GetDataFolder(1), 4))
	mut_name = ReplaceString("'", mut_name, "")
   
	setdataFolder(analysis_folder)
	
	string list = wavelist((chan+"_fitpeak_"+num2str(temp)),";","")
	
	data_saver(mut_name, traces_prefix, chan, (amp_fin-amp_ini), 2, temp)		//se guarda en la ultima columna para respetar el orden de los graficos
	
	setdataFolder(current_folder)
end

Function CursorMovedHook(info)		//capturar datos de los cursores
	String info
	
	string cursor_name_str = stringfromList(2,info,";")
	//Print valor
	string csr_name, csr_index
	[csr_name, csr_index] = cursor_info_spliter(cursor_name_str)

End

function [String val_name, String val_value] cursor_info_spliter(string expresion)
	 
	String expr = "([[:alpha:]]+):([[:alpha:]]+)"
		string indicador, valor		
		SplitString/E=(expr) expresion, indicador, valor
	
	return [indicador, valor]
End	


//====================================================
//   MANEJO DE DATOS DE AMPLITUD
//====================================================

Function data_saver(mut_name, traces_prefix, chan, max_amp, col_index, temp)
    String mut_name, traces_prefix, chan
    Variable max_amp, col_index, temp

    Variable nT = 6
    Variable t0 = 20
    Variable dt = 5
    Variable idx = round((temp - t0) / dt)

    // ---------------- VALIDACIONES ----------------
    if (idx < 0 || idx >= nT)
        Print "ERROR idx fuera de rango:", idx, " temp=", temp
        return 0
    endif

    if (col_index < 0 || col_index >= 3)
        Print "ERROR col_index fuera de rango:", col_index
        return 0
    endif
    // ------------------------------------------------

    String maxwave_fullname = "'"+mut_name + "_" + traces_prefix + "_" + chan+"'"
    String maxwave_name = (ParentFolder(GetDataFolder(1), 2)+maxwave_fullname)
	//print maxwave_name, max_amp //debug
	
	if (!WaveExists($maxwave_name))
    	Make/O/N=(nT,3) $maxwave_name
    	Wave maxwave = $maxwave_name
    	maxwave = NaN
    	SetScale/P x t0, dt, "°C", maxwave
	endif
	Wave maxwave = $maxwave_name
	maxwave[idx][col_index] = max_amp
    LogInfo ("GUARDADO OK:"+NameOfWave(maxwave)+\
    			" idx:"		+num2str(idx)+\
    			" col:"		+num2str(col_index)+\
    			" value:"		+num2str(max_amp))
    
	if (!wintype("Tabla_max"))   // no existe
    	Edit/K=1 /N=$("Tabla_max") maxwave.id 
	endif 


End


// Q10 --> en desarrollo

Function Include_generator(folder, genotype)
	String folder, genotype
	
	string list = wavelist((genotype+"*"),";","")
	variable i
	
	Make/T/O/N=(itemsInList(list),2) Include
	
	for (i = 0; i < itemsInList(list); i += 1)
		Include[i][0] = stringfromList(i, list)
		Include[i][1] = "0"
	endfor
		
End

Function Q10_calculator(TempC, Include, col_index)
    Wave TempC                     // 1D temperaturas
    Wave/T Include                 // Include[][0]: nombres
    variable col_index                               // Include[][1]: número 0/1
        

    Variable nCells = DimSize(Include, 0)   // nº de filas en Include
    Variable nT = DimSize(TempC, 0)         // nº de temperaturas
    Variable nPairs = nT - 1                // nº de intervalos de T

    Variable i, p, Ti, Tj, Ai, Aj, Q10

    // Wave de salida: filas = intervalos T_i → T_j, columnas = células
    Make/O/N=(nCells, nPairs) Q10_cells
    Q10_cells = NaN

    for (i = 0; i < nCells; i += 1)

        // leer flag de inclusión
        Variable useCell = str2num(Include[i][1])
        if (useCell != 0)
            Print "Saltando célula:", Include[i][0], "por motivo:", useCell
            continue
        endif

        // nombre de la wave con los datos
        String wName = Include[i][0]

        // referencia real a la wave
        Wave w = $wName

        Print "Procesando:", wName

        // calcular Q10 para cada intervalo de temperatura
        for (p = 0; p < nPairs; p += 1)
            Ti = TempC[p]
            Tj = TempC[p+1]
            Ai = w[p][col_index]
            Aj = w[p+1][col_index]

            if (Ai > 0 && Aj > 0)
                Q10 = (Aj/Ai)^(10/(Tj - Ti))
                Q10_cells[i][p] = Q10
            else
                Q10_cells[i][p] = NaN
            endif
        endfor

    endfor

End

Function Arrhenius_calculator(TempC, Include, col_index)
    Wave TempC
    Wave/T Include                  // Include[][0] name ; Include[][1] reason code (0=in)
	 Variable col_index
	 
    Variable nCells = DimSize(Include, 0)
    Variable nT     = DimSize(TempC, 0)

    Make/O/N=(nT) Tk, invTk
    Tk    = TempC + 273.15
    invTk = 1 / Tk

    Make/O/N=(nCells) Ea_kJmol, R2_cells, slope_b, intercept_a
    Ea_kJmol = NaN
    R2_cells = NaN
    slope_b  = NaN
    intercept_a = NaN

    Make/O/N=(nT) lnA, fitWave
    Make/O/N=2 coeff

    Variable i, j
    Variable R = 8.314

    for (i = 0; i < nCells; i += 1)

        Variable reason = str2num(Include[i][1])
        String wName = Include[i][0]

        if (reason != 0)
            Print "Saltando célula: ", wName, " por motivo: ", reason
            continue
        endif

        Wave w = $wName

        // Construir lnA, marcando inválidos como NaN
        for (j = 0; j < nT; j += 1)
            if (numtype(w[j]) == 0 && w[j] > 0)
                lnA[j] = ln(w[j][col_index])
            else
                lnA[j] = NaN
            endif
        endfor

        // Contar puntos válidos
        Variable nValid = 0
        for (j = 0; j < nT; j += 1)
            if (numtype(lnA[j]) == 0)
                nValid += 1
            endif
        endfor

        if (nValid < 3)
            Print "Arrhenius: ", wName, " insuficientes puntos válidos (", nValid, ")"
            continue
        endif
        
        string out_wname= "ln_"+wName
        Make/O/N=(nT) $out_wname = lnA
         

        // Fit lineal (CurveFit ignora NaNs)
        CurveFit/Q line, lnA[2,4] /X=invTk[2,4] /D=fitWave //C=coeff alt: 1 y 3
		  wave W_coef
        intercept_a[i] = W_coef[0]
        slope_b[i]     = W_coef[1]
        
        

        // Calcular R² correctamente SOLO con puntos válidos
        Variable ymean = 0
        for (j = 0; j < nT; j += 1)
            if (numtype(lnA[j]) == 0)
                ymean += lnA[j]
            endif
        endfor
        ymean /= nValid

        Variable SS_tot = 0
        Variable SS_res = 0
        for (j = 0; j < nT; j += 1)
            if (numtype(lnA[j]) == 0 && numtype(fitWave[j]) == 0)
                SS_tot += (lnA[j] - ymean)^2
                SS_res += (lnA[j] - fitWave[j])^2
            endif
        endfor

        if (SS_tot > 0)
            R2_cells[i] = 1 - SS_res/SS_tot
        else
            R2_cells[i] = NaN
        endif

        Print "Arrhenius: ", wName, " Ea(kJ/mol)=", Ea_kJmol[i], " R2=", R2_cells[i]

    endfor
    KILLWaves/Z lnA
End

