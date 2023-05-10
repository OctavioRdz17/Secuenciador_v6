//+------------------------------------------------------------------+
//|                                              Secuenciador_v6.mq4 |
//|                                   Copyright 2022, Toktrading.net |
//+------------------------------------------------------------------+
//Indicador de secuencia 
#property copyright "Copyright 2022, Octavio Rodriguez"
#property link      "www.toktrading.net"
#property version   "6.0"
#property strict
#property indicator_chart_window
#property indicator_minimum -5
#property indicator_maximum 5
#property indicator_buffers 7
#property indicator_plots   7

//import section
#import "kernel32.dll"
int SystemTimeToFileTime(int& TimeArray[], int& FileTimeArray[]);
int FileTimeToLocalFileTime(int& FileTimeArray[], int& LocalFileTimeArray[]);
void GetSystemTime(int& TimeArray[]);
#import


//caduca
   int limityear  = 2023;
   int limitmonth = 12;
   int limitday   = 31;

//--- plot tendencia
#property indicator_label1  "Tendencia"
#property indicator_type1   DRAW_NONE
#property indicator_color1  clrSlateBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "Maximo"
#property indicator_type2   DRAW_NONE
#property indicator_color2  clrSlateBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "Minimo"
#property indicator_type3   DRAW_NONE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "Maximo Nuevo"
#property indicator_type4   DRAW_NONE
#property indicator_color4  clrSlateBlue
#property indicator_style4  STYLE_DOT
#property indicator_width4  1


#property indicator_label5  "Minimo Nuevo"
#property indicator_type5   DRAW_NONE
#property indicator_color5  clrTomato
#property indicator_style5  STYLE_DOT

#property indicator_label6  "Maximo Dualidad"
#property indicator_type6   DRAW_NONE
#property indicator_color6  clrAqua
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2

#property indicator_label7  "Minimo Dualidad"
#property indicator_type7   DRAW_NONE
#property indicator_color7  clrFuchsia
#property indicator_style7  STYLE_SOLID
#property indicator_width7  2


//--- input parameters
int     timeframe = Period();

input   double PullbackLevel=30.0;
input   double MesesDeTendencia = 1;//Semanas de tendencia
input   int PipsRectangulo = 35;//Altura de Rectangulos
        int velasExpress = 20000;
        bool expressTrend = false;
        bool reiniciandotendencia = false;
input   bool set_alarm  = true;//Alarmas Activadas 
input   int start_alarm = 8; //Hora de inicio alarmas
input   int end_alarm =  16; //Hora de fin alarmas
input   color ColorMaximo = clrSkyBlue;
input   color ColorMinimo = clrCrimson;


//--- indicator buffers
  double         tendenciaBuffer[];
  double         maximoBuffer[];
  double         minimoBuffer[];
  double         maximoNuevoBuffer[];
  double         minimoNuevoBuffer[];
  double         maximoPasadoBuffer[];
  double         minimoPasadoBuffer[];
  
  int tendenciaActual;
  double maximo;  //maximo de tendencia
  double minimo;  //minimo de tendencia 
  double maximoNuevo;
  double minimoNuevo;
  double maximoPasado;
  double minimoPasado;
  
  //maximo y minimo de las secuencias confirmadas y sus posiciones
  int posicionMaximo;
  int posicionMinimo; 
  int posicionMaximoPasado;
  int posicionMinimoPasado;
  
  //maximosy minimos para las secuencias no confirmadas
  int posicionMaximoNuevo;
  int posicionMinimoNuevo;
  int limit;
 
 // valores de las velas actuales del ciclo for
  double velaevaluandomax;
  double velaevaluandomin;
  
int ciclo;
int barrasIniciales;
int barrasActuales =Bars;

bool primerciclo;
bool startCount;

int last_level = 0;
int past_level = 0;
bool starting = true;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   maximo = 0;  //maximo de tendencia
   minimo = 0;  //minimo de tendencia 
   maximoNuevo = 0;
   minimoNuevo = 0;
   maximoPasado = 9999999;
   minimoPasado =0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            

   
//--- indicator buffers mapping
   tendenciaActual = 0;
    
   SetIndexBuffer(0,tendenciaBuffer);
   SetIndexBuffer(1,maximoBuffer);
   SetIndexBuffer(2,minimoBuffer);
   SetIndexBuffer(3,maximoNuevoBuffer);
   SetIndexBuffer(4,minimoNuevoBuffer);
   SetIndexBuffer(5,maximoPasadoBuffer);
   SetIndexBuffer(6,minimoPasadoBuffer);
   
   //--- Eliminar rectangulos de la grafica
   ObjectsDeleteAll(0,OBJ_RECTANGLE);
   ObjectsDeleteAll(NULL,"MIN",1,OBJ_RECTANGLE);
   ObjectsDeleteAll(NULL,"MAX",1,OBJ_RECTANGLE);
      
  //--- Aqui se crea la secuencia inicial
   int multiplicadorSemanas = 0;
   if(Period() == 1)multiplicadorSemanas = 480  * 15;
   if(Period() == 5)multiplicadorSemanas = 480 * 3;
   if(Period() == 15)multiplicadorSemanas = 480;
   if(Period() == 30)multiplicadorSemanas = 240;
   if(Period() == 60)multiplicadorSemanas = 120;
   if(Period() == 240)multiplicadorSemanas = 30; //4h
   if(Period() == 1440)multiplicadorSemanas = 1; //1d
   if(Period() == 10080)multiplicadorSemanas = 1;//1w
   if(Period() == 43200)multiplicadorSemanas = 1/4; //1m
   
   
   barrasIniciales = (int)NormalizeDouble(MesesDeTendencia * multiplicadorSemanas, 0);
   //if (barrasIniciales<=50)barrasIniciales = 300;
   if(barrasIniciales>=(Bars(NULL,Period())-1))barrasIniciales =  Bars(NULL,Period())-1;
           // parametros iniciales 
           
           primerciclo = true;
           startCount = false;
   
   if(!timecheck())
      {
         Alert("Se termino el tiempo de prueba de este indicador");
         return(INIT_FAILED);
      }
      
   //if(logdhay())return(INIT_SUCCEEDED);
   if(IsTesting())return(INIT_SUCCEEDED);
   


