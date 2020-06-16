//+------------------------------------------------------------------+
//|                                                    Bystruev9.mq4 |
//|                 Copyright © 2009, Denis Bystruev, 19-26 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 19-26 Feb 2009"
#property link      "http://www.moeradio.ru"

#include <stderror.mqh>
#include <stdlib.mqh>

extern double  FlushLose      =  0.5;  // start over if our balance is 50% of start balance
extern double  FlushWin       =  4;    // start over once our balance is 4X higher
extern double  LotFactor      =  2.0;  // factor when multiplying lot size
extern double  LotStep        =  0.0;  // incremental value when increasing lot size
extern int     OrderDelta     =  50;   // difference between buy sell and stop sell orders
extern double  StopLossFactor =  0.5;  // set trailing stop loss at 50% of the won profit

double   CurrentEquity;             // the current account equity
double   CurrentLot;                // the current lot size we work with
datetime EmailTime;                 // the time when the last e-mail was sent
datetime EmailPeriod = 3600;        // how often to send e-mails in seconds
datetime LastTime;                  // time when the script was run last time
double   MaxEquity;                 // the maximum equity we reached
double   OldBid;                    // the previous value of Bid
double   TimeDelay;                 // current delay depending on TimePeriod
datetime TimePeriod     =  0;       // how often to trade in seconds, 0 - as often as ticks come
double   Zero           =  0.00001; // very low number to compare double numbers

//+------------------------------------------------------------------+
//| Find first order with given parameters                           |
//| If not found return -1, if found - order ticket                  |
//+------------------------------------------------------------------+
int find_order(int type, double volume, double& price)
{
   for (int i = 0; i < OrdersTotal(); i++ )
   {
      if (OrderSelect(i, SELECT_BY_POS))
      {
         if ((OrderType() == type) && (MathAbs(OrderLots() - volume) < Zero))
         {
            price = OrderOpenPrice();
            return (OrderTicket());
         }
      }
   }
   price = 0.0;
   return (-1);
}

