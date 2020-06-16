//+-------------------------------------------------------------------------+
//|                                                               reshetov.mq4 |
//|      Copyright © 2009, Yury V. Reshetov  http://bigfx.ru/load/3-1-0-177 |
//|                                          http://bigfx.ru/load/3-1-0-177 |
//+-------------------------------------------------------------------------+
#property copyright "Copyright © 2009, Yury V. Reshetov  http://bigfx.ru/load/3-1-0-177"
#property link      "http://bigfx.ru/load/3-1-0-177"
extern double lots = 0.1;
extern int prsi = 89;
extern int pcci = 27;
extern int fastmacd = 33;
extern int slowmacd = 68;
extern int signalmacd = 17;
extern int magic = 888;
extern int slippage = 0;
static int prevtime = 0;

int init() {
   prevtime = Time[0];
   return(0);
}

int start() {

   if (! IsTradeAllowed()) {
      return(0);
   }

   if (Time[0] == prevtime) {
      return(0);
   }
   prevtime = Time[0];

   int ticket = -1;
   int total = OrdersTotal();
   for (int i = 0; i < total; i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if ((OrderSymbol() == Symbol()) && (OrderMagicNumber() == magic)) {
         int prevticket = OrderTicket();
         if (OrderType() == OP_BUY) {
            if (shortsignal()) {
               ticket = OrderSend(Symbol(), OP_SELL, 2.0 * lots, Bid, slippage, 0, 0, WindowExpertName(), magic, 0, Red);
               Sleep(30000);
               if (ticket < 0) {
                  prevtime = Time[1];
                  return(0);
               } else {
                  OrderCloseBy(ticket, prevticket, Red);
               }
            }
          } else {
            if (longsignal()) {
               ticket = OrderSend(Symbol(), OP_BUY, 2.0 * lots, Ask, slippage, 0, 0, WindowExpertName(), magic, 0, Blue);
               Sleep(30000);
               if (ticket < 0) {
                  prevtime = Time[1];
                  return(0);
               } else {
                  OrderCloseBy(ticket, prevticket, Blue);
               }
            }
          }
          return(0);
      }
   }

   if (longsignal()) {
      ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, slippage, 0, 0, WindowExpertName(), magic, 0, Blue);
      Sleep(30000);
      if (ticket < 0) {
         prevtime = Time[1];
      }
      return(0);
   }
   if (shortsignal()) {
      ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, slippage, 0, 0, WindowExpertName(), magic, 0, Red);
      Sleep(30000);
      if (ticket < 0) {
         prevtime = Time[1];
      }
      return(0);
   }
   return(0);
}

bool longsignal() {
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
   if (fao1() < 0) {
      return(false);
   }
   if (fmacd1() < 0) {
      return(false);
   }
   return(true);
}

bool shortsignal() {
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
   if (fao1() > 0) {
      return(false);
   }
   if (fmacd1() > 0) {
      return(false);
   }
   return(true);
}
int frsi() {
   int result = 0;
   double ind = iRSI(Symbol(), 0, prsi, PRICE_OPEN, 0) - 50.0;
   if (ind < 0) {
      result = 1;
   }
   if (ind > 0) {
      result = -1;
   }
   return(result);
}

int fcci() {
   int result = 0;
   double ind = iCCI(Symbol(), 0, pcci, PRICE_OPEN, 0);
   if (ind < 0) {
      result = 1;
   }
   if (ind > 0) {
      result = -1;
   }
   return(result);
}

int fac() {
   int result = 0;
   double ind = iAC(Symbol(), 0, 0);
   if (ind < 0) {
      result = 1;
   }
   if (ind > 0) {
      result = -1;
   }
   return(result);
}

int fac1() {
   int result = 0;
   double ind = iAC(Symbol(), 0, 0);
   double ind1 = iAC(Symbol(), 0, 1);
   if ((ind - ind1) < 0) {
      result = 1;
   }
   if ((ind - ind1) > 0) {
      result = -1;
   }
   return(result);
}

int fao1() {
   int result = 0;
   double ind = iAO(Symbol(), 0, 0);
   double ind1 = iAO(Symbol(), 0, 1);
   if ((ind - ind1) < 0) {
      result = 1;
   }
   if ((ind - ind1) > 0) {
      result = -1;
   }
   return(result);
}

int fmacd1() {
   int result = 0;
   double ind = iMACD(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, MODE_MAIN, 0);
   double ind1 = iMACD(Symbol(), 0, fastmacd, slowmacd, signalmacd, PRICE_OPEN, MODE_MAIN, 1);
   if ((ind - ind1) < 0) {
      result = 1;
   }
   if ((ind - ind1) > 0) {
      result = -1;
   }
   return(result);
}

