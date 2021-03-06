//+------------------------------------------------------------------+
//|                                   2020.06.15_Bystruev16_Stop.mq4 |
//| Copyright © 2009-2020, Denis Bystruev, 12 Mar 2009 - 15 Jun 2020 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009-2020, Denis Bystruev, 12 Mar 2009 - 15 Jun 2020"
#property link      "https://github.com/dbystruev"
#property version   "20.06"
#property strict

//---- input parameters
extern   int      trade_period   =  15;      // how often to trade in seconds
extern   int      stop_loss      =  40;      // initial stop loss level
extern   double   max_balance    =  0;       // maximum reached account balance
extern   double   min_profit     =  0.005;   // minimum profit from current balance (0.005 = 0.5%)
extern   double   trailing_level =  0.8;     // trailing level (0...1)
extern   bool     use_stop_order =  true;    // use stop (true) or limit (false) orders
extern   int      return_level   =  10000;   // when to set take profit equal to buy price

double            last_bid;                  // last bid price
datetime          last_tick;                 // time of the last tick
datetime          last_trade;                // time of the last trade
double            lot;                       // current lot size
double            max_speed;                 // maximum price move speed in double points / second
int               max_spread;                // maximum spread
int               order_delta;               // difference between buy and sell orders
int               order_type1;               // first order type
int               order_type2;               // second order type
double            price_speed;               // price move speed in double points / second
double            spread;                    // spread between Ask and Bid

//+------------------------------------------------------------------+
//| Adjust an order with given ticket.                               |
//+------------------------------------------------------------------+
void adjust_order(int ticket)
  {
   double   price;
   double   sign = use_stop_order ? 1 : -1;
   double   sl = Point * sign * stop_loss;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      switch(OrderType())
        {
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
            price    = (Ask + Bid) / 2 + Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMax(price, Ask + spread);
            if(OrderModify(ticket, price, price - sl, 0, 0))
              {
               last_trade = TimeCurrent();
              }
            break;
         case OP_SELLSTOP:
         case OP_BUYLIMIT:
            price    = (Ask + Bid) / 2 - Point * order_delta / 2;
            price    =  Point * MathRound(price / Point);
            price    =  MathMin(price, Bid - spread);
            if(OrderModify(ticket, price, price + sl, 0, 0))
              {
               last_trade = TimeCurrent();
              }
            break;
        }
     }
  }

