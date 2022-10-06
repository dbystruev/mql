//+------------------------------------------------------------------+
//|                                              Agressive_Steps.mq4 |
//|                                   Copyright 2022, Denis Bystruev |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+
#include <stdlib.mqh>
#property copyright "Copyright © 2022, Denis Bystruev, 2–5 Oct 2022"
#property link      "https://github.com/dbystruev"
#property version   "22.10"
#property strict

//---- input parameters
extern  double  delta_step          =   0.00100;    // by how much to increase the price delta on each step
extern  double  delta_trailing      =   0.00050;    // stop loss trailing delta
extern  int     error_interval      =   60;         // the number of seconds to wait after any error
extern  double  lot_init            =   -1;         // the lot size to set initially (use minimum lot if negative)
extern  double  lot_step            =   -1;         // by how much to increase the lot size on each step (use lot_init if negative)
extern  int     open_orders_max     =   5;          // the maximum number of open limit/stop orders
extern  int     restart_interval    =   3600;       // restart interval in seconds if no market orders are present
extern  bool    use_limit_orders    =   true;       // use limit (true) or stop (false) orders
extern  bool    use_sell_orders     =   true;       // use sell (true) or buy (false) orders

//---- variables
double      lot_current;    // 0.10, 0.20, 0.30, ...
int         market_orders;  // the number of market orders
datetime    no_error_time;  // the time when trading is allowed after the error 
datetime    restart_time;   // the time of the next restart
double      profitable_sl;  // -1 or stop loss with positive profit

//+---------------------------------------------------------------------+
//| Get the price above given which is rounded to given delta           |
//| Parameters:                                                         |
//|     price — non-rounded price (usually Ask, e.g. 0.98053)           |
//|     delta — delta to which the price should be rounded (e.g. 0.001) |
//| Returns:                                                            |
//|     price above given rounded to given delta (e.g. 0.98100)         |
//+---------------------------------------------------------------------+
double above(double price, double delta) {
    return delta * ceil(price / delta);
}

//+---------------------------------------------------------------------+
//| Get the price below given which is rounded to given delta           |
//| Parameters:                                                         |
//|     price — non-rounded price (usually Bid, e.g. 0.98035)           |
//|     delta — delta to which the price should be rounded (e.g. 0.001) |
//| Returns:                                                            |
//|     price below given rounded to given delta (e.g. 0.98000)         |
//+---------------------------------------------------------------------+
double below(double price, double delta) {
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
        if (OrderDelete(OrderTicket())) continue;
        Print("OrderDelete(", OrderTicket(), "): ", ErrorDescription(GetLastError()));
        no_error_time = TimeCurrent() + error_interval;
    }
    set_restart_time();
}

//+---------------------------------------------------------------------+
//| Find maximum lot among open orders                                  |
//| Returns:                                                            |
//|     0 if there are no orders, or maximum lot among open orders      |
//+---------------------------------------------------------------------+
double find_max_lot() {
    double max_lot = 0;
    for (int i = 0; i < OrdersTotal(); i++) {
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        max_lot = fmax(max_lot, OrderLots());
     }
    return max_lot;
}

//+---------------------------------------------------------------------+
//| Find maximum open price among all orders                            |
//| Returns:                                                            |
//|     Maximum open price among all orders or Ask                      |
//+---------------------------------------------------------------------+
double find_max_price() {
    double max_price = 0;
    for (int i = 0; i < OrdersTotal(); i++) {
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        max_price = fmax(max_price, OrderOpenPrice());
    }
    return max_price == 0 ? Ask : max_price;
}

//+---------------------------------------------------------------------+
//| Find minimum open price among all orders                            |
//| Returns:                                                            |
//|     Minimum open price among all orders or Bid                      |
//+---------------------------------------------------------------------+
double find_min_price() {
    const double max_double = 1.7976931348623158e+308;
    double min_price = max_double;
    for (int i = 0; i < OrdersTotal(); i++) {
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        min_price = fmin(min_price, OrderOpenPrice());
    }
    return min_price == max_double ? Bid : min_price;
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
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        if (!is_market_order(OrderType())) continue;
        total++;
    }
    return total;
}

//+---------------------------------------------------------------------+
//| Calculate the new stop loss for the orders above Ask or below Bid   |
//+---------------------------------------------------------------------+
double new_stop_loss() {
    return use_sell_orders ? above(Ask + delta_trailing, delta_trailing) : below(Bid - delta_trailing, delta_trailing);
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
    show_comments();
    // Wait for the error to expire
    if (TimeCurrent() < no_error_time) return;
    // Reload non-market orders if there were no movements for a long time
    if (restart_time < TimeCurrent()) {
        if (market_orders_total() < 1) {
            delete_non_market_orders();
            setup_vars();
        }
    }
    // Check if all market orders were closed
    if ((0 < market_orders) && (market_orders_total() < 1)) {
        delete_non_market_orders();
        setup_vars();
    }
    send_new_orders_if_needed();
    update_vars();
    trail_orders_if_possible();
}

