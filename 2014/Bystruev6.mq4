//+------------------------------------------------------------------+
//|                                                    Bystruev6.mq4 |
//|                    Copyright � 2009, Denis Bystruev, 23 Feb 2009 |
//|                                           http://www.moeradio.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright � 2009, Denis Bystruev, 23 Feb 2009"
#property link      "http://www.moeradio.ru"

// ���� ����� �������� � ���������.
// �����������, � ������� ������ ���������� ����� ���� ��� � ����� �����������.
// ��� ������ ��� ���������� �������� �������� �������� (max_ticks), ��������� � ��� �� �����������
// ���� ������� - trailing stop, ���� �� ������� - ������ stop loss

extern int  max_ticks   = 4;  // ������� ��� ���� ������ ���� � ����� �����������
extern int  max_move    = 25; // ����� ������ �� ����� ���������� ����� ����� �����������

int         direction;        // ����������� �������� ����: -1 - ����, 0 - ���������, 1 - �����
double      last_bid;         // ���������� ���� bid
double      lot;              // ������� ������ ����
int         move;             // �� ����� ���������� ������� ���������� ����
double      stop_loss;        // ������ ����-�����
int         ticks;            // ���������� ����� � ����� �����������

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
   direction_ticks(0, 0);                                      // ����������� �������� ���� �� �����, �������� ���-�� �����
   last_bid = Bid;                                             // ���������� ������� ����
   lot = MarketInfo( Symbol(), MODE_MINLOT );                  // ������������� ���������� ��������� ������ ����
   stop_loss = MarketInfo( Symbol(), MODE_STOPLEVEL ) * Point; // ������������� ���������� ��������� ����-����
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {
   double   new_bid = Bid;                                     // ���������� ������� �������� ���� bid
   switch ( direction ) {
      case -1:                                                 // ����������� �������� ���� ����
         if ( new_bid < last_bid ) ticks++;                    // ���� ���������� ��������� ����
         if ( last_bid < new_bid ) direction_ticks( 1, 1 );    // ���� ����� �����
         break;
      case 0:                                                  // ������ ��� ���� �� ���������
         if ( new_bid < last_bid ) direction_ticks( -1, 1 );   // ���� �������� ����
         if ( last_bid < new_bid ) direction_ticks( 1, 1);     // ���� �������� �����
         break;
      case 1:                                                  // ����������� �������� ���� �����
         if ( new_bid < last_bid ) direction_ticks( -1, 1 );   // ���� ����� ����
         if ( last_bid < new_bid ) ticks++;                    // ���� ���������� ��������� �����
         break;
   }
   move += MathAbs( MathRound(( last_bid - new_bid ) / Point ));
   last_bid = new_bid;                                         // ���������� ������� ���� bid
   if ( OrdersTotal() == 0 ) {                                 // ������� ��� - ����� ������������� �����
      change_lot();                                            // �������� ������ ����
      if(( ticks >= max_ticks ) && ( move >= max_move )) send_order();                   // ���������� ����� � ����� ����������� �������� �������
   }
   if ( OrdersTotal() > 0 ) update_order();                    // ��������� ����-����
}
//+------------------------------------------------------------------+
//| ������������� ����������� direction � ����� ����� ticks          |
//+------------------------------------------------------------------+
void direction_ticks ( int d, int t ) {
   direction = d;
   ticks = t;
   move = 0;
}
//+------------------------------------------------------------------+
//| �������� ������ ����                                             |
//+------------------------------------------------------------------+
void change_lot() {
}
//+------------------------------------------------------------------+
//| ��������� ����� � ������ ��� �����������                         |
//+------------------------------------------------------------------+
void send_order() {
   switch ( direction ) {
      case -1:                                                 // ���� ��� ���� - ��������� ����� �� �������
         while( !OrderSend( Symbol(), OP_SELL, lot, Bid, 0, Ask + stop_loss, 0.0 )) {}
         break;
      case 1:                                                  // ���� ��� ����� - ��������� ����� �� �������
         while( !OrderSend( Symbol(), OP_BUY, lot, Ask, 0, Bid - stop_loss, 0.0 )) {}
         break;
   }
}
//+------------------------------------------------------------------+
//| ������������� stop loss ��� �������� ���� �� �������� �����      |
//+------------------------------------------------------------------+
void update_order() {
   double   new_stop_loss;                                     // ����� �������� stop loss
   if ( OrderSelect( 0, SELECT_BY_POS )) {                     // �������, ��� � ��� ������ ���� �����
      switch ( OrderType() ) {                                 // ��� ������ ���� buy, ���� sell
         case OP_BUY:
            new_stop_loss = Bid - stop_loss;
            if ( OrderStopLoss() < new_stop_loss )
               OrderModify( OrderTicket(), OrderOpenPrice(), new_stop_loss, 0.0, 0 );
            break;
         case OP_SELL:
            new_stop_loss = Ask + stop_loss;
            if ( new_stop_loss < OrderStopLoss() )
               OrderModify( OrderTicket(), OrderOpenPrice(), new_stop_loss, 0.0, 0 );
            break;
      }
   }
}