//+------------------------------------------------------------------+
//|                                             Bystruev20090407.mq4 |
//|                     Copyright © 2009, Denis Bystruev, 7 Apr 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 7 Apr 2009"
#property link      "http://www.moeradio.ru"

#define  STATUS_COLLECTING_STATS    0
#define  STATUS_TRADING             1
#define  ZERO                       0.00001

extern   int      status_ticks   =  100;  // for how long to collect status
extern   int      trade_ticks    =  100;  // for how long to trade
extern   double   trailing_level =  0.5;  // trail at 50%

double   high_price;    // current high price
int      high_ticket;   // ticket for high order
double   lot;           // current lot size
double   low_price;     // current low price
int      low_ticket;    // tikect for low order
double   spread;        // minimum spread
int      status;        // current status (working mode)
int      ticks_counter; // counter for status_ticks or trade_ticks

int init() {
   spread         =  MarketInfo(Symbol(), MODE_SPREAD) * Point;
   high_price     =  Ask + spread;
   high_ticket    =  -1;
   lot            =  MarketInfo(Symbol(), MODE_MINLOT);
   low_price      =  Bid - spread;
   low_ticket     =  -1;
   status         =  STATUS_COLLECTING_STATS;
   ticks_counter  =  0;
}

int close_order(int ticket) {
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      switch (OrderType()) {
         case OP_BUY:
            if (OrderClose(ticket, OrderLots(), Bid, 0)) {
               ticket = -1;
            }
            break;
         case OP_SELL:
            if (OrderClose(ticket, OrderLots(), Ask, 0)) {
               ticket = -1;
            }
            break;
         case OP_BUYLIMIT:
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
         case OP_SELLSTOP:
            OrderDelete(ticket);
            ticket = -1;
            break;
      }
   }
   return (ticket);
}

int send_order(int cmd, double volume, double price, double stoploss, double takeprofit) {
   return (OrderSend(Symbol(), cmd, volume, price, 0, stoploss, takeprofit));
}

int start() {
   if (AccountEquity() < lot * MarketInfo(Symbol(), MODE_MARGINREQUIRED)) {
      return;
   }
   switch (status) {
      case STATUS_COLLECTING_STATS:
         ticks_counter++;
         if (ticks_counter > status_ticks) {
            status         =  STATUS_TRADING;
            ticks_counter  =  0;
         } else {
            low_price      =  MathMin(low_price, Bid - spread);
            high_price     =  MathMax(high_price, Ask + spread);
         }
         break;
      case STATUS_TRADING:
         ticks_counter++;
         if (ticks_counter >= trade_ticks) {
            low_ticket     =  close_order(low_ticket);
            high_ticket    =  close_order(high_ticket);
            low_price      =  Bid - spread;
            high_price     =  Ask + spread;
            status         =  STATUS_COLLECTING_STATS;
            ticks_counter  =  0;
         } else {
            if (OrdersTotal() == 0) {
               low_ticket  =  send_order(OP_SELLSTOP, lot, low_price, 0.0, 0.0);
               high_ticket =  send_order(OP_BUYSTOP, lot, high_price, 0.0, 0.0);
            } else {
               trail_order(low_ticket);
               trail_order(high_ticket);
            }
         }
         break;
   }
}

void trail_order(int ticket) {
   double   prev_stoploss;
   double   stoploss;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      switch (OrderType()) {
         case OP_BUY:
            if (OrderStopLoss() > ZERO) {
               prev_stoploss = OrderStopLoss();
            } else {
               prev_stoploss = OrderOpenPrice();
            }
            stoploss =  OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice());
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMin(stoploss, Bid - spread);
            if (prev_stoploss < stoploss) {
               OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            }
            break;
         case OP_SELL:
            if (OrderStopLoss() > ZERO) {
               prev_stoploss = OrderStopLoss();
            } else {
               prev_stoploss = OrderOpenPrice();
            }
            stoploss =  OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMax(stoploss, Ask + spread);
            if (stoploss < prev_stoploss) {
               OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            }
            break;
      }
   }
}

