//+--------------------------------------------------------------------+
//|                                   2014_Bystruev16_stop_average.mq4 |
//| Copyright © 2009 - 2014, Denis Bystruev, 12 Mar 2009 - 16 Jul 2014 |
//|                                                   dbystruev@me.com |
//+--------------------------------------------------------------------+
#property copyright "Copyright © 2009 - 2014, Denis Bystruev, 12 Mar 2009 - 16 Jul 2014"
#property link      "mailto:dbystruev@me.com"

//---- input parameters
extern   int      max_history_ticks = 10000; // after how many ticks to flush average move
extern   int      min_history_ticks =    10; // how many ticks to count in the beginning to calculate average move
extern   double   max_delta_factor  =  30.0; // maximum delta factor between ask (or bid) price and buy stop (or sell stop) order
extern   double   min_delta_factor  =  15.0; // minimum delta factor between ask (or bid) price and buy stop (or sell stop) order
extern   double   risk_level     =     0.05; // how much of AccountEquity() we can loose in one wrong stop loss
extern   double   trailing_level =      0.5; // trail at 50%

double            average_ask_move_sum;      // sum of average moves of ask price
double            average_bid_move_sum;      // sum of average moves of bid price
double            last_ask;                  // previous ask price
double            last_bid;                  // previous bid price
datetime          last_trade;                // time of the last trade
double            lot;                       // current lot size
int               moves_nr;                  // number of moves we use for calculating average move
double            order_delta;               // difference between buy and sell orders
double            stop_level;                // minimum stop level from current price
double            stop_loss;                 // stop loss level
double            tick_size;                 // minimum tick size in points

void adjust_order(int ticket) {
   double old_price, new_max_price, new_min_price, new_price;
   
   if (moves_nr < 1) {
      Comment("Error: moves_nr(" + IntegerToString(moves_nr) + ") < 1");
      return;
   }

   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      old_price = OrderOpenPrice();
      switch (OrderType()) {
         case OP_BUYSTOP:
            new_max_price = Ask + max_delta_factor * average_ask_move_sum / moves_nr;
            new_min_price = Ask + min_delta_factor * average_ask_move_sum / moves_nr;
            if ((old_price < new_min_price) || (new_max_price < old_price)) {
               new_price = (new_max_price + new_min_price) / 2.0;
               new_price = Point * MathRound(new_price / Point);
               new_price = MathMax(new_price, Ask + stop_level + stop_loss);
               if (OrderModify(ticket, new_price, new_price - stop_loss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            break;
         case OP_SELLSTOP:
            new_max_price = Bid - min_delta_factor * average_bid_move_sum / moves_nr;
            new_min_price = Bid - max_delta_factor * average_bid_move_sum / moves_nr;
            if ((old_price < new_min_price) || (new_max_price < old_price)) {
               new_price = (new_max_price + new_min_price) / 2.0;
               new_price = Point * MathRound(new_price / Point);
               new_price = MathMin(new_price, Bid - stop_level - stop_loss);
               if (OrderModify(ticket, new_price, new_price + stop_loss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            break;
      }
   }
}

void adjust_orders(int order_type1, int order_type2) {
   set_order_delta();
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            adjust_order(OrderTicket());
         }
      }
   }
}

void delete_orders(int order_type1, int order_type2) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            bool o = OrderDelete(OrderTicket());
         }
      }
   }
}

void init() {
   history_flush();
   last_ask = -1.0;
   last_bid = -1.0;
   last_trade = 0;
   set_lot_size();
}

void history_flush() {
   delete_orders(OP_BUYSTOP, OP_SELLSTOP);
   average_ask_move_sum = 0.0;
   average_bid_move_sum = 0.0;
   last_ask = Ask;
   last_bid = Bid;
   moves_nr = 0;
}

void history_update() {
   average_ask_move_sum += MathAbs(Ask - last_ask);
   average_bid_move_sum += MathAbs(Bid - last_bid);
   last_ask = Ask;
   last_bid = Bid;
   moves_nr++;
}

