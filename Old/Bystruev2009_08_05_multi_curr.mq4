extern   double   lot_margin        =  0.01;
extern   int      period            =  7;
extern   string   symbol_1          =  "USDCHF";
extern   string   symbol_2          =  "GBPUSD";
extern   string   symbol_3          =  "EURUSD";
extern   string   symbol_4          =  "USDJPY";
extern   string   symbol_5          =  "AUDUSD";
extern   string   symbol_6          =  "USDCAD";
extern   string   symbol_7          =  "EURGBP";
extern   string   symbol_8          =  "EURCHF";
extern   string   symbol_9          =  "EURJPY";
extern   string   symbol_10         =  "GBPJPY";
extern   string   symbol_11         =  "GBPCHF";
extern   string   symbol_12         =  "EURAUD";
extern   string   symbol_13         =  "";
extern   string   symbol_14         =  "";
extern   string   symbol_15         =  "";
extern   string   symbol_16         =  "";
extern   string   symbol_17         =  "";
extern   string   symbol_18         =  "";
extern   string   symbol_19         =  "";
extern   string   symbol_20         =  "";
extern   int      trade_interval    =  60;
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

string   cur_symbol;
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
   return (norm_lot(lot_margin * AccountBalance() / MarketInfo(cur_symbol, MODE_MARGINREQUIRED)));
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
}  }

double min_max(double min, double x, double max) {
   return (MathMax(min, MathMin(max, x)));
}

double norm_lot(double lot) {
   lot = MarketInfo(cur_symbol, MODE_LOTSTEP) * MathRound(lot / MarketInfo(cur_symbol, MODE_LOTSTEP));
   return (min_max(MarketInfo(cur_symbol, MODE_MINLOT), lot, MarketInfo(cur_symbol, MODE_MAXLOT)));
}

double norm_price(double price) {
   if (cur_symbol == "GOLD") price = 0.1 * MathRound(price / 0.1);
   return (MarketInfo(cur_symbol, MODE_POINT) * MathRound(price / MarketInfo(cur_symbol, MODE_POINT)));
}

void print_message(string message) {
   static string old_message = "";
   if (message != old_message) Print(message);
   old_message = message;   
}

void process_orders(string symbol) {
   if (symbol == "") return;
   if (AccountEquity() < MarketInfo(symbol, MODE_MARGINREQUIRED) * MarketInfo(symbol, MODE_MINLOT)) return;
   double spread = MarketInfo(symbol, MODE_POINT) * MarketInfo(symbol, MODE_SPREAD);
   double current_high = iHigh(symbol, timeframe, 0) + spread;
   double current_low = iLow(symbol, timeframe, 0);
   double prev_high = iHigh(symbol, timeframe, 1) + spread;
   double prev_low = iLow(symbol, timeframe, 1);
   int digits = MarketInfo(symbol, MODE_DIGITS);
   print_message(symbol + ": spread = " + DoubleToStr(spread, digits) + ", current_high = " + DoubleToStr(current_high, digits) + ", current_low = " + DoubleToStr(current_low, digits) + ", prev_high = " + DoubleToStr(prev_high, digits) + ", prev_low = " + DoubleToStr(prev_low, digits));
   cur_symbol = symbol;
   if ((total_orders(OP_BUY, OP_BUYSTOP) < 1) && (current_high < prev_high)) send_order(OP_BUYSTOP, prev_high, (prev_high - prev_low) / 2.0);
   if ((total_orders(OP_SELL, OP_SELLSTOP) < 1) && (prev_low < current_low)) send_order(OP_SELLSTOP, prev_low, (prev_high - prev_low) / 2.0);
}

void send_order(int order_type, double price, double stoploss_delta) {
   double lot = get_lot();
   double stoplevel = MarketInfo(cur_symbol, MODE_POINT) * MarketInfo(cur_symbol, MODE_STOPLEVEL);
   price = norm_price(price);
   stoploss_delta = norm_price(MathMax(stoplevel, stoploss_delta));
   switch (order_type) {
      case OP_BUYSTOP:
         if (MarketInfo(cur_symbol, MODE_ASK) + stoplevel < price)
            OrderSend(cur_symbol, order_type, lot, price, 0, price - stoploss_delta, 0.0, NULL, MAGIC_NUMBER);
         break;
      case OP_SELLSTOP:
         if (price < MarketInfo(cur_symbol, MODE_BID) - stoplevel)
            OrderSend(cur_symbol, order_type, lot, price, 0, price + stoploss_delta, 0.0, NULL, MAGIC_NUMBER);
         break;
   }
   int digits = MarketInfo(cur_symbol, MODE_DIGITS);
   print_message(cur_symbol + ": lot = " + DoubleToStr(lot, digits) + ", price = " + DoubleToStr(price, digits) + ", stoploss_delta = " + DoubleToStr(stoploss_delta, digits));
}

int start() {
   static datetime last_run = 0;
   if (TimeCurrent() < trade_interval * MathRound((last_run + trade_interval) / trade_interval)) return;
   print_message("Running at " + TimeToStr(TimeCurrent()));
   last_run = TimeCurrent();
   delete_old_orders(timeframe * 60);
   process_orders(Symbol());
   process_orders(symbol_1);
   process_orders(symbol_2);
   process_orders(symbol_3);
   process_orders(symbol_4);
   process_orders(symbol_5);
   process_orders(symbol_6);
   process_orders(symbol_7);
   process_orders(symbol_8);
   process_orders(symbol_9);
   process_orders(symbol_10);
   process_orders(symbol_11);
   process_orders(symbol_12);
   process_orders(symbol_13);
   process_orders(symbol_14);
   process_orders(symbol_15);
   process_orders(symbol_16);
   process_orders(symbol_17);
   process_orders(symbol_18);
   process_orders(symbol_19);
   process_orders(symbol_20);
   trail_orders(OP_BUY, OP_SELL);
}

int total_orders(int order_type_1 = -1, int order_type_2 = -1) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderSymbol() == cur_symbol) {
               if ((order_type_1 == -1) || (order_type_1 == OrderType()) || (order_type_2 == OrderType())) total_orders++;
            }
   }  }  }
   return (total_orders);
}

void trail_order(int ticket) {
   double stoplevel = MarketInfo(cur_symbol, MODE_POINT) * MarketInfo(cur_symbol, MODE_STOPLEVEL);
   double stoploss;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      switch (OrderType()) {
         case OP_BUY:
            stoploss = norm_price(OrderOpenPrice() + trailing_level * (MarketInfo(cur_symbol, MODE_BID) - OrderOpenPrice()));
            stoploss = MathMin(stoploss, MarketInfo(cur_symbol, MODE_BID) - stoplevel);
            if ((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss)) OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            break;
         case OP_SELL:
            stoploss = norm_price(OrderOpenPrice() - trailing_level * (OrderOpenPrice() - MarketInfo(cur_symbol, MODE_ASK)));
            stoploss = MathMax(stoploss, MarketInfo(cur_symbol, MODE_ASK) + stoplevel);
            if ((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss())) OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            break;
}  }  }

void trail_orders(int order_type_1, int order_type_2) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if ((OrderType() == order_type_1) || (OrderType() == order_type_2)) {
               trail_order(OrderTicket());
}  }  }  }  }