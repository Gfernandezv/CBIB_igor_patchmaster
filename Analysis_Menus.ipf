#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Analysis"
	submenu "Nanion"
   	"Panel", start_panels()
	End
end

Function menu_tempresponse()
	
	// INICIO Valores por defecto del menu, cambiar en caso de ser necesario
	// 03-12-25: se pasa la carpeta al storer, para almacenar el historial de variables en cada carpeta
	string chan = getdataFolder(1)
	Variable basal_i = nvar_storer("ramp_basal_i", 0, chan)
	//Variable basal_f = nvar_storer("ramp_basal_f", 0, chan)
	Variable peak_f = nvar_storer("ramp_peak_f", 0, chan)
	Variable temp = nvar_storer("ramp_temp", 0, chan)
	 
	//Variable delta_basal = 0.04 //cantidad de tiempo para el ajuste lineal   
   // FIN
   
   
   variable numFolders = ItemsInList(chan, ":")
   string chanexp=stringFromList((numFolders-2),chan,":") 

	Prompt chanexp, "Canal:"
	Prompt basal_i, "Inicio rampa:"
	Prompt peak_f, "Peak:"
	Prompt temp, "Temperatura:"
	DoPrompt "Completa los datos", basal_i, peak_f, temp, chanexp
	//basal_f = peak_f //basal_i + delta_basal
	
	if (V_Flag)
		Print "❌ Cancelado por el usuario."
		return -1
	endif
	
//	if (basal_f <= basal_i)
//		Abort "⛔ El tiempo final del pulso debe ser mayor que el inicial."
//	endif

	nvar_storer("ramp_basal_i", basal_i, chan)
	//nvar_storer("ramp_basal_f", basal_f, chan)
	nvar_storer("ramp_peak_f", peak_f, chan)
	nvar_storer("ramp_temp", temp, chan)
	svar_storer("chanexp", chanexp, chan)
	
	LogInfo("✅ Parámetros aceptados. Analizando temperatura: "+num2str(temp)+"°C")

	tempresponse(basal_i,peak_f,temp,chanexp) //se elimina basal _f
End

Function menu_leaksustraction()
	
	// INICIO Valores por defecto del menu, cambiar en caso de ser necesario
	// 03-12-25: se pasa la carpeta al storer, para almacenar el historial de variables en cada carpeta
	string chan = getdataFolder(1)
	Variable ramp_i = nvar_storer("ramp_basal_i", 0, chan)
	Variable ramp_f = nvar_storer("ramp_peak_f", 0, chan)
	Variable v_ini = nvar_storer("V_Ramp_ini", 0, chan)
	Variable v_fin = nvar_storer("V_Ramp_fin", 0, chan) 

	Prompt ramp_i, "Inicio rampa:"
	Prompt ramp_f, "Fin rampa:"
	Prompt v_ini, "Potencial inicio rampa:"
	Prompt v_fin, "Potencial fin rampa:"
	
	DoPrompt "Completa los datos", ramp_i, ramp_f, v_ini, v_fin
	
	if (V_Flag)
		Print "❌ Cancelado por el usuario."
		return -1
	endif
	
//	if (basal_f <= basal_i)
//		Abort "⛔ El tiempo final del pulso debe ser mayor que el inicial."
//	endif

	nvar_storer("ramp_basal_i", ramp_i, chan)
	nvar_storer("ramp_peak_f", ramp_f, chan)
	nvar_storer("V_Ramp_ini", v_ini, chan)
	nvar_storer("V_Ramp_fin", v_fin, chan)
	
	LogInfo("✅ Parámetros aceptados. Analizando leak: ")

	//tempresponse(basal_i,peak_f,temp,chanexp) //se elimina basal _f
End