void send_order(int type) {
   double new_max_price, new_min_price, new_price;
   
   if (moves_nr < 1) {
      Comment("Error: moves_nr(" + IntegerToString(moves_nr) + ") < 1");
      return;
   }

   switch (type) {
      case OP_BUYSTOP:
         new_max_price = Ask + max_delta_factor * average_ask_move_sum / moves_nr;
         new_min_price = Ask + min_delta_factor * average_ask_move_sum / moves_nr;
         new_price = (new_max_price + new_min_price) / 2.0;
         new_price = Point * MathRound(new_price / Point);
         new_price = MathMax(new_price, Ask + stop_level + stop_loss);
         if (OrderSend(Symbol(), type, lot, new_price, 0, new_price - stop_loss, 0.0) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
      case OP_SELLSTOP:
         new_max_price = Bid - min_delta_factor * average_bid_move_sum / moves_nr;
         new_min_price = Bid - max_delta_factor * average_bid_move_sum / moves_nr;
         new_price = (new_max_price + new_min_price) / 2.0;
         new_price = Point * MathRound(new_price / Point);
         new_price = MathMin(new_price, Bid - stop_level - stop_loss);
         if (OrderSend(Symbol(), type, lot, new_price, 0, new_price + stop_loss, 0.0) >= 0) {
            last_trade = TimeCurrent();
         }
         break;
   }
}

void send_orders(int type1, int type2) {
   set_order_delta();

   send_order(type1);
   send_order(type2);
}

void set_lot_size() {
   double lot_step =  MarketInfo(Symbol(), MODE_LOTSTEP);
   stop_level = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   stop_loss = MathMax(2 * MathAbs(Ask - Bid), stop_level);
   tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
   lot = risk_level * AccountEquity() / (MarketInfo(Symbol(), MODE_TICKVALUE) * stop_loss / tick_size);
   lot = lot_step * MathRound(lot / lot_step);
   lot = MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot = MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
}

void set_order_delta() {
   double avg_delta_factor = (max_delta_factor + min_delta_factor) / 2.0;
   double avg_move_sum = (average_ask_move_sum + average_bid_move_sum) / 2.0;
   
   if (moves_nr < 1) {
      Comment("Error: moves_nr(" + IntegerToString(moves_nr) + ") < 1");
      return;
   }
   
   order_delta = avg_delta_factor * avg_move_sum / moves_nr;
}

void start() {
   double balance_required = MarketInfo(Symbol(), MODE_MARGINREQUIRED) * MarketInfo(Symbol(), MODE_MINLOT);
   
   if (AccountBalance() < balance_required) {
      Comment("No money to trade\nAccount balance: " + DoubleToStr(AccountBalance(), 2) + "\nBalance required: " + DoubleToStr(balance_required, 2));
      return;
   }
   
   if (min_history_ticks < 2) {
      Comment("Wrong parameter: min_history_ticks (" + IntegerToString(min_history_ticks) + ") < 2");
      return;
   }
   
   if (max_history_ticks < min_history_ticks) {
      Comment("Wrong parameter: max_history_ticks (" + IntegerToString(max_history_ticks) + ") < min_history_ticks (" + IntegerToString(min_history_ticks) + ")");
      return;
   }

   if ((last_ask < 0) || (last_bid < 0)) {
      history_flush();
      return;
   }
      
   history_update();

   switch (total_orders(OP_BUYSTOP, OP_SELLSTOP)) {
      case 0:
         switch (total_orders(OP_BUY, OP_SELL)) {
            case 0:
               if (moves_nr <= min_history_ticks) {
                  string comment = "History: " + IntegerToString(moves_nr) + " of " + IntegerToString(min_history_ticks);
                  if (0 < moves_nr) {
                     comment += "\nAverage Ask Move = " + DoubleToStr(average_ask_move_sum / moves_nr, Digits);
                     comment += "\nAverage Bid Move = " + DoubleToStr(average_bid_move_sum / moves_nr, Digits);
                  }
                  Comment(comment);
                  return;
               }
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
         if (max_history_ticks < moves_nr) {
            history_flush();
            return;
         }
         adjust_orders(OP_BUYSTOP, OP_SELLSTOP);
         break;
   }
   datetime last_trade_in = TimeCurrent() - last_trade;
   comment = "History: " + IntegerToString(moves_nr) + " of " + IntegerToString(max_history_ticks);
   if (0 < moves_nr) {
      comment += "\nAverage Ask Move = " + DoubleToStr(average_ask_move_sum / moves_nr, Digits);
      comment += "\nAverage Bid Move = " + DoubleToStr(average_bid_move_sum / moves_nr, Digits);
   }
   comment += "\nLast trade was " + TimeToStr(last_trade_in, TIME_SECONDS) + " hours:minutes:seconds ago";
   Comment(comment);
}

int total_orders(int order_type1, int order_type2) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            total_orders++;
         }
      }
   }
   return (total_orders);
}

void trail_order(int ticket) {
   double stoploss;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
   switch (OrderType()) {
         case OP_BUY:
            stoploss =  MathMax(OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice()), Bid - order_delta / 2.0);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMin(stoploss, Bid - stop_level);
            if ((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss)) {
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            if (Ask + stop_level < OrderOpenPrice()) {
               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice() + tick_size, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            break;
         case OP_SELL:
            stoploss =  MathMin(OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask), Ask + order_delta / 2.0);
            stoploss =  Point * MathRound(stoploss / Point);
            stoploss =  MathMax(stoploss, Ask + stop_level);
            if ((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss())) {
               if (OrderModify(ticket, OrderOpenPrice(), stoploss, 0.0, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            if (OrderOpenPrice() < Bid - stop_level) {
               if (OrderModify(ticket, OrderOpenPrice(), OrderStopLoss(), OrderOpenPrice() - tick_size, 0)) {
                  last_trade = TimeCurrent();
               }
            }
            break;
      }
   }
}

void trail_orders(int order_type1, int order_type2) {
   set_order_delta();

   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if ((OrderType() == order_type1) || (OrderType() == order_type2)) {
            trail_order(OrderTicket());
         }
      }
   }
}