//+------------------------------------------------------------------+
//|                                         2014_Bystruev16_stop.mq4 |
//|Copyright © 2009 - 2014, Denis Bystruev, 12 Mar 2009 - 1 Jul 2014 |
//|                                                 dbystruev@me.com |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009 - 2014, Denis Bystruev, 12 Mar 2009 - 1 Jul 2014"
#property link      "mailto:dbystruev@me.com"

//---- input parameters
extern   double   order_delta    =  0.0025;  // difference between buy and sell orders
extern   double   stop_loss      = 0.00025;  // initial stop loss level
extern   double   risk_level     =    0.05;  // how much of AccountEquity() we can loose in one wrong stop loss
extern   double   trailing_level =     0.5;  // trail at 50%
extern   int      trade_period   =      10;  // how often to trade in seconds

datetime          last_trade;                // time of the last trade
double            lot;                       // current lot size
double            stop_level;                // minimum stop level from current price
double            tick_size;                 // minimum tick size in points

void adjust_order(int ticket) {
   double   price;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
   switch (OrderType()) {
         case OP_BUYSTOP:
            price    =  (Ask + Bid) / 2.0 + order_delta / 2.0;
            price    =  Point * MathRound(price / Point);
            price    =  MathMax(price, Ask + stop_level);
            if (OrderModify(ticket, price, price - stop_loss, 0.0, 0)) {
               last_trade = TimeCurrent();
            }
            break;
         case OP_SELLSTOP:
            price    =  (Ask + Bid) / 2.0 - order_delta / 2.0;
            price    =  Point * MathRound(price / Point);
            price    =  MathMin(price, Bid - stop_level);
            if (OrderModify(ticket, price, price + stop_loss, 0.0, 0)) {
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
   last_trade = 0;
   tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
   set_lot_size();
}

void send_order(int type) {
   double   price;
   switch (type) {
      case OP_BUYSTOP:
         price    =  (Ask + Bid) / 2.0 + order_delta / 2.0;
         price    =  Point * MathRound(price / Point);
         price    =  MathMax(price, Ask + stop_level);
         if (OrderSend(Symbol(), type, lot, price, 0, price - stop_loss, 0.0) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_SELLSTOP:
         price    =  (Ask + Bid) / 2.0 - order_delta / 2.0;
         price    =  Point * MathRound(price / Point);
         price    =  MathMin(price, Bid - stop_level);
         if (OrderSend(Symbol(), type, lot, price, 0, price + stop_loss, 0.0) >= 0) {
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
   double lot_step =  MarketInfo(Symbol(), MODE_LOTSTEP);
   lot = risk_level * AccountEquity() / (MarketInfo(Symbol(), MODE_TICKVALUE) * stop_loss / tick_size);
   lot = lot_step * MathRound(lot / lot_step);
   lot = MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot = MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
}

int start() {
   stop_level = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   if (AccountBalance() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT)) return;
   switch (total_orders(OP_BUYSTOP, OP_SELLSTOP)) {
      case 0:
         switch (total_orders(OP_BUY, OP_SELL)) {
            case 0:
               set_lot_size();
               send_orders(OP_BUYSTOP, OP_SELLSTOP);
               break;
            case 1:
            case 2:
               trail_orders(OP_BUY, OP_SELL);
               break;
         }
         break;
      case 1:
         delete_orders(OP_BUYSTOP, OP_SELLSTOP);
         break;
      case 2:
         datetime next_trade_in = last_trade + trade_period - TimeCurrent();
         if (next_trade_in > 0) {
            Comment("Next trade is in " + TimeToStr(next_trade_in, TIME_SECONDS) + " hours:minutes:seconds");
            return;
         }
         adjust_orders(OP_BUYSTOP, OP_SELLSTOP);
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
            stoploss =  MathMax(OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice()), Bid - order_delta / 2.0);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMin(stoploss, Bid - stop_level);
            if ((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss)) {
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            if (Ask + stop_level < OrderOpenPrice()) {
               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice() + tick_size, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            break;
         case OP_SELL:
            stoploss =  MathMin(OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask), Ask + order_delta / 2.0);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMax(stoploss, Ask + stop_level);
            if ((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss())) {
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            if (OrderOpenPrice() < Bid - stop_level) {
               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice() - tick_size, 0)) {
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