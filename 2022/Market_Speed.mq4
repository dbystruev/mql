//+------------------------------------------------------------------+
//|                                                 Market_Speed.mq4 |
//|                                   Copyright 2022, Denis Bystruev |
//|                                     https://github.com/dbystruev |
//+------------------------------------------------------------------+
#include <stdlib.mqh>
#property copyright "Copyright © 2022, Denis Bystruev, 7 Oct 2022"
#property link      "https://github.com/dbystruev"
#property version   "22.10"
#property strict

//---- variables
double      max_ask_down_speed;         // Maximum speed for Ask going down
datetime    max_ask_down_speed_time;    // Maximum Ask down speed timestamp
double      max_ask_up_speed;           // Maximum speed for Ask going up
datetime    max_ask_up_speed_time;      // Maximum Ask up speed timestamp
double      max_bid_down_speed;         // Maximum speed for Bid going down
datetime    max_bid_down_speed_time;    // Maximum Bid down speed timestamp
double      max_bid_up_speed;           // Maximum speed for Bid going up
datetime    max_bid_up_speed_time;      // Maximum Bid up speed timestamp
double      prev_ask;                   // Previous Ask
datetime    prev_ask_time;              // Previous Ask timestamp
double      prev_bid;                   // Previous Bid
datetime    prev_bid_time;              // Previous Bid timestamp

//+---------------------------------------------------------------------+
//| Expert initialization function — called once                        |
//+---------------------------------------------------------------------+
int OnInit() {
    max_ask_down_speed = 0;
    max_ask_down_speed_time = TimeCurrent();
    max_ask_up_speed = 0;
    max_ask_up_speed_time = TimeCurrent();
    max_bid_down_speed = 0;
    max_bid_down_speed_time = TimeCurrent();
    max_bid_up_speed = 0;
    max_bid_up_speed_time = TimeCurrent();
    update_prev_vars();
    return(INIT_SUCCEEDED);
}

//+---------------------------------------------------------------------+
//| Expert tick function — called on every tick                         |
//+---------------------------------------------------------------------+
void OnTick() {
    string comment = "";
    const string nl = "\n                                        ";
    const datetime ask_interval = TimeCurrent() - prev_ask_time;
    if (0 < ask_interval) {
        const double ask_speed = (Ask - prev_ask) / ask_interval;
        if (ask_speed < 0) {
            if (max_ask_down_speed < fabs(ask_speed)) {
                max_ask_down_speed = fabs(ask_speed);
                max_ask_down_speed_time = TimeCurrent();
            }
        }
        if (0 < ask_speed) {
            if (max_ask_up_speed < ask_speed) {
                max_ask_up_speed = ask_speed;
                max_ask_up_speed_time = TimeCurrent();
            }
        }
        comment += nl + "Ask speed: " + DoubleToString(60 * ask_speed, Digits) + " points/minute";
        comment += nl + "Max ask down speed: " + DoubleToString(60 * max_ask_down_speed, Digits) + " points/minute";
        comment += " for " + TimeToString(TimeCurrent() - max_ask_down_speed_time, TIME_SECONDS) + " s";
        comment += nl + "Max ask up speed: " + DoubleToString(60 * max_ask_up_speed, Digits) + " points/minute";
        comment += " for " + TimeToString(TimeCurrent() - max_ask_up_speed_time, TIME_SECONDS) + " s";
    } 
    const datetime bid_interval = TimeCurrent() - prev_bid_time;
    if (0 < bid_interval) {
        const double bid_speed = (Bid - prev_bid) / bid_interval;
        if (bid_speed < 0) {
            if (max_bid_down_speed < fabs(bid_speed)) {
                max_bid_down_speed = fabs(bid_speed);
                max_bid_down_speed_time = TimeCurrent();
            }
        }
        if (0 < bid_speed) {
            if (max_bid_up_speed < bid_speed) {
                max_bid_up_speed = bid_speed;
                max_bid_up_speed_time = TimeCurrent();
            }
        }
        comment += nl + "Bid speed: " + DoubleToString(60 * bid_speed, Digits) + " points/minute";
        comment += nl + "Max bid down speed: " + DoubleToString(60 * max_bid_down_speed, Digits) + " points/minute";
        comment += " for " + TimeToString(TimeCurrent() - max_bid_down_speed_time, TIME_SECONDS) + " s";
        comment += nl + "Max bid up speed: " + DoubleToString(60 * max_bid_up_speed, Digits) + " points/minute";
        comment += " for " + TimeToString(TimeCurrent() - max_bid_up_speed_time, TIME_SECONDS) + " s";
    }
    if (comment != "") Comment(comment);
    update_prev_vars();
}

//+---------------------------------------------------------------------+
//| Update prev_ask, prev_ask_time, prev_bid, prev_bid_time             |
//+---------------------------------------------------------------------+
void update_prev_vars() {
    prev_ask = Ask;
    prev_ask_time = TimeCurrent();
    prev_bid = Bid;
    prev_bid_time = TimeCurrent();
}