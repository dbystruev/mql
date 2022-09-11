//+------------------------------------------------------------------+
//|                                          Bystruev_2009_08_29.mq4 |
//|                  opyright © 2009, Denis Bystruev, 29 August 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 28 August 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   320090829

// Сначала выставляем случайный ордер, затем продолжаем, пока не получим прибыль

extern   int      stop_level     =  340;  // уровни stoploss и takeprofit
extern   int      lot_win_add    =  0;    // сколько прибавлять к лоту при выигрыше
extern   double   lot_win_mult   =  0.0;  // на сколько умножать лот при выигрыше
extern   int      lot_lost_add   =  1;    // сколько прибавлять к лоту при проигрыше
extern   double   lot_lost_mult  =  1.0;  // на сколько умножать лот при проигрыше

double   account_balance   =  0.0;  // текущий баланс
double   max_balance       =  0.0;  // максимальный баланс
double   lot               =  0.0;  // текущий размер лота
int      order_type        =  -1;   // тип ордера (OP_BUY или OP_SELL)

// инициализируем генератор случайных чисел
int init() {
   MathSrand(TimeLocal());
}

// нормализуем лот с учётом ограничений по минимуму и максимуму
double norm_lot(double lot) {
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
   double max_lot = MarketInfo(Symbol(), MODE_MAXLOT);
   double min_lot = MarketInfo(Symbol(), MODE_MINLOT);
   double norm_lot = lot_step * MathRound(lot / lot_step);
   norm_lot = MathMax(min_lot, norm_lot);
   norm_lot = MathMin(max_lot, norm_lot);
   return (norm_lot);
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

// основная функция - запускается автоматически при каждом тике
int start() {
   // ждём, пока сработает ордер - то есть, если есть ордер, не торгуем
   if (total_orders() > 0) return;
   // если не хватает денег, торговать не будем
   if (AccountFreeMargin() < lot * MarketInfo(Symbol(), MODE_MARGINREQUIRED)) {
      Comment("Не хватает денег для торговли лотом: " + DoubleToStr(lot, 2));
      return;
   }
   // вычисляем шаг лота
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
   // проверяем, выиграли мы в прошлый раз, или проиграли
   if (account_balance < AccountBalance()) {
      // выиграли
      lot += lot_win_add * lot_step;
      lot *= lot_win_mult;
      order_type = -1;
   } else if (AccountBalance() < account_balance) {
      // проиграли
      lot *= lot_lost_mult;
      lot += lot_lost_add * lot_step;
   }
   account_balance = AccountBalance();
   // проверяем, достигли ли мы максимального баланса
   if (max_balance < AccountBalance()) {
      // достигли
      lot = 0.0;
      max_balance = AccountBalance();
      order_type = -1;
   }
   lot = norm_lot(lot);
   // если тип ордера = -1, делаем его OP_BUY или OP_SELL
   if (order_type < 0) {
      order_type = MathRand() % 2;
   }
   // здесь будем хранить цену, стоплосс, тейкпрофит
   double price, stoploss, takeprofit;
   // здесь будет комментарий
   string comment;
   // убедимся, что устанавливаем takeprofit/stoploss не ближе, чем stop level
   stop_level = MathMax(stop_level, MarketInfo(Symbol(), MODE_STOPLEVEL));
   // вычисляем price, stoploss и takeprofit в зависимости от типа ордера
   switch (order_type) {
      case OP_BUY:
         price = Ask;
         stoploss = price - stop_level * Point;
         takeprofit = price + stop_level * Point;
         comment = "Покупаем лотов: " + DoubleToStr(lot, 2) + ", по цене: " + DoubleToStr(price, Digits);
         break;
      case OP_SELL:
         price = Bid;
         stoploss = price + stop_level * Point;
         takeprofit = price - stop_level * Point;
         comment = "Продаём лотов: " + DoubleToStr(lot, 2) + ", по цене: " + DoubleToStr(price, Digits);
         break;
   }
   Comment(comment);
   // торгуем
   if (order_type >= 0) {
      int result = OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER);
      if (result < 0) print_error(result, order_type, lot, price, stoploss, takeprofit);
}  }

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