//+---------------------------------------------------------------------+
//| Convert order type to string                                        |
//| Parameters:                                                         |
//|     - order_type — order type                                       |
//| Returns:                                                            |
//|     string representing order type                                  |
//+---------------------------------------------------------------------+
string OrderTypeToString(int order_type) {
    switch (order_type) {
        case OP_BUY:
            return "BUY";
        case OP_BUYLIMIT:
            return "BUY LIMIT";
        case OP_BUYSTOP:
            return "BUY STOP";
        case OP_SELL:
            return "SELL";
        case OP_SELLLIMIT:
            return "SELL LIMIT";
        case OP_SELLSTOP:
            return "SELL STOP";
        default:
            return "unknown";
    }
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
        double min_lot = fmax(lot_init, MarketInfo(Symbol(), MODE_MINLOT));
        double step = lot_step < 0 ? min_lot : lot_step;
        double lot = lot_current < min_lot ? min_lot : lot_current + step;
        // use_limit_orders and use_sell_orders (SELL_LIMIT) -> above
        // use_limit_orders, but don't use_sell_orders (BUY_LIMIT) -> below
        // don't use_limit_orders, but use_sell_orders (SELL_STOP) -> below
        // don't use_limit_orders, don't use_sell_orders (BUY_STOP) -> above
        double price = use_limit_orders == use_sell_orders
            ? above(find_max_price() + delta, delta_step)
            : below(find_min_price() - delta, delta_step);
        if (0 < OrderSend(Symbol(), order_type, lot, price, 0, 0, 0)) {
            lot_current = lot;
        } else {
            Print("OrderSend(", Symbol(), ", ", order_type, ", ", lot, ", ", price, ", 0, 0, 0): ", ErrorDescription(GetLastError()));
            no_error_time = TimeCurrent() + error_interval;
        }
    }
}

//+---------------------------------------------------------------------+
//| Set the time when to delete / reload market orders                  |
//+---------------------------------------------------------------------+
void set_restart_time() {
    restart_time = TimeCurrent() + restart_interval;
}

//+---------------------------------------------------------------------+
//| Initial setup of variables — called from OnInit() once              |
//+---------------------------------------------------------------------+
void setup_vars() {
    lot_current = find_max_lot();
    market_orders = market_orders_total();
    no_error_time = TimeCurrent();
    profitable_sl = -1;
}

//+---------------------------------------------------------------------+
//| Show comments information for visual debugging                      |
//+---------------------------------------------------------------------+
void show_comments() {
    string comment = "";
    if (TimeCurrent() < restart_time) {
        comment = "Refresh in " + TimeToString(restart_time - TimeCurrent(), TIME_SECONDS) + "\n";
    }
    comment += "Balance: " + DoubleToString(AccountBalance(), 2);
    comment += ", Equity: " + DoubleToString(AccountEquity(), 2);
    comment += ", Profit: " + DoubleToString(AccountEquity() - AccountBalance(), 2);
    comment += "\nProfitable SL: " + DoubleToString(profitable_sl, Digits);
    comment += ", new SL: " + DoubleToString(new_stop_loss(), Digits);
    double delta = (profitable_sl - new_stop_loss()) * (use_sell_orders ? 1 : -1);
    if (0 < profitable_sl) {
        comment += ", delta: " + DoubleToString(delta, Digits);
    }
    for (int i = 0; i < OrdersTotal(); i++) {
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        comment += "\n" + OrderTypeToString(OrderType());
        comment += " " + DoubleToString(OrderLots(), 2);
        comment += " at " + DoubleToString(OrderOpenPrice(), Digits);
        comment += ", SL " + DoubleToString(OrderStopLoss(), Digits);
        comment += ", profit " + DoubleToString(OrderProfit(), 2);
    }
    // Delay in visual mode
    //int delay = IsVisualMode() && (0 < delta) ? 100000 : 1;
    int delay = IsVisualMode() && (0 < market_orders_total()) && (delta < 0) ? 100000 : 1;
    for (int i = 0; i < delay; i++) Comment(comment);
}

//+---------------------------------------------------------------------+
//| If account equity is above account balance, change orders' stops    |
//+---------------------------------------------------------------------+
void trail_orders_if_possible() {
    if ((AccountEquity() < AccountBalance()) || (profitable_sl < 0)) return;
    if (market_orders_total() < 1) return;
    double new_sl = new_stop_loss();
    if (use_sell_orders) {
        if (new_sl < profitable_sl) {
            update_stop_loss(new_sl);
        }
    } else {
        if (profitable_sl < new_sl) {
            update_stop_loss(new_sl);
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
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        if (!is_market_order(OrderType())) continue;
        bool should_modify = (OrderStopLoss() == 0) || (use_sell_orders ? sl < OrderStopLoss() : OrderStopLoss() < sl);
        if (!should_modify) continue;
        if (OrderModify(OrderTicket(), OrderOpenPrice(), sl, 0, 0)) continue;
        Print("OrderModify(", OrderTicket(), ", ", OrderOpenPrice(), ", ", sl, ", 0, 0): ", ErrorDescription(GetLastError()));
        no_error_time = TimeCurrent() + error_interval;
    }
}

//+---------------------------------------------------------------------+
//| Update variables — called from OnTick() on every tick               |
//+---------------------------------------------------------------------+
void update_vars() {
    if (AccountBalance() < AccountEquity()) {
        if (profitable_sl < 0) {
            profitable_sl = use_sell_orders ? Ask : Bid;
        } else {
            profitable_sl = use_sell_orders ? fmax(profitable_sl, Ask) : fmin(profitable_sl, Bid);
        }
    }
    market_orders = market_orders_total();
    if (market_orders < 1) {
        setup_vars();
    }
}