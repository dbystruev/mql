extern   int      history_count     =  1;
extern   int      history_start     =  1;
extern   int      keep_order_time   =  31536000;
extern   double   lot_margin        =  0.1;
extern   double   max_loose         =  0.01;
extern   int      modify_wait       =  60;
extern   int      period            =  7;
extern   double   trailing_level    =  0.5;

//+------------------------------------------------------------------+
//|                                      Bystruev2009_07_29_bars.mq4 |
//|         Copyright © 2009, Denis Bystruev, 24 June - 29 July 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 24 June - 29 July 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   320090731
#define  ZERO           0.00001

datetime buystop_modify_time, sellstop_modify_time;
int      timeframe;

int deinit() {
   delete_old_orders();
}

void delete_old_orders(int seconds_ago = 0) {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderOpenTime() + seconds_ago < TimeCurrent()) {
               switch (OrderType()) {
                  case OP_BUYLIMIT:
                  case OP_BUYSTOP:
                  case OP_SELLLIMIT:
                  case OP_SELLSTOP:
                     OrderDelete(OrderTicket());
}  }  }  }  }  }

double get_lot() {
   return (norm_lot(lot_margin * AccountBalance() / MarketInfo(Symbol(), MODE_MARGINREQUIRED)));
}

double highest(string symbol, int timeframe, int count, int start = 0) {
   double highest = iHigh(symbol, timeframe, start);
   for (int i = 1; i < count; i++) {
      highest = MathMax(highest, iHigh(symbol, timeframe, start + i));
   }
   return (highest);
}

int init() {
   switch (period) {
      case 1:
         timeframe = PERIOD_M1;
         break;
      case 2:
         timeframe = PERIOD_M5;
         break;
      case 3:
         timeframe = PERIOD_M15;
         break;
      case 4:
         timeframe = PERIOD_M30;
         break;
      case 5:
         timeframe = PERIOD_H1;
         break;
      case 6:
         timeframe = PERIOD_H4;
         break;
      case 7:
         timeframe = PERIOD_D1;
         break;
      case 8:
         timeframe = PERIOD_W1;
         break;
      case 9:
         timeframe = PERIOD_MN1;
         break;
   }
}

double lowest(string symbol, int timeframe, int count, int start = 0) {
   double lowest = iLow(symbol, timeframe, start);
   for (int i = 1; i < count; i++) {
      lowest = MathMin(lowest, iLow(symbol, timeframe, start + i));
   }
   return (lowest);
}

double min_max(double min, double x, double max) {
   return (MathMax(min, MathMin(max, x)));
}

double norm_lot(double lot) {
   lot = MarketInfo(Symbol(), MODE_LOTSTEP) * MathRound(lot / MarketInfo(Symbol(), MODE_LOTSTEP));
   return (min_max(MarketInfo(Symbol(), MODE_MINLOT), lot, MarketInfo(Symbol(), MODE_MAXLOT)));
}

double norm_price(double price) {
   if (Symbol() == "GOLD") price = 0.1 * MathRound(price / 0.1);
   return (Point * MathRound(price / Point));
}

void print_message(string message) {
   static string old_message = "";
   if (message != old_message) Print(message);
   old_message = message;   
}

void send_order(int order_type, double price, double stoploss) {
   double lot = get_lot();
   double stoplevel = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   price = norm_price(price);
   stoploss = MathMax(stoplevel, norm_price(MathMin(max_loose * (Ask + Bid) / 2.0, MathAbs(price - stoploss))));
   switch (order_type) {
      case OP_BUYSTOP:
         stoploss = price - stoploss;
         if (Ask + stoplevel < price) {
            if (OrderSend(Symbol(), order_type, lot, price, 0, stoploss, 0.0, NULL, MAGIC_NUMBER) > 0)
               buystop_modify_time = TimeCurrent();
         }
         break;
      case OP_SELLSTOP:
         stoploss = price + stoploss;
         if (price < Bid - stoplevel) {
            if (OrderSend(Symbol(), order_type, lot, price, 0, stoploss, 0.0, NULL, MAGIC_NUMBER) > 0)
               sellstop_modify_time = TimeCurrent();
         }
         break;
   }
   print_message(Symbol() + ": lot = " + DoubleToStr(lot, Digits) + ", price = " + DoubleToStr(price, Digits) + ", stoploss = " + DoubleToStr(stoploss, Digits));
}

