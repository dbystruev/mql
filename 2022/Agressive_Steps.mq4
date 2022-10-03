//+------------------------------------------------------------------+
//|                                              Agressive_Steps.mq4 |
//|                                   Copyright 2022, Denis Bystruev |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+
#include <stdlib.mqh>
#property copyright "Copyright © 2022, Denis Bystruev, 2–3 Oct 2022"
#property link      "https://github.com/dbystruev"
#property version   "22.10"
#property strict

//---- input parameters
extern  double  delta_init          =   0.00100;    // the initial price delta
extern  double  delta_step          =   0.00100;    // by how much to increase the price delta on each step
extern  double  delta_trailing      =   0.00050;    // stop loss trailing delta
extern  double  lot_init            =   0.10;       // the lot size to set initially
extern  double  lot_step            =   0.10;       // by how much to increase the lot size on each step
extern  int     open_orders_max     =   5;          // the maximum number of open limit/stop orders
extern  int     restart_interval    =   3600;       // restart interval in seconds if no market orders are present
extern  bool    use_limit_orders    =   true;       // use limit (true) or stop (false) orders
extern  bool    use_sell_orders     =   true;       // use sell (true) or buy (false) orders

//---- variables
double      delta_current;  // 0.00100, 0.00200, 0.00300, ...
double      lot_current;    // 0.10, 0.20, 0.30, ...
datetime    restart_time;   // the time of the next restart
double      stop_loss;      // -1 or stop loss with positive profit

//+---------------------------------------------------------------------+
//| Get price above given price which is rounded to delta init / step   |
//| Parameters:                                                         |
//|     price — non-rounded price (usually Ask, e.g. 0.98053)           |
//| Returns:                                                            |
//|     price above given rounded to delta init / step (e.g. 0.98100)   |
//+---------------------------------------------------------------------+
double above(double price) {
    double delta = fmax(delta_init, delta_step);
    return delta * ceil(price / delta);
}

//+---------------------------------------------------------------------+
//| Get price below given price which is rounded to delta init / step   |
//| Parameters:                                                         |
//|     price — non-rounded price (usually Bid, e.g. 0.98035)           |
//| Returns:                                                            |
//|     price below given rounded to delta init / step (e.g. 0.98000)   |
//+---------------------------------------------------------------------+
double below(double price) {
    double delta = fmax(delta_init, delta_step);
    return delta * floor(price / delta);
}

//+---------------------------------------------------------------------+
//| Find and delete all non-market orders                               |
//| Called from OnInit() once                                           |
//+---------------------------------------------------------------------+
void delete_non_market_orders() {
    for (int i = OrdersTotal() - 1; 0 <= i; i--) {
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        if (is_market_order(OrderType())) continue;
        if (!OrderDelete(OrderTicket())) {
            Print(ErrorDescription(GetLastError()));
        }
    }
}

//+---------------------------------------------------------------------+
//| Find a price above Ask or below Bid to place the first order        |
//| Returns:                                                            |
//|     price above Ask or below Bid to place the first order           |
//+---------------------------------------------------------------------+
double find_base_price() {
    // use_limit_orders and use_sell_orders (SELL_LIMIT) -> Ask
    // use_limit_orders, but do not use_sell_orders (BUY_LIMIT) -> Bid
    // do not use_limit_orders, but use_sell_orders (SELL_STOP) -> Bid
    // do not use_limit_orders, and do not use_sell_orders (BUY_STOP) -> Ask
    return use_limit_orders == use_sell_orders ? above(Ask) : below(Bid);
}

//+---------------------------------------------------------------------+
//| Find maximum delta between orders, taking base price into account   |
//| Returns:                                                            |
//|     Maximum delta between orders, taking base price into account    |
//+---------------------------------------------------------------------+
double find_max_delta() {
    int orders_total = OrdersTotal();
    if (orders_total < 1) return 0;
    double prices[];
    if (ArrayResize(prices, orders_total + 1) < 0) return 0;
    prices[0] = find_base_price();
    int prices_added = 1;
    for (int i = 0; i < orders_total; i++) {
        if (OrderSelect(i, SELECT_BY_POS)) {
            prices[prices_added++] = OrderOpenPrice();
        }
    }
    if (ArraySize(prices) != prices_added) {
        ArrayResize(prices, prices_added);
    }
    ArraySort(prices);
    double max_delta = 0;
    for (int i = 1; i < prices_added; i++) {
        max_delta = fmax(max_delta, prices[i] - prices[i - 1]);
    }
    return max_delta;
}

//+---------------------------------------------------------------------+
//| Find maximum lot among open orders                                  |
//| Returns:                                                            |
//|     0 if there are no orders, or maximum lot among open orders      |
//+---------------------------------------------------------------------+
double find_max_lot() {
    double max_lot = 0;
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS)) {
            max_lot = fmax(max_lot, OrderLots());
        }
     }
    return max_lot;
}

//+---------------------------------------------------------------------+
//| Find maximum open price among all orders                            |
//| Returns:                                                            |
//|     Maximum open price among all orders or Ask                      |
//+---------------------------------------------------------------------+
double find_max_price() {
    double max_price = above(Ask);
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS)) {
            max_price = fmax(max_price, OrderOpenPrice());
        }
    }
    return max_price;
}

