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
input bool     use_stop_order = true;  // use stop (true) or limit (false) orders
input double   trailing_level =  0.5;  // trailing level (0...1)

//--- global variables
double         adjust;                 // value to adjust stop/limit orders by
double         lot;                    // current lot size
double         max_price;              // maximum price since last trade
double         min_price;              // minimum price since last trade
int            order_type1;            // first order type
int            order_type2;            // second order type
datetime       reset_time;             // time when max_price and min_price were reset

//+------------------------------------------------------------------+
//| Adjust an order with given ticket.                               |
//+------------------------------------------------------------------+
void adjust_order(int ticket)
  {
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      switch(OrderType())
        {
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
            if(adjust < 0)
               if(OrderModify(ticket, OrderOpenPrice() + adjust, 0, 0, 0)) {}
            break;
         case OP_SELLSTOP:
         case OP_BUYLIMIT:
            if(0 < adjust)
               if(OrderModify(ticket, OrderOpenPrice() + adjust, 0, 0, 0)) {}
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
   reset_adjust_max_min_price_time();
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
               if(price_too_close())
                  return;
               set_lot_size();
               send_orders(order_type1, order_type2);
               break;
            case 1:
            case 2:
               trail_orders(OP_BUY, OP_SELL);
               reset_adjust_max_min_price_time();
               break;
           }
         break;
      case 1:
         delete_orders(order_type1, order_type2);
         reset_adjust_max_min_price_time();
         break;
      case 2:
         if(adjust != 0)
            adjust_orders(order_type1, order_type2);
         break;
     }
  }

//+------------------------------------------------------------------+
//| Reset max_price, min_price, and reset_time                       |
//+------------------------------------------------------------------+
void reset_adjust_max_min_price_time()
  {
   adjust = 0;
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
   double mid_price = (max_price + min_price) / 2;
   return Ask + Point < mid_price || mid_price < Bid - Point || (max_price - min_price) / Point < MarketInfo(_Symbol, MODE_SPREAD) + MarketInfo(_Symbol, MODE_STOPLEVEL);
  }

//+------------------------------------------------------------------+
//| Send an order of given type. Changes last_trade if successful.   |
//+------------------------------------------------------------------+
void send_order(int type)
  {
   switch(type)
     {
      case OP_BUYSTOP:
      case OP_SELLLIMIT:
         if(0 <= OrderSend(_Symbol, type, lot, max_price, 0, 0, 0))
           {
            max_price = Ask;
           }
         break;
      case OP_SELLSTOP:
      case OP_BUYLIMIT:
         if(0 <= OrderSend(_Symbol, type, lot, min_price, 0, 0, 0))
           {
            min_price = Bid;
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
   comment += space + "Mid points for max/min = " + DoubleToString((max_price + min_price) / 2, Digits) + ", for Ask/Bid = " + DoubleToString((Ask + Bid) / 2, Digits);
   comment += space + "Spreads for max/min = " + IntegerToString((int)((max_price - min_price) / Point)) + ", for Ask/Bid = " + IntegerToString((int)((Ask - Bid) / Point));
   comment += space + "Market info spread = " + IntegerToString((int) MarketInfo(_Symbol, MODE_SPREAD)) + ", stop level = " + IntegerToString((int) MarketInfo(_Symbol, MODE_STOPLEVEL));
   comment += space + "Time since reset = " + formatted_time(time_since_reset());
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
   double new_sl;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      switch(OrderType())
        {
         case OP_BUY:
            new_sl = OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice());
            new_sl = Point * MathRound(new_sl / Point);
            if((OrderOpenPrice() < new_sl) && (OrderStopLoss() < new_sl))
              {
               if(OrderModify(ticket, OrderOpenPrice(), new_sl, 0.0, 0)) {}
              }
            break;
         case OP_SELL:
            new_sl = OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            new_sl = Point * MathRound(new_sl / Point);
            if((new_sl < OrderOpenPrice()) && ((new_sl < OrderStopLoss()) || (OrderStopLoss() == 0)))
              {
               if(OrderModify(ticket, OrderOpenPrice(), new_sl, 0.0, 0)) {}
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
   if(max_price < Ask)
     {
      adjust = Ask - max_price;
      max_price = Ask;
     }
   if(Bid < min_price)
     {
      adjust = Bid - min_price;
      min_price = Bid;
     }
  }

//+------------------------------------------------------------------+

