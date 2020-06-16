//+------------------------------------------------------------------+
//|                                             Bystruev20090409.mq4 |
//|                     Copyright © 2009, Denis Bystruev, 9 Apr 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 9 Apr 2009"
#property link      "http://www.moeradio.ru"

#define        MAGIC          19730503

extern   int   min_delta      =  50;   // Minimum difference between low and high price when to start trading
extern   int   trailing_level =  0.5;  // Trail at 50%

double         lot;                    // Current lot size
double         max_price;              // Maximum price
double         min_price;              // Minimum price
int            order_ticket;           // Order ticket for our only order
double         stop_level;             // Minimum spread of stop order and price
int            total_orders_array[6];  // Array of total orders of each type

int init() {
   lot         =  MarketInfo(Symbol(), MODE_MINLOT);
   stop_level  =  Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   max_price   =  Ask;
   min_price   =  Bid;
}

int start() {
   max_price   =  MathMax(max_price, Ask);
   min_price   =  MathMin(min_price, Bid);
   switch (total_orders()) {
      case 0:
         if (max_price - min_price < min_delta * Point) {
            return;
         }
         order_ticket = send_order();
         break;
      default:
         trail_order(order_ticket);
         break;
   }   
}

int send_order() {
   int      mode;
   double   price =  (min_price + max_price) / 2.0;
   double   stoploss;
   if ((Ask + Bid) / 2.0 < price) {
      mode     =  OP_BUYSTOP;
      stoploss =  min_price;
   } else {
      mode  =  OP_SELLSTOP;
      stoploss =  max_price;
   }
   price =  Point * MathRound(price / Point);
   return (OrderSend(Symbol(), mode, lot, price, 0, stoploss, 0.0, NULL, MAGIC));
}

int total_orders() {
   int   total_orders   =  0;
   ArrayInitialize(total_orders_array, 0);
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC) {
            total_orders++;
            total_orders_array[OrderType()]++;
         }
      }
   }
   return (total_orders);
}

void trail_order(int ticket) {
   double   stoploss;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      switch (OrderType()) {
         case OP_BUY:
            stoploss =  OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice());
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMin(stoploss, Bid - stop_level);
            if ((OrderStopLoss() < stoploss) && (OrderOpenPrice() < stoploss)) {
               OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
               Print("stoploss = " + stoploss);
            }
            break;
         case OP_SELL:
            stoploss =  OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMax(stoploss, Ask + stop_level);
            if ((stoploss < OrderStopLoss()) && (stoploss < OrderOpenPrice())) {
               OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
               Print("stoploss = " + stoploss);
            }
            break;
      }
   }
}