//+------------------------------------------------------------------+
//|                                                    Bystruev5.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 21 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 21-22 Feb 2009"
#property link      "http://www.moeradio.ru"

// На сколько шагов увеличивать при проигрыше
// или уменьшать при выигрыше текущий размер лота
extern int  lot_factor        = 10;     // 0 - размер лота не меняется

// Число пунктов, на которые должен отходить take profit
extern int  take_profit_step  = 50;

// Число пунктов, на которые должен отходить stop loss
extern int  stop_loss_step    = 10;

// Счётчик тиков buy/sell
// если он < 0, у нас было больше buy (take profit при buy + stop loss при sell)
// если он > 0, у нас было больше sell (take profit при sell + stop loss при buy)
// если он = 0, у нас было одинаковое число buy и sell ордеров
int         buy_sell_count;

// Счётчик выигрышей/проигрышей
// если он < 0, у нас было больше проигрышей
// если он > 0, у нас было больше выигрышей
// если он = 0, выигрышей и проигрышей было поровну
int         win_lost_count;

double      balance;             // Текущий денежный баланс счёта
double      min_balance = 0.5;   // Минимальный баланс (от максимально достигнутого)
double      max_balance;         // Максимально достигнутый баланс счёта
double      lot;                 // Текущий размер лота
double      max_lot;             // Максимальный размер лота
double      min_lot;             // Минимальный размер лота
int         order_direction;     // Направление очередного ордера: -1 (buy) или 1 (sell)
double      price;               // Цена последнего ордера
int         ticket;              // Номер ордера

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   MathSrand( TimeLocal() );     // Инициализация генератора случайных чисел
   buy_sell_count = 0;           // Обнуляем счётчик тиков buy/sell
   win_lost_count = 0;           // Обнуляем счётчик выигрышей/проигрышей
   balance = AccountBalance();   // Запоминаем текущий баланс счёта
   max_balance = balance;        // Пока что максимальный баланс равен текущему
   max_lot = MarketInfo( Symbol(), MODE_MAXLOT );  // выставляем максимальный лот
   min_lot = MarketInfo( Symbol(), MODE_MINLOT );  // выставляем минимальный лот
   lot = min_lot;                // начинаем с минимального лота
   order_direction = 0;          // в начале направление нам неизвестно
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
   if ( OrdersTotal() > 0 ) {
      switch ( order_direction ) {
         case -1:
            // если Bid не вышел за оговоренные пределы - ждём, когда выйдет
            if (( price - stop_loss_step * Point < Bid ) && ( Bid < price + take_profit_step * Point )) return;
            // иначе пробуем закрыть buy order
            while( !OrderClose( ticket, lot, Bid, 0 )) {}
            break;
         case 1:
            // если Ask не вышел за оговоренные пределы - ждём, когда выйдет
            if (( price - take_profit_step * Point < Ask ) && ( Ask < price + stop_loss_step * Point )) return;
            // иначе пробуем закрыть sell order
            while( !OrderClose( ticket, lot, Ask, 0 )) {}
            break;
      }
   }
   // если достигли минимального баланса, больше ничего не делаем
   if ( AccountBalance() < min_balance * max_balance ) return;
   // если направление = 0, мы в начале, и счётчики трогать не надо
   if ( order_direction != 0 ) {
      // если баланс увеличился - сработал take profit, если уменьшился - stop loss
      if ( AccountBalance() < balance ) {
         win_lost_count--;    // баланс уменьшился, сработал stop loss, мы проиграли
         // если направление было buy (-1), и мы проиграли, значит, это был sell (+1)
         // если направление было sell (1), и мы проиграли, значит, это был buy (-1)
         buy_sell_count -= order_direction;
         // увеличиваем размер лота из-за проигрыша
         lot = MathMin( max_lot, lot + lot_factor * MarketInfo( Symbol(), MODE_LOTSTEP ));
      } else {
         win_lost_count++;    // баланс увеличился, сработал take profit, мы выиграли
         // если направление было buy (-1), и мы выиграли, значит, это был buy (-1)
         // если направление было sell (1), и мы выиграли, значит, это был sell (+1)
         buy_sell_count += order_direction;
         // уменьшаем размер лота из-за выигрыша
         lot = MathMax( min_lot, lot - lot_factor * MarketInfo( Symbol(), MODE_LOTSTEP ));
      }
   }
   // запоминаем новый баланс, так как ордеров нет, то AccountBalance() = AccountEquity()
   balance = AccountBalance();
   // если превысили максимально достигнутый ранее баланс, сбрасываем lot в начальное значение
   if ( max_balance < balance ) {
      lot = min_lot;                // Начинаем опять с минимального лота
      max_balance = balance;        // Устанавливаем новый максимальный баланс
      buy_sell_count = 0;           // Обнуляем счётчик тиков buy/sell
      win_lost_count = 0;           // Обнуляем счётчик выигрышей/проигрышей
   }
   // выставляем операцию в зависимости от числа тиков в ту или иную сторону
   if (buy_sell_count < 0) {
      order_direction = -1;          // было больше buy, значит, продолжаем buy (-1)
   } else if (buy_sell_count > 0) {
      order_direction = 1;         // было больше sell, значит, продолжаем sell (1)
   } else {                         // здесь счётчик buy_sell_count равен нулю
      // оставляем order_direction, как был, только если он не был равен нулю (начало)
      if (order_direction == 0) {   // в этом случае случайно получаем -1 (buy) или 1 (sell)
         order_direction = 2 * MathRand() / 32768 - 1;
      }
   }
   switch ( order_direction ) {
      case -1:
         ticket = -1;
         // пробуем послать buy order, пока он не сработает
         while( ticket < 0 ) {
            price = Ask;
            ticket = OrderSend( Symbol(), OP_BUY, lot, price, 0, 0.0, 0.0 );
         }
         break;
      case 1:
         ticket = -1;
         // пробуем послать sell order, пока он не сработает
         while( ticket < 0 ) {
            price = Bid;
            ticket = OrderSend( Symbol(), OP_SELL, lot, price, 0, 0.0, 0.0 );
         }
         break;
   }
}
//+------------------------------------------------------------------+