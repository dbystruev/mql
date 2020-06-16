extern   int      days_wait      =  40;
extern   int      initial_delta  =  10;
extern   double   minimum_move   =  0.001;
extern   double   maximum_move   =  0.010;
extern   double   mult_factor    =  1.4;

//+------------------------------------------------------------------+
//|                                           Bystruev2009_07_27.mq4 |
//|         Copyright © 2009, Denis Bystruev, 24 June - 27 July 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 24 June - 27 July 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   320090728
#define  ZERO           0.00001

int      bet_count;
double   day_open_price;
double   initial_lot;
bool     trade_allowed;
int      win_count;

void close_all_orders() {
   while (total_orders() > 0) {
      for (int i = OrdersTotal() - 1; i >= 0; i--) {
         if (OrderSelect(i, SELECT_BY_POS)) {
            if (OrderMagicNumber() == MAGIC_NUMBER) {
               switch (OrderType()) {
                  case OP_BUY:
                     OrderClose(OrderTicket(), OrderLots(), Point * MathRound(Bid / Point), 1);
                     break;
                  case OP_SELL:
                     OrderClose(OrderTicket(), OrderLots(), Point * MathRound(Ask / Point), 1);
                     break;
                  case OP_BUYLIMIT:
                  case OP_BUYSTOP:
                  case OP_SELLLIMIT:
                  case OP_SELLSTOP:
                     OrderDelete(OrderTicket());
                     break;
      }  }  }  }
      if (total_orders() > 0) Sleep(5000);
}  }

int find_min_order(int order_type_1 = -1, int order_type_2 = -1) {
   int find_order = -1;
   double min_lots = MarketInfo(Symbol(), MODE_MAXLOT);
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if ((order_type_1 == -1) || (OrderType() == order_type_1) || (OrderType() == order_type_2)) {
               if ((find_order < 0) || (OrderLots() < min_lots)) {
                  find_order = OrderTicket();
                  min_lots = OrderLots();
   }  }  }  }  }
   return (find_order);
}

int get_bet() {
   return (bet_count);
}

int init() {
   bet_count = 1;
   day_open_price = iOpen(Symbol(), PERIOD_D1, 0);
   initial_lot = MarketInfo(Symbol(), MODE_MINLOT);
   trade_allowed = TRUE;
   win_count = 0;
}

void lose(int bet = 1) {
   win_count -= bet;
   bet_count = 1;
}

double min_max(double min, double x, double max) {
   return (MathMax(min, MathMin(max, x)));
}

double norm_lot(double lot) {
   lot = MarketInfo(Symbol(), MODE_LOTSTEP) * MathRound(lot / MarketInfo(Symbol(), MODE_LOTSTEP));
   return (min_max(MarketInfo(Symbol(), MODE_MINLOT), lot, MarketInfo(Symbol(), MODE_MAXLOT)));
}

void print_message(string message) {
   static string old_message = "";
   if (message != old_message) Print(message);
   old_message = message;   
}

void send_order(int order_type, int take_profit, double lot = 0.0) {
   double price, takeprofit;
   lot = norm_lot(lot);
   switch (order_type) {
      case OP_BUY:
         price = Ask;
         takeprofit = price + Point * take_profit;
         break;
      case OP_SELL:
         price = Bid;
         takeprofit = price - Point * take_profit;
         break;
   }
   if (OrderSend(Symbol(), order_type, lot, price, 0, 0.0, takeprofit, NULL, MAGIC_NUMBER) >= 0) {
      update_takeprofit(order_type, takeprofit);
}  }

int sign(int x) {
   if (x < 0) return (-1);
   if (0 < x) return (1);
   return (0);
}

int start() {
   bool same_period = FALSE;
   for (int i = 0; i < days_wait; i++) {
      if (MathAbs(day_open_price - iOpen(Symbol(), PERIOD_D1, i)) < ZERO) same_period = TRUE;
   }
   if (!trade_allowed && same_period) return;
   trade_allowed = TRUE;
   day_open_price = iOpen(Symbol(), PERIOD_D1, 0);
   double max_delta = maximum_move * (Ask + Bid) / 2.0;
   double min_delta = minimum_move * (Ask + Bid) / 2.0;
   int total_buy_orders = total_orders(OP_BUY);
   int total_sell_orders = total_orders(OP_SELL);
   int total_orders = total_buy_orders + total_sell_orders;
   int buy_sign = sign(total_buy_orders);
   int sell_sign = sign(total_sell_orders);
   if ((Ask < day_open_price - max_delta) || (day_open_price + max_delta < Bid)) {
      close_all_orders();
      trade_allowed = FALSE;
      return;
   }
   if (total_buy_orders * total_sell_orders != 0) return;
   switch (total_orders) {
      case 0:
         if (Ask < day_open_price - min_delta) {
            send_order(OP_BUY, initial_delta / mult_factor);
         } else if (day_open_price + min_delta < Bid) {
            send_order(OP_SELL, initial_delta / mult_factor);
         }
         break;
      default:
         int min_order = find_min_order(OP_BUY * buy_sign + OP_SELL * sell_sign);
         if (!OrderSelect(min_order, SELECT_BY_TICKET)) break;
         double open_price = OrderOpenPrice() + Point * initial_delta * (buy_sign - sell_sign);
         int mult = MathPow(mult_factor, total_orders + 1);
         int new_delta = mult * initial_delta;
         double new_lot = mult * initial_lot;
         double stop_loss = open_price + Point * new_delta * (sell_sign - buy_sign);
         print_message("day_open_price = " + DoubleToStr(day_open_price, Digits) + ", min_delta = " + DoubleToStr(min_delta, Digits) + ", max_delta = " + DoubleToStr(max_delta, Digits) + ", open_price = " + DoubleToStr(open_price, Digits) + ", stop_loss = " + DoubleToStr(stop_loss, Digits) + ", new_delta = " + DoubleToStr(new_delta, 0) + ", new_lot = " + DoubleToStr(new_lot, 2));
         if ((total_buy_orders > 0) && (stop_loss < Bid)) break;
         if ((total_sell_orders > 0) && (Ask < stop_loss)) break;
         send_order(OP_BUY * buy_sign + OP_SELL * sell_sign, new_delta / mult_factor, new_lot);
         break;
   }
}

int total_orders(int order_type_1 = -1, int order_type_2 = -1) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if ((order_type_1 == -1) || (order_type_1 == OrderType()) || (order_type_2 == OrderType())) total_orders++;
   }  }  }
   return (total_orders);
}

void update_takeprofit(int order_type, double takeprofit) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderType() == order_type) {
               if (MathAbs(OrderTakeProfit() - takeprofit) > ZERO) {
                  OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), takeprofit, OrderExpiration());
}  }  }  }  }  }

void win(int bet = 1) {
   win_count += bet;
   bet_count += 1;
}