//+------------------------------------------------------------------+
//|                                         Bystruev_Friday_Sell.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 10 Apr 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 10 Apr 2009"
#property link      "http://www.moeradio.ru"

//extern   datetime    open_time   =  D'10.04.2009 21:58';
extern   datetime    open_time   =  D'10.04.2009 21:58';
extern   datetime    close_time  =  D'13.04.2009 00:00';
extern   int         order_type  =  OP_SELL;

double               lot;
int                  order_ticket;

void close_order(int ticket) {
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      switch(ticket) {
         case OP_BUY:
            OrderClose(ticket, OrderLots(), Bid, 0);
            break;
         case OP_SELL:
            OrderClose(ticket, OrderLots(), Ask, 0);
            break;
      }
   }
}

void close_orders() {
   int i;
   for (i = OrdersTotal(); i > 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         close_order(OrderTicket());
      }
   }
}

int init() {
   double   lot_step =  MarketInfo(Symbol(), MODE_LOTSTEP);
   lot   =  0.62 * AccountEquity() / MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   lot   =  lot_step * MathRound(lot / lot_step);
   lot   =  MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot   =  MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
}

int send_order(int type) {
   switch (type) {
      case OP_BUY:
         return (OrderSend(Symbol(), type, lot, Ask, 0, 0.0, 0.0));
      case OP_SELL:
         return (OrderSend(Symbol(), type, lot, Bid, 0, 0.0, 0.0));
   }
   return (-1);
}

int start() {
   if (TimeCurrent() < open_time) return;
   Print ("TimeCurrent() >= open_time");
   if (TimeCurrent() < close_time) {
      if (OrdersTotal() == 0) {
         order_ticket = send_order(order_type);
         if (order_ticket < 0) {
            Print("Error " + GetLastError());
         }
      }
      return;
   }
   Print ("TimeCurrent() >= close_time");
   if (OrdersTotal() > 0) {
      close_orders();
   }
}

