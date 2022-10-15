//+------------------------------------------------------------------+
//|                                              Agressive_Steps.mq4 |
//|                                   Copyright 2022, Denis Bystruev |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+
#include <stdlib.mqh>
#property copyright "Copyright © 2022, Denis Bystruev, 2–14 Oct 2022"
#property link      "https://github.com/dbystruev"
#property version   "22.10"
#property strict

//---- input parameters
extern  double  delta_trailing      =   0.00050;    // delta_trailing: stop loss trailing delta
extern  int     error_interval      =   60;         // error_interval: the number of seconds to wait after any error
extern  double  min_lot_balance     =   -1;         // min_lot_balance: account balance to match min lot, -1 — start from current
extern  int     open_orders_max     =   5;          // open_orders_max: the maximum number of open limit/stop orders
extern  int     restart_interval    =   3600;       // restart_interval: in seconds if no market orders are present
extern  bool    use_fibonacci       =   true;       // use fibonacci numbers for delta step
extern  bool    use_limit_orders    =   true;       // use limit (true) or stop (false) orders
extern  bool    use_sell_orders     =   true;       // use sell (true) or buy (false) orders

//---- variables
double      lot_balance;    // account balance to match min lot
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
//| Calculate the delta for a given step                                |
//| Parameters:                                                         |
//|     step — the step to calculate delta for, usually OrdersTotal()   |
//| Returns:                                                            |
//|     fibonacci(steap), if use_fibonacci is true                      |
//|     step, if use_fibonacci is false                                 |
//+---------------------------------------------------------------------+
int get_delta(int step) {
    if (!use_fibonacci) return step;
    const double sqrt5 = sqrt(5);
    const double golden_ratio = (1 + sqrt5) / 2;
    const int delta = (int) round(pow(golden_ratio, step) / sqrt5);
    return delta;
}

//+---------------------------------------------------------------------+
//| Calculate delta step based on current balance                       |
//| Returns:                                                            |
//|     0.01 if balance is 100, sqrt(balance) = 10                      |
//|     0.001 if balance is 10000, sqrt(balance) = 100                  |
//+---------------------------------------------------------------------+
double get_delta_step() {
    if (AccountBalance() < 0.01) return 1;
    const double spread = Point * MarketInfo(Symbol(), MODE_SPREAD);
    const double stop_level = Point * MarketInfo(Symbol(), MODE_STOPLEVEL);
    const double min_delta_step = fmax(spread, stop_level);
    const double raw_delta_step = (Ask + Bid) / 2 / open_orders_max / sqrt(AccountBalance());
    const double delta_step = fmax(min_delta_step, raw_delta_step);
    return NormalizeDouble(delta_step, 3);
}

//+---------------------------------------------------------------------+
//| Calculate the lot for a given step                                  |
//| Parameters:                                                         |
//|     step — the step to calculate the lot for, usually OrdersTotal() |
//| Returns:                                                            |
//|     new lot based on market min lot and lot step                    |
//+---------------------------------------------------------------------+
double get_lot(int step) {
    const double min_lot = MarketInfo(Symbol(), MODE_MINLOT);
    const double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);
    const double lot = min_lot + step * lot_step;
    const double lot_mult = lot_balance / AccountBalance();
    const double rounded_lot = lot_step * round(lot * lot_mult / lot_step);
    return fmax(min_lot, rounded_lot);
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
    lot_balance = min_lot_balance < 0 ? AccountBalance() : min_lot_balance;
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
    const int orders_to_open = open_orders_max - non_market_orders_total();
    if (orders_to_open < 1) return;
    const int order_type = use_limit_orders
        ? use_sell_orders ? OP_SELLLIMIT : OP_BUYLIMIT
        : use_sell_orders ? OP_SELLSTOP : OP_BUYSTOP;
    for (int i = 0; i < orders_to_open; i++) {
        const int orders_total = OrdersTotal();
        const double delta_step = get_delta_step();
        const double delta = get_delta(orders_total) * delta_step;
        const double lot = get_lot(orders_total);
        // use_limit_orders and use_sell_orders (SELL_LIMIT) -> above
        // use_limit_orders, but don't use_sell_orders (BUY_LIMIT) -> below
        // don't use_limit_orders, but use_sell_orders (SELL_STOP) -> below
        // don't use_limit_orders, don't use_sell_orders (BUY_STOP) -> above
        const double price = use_limit_orders == use_sell_orders
            ? above(find_max_price() + delta, delta_step)
            : below(find_min_price() - delta, delta_step);
        if (0 < OrderSend(Symbol(), order_type, lot, price, 0, 0, 0)) continue;
        Print("OrderSend(", Symbol(), ", ", order_type, ", ", lot, ", ", price, ", 0, 0, 0): ", ErrorDescription(GetLastError()));
        no_error_time = TimeCurrent() + error_interval;
    }
}

//+---------------------------------------------------------------------+
//| Set the time when to delete / reload market orders                  |
//+---------------------------------------------------------------------+
void set_restart_time() {
    restart_time = TimeCurrent() + restart_interval;
}

//+---------------------------------------------------------------------+
//| Initial setup of variables — called when there are no market orders |
//+---------------------------------------------------------------------+
void setup_vars() {
    market_orders = market_orders_total();
    no_error_time = TimeCurrent();
    profitable_sl = -1;
}

//+---------------------------------------------------------------------+
//| Show comments information for visual debugging                      |
//+---------------------------------------------------------------------+
void show_comments() {
    string comment = "";
    const string nl = "\n                                        ";
    if (TimeCurrent() < restart_time) {
        comment = nl + "Refresh in " + TimeToString(restart_time - TimeCurrent(), TIME_SECONDS);
    }
    comment += nl + "Balance: " + DoubleToString(AccountBalance(), 2);
    comment += ", Equity: " + DoubleToString(AccountEquity(), 2);
    comment += ", Profit: " + DoubleToString(AccountEquity() - AccountBalance(), 2);
    comment += nl + "Min lot balance: " + DoubleToString(lot_balance, 2);
    comment += " (" + DoubleToString(100 * lot_balance / AccountBalance(), 2) + "% of balance)";
    comment += nl + "Delta step: " + DoubleToString(get_delta_step(), Digits);
    comment += nl + "Profitable SL: " + DoubleToString(profitable_sl, Digits);
    comment += ", new SL: " + DoubleToString(new_stop_loss(), Digits);
    double delta = (profitable_sl - new_stop_loss()) * (use_sell_orders ? 1 : -1);
    if (0 < profitable_sl) {
        comment += ", delta: " + DoubleToString(delta, Digits);
    }
    for (int i = 0; i < OrdersTotal(); i++) {
        if (!OrderSelect(i, SELECT_BY_POS)) continue;
        comment += nl + OrderTypeToString(OrderType());
        const double lots = OrderLots();
        comment += " " + DoubleToString(lots, 2);
        comment += " at " + DoubleToString(OrderOpenPrice(), Digits);
        comment += ", SL " + DoubleToString(OrderStopLoss(), Digits);
        comment += ", profit " + DoubleToString(OrderProfit(), 2);
        const double expected_lot = get_lot(i);
        if (expected_lot == lots) continue;
        comment += ", expected lot " + DoubleToString(expected_lot, 2);
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