//+------------------------------------------------------------------+
//|                                          Bystruev_2009_08_29.mq4 |
//|                  opyright � 2009, Denis Bystruev, 29 August 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2009, Denis Bystruev, 28 August 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   320090829

// ������� ���������� ��������� �����, ����� ����������, ���� �� ������� �������

extern   int      stop_level     =  340;  // ������ stoploss � takeprofit
extern   int      lot_win_add    =  0;    // ������� ���������� � ���� ��� ��������
extern   double   lot_win_mult   =  0.0;  // �� ������� �������� ��� ��� ��������
extern   int      lot_lost_add   =  1;    // ������� ���������� � ���� ��� ���������
extern   double   lot_lost_mult  =  1.0;  // �� ������� �������� ��� ��� ���������

double   account_balance   =  0.0;  // ������� ������
double   max_balance       =  0.0;  // ������������ ������
double   lot               =  0.0;  // ������� ������ ����
int      order_type        =  -1;   // ��� ������ (OP_BUY ��� OP_SELL)

// �������������� ��������� ��������� �����
int init() {
   MathSrand(TimeLocal());
}

// ����������� ��� � ������ ����������� �� �������� � ���������
double norm_lot(double lot) {
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
   double max_lot = MarketInfo(Symbol(), MODE_MAXLOT);
   double min_lot = MarketInfo(Symbol(), MODE_MINLOT);
   double norm_lot = lot_step * MathRound(lot / lot_step);
   norm_lot = MathMax(min_lot, norm_lot);
   norm_lot = MathMin(max_lot, norm_lot);
   return (norm_lot);
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

// �������� ������� - ����������� ������������� ��� ������ ����
int start() {
   // ���, ���� ��������� ����� - �� ����, ���� ���� �����, �� �������
   if (total_orders() > 0) return;
   // ���� �� ������� �����, ��������� �� �����
   if (AccountFreeMargin() < lot * MarketInfo(Symbol(), MODE_MARGINREQUIRED)) {
      Comment("�� ������� ����� ��� �������� �����: " + DoubleToStr(lot, 2));
      return;
   }
   // ��������� ��� ����
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
   // ���������, �������� �� � ������� ���, ��� ���������
   if (account_balance < AccountBalance()) {
      // ��������
      lot += lot_win_add * lot_step;
      lot *= lot_win_mult;
      order_type = -1;
   } else if (AccountBalance() < account_balance) {
      // ���������
      lot *= lot_lost_mult;
      lot += lot_lost_add * lot_step;
   }
   account_balance = AccountBalance();
   // ���������, �������� �� �� ������������� �������
   if (max_balance < AccountBalance()) {
      // ��������
      lot = 0.0;
      max_balance = AccountBalance();
      order_type = -1;
   }
   lot = norm_lot(lot);
   // ���� ��� ������ = -1, ������ ��� OP_BUY ��� OP_SELL
   if (order_type < 0) {
      order_type = MathRand() % 2;
   }
   // ����� ����� ������� ����, ��������, ����������
   double price, stoploss, takeprofit;
   // ����� ����� �����������
   string comment;
   // ��������, ��� ������������� takeprofit/stoploss �� �����, ��� stop level
   stop_level = MathMax(stop_level, MarketInfo(Symbol(), MODE_STOPLEVEL));
   // ��������� price, stoploss � takeprofit � ����������� �� ���� ������
   switch (order_type) {
      case OP_BUY:
         price = Ask;
         stoploss = price - stop_level * Point;
         takeprofit = price + stop_level * Point;
         comment = "�������� �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
         break;
      case OP_SELL:
         price = Bid;
         stoploss = price + stop_level * Point;
         takeprofit = price - stop_level * Point;
         comment = "������ �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
         break;
   }
   Comment(comment);
   // �������
   if (order_type >= 0) {
      int result = OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER);
      if (result < 0) print_error(result, order_type, lot, price, stoploss, takeprofit);
}  }

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