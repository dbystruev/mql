//+------------------------------------------------------------------+
//|                                                       Waiter.mq4 |
//|                                   Copyright 2020, Denis Bystruev |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+

#property copyright "Copyright 2020.07.10, Denis Bystruev"
#property link      "https://github.com/dbystruev"
#property version   "1.00"
#property strict

//--- input parameters
input double   min_profit =  0;        // minimum profit from current balance (0.005 = 0.5%)
input int      sl_tp_ratio = 20;       // stop loss level to take profit level
input int      trailing_percent = 80;  // trailing percent 1...99
input bool     use_stop_order = true;  // use stop (true) or limit (false) orders
input int      wait_minutes = 10;      // waiting minutes before start

//--- global variables
double         lot;                    // current lot size
double         max_price;              // maximum price since last trade
double         min_price;              // minimum price since last trade
int            order_type1;            // first order type
int            order_type2;            // second order type
datetime       reset_time;             // time when max_price and min_price were reset

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
            if(OrderDelete(OrderTicket())) {}
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
   lot = MarketInfo(_Symbol, MODE_MINLOT);
   order_type1 = use_stop_order ? OP_BUYSTOP : OP_SELLLIMIT;
   order_type2 = use_stop_order ? OP_SELLSTOP : OP_BUYLIMIT;
   reset_max_min_price_time();
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function.                                            |
//+------------------------------------------------------------------+
void OnTick()
  {
   update_vars();
   show_comments();

   switch(total_orders(order_type1, order_type2))
     {
      case 0:
         switch(total_orders(OP_BUY, OP_SELL))
           {
            case 0:
               if(0 < wait_time() || price_too_close())
                  return;
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
         reset_max_min_price_time();
         break;
     }
  }

//+------------------------------------------------------------------+
//| Reset max_price, min_price, and reset_time                       |
//+------------------------------------------------------------------+
void reset_max_min_price_time()
  {
   max_price = Ask;
   min_price = Bid;
   reset_time = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Returns number as a string with padded 0 if number < 10.         |
//+------------------------------------------------------------------+
string padded_number(int number)
  {
   return (number < 10 ? "0" : "") + IntegerToString(number);
  }

//+------------------------------------------------------------------+
//| Returns true if current price is too close to max or min price   |
//+------------------------------------------------------------------+
bool price_too_close()
  {
   double price_spread = max_price - min_price;
   double top_border = min_price + 2 * price_spread / 3;
   double bottom_border = min_price + price_spread / 3;
   return Bid < bottom_border || top_border < Ask;
  }

//+------------------------------------------------------------------+
//| Send an order of given type. Changes last_trade if successful.   |
//+------------------------------------------------------------------+
void send_order(int type)
  {
   double price;
   double sign = use_stop_order ? 1 : -1;
   double sl = sign * (max_price - min_price);
   switch(type)
     {
      case OP_BUYSTOP:
      case OP_SELLLIMIT:
         price = max_price;
         if(0 <= OrderSend(Symbol(), type, lot, price, 0, price - sl, 0)) {}
         break;
      case OP_SELLSTOP:
      case OP_BUYLIMIT:
         price = min_price;
         if(0 <= OrderSend(Symbol(), type, lot, price, 0, price + sl, 0)) {}
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
   lot = MarketInfo(Symbol(), MODE_MINLOT);
  }

//+------------------------------------------------------------------+
//| Show comments on each tick.                                      |
//+------------------------------------------------------------------+
void show_comments()
  {
   string space = "\n                                             ";
   string comment = space + "Max price = " + DoubleToString(max_price, Digits) + ", Ask = " + DoubleToString(Ask, Digits);
   comment += space + "Min price = " + DoubleToString(min_price, Digits) + ", Bid = " + DoubleToString(Bid, Digits);
   comment += space + "Time since reset = " + formatted_time(time_since_reset());
   if(0 < wait_time())
      comment += ", wait time = " + formatted_time(wait_time());
   if(price_too_close())
      comment += space + "Price too close";
   Comment(comment);
  }

//+------------------------------------------------------------------+
//| Time passed since last reset                                     |
//+------------------------------------------------------------------+
datetime time_since_reset()
  {
   return TimeCurrent() - reset_time;
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
   double spread = Point * MarketInfo(_Symbol, MODE_SPREAD);
   double stoploss;
   double trailing_level = trailing_percent / 100;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      double profit = (AccountEquity() - AccountBalance()) * trailing_level;
      bool profitable = min_profit * AccountBalance() < profit;
      switch(OrderType())
        {
         case OP_BUY:
            stoploss = OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice());
            stoploss = Point * MathRound(stoploss / Point);
            stoploss = MathMin(stoploss, Bid - spread);
            if((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss) && profitable)
              {
               if(OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {}
              }
            break;
         case OP_SELL:
            stoploss = OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            stoploss = Point * MathRound(stoploss / Point);
            stoploss = MathMax(stoploss, Ask + spread);
            if((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss()) && profitable)
              {
               if(OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {}
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
//| Update variables with every tick.                                |
//+------------------------------------------------------------------+
void update_vars()
  {
   max_price = MathMax(Ask, max_price);
   min_price = MathMin(Bid, min_price);
  }

//+------------------------------------------------------------------+
//| Time to wait before wait_minutes expire                          |
//+------------------------------------------------------------------+
datetime wait_time()
  {
   return 60 * wait_minutes - time_since_reset();
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