int start() {
   if (AccountEquity() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT)) return;
   double current_high = iHigh(Symbol(), timeframe, 0);
   double current_low = iLow(Symbol(), timeframe, 0);
   double prev_high = highest(Symbol(), timeframe, history_count, history_start);
   double prev_low = lowest(Symbol(), timeframe, history_count, history_start);
   print_message(Symbol() + ": current_high = " + DoubleToStr(current_high, Digits) + ", current_low = " + DoubleToStr(current_low, Digits) + ", prev_high = " + DoubleToStr(prev_high, Digits) + ", prev_low = " + DoubleToStr(prev_low, Digits));
   delete_old_orders(timeframe * 60);
   if (total_orders(OP_BUYSTOP) > 0) update_orders(OP_BUYSTOP, prev_high, prev_low);
   if ((total_orders(OP_BUY, OP_BUYSTOP) < 1) && (current_high < prev_high)) send_order(OP_BUYSTOP, prev_high, prev_low);
   if (total_orders(OP_SELLSTOP) > 0) update_orders(OP_SELLSTOP, prev_low, prev_high);
   if ((total_orders(OP_SELL, OP_SELLSTOP) < 1) && (prev_low < current_low)) send_order(OP_SELLSTOP, prev_low, prev_high);
   trail_orders(OP_BUY, OP_SELL);
}

int total_orders(int order_type_1 = -1, int order_type_2 = -1) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderSymbol() == Symbol()) {
               if ((order_type_1 == -1) || (order_type_1 == OrderType()) || (order_type_2 == OrderType())) total_orders++;
            }
   }  }  }
   return (total_orders);
}

void trail_order(int ticket) {
   double stoplevel = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   double stoploss;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      switch (OrderType()) {
         case OP_BUY:
            stoploss = norm_price(OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice()));
            stoploss = MathMin(stoploss, Bid - stoplevel);
            if ((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss)) OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            if (OrderOpenTime() + keep_order_time < TimeCurrent()) OrderClose(ticket, OrderLots(), Bid, 1);
            break;
         case OP_SELL:
            stoploss = norm_price(OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask));
            stoploss = MathMax(stoploss, Ask + stoplevel);
            if ((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss())) OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            if (OrderOpenTime() + keep_order_time < TimeCurrent()) OrderClose(ticket, OrderLots(), Ask, 1);
            break;
}  }  }

void trail_orders(int order_type_1, int order_type_2) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderSymbol() == Symbol()) {
               if ((OrderType() == order_type_1) || (OrderType() == order_type_2)) {
                  trail_order(OrderTicket());
}  }  }  }  }  }

void update_order(int order_ticket, double price, double stoploss) {
   double stoplevel = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   price = norm_price(price);
   stoploss = MathMax(stoplevel, norm_price(MathMin(max_loose * (Ask + Bid) / 2.0, MathAbs(price - stoploss))));
   if (OrderSelect(order_ticket, SELECT_BY_TICKET)) {
      if (MathAbs(OrderOpenPrice() - price) > ZERO) {
         switch (OrderType()) {
            case OP_BUYSTOP:
               stoploss = price - stoploss;
               if ((Ask + stoplevel < price) && (buystop_modify_time + modify_wait < TimeCurrent())) {
                  if (OrderModify(order_ticket, price, stoploss, OrderTakeProfit(), OrderExpiration()))
                     buystop_modify_time = TimeCurrent();
               }
               break;
            case OP_SELLSTOP:
               stoploss = price + stoploss;
               if ((price < Bid - stoplevel) && (sellstop_modify_time + modify_wait < TimeCurrent())) {
                  if (OrderModify(order_ticket, price, stoploss, OrderTakeProfit(), OrderExpiration()))
                     sellstop_modify_time = TimeCurrent();
               }
               break;
}  }  }  }

void update_orders(int order_type, double price, double stoploss) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderSymbol() == Symbol()) {
               if (OrderType() == order_type) {
                  update_order(OrderTicket(), price, stoploss);
}  }  }  }  }  }