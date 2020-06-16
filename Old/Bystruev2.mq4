//+------------------------------------------------------------------+
//|                                                    Bystruev2.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 18 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 18-19 Feb 2009"
#property link      "http://www.moeradio.ru"

#include <stderror.mqh>
#include <stdlib.mqh>

double   CurrentEquity;          // the current account equity
double   CurrentLot;             // the current lot size we work with
double   FlushLose   =  0.5;     // start over if our balance is 50% of start balance
double   FlushWin    =  1.01;    // start over once our balance is 1% higher
double   LotStep     =  0.1;     // steps when incrementing or decrementing lot size
double   MinLot      =  0.1;     // the minimum lot we start with
double   OrderDelta  =  0.0050;  // difference between neighbouring orders, must be multiply of 0.0002
double   Zero        =  0.00001; // very low number to compare double numbers

//+------------------------------------------------------------------+
//| Find first order with given parameters                           |
//| If not found return -1, if found - order ticket
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
//| Close corresponding buy and sell orders if they exist            |
//+------------------------------------------------------------------+
void close_buy_sell()
{
   double PreviousLot = MathMax(CurrentLot - LotStep, MinLot);
   double price;
   int buy_order = find_order(OP_BUY, CurrentLot, price);
   int sell_order = find_order(OP_SELL, CurrentLot, price);
   
   if ((buy_order < 0) && (sell_order < 0))
   {
      buy_order = find_order(OP_BUY, PreviousLot, price);
      sell_order = find_order(OP_SELL, PreviousLot, price);
   }
   if ((buy_order >= 0) && (sell_order >= 0))
   {
      if (OrderCloseBy(buy_order, sell_order))
      {
         close_order(find_order(OP_BUYLIMIT, CurrentLot, price));
         close_order(find_order(OP_SELLLIMIT, CurrentLot, price));
         CurrentLot = MathMax(PreviousLot - LotStep, MinLot);
      }
   }
}

//+------------------------------------------------------------------+
//| Open buy limit order below Bid and sell limit order above Ask    |
//+------------------------------------------------------------------+
void open_buy_sell()
{
   double buy_price;
   double sell_price;
   int buylimit_order = find_order(OP_BUYLIMIT, CurrentLot, buy_price);
   int selllimit_order = find_order(OP_SELLLIMIT, CurrentLot, sell_price);
   int buy_order = find_order(OP_BUY, CurrentLot, buy_price);
   int sell_order = find_order(OP_SELL, CurrentLot, sell_price);

   if ((buylimit_order >= 0) && (selllimit_order >= 0)) return;
   if ((buy_order >= 0) && (sell_order >= 0)) return;
   if ((buylimit_order < 0) && (selllimit_order < 0) && (buy_order < 0) && (sell_order < 0))
   {
      buy_price = OrderDelta * MathFloor((Ask + Bid) / 2.0 / OrderDelta);
      sell_price = buy_price + OrderDelta;
      OrderSend(Symbol(), OP_BUYLIMIT, CurrentLot, buy_price, 0.0, 0.0, 0.0);
      OrderSend(Symbol(), OP_SELLLIMIT, CurrentLot, sell_price, 0.0, 0.0, 0.0);
      return;
   }
   if (buy_order >= 0)
   {
      if (selllimit_order < 0) OrderSend(Symbol(), OP_SELLLIMIT, CurrentLot, buy_price + OrderDelta, 0.0, 0.0, 0.0);
      CurrentLot += LotStep;
      OrderSend(Symbol(), OP_BUYLIMIT, CurrentLot, buy_price - OrderDelta, 0.0, 0.0, 0.0);
      return;
   }
   if (sell_order >= 0)
   {
      if (buylimit_order < 0) OrderSend(Symbol(), OP_BUYLIMIT, CurrentLot, sell_price - OrderDelta, 0.0, 0.0, 0.0);
      CurrentLot += LotStep;
      OrderSend(Symbol(), OP_SELLLIMIT, CurrentLot, sell_price + OrderDelta, 0.0, 0.0, 0.0);
      return;
   }
}

//+------------------------------------------------------------------+
//| If we won or lost enough flush all orders and restart            |
//+------------------------------------------------------------------+
void check_win_lose()
{
      if ((FlushWin * CurrentEquity < AccountEquity()) || (AccountEquity() < FlushLose * CurrentEquity))
      {
         close_all_orders();
      }
      CurrentEquity = AccountEquity();
      MinLot = MathMax(MinLot, MathFloor(CurrentEquity / 1000.0) / 10.0);
}

//+------------------------------------------------------------------+
//| Close or delete an order                                         |
//+------------------------------------------------------------------+
void close_order(int order)
{
   if (order < 0) return;
   if (OrderSelect(order, SELECT_BY_TICKET))
   {
      switch (OrderType())
      {
         case OP_BUY:
         case OP_SELL:
            OrderClose(OrderTicket(), OrderLots(), (Ask + Bid) / 2.0, 0.1);
            break;
         case OP_BUYLIMIT:
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
         case OP_SELLSTOP:
            OrderDelete(OrderTicket());
            break;
      }
   }
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
                  OrderClose(OrderTicket(), OrderLots(), (Ask + Bid) / 2.0, 0.1);
                  break;
               case OP_BUYLIMIT:
               case OP_BUYSTOP:
               case OP_SELLLIMIT:
               case OP_SELLSTOP:
                  OrderDelete(OrderTicket());
                  break;
            }
         } else {
            MessageBox("Can not close orders: " + ErrorDescription(GetLastError()));
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
   CurrentEquity = AccountEquity();
   MinLot = MathMax(MinLot, MathFloor(CurrentEquity / 1000.0) / 10.0);
   CurrentLot = MinLot;
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   close_all_orders();   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
  {
//----
   check_win_lose();
   open_buy_sell();
   close_buy_sell();
//----
   return(0);
  }
//+------------------------------------------------------------------+