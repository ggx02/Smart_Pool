#include "SmartPool.h"
#include "printf.h"

module SmartPoolC {
  uses {
    interface Boot;
    interface Timer<TMilli> as Timer;
    interface Leds;
    
    // Radio
    interface Packet;
    interface AMSend;
    interface SplitControl as RadioControl;

    // Sensore Torbidità
    interface Read<uint16_t> as ReadTurbidity;
    
    // Sensore Temperatura
    interface Read<uint16_t> as ReadTemp;

    // Interfaccia per leggere il pH 
    interface Read<uint16_t> as ReadPh;

    // Interfacce Pompe 
    interface HplMsp430GeneralIO as PumpPlus;  // Pompa Base (pH +)
    interface HplMsp430GeneralIO as PumpMinus; // Pompa Acido (pH -)
    
    // Timer durata dosaggio
    interface Timer<TMilli> as PumpTimer;
  }
}

implementation {

  message_t packet;
  bool radioBusy = FALSE;
  
   uint16_t g_temp_raw = 0; 
   int32_t g_temp_celsius = 0;  
   uint32_t g_turb_mv = 0; 
   uint8_t g_turb_status = TURBIDITY_OK;
   uint8_t g_ph_status = PH_NONMISURATO;

  // Soglia Torbidità
  const uint32_t SOGLIA_PIN_MV = 1885; 

  // Durata Pompe 
  const uint16_t PUMP_DURATION = 6000; 
  
  // Soglie Ph
  const uint16_t SOGLIA_PIN_ACIDO = 1920; 
  const uint16_t SOGLIA_PIN_BASICO = 1840;

  // Conversione Temp
  int32_t adcToCelsius(uint16_t adc_val) {
      int32_t temp = 0;
      temp = 25 + ((int32_t)adc_val - 2048) / 45;
      return temp;
  }

  void stopPumps() {
      call PumpPlus.clr();    
      call PumpMinus.clr();   
  }

  event void Boot.booted() {
    call PumpPlus.makeOutput(); //config pin digitali
    call PumpMinus.makeOutput();
    stopPumps(); // pompe spente all'avvio
    call RadioControl.start();
  }

  event void RadioControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer.startPeriodic(TIMER_PERIOD_MILLI);
      printf("System Ready. Cycle Duration: %u ms. Pump Duration: %u ms.\n",TIMER_PERIOD_MILLI, PUMP_DURATION);
      printfflush();
    } else {
      call RadioControl.start();
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  event void Timer.fired() {
    call Leds.led0Toggle(); 
    printf("\n Reading Cycle Start \n");
    printfflush();
    call ReadTurbidity.read();  //Torbidità
  }

  void sendRadioMessage() {
    if (!radioBusy) {
      SmartPoolMsg_t* msg = (SmartPoolMsg_t*)call Packet.getPayload(&packet, sizeof(SmartPoolMsg_t));
      msg->nodeId = TOS_NODE_ID;
      
      // Assegnazione degli stati
      msg->status_turbidity = g_turb_status;
      msg->status_ph = g_ph_status;
      msg->temp_celsius = g_temp_celsius;
      
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(SmartPoolMsg_t)) == SUCCESS) {
        radioBusy = TRUE;
      }
    }
  }

  // TORBIDITÀ
  event void ReadTurbidity.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
      g_turb_mv = (uint32_t)data * 3000 / 4096;
      printf("ADC Raw: %u | PIN Voltage: %lu mV\n", data, g_turb_mv);
      printfflush();

      if (g_turb_mv <= SOGLIA_PIN_MV) {
        printf("DIRTY WATER. STOP.\n");
        printfflush();
        
        g_turb_status = TURBIDITY_DIRTY;
        g_ph_status = PH_NONMISURATO; 
        call ReadTemp.read();

        call Leds.led1On(); 
        call Leds.led2Off();
        stopPumps(); 
      
        // Invio messaggio 
        sendRadioMessage(); 
        
      } else {
        printf("Water Clean. Reading Temp...\n");
        printfflush();
        
        g_turb_status = TURBIDITY_OK;
        call Leds.led1Off();
        call Leds.led2On(); 
        call ReadTemp.read();
      }
    } else {
      printf("Error Reading Turbidity.\n");
      printfflush();
    }
  }

  // TEMPERATURA
  event void ReadTemp.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
      g_temp_raw = data; 
      g_temp_celsius = adcToCelsius(g_temp_raw);
      
      printf("Temp ADC: %u. Temp-> %ld C\n", g_temp_raw, g_temp_celsius);
      printfflush();
      
	//se acqua=clean -> misura pH
     if(g_turb_status == TURBIDITY_OK){
      printf("Reading pH...\n");
      call ReadPh.read();
     }

    } else {
      printf("Error reading Temp Probe.\n"); 
    }
  }

  // pH E POMPE
  event void ReadPh.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {

        uint32_t voltage_pH; 

        voltage_pH = ((uint32_t)data * 3000) / 4096;
                  
        printf("pH Sensor Pin: %lu mV -> ", voltage_pH);
	printfflush();
       
	 // SOGLIE
        if (voltage_pH > SOGLIA_PIN_ACIDO) {
            // CASO ACIDO (> 1910 mV) 
            printf("ACIDO (minore di 6.5).\n");
	    printfflush();
            g_ph_status = PH_ACIDO;            

        } else if (voltage_pH < SOGLIA_PIN_BASICO) {
            // CASO BASICO (< 1860 mV)
            printf("BASE (ph>8).\n");
            printfflush();
            g_ph_status = PH_BASICO; 

        } else {
            // CASO NEUTRO
            printf("NEUTRO (range 6.5-8).\n");
            printfflush();
            g_ph_status = PH_NEUTRO; 
        }
        
	sendRadioMessage(); // Invio con Temp e Stati Ph

	//ATTIVAZIONE POMPE	
	 if(g_ph_status == PH_ACIDO){
	 printf("DOSING BASE (+).\n");
         printfflush();
	    call PumpPlus.set(); 
            call PumpTimer.startOneShot(PUMP_DURATION);

	}else if(g_ph_status == PH_BASICO){
         printf("DOSING ACID (-).\n");
         printfflush();
	    call PumpMinus.set(); 
            call PumpTimer.startOneShot(PUMP_DURATION);

	}else {
	
	printf("Pumps OFF.\n");
	stopPumps();

	}
        
    } else {
        printf("Error reading pH Probe.\n");
        printfflush();
        g_ph_status = PH_NONMISURATO; 
      }
  }

  // Spegne le pompe
  event void PumpTimer.fired() {
      stopPumps();      
      printf(" -> Dosing Complete. Pumps Stopped.\n");
      printfflush();
   
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (&packet == msg) radioBusy = FALSE;
  }
}
