//+------------------------------------------------------------------+
//|                                   2020.06.15_Bystruev16_Stop.mq4 |
//| Copyright © 2009-2020, Denis Bystruev, 12 Mar 2009 - 15 Jun 2020 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009-2020, Denis Bystruev, 12 Mar 2009 - 15 Jun 2020"
#property link      "https://github.com/dbystruev"
#property version   "2020.06.15"
#property strict

//---- input parameters
extern   double   max_balance    =  0;    // maximum reached account balance
extern   int      order_delta    =  100;  // difference between buy and sell orders
extern   int      stop_loss      =  100;  // initial stop loss level
extern   int      return_level   =  10000;// when to set take profit equal to buy price
extern   double   trailing_level =  0.5;  // trail at 50%
extern   int      trade_period   =  30;   // how often to trade in seconds

datetime          last_trade;             // time of the last trade
double            lot;                    // current lot size
double            spread;                 // spread between Ask and Bid

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void adjust_order(int ticket)
  {
   double   price;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      switch(OrderType())
        {
         case OP_BUYSTOP:
            price    = (Ask + Bid) / 2 + Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMax(price, Ask + spread);
            if(OrderModify(ticket, price, price - Point * stop_loss, 0.0, 0))
              {
               last_trade = TimeCurrent();
              }
            break;
         case OP_SELLSTOP:
            price    = (Ask + Bid) / 2 - Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMin(price, Bid - spread);
            if(OrderModify(ticket, price, price + Point * stop_loss, 0.0, 0))
              {
               last_trade = TimeCurrent();
              }
            break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void adjust_orders(int order_type1, int order_type2)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == order_type1) || (OrderType() == order_type2))
           {
            adjust_order(OrderTicket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void delete_orders(int order_type1, int order_type2)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == order_type1) || (OrderType() == order_type2))
           {
            OrderDelete(OrderTicket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   last_trade  =  0;
   spread      =  Point * MarketInfo(Symbol(), MODE_SPREAD);
   set_lot_size();
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   max_balance = MathMax(AccountBalance(), max_balance);
   datetime next_move = last_trade + trade_period - TimeCurrent();
   string comment = "Max Balance = " + DoubleToString(max_balance, 2);
   if(0 < next_move)
     {
      comment += "\nNext move in " + TimeMinute(next_move) + ":" + TimeSeconds(next_move);
     }
   Comment(comment);
   if(AccountBalance() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT))
      return;
   switch(total_orders(OP_BUYSTOP, OP_SELLSTOP))
     {
      case 0:
         switch(total_orders(OP_BUY, OP_SELL))
           {
            case 0:
               set_lot_size();
               send_orders(OP_BUYSTOP, OP_SELLSTOP);
               break;
            case 1:
            case 2:
               trail_orders(OP_BUY, OP_SELL);
               break;
           }
         break;
      case 1:
         delete_orders(OP_BUYSTOP, OP_SELLSTOP);
         break;
      case 2:
         if(TimeCurrent() < last_trade + trade_period)
           {
            return;
           }
         adjust_orders(OP_BUYSTOP, OP_SELLSTOP);
         break;
     }
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void send_order(int type)
  {
   double   price;
   switch(type)
     {
      case OP_BUYSTOP:
         price    = (Ask + Bid) / 2 + Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMax(price, Ask + spread);
         if(OrderSend(Symbol(), type, lot, price, 0, price - Point * stop_loss, 0.0) >= 0)
           {
            last_trade = TimeCurrent();
           }
         break;
      case OP_SELLSTOP:
         price    = (Ask + Bid) / 2 - Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMin(price, Bid - spread);
         if(OrderSend(Symbol(), type, lot, price, 0, price + Point * stop_loss, 0.0) >= 0)
           {
            last_trade = TimeCurrent();
           }
         break;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void send_orders(int type1, int type2)
  {
   send_order(type1);
   send_order(type2);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void set_lot_size()
  {
   double   lot_step =  MarketInfo(Symbol(), MODE_LOTSTEP);
   lot   =  AccountEquity() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / 10.0;
   lot   =  lot_step * MathRound(lot / lot_step);
   lot   =  MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot   =  MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int total_orders(int order_type1, int order_type2)
  {
   int total_orders = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == order_type1) || (OrderType() == order_type2))
           {
            total_orders++;
           }
        }
     }
   return (total_orders);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void trail_order(int ticket)
  {
   double   stoploss;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      bool profitable = max_balance < AccountBalance() + trailing_level * (AccountEquity() - AccountBalance());
      switch(OrderType())
        {
         case OP_BUY:
            stoploss =  OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice());
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMin(stoploss, Bid - spread);
            if((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss) && profitable)
              {
               if(OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0))
                 {
                  last_trade = TimeCurrent();
                 }
              }
            if(Bid + Point * return_level < OrderOpenPrice())
              {
               if(OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice(), 0))
                 {
                  last_trade = TimeCurrent();
                 }
              }
            break;
         case OP_SELL:
            stoploss =  OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMax(stoploss, Ask + spread);
            if((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss()) && profitable)
              {
               if(OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0))
                 {
                  last_trade = TimeCurrent();
                 }
              }
            if(OrderOpenPrice() + Point * return_level < Ask)
              {
               if(OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice(), 0))
                 {
                  last_trade = TimeCurrent();
                 }
              }
            break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void trail_orders(int order_type1, int order_type2)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == order_type1) || (OrderType() == order_type2))
           {
            trail_order(OrderTicket());
           }
        }
     }
  }
//+------------------------------------------------------------------+
