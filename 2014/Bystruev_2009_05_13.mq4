//+------------------------------------------------------------------+
//|                                          Bystruev_2009_05_13.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 13 May 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 13 May 2009"
#property link      "http://www.moeradio.ru"

// very low number to compare doubles
#define  ZERO        0.00001

extern   double   delta_factor   =  2.0;  // double delta if price moves wrong direction
extern   double   lot_factor     =  2.0;  // double lot if price moves wrong direction
extern   int      start_delta    =  66;   // delta in points to start with
extern   double   tp_ratio       =  0.8;  // assume return to at least 80% of old price after price move

         double   start_lot;              // lot size to start with
         int      start_tp;               // take profit in points to start with

// adds an order of given order_type with twice lot, new tp and twice delta
// returns order's ticket if success or -1 otherwise
int add_order(int new_order_type) {
   switch (new_order_type) {
      case OP_BUYLIMIT:
         int   order_type  =  OP_BUY;
         int   sign        = -1;
         break;
      case OP_SELLLIMIT:
         order_type = OP_SELL;
         sign = 1;
         break;
   }
   int   first_order   =  find_order(order_type, start_lot);
   if (!OrderSelect(first_order, SELECT_BY_TICKET)) {
      return (-1);
   }
   double   first_price    =  OrderOpenPrice();
   int   last_order   =  find_order(order_type, 0.0, TRUE);
   if (!OrderSelect(last_order, SELECT_BY_TICKET)) {
      return (-1);
   }
   double   last_lot_size  =  OrderLots();
   double   last_price     =  OrderOpenPrice();
   if (first_order == last_order) {
      int      new_delta   =  start_delta * delta_factor * sign;
   } else {
      int prev_order = find_order(order_type, OrderLots() / lot_factor);
      if (!OrderSelect(prev_order, SELECT_BY_TICKET)) {
         return (-1);
      }
      double   prev_price  =  OrderOpenPrice();
      new_delta = delta_factor * MathRound((last_price - prev_price) / Point);
   }
   double   new_price         =  last_price + new_delta * Point;
   double   new_lot_size      =  last_lot_size * lot_factor;
   int      new_tp            =  MathRound(((first_price - new_price) * tp_ratio) / Point);
   return(send_order(new_order_type, new_lot_size, last_price, new_delta, new_tp));
}

// deletes all orders with given order_type
// returns true if all orders deleted successfully, false otherwise
bool delete_orders(int order_type) {
   bool  delete_orders  =  TRUE;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderType() == order_type) {
            if (OrderDelete(OrderTicket())) {
               i--;
            } else {
               delete_orders = FALSE;
            }
         }
      }
   }
   return (delete_orders);
}

// finds the first order with given order_type and optional lot size
// returns order ticket or -1 if an order with given parameters not found
int find_order(int order_type, double lot_size = 0.0, bool find_max_lot = FALSE) {
   int      find_order  =  -1;
   double   max_lot = 0.0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type) && ((MathAbs(lot_size) < ZERO) || (MathAbs(lot_size - OrderLots()) < ZERO))) {
            if (!find_max_lot) {
               return (OrderTicket());
            }
            if (max_lot < OrderLots()) {
               find_order = OrderTicket();
               max_lot = OrderLots();
            }
         }
      }
   }
   return (find_order);
}

int init() {
   start_delta =  MathMax(start_delta, MarketInfo(Symbol(), MODE_STOPLEVEL));
   start_lot   =  MarketInfo(Symbol(), MODE_MINLOT);
   start_tp    =  MarketInfo(Symbol(), MODE_STOPLEVEL);
}


// finds an order with order_type and lot_size and sets its price to delta range of given price and
// sets its take profit to tp range of given price
// returns true on success, false otherwise
bool modify_order(int order_type, double lot_size, double price, int delta, int tp) {
   double   new_price      =  10 * Point * MathRound((price + delta * Point) / 10 / Point);
   double   new_tp         =  new_price + tp * Point;
   int      order_ticket   =  find_order(order_type, lot_size);
   if (order_ticket < 0) {
      return (FALSE);
   }
   if (!OrderSelect(order_ticket, SELECT_BY_TICKET)) {
      return (FALSE);
   }
   switch (order_type) {
      case OP_BUYLIMIT:
            if (new_price < OrderOpenPrice()) {
               return (FALSE);
            }
         break;
      case OP_SELLLIMIT:
            if (OrderOpenPrice() < new_price) {
               return (FALSE);
            }
         break;
   }
   return (OrderModify(order_ticket, new_price, OrderStopLoss(), new_tp, OrderExpiration()));
}

