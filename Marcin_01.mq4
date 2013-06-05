//+------------------------------------------------------------------+
//             Copyright © 2012, 2013 chew-z         |
// v .01 - Marcin stub                                        |
// 1)                                                                 |
// 2)                                                                 |
// 3)                                                                 |
// 4)                                                                 |
//+------------------------------------------------------------------+
#property copyright "Marcin_01 © 2012, 2013 chew-z"
#include <TradeContext.mq4>
#include <TradeTools_Marcin.mqh>
#include <stdlib.mqh>

int magic_number_1 = 12345678;
int StopLevel;
string AlertText ="";
string orderComment = "Marcin _01";
static int BarTime;
int contracts = 0;
double Lots;
double StopLoss, TakeProfit;

//--------------------------
int init()  {
   BarTime = 0;				// 
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits == 5 || Digits == 3) {    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits.pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits.pips = 0; } 
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
    GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0); 
}

// DISCOVER SIGNALS
   if ( GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) == 0 )   { // Only first signal on a bar
     
      if ( isPullback_L() )  {
            LongBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 
      }
      if ( isPullback_S() )  {
            ShortBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 
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
          StopLoss = NormalizeDouble(Bid - SL * pips2dbl, Digits);
          TakeProfit = NormalizeDouble(Ask + TP * pips2dbl, Digits);
//--------Transaction
       check = f_SendOrders(OP_BUY, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5);
       else { AlertText = "Error opening BUY order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5); }
       f_SendAlerts(AlertText);
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
            StopLoss = NormalizeDouble(Ask + SL*pips2dbl, Digits);
            TakeProfit = NormalizeDouble(Bid - TP*pips2dbl, Digits);
//--------Transaction
       check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
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



