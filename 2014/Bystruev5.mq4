//+------------------------------------------------------------------+
//|                                                    Bystruev5.mq4 |
//|                    Copyright � 2009, Denis Bystruev, 21 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2009, Denis Bystruev, 21-22 Feb 2009"
#property link      "http://www.moeradio.ru"

// �� ������� ����� ����������� ��� ���������
// ��� ��������� ��� �������� ������� ������ ����
extern int  lot_factor        = 10;     // 0 - ������ ���� �� ��������

// ����� �������, �� ������� ������ �������� take profit
extern int  take_profit_step  = 50;

// ����� �������, �� ������� ������ �������� stop loss
extern int  stop_loss_step    = 10;

// ������� ����� buy/sell
// ���� �� < 0, � ��� ���� ������ buy (take profit ��� buy + stop loss ��� sell)
// ���� �� > 0, � ��� ���� ������ sell (take profit ��� sell + stop loss ��� buy)
// ���� �� = 0, � ��� ���� ���������� ����� buy � sell �������
int         buy_sell_count;

// ������� ���������/����������
// ���� �� < 0, � ��� ���� ������ ����������
// ���� �� > 0, � ��� ���� ������ ���������
// ���� �� = 0, ��������� � ���������� ���� �������
int         win_lost_count;

double      balance;             // ������� �������� ������ �����
double      min_balance = 0.5;   // ����������� ������ (�� ����������� ������������)
double      max_balance;         // ����������� ����������� ������ �����
double      lot;                 // ������� ������ ����
double      max_lot;             // ������������ ������ ����
double      min_lot;             // ����������� ������ ����
int         order_direction;     // ����������� ���������� ������: -1 (buy) ��� 1 (sell)
double      price;               // ���� ���������� ������
int         ticket;              // ����� ������

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   MathSrand( TimeLocal() );     // ������������� ���������� ��������� �����
   buy_sell_count = 0;           // �������� ������� ����� buy/sell
   win_lost_count = 0;           // �������� ������� ���������/����������
   balance = AccountBalance();   // ���������� ������� ������ �����
   max_balance = balance;        // ���� ��� ������������ ������ ����� ��������
   max_lot = MarketInfo( Symbol(), MODE_MAXLOT );  // ���������� ������������ ���
   min_lot = MarketInfo( Symbol(), MODE_MINLOT );  // ���������� ����������� ���
   lot = min_lot;                // �������� � ������������ ����
   order_direction = 0;          // � ������ ����������� ��� ����������
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
            // ���� Bid �� ����� �� ����������� ������� - ���, ����� ������
            if (( price - stop_loss_step * Point < Bid ) && ( Bid < price + take_profit_step * Point )) return;
            // ����� ������� ������� buy order
            while( !OrderClose( ticket, lot, Bid, 0 )) {}
            break;
         case 1:
            // ���� Ask �� ����� �� ����������� ������� - ���, ����� ������
            if (( price - take_profit_step * Point < Ask ) && ( Ask < price + stop_loss_step * Point )) return;
            // ����� ������� ������� sell order
            while( !OrderClose( ticket, lot, Ask, 0 )) {}
            break;
      }
   }
   // ���� �������� ������������ �������, ������ ������ �� ������
   if ( AccountBalance() < min_balance * max_balance ) return;
   // ���� ����������� = 0, �� � ������, � �������� ������� �� ����
   if ( order_direction != 0 ) {
      // ���� ������ ���������� - �������� take profit, ���� ���������� - stop loss
      if ( AccountBalance() < balance ) {
         win_lost_count--;    // ������ ����������, �������� stop loss, �� ���������
         // ���� ����������� ���� buy (-1), � �� ���������, ������, ��� ��� sell (+1)
         // ���� ����������� ���� sell (1), � �� ���������, ������, ��� ��� buy (-1)
         buy_sell_count -= order_direction;
         // ����������� ������ ���� ��-�� ���������
         lot = MathMin( max_lot, lot + lot_factor * MarketInfo( Symbol(), MODE_LOTSTEP ));
      } else {
         win_lost_count++;    // ������ ����������, �������� take profit, �� ��������
         // ���� ����������� ���� buy (-1), � �� ��������, ������, ��� ��� buy (-1)
         // ���� ����������� ���� sell (1), � �� ��������, ������, ��� ��� sell (+1)
         buy_sell_count += order_direction;
         // ��������� ������ ���� ��-�� ��������
         lot = MathMax( min_lot, lot - lot_factor * MarketInfo( Symbol(), MODE_LOTSTEP ));
      }
   }
   // ���������� ����� ������, ��� ��� ������� ���, �� AccountBalance() = AccountEquity()
   balance = AccountBalance();
   // ���� ��������� ����������� ����������� ����� ������, ���������� lot � ��������� ��������
   if ( max_balance < balance ) {
      lot = min_lot;                // �������� ����� � ������������ ����
      max_balance = balance;        // ������������� ����� ������������ ������
      buy_sell_count = 0;           // �������� ������� ����� buy/sell
      win_lost_count = 0;           // �������� ������� ���������/����������
   }
   // ���������� �������� � ����������� �� ����� ����� � �� ��� ���� �������
   if (buy_sell_count < 0) {
      order_direction = -1;          // ���� ������ buy, ������, ���������� buy (-1)
   } else if (buy_sell_count > 0) {
      order_direction = 1;         // ���� ������ sell, ������, ���������� sell (1)
   } else {                         // ����� ������� buy_sell_count ����� ����
      // ��������� order_direction, ��� ���, ������ ���� �� �� ��� ����� ���� (������)
      if (order_direction == 0) {   // � ���� ������ �������� �������� -1 (buy) ��� 1 (sell)
         order_direction = 2 * MathRand() / 32768 - 1;
      }
   }
   switch ( order_direction ) {
      case -1:
         ticket = -1;
         // ������� ������� buy order, ���� �� �� ���������
         while( ticket < 0 ) {
            price = Ask;
            ticket = OrderSend( Symbol(), OP_BUY, lot, price, 0, 0.0, 0.0 );
         }
         break;
      case 1:
         ticket = -1;
         // ������� ������� sell order, ���� �� �� ���������
         while( ticket < 0 ) {
            price = Bid;
            ticket = OrderSend( Symbol(), OP_SELL, lot, price, 0, 0.0, 0.0 );
         }
         break;
   }
}
//+------------------------------------------------------------------+