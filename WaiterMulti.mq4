//+------------------------------------------------------------------+
//|                                                  WaiterMulti.mq4 |
//|                                   Copyright 2020, Denis Bystruev |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+

#property copyright "Copyright 2020.07.10, Denis Bystruev"
#property link      "https://github.com/dbystruev"
#property version   "1.00"
#property strict

//--- input parameters
input double   adjust_time_factor = 0.001;// adjust time factor: how much longer to keep orders not movable
input double   loss_step = 0.001;         // loss step to start putting market orders (0.1 = 10%)
input double   lot_equity_factor = 0.001; // lot equity factor for lot setting (0.01 = 1% of max equity)
input double   proximity_factor  = 7;     // proximity factor: how close to orders start moving them
input double   stop_level_factor = 2;     // stop level factor: how far to put orders initially from current price
input double   trailing_level = 0.5;      // trailing level (0...1)
input bool     use_stop_order = true;     // use stop (true) or limit (false) orders

//--- global variables
double         lot;                       // current l ot size
int            max_orders;                // maximum number of BUY and SELL orders
double         max_price;                 // maximum price since last trade
double         min_price;                 // minimum price since last trade
datetime       order_last_move;           // last time the stop/limit orders above the ask and below the bid were moved
datetime       order_next_move;           // next time the stop/limit orders above the ask and below the bid were moved
int            order_type1;               // first order type
int            order_type2;               // second order type
datetime       reset_time;                // time when max_price and min_price were reset

