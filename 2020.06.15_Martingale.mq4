//+------------------------------------------------------------------+
//|                                        2020.06.15_Martingale.mq4 |
//|                 Copyright 2020, Denis Bystruev, dbystruev@me.com |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+

#property copyright "Copyright 2020, Denis Bystruev, dbystruev@me.com"
#property link      "https://github.com/dbystruev"
#property version   "1.07"
#property strict

#import "stdlib.ex4"
string ErrorDescription(int error_code);
#import

//--- input parameters
input double balance_rate = 100;    // balance which corresponds to initial lot
input double input_lot = 0.01;      // initial lot
input double lot_add = 0.01;        // lot addition/substraction after loss/profit
input double lot_factor = 1;        // lot multiplicator/divider after loss/profit
input double input_balance = 0;     // maximum account balance
input double spread_factor = 2;     // spread multiplicator/divider after loss/profit
input int input_spread = 10;        // starting spread
input double trailing_level = 0.8;  // trailing level
input bool input_use_stop = true;   // use stop (true) or limit (false) orders

//--- independent global variables
bool use_stop_orders = input_use_stop;

//--- dependent global variables
double current_lot;
int current_spread;
string error = "";
int error_count = 0;
double last_balance;
int lot_rate;
double lot_start;
double max_balance;
int order_type1;
int order_type2;
double previous_lot;
int previous_spread;
int spread_start;

//+------------------------------------------------------------------+
//| Delete the orders of given types. Returns true if deleted.       |
//+------------------------------------------------------------------+
bool delete_orders(int type1, int type2)
  {
   bool result = true;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            result = result && OrderDelete(OrderTicket());
           }
        }
     }
   if(!result)
     {
      error = "ERROR in delete_orders(" + string(type1) + ", " + string(type2) + "): " + ErrorDescription(GetLastError());
      error_count = 10;
     }
   return result;
  }

//+------------------------------------------------------------------+
//| Get lot for the given step                                       |
//+------------------------------------------------------------------+
double get_lot(int step)
  {
   return lot_factor == 1
          ? lot_start + (step - 1) * lot_add
          : MathPow(lot_factor, step - 1) * (lot_start + lot_add / (lot_factor - 1)) - lot_add / (lot_factor - 1);
  }

//+------------------------------------------------------------------+
//| Get profit/loss based on current lot, spread, and step           |
//+------------------------------------------------------------------+
double get_profit_loss(int step)
  {
// Point value in deposit currency
   double point_value = Point * MarketInfo(_Symbol, MODE_TICKVALUE) / MarketInfo(_Symbol, MODE_TICKSIZE);
// Amount of potenial profit/loss
   return get_spread(step) * get_lot(step) * lot_rate * point_value;
  }

//+------------------------------------------------------------------+
//| Get spread for the given step                                    |
//+------------------------------------------------------------------+
double get_spread(int step)
  {
   return spread_start * (MathPow(spread_factor, step - 1));
  }

//+------------------------------------------------------------------+
//| Get step from current lot, its start, addition, and factor       |
//+------------------------------------------------------------------+
int get_step()
  {
   return lot_factor == 1
// current_lot == lot_start + (step - 1) * lot_add
// current_lot - lot_start == (step - 1) * lot_add
// (current_lot - lot_start) / lot_add == step - 1
// step == (current_lot - lot_start) / lot_add + 1
          ? (lot_add == 0 ? get_step_from_spread() : (int) MathRound((current_lot - lot_start) / lot_add + 1))
// current_lot == MathPow(lot_factor, step - 1) * (lot_start + lot_add / (lot_factor - 1)) - lot_add / (lot_factor - 1)
// current_lot + lot_add / (lot_factor - 1) == MathPow(lot_factor, step - 1) * (lot_start + lot_add / (lot_factor - 1))
// (current_lot + lot_add / (lot_factor - 1)) / (lot_start + lot_add / (lot_factor - 1)) == MathPow(lot_factor, step - 1)
// MathLog((current_lot + lot_add / (lot_factor - 1)) / (lot_start + lot_add / (lot_factor - 1))) == MathLog(MathPow(lot_factor, step - 1))
// MathLog((current_lot + lot_add / (lot_factor - 1)) / (lot_start + lot_add / (lot_factor - 1))) == (step - 1) * MathLog(lot_factor)
// MathLog((current_lot + lot_add / (lot_factor - 1)) / (lot_start + lot_add / (lot_factor - 1))) / MathLog(lot_factor) == step - 1
// step == MathLog((current_lot + lot_add / (lot_factor - 1)) / (lot_start + lot_add / (lot_factor - 1))) / MathLog(lot_factor) + 1
          : (int) MathRound(MathLog((current_lot + lot_add / (lot_factor - 1)) / (lot_start + lot_add / (lot_factor - 1))) / MathLog(lot_factor) + 1);
  }

