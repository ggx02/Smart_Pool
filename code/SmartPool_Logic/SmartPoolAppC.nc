#include "SmartPool.h"
#include "printf.h"

configuration SmartPoolAppC {}

implementation {

  components MainC, SmartPoolC, LedsC;
  
  // Timer Principale
  components new TimerMilliC() as Timer0;
  
  // Timer Pompe
  components new TimerMilliC() as TimerPumps;
  
  // Debug/Radio
  components PrintfC, SerialStartC; 
  components ActiveMessageC;
  components new AMSenderC(AM_SMARTPOOL_MSG);

  // Sensori
  components new AdcReadClientC() as TurbidityClient;
  components AdcTurbidityConfigC;  
  components new AdcReadClientC() as TempClient;
  components AdcTempConfigC;  
  components new AdcReadClientC() as PhClient;
  components AdcPhConfigC;

  // PIN DIGITALI
  components HplMsp430GeneralIOC as GpioC;

  // WIRING
  SmartPoolC.Boot -> MainC;
  SmartPoolC.Leds -> LedsC;

  SmartPoolC.Timer -> Timer0;         
  SmartPoolC.PumpTimer -> TimerPumps;

  SmartPoolC.Packet -> AMSenderC;
  SmartPoolC.AMSend -> AMSenderC;
  SmartPoolC.RadioControl -> ActiveMessageC;

  SmartPoolC.ReadTurbidity -> TurbidityClient;
  TurbidityClient.AdcConfigure -> AdcTurbidityConfigC;

  SmartPoolC.ReadTemp -> TempClient;
  TempClient.AdcConfigure -> AdcTempConfigC;

  SmartPoolC.ReadPh -> PhClient;
  PhClient.AdcConfigure -> AdcPhConfigC;
  
  // Pompa PLUS (Base)-PIN 3 
  SmartPoolC.PumpPlus -> GpioC.Port23;
 
  // Pompa MINUS (Acido)-PIN 4 
  SmartPoolC.PumpMinus -> GpioC.Port26;
}
