//+------------------------------------------------------------------+
//|                                                   Bystruev11.mq4 |
//|            Copyright © 2009, Denis Bystruev, 19 Feb - 2 Mar 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 19 Feb - 2 Mar 2009"
#property link      "http://www.moeradio.ru"

#define MAGIC 1973050317

extern datetime   period = 300;     // how often to trade in seconds

double   last_bid;            // previous Bid value
datetime last_trade;          // when last trade has happened
int      lost;                // how many points is lost
double   lot;                 // current lot size
double   start_balance;       // the balance we have started with

int init() {
   last_bid = Bid;
   last_trade = 0;
   lost = 0;
   start_balance = AccountEquity();
   update_lot();
}

void update_lot() {
   lot = MarketInfo(Symbol(), MODE_MINLOT);
   if (start_balance < AccountEquity()) {
      lot = MathMax(lot, (AccountEquity() - start_balance) / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / 2.0);
   }
}

void buy() {
   double   take_profit;       // take profit value
   
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC) {
            switch (OrderType()) {
               case OP_BUY:
                  return;
               case OP_SELL:
                  double gain = OrderOpenPrice() - Ask;
                  if (!OrderClose(OrderTicket(), OrderLots(), Ask, 0, Red)) {
                     return;
                  }
                  lost -= MathRound(gain / Point);
                  break;
            }
         }
      }
   }
   update_lot();
   lost = MathMax(lost, MarketInfo(Symbol(), MODE_STOPLEVEL));
   take_profit = Ask + lost * Point;
   if (OrderSend(Symbol(), OP_BUY, lot, Ask, 0, 0.0, take_profit, NULL, MAGIC, 0, Blue) >= 0)
      last_trade = TimeCurrent();
}

void sell() {
   double   take_profit;       // take profit value
   
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC) {
            switch (OrderType()) {
               case OP_BUY:
                  double gain = Bid - OrderOpenPrice();
                  if (!OrderClose(OrderTicket(), OrderLots(), Bid, 0, Blue)) {
                     return;
                  }
                  lost -= MathRound(gain / Point);
                  break;
               case OP_SELL:
                  return;
            }
         }
      }
   }
   update_lot();
   lost = MathMax(lost, MarketInfo(Symbol(), MODE_STOPLEVEL));
   take_profit = Bid - lost * Point;
   if (OrderSend(Symbol(), OP_SELL, lot, Bid, 0, 0.0, take_profit, NULL, MAGIC, 0, Red) >= 0)
      last_trade = TimeCurrent();
}

int start() {
   if ((TimeCurrent() < last_trade + period) && (OrdersTotal() > 0))
      return;
   if (last_bid < Bid) {
      buy();
   } else {
      sell();
   }
   last_bid = Bid;
}

