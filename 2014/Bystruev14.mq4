//+------------------------------------------------------------------+
//|                                                   Bystruev14.mq4 |
//|                     Copyright © 2009, Denis Bystruev, 6 Mar 2009 |
//|                                                 bystruev@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 6 Mar 2009"
#property link      "bystruev@mail.ru"

#define        MAGIC    903061548
#define        ZERO     0.00001

extern double  lose_level = 0.8;       // flush when we get down from our original balance
extern double  lot_factor = 1.5;       // what factor to increase lot when we lose
extern double  win_level = 1.1;        // flush when we get up from our original balance
extern int     points = 10;            // points below bid/above ask price

double         balance;                // previous equity value
int            buy_order;              // buy order ticket
double         lot;                    // current lot size
double         max_ask;                // maximum ask price we saw
double         min_bid;                // minimum bid price we saw
double         min_lot;                // minimum lot size
int            sell_order;             // sell order ticket

int count_orders(int order_type_a = -1, int order_type_b = -1, int magic = MAGIC) {
   int counter = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (((OrderType() == order_type_a) || (order_type_a < 0)) || ((OrderType() == order_type_b) || (order_type_b < 0))) {
            if (OrderMagicNumber() == magic) counter++;
         }
      }
   }
   return (counter);
}

int open_order(int order_type, double price = 0.0) {
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
   lot = lot_step * MathFloor(lot / lot_step);
   lot = MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot = MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
   if (AccountFreeMargin() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lot) return (-1);
   switch (order_type) {
      case OP_BUY:
         price = Ask;
         break;
      case OP_SELL:
         price = Bid;
         break;
      default:
         if (MathAbs(price) < ZERO) price = (Bid + Ask) / 2;
         break;
   }
   price = Point * MathFloor(price / Point);
   return (OrderSend(Symbol(), order_type, lot, price, 0, 0.0, 0.0, NULL, MAGIC));
}

bool close_order(int order_ticket, int magic = MAGIC) {
   double price;
   if (!OrderSelect(order_ticket, SELECT_BY_TICKET)) return (False);
   if (OrderMagicNumber() != magic) return (False);
   switch (OrderType()) {
      case OP_BUY:
         price = Bid;
         break;
      case OP_SELL:
         price = Ask;
         break;
      default:
         return (OrderDelete(order_ticket));     
   }
   return (OrderClose(order_ticket, OrderLots(), price, 0));
}

double gain() {
   if (MathAbs(balance) < ZERO) return (0.0);
   return (AccountEquity() / balance);
}

int init() {
   balance = AccountEquity();
   max_ask = Ask;
   min_bid = Bid;
   min_lot = MarketInfo(Symbol(), MODE_MINLOT);
   lot = min_lot;
}

int start() {
   max_ask = MathMax(max_ask, Ask);
   min_bid = MathMin(min_bid, Bid);
   switch (count_orders()) {
      case 0:
         if ((min_bid + points * Point < Bid) && (Ask < max_ask - points * Point)) {
            sell_order = open_order(OP_SELLSTOP, min_bid);
            buy_order = open_order(OP_BUYSTOP, max_ask);
         }
         break;
      case 1:
         close_order(buy_order);
         close_order(sell_order);
         break;
      case 2:
         switch (count_orders(OP_BUY, OP_SELL)) {
            case 1:
               if ((gain() < lose_level) || (win_level < gain())) {
                  balance = AccountEquity();
                  lot = min_lot;
                  max_ask = Ask;
                  min_bid = Bid;
                  close_order(buy_order);
                  close_order(sell_order);
               }
               break;
            case 2:
               close_order(buy_order);
               close_order(sell_order);
               lot = MathMax(lot + min_lot, lot_factor * lot);
               break;
         }               
         break;
   }
}
//+------------------------------------------------------------------+