//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
      if(primerciclo==true)
      {
           maximo = iHigh(NULL,timeframe,barrasIniciales);
           minimo = iLow(NULL,timeframe,barrasIniciales);
           maximoNuevo = maximo;
           minimoNuevo = minimo;
           dibujarMaximo(barrasIniciales,maximo);
           dibujarMinimo(barrasIniciales,minimo); 
           posicionMaximoNuevo = posicionMaximo = barrasIniciales;
           posicionMinimoNuevo = posicionMinimo = barrasIniciales;
           tendenciaBuffer[barrasIniciales]= tendenciaActual;
          
          //secuencia para cuando se inicia el indicador
           for(int i=0;i<barrasIniciales;i++)
           {
              ciclo = (barrasIniciales)-i;
              tendenciaCiclo(ciclo);
              
              //revision para velas expres
              if(expressTrend == true && (posicionMaximo > (velasExpress+ciclo) ||  posicionMinimo > (velasExpress+ciclo))){
              //Print("posicionMaximo ="+(string)posicionMaximo+" posicionMinimo ="+(string)posicionMinimo);
              if(posicionMaximo>posicionMinimo){
                  reinicioExpress(posicionMaximo);
                  }else{
                   reinicioExpress(posicionMinimo);  
                  }
               
            }           
           }
           primerciclo = false;
           starting =false;
           
      }
      limit = Bars - barrasActuales;
      
      //cuando empieza el indicador no cuenta hasta no estar en estado actual osea rates total == prev calc
      if(rates_total == prev_calculated)startCount=true;// se cambia el estado a true
      
      
      for(int r =0;r<limit;r++)
      {
         //se suma 1 a todas las pociciones para compensar la vela nueva
        posicionMaximo++;
        posicionMinimo++;
        posicionMaximoNuevo++;
        posicionMinimoNuevo++;
        posicionMaximoPasado++;
        posicionMinimoPasado++;
        barrasActuales++;
         
        ciclo = 1;
        tendenciaCiclo(ciclo);
         
        if( expressTrend == true &&
            (posicionMaximo > velasExpress ||  posicionMinimo > velasExpress)){
              //Print("posicionMaximo ="+(string)posicionMaximo+" posicionMinimo ="+(string)posicionMinimo);
              reinicioExpress(velasExpress);
            }


        
      }
   
  
   
    //--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+

  bool revisandoRetroceso(int inicioScan,int finScan,double inicioTendencia,double finTendencia)
    {
      double retrocesoComparar;
      int velasContar = (finScan-1) - inicioScan;
      double distanciaRompimiento;
      double puntoRetroceso;
      //se saca la distancia a medir para el retroceso segun si es tendencia alcista o bajista
      if(finTendencia>inicioTendencia)//tendencia alcista
        {
          distanciaRompimiento = finTendencia - inicioTendencia;
          puntoRetroceso =  finTendencia -(distanciaRompimiento *  PullbackLevel/100);
          if(velasContar>0)
          {
          retrocesoComparar = iLow(NULL,timeframe,iLowest(NULL,timeframe,MODE_LOW,velasContar,inicioScan));
          }
          else{
          retrocesoComparar = iLow(NULL,timeframe,inicioScan);
          }
          //Comment ("el punto minimo es "+ retrocesoComparar +" \nel punto de retroceso es ="+puntoRetroceso+"\nEl maximo es = "+ finTendencia+"\nEl minimo es = "+inicioTendencia);
          if(retrocesoComparar<=puntoRetroceso)return true;
        }
        //si la tendencia es bajista es el otro caso
        else
        {
          //sacamos la distancia 
          distanciaRompimiento = inicioTendencia - finTendencia;
          puntoRetroceso =  finTendencia + (distanciaRompimiento * PullbackLevel/100);
          if(velasContar>0)
          {
          retrocesoComparar = iHigh(NULL,timeframe,iHighest(NULL,timeframe,MODE_HIGH,velasContar,inicioScan));
          }
          else{
          retrocesoComparar = iHigh(NULL,timeframe,inicioScan);
          }  
          //Comment ("el punto maximo es "+ retrocesoComparar +" \nel punto de retroceso es ="+puntoRetroceso+"\nEl maximo es = "+ inicioTendencia+"\nEl minimo es = "+finTendencia);
          if(retrocesoComparar>=puntoRetroceso)return true;
        }     
      return false;
    }
    
