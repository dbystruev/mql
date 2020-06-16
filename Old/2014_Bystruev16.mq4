//+------------------------------------------------------------------+

//|                                                   Bystruev16.mq4 |

//|                    Copyright ? 2009, Denis Bystruev, 12 Mar 2009 |

//|                                           http://www.moeradio.ru |

//+------------------------------------------------------------------+

#property copyright "Copyright ? 2009, Denis Bystruev, 12 Mar 2009"

#property link      "http://www.moeradio.ru"



#define  LIMIT_MAGIC 1

#define  STOP_MAGIC  2



//---- input parameters

extern   int      limit_delta    =  1000; // difference between buy limit and sell limit orders

extern   int      stop_delta     =  500;   // difference between buy stop and sell stop orders

extern   int      stop_loss      =  500;   // initial stop loss level

extern   int      return_level   =  1000; // when to set take profit equal to buy price

extern   double   trailing_level =  0.5;  // trail at 50%

extern   int      trade_period   =  90;   // how often to trade in seconds



datetime          last_trade;             // time of the last trade

double            lot;                    // current lot size

double            spread;                 // spread between Ask and Bid



void adjust_order(int ticket) {

   double   price;

   if (OrderSelect(ticket, SELECT_BY_TICKET)) {

   switch (OrderType()) {

         case OP_BUYLIMIT:

            price    =  (Ask + Bid) / 2 - Point * limit_delta / 2;

            price    =  Point * MathRound(price / Point);

            price    =  MathMin(price, Bid - spread);

            if (OrderModify(ticket, price, price - Point * stop_loss, 0.0, 0)) {

               last_trade = TimeCurrent();

            }

            break;

         case OP_BUYSTOP:

            price    =  (Ask + Bid) / 2 + Point * stop_delta / 2;

            price    =  Point * MathRound(price / Point);

            price    =  MathMax(price, Ask + spread);

            OrderModify(ticket, price, price - Point * stop_loss, 0.0, 0);

            break;

         case OP_SELLLIMIT:

            price    =  (Ask + Bid) / 2 + Point * limit_delta / 2;

            price    =  Point * MathRound(price / Point);

            price    =  MathMax(price, Ask + spread);

            if (OrderModify(ticket, price, price + Point * stop_loss, 0.0, 0)) {

               last_trade = TimeCurrent();

            }

            break;

         case OP_SELLSTOP:

            price    =  (Ask + Bid) / 2 - Point * stop_delta / 2;

            price    =  Point * MathRound(price / Point);

            price    =  MathMin(price, Bid - spread);

            OrderModify(ticket, price, price + Point * stop_loss, 0.0, 0);

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

         price    =  (Ask + Bid) / 2 - Point * limit_delta / 2;

         price    =  Point * MathRound(price / Point);

         price    =  MathMin(price, Bid - spread);

         if (OrderSend(Symbol(), type, lot, price, 0, price - Point * stop_loss, 0.0, NULL, LIMIT_MAGIC) >= 0) {

            last_trade = TimeCurrent();

         }

         break;

      case OP_BUYSTOP:

         price    =  (Ask + Bid) / 2 + Point * stop_delta / 2;

         price    =  Point * MathRound(price / Point);

         price    =  MathMax(price, Ask + spread);

         if (OrderSend(Symbol(), type, 2.0 * lot, price, 0, price - Point * stop_loss, 0.0, NULL, STOP_MAGIC) >= 0) {

            last_trade = TimeCurrent();

         }

         break;

      case OP_SELLLIMIT:

         price    =  (Ask + Bid) / 2 + Point * limit_delta / 2;

         price    =  Point * MathRound(price / Point);

         price    =  MathMax(price, Ask + spread);

         if (OrderSend(Symbol(), type, lot, price, 0, price + Point * stop_loss, 0.0, NULL, LIMIT_MAGIC) >= 0) {

            last_trade = TimeCurrent();

         }

         break;

      case OP_SELLSTOP:

         price    =  (Ask + Bid) / 2 - Point * stop_delta / 2;

         price    =  Point * MathRound(price / Point);

         price    =  MathMin(price, Bid - spread);

         if (OrderSend(Symbol(), type, 2.0 * lot, price, 0, price + Point * stop_loss, 0.0, NULL, STOP_MAGIC) >= 0) {

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

   lot   =  AccountEquity() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / 20.0;

   lot   =  lot_step * MathRound(lot / lot_step);

   lot   =  MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));

   lot   =  MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT) / 2.0);

}



int start() {

   if (AccountBalance() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT)) return;

   switch (total_orders(OP_BUYSTOP, OP_SELLSTOP)) {

      case 0:

         switch (total_orders(OP_BUY, OP_SELL, STOP_MAGIC)) {

            case 0:

               set_lot_size();

               send_orders(OP_BUYSTOP, OP_SELLSTOP);

               break;

            case 1:

            case 2:

               if (total_orders(OP_BUY, OP_SELL, LIMIT_MAGIC) == 0) {

                  trail_orders(OP_BUY, OP_SELL, STOP_MAGIC);

               }

               break;

         }

         break;

      case 1:

         delete_orders(OP_BUYSTOP, OP_SELLSTOP);

         break;

      case 2:

         if ((TimeCurrent() > last_trade + trade_period) && (total_orders(OP_BUY, OP_SELL, LIMIT_MAGIC) == 0)) {

            adjust_orders(OP_BUYSTOP, OP_SELLSTOP);

         }

         break;

   }

   switch (total_orders(OP_BUYLIMIT, OP_SELLLIMIT)) {

      case 0:

         switch (total_orders(OP_BUY, OP_SELL, LIMIT_MAGIC)) {

            case 0:

               send_orders(OP_BUYLIMIT, OP_SELLLIMIT);

               break;

            case 1:

            case 2:

               trail_orders(OP_BUY, OP_SELL, LIMIT_MAGIC);

               break;

         }

         break;

      case 1:

         delete_orders(OP_BUYLIMIT, OP_SELLLIMIT);

         break;

      case 2:

         if (TimeCurrent() > last_trade + trade_period) {

            adjust_orders(OP_BUYLIMIT, OP_SELLLIMIT);

         }

         break;

   }

}



int total_orders(int order_type1, int order_type2, int magic = 0) {

   int total_orders = 0;

   for (int i = 0; i < OrdersTotal(); i++) {

      if (OrderSelect(i, SELECT_BY_POS)) {

         if (((OrderType() == order_type1) || (OrderType() == order_type2)) && ((magic == 0) || (OrderMagicNumber() == magic))) {

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

            if (Bid + Point * return_level < OrderOpenPrice()) {

               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice(), 0)) {

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

            if (OrderOpenPrice() + Point * return_level < Ask) {

               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice(), 0)) {

                  last_trade = TimeCurrent();

               }

            }

            break;

      }

   }

}



void trail_orders(int order_type1, int order_type2, int magic) {

   for (int i = 0; i < OrdersTotal(); i++) {

      if (OrderSelect(i, SELECT_BY_POS)) {

         if (((OrderType() == order_type1) || (OrderType() == order_type2)) && (OrderMagicNumber() == magic)) {

            trail_order(OrderTicket());

         }

      }

   }

}