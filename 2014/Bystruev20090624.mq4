extern   int      half_delta  =  25;
extern   double   lose_ratio  =  0.5;

//+------------------------------------------------------------------+
//|                                             Bystruev20090624.mq4 |
//|                Copyright © 2009, Denis Bystruev, 24-29 June 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 24 June - 2 July 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   84375903
#define  ZERO           0.000001

double   account_equity;
double   lot_balance;
double   lot_prev;
int      lot_ticket;
double   spread;

void check_lot() {
   int ticket = find_order(OP_BUY, OP_SELL);
   if (ticket != lot_ticket) {
      if (OrderSelect(ticket, SELECT_BY_TICKET)) {
         if ((OrderLots() < lot_prev) || equal(OrderLots(), lot_prev)) {
            lot_balance -= lot_prev;
         } else {
            lot_balance += lot_prev;
         }
         lot_prev = OrderLots();
         lot_ticket = ticket;
      }
      if (lot_balance < -ZERO) {
         close_all_orders();
         init();
      }
   }
}

bool check_order(int ticket, int market_ticket) {
   bool check_order = FALSE;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      int order_type = OrderType();
      double order_lot = OrderLots();
      double order_price = OrderOpenPrice();
      double order_stoploss = OrderStopLoss();
      double order_takeprofit = OrderTakeProfit();
      if (OrderSelect(market_ticket, SELECT_BY_TICKET)) {
         double market_lot = OrderLots();
         double market_stoploss = OrderStopLoss();
         double market_takeprofit = OrderTakeProfit();
         switch (OrderType()) {
            case OP_BUY:
               if (!equal(order_stoploss, order_price - 2 * half_delta * Point)) break;
               if (!equal(order_takeprofit, order_price + 2 * half_delta * Point)) break;
               switch (order_type) {
                  case OP_BUYLIMIT:
                     if (!equal(order_lot, next_lot(market_lot))) break;
                     if (!equal(order_price, market_stoploss + spread)) break;
                     check_order = TRUE;
                     break;
                  case OP_BUYSTOP:
                     if (!equal(order_lot, prev_lot(market_lot))) break;
                     if (!equal(order_price, market_takeprofit - spread)) break;
                     check_order = TRUE;
                     break;
               }
               break;
            case OP_SELL:
               if (!equal(order_stoploss, order_price + 2 * half_delta * Point)) break;
               if (!equal(order_takeprofit, order_price - 2 * half_delta * Point)) break;
               switch (order_type) {
                  case OP_SELLLIMIT:
                     if (!equal(order_lot, next_lot(market_lot))) break;
                     if (!equal(order_price, market_stoploss - spread)) break;
                     check_order = TRUE;
                     break;
                  case OP_SELLSTOP:
                     if (!equal(order_lot, prev_lot(market_lot))) break;
                     if (!equal(order_price, market_takeprofit + spread)) break;
                     check_order = TRUE;
                     break;
               }
               break;
         }
      }
   }
   return (check_order);
}

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
               }
            }
         }
      }
      if (total_orders() > 0)
         Sleep(5000);
   }
}

bool equal(double a, double b) {
   return (MathAbs(a - b) < ZERO);
}

int find_order(int order_type_1 = -1, int order_type_2 = -1) {
   int find_order = -1;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if ((order_type_1 == -1) || (OrderType() == order_type_1) || (OrderType() == order_type_2)) {
               find_order = OrderTicket();
               break;
            }
         }
      }
   }
   return (find_order);
}

int init() {
   account_equity = AccountEquity();
   lot_balance = 0.0;
   lot_prev = 0.0;
   lot_ticket = -1;
   spread = Ask - Bid;
}

double next_lot(double lot) {
   double next_lot = MarketInfo(Symbol(), MODE_MINLOT);
   if (!equal(lot, 0.0)) {
//      next_lot = lot;
//      next_lot = lot + 2 * MarketInfo(Symbol(), MODE_LOTSTEP);
      next_lot = 2 * lot + MarketInfo(Symbol(), MODE_LOTSTEP);
      next_lot = MathMax(next_lot, MarketInfo(Symbol(), MODE_MINLOT));
      next_lot = MathMin(next_lot, MarketInfo(Symbol(), MODE_MAXLOT));
   }
   return (next_lot);
}