/////////////////////////////////////////////////////    

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dibujarMaximo(int tiempo,double valor)
  {
    // Agregamos el conteo de los maximos anteriores
    check_double_level(1,start_alarm,end_alarm);
    if(tiempo<=4)
        {
        string tiempoletra =IntegerToString((Bars -tiempo),0);
        tiempoletra = StringConcatenate("MAX",tiempoletra);
        ObjectDelete(tiempoletra);
        ObjectCreate(0,tiempoletra,OBJ_RECTANGLE,0,iTime(NULL,timeframe,tiempo),valor,iTime(NULL,timeframe,0),(valor-(10*Point)));
        
        ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,ColorMaximo);
        if(reiniciandotendencia)ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,clrLightGreen);
        return;
     }
   string tiempoletra =IntegerToString((Bars -tiempo),0);
   tiempoletra = StringConcatenate("MAX",tiempoletra);
   ObjectDelete(tiempoletra);
   ObjectCreate(0,tiempoletra,OBJ_RECTANGLE,0,iTime(NULL,timeframe,tiempo),valor,iTime(NULL,timeframe,(tiempo-4)),(valor-(10*Point)));
   
   ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,ColorMaximo);
   if(reiniciandotendencia)ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,clrLightGreen);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dibujarMinimo(int tiempo,double valor)
  {
    check_double_level(-1,start_alarm,end_alarm);
   if(tiempo<=4)
     {
      string tiempoletra =IntegerToString((Bars -tiempo),0);
      tiempoletra = StringConcatenate("MIN",tiempoletra);
      ObjectDelete(tiempoletra);
      ObjectCreate(0,tiempoletra,OBJ_RECTANGLE,0,iTime(NULL,timeframe,tiempo),valor,iTime(NULL,timeframe,0),(valor+(10*Point)));
      ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,ColorMinimo);
      if(reiniciandotendencia)ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,clrOrchid);
      return;
     }
   string tiempoletra =IntegerToString((Bars -tiempo),0);
   tiempoletra = StringConcatenate("MIN",tiempoletra);
   ObjectDelete(tiempoletra);
   ObjectCreate(0,tiempoletra,OBJ_RECTANGLE,0,iTime(NULL,timeframe,tiempo),valor,iTime(NULL,timeframe,(tiempo-4)),(valor+(10*Point)));
   ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,ColorMinimo);
   if(reiniciandotendencia)ObjectSetInteger(0,tiempoletra,OBJPROP_COLOR,clrOrchid);
  }
    
//////////////////////////////////////////////////////////////    
    
   int revisarMinimo(int inicioScan,int finScan)
    {
      int velascontar = finScan - inicioScan;
      int checkmin = iLowest(NULL,timeframe,MODE_LOW,velascontar,inicioScan);
      return (checkmin);
    }
    
   int revisarMaximo(int inicioScan,int finScan)
    {
      int velascontar = finScan - inicioScan;
      int checkmax = iHighest(NULL,timeframe,MODE_HIGH,velascontar,inicioScan);
      return (checkmax);
    }
    
    
    
    void crearBuffers(int cic,int tend,double max,double min, double maxNuevo,double minNuevo,double maxPasado, double minPasado)
      {
          tendenciaBuffer[cic]=tend;
          maximoBuffer[cic]= max;
          minimoBuffer[cic]= min;
          maximoNuevoBuffer[cic]= maxNuevo;
          minimoNuevoBuffer[cic]= minNuevo;
          maximoPasadoBuffer [cic] = maxPasado;
          minimoPasadoBuffer [cic] = minPasado;
              
       }
       
       
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void tendenciaCiclo(int perm)
{

    velaevaluandomax = iHigh(NULL,timeframe,perm);
    velaevaluandomin = iLow(NULL,timeframe,perm);
      if(tendenciaActual==0 && velaevaluandomax > maximo && velaevaluandomin >= minimo )//inicio alcista
            {
              tendenciaActual = 1;
              maximoNuevo = velaevaluandomax;
              posicionMaximoNuevo =perm;
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;
            }
         if(tendenciaActual==0 && velaevaluandomax <= maximo && velaevaluandomin < minimo )// inicio bajista
            {
              tendenciaActual = -1;
              posicionMinimoNuevo = perm; 
              minimoNuevo = velaevaluandomin;
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;
            } 
         if(tendenciaActual==0 && velaevaluandomax <= maximo && velaevaluandomin >= minimo )// inicio sin definir
            {
              tendenciaActual = 0;
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;
            }         
          if(tendenciaActual==0 && velaevaluandomax > maximo && velaevaluandomin < minimo )// inicio sin definir
            {
             tendenciaActual = 0;
             maximoNuevo = maximo =  velaevaluandomax;
             minimoNuevo= minimo = velaevaluandomin;
             posicionMaximo = posicionMinimo = perm;
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado); 
             return;
            }   
            
 //  1         
