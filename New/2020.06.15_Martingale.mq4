//+------------------------------------------------------------------+
//|                                        2020.06.15_Martingale.mq4 |
//|                 Copyright 2020, Denis Bystruev, dbystruev@me.com |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+

#property copyright "Copyright 2020, Denis Bystruev, dbystruev@me.com"
#property link      "https://github.com/dbystruev"
#property version   "1.00"
#property strict

#import "stdlib.mqh"
string ErrorDescription(int error_code);
#import

//--- input parameters
input double input_lot = 0.01;      // initial lot
input double lot_add = 0.01;        // lot addition
input double lot_factor = 1;        // lot multiplicator
input double input_balance = 0;     // maximum account balance
input double spread_factor = 2;     // spread factor
input double input_spread = 10;     // starting spread
input double trailing_level = 0.5;  // trailing level

//--- global variables
string error = "";
double lot_start = MathMax(MarketInfo(Symbol(), MODE_MINLOT), input_lot);
double max_balance = MathMax(AccountBalance(), input_balance);
int spread_start = (int) MathMax(3 * MarketInfo(_Symbol, MODE_SPREAD), input_spread);

double current_lot = lot_start;
int current_spread = spread_start;
double previous_lot = current_lot;
int previous_spread = current_spread;

//+------------------------------------------------------------------+
//| Delete the orders of given types. Returns true if deleted.       |
//+------------------------------------------------------------------+
bool delete_orders(int order_type1, int order_type2)
  {
   bool result = true;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == order_type1) || (OrderType() == order_type2))
           {
            result = result && OrderDelete(OrderTicket());
           }
        }
     }
   if(!result)
     {
      error = "\nERROR in delete_orders(" + string(order_type1) + ", " + string(order_type2) + "): " + ErrorDescription(GetLastError());
     }
   return result;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
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
   max_balance = MathMax(AccountBalance(), max_balance);
   Comment("Max balance = ", max_balance, "\nCurrent lot = ", current_lot, "\nCurrent spread = ", current_spread, error);

// Main loop
   switch(total_orders(OP_BUYSTOP, OP_SELLSTOP))
     {
      case 0:
         switch(total_orders(OP_BUY, OP_SELL))
           {
            case 0:
               send_orders(OP_BUYSTOP, OP_SELLSTOP);
               break;
            default:
               if(max_balance < AccountEquity())
                 {
                  trail_orders(OP_BUY, OP_SELL);
                 }
               break;
           }
         break;
      case 1:
         delete_orders(OP_BUYSTOP, OP_SELLSTOP);
         break;
      default:
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
   switch(type)
     {
      case OP_BUYSTOP:
         price    = (Ask + Bid) / 2 + Point * current_spread;
         price    = Point * MathRound(price / Point);
         price    = MathMax(price, Ask + Point * current_spread);
         result   = OrderSend(_Symbol, type, current_lot, price, 0, price - Point * current_spread, price + Point * current_spread);
         break;
      case OP_SELLSTOP:
         price    = (Ask + Bid) / 2 - Point * current_spread;
         price    = Point * MathRound(price / Point);
         price    = MathMin(price, Bid - Point * current_spread);
         result   = OrderSend(_Symbol, type, current_lot, price, 0, price + Point * current_spread, price - Point * current_spread);
         break;
     }
   if(result < 0)
     {
      error = "\nERROR in send_order(" + string(type) + "): " + ErrorDescription(GetLastError());
     }
   return result;
  }

//+------------------------------------------------------------------+
//| Send orders of given types                                       |
//+------------------------------------------------------------------+
void send_orders(int type1, int type2)
  {
   if (AccountBalance() < max_balance) {
      current_lot = lot_factor * current_lot + lot_add;
      current_spread = (int) spread_factor * current_spread;
   } else {
      current_lot = lot_start;
      current_spread = spread_start;
   }
   if(0 < send_order(type1) && 0 < send_order(type2))
     {
      previous_lot = current_lot;
      previous_spread = current_spread;
     }
  }

//+------------------------------------------------------------------+
//| Number of orders of given types                                  |
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
//| Trail buy or sell order. Returns true if trail successfull       |
//+------------------------------------------------------------------+
bool trail_order(int ticket)
  {
   bool result = false;
   double stoploss;
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      bool profitable = max_balance < AccountBalance() + trailing_level * (AccountEquity() - AccountBalance());
      switch(OrderType())
        {
         case OP_BUY:
            stoploss = OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice());
            stoploss = Point * MathRound(stoploss / Point);
            stoploss = MathMin(stoploss, Bid - Point * current_spread);
            if((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss) && profitable)
              {
               result = OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0);
              }
            break;
         case OP_SELL:
            stoploss = OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            stoploss = Point * MathRound(stoploss / Point);
            stoploss = MathMax(stoploss, Ask + Point * current_spread);
            if((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss()) && profitable)
              {
               result = OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0);
              }
            break;
        }
     }
   if(!result)
     {
      error = "\nERROR in trail_order(" + string(ticket) + "): " + ErrorDescription(GetLastError());
     }
   return result;
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