//+------------------------------------------------------------------+
//| Calculate step based on current spread, its factor, and start    |
//+------------------------------------------------------------------+
int get_step_from_spread()
  {
// current_spread == spread_start * MathPow(spread_factor, step - 1)
// current_spread / spread_start == MathPow(spread_factor, step - 1)
// MathLog(current_spread / spread_start) == MathLog(MathPow(spread_factor, step - 1))
// MathLog(current_spread / spread_start) == (step - 1) * MathLog(spread_factor)
// MathLog(current_spread / spread_start) / MathLog(spread_factor) == step - 1
// step == MathLog(current_spread / spread_start) / MathLog(spread_factor) + 1
   return (int) MathRound(MathLog(current_spread / spread_start) / MathLog(spread_factor)) + 1;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   update_all();
//---
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   update_balance();
   int step = get_step() - 1;
   double lot = get_lot(step);
   double profit_loss = get_profit_loss(step);
   string space = "\n                                ";
   Comment(
      space, "Last balance = ", last_balance,
      space, "Max balance = ", max_balance,
      space, "Current lot = ", current_lot, " x ", lot_rate, " = ", current_lot * lot_rate,
      space, "Current spread = ", current_spread,
      space, "Previous lot = ", previous_lot, " x ", lot_rate, " = ", previous_lot * lot_rate,
      space, "Previous spread = ", previous_spread,
      space, "Previous step = ", step,
      space, "get_lot(", step, ") = ", lot, " x ", lot_rate, " = ", lot * lot_rate,
      space, "get_spread(", step, ") = ", get_spread(step),
      space, "get_profit_loss(", step, ") = ", profit_loss, ", at ", (int) MathRound(100 * trailing_level), "% = ", profit_loss / trailing_level,
      space, error
   );
// Main loop
   switch(total_orders(order_type1, order_type2))
     {
      case 0:
         switch(total_orders(OP_BUY, OP_SELL))
           {
            case 0:
               send_orders(order_type1, order_type2);
               break;
            default:
               set_lot_spread(OP_BUY, OP_SELL);
               if(last_balance < AccountEquity())
                 {
                  trail_orders(OP_BUY, OP_SELL);
                 }
               break;
           }
         break;
      case 1:
         delete_orders(order_type1, order_type2);
         break;
      default:
         set_lot_spread(order_type1, order_type2);
         break;
     }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Send an order of given type. Returns ticket number or -1         |
//+------------------------------------------------------------------+
int send_order(int type)
  {
   double price;
   int result = 0;
   double spread = use_stop_orders ? spread_start : current_spread;
   int sign = use_stop_orders ? 1 : -1;
   switch(type)
     {
      case OP_BUYSTOP:
      case OP_SELLLIMIT:
         price    = (Ask + Bid) / 2 + Point * spread;
         price    = Point * MathRound(price / Point);
         price    = MathMax(price, Ask + Point * spread);
         result   = OrderSend(_Symbol, type, current_lot * lot_rate, price, 0, price - sign * Point * current_spread, price + sign * Point * current_spread);
         break;
      case OP_BUYLIMIT:
      case OP_SELLSTOP:
         price    = (Ask + Bid) / 2 - Point * spread;
         price    = Point * MathRound(price / Point);
         price    = MathMin(price, Bid - Point * spread);
         result   = OrderSend(_Symbol, type, current_lot * lot_rate, price, 0, price + sign * Point * current_spread, price - sign * Point * current_spread);
         break;
     }
   if(result < 0)
     {
      error = "ERROR in send_order(" + string(type) + "): " + ErrorDescription(GetLastError());
      error_count = 10;
     }
   return result;
  }

//+------------------------------------------------------------------+
//| Send orders of given types                                       |
//+------------------------------------------------------------------+
void send_orders(int type1, int type2)
  {
   if(AccountBalance() < max_balance)
     {
      if(AccountBalance() < last_balance)
        {
         current_lot = lot_factor * previous_lot + lot_add;
         current_spread = (int) MathRound(spread_factor * previous_spread);
        }
      else
         if(last_balance < AccountBalance())
           {
            current_lot = MathMax(lot_start, (previous_lot - lot_add) / lot_factor);
            current_spread = (int) MathRound(MathMax(spread_start, previous_spread / spread_factor));
           }
      last_balance = AccountBalance();
     }
   else
     {
      update_lot_spread();
     }
   if(0 < send_order(type1) && 0 < send_order(type2))
     {
      update_error_last_previous();
     }
  }

//+------------------------------------------------------------------+
//| Set current lot and spread from existing buy/sell order          |
//+------------------------------------------------------------------+
void set_lot_spread(int type1, int type2)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            current_lot = MathMax(MarketInfo(_Symbol, MODE_MINLOT), OrderLots() / lot_rate);
            current_spread = (int) MathRound(MathAbs((OrderOpenPrice() - OrderStopLoss()) / Point));
            update_error_last_previous();
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Number of orders of given types                                  |
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
//| Trail buy or sell order. Returns true if trail successfull       |
//+------------------------------------------------------------------+
bool trail_order(int ticket)
  {
   bool result = false;
   double stoploss;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      int step = get_step() - 1;
      bool profitable = last_balance + get_profit_loss(step) < AccountBalance() + trailing_level * (AccountEquity() - AccountBalance());
      switch(OrderType())
        {
         case OP_BUY:
            stoploss = OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice());
            stoploss = MathMin(stoploss, Bid - Point * spread_start);
            stoploss = Point * MathRound(stoploss / Point);
            if((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss) && profitable)
              {
               result = OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0);
              }
            break;
         case OP_SELL:
            stoploss = OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            stoploss = MathMax(stoploss, Ask + Point * spread_start);
            stoploss = Point * MathRound(stoploss / Point);
            if((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss()) && profitable)
              {
               result = OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0);
              }
            break;
        }
     }
   if(!result)
     {
      int last_error = GetLastError();
      if(last_error != ERR_NO_ERROR)
        {
         error = "ERROR in trail_order(" + string(ticket) + "): " + ErrorDescription(last_error);
         error_count = 10;
        }
     }
   return result;
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
//| Update all variables                                             |
//+------------------------------------------------------------------+
void update_all()
  {
   update_balance();
   update_lot_spread();
   update_error_last_previous();
   update_order_type();
  }

