#include "SmartPool.h"
#include "printf.h"

configuration SmartPoolBaseAppC {}
implementation {
  components MainC, LedsC;
  components SmartPoolBaseC;
  
  //Ricezione Radio
  components ActiveMessageC;
  components new AMReceiverC(AM_SMARTPOOL_MSG);
  components PlatformSerialC; // Gestisce i pin UART esterni tramite Msp430Uart0C
  components PrintfC, SerialStartC;

  // WIRING 
  SmartPoolBaseC.Boot -> MainC;
  SmartPoolBaseC.Leds -> LedsC;

  SmartPoolBaseC.RadioControl -> ActiveMessageC;
  SmartPoolBaseC.Receive -> AMReceiverC;
  SmartPoolBaseC.Packet -> AMReceiverC;

  // WIRING UART
  SmartPoolBaseC.UartControl -> PlatformSerialC.StdControl;
  SmartPoolBaseC.UartStream -> PlatformSerialC.UartStream;
  SmartPoolBaseC.UartResource -> PlatformSerialC.Resource;
}
