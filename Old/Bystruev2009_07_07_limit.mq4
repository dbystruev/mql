extern   double   delta_add   =  0.0;
extern   double   delta_mult  =  1.5;
extern   double   lot_add     =  0.0;
extern   double   lot_mult    =  1.5;

//+------------------------------------------------------------------+
//|                                           Bystruev2009_07_07.mq4 |
//|          Copyright © 2009, Denis Bystruev, 24 June - 9 July 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 24 June - 9 July 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   320090709

double   base_price;
double   delta;
int      last_order_type;
double   last_order_price;
double   lot;

void delete_orders(int order_type_1 = -1, int order_type_2 = -1) {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if ((order_type_1 == -1) || (order_type_1 == OrderType()) || (order_type_2 == OrderType())) {
               OrderDelete(OrderTicket());
   }  }  }  }
}

int find_order(int order_type_1 = -1, int order_type_2 = -1) {
   int find_order = -1;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if ((order_type_1 == -1) || (OrderType() == order_type_1) || (OrderType() == order_type_2)) {
               find_order = OrderTicket();
               break;
   }  }  }  }
   return (find_order);
}

int init() {
   delta = next_delta(0);
   last_order_type = -1;
}

double min_max(double min, double x, double max) {
   return (MathMax(min, MathMin(max, x)));
}

int next_delta(int delta) {
   return (norm_delta(delta_mult * delta + delta_add));
}

double next_lot(double lot) {
   return (norm_lot(lot_mult * lot + lot_add * MarketInfo(Symbol(), MODE_LOTSTEP)));
}

int norm_delta(double delta) {
   return (MathMax(MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD) + 1, MathRound(delta)));
}

double norm_lot(double lot) {
   lot = MarketInfo(Symbol(), MODE_LOTSTEP) * MathRound(lot / MarketInfo(Symbol(), MODE_LOTSTEP));
   return (min_max(MarketInfo(Symbol(), MODE_MINLOT), lot, MarketInfo(Symbol(), MODE_MAXLOT)));
}

int prev_delta(int delta) {
   return (next_delta(0));
}

double prev_lot(double lot = 0.0) {
   lot = AccountBalance() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / 100.0;
   return (norm_lot(lot));
}

void send_order(int order_type) {
   double price, stoploss, takeprofit;
   switch (order_type) {
      case OP_BUYLIMIT:
         price = base_price - delta * Point;
         stoploss = price - delta * Point;
         takeprofit = price + delta * Point;
         break;
      case OP_BUYSTOP:
         price = base_price + delta * Point;
         stoploss = price - delta * Point;
         takeprofit = price + delta * Point;
         break;
      case OP_SELLLIMIT:
         price = base_price + delta * Point;
         stoploss = price + delta * Point;
         takeprofit = price - delta * Point;
         break;
      case OP_SELLSTOP:
         price = base_price - delta * Point;
         stoploss = price + delta * Point;
         takeprofit = price - delta * Point;
         break;
   }
   OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER);
}

int start() {
   if (AccountEquity() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lot) return;
   switch (total_orders()) {
      case 0:
         switch (last_order_type) {
            case OP_BUY:
               if (Bid < last_order_price) {
                  delta = next_delta(delta);
                  lot = next_lot(lot);
               } else {
                  delta = prev_delta(delta);
                  lot = prev_lot(lot);
               }
               break;
            case OP_SELL:
               if (last_order_price < Ask) {
                  delta = next_delta(delta);
                  lot = next_lot(lot);
               } else {
                  delta = prev_delta(delta);
                  lot = prev_lot(lot);
               }
               break;
         }
         base_price = Point * MathRound((Ask + Bid) / 2 / Point);
         if (delta == next_delta(0)) {
            last_order_type = -1;
            lot = prev_lot();
         }
         Print("Price = " + DoubleToStr(base_price, Digits) + ", Delta = " + DoubleToStr(delta, 0) + ", Lot = " + DoubleToStr(lot, 2));
         send_order(OP_BUYLIMIT);
         send_order(OP_SELLLIMIT);
         break;
      case 1:
         if (total_orders(OP_BUY, OP_SELL) == 0) delete_orders(OP_BUYLIMIT, OP_SELLLIMIT);
         break;
      case 2:
         if (OrderSelect(find_order(OP_BUY, OP_SELL), SELECT_BY_TICKET)) {
            last_order_price = OrderOpenPrice();
            last_order_type = OrderType();
            delete_orders(OP_BUYLIMIT, OP_SELLLIMIT);
         }
         break;
}  }

int total_orders(int order_type_1 = -1, int order_type_2 = -1) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if ((order_type_1 == -1) || (order_type_1 == OrderType()) || (order_type_2 == OrderType())) total_orders++;
   }  }  }
   return (total_orders);
}