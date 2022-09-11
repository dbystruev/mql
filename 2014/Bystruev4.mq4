//+------------------------------------------------------------------+
//|                                                    Bystruev4.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 20 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 20 Feb 2009"
#property link      "http://www.moeradio.ru"

#include <stderror.mqh>
#include <stdlib.mqh>

extern   int   total_orders   =  10;

double   lot;        // Lot size
double   spread;     // Point * spread
double   stoplevel;  // Stop level for stop loss/take profit

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   MathSrand( TimeLocal() );
   lot = MarketInfo( Symbol(), MODE_MINLOT );
   spread = Point * MarketInfo( Symbol(), MODE_SPREAD );
   stoplevel = MarketInfo( Symbol(), MODE_STOPLEVEL );
   
   Print( "MINLOT    = " + MarketInfo( Symbol(), MODE_MINLOT ));
   Print( "SPREAD    = " + MarketInfo( Symbol(), MODE_SPREAD ));
   Print( "STOPLEVEL = " + MarketInfo( Symbol(), MODE_STOPLEVEL ));
   Print( "LOTSIZE   = " + MarketInfo( Symbol(), MODE_LOTSIZE ));
   Print( "TICKVALUE = " + MarketInfo( Symbol(), MODE_TICKVALUE ));
   Print( "TICKSIZE  = " + MarketInfo( Symbol(), MODE_TICKSIZE ));
   Print( "SWAPLONG  = " + MarketInfo( Symbol(), MODE_SWAPLONG ));
   Print( "SWAPSHORT = " + MarketInfo( Symbol(), MODE_SWAPSHORT ));
   Print( "Ask       = " + Ask);
   Print( "Bid       = " + Bid);
   Print( "Point     = " + Point);
}

//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   int      direction   =  MathRand() / ( 32768 / 2 );
   double   price       =  Bid * direction + Ask * ( 1 - direction );
   
   if ( OrdersTotal() < total_orders ) {
      Print ( "Bid = " + Bid + "   Ask = " + Ask + "   direction = " + direction + " lot = " + lot + "   price = " + price );
      if ( OrderSend( Symbol(), direction, lot, price, spread, 0.0, price + ( 1 - 2 * direction ) * spread ) < 0 ) {
         Print( "Order send error: " + ErrorDescription( GetLastError() ));
      }
} 

}
//+------------------------------------------------------------------+