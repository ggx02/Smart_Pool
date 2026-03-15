#include "SmartPool.h"

module SmartPoolBaseC {
  uses {
    interface Boot;
    interface Leds;
    interface SplitControl as RadioControl;    
    interface Receive;
    interface Packet;

    // Interfacce per la Seriale Uart
    interface StdControl as UartControl;
    interface Resource as UartResource;
    interface UartStream;
  }
}

implementation {

  // Variabili per buffer seriale
  uint8_t uartBuffer[60];
  bool sending = FALSE;

  // conversione numeri in testo
  void appendInt(char* buffer, uint8_t* idx, int value) {
      char temp[10];
      int i = 0;
      int v = value;
      
      // Estrai cifre
      do { temp[i++] = (v % 10) + '0'; } 
        while ((v /= 10) > 0);
      
      // Inverti
      while (i > 0) buffer[(*idx)++] = temp[--i];
  }

  event void Boot.booted() {
    call RadioControl.start();    
  }

  event void RadioControl.startDone(error_t err) {   
    if (err == SUCCESS) {
       call Leds.led1Toggle(); 
       call UartControl.start(); //Accensione UART solo se l'accensione radio è andata a buon fine

    } else {
       call RadioControl.start();
    }
  }

  event void RadioControl.stopDone(error_t err) {}

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    bool isSending;

    // Controllo Lunghezza 
    if (len == sizeof(SmartPoolMsg_t)) {
      
      SmartPoolMsg_t* rcm = (SmartPoolMsg_t*)payload;
      call Leds.led1Toggle(); 

      atomic { isSending = sending; } //direttiva per la variabile "sending" sync e async

      if (!isSending) {
        uint8_t i = 0;      
        memset(uartBuffer, 0, sizeof(uartBuffer));
        //stringa: $Turb,Ph,Temp;\n
        uartBuffer[i++] = '$';       
        appendInt((char*)uartBuffer, &i, rcm->status_turbidity);
        uartBuffer[i++] = ',';      
        appendInt((char*)uartBuffer, &i, rcm->status_ph);
        uartBuffer[i++] = ',';       
        appendInt((char*)uartBuffer, &i, rcm->temp_celsius);      
        uartBuffer[i++] = ';';
        uartBuffer[i++] = '\n';       

        // Accesso alla seriale per inviare
        call UartResource.request();

      }
      
      if (rcm->status_turbidity == TURBIDITY_DIRTY) {
          call Leds.led0On(); //led_rosso_telos
      } else {
          call Leds.led0Off();
      }
    }
    return msg;
  }

  // GESTIONE SERIALE 
  event void UartResource.granted() {

    uint16_t len = 0;
    while(uartBuffer[len] != '\n' && len < 50) len++;
    len++; 

    // Invio 
    if (call UartStream.send(uartBuffer, len) == SUCCESS) {
      atomic { sending = TRUE; }
    } else {
      call UartResource.release();
    }
  }

  async event void UartStream.sendDone(uint8_t* buf, uint16_t len, error_t error) {
    call UartResource.release();
    atomic { sending = FALSE; }
  }

  async event void UartStream.receivedByte(uint8_t byte) {}
  async event void UartStream.receiveDone(uint8_t* buf, uint16_t len, error_t error) {}
}
