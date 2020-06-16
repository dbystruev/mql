//+------------------------------------------------------------------+
//|                                                     Bystruev.mq4 |
//|                 Copyright © 2009, Denis Bystruev, 13-19 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 13-19 Feb 2009"
#property link      "http://www.moeradio.ru"

extern   double   Delta = 0.0004;   // delta between buy order and sell order = 2 * Delta + 0.0002

string   MySymbol;         // currency symbol, e. g. EURUSD
int      BuyOrder;         // ticket number for buy stop order
int      SellOrder;        // ticket number for sell stop order
double   BuyPrice;         // price at which BuyOrder is executed
double   SellPrice;        // price at which SellOrder is executed
double   BuyStopLoss;      // stop loss price for BuyOrder
double   SellStopLoss;     // stop loss price for SellOrder
double   BuyTakeProfit;    // take profit price for BuyOrder
double   SellTakeProfit;   // take profit price for SellOrder
double   Lot = 0.1;        // current lot size
double   MaxBalance;       // maximum balance

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
   MySymbol = Symbol();
   MaxBalance = AccountBalance();
   BuyOrder = -1;          // makes sure buy stop order is executed
   SellOrder = -1;         // makes sure sell stop order is executed
   int i;                  // counter for the cycle
   if (OrdersTotal() > 2)  // if there are too many orders try to delete some
   {
      for (i = 0; i < OrdersTotal(); i++)
      {
         if (OrderSelect(i, SELECT_BY_POS))
         {
            switch (OrderType())
            {
               case OP_BUYSTOP:
               case OP_BUYLIMIT:
               case OP_SELLSTOP:
               case OP_SELLLIMIT:   // at first delete non-market orders only
                  OrderDelete(OrderTicket());
                  break;
            }
         }
      }
   }
   if (OrdersTotal() > 2)  // if there are still too many orders try to close some
   {
      for (i = 0; i < OrdersTotal(); i++)
      {
         if (OrderSelect(i, SELECT_BY_POS))
         {
            switch (OrderType())
            {
               case OP_BUY:
               case OP_SELL:        // now we close market orders only
                  OrderClose(OrderTicket(), OrderLots(), (Bid + Ask) / 2, 1000);
                  break;
            }
         }
      }
   }
   for (i = 0; i < OrdersTotal(); i++)    // now obtain information about remaining orders if any
   {
      if (OrderSelect(i, SELECT_BY_POS))
      {
         Lot = OrderLots();
         switch (OrderType())
         {
            case OP_BUY:         // we don't operate with buy limit orders
            case OP_BUYSTOP:
               BuyOrder = OrderTicket();
               BuyPrice = OrderOpenPrice();
               BuyStopLoss = OrderStopLoss();
               BuyTakeProfit = OrderTakeProfit();
               if (BuyStopLoss < Delta) BuyStopLoss = BuyPrice;         // in case BuyStopLoss is 0 or close
               if (BuyTakeProfit < Delta) BuyTakeProfit = BuyPrice;     // in case BuyTakeProfit is 0 or close
               break;
            case OP_SELL:        // we don't operate with sell limit orders
            case OP_SELLSTOP:
               SellOrder = OrderTicket();
               SellPrice = OrderOpenPrice();
               SellStopLoss = OrderStopLoss();
               SellTakeProfit = OrderTakeProfit();
               if (SellStopLoss < Delta) SellStopLoss = SellPrice;      // in case SellStopLoss is 0 or close
               if (SellTakeProfit < Delta) SellTakeProfit = SellPrice;  // in case SellTakeProfit is 0 or close
               break;
         }
      }
   }
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
   double   NewStopLoss;      // new value of stop loss
   double   NewTakeProfit;    // new value of take profit
   
   switch (OrdersTotal())     // there could be 0, 1, or 2 orders
   {
      case 0:                 // no orders yet, we create both
         BuyOrder = -1;
         SellOrder = -1;
         OpenOrders();
         break;
      case 1:                 // one order, need to re-create another
         if (OrderSelect(0, SELECT_BY_POS))
         {
            Lot = OrderLots();
            switch (OrderType())
            {
               case OP_BUY:
               case OP_BUYSTOP:     // buy order exists, need to re-create sell order
                  SellOrder = -1;
                  break;
               case OP_SELL:
               case OP_SELLSTOP:    // sell order exists, need to re-create buy order
                  BuyOrder = -1;
                  break;
            }
         }
         OpenOrders();
         break;
      case 2:              // two orders
         if (BuyOrder > 0)          // at first work with the buy order
         {
            if (OrderSelect(BuyOrder, SELECT_BY_TICKET))
            {
               if (OrderType() == OP_BUYSTOP)         // buy stop order is not yet executed
               {
                  if (OrderSelect(SellOrder, SELECT_BY_TICKET))
                  {
                     if ((OrderType() == OP_SELLSTOP) || (Ask + Delta < BuyPrice))  // sell stop order is not yet executed
                     {
                        BuyPrice = Ask + Delta;
                        BuyStopLoss = BuyPrice;
                        BuyTakeProfit = BuyPrice;
                        OrderModify(BuyOrder, BuyPrice, 0.0, 0.0, 0.0);
                     }
                  }
               } else if (BuyPrice < Bid)    // bid went up high
               {
                  NewStopLoss = (BuyPrice + Bid) / 2.0;  // average between BuyPrice and Bid
                  if (BuyStopLoss < NewStopLoss)         // need to change BuyStopLoss
                  {
                     SellTakeProfit += NewStopLoss - BuyStopLoss;
                     BuyStopLoss = NewStopLoss;
                     if (OrderModify(BuyOrder, BuyPrice, BuyStopLoss, 0.0, 0.0))
                     {
                        if (OrderSelect(SellOrder, SELECT_BY_TICKET))
                        {
                           if (OrderType() == OP_SELL)
                           {
//                              SellTakeProfit += Ask - Bid;
                              OrderModify(SellOrder, SellPrice, 0.0, SellTakeProfit, 0.0);
                           }
                        }
                     }
                  }
/*               } else if (Ask + 2 * Delta < BuyPrice - 2 * Delta)   // ask went too low
               {
                  NewTakeProfit = (Ask + BuyPrice) / 2.0;  // average between Ask and BuyPrice
                  if (NewTakeProfit < BuyTakeProfit)         // need to change BuyStopLoss
                  {
                     BuyTakeProfit = NewTakeProfit;
                     OrderModify(BuyOrder, BuyPrice, 0.0, BuyTakeProfit, 0.0);
                  }
*/               }
            }
         }
         if (SellOrder > 0)         // then we work with the sell order
         {
            if (OrderSelect(SellOrder, SELECT_BY_TICKET))
            {
               if (OrderType() == OP_SELLSTOP)        // sell stop order is not ye executed
               {
                  if (OrderSelect(BuyOrder, SELECT_BY_TICKET))
                  {
                     if (OrderType() == OP_BUYSTOP || (SellPrice < Bid - Delta))
                     {
                        SellPrice = Bid - Delta;
                        SellStopLoss = SellPrice;
                        SellTakeProfit = SellPrice;
                        OrderModify(SellOrder, SellPrice, 0.0, 0.0, 0.0);
                     }
                  }
               } else if (Ask < SellPrice)   // ask went down low
               {
                  NewStopLoss = (Ask + SellPrice) / 2.0; // average between Ask and SellPrice
                  if (NewStopLoss < SellStopLoss)        // need to change SellStopLoss
                  {
                     BuyTakeProfit -= SellStopLoss - NewStopLoss;
                     SellStopLoss = NewStopLoss;
                     if (OrderModify(SellOrder, SellPrice, SellStopLoss, 0.0, 0.0))
                     {
                        if (OrderSelect(BuyOrder, SELECT_BY_TICKET))
                        {
                           if (OrderType() == OP_BUY)
                           {
//                              BuyTakeProfit -= Ask - Bid;
                              OrderModify(BuyOrder, BuyPrice, 0.0, BuyTakeProfit, 0.0);
                           }
                        }
                     }
                  }
/*               } else if (SellPrice + 2 * Delta < Bid - 2 * Delta)   // bid went too high
               {
                  NewTakeProfit = (Bid + SellPrice) / 2.0; // average between Bid and SellPrice
                  if (SellTakeProfit < NewTakeProfit)
                  {
                     SellTakeProfit = NewTakeProfit;
                     OrderModify(SellOrder, SellPrice, 0.0, SellTakeProfit, 0.0);
                  }
*/               }
            }
         }
         break;
   }
}
//+------------------------------------------------------------------+
// OpenOrders() function opens a buy stop and/or a sell stop order(s)
//+------------------------------------------------------------------+
void OpenOrders()
{
   if ((BuyOrder < 0) && (SellOrder < 0))   // we only change lot if there are no open orders
   {
      Lot = MathMax(MathRound(AccountFreeMargin() / 100.0) / 10.0, 0.1);
   }
/*   double MinLot = 0.1;
   double MaxLot = MathRound(AccountFreeMargin() / 100.0) / 10.0;   // Lot size
   if (AccountBalance() < MaxBalance)        // if we got less money
   {
      MaxBalance = AccountBalance();
      Lot = MathMin(2.0 * Lot, MaxLot);
   } else if (MaxBalance < AccountBalance()) // if we got more money
   {
      MaxBalance = AccountBalance();
      Lot = MathMax(Lot / 2.0, MinLot);
   }
*/   if (BuyOrder < 0)    // Usually it is -1, meaning there is no buy stop order yet
   {
      BuyPrice = Ask + Delta;
      BuyOrder = OrderSend(MySymbol, OP_BUYSTOP, Lot, BuyPrice, 0.0, 0.0, 0.0);
      BuyStopLoss = BuyPrice;
      BuyTakeProfit = BuyPrice;
   }
   if (SellOrder < 0)   // Usually it is -1, meaning there is no sell stop order yet
   {
      SellPrice = Bid - Delta;
      SellOrder = OrderSend(MySymbol, OP_SELLSTOP, Lot, SellPrice, 0.0, 0.0, 0.0);
      SellStopLoss = SellPrice;
      SellTakeProfit = SellPrice;
   }
}