//+------------------------------------------------------------------+
//| Adjust an order with given ticket. Return true if successful.    |
//+------------------------------------------------------------------+
bool adjust_order(int ticket)
  {
   if(OrderSelect(ticket, SELECT_BY_TICKET))
     {
      switch(OrderType())
        {
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
            return OrderModify(ticket, Ask + spread_stoplevel_with_factor(), 0, 0, 0);
         case OP_SELLSTOP:
         case OP_BUYLIMIT:
            return OrderModify(ticket, Bid - spread_stoplevel_with_factor(), 0, 0, 0);
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Adjust the orders of given types.                                |
//+------------------------------------------------------------------+
void adjust_orders(int type1, int type2)
  {
   if(TimeCurrent() < order_next_move())
      return;
   if(proximity_factor * spread_stoplevel() < MathMin(order_to_price(type1, Ask), order_to_price(type2, Bid)))
      return;
   int orders_adjusted = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            if(adjust_order(OrderTicket()))
               orders_adjusted++;
           }
        }
     }
   if(0 < orders_adjusted)
     {
      order_next_move = 2 * TimeCurrent() - order_last_move;
      order_last_move = TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
//| Gap between two given orders.                                    |
//+------------------------------------------------------------------+
double between_orders(int type1, int type2)
  {
   if(order_select(order_type1))
     {
      double first_price = OrderOpenPrice();
      if(order_select(order_type2))
         return MathAbs(OrderOpenPrice() - first_price);
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| Delete/close the orders of given types. Returns true if deleted. |
//+------------------------------------------------------------------+
bool delete_orders(int type1, int type2)
  {
   int deleted_orders = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if((OrderType() == type1) || (OrderType() == type2))
           {
            switch(OrderType())
              {
               case OP_BUY:
                  if(OrderClose(OrderTicket(), OrderLots(), Bid, 0))
                     deleted_orders++;
                  break;
               case OP_SELL:
                  if(OrderClose(OrderTicket(), OrderLots(), Ask, 0))
                     deleted_orders++;
                  break;
               default:
                  if(OrderDelete(OrderTicket()))
                     deleted_orders++;
                  break;
              }
           }
        }
     }
   return 0 < deleted_orders;
  }

//+------------------------------------------------------------------+
//| Distance from initial order to order with step number            |
//+------------------------------------------------------------------+
double distance_for_step(int step)
  {
   if(step < 1)
      return 0;
   return distance_for_step(step - 1) + step * MathPow(2, step - 1);
  }

//+------------------------------------------------------------------+
//| Format time to 00:00:00.                                         |
//+------------------------------------------------------------------+
string formatted_time(datetime time)
  {
   string sign = time < 0 ? "-" : "";
   time = time < 0 ? -time : time;
   return sign + padded_number(TimeHour(time)) + ":"+ padded_number(TimeMinute(time)) + ":"+ padded_number(TimeSeconds(time));
  }

//+------------------------------------------------------------------+
//| Calculate a loss for given step                                  |
//+------------------------------------------------------------------+
double loss_for_step(int step)
  {
   return loss_step * distance_for_step(step);
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
   max_orders = (int) MathRound(1 / loss_step);
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

   int buy_sell_orders = total_orders(OP_BUY, OP_SELL);
   switch(total_orders(order_type1, order_type2))
     {
      case 0:
         switch(buy_sell_orders)
           {
            case 0:
               if(price_too_close())
                  return;
               set_lot_size();
               send_orders(order_type1, order_type2);
               reset_max_min_price_time();
               break;
            default:
               if(buy_sell_orders < max_orders &&
                  AccountEquity() < (1 - loss_for_step(buy_sell_orders)) * AccountBalance())
                 {
                  if(order_select(OP_BUY, OP_SELL))
                    {
                     lot = OrderLots();
                     send_order(OrderType());
                    }
                 }
               else
                 {
                  trail_orders(OP_BUY, OP_SELL);
                  reset_max_min_price_time();
                 }
           }
         break;
      case 1:
         if(0 < buy_sell_orders)
           {
            if(delete_orders(order_type1, order_type2)) {}
           }
         else
           {
            int order_type = 0 < total_orders(order_type1) ? order_type2 : order_type1;
            send_order(order_type);
           }
         break;
      case 2:
         adjust_orders(order_type1, order_type2);
         break;
     }
  }

//+------------------------------------------------------------------+
//| Minimum of bottom_order_next_move and top_order_next_move.       |
//+------------------------------------------------------------------+
datetime order_next_move()
  {
   return TimeCurrent() + (datetime)(adjust_time_factor * (order_next_move - TimeCurrent()));
  }

//+------------------------------------------------------------------+
//| Selects first order of given type. Returns false if not found.   |
//+------------------------------------------------------------------+
bool order_select(int type1, int type2 = -1, bool find_profitable = false)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if(OrderType() == type1 || OrderType() == type2)
           {
            if(find_profitable)
              {
               if(0 < OrderProfit())
                  return true;
              }
            else
               return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Gap between given order and the price.                           |
//+------------------------------------------------------------------+
double order_to_price(int type, double price)
  {
   if(order_select(type))
      return MathAbs(OrderOpenPrice() - price);
   return -1;
  }

//+------------------------------------------------------------------+
//| Reset max_price, min_price, and reset_time                       |
//+------------------------------------------------------------------+
void reset_max_min_price_time()
  {
   max_price = Ask;
   min_price = Bid;
   order_last_move = TimeCurrent();
   order_next_move = order_last_move + 1;
  }

//+------------------------------------------------------------------+
//| Returns number as a string with padded 0 if number < 10.         |
//+------------------------------------------------------------------+
string padded_number(int number)
  {
   return (number < 10 ? "0" : "") + IntegerToString(number);
  }

//+------------------------------------------------------------------+
//| Value corresponding to one point price move for one lot.         |
//+------------------------------------------------------------------+
double point_value()
  {
   return Point * MarketInfo(_Symbol, MODE_TICKVALUE) / MarketInfo(_Symbol, MODE_TICKSIZE);
  }

//+------------------------------------------------------------------+
//| Returns true if current price is too close to max or min price.  |
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
      case OP_BUY:
         if(0 <= OrderSend(_Symbol, type, lot, Ask, 0, 0, 0)) {}
         break;
      case OP_SELL:
         if(0 <= OrderSend(_Symbol, type, lot, Bid, 0, 0, 0)) {}
         break;
      case OP_BUYSTOP:
      case OP_SELLLIMIT:
         if(0 <= OrderSend(_Symbol, type, lot, Ask + spread_stoplevel_with_factor(), 0, 0, 0)) {}
         break;
      case OP_SELLSTOP:
      case OP_BUYLIMIT:
         if(0 <= OrderSend(_Symbol, type, lot, Bid - spread_stoplevel_with_factor(), 0, 0, 0)) {}
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
   lot = lot_equity_factor * max_lot_by_equity();
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
   string comment = "";
   double first_price = 0;
   if(order_select(order_type1))
     {
      comment += space + "Ask to top order: " + IntegerToString((int)(order_to_price(order_type1, Ask) / Point));
      comment += " (need < " + IntegerToString((int)(proximity_factor * spread_stoplevel() / Point)) + " to move)";
     }
   if(order_select(order_type2))
     {
      comment += space + "Bid to bottom order: " + IntegerToString((int)(order_to_price(order_type2, Bid) / Point));
      comment += " (need < " + IntegerToString((int)(proximity_factor * spread_stoplevel() / Point)) + " to move)";
     }
   if(AccountEquity() < AccountBalance())
     {
      comment += space + "Current loss = " + DoubleToString(100 * (1 - AccountEquity() / AccountBalance()), 1) + "%";
      comment += ", loss steps =";
      for(int step = 1; step <= max_orders && loss_for_step(step) < 1; step++)
        {
         comment += " " + DoubleToString(100 * loss_for_step(step), 1) + "%";
        }
     }
   else
      if(AccountBalance() < AccountEquity())
         comment += space + "Current gain = " + DoubleToString(100 * (AccountEquity() / AccountBalance() - 1), 1) + "%";
   comment += space + "Lot = " + DoubleToString(lot, 2);
   comment += ", max lot by equity = " + DoubleToString(100 * lot_equity_factor, 1) + "%";
   comment += " * " + DoubleToString(max_lot_by_equity(), 2);
   comment += space + "Market info spread = " + IntegerToString((int) MarketInfo(_Symbol, MODE_SPREAD));
   comment += ", stop level = " + IntegerToString((int) MarketInfo(_Symbol, MODE_STOPLEVEL));
   if(0 < total_orders(order_type1, order_type2))
     {
      comment += space + "Max price = " + DoubleToString(max_price, Digits) + ", ask = " + DoubleToString(Ask, Digits);
      comment += space + "Min price = " + DoubleToString(min_price, Digits) + ", bid = " + DoubleToString(Bid, Digits);
      comment += space + "Mid points for max/min = " + DoubleToString((max_price + min_price) / 2, Digits);
      comment += ", for ask/bid = " + DoubleToString((Ask + Bid) / 2, Digits);
      int between_orders = (int)(MathRound(between_orders(order_type1, order_type2) / Point));
      if(0 < between_orders)
        {
         comment += space + "There are " + IntegerToString(between_orders) + " points between orders";
        }
      comment += space + "Spreads for max/min = " + IntegerToString((int)((max_price - min_price) / Point));
      comment += ", for ask/bid = " + IntegerToString((int)((Ask - Bid) / Point));
      comment += space + "Orders moved " + formatted_time(TimeCurrent() - order_last_move) + " ago";
      if(TimeCurrent() < order_next_move())
        {
         comment += space + "Orders' next move in ";
         comment += formatted_time(order_next_move() - TimeCurrent());
        }
     }
   if(total_orders() == 0 && price_too_close())
     {
      comment += space + "Price is too close (";
      comment += IntegerToString((int) MathRound((max_price - Ask) / Point)) + " to ask, ";
      comment += IntegerToString((int) MathRound((Bid - min_price) / Point)) + " to bid) to send new orders";
     }
   if(order_select(OP_BUY, OP_SELL, true) && 0 < OrderStopLoss())
     {
      double profit = OrderLots() * point_value() * stop_points();
      comment += space + "Value = " + IntegerToString(stop_points()) + " sl";
      comment += " x " + DoubleToString(point_value(), 2);
      comment += " x " + DoubleToString(OrderLots(), 2) + " lot";
      comment += " = " + DoubleToString(profit, 2);
      comment += " (" + DoubleToString(AccountBalance() + profit, 2) + " total)";
     }
   Comment(comment);
  }

//+------------------------------------------------------------------+
//| Market info spread + stop level in points.                       |
//+------------------------------------------------------------------+
double spread_stoplevel()
  {
   return Point * (MarketInfo(_Symbol, MODE_SPREAD) + MarketInfo(_Symbol, MODE_STOPLEVEL));
  }

//+------------------------------------------------------------------+
//| Spread stop level in points taking into account stop level factor|
//+------------------------------------------------------------------+
double spread_stoplevel_with_factor()
  {
   return Point * MathRound(stop_level_factor * spread_stoplevel() / Point);
  }

//+------------------------------------------------------------------+
//| Stop points for currently selected order.                        |
//+------------------------------------------------------------------+
int stop_points()
  {
   return (int)(MathAbs(OrderOpenPrice() - OrderStopLoss()) / Point);
  }

//+------------------------------------------------------------------+
//| Number of orders of given types.                                 |
//+------------------------------------------------------------------+
int total_orders(int type1 = -1, int type2 = -1)
  {
   int total_orders = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS))
        {
         if(OrderType() == type1 || OrderType() == type2 || type1 < 0)
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
            if(OrderOpenPrice() < new_sl && OrderStopLoss() < new_sl)
              {
               if(OrderModify(ticket, OrderOpenPrice(), new_sl, 0.0, 0)) {}
              }
            break;
         case OP_SELL:
            new_sl = OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask);
            new_sl = Point * MathRound(new_sl / Point);
            if(new_sl < OrderOpenPrice() && (new_sl < OrderStopLoss() || OrderStopLoss() == 0))
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
