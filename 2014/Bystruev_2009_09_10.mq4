//+------------------------------------------------------------------+
//|                                          Bystruev_2009_09_10.mq4 |
//|                    Copyright � 2009, Denis Bystruev, 10 Sep 2009 |
//|                                                 bystruev@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2009, Denis Bystruev, 10 Sep 2009"
#property link      "bystruev@mail.ru"

// ����� ��������� �������� ���� ������, ��� ��������� bars_to_track ���������� ����������,
// ������� ���� � ������� ��������� �������� ����, ���� ������ ����

#define  MAGIC_NUMBER   320090910

extern   int      bars_to_track     =  1000; // ������� ����� ����� ����� �� ��������
extern   int      delta_lose_add    =  0;    // ������� ��������� � delta ����� ���������
extern   double   delta_lose_mult   =  2.0;  // �� ������� �������� delta ����� ���������
extern   int      delta_win_add     =  0;    // ������� ��������� � delta ����� ��������
extern   double   delta_win_mult    =  0.0;  // �� ������� �������� delta ����� ��������
extern   int      lot_lose_add      =  1;    // ������� ��������� � ���� ����� ���������
extern   double   lot_lose_mult     =  1.0;  // �� ������� �������� ��� ����� ���������
extern   int      lot_win_add       =  0;    // ������� ��������� � ���� ����� ��������
extern   double   lot_win_mult      =  0.0;  // �� ������� �������� ��� ����� ��������
extern   int      start_delta       =  0;    // � ����� delta ��������
extern   double   start_lot         =  0.0;  // � ������ ���� ��������
extern   bool     follow_bar_move   =  TRUE; // ��������� �� � ������� �������� �������� ����

double   balance; // ������� ������
int      delta;   // ������ ����-���� � ����-������
double   lot;     // ������� ������ ����
int      ticket;  // ����� ������, ������� �������

// ������������� ���������� ����������
int init() {
   balance = AccountBalance();   // ������� ������
   delta = start_delta;          // ������ ����-���� � ����-������
   lot =  start_lot;             // ������� ������ ����
   ticket = -1;                  // ����� ������, ������� �������
}

// ����� ��������� �� ������
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

// �������� �������, ���������� ��� ������ ����
int start() {
   // ���� ���� ���� �� ���� ����� - ���, ����� �� ���������, �� �������
   if (total_orders() > 0) return;
   // ���� �� ������� ����� - �� �������
   if (AccountFreeMargin() < lot * MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;
   // ���� � ��� ��� ����������� �����, ������, �������� ��, ��� ���������
   if (ticket >= 0) {
      double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
      if (balance < AccountBalance()) {
         // ��������
         delta *= delta_win_mult;
         delta += delta_win_add;
         lot *= lot_win_mult;
         lot += lot_win_add * lot_step;
      } else {
         // ���������
         delta += delta_lose_add;
         delta *= delta_lose_mult;
         lot += lot_lose_add * lot_step;
         lot *= lot_lose_mult;
      }
      ticket = -1;
   }
   // �������� ������� ������
   balance = AccountBalance();
   // ��������, ��� delta �� ������, ��� ������� ������ + �����
   delta = MathMax(delta, MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   // ��������, ��� ��� �� ����� �� ������� ��������� � ����������
   lot = MathMax(lot, MarketInfo(Symbol(), MODE_MINLOT));  // ������� ����� �� ������ ������������
   lot = MathMin(lot, MarketInfo(Symbol(), MODE_MAXLOT));  // ������� ����� �� ������ �������������
   // ����� ������ ���� ������������ ��������� � � ��������
   int      max_move_index =  1;                // ������ ���� � ������������ ����������
   double   max_move_value =  High[1] - Low[1]; // �������� ������������ ���������
   for (int i = 2; i < bars_to_track; i++) {
      double   move_value  =  High[i] - Low[i]; // �������� ��������� ���������
      if (max_move_value < move_value) {
         max_move_index = i;
         max_move_value = move_value;
   }  }
   // ����� �������� ������� ���������
   move_value = High[0] - Low[0];
   // ����� ������������ ������ ��� ������ �� �����
   string comment = "������������ ���������: " + DoubleToStr(max_move_value / Point, 0) + " (����� �����: " + max_move_index + ")\n";
   comment = comment + "������� ���������: " + DoubleToStr(move_value / Point, 0) + "\n";
   comment = comment + "����� ����� �����: " + bars_to_track + "\n";
   comment = comment + "������ ����-������ � ����-���� (delta): " + delta + "\n";
   comment = comment + "������ ����: " + DoubleToStr(lot, 2) + "\n";
   // ���� ������� ��������� - ����������, �������� ���������
   if (max_move_value < move_value) {
      int   order_type;    // ��� ������ - BUY ��� SELL
      // �����, � ����� ������� �������� ������� ���
      if (Open[0] < Close[0]) {
         // ���� �����
         if (follow_bar_move) {
            // ������� � ������� �������� - ��������
            order_type = OP_BUY;
         } else {
            // ������� ������ �������� - ������
            order_type = OP_SELL;
      }  } else {
         // ���� ������
         if (follow_bar_move) {
            // ������� � ������� �������� - ������
            order_type = OP_SELL;
         } else {
            // ������� ������ �������� - ��������
            order_type = OP_BUY;
      }  }
      // ��������� ���� � ������ ����-���� � ����-������
      double   price, stop_loss, take_profit;   // ����, ����-����, ����-������
      switch (order_type) {
         case OP_BUY:
            price = Ask;
            stop_loss = price - Point * delta;
            take_profit = price + Point * delta;
            comment = "�������� �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
            break;
         case OP_SELL:
            price = Bid;
            stop_loss = price + Point * delta;
            take_profit = price - Point * delta;
            comment = "������ �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
         break;
      }
      ticket = OrderSend(Symbol(), order_type, lot, price, 0, stop_loss, take_profit, NULL, MAGIC_NUMBER);
      if (ticket < 0) print_error(ticket, order_type, lot, price, stop_loss, take_profit);
   }
   Comment(comment);
}

// ����� ���������� ������� ������������ ���� � �������������� MAGIC_NUMBER
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