//Cuando la tendencia cambia a alcista sin comprobar 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////               
          
          
          //rompiendo maximonuevo anterior
            if(tendenciaActual==1 && velaevaluandomax > maximoNuevo && velaevaluandomin >= minimo )
            {
              //busca retroceso para cambiar a tendencia 2
               if(velaevaluandomax>maximoPasado)
               {
                  tendenciaActual = 3;
                  posicionMinimo =revisarMinimo(perm,posicionMaximoPasado);
                  maximoPasado = 9999999;
                  minimo = iLow(NULL,timeframe,posicionMinimo);
                  dibujarMinimo(posicionMinimo,minimo);
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                  return;  
               }
              if( revisandoRetroceso(perm,posicionMaximoNuevo,minimo,maximoNuevo)) 
                {
                tendenciaActual = 3; //se cambia a 3 confirmada sin retroceso nuevo
                maximoPasado = 9999999;
                minimo = velaevaluandomin;// como se genero el retroceso justo aqui donde no habia aqui mismo es el minimo
                posicionMinimo = perm;
                dibujarMinimo(posicionMinimo,minimo);
                maximo = velaevaluandomax; //y el maximo ya que se confirma la secuencia
                posicionMaximo  = perm;//se toman los puntos de los nuevos maximos y minimos
                ///crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                return;
                }
              maximoNuevo = velaevaluandomax; //despues de sacar el retroceso con el maximo pasado ahora si se actualiza el valor para seguir buscando retroceso con la nueva vela
              posicionMaximoNuevo = perm;//se toma la posicion del maximo nuevo
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }
            
          // tendencia 1 pero sin romper para ningun lado
          if(tendenciaActual==1 && velaevaluandomax <= maximoNuevo && velaevaluandomin >= minimo )
            {
              //busca retroceso para cambiar a tendencia 2
              if( revisandoRetroceso(perm,posicionMaximoNuevo,minimo,maximoNuevo)) tendenciaActual = 2;//se cambia a 2 alcista con retroceso
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }
           
          // tendencia 1 rompiendo para abajo la tendencia al cambiar de nuevo la tendencia se confirma la trampa del mercado
          if(tendenciaActual==1 && velaevaluandomax <= maximoNuevo && velaevaluandomin < minimo )
            {
              //cambia tendencia a -3 que es tendencia confirmada 
             minimo = velaevaluandomin; //se toma el nuevo minimo y su posicion
             posicionMinimo = perm;
             
             //se guardan los valores de los maximos pasados para tenerlos de comparacion 
             maximoPasado = maximoNuevo;
             posicionMaximoPasado = posicionMaximoNuevo;
             
             tendenciaActual = -3;  
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);           
             return;
            }
            
          //rompiendo en ambos lados se ve si la vela termino siendo positiva o negativa para confirmar tendencia alcista o bajista
          if(tendenciaActual==1 && velaevaluandomax > maximoNuevo && velaevaluandomin < minimo )
            {
              if(Open[perm]<Close[perm])// si cierra arriba se cambia a alcista confirmada
                {
                  tendenciaActual = 3;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  dibujarMinimo(perm,minimo);
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  maximoPasado = 9999999;
                  minimoPasado =0;   
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);              
                }
              else //
              {
                  tendenciaActual = -3;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  maximoNuevo = velaevaluandomax;
                  posicionMaximoNuevo = perm;                
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              }             
             return;
            }
            
            
//cuando la tendencia es 2 alcista sin confirmar con retroceso
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
          
          //rompiendo maximonuevo anterior
          if(tendenciaActual==2 && velaevaluandomax > maximoNuevo && velaevaluandomin >= minimo )
            {
              //Al romper maximo se confirma la tendencia
              tendenciaActual = 3;
              posicionMinimo =revisarMinimo(perm,posicionMaximoNuevo);
              maximoPasado =9999999;
              minimo = iLow(NULL,timeframe,posicionMinimo);
              dibujarMinimo(posicionMinimo,minimo);
              maximo = velaevaluandomax;
              posicionMaximo = perm;  
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;    
            }
            
          //cuando no rompe para ningun lado  
          if(tendenciaActual==2 && velaevaluandomax <= maximoNuevo && velaevaluandomin >= minimo)
            {
              //se continua la misma tendencia ya que no hay que hacer y  ya se comprobo la tendencia
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;
            }
          
          //cuando rompe en negativo
          if(tendenciaActual==2 && velaevaluandomax < maximoNuevo && velaevaluandomin <= minimo )
            {
              //cambia tendencia a -3 que es tendencia confirmada 
             minimo = velaevaluandomin; //se toma el nuevo minimo y su posicion
             posicionMinimo = perm;
             
             //se guardan los valores de los maximos pasados para tenerlos de comparacion 
             maximoPasado = maximoNuevo;
             posicionMaximoPasado = posicionMaximoNuevo;
             
             tendenciaActual = -3;  
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);            
             return;
            }
           
           //cuando rompe para los dos lados
          if(tendenciaActual==2 && velaevaluandomax > maximo && velaevaluandomin < minimo )
            {
              if(Open[perm]<Close[perm])// si cierra arriba se cambia a alcista confirmada
                {
                  tendenciaActual = 3;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  dibujarMinimo(perm,minimo);
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;  
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);               
                }
              else 
              {
                  tendenciaActual = -1;
                  minimoNuevo = velaevaluandomin;
                  posicionMinimoNuevo = perm;
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                 // dibujarMaximo(ciclo,maximo);
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              }             
             return;
            }
          
          
