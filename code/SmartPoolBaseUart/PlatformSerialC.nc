
configuration PlatformSerialC {
  
  provides interface StdControl;
  provides interface UartStream;
  provides interface UartByte;
  provides interface Resource;
  
}

implementation {
  
  components new Msp430Uart0C() as UartC;
  UartStream = UartC;  
  UartByte = UartC;
  Resource = UartC.Resource;
  
  components TelosSerialP;
  StdControl = TelosSerialP;
  TelosSerialP.Msp430UartConfigure <- UartC.Msp430UartConfigure;
  TelosSerialP.Resource -> UartC.Resource;
  
}
