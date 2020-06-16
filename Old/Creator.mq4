//+-------------------------------------------------------------------------+
//|                                                             Creator.mq4 |
//|    Copyright (c) 2009, Yury V. Reshetov  http://bigfx.ru/load/3-1-0-177 |
//|                                          http://bigfx.ru/load/3-1-0-177 |
//+-------------------------------------------------------------------------+
#property copyright "Copyright (c) 2009, Yury V. Reshetov  http://bigfx.ru/load/3-1-0-177"
#property link      "http://bigfx.ru/load/3-1-0-177"
extern double lots = 1;
extern int dcandle = 0;
extern int  drsi = 0;
extern int  dcci = 0;
extern int  dac = 0;
extern int  dac1 = 0;
extern int  dao = 0;
extern int  dao1 = 0;
extern int  dmacd = 0;
extern int  dmacd1 = 0;
extern int  dosma = 0;
extern int  dosma1 = 0;
extern int  prsi = 14;
extern int  pcci = 20;
extern int  fastmacd = 12;
extern int  slowmacd = 26;
extern int  signalmacd = 9;
static int prevtime = 0;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   prevtime = Time[0];
   return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
//----
   int ticket = -1;
   int total = OrdersTotal();
   for (int i = 0; i < total; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      int prevticket = OrderTicket();
      if (OrderType() == OP_BUY) {
         if (shortsignal()) {
            ticket = OrderSend(Symbol(), OP_SELL, 2.0, Bid, 0, 0, 0, "", 0, 0, Red);  
            OrderCloseBy(ticket, prevticket, Red);
         }
      } else {
         if (longsignal()) {
            ticket = OrderSend(Symbol(), OP_BUY, 2.0, Ask, 0, 0, 0, "", 0, 0, Blue);  
            OrderCloseBy(ticket, prevticket, Blue);
         }
      }
      return(0);
   }
//----
   if (longsignal()) {
      OrderSend(Symbol(), OP_BUY, 1.0, Ask, 0, 0, 0, "", 0, 0, Blue);  
      return(0);
   }
   if (shortsignal()) {
      OrderSend(Symbol(), OP_SELL, 1.0, Bid, 0, 0, 0, "", 0, 0, Red);  
   }
   return(0);
  }
//+------------------------------------------------------------------+
bool longsignal() {
   if (fcandle() < 0) {
      return(false);
   }
   if (frsi() < 0) {
      return(false);
   }
   if (fcci() < 0) {
      return(false);
   }
   if (fac() < 0) {
      return(false);
   }
   if (fac1() < 0) {
      return(false);
   }
   if (fao() < 0) {
      return(false);
   }
   if (fao1() < 0) {
      return(false);
   }
   if (fmacd() < 0) {
      return(false);
   }
   if (fmacd1() < 0) {
      return(false);
   }
   if (fosma() < 0) {
      return(false);
   }
   if (fosma1() < 0) {
      return(false);
   }
   return(true);
}
bool shortsignal() {
   if (fcandle() > 0) {
      return(false);
   }
   if (frsi() > 0) {
      return(false);
   }
   if (fcci() > 0) {
      return(false);
   }
   if (fac() > 0) {
      return(false);
   }
   if (fac1() > 0) {
      return(false);
   }
   if (fao() > 0) {
      return(false);
   }
   if (fao1() > 0) {
      return(false);
   }
   if (fmacd() > 0) {
      return(false);
   }
   if (fmacd1() > 0) {
      return(false);
   }
   if (fosma() > 0) {
      return(false);
   }
   if (fosma1() > 0) {
      return(false);
   }
   return(true);
}
int fcandle() {
   if (dcandle == 0) {
      return(0);
   }
   int result = 0;
   if (Open[0] > Open[1]) {
      result = 1;
   }
   if (Open[0] < Open[1]) {
      result = -1;
   }
   if (dcandle == 1) {
      return(-result);
   }
   return(result);
}
int frsi() {
   if (drsi == 0) {
      return(0);
   }
   int result = 0;
   double ind = iRSI(Symbol(), 0, prsi, PRICE_OPEN, 0) - 50.0;
   if (ind > 0) {
      result = 1;
   }
   if (ind < 0) {
      result = -1;
   }
   if (drsi == 1) {
      return(-result);
   }
   return(result);
}
int fcci() {
   if (dcci == 0) {
      return(0);
   }
   int result = 0;
   double ind = iCCI(Symbol(), 0, pcci, PRICE_OPEN, 0);
   if (ind > 0) {
      result = 1;
   }
   if (ind < 0) {
      result = -1;
   }
   if (dcci == 1) {
      return(-result);
   }
   return(result);
}
int fac() {
   if (dac == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iAC(Symbol(), 0, 0);
   if (ind > 0) {
      result = 1;
   }
   if (ind < 0) {
      result = -1;
   }
   if (dac == 1) {
      return(-result);
   }
   return(result);
}
int fac1() {
   if (dac1 == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iAC(Symbol(), 0, 0);
   double ind1 = iAC(Symbol(), 0, 1);
   if ((ind - ind1) > 0) {
      result = 1;
   }
   if ((ind - ind1) < 0) {
      result = -1;
   }
   if (dac1 == 1) {
      return(-result);
   }
   return(result);
}
int fao() {
   if (dao == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iAO(Symbol(), 0, 0);
   if (ind > 0) {
      result = 1;
   }
   if (ind < 0) {
      result = -1;
   }
   if (dao == 1) {
      return(-result);
   }
   return(result);
}
int fao1() {
   if (dao1 == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iAO(Symbol(), 0, 0);
   double ind1 = iAO(Symbol(), 0, 1);
   if ((ind - ind1) > 0) {
      result = 1;
   }
   if ((ind - ind1) < 0) {
      result = -1;
   }
   if (dao1 == 1) {
      return(-result);
   }
   return(result);
}
int fmacd() {
   if (dmacd == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iMACD(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, MODE_MAIN, 0);
   if (ind > 0) {
      result = 1;
   }
   if (ind < 0) {
      result = -1;
   }
   if (dmacd == 1) {
      return(-result);
   }
   return(result);
}
int fmacd1() {
   if (dmacd1 == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iMACD(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, MODE_MAIN, 0);
   double ind1 = iMACD(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, MODE_MAIN, 1);
   if ((ind - ind1) > 0) {
      result = 1;
   }
   if ((ind - ind1) < 0) {
      result = -1;
   }
   if (dmacd1 == 1) {
      return(-result);
   }
   return(result);
}
int fosma() {
   if (dosma == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iOsMA(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, 0);
      
   if (ind > 0) {
      result = 1;
   }
   if (ind < 0) {
      result = -1;
   }
   if (dosma == 1) {
      return(-result);
   }
   return(result);
}
int fosma1() {
   if (dosma1 == 0) {
      return(0);
   }
   
   int result = 0;
   double ind = iOsMA(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, 0);
   double ind1 = iOsMA(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, 1);
      
   if ((ind - ind1) > 0) {
      result = 1;
   }
   if ((ind - ind1) < 0) {
      result = -1;
   }
   if (dosma1 == 1) {
      return(-result);
   }
   return(result);
}
