//+------------------------------------------------------------------+
//|                                                   Bystruev10.mq4 |
//|                    Copyright © 2009, Denis Bystruev, 27 Feb 2009 |
//|                                                 bystruev@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, Denis Bystruev, 27 Feb 2009"
#property link      "bystruev@mail.ru"

#define     MAGIC    1973050317              // мой день и время рождения

//---- input parameters
extern datetime   time_period = 1;           // торгуем раз в time_pediod секунд
extern datetime   minmax_period = 86400;     // сбрасываем значения min bid/max bid раз в сутки
extern double     stop_loss = 80.0;          // значение stop loss в пунктах
extern double     take_profit = 100.0;       // значение take profit в пунктах

//---- global variables
double         balance;                      // прошлое значение AccountEquity()
datetime       email_time = 0;               // the time when the last e-mail was sent
datetime       email_period = 3600;          // how often to send e-mails in seconds
double         last_bid;                     // прошлое значение Bid
double         lot = 0.0;                    // текущее значение размера лота
double         max_balance = 0.0;            // максимально достигнутый баланс
double         max_bid;                      // максимальное значение Bid
double         min_bid;                      // минимальное значение Bid
datetime       minmax_time = 0;              // время последнего сброса min bid/max bid
double         sl;                           // множитель для stop loss
datetime       time_run;                     // когда запускали последний раз
double         tp;                           // множитель для take profit
//+------------------------------------------------------------------+
//| update all global variables                                      |
//+------------------------------------------------------------------+
void update_vars() {
   balance = AccountEquity();                // запоминаем текущий баланс счёта
   last_bid = Bid;                           // запоминаем последнее значение Bid
   max_balance = MathMax(max_balance, balance); // обновляем максимальное значение баланса
   if (minmax_time + minmax_period < TimeCurrent()) {
      minmax_time = TimeCurrent();
      max_bid = Bid;                         // максимальное значение Bid
      min_bid = Bid;                         // минимальное значение Bid
   } else {
      max_bid = MathMax(max_bid, Bid);       // запоминаем максимальное значение Bid
      min_bid = MathMin(min_bid, Bid);       // запоминаем минимальное значение Bid
   }
   if (stop_loss < take_profit) {            // устанавливаем значения множителей sl и tp
      sl = 1.0;
      tp = take_profit / stop_loss;
   } else {
      tp = 1.0;
      sl = stop_loss / take_profit;
   }
   time_run = TimeCurrent();                 // последний раз запускали только что
}
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   update_vars();                            // инициализировать все переменные
}
//+------------------------------------------------------------------+
//| Sends e-mail with account information                            |
//+------------------------------------------------------------------+
void Email()
{
      string   Subject  = "Equity: " + DoubleToStr(AccountEquity(), 2);
      string   Text     = "Lot: " + DoubleToStr(lot, 2);
      
      Text = Text + "\nBid: " + DoubleToStr(Bid, Digits);
      Text = Text + "\nAsk: " + DoubleToStr(Ask, Digits);
      for (int i = 0; i < OrdersTotal(); i++) {
         if (OrderSelect(i, SELECT_BY_POS)) {
            if (OrderMagicNumber() == MAGIC) {
               switch (OrderType()) {
                  case OP_BUY:
                     Text = Text + "\nBuy ";
                     break;
                  case OP_SELL:
                     Text = Text + "\nSell ";
                     break;
                  case OP_BUYLIMIT:
                     Text = Text + "\nBuy Limit ";
                     break;
                  case OP_SELLLIMIT:
                     Text = Text + "\nSell Limit ";
                     break;
                  case OP_BUYSTOP:
                     Text = Text + "\nBuy Stop ";
                     break;
                  case OP_SELLSTOP:
                     Text = Text + "\nSell Stop ";
                     break;
               }
               Text = Text + DoubleToStr(OrderOpenPrice(), Digits) + " ";
               Text = Text + DoubleToStr(OrderStopLoss(), Digits) + " ";
               Text = Text + DoubleToStr(OrderTakeProfit(), Digits);
            }
         }
      }
      SendMail(Subject, Text);
      email_time = TimeCurrent();
}
//+------------------------------------------------------------------+
//| main trade function                                              |
//+------------------------------------------------------------------+
void trade() {
   double   lot_step = MathMax(MarketInfo(Symbol(), MODE_MINLOT), MarketInfo(Symbol(), MODE_LOTSTEP));  // размер шага лота
   // посмотрим, нет ли у нас открытых ордеров
   for (int i = 0; i < OrdersTotal(); i++)
      if (OrderSelect(i, SELECT_BY_POS))
         if (OrderMagicNumber() == MAGIC)
            return;                          // нашли действующий ордер - торговать не будем
   // выставим размер лота
   if (balance < AccountEquity())            // если торговали хорошо, можно уменьшить размер лота
      lot -= tp * lot_step;
   else if (AccountEquity() < balance)       // если торговали плохо, увеличим размер лота
      lot += sl * lot_step;
   // если достигли максимального баланса, устанавливаем минимальный лот
   if (max_balance < AccountEquity())
      lot = MarketInfo(Symbol(), MODE_MINLOT);
   // нормализуем размер лота
   lot = lot_step * MathFloor(lot / lot_step);
   // размер лота должен укладываться в заданные рамки
   lot = MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot = MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
   // открытых ордеров нет, можно торговать
   if (max_bid < Bid) {
      // цена идёт вверх, будем продавать
      OrderSend(Symbol(), OP_SELL, lot, Bid, 0, Bid + stop_loss * Point, Bid - take_profit * Point, NULL, MAGIC, 0, Red);
   } else if (Bid < min_bid) {
      // цена идёт вниз, будем покупать
      OrderSend(Symbol(), OP_BUY, lot, Ask, 0, Ask - stop_loss * Point, Ask + take_profit * Point, NULL, MAGIC, 0, Blue);
   }
   Email();                                  // отошлём письмо
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   if (TimeCurrent() >= email_time + email_period)
      Email();                            // отослать письмо, если прошёл email_period
   if (TimeCurrent() < time_run + time_period)
      return;                             // торговать рано - не прошёл time_period
   trade();                               // торгуем
   update_vars();                         // обновим все переменные
}

