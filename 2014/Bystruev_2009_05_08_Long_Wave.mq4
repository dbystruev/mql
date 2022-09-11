//+------------------------------------------------------------------+
//|                                Bystruev_2009_05_08_Long_Wave.mq4 |
//|                  Copyright � 2009, Denis Bystruev, 5 August 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2009, Denis Bystruev, 5 August 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   320090508

// ���� ������� ������� ��� ���� ����������� ������, ��� ��� ������ ����������
// ���������� �����, ����� �������� � ������� �������� ����

extern int     bars_to_track  =  1250; // ���������� �����, ������� �����������
extern int     lot_add        =  -1;   // ������� ���������� � ���� ��� �������� ��� �������� ��� ��������
extern double  lot_factor     =  1.0;  // �� ������� �������� ��� ��� ��������� ��� ������ ��� ��������
extern int     max_orders     =  1;    // ������������ ����� �������, ������� ���������
extern double  max_risk       =  0.1;  // ����� �����, ���������� �� �������� ������ ������
extern double  trailing_level =  0.5;  // ������� ��������� (0.5 = 50%)

// ����� ����� �������� ���������� � ������������ ������
double balance, max_balance;
// ����� ����� �������� ������ ����
double lot;

// �������������� ����������
int init() {
   // ���������� ������� � ������������ ������ �� �������
   balance = AccountBalance();
   max_balance = AccountBalance();
   // �������� �������� � ������������ ����
   lot = get_lot(0.0);
}

// ��������� ������ ���� � ������ ������������� �����
double get_lot(double current_lot, int step = 0) {
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
   double get_lot = current_lot + step * lot_step;
   double max_risk_lot = max_risk * max_balance / MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   get_lot = norm_lot(MathMin(get_lot, max_risk_lot));
   return (get_lot);
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

// ����������� ����
double norm_price(double price) {
   if (Symbol() == "GOLD") price = 0.1 * MathRound(price / 0.1);
   return (Point * MathRound(price / Point));
}

// �������� ������� - ����������� ������������� ��� ������ ����
int start() {
   // ������ buy/sell ������ (���� ����), �� ������, ���� ������� ����������� �����
   // if (lot == get_lot(0.0)) trail_orders(OP_BUY, OP_SELL);   
   // ���, ���� ��������� ������ - �� ����, ���� ����� ������� �������� ���������, �� �������
   if (total_orders() >= max_orders) return;
   // ��� ������ ��������� ������ ���� � ����������� �� ����, �������� �� ��� ���������
   if (balance < AccountBalance()) lot = get_lot(lot / lot_factor, -lot_add);  // �������� - ��������� ������ ����
   if (AccountBalance() < balance) lot = get_lot(lot * lot_factor, lot_add);   // ��������� - ����������� ������ ����
   balance = AccountBalance();
   // ���� ��������� ������������ ������, ���������� ��� � �����������
   if (max_balance < AccountBalance()) {
      lot = get_lot(0.0);
      max_balance = AccountBalance();
   }
   // ���� �� ������� �����, ��������� �� �����
   if (AccountFreeMargin() < lot * MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;
   // ����������� ��������, ��� ������� ����� ���������, ������ ���� ������ ������
   int min_delta = MarketInfo(Symbol(), MODE_STOPLEVEL);
   // ����� ����� ��� ������ - OP_BUY ��� OP_SELL
   int order_type = -1;
   // ����� ����� ������� ����, ��������, ����������
   double price, stoploss, takeprofit;
   // ����� ������������ ��������� �������� ���������� �����
   int max = 0, max_index = 0;
   for (int i = 1; i <= bars_to_track; i++) {
      // ��������� ���� � ������� i �����
      int delta = MathRound((High[i] - Low[i]) / Point);
      if (max < delta) {
         max = delta;
         max_index = i;
   }  }
   // ����� ��������� �������� ����
   delta = MathRound((High[0] - Low[0]) / Point);
   // ����� ������������ ������ ��� ������ �� �����
   string comment = "������������ ���������: " + max + " (����� �����: " + max_index + ")\n";
   comment = comment + "������� ���������: " + delta + "\n";
   comment = comment + "����� ����� �����: " + bars_to_track + "\n";
   // ���� ������� ��������� ������ ���������� ������������, ����
   if ((max < delta) && (min_delta < delta) && (OrdersTotal() < max_orders)) {
      if (Open[0] < Close[0]) {
         order_type = OP_BUY;    // ����� �����
         price = Ask;
//         stoploss = MathMin(Low[0], Low[1]);
         stoploss = Low[iLowest(NULL, 0, MODE_LOW, bars_to_track)];
         comment = comment + "�������� �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
      }
      if (Close[0] < Open[0]) {
         order_type = OP_SELL;   // ������� ����
         price = Bid;
//         stoploss = MathMax(High[0], High[1]) + Point * MarketInfo(Symbol(), MODE_SPREAD);
         stoploss = High[iHighest(NULL, 0, MODE_HIGH, bars_to_track)] + Point * MarketInfo(Symbol(), MODE_SPREAD);
         comment = comment + "������ �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
      }
      // ������� ����-������ ����� ����� ����, ���� �� ������� ����������� ����� (��-�� �����)
      takeprofit = price + price - stoploss;
      // if (lot == get_lot(0.0)) takeprofit = 0.0;
   }
   Comment(comment);
   // �������
   if (order_type >= 0) {
      int result = OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER);
      if (result < 0) {
         Print("Order Error: Error = " + GetLastError());
         Print("Order Error: Symbol = " + Symbol());
         switch (order_type) {
            case OP_BUY:
               Print("Order Error: order_type = OP_BUY");
               break;
            case OP_SELL:
               Print("Order Error: order_type = OP_SELL");
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
}  }  }

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

// ������ ���������� BUY ��� SELL ����� � ������� trailing_level �� 0 �� 1
void trail_order(int ticket) {
   double stoplevel = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
   double stoploss;
   if (OrderSelect(ticket, SELECT_BY_TICKET)) {
      switch (OrderType()) {
         case OP_BUY:
            stoploss = norm_price(OrderOpenPrice() + trailing_level * (Bid - OrderOpenPrice()));
            stoploss = MathMin(stoploss, Bid - stoplevel);
            if ((OrderOpenPrice() < stoploss) && (OrderStopLoss() < stoploss)) OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            break;
         case OP_SELL:
            stoploss = norm_price(OrderOpenPrice() - trailing_level * (OrderOpenPrice() - Ask));
            stoploss = MathMax(stoploss, Ask + stoplevel);
            if ((stoploss < OrderOpenPrice()) && (stoploss < OrderStopLoss())) OrderModify(ticket, OrderOpenPrice(), stoploss, OrderTakeProfit(), 0);
            break;
}  }  }

// ������ ������ ��������� �����
void trail_orders(int order_type_1, int order_type_2) {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderSelect(i, SELECT_BY_POS)) {
         if (OrderMagicNumber() == MAGIC_NUMBER) {
            if (OrderSymbol() == Symbol()) {
               if ((OrderType() == order_type_1) || (OrderType() == order_type_2)) {
                  trail_order(OrderTicket());
}  }  }  }  }  }