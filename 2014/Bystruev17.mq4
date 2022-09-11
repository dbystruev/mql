//+------------------------------------------------------------------+
//|                                                   Bystruev17.mq4 |
//|                 Copyright © 2009, Denis Bystruev, 12-16 Mar 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 12-16 Mar 2009"
#property link      "http://www.moeradio.ru"

//---- input parameters
extern   int      order_delta    =  50;   // difference between buy and sell orders
extern   double   trailing_level =  0.5;  // trail at 50%
extern   int      trade_period   =  600;  // how often to trade in seconds

datetime          last_trade;             // time of the last trade
double            lot;                    // current lot size
double            spread;                 // spread between Ask and Bid

void adjust_order(int ticket) {
   double   price;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
   switch (OrderType()) {
         case OP_BUYLIMIT:
            price    =  (Ask + Bid) / 2 - Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMin(price, Bid - spread);
            if (OrderModify(ticket, price, price - Point * order_delta, 0.0, 0)) {
               last_trade = TimeCurrent();
            }
            break;
         case OP_SELLLIMIT:
            price    =  (Ask + Bid) / 2 + Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMax(price, Ask + spread);
            if (OrderModify(ticket, price, price + Point * order_delta, 0.0, 0)) {
               last_trade = TimeCurrent();
            }
            break;
         case OP_BUYSTOP:
            price    =  (Ask + Bid) / 2 + Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMax(price, Ask + spread);
            if (OrderModify(ticket, price, price - Point * order_delta, 0.0, 0)) {
               last_trade = TimeCurrent();
            }
            break;
         case OP_SELLSTOP:
            price    =  (Ask + Bid) / 2 - Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMin(price, Bid - spread);
            if (OrderModify(ticket, price, price + Point * order_delta, 0.0, 0)) {
               last_trade = TimeCurrent();
            }
            break;
      }
   }
}

void adjust_orders(int order_type1, int order_type2) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            adjust_order(OrderTicket());
         }
      }
   }
}

void delete_orders(int order_type1, int order_type2) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            OrderDelete(OrderTicket());
         }
      }
   }
}

int init() {
   last_trade  =  0;
   spread      =  Point * MarketInfo(Symbol(), MODE_SPREAD);
   set_lot_size();
}

void send_order(int type) {
   double   price;
   switch (type) {
      case OP_BUYLIMIT:
         price    =  (Ask + Bid) / 2 - Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMin(price, Bid - spread);
         if (OrderSend(Symbol(), type, lot, price, 0, price - Point * order_delta, 0.0) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_SELLLIMIT:
         price    =  (Ask + Bid) / 2 + Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMax(price, Ask + spread);
         if (OrderSend(Symbol(), type, lot, price, 0, price + Point * order_delta, 0.0) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_BUYSTOP:
         price    =  (Ask + Bid) / 2 + Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMax(price, Ask + spread);
         if (OrderSend(Symbol(), type, lot, price, 0, price - Point * order_delta, 0.0) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_SELLSTOP:
         price    =  (Ask + Bid) / 2 - Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMin(price, Bid - spread);
         if (OrderSend(Symbol(), type, lot, price, 0, price + Point * order_delta, 0.0) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
   }
}

void send_orders(int type1, int type2) {
   send_order(type1);
   send_order(type2);
}

void set_lot_size() {
   double   lot_step =  MarketInfo(Symbol(), MODE_LOTSTEP);
   lot   =  AccountEquity() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / 10.0;
   lot   =  lot_step * MathRound(lot / lot_step);
   lot   =  MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot   =  MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
}

int start() {
   switch (total_orders(OP_BUYLIMIT, OP_SELLLIMIT)) {
      case 0:
         switch (total_orders(OP_BUY, OP_SELL)) {
            case 0:
               set_lot_size();
               send_orders(OP_BUYLIMIT, OP_SELLLIMIT);
               break;
            case 1:
            case 2:
               trail_orders(OP_BUY, OP_SELL);
               break;
         }
         break;
      case 1:
         delete_orders(OP_BUYLIMIT, OP_SELLLIMIT);
         break;
      case 2:
         if (TimeCurrent() < last_trade + trade_period) {
            return;
         }
         adjust_orders(OP_BUYLIMIT, OP_SELLLIMIT);
         break;
   }
}

int total_orders(int order_type1, int order_type2) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            total_orders++;
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
            stoploss =  MathMin(stoploss, Bid - spread);
            if ((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss)) {
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            break;
         case OP_SELL:
            stoploss =  OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMax(stoploss, Ask + spread);
            if ((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss())) {
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            break;
      }
   }
}

void trail_orders(int order_type1, int order_type2) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            trail_order(OrderTicket());
         }
      }
   }
}