//+------------------------------------------------------------------+
//| Open sell stop order below Bid and buy stop order above Ask      |
//+------------------------------------------------------------------+
void buy_sell()
{
   double buy_price, sell_price, buystop_price, sellstop_price, stop_loss;
   int buystop_order = find_order(OP_BUYSTOP, CurrentLot, buystop_price);
   int sellstop_order = find_order(OP_SELLSTOP, CurrentLot, sellstop_price);
   int buy_order = find_order(OP_BUY, CurrentLot, buy_price);
   int sell_order = find_order(OP_SELL, CurrentLot, sell_price);
   double oldMA = iMA(Symbol(), 0, 14, 0, MODE_SMA, PRICE_MEDIAN, 1);
   double newMA = iMA(Symbol(), 0, 14, 0, MODE_SMA, PRICE_MEDIAN, 0);

   if ((buy_order < 0) && (sell_order < 0) && (buystop_order < 0) && (sellstop_order < 0))
   {
      change_current_lot();
//      Print("oldMA = " + oldMA + "  newMA = " + newMA);
      sellstop_price = Point * MathFloor((Ask + Bid - OrderDelta * Point) / 2.0 / Point);
      buystop_price = sellstop_price + OrderDelta * Point;
//      Print("sellstop_price = " + sellstop_price + "  buystop_price = " + buystop_price);
      buystop_order = OrderSend(Symbol(), OP_BUYSTOP, CurrentLot, buystop_price, 0, 0.0, 0.0);
      if (buystop_order >= 0)
         OrderSend(Symbol(), OP_SELLSTOP, CurrentLot, sellstop_price, 0, 0.0, 0.0);
      return;
   }
   
   if ((buy_order >= 0) && (sell_order >=0))
   {
      OrderCloseBy(buy_order, sell_order);
      return;
   }
   
   if (buy_order >= 0)
   {
      stop_loss = Bid - Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
      if (buy_price < stop_loss)
      {
         if (OrderSelect(buy_order, SELECT_BY_TICKET))
            if (MathAbs(OrderStopLoss()) > Zero)
               stop_loss = Point * MathFloor((buy_price + StopLossFactor * (stop_loss - buy_price)) / Point);
            if ((MathAbs(OrderStopLoss()) < Zero) || (OrderStopLoss() < stop_loss))
               if (OrderModify(buy_order, buy_price, stop_loss, 0.0, 0))
                  if (sellstop_order >= 0)
                     OrderDelete(sellstop_order);
      } else if (sellstop_order < 0)
         OrderSend(Symbol(), OP_SELLSTOP, CurrentLot, buy_price - OrderDelta * Point, 0.0, 0.0, 0.0);
      return;
   }
   
   if (sell_order >= 0)
   {
      stop_loss = Ask + Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
      if (stop_loss < sell_price)
      {
         if (OrderSelect(sell_order, SELECT_BY_TICKET))
            if (MathAbs(OrderStopLoss()) > Zero)
               stop_loss = Point * MathFloor((sell_price - StopLossFactor * (sell_price - stop_loss)) / Point);
            if ((MathAbs(OrderStopLoss()) < Zero) || (stop_loss < OrderStopLoss()))
               if (OrderModify(sell_order, sell_price, stop_loss, 0.0, 0))
                  if (buystop_order >= 0)
                     OrderDelete(buystop_order);
      } else if (buystop_order < 0)
         OrderSend(Symbol(), OP_BUYSTOP, CurrentLot, sell_price + OrderDelta * Point, 0.0, 0.0, 0.0);  
      return;
   }
   
   if ((buystop_order >= 0) && (sellstop_order >= 0))
   {
      double Delta = Bid - OldBid;
      double stoplevel = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
      OldBid = Bid;
      if (MathAbs(Delta) < Zero) return;
      if (((newMA < oldMA) && (Delta > 0)) || ((oldMA < newMA) && (Delta < 0)))
      {
         buystop_price -= 2.0 * Delta;
         sellstop_price -= 2.0 * Delta;
         if ((sellstop_price < Bid - stoplevel) && (Ask + stoplevel < buystop_price))
         {
            if ((Delta < 0))
            {
               if (update_stop_order(sellstop_order, sellstop_price))
                  update_stop_order(buystop_order, buystop_price);
            } else {
               if (update_stop_order(buystop_order, buystop_price))
                  update_stop_order(sellstop_order, sellstop_price);
            }
         }
      }
      TimeDelay = TimePeriod;
      return;
   }

   if (buystop_order >= 0)
   {
      if (Ask < buystop_price - OrderDelta * Point)
      {
         OrderDelete(buystop_order);
      } else
         OrderSend(Symbol(), OP_SELLSTOP, CurrentLot, buystop_price - OrderDelta * Point, 0.0, 0.0, 0.0);
      return;
   }
   
   if (sellstop_order >= 0)
   {
      if (sellstop_price + OrderDelta * Point < Bid)
      {
         OrderDelete(sellstop_order);
      } else
         OrderSend(Symbol(), OP_BUYSTOP, CurrentLot, sellstop_price + OrderDelta * Point, 0.0, 0.0, 0.0);
      return;
   }
}

//+------------------------------------------------------------------+
//| Update stop order                                                |
//+------------------------------------------------------------------+
bool update_stop_order(int order_ticket, double price)
{
   if (OrderSelect(order_ticket, SELECT_BY_TICKET))
   {
      return (OrderModify(order_ticket, price, 0.0, 0.0, 0));
   }
   return (False);
}

//+------------------------------------------------------------------+
//| Change lot size                                                  |
//+------------------------------------------------------------------+
void change_current_lot()
{
      double gain = AccountEquity() - CurrentEquity;
      double LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
      double MaxLot = MarketInfo(Symbol(), MODE_MAXLOT);
      double MinLot = MarketInfo(Symbol(), MODE_MINLOT);
      
      if (MathAbs(gain) < Zero) return;
      MinLot = MathMax(MinLot, LotStep * MathFloor(AccountFreeMargin() / MarketInfo(Symbol(), MODE_MARGINREQUIRED) / LotStep / 8.0));
      MaxLot = MathMin(MaxLot, LotFactor * LotFactor * MinLot + 10.0 * LotStep);
      if (gain < 0)
      {
         CurrentLot = MathMin(MaxLot, MathMax(MinLot, LotStep * MathRound((LotFactor * CurrentLot + LotStep) / LotStep)));
         if (AccountFreeMargin() < CurrentLot * MarketInfo(Symbol(), MODE_MARGINREQUIRED))
            CurrentLot = MinLot;
      } else {
         if (MaxEquity < AccountEquity()) {
            MaxEquity = AccountEquity();
            CurrentLot = MathMin(MaxLot, MathMax(MinLot, LotStep * MathRound(((CurrentLot - LotStep) / LotFactor) / LotStep)));
         }
      }
      CurrentEquity = AccountEquity();
      Email();
}

