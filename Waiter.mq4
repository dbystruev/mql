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
input double   max_loose      = 0.64;  // maximum to loose from balance (0.1 = 10%)
input double   reset_seconds  = 86400; // seconds to pass to reset stop or limit orders
input double   trailing_level =  0.5;  // trailing level (0...1)
input bool     use_stop_order = false;  // use stop (true) or limit (false) orders

//--- global variables
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
   double new_price;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      switch(OrderType())
        {
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
            new_price = Ask + spread_stoplevel();
            if(OrderOpenPrice() < new_price)
               if(OrderModify(ticket, new_price, 0, 0, 0)) {}
            break;
         case OP_SELLSTOP:
         case OP_BUYLIMIT:
            new_price = Bid - spread_stoplevel();
            if(new_price < OrderOpenPrice())
               if(OrderModify(ticket, new_price, 0, 0, 0)) {}
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
            switch(OrderType())
              {
               case OP_BUY:
                  if(OrderClose(OrderTicket(), OrderLots(), Bid, 0)) {}
                  break;
               case OP_SELL:
                  if(OrderClose(OrderTicket(), OrderLots(), Ask, 0)) {}
                  break;
               default:
                  if(OrderDelete(OrderTicket())) {}
                  break;
              }
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
//| Maximum lot for equity present                                   |
//+------------------------------------------------------------------+
double max_lot_by_equity()
  {
   return AccountEquity() / MarketInfo(_Symbol, MODE_MARGINREQUIRED);
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
               if(price_too_close())
                  return;
               set_lot_size();
               send_orders(order_type1, order_type2);
               reset_max_min_price_time();
               break;
            case 1:
            case 2:
               if(AccountEquity() < (1 - max_loose) * AccountBalance())
                  delete_orders(OP_BUY, OP_SELL);
               else
                  trail_orders(OP_BUY, OP_SELL);
               reset_max_min_price_time();
               break;
           }
         break;
      case 1:
         delete_orders(order_type1, order_type2);
         reset_max_min_price_time();
         break;
      case 2:
         if(time_since_reset() < reset_seconds)
            adjust_orders(order_type1, order_type2);
         else
            delete_orders(order_type1, order_type2);
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
   return max_price - spread_stoplevel() < Ask || Bid < min_price + spread_stoplevel();
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
         if(0 <= OrderSend(_Symbol, type, lot, Ask + spread_stoplevel(), 0, 0, 0)) {}
         break;
      case OP_SELLSTOP:
      case OP_BUYLIMIT:
         if(0 <= OrderSend(_Symbol, type, lot, Bid - spread_stoplevel(), 0, 0, 0)) {}
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
   double lot_step = MarketInfo(_Symbol, MODE_LOTSTEP);
   double max_lot = MarketInfo(_Symbol, MODE_MAXLOT);
   double min_lot = MarketInfo(_Symbol, MODE_MINLOT);
   lot = max_lot_by_equity() / 10;
   lot = lot_step * MathRound(lot / lot_step);
   lot = MathMax(min_lot, lot);
   lot = MathMin(max_lot, lot);
  }

//+------------------------------------------------------------------+
//| Show comments on each tick.                                      |
//+------------------------------------------------------------------+
void show_comments()
  {
   string space = "\n                                             ";
   string comment = space + "Lot size = " + DoubleToString(lot, 2);
   comment += ", max lot by equity = " + DoubleToString(max_lot_by_equity(), 2);
   comment += space + "Max price = " + DoubleToString(max_price, Digits) + ", ask = " + DoubleToString(Ask, Digits);
   comment += ", max price to ask = " + IntegerToString((int) MathRound((max_price - Ask) / Point));
   comment += space + "Min price = " + DoubleToString(min_price, Digits) + ", bid = " + DoubleToString(Bid, Digits);
   comment += ", bid to min price = " + IntegerToString((int) MathRound((Bid - min_price) / Point));
   comment += space + "Mid points for max/min = " + DoubleToString((max_price + min_price) / 2, Digits);
   comment += ", for ask/bid = " + DoubleToString((Ask + Bid) / 2, Digits);
   comment += space + "Spreads for max/min = " + IntegerToString((int)((max_price - min_price) / Point));
   comment += ", for ask/bid = " + IntegerToString((int)((Ask - Bid) / Point));
   comment += space + "Market info spread = " + IntegerToString((int) MarketInfo(_Symbol, MODE_SPREAD));
   comment += ", stop level = " + IntegerToString((int) MarketInfo(_Symbol, MODE_STOPLEVEL));
   comment += space + "Time since reset = " + formatted_time(time_since_reset());
   if(price_too_close())
      comment += space + "Price too close";
   Comment(comment);
  }

//+------------------------------------------------------------------+
//| Market info spread + stop level in points                        |
//+------------------------------------------------------------------+
double spread_stoplevel()
  {
   return Point * (MarketInfo(_Symbol, MODE_SPREAD) + MarketInfo(_Symbol, MODE_STOPLEVEL));
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
      max_price = Ask;
     }
   if(Bid < min_price)
     {
      min_price = Bid;
     }
  }

//+------------------------------------------------------------------+