//+---------------------------------------------------------------------+
//| Find minimum open price among all orders                            |
//| Returns:                                                            |
//|     Minimum open price among all orders or Bid                      |
//+---------------------------------------------------------------------+
double find_min_price() {
    double min_price = below(Bid);
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS)) {
            min_price = fmin(min_price, OrderOpenPrice());
        }
    }
    return min_price;
}

//+---------------------------------------------------------------------+
//| Check if given order type is a market order (OP_BUY or OP_SELL)     |
//| Parameters:                                                         |
//|     order_type — order type                                         |
//| Returns:                                                            |
//|     true if order_type is OP_BUY or OP_SELL, false otherwise        |
//+---------------------------------------------------------------------+
bool is_market_order(int order_type) {
    return (order_type == OP_BUY) || (order_type == OP_SELL);
}

//+---------------------------------------------------------------------+
//| Count the number of market orders (OP_BUY or OP_SELL)       |
//| Returns:                                                            |
//|     the number of market orders (OP_BUY or OP_SELL)         |
//+---------------------------------------------------------------------+
int market_orders_total() {
    int total = 0;
    for (int i = 0; i < OrdersTotal(); i++) {
        if (is_market_order(OrderType())) {
            total++;
        }
    }
    return total;
}

//+---------------------------------------------------------------------+
//| Count the number of non-market orders (not OP_BUY or OP_SELL)       |
//| Returns:                                                            |
//|     the number of non-market orders (not OP_BUY or OP_SELL)         |
//+---------------------------------------------------------------------+
int non_market_orders_total() {
    return OrdersTotal() - market_orders_total();
}

//+---------------------------------------------------------------------+
//| Expert initialization function — called once                        |
//+---------------------------------------------------------------------+
int OnInit() {
    delete_non_market_orders();
    setup_vars();
    return(INIT_SUCCEEDED);
}

//+---------------------------------------------------------------------+
//| Expert tick function — called on every tick                         |
//+---------------------------------------------------------------------+
void OnTick() {
    if (restart_time < TimeCurrent()) {
        if (market_orders_total() < 1) {
            delete_non_market_orders();
            setup_vars();
        }
    }
    send_new_orders_if_needed();
    trail_orders_if_possible();
    update_vars();
}

//+---------------------------------------------------------------------+
//| Send new orders if not enough of them are open                      |
//+---------------------------------------------------------------------+
void send_new_orders_if_needed() {
    int orders_to_open = open_orders_max - non_market_orders_total();
    if (orders_to_open < 1) return;
    int order_type = use_limit_orders
        ? use_sell_orders ? OP_SELLLIMIT : OP_BUYLIMIT
        : use_sell_orders ? OP_SELLSTOP : OP_BUYSTOP;
    for (int i = 0; i < orders_to_open; i++) {
        double delta = OrdersTotal() * delta_step;
        double lot = lot_current == 0 ? lot_init : lot_current + lot_step;
        double price = use_limit_orders == use_sell_orders ? find_max_price() + delta : find_min_price() - delta;
        if (0 < OrderSend(Symbol(), order_type, lot, price, 0, 0, 0)) {
            delta_current = delta;
            lot_current = lot;
        } else {
            Print(ErrorDescription(GetLastError()));
        }
    }
}

//+---------------------------------------------------------------------+
//| Initial setup of variables — called from OnInit() once              |
//+---------------------------------------------------------------------+
void setup_vars() {
    delta_current = find_max_delta();
    lot_current = find_max_lot();
    restart_time = TimeCurrent() + restart_interval;
    stop_loss = -1;
}

//+---------------------------------------------------------------------+
//| If account equity is above account balance, change orders' stops    |
//+---------------------------------------------------------------------+
void trail_orders_if_possible() {
    if (AccountEquity() < AccountBalance()) return;
    if (use_limit_orders == use_sell_orders) {
        double new_sl = Ask + delta_trailing;
        if (new_sl < stop_loss) {
            update_stop_loss(stop_loss);
        }
    } else {
        double new_sl = Bid - delta_trailing;
        if (stop_loss < new_sl) {
            update_stop_loss(stop_loss);
        }
    }
}

//+---------------------------------------------------------------------+
//| Update stop loss in market orders                                   |
//| Parameters:                                                         |
//|     — sl — stop loss to set in orders                               |
//+---------------------------------------------------------------------+
void update_stop_loss(double sl) {
    for (int i = 0; i < OrdersTotal(); i++) {
        if (OrderSelect(i, SELECT_BY_POS)) {
            if (is_market_order(OrderType())) {
                if (!OrderModify(OrderTicket(), OrderOpenPrice(), sl, 0, 0)) {
                    Print(ErrorDescription(GetLastError()));
                }
            }
        }
    }
}

//+---------------------------------------------------------------------+
//| Update variables — called from OnTick() on every tick               |
//+---------------------------------------------------------------------+
void update_vars() {
    if (AccountBalance() < AccountEquity()) {
        if (stop_loss < 0) {
            stop_loss = use_limit_orders == use_sell_orders ? Bid : Ask;
        } else {
            stop_loss = use_limit_orders == use_sell_orders ? fmax(stop_loss, Bid) : fmin(stop_loss, Ask);
        }
    }
    if (market_orders_total() < 1) {
        setup_vars();
    }
}