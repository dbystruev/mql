//+------------------------------------------------------------------+
//|                                   Bystruev_20090623_Roulette.mq4 |
//|                   Copyright © 2009, Denis Bystruev, 23 June 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 23-25 June 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC 305090623

extern   int   loss_lot_change   =  2;    // After a loss, increase lot by 2 steps
extern   int   delta_points      =  10;   // Delta between buy and sell orders and also take profit and stop loss limits
extern   int   win_lot_change    =  -1;   // After a win, decrease lot by 1 step

double   start_lot;  // Initial lot to start with

int init() {
   start_lot = MarketInfo(Symbol(), MODE_MINLOT);
}

// returns true if we can not continue because of no money
bool is_lost() {
   return (AccountBalance() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT));
}

// sends an order depending on order type, return is the same as in standard OrderSend function
int send_order(int order_type, double lot, double price) {
   double stop_loss, take_profit;
   price = NormalizeDouble(price, Digits);
   switch (order_type) {
      case OP_BUYLIMIT:
      case OP_BUYSTOP:
         stop_loss = price - Point * delta_points;
         take_profit = price + Point * delta_points;
         break;
      case OP_SELLLIMIT:
      case OP_SELLSTOP:
         stop_loss = price + Point * delta_points;
         take_profit = price - Point * delta_points;
         break;
   }
   return (OrderSend(Symbol(), order_type, lot, price, 0, stop_loss, take_profit, NULL, MAGIC));
}

int start() {
   while(!is_lost()) {
      switch (total_orders()) {
         case 0:
            send_order(OP_BUYLIMIT, start_lot, (Ask + Bid) / 2.0 - Point * delta_points / 2.0);
            send_order(OP_SELLLIMIT, start_lot, (Ask + Bid) / 2.0 + Point * delta_points / 2.0);
            break;
         case 1:
            break;
         case 2:
            break;
         case 3:
            break;
      }
   }
}

// returns the total number of orders of given type with magic number
int total_orders(int order_type_1 = -1, int order_type_2 = -1) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC) {
            if ((order_type_1 == -1) || (OrderType() == order_type_1) || (OrderType() == order_type_2)) {
               total_orders++;
            }
         }
      }
   }
   return (total_orders);
}

