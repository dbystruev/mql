//+------------------------------------------------------------------+
//|                                                   Bystruev15.mq4 |
//|                     Copyright © 2009, Denis Bystruev, 9 Mar 2009 |
//|                                                 bystruev@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 9 Mar 2009"
#property link      "bystruev@mail.ru"

//---- input parameters
extern double  max_loss          =  0.5;
extern int     take_profit       =  100;
extern int     stop_loss         =  50;
extern int     take_profit_step  =  2;
extern int     stop_loss_step    =  1;

double      lost_balance;
double      lot;
double      lot_step;
double      max_lot;
double      min_balance;
double      min_lot;
bool        stop_trade;
double      won_balance;

int init() {
   lost_balance   =  AccountBalance();
   lot            =  MarketInfo(Symbol(), MODE_MINLOT);
   lot_step       =  MarketInfo(Symbol(), MODE_LOTSTEP);
   max_lot        =  MarketInfo(Symbol(), MODE_MAXLOT);
   min_balance    =  max_loss * AccountBalance();
   min_lot        =  MarketInfo(Symbol(), MODE_MINLOT);
   stop_trade     =  False;
   won_balance    =  AccountBalance();
}
void trade() {
   double   high  =  MarketInfo(Symbol(), MODE_HIGH);
   double   low   =  MarketInfo(Symbol(), MODE_LOW);
   int      mode;
   double   price =  Point * MathRound((Ask + Bid) / 2.0 / Point);
   double   stoploss;
   double   takeprofit;
   if (OrdersTotal() > 0) return;
   if (MathAbs(price - low) > MathAbs(high - price)) {
      mode = OP_BUY;
      price = Ask;
      stoploss = price - stop_loss * Point;
      takeprofit = price + take_profit * Point;
   } else {
      mode = OP_SELL;
      price = Bid;
      stoploss = price + stop_loss * Point;
      takeprofit = price - take_profit * Point;
   }
   OrderSend(Symbol(), mode, lot, price, 0, stoploss, takeprofit);
}
bool lost() {
   if (OrdersTotal() > 0) return (False);
   bool lost = (AccountBalance() < lost_balance);
   if (AccountBalance() < min_balance) {
      stop_trade = True;
      Print("Stop trade: account balance is below minimum balance of " + min_balance);
      Print("Minimum lot: " + min_lot + ", maximum lot: " + max_lot);
   }
   lost_balance = AccountBalance();
   return (lost);
}
bool won() {
   if (OrdersTotal() > 0) return (False);
   bool won = (won_balance < AccountBalance());
   min_balance = MathMax(min_balance, max_loss * AccountBalance());
   won_balance = AccountBalance();
   return (won);
}
void fix_lot() {
   if (OrdersTotal() > 0) return;
//   Print("Before fix_lot() lot = " + lot);
   lot   =  lot_step * MathRound(lot / lot_step);
   lot   =  MathMax(lot, min_lot);
   lot   =  MathMin(lot, max_lot);
//   Print("After fix_lot() lot = " + lot);
   if (AccountBalance() < 2.0 * MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lot) {
      stop_trade = True;
      Print("Stop trade: no required margin.  Lot = " + lot + ", required margin = " + MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lot);
   }
}
int start() {
   if (stop_trade) return;
   if (lost()) lot += lot_step * stop_loss_step;
   if (won()) lot -= lot_step * take_profit_step;
   fix_lot();
   trade();
}