//+------------------------------------------------------------------+
//|                                          Bystruev_2009_08_28.mq4 |
//|                  opyright � 2009, Denis Bystruev, 28 August 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2009, Denis Bystruev, 28 August 2009"
#property link      "http://www.moeradio.ru"

#define  MAGIC_NUMBER   320090828

// ���� ������� ���� ����� �� ������� ������, ������������ ����� ����������� ���������� �����,
// ���� � �������, ��� �������� ������

extern int     bars_to_track  =  1250; // ���������� �����, ������� �����������
extern double  trailing_level =  0.5;  // ������� ��������� (0.5 = 50%)

double   lot;

// �������������� ������ ����
int init() {
   lot = MarketInfo(Symbol(), MODE_MINLOT);
}

double norm_price(double price) {
   double tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
   return (tick_size * MathRound(price / tick_size));
}

// �������� ������� - ����������� ������������� ��� ������ ����
int start() {
   // ������ buy/sell ������ (���� ����)
   trail_orders(OP_BUY, OP_SELL);   
   // ���, ���� ��������� ����� - �� ����, ���� ���� �����, �� �������
   if (total_orders() > 0) return;
   // ���� �� ������� �����, ��������� �� �����
   if (AccountFreeMargin() < lot * MarketInfo(Symbol(), MODE_MARGINREQUIRED)) return;
   // ����� ����� ��� ������ - OP_BUY ��� OP_SELL
   int order_type = -1;
   // ����� ����� ������� ����, ��������, ����������
   double price, stoploss, takeprofit;
   // ����� ������������ ��������� �������� ���������� �����
   int max_ask_index = iHighest(NULL, 0, MODE_HIGH, bars_to_track, 1);
   int min_bid_index = iLowest(NULL, 0, MODE_LOW, bars_to_track, 1);
   double max_ask = High[max_ask_index] + Point * MarketInfo(Symbol(), MODE_SPREAD);
   double min_bid = Low[min_bid_index];
   // ����� ������������ ������ ��� ������ �� �����
   string comment = "������������ ��������: " + max_ask + " (����� �����: " + max_ask_index + ")\n";
   comment = comment + "����������� ��������: " + min_bid + " (����� �����: " + min_bid_index + ")\n";
   comment = comment + "����� ����� �����: " + bars_to_track + "\n";
   // ���� ������� ������������ �������� ������ ����������� ���������, ������ sell limit ��� buy stop
   if (max_ask < Ask) {
      order_type = OP_SELLLIMIT;
      price = Ask + Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
      takeprofit = norm_price((min_bid + price) / 2.0);
      comment = comment + "������ �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
   }
   // ���� ������� ����������� �������� ������ ����������� ��������, ������ buy limit ��� sell stop
   if (Bid < min_bid) {
      order_type = OP_BUYLIMIT;
      price = Bid - Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
      takeprofit = norm_price((price + max_ask) / 2.0);
      comment = comment + "�������� �����: " + DoubleToStr(lot, 2) + ", �� ����: " + DoubleToStr(price, Digits);
   }
   stoploss = price + price - takeprofit;
   Comment(comment);
   // �������
   if (order_type >= 0) {
      int result = OrderSend(Symbol(), order_type, lot, price, 0, stoploss, takeprofit, NULL, MAGIC_NUMBER, 0);
      if (result < 0) {
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