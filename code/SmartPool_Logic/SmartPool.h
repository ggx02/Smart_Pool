#ifndef SMARTPOOL_H
#define SMARTPOOL_H

enum {
  AM_SMARTPOOL_MSG = 6,
  TIMER_PERIOD_MILLI = 60000, // Timer Lettura
  
  // TORBIDITÀ 
  TURBIDITY_OK = 0,  
  TURBIDITY_DIRTY = 1,

  // pH
  PH_NEUTRO = 0, 
  PH_ACIDO = 1,
  PH_BASICO = 2,
  PH_NONMISURATO = 3
};

typedef nx_struct SmartPoolMsg {
  
  nx_uint16_t nodeId;
  nx_uint8_t  status_turbidity;
  nx_uint8_t  status_ph;        
  nx_int16_t  temp_celsius; 
  
 } SmartPoolMsg_t;

#endif