double prev_lot(double lot) {
   double prev_lot = lot - MarketInfo(Symbol(), MODE_LOTSTEP);
//   double prev_lot = 2 * lot;
   prev_lot = MathMax(prev_lot, MarketInfo(Symbol(), MODE_MINLOT));
   prev_lot = MathMin(prev_lot, MarketInfo(Symbol(), MODE_MAXLOT));
   return (prev_lot);
}

void send_limit_order(int ticket) {
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      int order_type;
      double lot = next_lot(OrderLots());
      double price, stoploss, takeprofit;
      switch (OrderType()) {
         case OP_BUY:
            order_type = OP_BUYLIMIT;
            price = OrderStopLoss() + spread;
            stoploss = price - 2 * half_delta * Point;
            takeprofit = price + 2 * half_delta * Point;
            break;
         case OP_SELL:
            order_type = OP_SELLLIMIT;
            price = OrderStopLoss() - spread;
            stoploss = price + 2 * half_delta * Point;
            takeprofit = price - 2 * half_delta * Point;
            break;
      }
      OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER);
   }
}

void send_order(int order_type) {
   double lot = next_lot(0.0);
   double price = Point * MathRound((Ask + Bid) / 2.0 / Point);
   double stoploss, takeprofit;
   switch (order_type) {
      case OP_BUYLIMIT:
         price -= half_delta * Point;
         stoploss = price - 2 * half_delta * Point;
         takeprofit = price + 2 * half_delta * Point;
         break;
      case OP_SELLLIMIT:
         price += half_delta * Point;
         stoploss = price + 2 * half_delta * Point;
         takeprofit = price - 2 * half_delta * Point;
         break;
   }
   OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER);
}

void send_stop_order(int ticket) {
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      int order_type;
      double lot = prev_lot(OrderLots());
      if (!equal(lot, OrderLots())) {
         double price, stoploss, takeprofit;
         switch (OrderType()) {
            case OP_BUY:
               order_type = OP_BUYSTOP;
               price = OrderTakeProfit() - spread;
               stoploss = price - 2 * half_delta * Point;
               takeprofit = price + 2 * half_delta * Point;
               break;
            case OP_SELL:
               order_type = OP_SELLSTOP;
               price = OrderTakeProfit() + spread;
               stoploss = price + 2 * half_delta * Point;
               takeprofit = price - 2 * half_delta * Point;
               break;
         }
         OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER);
      }
   }
}

int start() {
   if (AccountEquity() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT)) return;
   if (AccountEquity() < lose_ratio * account_equity) {
      close_all_orders();
      init();
   }
   check_lot();
   switch (total_orders()) {
      case 0:
         send_order(OP_BUYLIMIT);
         send_order(OP_SELLLIMIT);
         break;
      case 1:
         int ticket = find_order();
         if (!OrderSelect(ticket, SELECT_BY_TICKET))
            break;
         switch (OrderType()) {
            case OP_BUY:
            case OP_SELL:
               send_limit_order(ticket);
               send_stop_order(ticket);
               break;
            default:
               OrderDelete(ticket);
               break;
         }
         break;
      case 2:
         int market_ticket = find_order(OP_BUY, OP_SELL);
         int limit_ticket = find_order(OP_BUYLIMIT, OP_SELLLIMIT);
         int stop_ticket = find_order(OP_BUYSTOP, OP_SELLSTOP);
         if (market_ticket < 0) break;
         if (limit_ticket > 0) {
            if (!check_order(limit_ticket, market_ticket)) {
               OrderDelete(limit_ticket);
               break;
            }
            send_stop_order(market_ticket);
            break;
         }
         if (stop_ticket > 0) {
            if (!check_order(stop_ticket, market_ticket)) {
               OrderDelete(stop_ticket);
               break;
            }
            send_limit_order(market_ticket);
            break;
         }
   }
}

int total_orders() {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) total_orders++;
      }
   }
   return (total_orders);
}