//+------------------------------------------------------------------+
//| Adjust the orders of given types.                                |
//+------------------------------------------------------------------+
void adjust_orders(int type1, int type2)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            adjust_order(OrderTicket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Delete the orders of given types. Changes last_trade if deleted. |
//+------------------------------------------------------------------+
void delete_orders(int type1, int type2)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            if(OrderDelete(OrderTicket()))
               last_trade = TimeCurrent();
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Format time to 00:00:00.                                         |
//+------------------------------------------------------------------+
string formatted_time(datetime time)
  {
   return padded_number(TimeHour(time)) + ":"+ padded_number(TimeMinute(time)) + ":"+ padded_number(TimeSeconds(time));
  }

//+------------------------------------------------------------------+
//| Expert initialization function.                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   order_type1 = use_stop_order ? OP_BUYSTOP : OP_SELLLIMIT;
   order_type2 = use_stop_order ? OP_SELLSTOP : OP_BUYLIMIT;
   last_bid = Bid;
   last_tick = TimeCurrent();
   last_trade  =  0;
   max_speed = 0;
   max_spread = (int) MarketInfo(Symbol(), MODE_SPREAD);
   price_speed = 0;
   spread      =  Point * max_spread;
   set_lot_size();
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function.                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   update_vars();
   datetime next_move = last_trade + trade_period - TimeCurrent();
   string space = "\n                                             ";
   string comment = space + "Max Balance = " + DoubleToString(max_balance, 2);
   comment += space + "Max Spread = " + IntegerToString(max_spread);
   comment += space + "Order Delta = " + IntegerToString(order_delta);
   comment += space + "Price Speed: current = " + DoubleToString(trade_period * price_speed / Point, 2);
   comment += ", max = " + DoubleToString(trade_period * max_speed / Point, 2) + " points in " + IntegerToString(trade_period) + " sec";
   if(0 < next_move)
     {
      comment += space + "Next move in " + formatted_time(next_move);
     }
   else
     {
      datetime last_move = TimeCurrent() - last_trade;
      comment += space + "Last move was " + formatted_time(last_move) + " ago";
     }
   Comment(comment);
   if(AccountBalance() < MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT))
      return;
   switch(total_orders(order_type1, order_type2))
     {
      case 0:
         switch(total_orders(OP_BUY, OP_SELL))
           {
            case 0:
               set_lot_size();
               send_orders(order_type1, order_type2);
               break;
            case 1:
            case 2:
               trail_orders(OP_BUY, OP_SELL);
               break;
           }
         break;
      case 1:
         delete_orders(order_type1, order_type2);
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
//| Returns number as a string with padded 0 if number < 10.         |
//+------------------------------------------------------------------+
string padded_number(int number)
  {
   return (number < 10 ? "0" : "") + IntegerToString(number);
  }

//+------------------------------------------------------------------+
//| Send an order of given type. Changes last_trade if successful.   |
//+------------------------------------------------------------------+
void send_order(int type)
  {
   double   price;
   double   sign = use_stop_order ? 1 : -1;
   double   sl = Point * sign * stop_loss;
   switch(type)
     {
      case OP_BUYSTOP:
      case OP_SELLLIMIT:
         price    = (Ask + Bid) / 2 + Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMax(price, Ask + spread);
         if(OrderSend(Symbol(), type, lot, price, 0, price - sl, 0) >= 0)
           {
            last_trade = TimeCurrent();
            max_speed = price_speed;
           }
         break;
      case OP_SELLSTOP:
      case OP_BUYLIMIT:
         price    = (Ask + Bid) / 2 - Point * order_delta / 2;
         price    =  Point * MathRound(price / Point);
         price    =  MathMin(price, Bid - spread);
         if(OrderSend(Symbol(), type, lot, price, 0, price + sl, 0) >= 0)
           {
            last_trade = TimeCurrent();
            max_speed = price_speed;
           }
         break;
     }
  }

//+------------------------------------------------------------------+
//| Send orders of given types.                                      |
//+------------------------------------------------------------------+
void send_orders(int type1, int type2)
  {
   send_order(type1);
   send_order(type2);
  }

//+------------------------------------------------------------------+
//| Set current lot size.                                            |
//+------------------------------------------------------------------+
void set_lot_size()
  {
   double   lot_step =  MarketInfo(Symbol(), MODE_LOTSTEP);
   lot   =  AccountEquity() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / 10;
   lot   =  lot_step * MathRound(lot / lot_step);
   lot   =  MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot   =  MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
  }

//+------------------------------------------------------------------+
//| Number of orders of given types.                                 |
//+------------------------------------------------------------------+
int total_orders(int type1, int type2)
  {
   int total_orders = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            total_orders++;
           }
        }
     }
   return (total_orders);
  }

//+------------------------------------------------------------------+
//| Trail an order with given ticket number.                         |
//+------------------------------------------------------------------+
void trail_order(int ticket)
  {
   double   stoploss;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      double profit =  trailing_level * (AccountEquity() - AccountBalance());
      bool profitable = min_profit * max_balance < profit;
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
//| Trail orders of given types.                                     |
//+------------------------------------------------------------------+
void trail_orders(int type1, int type2)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            trail_order(OrderTicket());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Update vars on each tick                                         |
//+------------------------------------------------------------------+
void update_vars()
  {
   datetime time_since_last_tick = TimeCurrent() - last_tick;
   if(0 < time_since_last_tick)
     {
      price_speed = MathAbs(Bid - last_bid) / time_since_last_tick;
      max_speed = MathMax(price_speed, max_speed);
     }
   last_bid = Bid;
   last_tick = TimeCurrent();
   max_balance = MathMax(AccountBalance(), max_balance);
   max_spread = (int) MathMax(MarketInfo(_Symbol, MODE_SPREAD), max_spread);
   order_delta = (int) MathRound(10 * MarketInfo(_Symbol, MODE_SPREAD));
  }
//+------------------------------------------------------------------+
