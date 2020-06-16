//+------------------------------------------------------------------+
//|                                                   Bystruev12.mq4 |
//|            Copyright © 2009, Denis Bystruev, 24 Feb - 4 Mar 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 24 Feb - 5 Mar 2009"
#property link      "http://www.moeradio.ru"

#define     MAGIC          1973050317
#define     STATE_GROW     1
#define     STATE_NORMAL   2
#define     STATE_RECOVERY 3

//---- input parameters
extern int  step = 10;        // step between neighboring buy and sell orders

double      balance;          // current starting balance
double      lot;              // current lot size
double      max_balance;      // maximum balance ever achieved
int         state;            // current state: normal or growing
double      zero = 0.00001;   // very low number to compare doubles

//+------------------------------------------------------------------+
//| send a limit order                                               |
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
   double   new_lot_balance = MarketInfo(Symbol(), MODE_MARGINREQUIRED) * new_lot;
   double   old_lot = lot;
   Print("balance = " + balance + "  new_lot_balance = " + new_lot_balance + "   max_balance = " + max_balance);
   if (AccountEquity() < balance) {
      Sleep(300000);                            // we lost - do nothing for 5 min
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
            if (MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lot < AccountFreeMargin()) {
               lot = min_lot;
            }
            break;
      }
   }
   if (balance < AccountEquity()) {
      switch (state) {
         case STATE_GROW:
         case STATE_NORMAL:
            balance += (AccountEquity() - balance) / 2.0;
            max_balance = MathMax(max_balance, balance);
            break;
         case STATE_RECOVERY:
            balance = AccountEquity();
            lot -= lot_step;
            if (max_balance < balance) {
               lot = min_lot;
               max_balance = balance;
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
   state = STATE_NORMAL;                     // at first we are not growing
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   // Act only if there are no orders or there is one order
   switch (OrdersTotal()) {
      case 0:
         check_lot();
         send_order(OP_BUYLIMIT, Bid - step * Point / 2.0, -2 * step, step);
         send_order(OP_SELLLIMIT, Ask + step * Point / 2.0, 2 * step, -step);
         break;
      case 1:
         if (OrderSelect(0, SELECT_BY_POS)) {
            switch (OrderType()) {
               case OP_BUYLIMIT:
                  if (check_lot()) {
                     if (OrderDelete(OrderTicket()))
                        send_order(OP_BUYLIMIT, Bid - step * Point / 2.0, -2 * step, step);
                  } else {
                     modify_order(OrderTicket(), Bid - step * Point / 2.0, -2 * step, step);
                  }
                  send_order(OP_SELLLIMIT, Ask + step * Point / 2.0, 2 * step, -step);
                  break;
               case OP_SELLLIMIT:
                  if (check_lot()) {
                     if (OrderDelete(OrderTicket()))
                        send_order(OP_SELLLIMIT, Ask + step * Point / 2.0, 2 * step, -step);
                  } else {
                     modify_order(OrderTicket(), Ask + step * Point / 2.0, 2 * step, -step);
                  }
                  send_order(OP_BUYLIMIT, Bid - step * Point / 2.0, -2 * step, step);
                  break;
            }
         }
         break;
      case 2:
         int   market_order = -1;
         int   limit_order = -1;
         for (int i = 0; i < 2; i++) {
            if (OrderSelect(i, SELECT_BY_POS)) {
               switch (OrderType()) {
                  case OP_BUY:
                  case OP_SELL:
                     market_order = OrderTicket();
                     break;
                  case OP_BUYLIMIT:
                  case OP_SELLLIMIT:
                     limit_order = OrderTicket();
                     break;
               }
            }
         }
         if ((market_order >= 0) && (limit_order >= 0)) {
            OrderDelete(limit_order);
         }
         break;
   }
}