//+------------------------------------------------------------------+
//| Update max balance                                               |
//+------------------------------------------------------------------+
void update_balance()
  {
   max_balance = MathMax(AccountBalance(), input_balance);
  }

//+------------------------------------------------------------------+
//| Update balance, lot, and spread variables                        |
//+------------------------------------------------------------------+
void update_lot_spread()
  {
   lot_start = MathMax(MarketInfo(_Symbol, MODE_MINLOT), input_lot);
   current_lot = lot_start;
   spread_start = (int) MathRound(MathMax(3 * MarketInfo(_Symbol, MODE_SPREAD), input_spread));
   current_spread = spread_start;
   lot_rate = (int) MathMax(MathRound(AccountBalance() / balance_rate), 1);
  }

//+------------------------------------------------------------------+
//| Update error, last, and previous variables                       |
//+------------------------------------------------------------------+
void update_error_last_previous()
  {
   error = 0 < error_count ? error : "";
   error_count = 0 < error_count ? error_count - 1 : 0;
   last_balance = AccountBalance();
   previous_lot = current_lot;
   previous_spread = current_spread;
  }

//+------------------------------------------------------------------+
//| Update order type variables                                      |
//+------------------------------------------------------------------+
void update_order_type()
  {
   order_type1 = use_stop_orders ? OP_BUYSTOP : OP_SELLLIMIT;
   order_type2 = use_stop_orders ? OP_SELLSTOP : OP_BUYLIMIT;
  }
//+------------------------------------------------------------------+
