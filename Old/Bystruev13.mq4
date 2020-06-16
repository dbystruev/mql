//+------------------------------------------------------------------+
//|                                                   Bystruev13.mq4 |
//|            Copyright © 2009, Denis Bystruev, 24 Feb - 6 Mar 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 24 Feb - 6 Mar 2009"
#property link      "http://www.moeradio.ru"

#define        MAGIC          1973050317
#define        STATE_GROW     1
#define        STATE_NORMAL   2
#define        STATE_RECOVERY 3

//---- input parameters
extern int     step = 10;           // step between neighboring buy and sell orders
extern int     stop_step = 30;      // how far stop loss/take profit should be
extern double  trailing_stop = 0.9; // trailing stop at 90%

double         balance;             // current starting balance
double         lot;                 // current lot size
double         max_balance;         // maximum balance ever achieved
double         old_balance;         // previous account equity
int            state;               // current state: normal, growing, or recovery
double         zero = 0.00001;      // very low number to compare doubles

//+------------------------------------------------------------------+
//| send an order                                                    |
//+------------------------------------------------------------------+
void send_order(int command, double price, int stop_loss, int take_profit) {
   price = Point * MathFloor(price / Point);
   OrderSend(Symbol(), command, lot, price, 0, price + Point * stop_loss, price + Point * take_profit, NULL, MAGIC);
}
//+------------------------------------------------------------------+
//| modify an order                                                  |
//+------------------------------------------------------------------+
void modify_order(int ticket, double price, int stop_loss, int take_profit) {
   price = Point * MathFloor(price / Point);
   OrderModify(ticket, price, price + Point * stop_loss, price + Point * take_profit, 0);
}
//+------------------------------------------------------------------+
//| lot size change function. Returns True if lot size has changed   |
//+------------------------------------------------------------------+
bool check_lot() {
   double   lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
   double   max_lot = MarketInfo(Symbol(), MODE_MAXLOT);
   double   min_lot = MarketInfo(Symbol(), MODE_MINLOT);
   double   new_lot = lot + lot_step;
   double   new_lot_balance = MathMax(MarketInfo(Symbol(), MODE_LOTSIZE) * Point * new_lot * stop_step, MarketInfo(Symbol(), MODE_MARGINREQUIRED) * new_lot);
   double   old_lot = lot;
   if (AccountEquity() < balance) {
      switch (state) {
         case STATE_GROW:
            balance = AccountEquity();
            lot = min_lot;
            state = STATE_NORMAL;
            break;
         case STATE_NORMAL:
         case STATE_RECOVERY:
            balance = AccountEquity();
            lot += 2 * lot_step;
            state = STATE_RECOVERY;
            if (AccountFreeMargin() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lot) {
               lot = min_lot;
            }
            break;
      }
   }
   if (balance < AccountEquity()) {
      switch (state) {
         case STATE_GROW:
         case STATE_NORMAL:
            balance += (AccountEquity() - old_balance) / 2.0;
            old_balance = AccountEquity();
            max_balance = MathMax(max_balance, balance);
            Print("balance = " + balance + "  max_balance = " + max_balance + "  Equity = " + AccountEquity());
            break;
         case STATE_RECOVERY:
            balance = AccountEquity();
            if (max_balance < balance) {
               lot = min_lot;
               max_balance = balance;
               state = STATE_NORMAL;
            }
            break;
      }
   }
   if (balance + new_lot_balance < AccountEquity()) {
      lot = (AccountEquity() - balance) / new_lot_balance * new_lot;
      state = STATE_GROW;
   }
   lot = lot_step * MathFloor(lot / lot_step);
   lot = MathMax(lot, min_lot);
   lot = MathMin(lot, max_lot);
   return (MathAbs(lot - old_lot) > zero);   // returns True if lot != old_lot
}
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   balance = AccountEquity();                // set the current started balance
   lot = MarketInfo(Symbol(), MODE_MINLOT);  // set the current lot equal to minimum lot size
   max_balance = balance;                    // maximum balance at the moment is the same as balance
   old_balance = balance;
   state = STATE_NORMAL;                     // at first we are not growing
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   double   stop_level = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double   trailing_price;
   switch (OrdersTotal()) {
      case 0:
         check_lot();
         send_order(OP_SELLSTOP, Bid - step * Point / 2.0, stop_step, -stop_step);
         send_order(OP_BUYSTOP, Ask + step * Point / 2.0, -stop_step, stop_step);
         break;
      case 1:
         if (OrderSelect(0, SELECT_BY_POS)) {
            switch (OrderType()) {
               case OP_BUY:
                  trailing_price = OrderOpenPrice() + (Bid - OrderOpenPrice()) * trailing_stop;
                  trailing_price = Point * MathFloor(trailing_price / Point);
                  if ((OrderOpenPrice() < Bid) && (trailing_price + stop_level < Bid) && (OrderStopLoss() < trailing_price)) {
                     OrderModify(OrderTicket(), OrderOpenPrice(), trailing_price, 0.0, 0);
                  }
                  break;
               case OP_SELL:
                  trailing_price = OrderOpenPrice() - (OrderOpenPrice() - Ask) * trailing_stop;
                  trailing_price = Point * MathFloor(trailing_price / Point);
                  if ((Ask < OrderOpenPrice()) && (Ask < trailing_price - stop_level) && (trailing_price < OrderStopLoss())) {
                     OrderModify(OrderTicket(), OrderOpenPrice(), trailing_price, 0.0, 0);
                  }
                  break;
               case OP_SELLSTOP:
                  if (check_lot()) {
                     if (OrderDelete(OrderTicket()))
                        send_order(OP_SELLSTOP, Bid - step * Point / 2.0, stop_step, -stop_step);
                  } else {
                     modify_order(OrderTicket(), Bid - step * Point / 2.0, stop_step, -stop_step);
                  }
                  send_order(OP_BUYSTOP, Ask + step * Point / 2.0, stop_step, stop_step);
                  break;
               case OP_BUYSTOP:
                  if (check_lot()) {
                     if (OrderDelete(OrderTicket()))
                        send_order(OP_BUYSTOP, Ask + step * Point / 2.0, stop_step, stop_step);
                  } else {
                     modify_order(OrderTicket(), Ask + step * Point / 2.0, stop_step, stop_step);
                  }
                  send_order(OP_SELLSTOP, Bid - step * Point / 2.0, stop_step, -stop_step);
                  break;
            }
         }
         break;
      case 2:
         int   market_order = -1;
         int   stop_order = -1;
         for (int i = 0; i < 2; i++) {
            if (OrderSelect(i, SELECT_BY_POS)) {
               switch (OrderType()) {
                  case OP_BUY:
                  case OP_SELL:
                     market_order = OrderTicket();
                     break;
                  case OP_SELLSTOP:
                  case OP_BUYSTOP:
                     stop_order = OrderTicket();
                     break;
               }
            }
         }
         if ((market_order >= 0) && (stop_order >= 0)) {
            OrderDelete(stop_order);
         }
         break;
   }
}