//+------------------------------------------------------------------+
//| Sends e-mail with account information                            |
//+------------------------------------------------------------------+
void Email()
{
      string   Subject  = "Equity: " + DoubleToStr(AccountEquity(), 2);
      string   Text     = "Lot: " + DoubleToStr(CurrentLot, 2);
      
      Text = Text + "\nBid: " + DoubleToStr(Bid, Digits);
      Text = Text + "\nAsk: " + DoubleToStr(Ask, Digits);
      for (int i = 0; i < OrdersTotal(); i++)
      {
         if (OrderSelect(i, SELECT_BY_POS))
         {
            switch (OrderType())
            {
               case OP_BUY:
                  Text = Text + "\nBuy ";
                  break;
               case OP_SELL:
                  Text = Text + "\nSell ";
                  break;
               case OP_BUYLIMIT:
                  Text = Text + "\nBuy Limit ";
                  break;
               case OP_SELLLIMIT:
                  Text = Text + "\nSell Limit ";
                  break;
               case OP_BUYSTOP:
                  Text = Text + "\nBuy Stop ";
                  break;
               case OP_SELLSTOP:
                  Text = Text + "\nSell Stop ";
                  break;
            }
            Text = Text + DoubleToStr(OrderOpenPrice(), Digits) + " ";
            Text = Text + DoubleToStr(OrderStopLoss(), Digits) + " ";
            Text = Text + DoubleToStr(OrderTakeProfit(), Digits);
         }
      }
      SendMail(Subject, Text);
      EmailTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| If we won or lost enough flush all orders and restart            |
//+------------------------------------------------------------------+
void check_win_lose()
{
   if ((FlushWin * CurrentEquity < AccountEquity()) || (AccountEquity() < FlushLose * CurrentEquity))
      close_all_orders();
}

//+------------------------------------------------------------------+
//| Close all orders, executed or not                                |
//+------------------------------------------------------------------+
void close_all_orders()
{
   while (OrdersTotal() > 0)
   {
      for (int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if (OrderSelect(i, SELECT_BY_POS))
         {
            switch (OrderType())
            {
               case OP_BUY:
               case OP_SELL:
                  if (!OrderClose(OrderTicket(), OrderLots(), Bid, 100))
                     if (!OrderClose(OrderTicket(), OrderLots(), Ask, 100))
                        Print("Error when closing order " + OrderTicket() + ": " + ErrorDescription(GetLastError()) + ". Price = " + OrderOpenPrice());
                  break;
               case OP_BUYLIMIT:
               case OP_BUYSTOP:
               case OP_SELLLIMIT:
               case OP_SELLSTOP:
                  OrderDelete(OrderTicket());
                  break;
            }
         } else {
            Print("Can not close orders: " + ErrorDescription(GetLastError()));
         }
      }
   }
}


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   close_all_orders();
   CurrentEquity = 0.0;
   CurrentLot = 0.0;
   MaxEquity = 0.0;
   change_current_lot();
   LastTime = TimeCurrent();
   OldBid = Bid;
   TimeDelay = 0;
//----
   return;
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   close_all_orders();   
//----
   return;
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
   if(TimeCurrent() >= EmailTime + EmailPeriod) Email();
   if(TimeCurrent() < LastTime + TimeDelay) return;
   TimeDelay = 0;
   check_win_lose();
   buy_sell();
   LastTime = TimeCurrent();
//   Print("TimeDelay = " + TimeDelay + " seconds");
//----
   return;
  }
//+------------------------------------------------------------------+