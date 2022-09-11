//+------------------------------------------------------------------+
//|                                             Bystruev20090421.mq4 |
//|                 Copyright © 2009, Denis Bystruev, 16-21 Apr 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 16-21 Apr 2009"
#property link      "http://www.moeradio.ru"

extern int     min_delta=20;
extern double  trail_level=0.7;

double   equity;
double   lot;
double   max_ask;
double   min_bid;
int      order_type;
double   stop_level;

int deinit() {
   ObjectsDeleteAll();
}

int init() {
   equity=AccountEquity();
   max_ask=Ask;
   min_bid=Bid;
   order_type=-1;
   stop_level=Point*MarketInfo(Symbol(), MODE_STOPLEVEL);
   ObjectCreate("MaxAsk",OBJ_HLINE,0,TimeCurrent(),max_ask);
   ObjectCreate("MinBid",OBJ_HLINE,0,TimeCurrent(),min_bid);
   ObjectSet("MaxAsk",OBJPROP_COLOR,DarkGreen);
   ObjectSet("MinBid",OBJPROP_COLOR,DarkGreen);
   print_delta(0);
   set_lot_size();
}

double price(double price) {
   return (Point*MathRound(price/Point));
}

void print_delta(int new_value=-1) {
   static int delta;
   int new_delta;
   if(new_value>=0) delta=new_value;
   new_delta=MathRound((max_ask-min_bid)/Point);
   if(new_delta!=delta) {
      ObjectMove("MaxAsk",0,TimeCurrent(),max_ask);
      ObjectMove("MinBid",0,TimeCurrent(),min_bid);
      Print(" Min Bid = "+DoubleToStr(min_bid,Digits)+
      ",  Max Ask = "+DoubleToStr(max_ask,Digits)+",  Delta = "+new_delta);
   }
   delta=new_delta;
}

void set_lot_size() {
   double lot_step=MarketInfo(Symbol(),MODE_LOTSTEP);
   lot=AccountEquity()/MarketInfo(Symbol(),MODE_MARGINREQUIRED)/32.0;
   if(AccountEquity()<equity) {
      lot=2.0*lot;
   } else {
      equity=AccountEquity();
   }
   lot=lot_step*MathRound(lot/lot_step);
   lot=MathMax(lot,MarketInfo(Symbol(),MODE_MINLOT));
   lot=MathMin(lot,MarketInfo(Symbol(),MODE_MAXLOT));
}

int start() {
   int      delta;
   bool     modify=FALSE;
   double   open_price;
   double   stop_loss;
   print_delta();
   max_ask=MathMax(max_ask,Ask);
   min_bid=MathMin(min_bid,Bid);
   open_price=price((max_ask+min_bid)/2.0);
   switch(OrdersTotal()) {
      case 0:
         if(order_type>0) {
            max_ask=Ask;
            min_bid=Bid;
            order_type=-1;
            set_lot_size();
         }
         if(max_ask-min_bid<min_delta*Point) return;
         if(Ask+stop_level<open_price) {
            order_type=OP_BUYSTOP;
            stop_loss=min_bid;
         } else if (open_price<Bid-stop_level) {
            order_type=OP_SELLSTOP;
            stop_loss=max_ask;
         }
         if(order_type>0) {
            if(OrderSend(Symbol(),order_type,lot,open_price,0,stop_loss,0.0)<0) {
               order_type=-1;
            }
         }
         break;
      case 1:
         if(OrderSelect(0,SELECT_BY_POS)) {
            switch(OrderType()) {
               case OP_BUY:
                  open_price=OrderOpenPrice();
                  stop_loss=price(open_price+trail_level*(Bid-open_price));
                  modify=((stop_loss>open_price)&&(stop_loss>OrderStopLoss())&&(stop_loss<(Bid-stop_level)));
                  break;
               case OP_BUYSTOP:
                  stop_loss=min_bid;
                  modify=((open_price<OrderOpenPrice())&&(open_price>(Ask+stop_level)));
                  break;
               case OP_SELL:
                  open_price=OrderOpenPrice();
                  stop_loss=price(open_price-trail_level*(open_price-Ask));
                  modify=((stop_loss<open_price)&&(stop_loss<OrderStopLoss())&&(stop_loss>(Ask+stop_level)));
                  break;
               case OP_SELLSTOP:
                  stop_loss=max_ask;
                  modify=((open_price>OrderOpenPrice())&&(open_price<(Bid-stop_level)));
                  break;
            }
            if(modify) {
               OrderModify(OrderTicket(),open_price,stop_loss,0.0,0);
            }
         }
         break;
   }
}

