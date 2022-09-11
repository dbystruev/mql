//+------------------------------------------------------------------+
//|                                                   Bystruev10.mq4 |
//|                    Copyright � 2009, Denis Bystruev, 27 Feb 2009 |
//|                                                 bystruev@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2009, Denis Bystruev, 27 Feb 2009"
#property link      "bystruev@mail.ru"

#define     MAGIC    1973050317              // ��� ���� � ����� ��������

//---- input parameters
extern datetime   time_period = 1;           // ������� ��� � time_pediod ������
extern datetime   minmax_period = 86400;     // ���������� �������� min bid/max bid ��� � �����
extern double     stop_loss = 80.0;          // �������� stop loss � �������
extern double     take_profit = 100.0;       // �������� take profit � �������

//---- global variables
double         balance;                      // ������� �������� AccountEquity()
datetime       email_time = 0;               // the time when the last e-mail was sent
datetime       email_period = 3600;          // how often to send e-mails in seconds
double         last_bid;                     // ������� �������� Bid
double         lot = 0.0;                    // ������� �������� ������� ����
double         max_balance = 0.0;            // ����������� ����������� ������
double         max_bid;                      // ������������ �������� Bid
double         min_bid;                      // ����������� �������� Bid
datetime       minmax_time = 0;              // ����� ���������� ������ min bid/max bid
double         sl;                           // ��������� ��� stop loss
datetime       time_run;                     // ����� ��������� ��������� ���
double         tp;                           // ��������� ��� take profit
//+------------------------------------------------------------------+
//| update all global variables                                      |
//+------------------------------------------------------------------+
void update_vars() {
   balance = AccountEquity();                // ���������� ������� ������ �����
   last_bid = Bid;                           // ���������� ��������� �������� Bid
   max_balance = MathMax(max_balance, balance); // ��������� ������������ �������� �������
   if (minmax_time + minmax_period < TimeCurrent()) {
      minmax_time = TimeCurrent();
      max_bid = Bid;                         // ������������ �������� Bid
      min_bid = Bid;                         // ����������� �������� Bid
   } else {
      max_bid = MathMax(max_bid, Bid);       // ���������� ������������ �������� Bid
      min_bid = MathMin(min_bid, Bid);       // ���������� ����������� �������� Bid
   }
   if (stop_loss < take_profit) {            // ������������� �������� ���������� sl � tp
      sl = 1.0;
      tp = take_profit / stop_loss;
   } else {
      tp = 1.0;
      sl = stop_loss / take_profit;
   }
   time_run = TimeCurrent();                 // ��������� ��� ��������� ������ ���
}
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   update_vars();                            // ���������������� ��� ����������
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
   double   lot_step = MathMax(MarketInfo(Symbol(), MODE_MINLOT), MarketInfo(Symbol(), MODE_LOTSTEP));  // ������ ���� ����
   // ���������, ��� �� � ��� �������� �������
   for (int i = 0; i < OrdersTotal(); i++)
      if (OrderSelect(i, SELECT_BY_POS))
         if (OrderMagicNumber() == MAGIC)
            return;                          // ����� ����������� ����� - ��������� �� �����
   // �������� ������ ����
   if (balance < AccountEquity())            // ���� ��������� ������, ����� ��������� ������ ����
      lot -= tp * lot_step;
   else if (AccountEquity() < balance)       // ���� ��������� �����, �������� ������ ����
      lot += sl * lot_step;
   // ���� �������� ������������� �������, ������������� ����������� ���
   if (max_balance < AccountEquity())
      lot = MarketInfo(Symbol(), MODE_MINLOT);
   // ����������� ������ ����
   lot = lot_step * MathFloor(lot / lot_step);
   // ������ ���� ������ ������������ � �������� �����
   lot = MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));
   lot = MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));
   // �������� ������� ���, ����� ���������
   if (max_bid < Bid) {
      // ���� ��� �����, ����� ���������
      OrderSend(Symbol(), OP_SELL, lot, Bid, 0, Bid + stop_loss * Point, Bid - take_profit * Point, NULL, MAGIC, 0, Red);
   } else if (Bid < min_bid) {
      // ���� ��� ����, ����� ��������
      OrderSend(Symbol(), OP_BUY, lot, Ask, 0, Ask - stop_loss * Point, Ask + take_profit * Point, NULL, MAGIC, 0, Blue);
   }
   Email();                                  // ������ ������
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   if (TimeCurrent() >= email_time + email_period)
      Email();                            // �������� ������, ���� ������ email_period
   if (TimeCurrent() < time_run + time_period)
      return;                             // ��������� ���� - �� ������ time_period
   trade();                               // �������
   update_vars();                         // ������� ��� ����������
}

