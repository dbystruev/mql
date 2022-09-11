//+------------------------------------------------------------------+
//|                                          Bystruev.2009.04.06.mq4 |
//|            Copyright © 2009, Denis Bystruev, 12 Mar - 6 Apr 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 12 Mar - 6 Apr 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_LIMIT    20001013
#define  MAGIC_STOP     19730503
#define  ZERO           0.00001

//---- input parameters
extern   int      order_delta_limit =  10;   // difference between buy and sell for limit orders
extern   int      order_delta_stop  =  50;   // difference between buy and sell for stop orders
extern   double   trailing_level    =  0.5;  // trail at 50%
extern   int      trade_period      =  90;   // how often to trade in seconds

datetime          last_trade;                // time of the last trade
double            lot;                       // current lot size
double            spread;                    // spread between Ask and Bid
double            trail_delta;               // trail delta in case trail is successful

bool adjust_order(int ticket, bool adjust_one_way = FALSE) {
   bool     adjust_order = FALSE;
   double   price;
   double   takeprofit;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
   switch (OrderType()) {
         case OP_BUY:
            if (OrderTakeProfit() < ZERO) {
               takeprofit = OrderOpenPrice();
            } else {
               takeprofit = OrderTakeProfit();
            }
            takeprofit -= trail_delta;
            if (Ask + spread < takeprofit) {
               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), takeprofit, 0)) {
                  adjust_order = TRUE;
                  last_trade = TimeCurrent();
               }
            }
            break;
         case OP_BUYSTOP:
            price    =  (Ask + Bid) / 2 + Point * order_delta_stop / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMax(price, Ask + spread);
            if ((!adjust_one_way) || (price < OrderOpenPrice())) {
               if (OrderModify(ticket, price, OrderStopLoss(), OrderTakeProfit(), 0)) {
                  adjust_order = TRUE;
                  last_trade = TimeCurrent();
               }
            }
            break;
         case OP_SELL:
            if (OrderTakeProfit() < ZERO) {
               takeprofit = OrderOpenPrice();
            } else {
               takeprofit = OrderTakeProfit();
            }
            takeprofit += trail_delta;
            if (takeprofit < Bid - spread) {
               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), takeprofit, 0)) {
                  adjust_order = TRUE;
                  last_trade = TimeCurrent();
               }
            }
            break;
         case OP_SELLSTOP:
            price    =  (Ask + Bid) / 2 - Point * order_delta_stop / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMin(price, Bid - spread);
            if ((!adjust_one_way) || (OrderOpenPrice() < price)) {
               if (OrderModify(ticket, price, OrderStopLoss(), OrderTakeProfit(), 0)) {
                  adjust_order = TRUE;
                  last_trade = TimeCurrent();
               }
            }
            break;
      }
   }
   return (adjust_order);
}

bool adjust_orders(int order_type1, int order_type2, bool adjust_one_way = FALSE) {
   bool  adjust_orders  =  FALSE;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            adjust_orders = (adjust_orders || adjust_order(OrderTicket(), adjust_one_way));
         }
      }
   }
   return (adjust_orders);
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
   trail_delta = 0.0;
}

void send_order(int type, int magic) {
   double   price;
   switch (type) {
      case OP_BUYLIMIT:
         price    =  (Ask + Bid) / 2 - Point * order_delta_limit / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMin(price, Bid - spread);
         if (OrderSend(Symbol(), type, lot, price, 0, 0.0, 0.0, NULL, magic) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_BUYSTOP:
         price    =  (Ask + Bid) / 2 + Point * order_delta_stop / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMax(price, Ask + spread);
         if (OrderSend(Symbol(), type, lot, price, 0, 0.0, 0.0, NULL, magic) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_SELLLIMIT:
         price    =  (Ask + Bid) / 2 + Point * order_delta_limit / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMax(price, Ask + spread);
         if (OrderSend(Symbol(), type, lot, price, 0, 0.0, 0.0, NULL, magic) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_SELLSTOP:
         price    =  (Ask + Bid) / 2 - Point * order_delta_stop / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMin(price, Bid - spread);
         if (OrderSend(Symbol(), type, lot, price, 0, 0.0, 0.0, NULL, magic) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
   }
}

void send_orders(int type1, int type2, int magic) {
   send_order(type1, magic);
   send_order(type2, magic);
}

void set_lot_size() {
   double   lot_step =  MarketInfo(Symbol(), MODE_LOTSTEP);
   lot   =  AccountEquity() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / 10.0;
   lot   =  lot_step * MathRound(lot / lot_step);
   lot   =  MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot   =  MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
}

int start() {
   if (AccountBalance() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT)) {
      return;
   }
   switch (total_orders(OP_BUYSTOP, OP_SELLSTOP)) {
      case 0:
         switch (total_orders(OP_BUY, OP_SELL, MAGIC_STOP)) {
            case 0:
               set_lot_size();
               trail_delta = 0.0;
               send_orders(OP_BUYSTOP, OP_SELLSTOP, MAGIC_STOP);
               break;
            case 1:
               if (!trail_orders(OP_BUY, OP_SELL)) {
                  if (total_order(OP_BUY, MAGIC_STOP) == 0) {
                     send_order(OP_BUYSTOP, MAGIC_STOP);
                  } else {
                     send_order(OP_SELLSTOP, MAGIC_STOP);
                  }
               }
               break;
            case 2:
               if (trail_orders(OP_BUY, OP_SELL)) {
                  if (adjust_orders(OP_BUY, OP_SELL)) {
                     trail_delta = 0.0;
                  }
               }
               break;
         }
         break;
      case 1:
         switch (total_orders(OP_BUY, OP_SELL, MAGIC_STOP)) {
            case 0:
               delete_orders(OP_BUYSTOP, OP_SELLSTOP);
               break;
            case 1:
               if (trail_orders(OP_BUY, OP_SELL)) {
                  delete_orders(OP_BUYSTOP, OP_SELLSTOP);
               } else {
                  adjust_orders(OP_BUYSTOP, OP_SELLSTOP, TRUE);
               }
               break;
            case 2:
               break;
         }
         break;
      case 2:
         if ((last_trade + trade_period < TimeCurrent()) && (total_orders(OP_BUY, OP_SELL) == 0)) {
            adjust_orders(OP_BUYSTOP, OP_SELLSTOP);
         }
         break;
   }
}

int total_order(int order_type, int magic = 0) {
   int total_order = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderType() == order_type) {
            if ((OrderMagicNumber() == magic) || (magic == 0)) {
               total_order++;
            }
         }
      }
   }
   return (total_order);
}

int total_orders(int order_type1, int order_type2, int magic = 0) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            if ((OrderMagicNumber() == magic) || (magic == 0)) {
               total_orders++;
            }
         }
      }
   }
   return (total_orders);
}

bool trail_order(int ticket) {
   double   prev_stoploss;
   double   stoploss;
   bool     trail_order = FALSE;
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
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0)) {
                  last_trade = TimeCurrent();
                  trail_delta = stoploss - prev_stoploss - trail_delta;
               }
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
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0)) {
                  last_trade = TimeCurrent();
                  trail_delta = prev_stoploss - stoploss - trail_delta;
               }
            }
            break;
      }
      if (OrderStopLoss() > ZERO) {
         trail_order = TRUE;
      }
   }
   return (trail_order);
}

bool trail_orders(int order_type1, int order_type2) {
   bool  trail_orders = FALSE;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            trail_orders = (trail_orders || trail_order(OrderTicket()));
         }
      }
   }
   return (trail_orders);
}