// 3 cuando la tendencia es 3 tendencia confirmada sin retroceso aun           
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
          
          
          //se rompe el maximo de la tendencia 
          if(tendenciaActual==3 && velaevaluandomax > maximo && velaevaluandomin >= minimo )
            {
              //busca retroceso para cambiar a tendencia 4
              if( revisandoRetroceso(perm,posicionMaximo,minimo,maximo)) 
                {
                tendenciaActual = 4; //se cambia a 4 confirmada con retroceso
                minimoPasado = 0; 
                posicionMinimo = revisarMinimo(perm,posicionMaximo);
                minimo = iLow (NULL,timeframe,posicionMinimo);
                dibujarMinimo(posicionMinimo,minimo);       
                maximo = velaevaluandomax; //se mueve maximo al nuevo punto
                posicionMaximo  = perm;//se toma el punto del maximo
                //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                return;
                }
              maximo = velaevaluandomax; //se mueve el nuevo maximo 
              posicionMaximo = perm;//se toma el punto
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }

          //no  rompe para ningun lado
          if(tendenciaActual==3 && velaevaluandomax <= maximo && velaevaluandomin >= minimo )
            {
              //busca retroceso para cambiar a tendencia 4
              if( revisandoRetroceso(perm,posicionMaximo,minimo,maximo)) tendenciaActual = 4;//se cambia a 4 cuando se confirma el retroceso
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }
            
          //rompe en negativo 
          if(tendenciaActual==3 && velaevaluandomax <= maximo && velaevaluandomin < minimo )
            {
            //if para encontrar dualidad
              if(velaevaluandomin<minimoPasado)
               {
                  tendenciaActual = -3;   
                  minimoPasado = 0;
                  posicionMaximo =revisarMaximo(perm,posicionMinimoPasado);
                  maximo = iHigh(NULL,timeframe,posicionMaximo);
                  dibujarMaximo(posicionMaximo,maximo);
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                  return;  
               }
              if(minimoPasado>0){
               tendenciaActual = -1;   
               //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);
               return;
               }
              //cambia tendencia -1
             minimoNuevo = velaevaluandomin; //minimoNuevo en tendencia no confirmada
             posicionMinimoNuevo = perm;
             tendenciaActual = -1;      
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);        
             return;
            }
          
          //rompiendo en ambos lados se ve si la vela termino siendo positiva o negativa para confirmar tendencia alcista o bajista
          if(tendenciaActual==3 && velaevaluandomax > maximo && velaevaluandomin < minimo )
            {
              if(Open[perm]<Close[perm])// si cierra arriba se cambia a alcista confirmada
                {
                  tendenciaActual = 3;                  
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  maximoPasado = 9999999;
                  minimoPasado =0;     
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);             
                }
              else //como viene de una confirmacion de tendencia momentanea se cambia a bajiasta sin confirmar
              {
                  tendenciaActual = -1;
                  minimoNuevo = velaevaluandomin;
                  posicionMinimoNuevo = perm;
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              }             
             return;
            }    
            
            
//tendencia 4 cuando ya esta confirmada la tendencia con pullback          
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    
    
              //rompiendo maximo anterior
          if(tendenciaActual==4 && velaevaluandomax > maximo && velaevaluandomin >= minimo )
            {
              tendenciaActual = 3;
              minimoPasado = 0;
              posicionMinimo =revisarMinimo(perm,posicionMaximo);
              minimo = iLow(NULL,timeframe,posicionMinimo);
              dibujarMinimo(posicionMinimo,minimo);
              maximo = velaevaluandomax;
              posicionMaximo = perm;  
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;      
            }
            
          //cuando no rompe para ningun lado  
          if(tendenciaActual==4 && velaevaluandomax <= maximo && velaevaluandomin >= minimo)
            {
              //se continua la misma tendencia ya que no hay que hacer y  ya se comprobo la tendencia
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;
            }
          
          //cuando rompe en negativo
          if(tendenciaActual==4 && velaevaluandomax < maximo && velaevaluandomin <= minimo )
            {
               //if para encontrar dualidad
              if(velaevaluandomin<minimoPasado)
               {
                  tendenciaActual = -3;   
                  minimoPasado = 0;
                  posicionMaximo =revisarMaximo(perm,posicionMinimoPasado);
                  maximo = iHigh(NULL,timeframe,posicionMaximo);
                  dibujarMaximo(posicionMaximo,maximo);
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                  return;  
               }
               if(minimoPasado>0){
                  tendenciaActual = -1;   
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);
                   return;
                  }
              //cambia tendencia a -1 que es tendencia confirmada 
             minimoNuevo = velaevaluandomin; //se tomsa el nuevo minimo y su posicion
             posicionMinimoNuevo = perm;
             tendenciaActual = -1; 
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);             
             return;
            }
           
           //cuando rompe para los dos lados
          if(tendenciaActual==4 && velaevaluandomax > maximo && velaevaluandomin < minimo )
            {
              if(Open[perm]<Close[perm])// si cierra arriba se cambia a alcista confirmada
                {
                  tendenciaActual = 3;             
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;  
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);               
                }
              else //como viene de una confirmacion de tendencia momentanea se cambia a bajiasta sin confirmar
              {
                  tendenciaActual = -1;
                  minimoNuevo = velaevaluandomin;
                  posicionMinimoNuevo = perm;
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                 
              }              
             return;
            }
            
            
    
