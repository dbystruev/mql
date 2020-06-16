//+------------------------------------------------------------------+
//|                                                    Bystruev6.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 23 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 23 Feb 2009"
#property link      "http://www.moeradio.ru"

// Идея этого эксперта в следующем.
// Отслеживаем, в течение какого количества тиков цена идёт в одном направлении.
// Как только это количество превысит заданное значение (max_ticks), действуем в том же направлении
// Если угадали - trailing stop, если не угадали - просто stop loss

extern int  max_ticks   = 4;  // сколько раз цена должна идти в одном направлении
extern int  max_move    = 25; // после сдвига на какое количество тиков можно действовать

int         direction;        // направление движения цены: -1 - вниз, 0 - неизменно, 1 - вверх
double      last_bid;         // предыдущая цена bid
double      lot;              // текущий размер лота
int         move;             // на какое количество пунктов сдвинулась цена
double      stop_loss;        // размер стоп-лосса
int         ticks;            // количество тиков в одном направлении

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   direction_ticks(0, 0);                                      // направление движения цены не знаем, обнуляем кол-во тиков
   last_bid = Bid;                                             // запоминаем текущую цену
   lot = MarketInfo( Symbol(), MODE_MINLOT );                  // устанавливаем минимально возможный размер лота
   stop_loss = MarketInfo( Symbol(), MODE_STOPLEVEL ) * Point; // устанавливаем минимально возможный стоп-лосс
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   double   new_bid = Bid;                                     // запоминаем текущее значение цены bid
   switch ( direction ) {
      case -1:                                                 // направление движения было вниз
         if ( new_bid < last_bid ) ticks++;                    // цена продолжает двигаться вниз
         if ( last_bid < new_bid ) direction_ticks( 1, 1 );    // цена пошла вверх
         break;
      case 0:                                                  // начало или цена не двигалась
         if ( new_bid < last_bid ) direction_ticks( -1, 1 );   // цена движется вниз
         if ( last_bid < new_bid ) direction_ticks( 1, 1);     // цена движется вверх
         break;
      case 1:                                                  // направление движения было вверх
         if ( new_bid < last_bid ) direction_ticks( -1, 1 );   // цена пошла вниз
         if ( last_bid < new_bid ) ticks++;                    // цена продолжает двигаться вверх
         break;
   }
   move += MathAbs( MathRound(( last_bid - new_bid ) / Point ));
   last_bid = new_bid;                                         // запоминаем текущую цену bid
   if ( OrdersTotal() == 0 ) {                                 // ордеров нет - можно устанавливать новый
      change_lot();                                            // изменяем размер лота
      if(( ticks >= max_ticks ) && ( move >= max_move )) send_order();                   // количество тиков в одном направлении достигло нужного
   }
   if ( OrdersTotal() > 0 ) update_order();                    // обновляем стоп-лосс
}
//+------------------------------------------------------------------+
//| устанавливает направление direction и число тиков ticks          |
//+------------------------------------------------------------------+
void direction_ticks ( int d, int t ) {
   direction = d;
   ticks = t;
   move = 0;
}
//+------------------------------------------------------------------+
//| изменяем размер лота                                             |
//+------------------------------------------------------------------+
void change_lot() {
}
//+------------------------------------------------------------------+
//| открывает ордер в нужном нам направлении                         |
//+------------------------------------------------------------------+
void send_order() {
   switch ( direction ) {
      case -1:                                                 // цена идёт вниз - открываем ордер на продажу
         while( !OrderSend( Symbol(), OP_SELL, lot, Bid, 0, Ask + stop_loss, 0.0 )) {}
         break;
      case 1:                                                  // цена идёт вверх - открываем ордер на покупку
         while( !OrderSend( Symbol(), OP_BUY, lot, Ask, 0, Bid - stop_loss, 0.0 )) {}
         break;
   }
}
//+------------------------------------------------------------------+
//| устанавливает stop loss или трейлинг стоп на открытый ордер      |
//+------------------------------------------------------------------+
void update_order() {
   double   new_stop_loss;                                     // новое значение stop loss
   if ( OrderSelect( 0, SELECT_BY_POS )) {                     // считаем, что у нас только один ордер
      switch ( OrderType() ) {                                 // тип ордера либо buy, либо sell
         case OP_BUY:
            new_stop_loss = Bid - stop_loss;
            if ( OrderStopLoss() < new_stop_loss )
               OrderModify( OrderTicket(), OrderOpenPrice(), new_stop_loss, 0.0, 0 );
            break;
         case OP_SELL:
            new_stop_loss = Ask + stop_loss;
            if ( new_stop_loss < OrderStopLoss() )
               OrderModify( OrderTicket(), OrderOpenPrice(), new_stop_loss, 0.0, 0 );
            break;
      }
   }
}