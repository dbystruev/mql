//+------------------------------------------------------------------+
//|                                          Bystruev_2009_09_10.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 10 Sep 2009 |
//|                                                 bystruev@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 10 Sep 2009"
#property link      "bystruev@mail.ru"

// когда амплитуда текущего бара больше, чем амплитуда bars_to_track количества предыдущих,
// торгуем либо в сторону изменения текущего бара, либо против него

#define  MAGIC_NUMBER   320090910

extern   int      bars_to_track     =  1000; // сколько баров назад брать во внимание
extern   int      delta_lose_add    =  0;    // сколько добавлять к delta после проигрыша
extern   double   delta_lose_mult   =  2.0;  // на сколько умножать delta после проигрыша
extern   int      delta_win_add     =  0;    // сколько добавлять к delta после выигрыша
extern   double   delta_win_mult    =  0.0;  // на сколько умножать delta после выигрыша
extern   int      lot_lose_add      =  1;    // сколько добавлять к лоту после проигрыша
extern   double   lot_lose_mult     =  1.0;  // на сколько умножать лот после проигрыша
extern   int      lot_win_add       =  0;    // сколько добавлять к лоту после выигрыша
extern   double   lot_win_mult      =  0.0;  // на сколько умножать лот после выигрыша
extern   int      start_delta       =  0;    // с какой delta начинать
extern   double   start_lot         =  0.0;  // с какого лота начинать
extern   bool     follow_bar_move   =  TRUE; // торговать ли в сторону движения текущего бара

double   balance; // текущий баланс
int      delta;   // уровни стоп-лосс и тейк-профит
double   lot;     // текущий размер лота
int      ticket;  // тикет ордера, которым торгуем

// инициализация глобальных переменных
int init() {
   balance = AccountBalance();   // текущий баланс
   delta = start_delta;          // уровни стоп-лосс и тейк-профит
   lot =  start_lot;             // текущий размер лота
   ticket = -1;                  // тикет ордера, которым торгуем
}

// вывод сообщения об ошибке
void print_error(int result, int order_type, double lot, double price, double stoploss, double takeprofit) {
         Print("Order Error: Error = " + GetLastError());
         Print("Order Error: Symbol = " + Symbol());
         switch (order_type) {
            case OP_BUY:
               Print("Order Error: order_type = OP_BUY");
               break;
            case OP_BUYLIMIT:
               Print("Order Error: order_type = OP_BUYLIMIT");
               break;
            case OP_BUYSTOP:
               Print("Order Error: order_type = OP_BUYSTOP");
               break;
            case OP_SELL:
               Print("Order Error: order_type = OP_SELL");
               break;
            case OP_SELLLIMIT:
               Print("Order Error: order_type = OP_SELLLIMIT");
               break;
            case OP_SELLSTOP:
               Print("Order Error: order_type = OP_SELLSTOP");
               break;
            default:
               Print("Order Error: order_type = " + order_type);
               break;
         }
         Print("Order Error: lot = " + lot);
         Print("Order Error: price = " + price);
         Print("Order Error: stoploss = " + stoploss);
         Print("Order Error: takeprofit = " + takeprofit);
         Print("Order Error: Ask = " + Ask + ", Bid = " + Bid);
}

// основная функция, вызываемая при каждом тике
int start() {
   // если есть хотя бы один ордер - ждём, когда он закроется, не торгуем
   if (total_orders() > 0) return;
   // если не хватает денег - не торгуем
   if (AccountFreeMargin() < lot * MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;
   // если у нас был действующий ордер, узнаем, выиграли мы, или проиграли
   if (ticket >= 0) {
      double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
      if (balance < AccountBalance()) {
         // выиграли
         delta *= delta_win_mult;
         delta += delta_win_add;
         lot *= lot_win_mult;
         lot += lot_win_add * lot_step;
      } else {
         // проиграли
         delta += delta_lose_add;
         delta *= delta_lose_mult;
         lot += lot_lose_add * lot_step;
         lot *= lot_lose_mult;
      }
      ticket = -1;
   }
   // запомним текущий баланс
   balance = AccountBalance();
   // убедимся, что delta не меньше, чем уровень стопов + спред
   delta = MathMax(delta, MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   // убедимся, что лот не вышел за пределы минимумов и максимумов
   lot = MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));  // торгуем лотом не меньше минимального
   lot = MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));  // торгуем лотом не больше максимального
   // найдём индекс бара максимальной амплитуды и её значение
   int      max_move_index =  1;                // индекс бара с максимальной амплитудой
   double   max_move_value =  High[1] - Low[1]; // значение максимальной амплитуды
   for (int i = 2; i < bars_to_track; i++) {
      double   move_value  =  High[i] - Low[i]; // значение очередной амплитуды
      if (max_move_value < move_value) {
         max_move_index = i;
         max_move_value = move_value;
   }  }
   // найдём значение текущей амплитуды
   move_value = High[0] - Low[0];
   // начнём формирование строки для вывода на экран
   string comment = "Максимальная амплитуда: " + DoubleToStr(max_move_value / Point, 0) + " (баров назад: " + max_move_index + ")\n";
   comment = comment + "Текущая амплитуда: " + DoubleToStr(move_value / Point, 0) + "\n";
   comment = comment + "Общее число баров: " + bars_to_track + "\n";
   comment = comment + "Уровни тейк-профит и стоп-лосс (delta): " + delta + "\n";
   comment = comment + "Размер лота: " + DoubleToStr(lot, 2) + "\n";
   // если текущая амплитуда - наибольшая, начинаем торговать
   if (max_move_value < move_value) {
      int   order_type;    // тип ордера - BUY или SELL
      // найдём, в какую сторону движется текущий бар
      if (Open[0] < Close[0]) {
         // цена растёт
         if (follow_bar_move) {
            // торгуем в сторону движения - покупаем
            order_type = OP_BUY;
         } else {
            // торгуем против движения - продаём
            order_type = OP_SELL;
      }  } else {
         // цена падает
         if (follow_bar_move) {
            // торгуем в сторону движения - продаём
            order_type = OP_SELL;
         } else {
            // торгуем против движения - покупаем
            order_type = OP_BUY;
      }  }
      // установим цену и уровни стоп-лосс и тейк-профит
      double   price, stop_loss, take_profit;   // цена, стоп-лосс, тейк-профит
      switch (order_type) {
         case OP_BUY:
            price = Ask;
            stop_loss = price - Point * delta;
            take_profit = price + Point * delta;
            comment = "Покупаем лотов: " + DoubleToStr(lot, 2) + ", по цене: " + DoubleToStr(price, Digits);
            break;
         case OP_SELL:
            price = Bid;
            stop_loss = price + Point * delta;
            take_profit = price - Point * delta;
            comment = "Продаём лотов: " + DoubleToStr(lot, 2) + ", по цене: " + DoubleToStr(price, Digits);
         break;
      }
      ticket = OrderSend(Symbol(), order_type, lot, price, 0, stop_loss, take_profit, NULL, MAGIC_NUMBER);
      if (ticket < 0) print_error(ticket, order_type, lot, price, stop_loss, take_profit);
   }
   Comment(comment);
}

// общее количество ордеров определённого типа с соотвествующим MAGIC_NUMBER
int total_orders(int order_type_1 = -1, int order_type_2 = -1) {
   int total_orders = 0;
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderSymbol() == Symbol()) {
               if ((order_type_1 == -1) || (order_type_1 == OrderType()) || (order_type_2 == OrderType())) total_orders++;
            }
   }  }  }
   return (total_orders);
}