// counts the number of orders with given order_type and optional lot size
// returns the number of such orders found
int orders_total(int order_type, double lot_size = 0.0) {
   int   orders_total   =  0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type) && ((MathAbs(lot_size) < ZERO) || (MathAbs(lot_size - OrderLots()) < ZERO))) {
            orders_total++;
         }
      }
   }
   return (orders_total);
}

// sends an order of order_type and lot_size with price of delta range of given price and
// take profit of tp range of given price
// returns order's ticket if success or -1 otherwise
int send_order(int order_type, double lot_size, double price, int delta, int tp) {
   double   new_price      =  10 * Point * MathRound((price + delta * Point) / 10 / Point);
   double   stop_level     =  Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   switch (order_type) {
      case OP_BUYLIMIT:
         if ((Ask - stop_level) < new_price) {
            new_price = Ask - stop_level;
         }
         break;
      case OP_SELLLIMIT:
         if (new_price < (Bid + stop_level)) {
            new_price = Bid + stop_level;
         }
         break;
   }
   double   new_tp         =  new_price + tp * Point;
   return (OrderSend(Symbol(), order_type, lot_size, new_price, 0, 0.0, new_tp));
}

// sets the same take profit for all order_type orders
// for buy orders it will be the lowest take profit, for sell orders - the highest
// returns true on success and false otherwise
bool set_tp(int order_type) {
   bool  set_tp   =  TRUE;
   double   max_tp = 0.0, min_tp = 1000000.0, tp;
   // at first search for minimum/maximum take profit
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderType() == order_type) {
            max_tp = MathMax(max_tp, OrderTakeProfit());
            min_tp = MathMin(min_tp, OrderTakeProfit());
         }
      }
   }
   // the second assign tp the lowest tp for buy orders and the highest tp for sell orders
   switch (order_type) {
      case OP_BUY:
         tp = min_tp;
         break;
      case OP_SELL:
         tp = max_tp;
         break;
   }
   // the third set take profits for all orders to the same tp
   for (i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderType() == order_type) {
            if (MathAbs(OrderTakeProfit() - tp) > ZERO) {
               set_tp = set_tp && OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tp, OrderExpiration());
            }
         }
      }
   }
   return (set_tp);
}

int start() {
   // if there are no any buy orders
   if (orders_total(OP_BUY) == 0) {
      // if there are any buy limit orders with lot > start_lot
      if (orders_total(OP_BUYLIMIT, start_lot) < orders_total(OP_BUYLIMIT)) {
         // delete all buy limit orders
         delete_orders(OP_BUYLIMIT);
      }
      // if there is a buy limit order with start_lot
      if (orders_total(OP_BUYLIMIT, start_lot) == 1) {
         // modify buy limit order with start_delta below bid price
         //modify_order(OP_BUYLIMIT, start_lot, Ask, -start_delta, start_tp);
      } else {
         // open buy limit order with start_lot, start_tp and start_delta below bid price
         send_order(OP_BUYLIMIT, start_lot, Ask, -start_delta, start_tp);
      }
      // exit
   }
      
   // if there are any buy orders
   if (orders_total(OP_BUY) > 0) {
      // check that all of them have the same tp equal to tp of the buy order with lowest price
      set_tp(OP_BUY);
      // if there is no buy limit order
      if (orders_total(OP_BUYLIMIT) == 0) {
         // open buy limit order with twice lot, new tp and twice delta below buy order with lowest price
         add_order(OP_BUYLIMIT);
      }
   }
         
   // the same for sell orders
   if (orders_total(OP_SELL) == 0) {
      if (orders_total(OP_SELLLIMIT, start_lot) < orders_total(OP_SELLLIMIT)) {
         delete_orders(OP_SELLLIMIT);
      }
      if (orders_total(OP_SELLLIMIT, start_lot) == 1) {
         //modify_order(OP_SELLLIMIT, start_lot, Bid, start_delta, -start_tp);
      } else {
         send_order(OP_SELLLIMIT, start_lot, Bid, start_delta, -start_tp);
      }
   }
      
   if (orders_total(OP_SELL) > 0) {
      set_tp(OP_SELL);
      if (orders_total(OP_SELLLIMIT) == 0) {
         add_order(OP_SELLLIMIT);
      }
   }
}