//Cuando la tendencia cambia a bajista sin comprobar           
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////               
/////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////
//////////////////////////////////////////          
          //-1
          //rompiendo minimonuevo anterior
          if(tendenciaActual==-1 && velaevaluandomin < minimoNuevo && velaevaluandomax <= maximo )
            {
               //Se busca dualidad
               if(velaevaluandomin<minimoPasado)
               {
                  tendenciaActual = -3;
                  posicionMaximo = revisarMaximo(perm,posicionMinimoPasado);
                  minimoPasado = 0;
                  maximo = iHigh(NULL,timeframe,posicionMaximo);
                  dibujarMaximo(posicionMaximo,maximo);
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado); 
                  return;                
               }
              //busca retroceso para cambiar a tendencia -2
              if( revisandoRetroceso(perm,posicionMinimoNuevo,maximo,minimoNuevo)) 
                {
                tendenciaActual = -3; //se cambia a 3 confirmada sin retroceso nuevo
                minimoPasado = 0;
                maximo = velaevaluandomax;// como se genero el retroceso justo aqui donde no habia aqui mismo es el maximo
                posicionMaximo = perm;
                dibujarMaximo(posicionMaximo,maximo);
                minimo = velaevaluandomin; //y el maximo ya que se confirma la secuencia
                posicionMinimo  = perm;//se toman los puntos de los nuevos maximos y minimos
                //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                return;
                }
              minimoNuevo = velaevaluandomin; //despues de sacar el retroceso con el maximo pasado ahora si se actualiza el valor para seguir buscando retroceso con la nueva vela
              posicionMinimoNuevo = perm;//se toma la posicion del minimo nuevo
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }
            
          // tendencia 1 pero sin romper para ningun lado
          if(tendenciaActual==-1 && velaevaluandomin >= minimoNuevo && velaevaluandomax <= maximo )
            {
              //busca retroceso para cambiar a tendencia -2
              if( revisandoRetroceso(perm,posicionMinimoNuevo,maximo,minimoNuevo)) tendenciaActual = -2;//se cambia a 2 alcista con retroceso
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }
           
          // tendencia -1 rompiendo para arriba la tendencia al cambiar de nuevo la tendencia se confirma la trampa del mercado
          if(tendenciaActual==-1 && velaevaluandomax > maximo && velaevaluandomin >= minimoNuevo )
            {
              //cambia tendencia a -3 que es tendencia confirmada 
             maximo = velaevaluandomax; //se toma el nuevo maximo y su posicion
             posicionMaximo = perm;
             
             //Se guardan los valores de los minimos pasados para tenerlos en comparacion
             minimoPasado = minimoNuevo;
             posicionMinimoPasado = posicionMinimoNuevo;
             
             tendenciaActual = 3;
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);              
             return;           
            }
            
          //rompiendo en ambos lados se ve si la vela termino siendo positiva o negativa para confirmar tendencia alcista o bajista
          if(tendenciaActual==-1 && velaevaluandomin < minimoNuevo && velaevaluandomax > maximo )
            {
              if(Open[perm]>Close[perm])// si cierra abajo se cambia a bajista confirmada
                {
                  tendenciaActual = -3;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;                
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;  
                  dibujarMaximo(posicionMaximo,maximo);  
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);             
                }
              else //se crea unn  minimoNuevo y se cambia a 3
              {
                  tendenciaActual = 3;
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  minimoNuevo = velaevaluandomin;
                  posicionMinimoNuevo = perm;
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
               }             
             return;
            }  
            
 ////   -2        
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////   
 //rompiendo maximonuevo anterior
          if(tendenciaActual==-2 && velaevaluandomin < minimoNuevo && velaevaluandomax <= maximo )
            {
              //Al romper minimo se confirma la tendencia
              tendenciaActual = -3;
              minimoPasado = 0;
              posicionMaximo =revisarMaximo(perm,posicionMinimoNuevo);
              maximo = iHigh(NULL,timeframe,posicionMaximo);
              dibujarMaximo(posicionMaximo,maximo);
              minimo = velaevaluandomin;
              posicionMinimo = perm;  
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);              
              return;       
            }
            
          //cuando no rompe para ningun lado  
          if(tendenciaActual==-2 && velaevaluandomin >= minimoNuevo && velaevaluandomax <= maximo)
            {
              //se continua la misma tendencia ya que no hay que hacer y  ya se comprobo la tendencia
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;
            }
          
          //cuando rompe hacia arriba
          if(tendenciaActual==-2 && velaevaluandomin >= minimoNuevo && velaevaluandomax > maximo )
            {
              //cambia tendencia a 3 que es tendencia confirmada 
             maximo = velaevaluandomax; //se toma el nuevo maximo y su posicion
             posicionMaximo = perm;
             
             //Se guardan los valores de los minimos pasados para tenerlos en comparacion
             minimoPasado = minimoNuevo;
             posicionMinimoPasado = posicionMinimoNuevo;
             
             tendenciaActual = 3;
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);             
             return;
            }
           
           //cuando rompe para los dos lados
          if(tendenciaActual==-2 && velaevaluandomin < minimoNuevo && velaevaluandomax > maximo )
            {
              if(Open[perm]>Close[perm])// si cierra abajo se cambia a bajista confirmada
                {
                  tendenciaActual = -3;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;                 
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  dibujarMaximo(posicionMaximo,maximo); 
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);               
                }
              else 
              {
                  tendenciaActual = 1;
                  maximoNuevo = velaevaluandomax;
                  posicionMaximoNuevo = perm;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                //dibujarMinimo(posicionMinimo,minimo);
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              }             
             return;
            }
            
            
            
