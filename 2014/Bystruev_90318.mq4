//+------------------------------------------------------------------+
//|                                               Bystruev_90318.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 18 Mar 2009 |
//|                                                 bystruev@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 18 Mar 2009"
#property link      "bystruev@mail.ru"

int      buy_ticket;    // Ticket for buy order
double   price_max;     // Maximum price
double   price_min;     // Minimum price
int      sell_ticket;   // Ticket for sell order

int init() {
   buy_ticket = -1;
   sell_ticket = -1;
   set_min_max();
}

void set_min_max() {
   price_max   =  Ask;
   price_min   =  Bid;
}

int send_order(int mode, double price_delta) {
   
}

int start() {
   switch (OrdersTotal()) {
      case 0:
         set_min_max();
         buy_ticket  =  send_order(OP_BUYLIMIT, 2 * (price_min - Bid));
         sell_ticket =  send_order(OP_BUYSTOP, 2 * (price_max - Ask));
         break;
   }
}

void update_min_max() {
   price_min   =  MathMin(price_min, Bid);
   price_max   =  MathMax(price_max, Ask);
}