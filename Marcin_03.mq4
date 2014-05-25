//+------------------------------------------------------------------+
//             Copyright © 2012, 2013 chew-z                 |
// v .03 - Marcin stub                                                   |
// 1)  Sygnał aktywny przez określony czas                 |
// 2)                                                                              |
// 3)                                                                              |
// 4)                                                                              |
//+------------------------------------------------------------------+
#property copyright "Marcin_03 © 2012, 2013 chew-z"
#include <TradeContext.mq4>
#include <TradeTools_Marcin.mqh>
#include <stdlib.mqh>

int magic_number_1 = 23456789;
int StopLevel;
string AlertText ="";
string orderComment = "Marcin _03";
static int BarTime;
static int t; //
int contracts = 0;
double Lots;
double StopLoss, TakeProfit;

//--------------------------
int init()  {
   GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0); 
   BarTime = 0;				// 
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits == 5 || Digits == 3) {    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits_pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits_pips = 0; } 
}

int deinit()  {
   GlobalVariableDel(StringConcatenate(Symbol(), magic_number_1));
   return;
}
//-------------------------
int start()    { 
bool isNewBar; 
bool  ShortBuy = false, LongBuy = false;
int cnt, ticket, check;

isNewBar = NewBar();
if (isNewBar) { 
    if(f_OrdersCount(magic_number_1) == 0) // Gdy nie ma pozycji (bo w domyśle, zostały zamknięte SL lub TP) wyzeruj flagę i czekaj na nowy sygnał
      GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0); 
// DISCOVER SIGNALS
   if ( GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) == 0 )   { // Only first signal on a bar
     
      if ( isTrend_H(T, K)  )  {
            if ( With_trend ) LongBuy = true; else ShortBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 
      }
      if ( isTrend_L(T, K) )  {
            if (With_trend) ShortBuy = true; else LongBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 
      }

   }

  }
// EXIT MARKET 

// MONEY MANAGEMENT
         Lots =  maxLots;
         contracts = maxContracts;
// ENTER MARKET CONDITIONS
if( contracts > 0 )   {
// check for long position (BUY) possibility
      if(LongBuy == true )      { // pozycja z sygnalu
          StopLoss = NormalizeDouble(Close[1] + (Pending - SL) * pips2dbl, Digits);
          TakeProfit = NormalizeDouble(Close[1] + TP * pips2dbl, Digits);
//--------Transaction
       check = f_SendOrders_OnStop(OP_BUYSTOP, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5);
       else { AlertText = "Error opening BUY order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5); }
       f_SendAlerts(AlertText);
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
            StopLoss = NormalizeDouble(Close[1] + (SL - Pending) *pips2dbl, Digits);
            TakeProfit = NormalizeDouble(Close[1] - TP*pips2dbl, Digits);          
//--------Transaction
       check = f_SendOrders_OnStop(OP_SELLSTOP, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Bid, 5);
       else { AlertText = "Error opening SELL order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Bid, 5); }
       f_SendAlerts(AlertText); 
      }
 }
 
   return(0); // exit
}

///////////////////////////////////////////////////////////////////
bool NewBar()  {
   if(BarTime != Time[0]) {
      BarTime = Time[0];
      return(true);
   } 
   return(false);
}