////   -3 cuando tenemos tendencia confirmada bajista sin retroceso
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////          
            
          
          //se rompe el minimo de la tendencia 
          if(tendenciaActual==-3 && velaevaluandomin < minimo && velaevaluandomax <= maximo )
            {
              //busca retroceso para cambiar a tendencia -4
              if( revisandoRetroceso(perm,posicionMinimo,maximo,minimo)) 
                {
                tendenciaActual = -4; //se cambia a 4 confirmada con retroceso 
                maximoPasado =9999999;
                posicionMaximo = revisarMaximo(perm,posicionMinimo);
                maximo = iHigh (NULL,timeframe,posicionMaximo);       
                minimo = velaevaluandomin; //se mueve maximo al nuevo punto
                posicionMinimo  = perm;//se toma el punto del maximo
                dibujarMaximo(posicionMaximo,maximo);
                //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                return;
                }
              
              minimo = velaevaluandomin; //se mueve el nuevo minimo 
              posicionMinimo = perm;//se toma el punto
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }

          //no  rompe para ningun lado
          if(tendenciaActual==-3 && velaevaluandomin >= minimo && velaevaluandomax <= maximo )
            {
              //busca retroceso para cambiar a tendencia 4
              if( revisandoRetroceso(perm,posicionMinimo,maximo,minimo)) tendenciaActual = -4;//se cambia a 4 cuando se confirma el retroceso
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
             return;
            }
            
          //rompe hacia arriba 
          if(tendenciaActual==-3 && velaevaluandomin >= minimo && velaevaluandomax > maximo )
            {
              //if para encontrar dualidad
              if(velaevaluandomax>maximoPasado)
               {
                  tendenciaActual = 3;   
                  maximoPasado = 9999999;
                  posicionMinimo =revisarMinimo(perm,posicionMaximoPasado);
                  minimo = iLow(NULL,timeframe,posicionMinimo);
                  dibujarMinimo(posicionMinimo,minimo);
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                  return;  
               }
                  //indicacion que no puede haber un maximonuevo sin romper primero el maximo pasado
              if(maximoPasado<9999998){
               tendenciaActual = 1;   
               //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);
               return;
              }
           //cambia tendencia 1
             maximoNuevo = velaevaluandomax; //minimoNuevo en tendencia no confirmada
             posicionMaximoNuevo = perm;
             tendenciaActual = 1;  
             //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);           
             return;
            }
          
          //rompiendo en ambos lados se ve si la vela termino siendo positiva o negativa para confirmar tendencia alcista o bajista
          if(tendenciaActual==-3 && velaevaluandomax > maximo && velaevaluandomin < minimo )
            {
              if(Open[perm]<Close[perm])// si cierra arriba se cambia a alcista no confirmada
                {
                  tendenciaActual = 1;                  
                  maximoNuevo = velaevaluandomax;
                  posicionMaximoNuevo = perm; 
                  posicionMinimo =perm;
                  minimo = velaevaluandomin; 
                  maximoPasado = 9999999;
                  minimoPasado =0;    
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                  return;           
                }
              else //como viene de una confirmacion de tendencia momentanea se cambia a bajiasta sin confirmar
              {
                  tendenciaActual = -4;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                  return;             
              }             
            
            }                
           

//tendencia -4 cuando ya esta confirmada la tendencia con pullback          
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    
    
              //rompiendo maximo anterior
          if(tendenciaActual==-4 && velaevaluandomax <= maximo && velaevaluandomin < minimo )
            {
                 //Al romper minimo se confirma la tendencia
                 tendenciaActual = -3;
                 maximoPasado = 9999999;
                 posicionMaximo =revisarMaximo(perm,posicionMinimo);
                 maximo = iHigh(NULL,timeframe,posicionMaximo);
                 dibujarMaximo(posicionMaximo,maximo);
                 minimo = velaevaluandomin;
                 posicionMinimo = perm; 
                 //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);             
                 return;    
            }
            
          //cuando no rompe para ningun lado  
          if(tendenciaActual==-4 && velaevaluandomax <= maximo && velaevaluandomin >= minimo)
            {
              //se continua la misma tendencia ya que no hay que hacer y  ya se comprobo la tendencia
              //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
              return;
            }
          
          //cuando rompe en negativo
          if(tendenciaActual==-4 && velaevaluandomax > maximo && velaevaluandomin >= minimo )
            {
             if(velaevaluandomax>maximoPasado)
               {
                  tendenciaActual = 3;
                  maximoPasado = 9999999;
                  posicionMinimo =revisarMinimo(perm,posicionMaximoPasado);
                  minimo = iLow(NULL,timeframe,posicionMinimo);
                  dibujarMinimo(posicionMinimo,minimo);
                  maximo = velaevaluandomax;
                  posicionMaximo = perm;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);  
                  return;  
               }
               
                  //indicacion que no puede haber un maximonuevo sin romper primero el maximo pasado
              if(maximoPasado<9999998){
               tendenciaActual = 1;   
               //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);
               return;
              }
             //cambia tendencia a 1 que es tendencia confirmada 
             maximoNuevo = velaevaluandomax; //se toma el nuevo minimo y su posicion
             posicionMaximoNuevo = perm;
             tendenciaActual = 1;   
            //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);           
             return;
            }
       
          //rompiendo para los dos laredos 
          if(tendenciaActual==-4 && velaevaluandomax > maximo && velaevaluandomin < minimo )
            {
              if(Open[perm]<Close[perm])// si cierra arriba se cambia a alcista no confirmada
                {
                  tendenciaActual = 1;                  
                  maximoNuevo = velaevaluandomax;
                  posicionMaximoNuevo = perm; 
                  posicionMinimo =perm;
                  minimo = velaevaluandomin;   
                 // dibujarMinimo(posicionMinimo,minimo); 
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado);             
                }
              else //como viene de una confirmacion de tendencia momentanea se cambia a bajiasta sin confirmar
              {
                  tendenciaActual = -3;
                  minimo = velaevaluandomin;
                  posicionMinimo = perm;
                  maximoPasado = 9999999;
                  minimoPasado =0;
                  //crearBuffers(ciclo,tendenciaActual,maximo,minimo,maximoNuevo,minimoNuevo,maximoPasado,minimoPasado); 
                 
              }             
             return;
            }  

}

bool timecheck(){

   if(TimeYear(TimeLocal())<limityear)return true;
   if(TimeYear(TimeLocal())>limityear)return false;
   
   if(TimeMonth(TimeLocal())<limitmonth)return true;
   if(TimeMonth(TimeLocal())>limitmonth)return false;
   
   if(TimeDay(TimeLocal())<=limitday)return true;
   if(TimeDay(TimeLocal())>limitday)return false;  
   
   return false;  
}

datetime GetWinLocalDateTime(){
   double hundrednSecPerSec = 10.0 * 1000000.0;
   double bit32to64 = 65536.0 * 65536.0;
   double secondsBetween1601And1970 = 11644473600.0;
   int    TimeArray[4];
   int    FileTimeArray[2];   // 100nSec since 1601/01/01 UTC
   int    LocalFileTimeArray[2];   // 100nSec since 1601/01/01 Local

   GetSystemTime(TimeArray);
   SystemTimeToFileTime(TimeArray, FileTimeArray);
   FileTimeToLocalFileTime(FileTimeArray, LocalFileTimeArray);

   double lfLo32 = LocalFileTimeArray[0];
   if(lfLo32 < 0)
      lfLo32 = bit32to64 + lfLo32;
   double ticksSince1601 = LocalFileTimeArray[1] * bit32to64 + lfLo32;
   double secondsSince1601 = ticksSince1601 / hundrednSecPerSec;
   double secondsSince1970 = secondsSince1601 - secondsBetween1601And1970;
   return (int)(secondsSince1970);
}
  
  void reinicioExpress(int velasReinicio){
    //--- Eliminar rectangulos de la grafica
    //ObjectsDeleteAll(0,OBJ_RECTANGLE);

    //Agregamos marcador para saber que es tendencia redibujada
    reiniciandotendencia =  true;
    
    barrasIniciales = velasReinicio - 2;
    tendenciaActual = 0;

    maximo = iHigh(NULL,timeframe,barrasIniciales);
    minimo = iLow (NULL,timeframe,barrasIniciales);
    maximoNuevo = maximo;
    minimoNuevo = minimo;
    maximoPasado = 9999999;
    minimoPasado =0;

    dibujarMaximo(barrasIniciales,maximo);
    dibujarMinimo(barrasIniciales,minimo);
    posicionMaximoNuevo = posicionMaximo = barrasIniciales;
    posicionMinimoNuevo = posicionMinimo = barrasIniciales;

    for(int i = velasReinicio-3; i > ciclo; i--)
        {      
          //revicionVolumen(i);
          //revicionFuerza(i);
          tendenciaCiclo(i);
        }
      //barrasActuales = Bars;
      reiniciandotendencia =  false;

}


void check_double_level(int new_level,int start_t, int end_t){
    // Creamos un algoritmo para contar cuando se tienen dos niveles consecutivos
    // tiene 2 var que son las ultimas velas pasadas last_level,past_level

    if(in_time(start_t,end_t) && !starting){
        // alarma de maximos consecutivos
        if (new_level == 1 && last_level == 1 ){
            // Cuando se dan las condiciones activamos la alarmar
            past_level = last_level;
            last_level = new_level;
            Alert("Posible entrada en el par => "+string(Symbol()));
            // Print("Posible entrada en el par => "+string(Symbol()));
        }
        
        // alarma de minimos consecutivos
        if (new_level == -1 && last_level == -1  ){
            // Cuando se dan las condiciones activamos la alarmar
            past_level = last_level;
            last_level = new_level;
            Alert("Posible entrada en el par => "+string(Symbol()));
            // Print("Posible entrada en el par => "+string(Symbol()));
        }
    }

    past_level = last_level;
    last_level = new_level;  
}

// Return true if the time in the range on the parameters
bool in_time(int start_time,int end_time){
    int horaEvaluar = TimeHour(iTime(NULL,Period(),0)); ///se toma la hora

    if(horaEvaluar >= start_time  && horaEvaluar < end_time && set_alarm)//if para solo ejecutar en 8 o 12
     {
       return true;
     }
     return false;

}