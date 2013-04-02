//+------------------------------------------------------------------+
//             Copyright © 2012, 2013 chew-z                         |
// v 1.01B - aktywnie traci w konsolidacji, niewyraŸnym trendzie     |
// 1) jedna pozycja na dobê                                          |
// 2) wariant z SL/TP w pipsach - powinny pasowaæ do ATR             |
// 3) isPullback_L/S1() - w trakcie sesji nie na zamkniêcie          |
// 4)                                                                |
//+------------------------------------------------------------------+
#property copyright "Dynamic Pullback 1.01B © 2012, 2013 chew-z"
#include <TradeContext.mq4>
#include <TradeTools.mqh>
#include <stdlib.mqh>
extern int SL = 30;
extern int TP = 100;
int magic_number_1 = 10001276;
int StopLevel;
int Today;
string AlertText ="";
string orderComment = "Dynamic Pullback 1.01B";
static int BarTime;
//--------------------------
int init()     {
   BarTime = 0;
   Today = DayOfWeek();
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits == 5 || Digits == 3) {    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits.pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits.pips = 0; }
}
int deinit()   {
   GlobalVariableDel(StringConcatenate(Symbol(), magic_number_1));
   return;
}
//-------------------------
int start()    { 
bool isNewBar, isNewDay;  
double StopLoss, TakeProfit;
bool  ShortBuy = false, LongBuy = false;
bool ShortExit = false, LongExit = false;
int cnt, ticket, check;
int contracts = 0;
double Lots;
double L, H, MA;

isNewBar = NewBar();
isNewDay = NewDay();
if ( isNewDay ) {
     lookBackDays = f_lookBackDays(); // 
     GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0);
}
// DISCOVER SIGNALS
   if (isNewBar && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) < 1)   {
     lookBackDays = f_lookBackDays(); // 
     H = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,lookBackDays,1)); 
     L = iLow (NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,lookBackDays,1));
    MA = iMA(NULL, PERIOD_D1, EMA, 0, MODE_EMA, PRICE_CLOSE, 1);
      if (isRecentHigh_L() && isPullback_L1()   )  {
            LongBuy = true;  
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 
      }
      if (isRecentLow_S() && isPullback_S1()   )  {
            ShortBuy = true; 
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 
      }
   }

// EXIT MARKET 
if( isNewBar ) {  
   for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position 
                                                      && OrderSymbol() == Symbol()                 // check for symbol
                                                      && (OrderMagicNumber()  == magic_number_1) ) // my magic number    
      {
         if(OrderType() == OP_BUY && ( isExit_L() && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 2 )  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(), Bid, 5, Violet); // close position
                  TradeIsNotBusy();
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5));
         }
         if(OrderType() == OP_SELL && ( isExit_S() && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 2 )  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(), Ask, 5, Violet); // close position
                  TradeIsNotBusy();
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Bid, 5));
         }
         
      }
   }
}
// MODIFY ORDERS 
if( isNewDay ) {
   for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position 
                                                      && OrderSymbol() == Symbol()                 // check for symbol
                                                      && OrderMagicNumber()  == magic_number_1 ) {
         if(OrderType()== OP_BUY && OrderMagicNumber()  == magic_number_1  && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 1 ) {
            StopLoss = NormalizeDouble(Ask - SL * pips2dbl, Digits);
            TakeProfit = NormalizeDouble(Ask + TP * pips2dbl, Digits);
            RefreshRates();
            if ( TakeProfit > OrderTakeProfit() + 5*pips2dbl || StopLoss > OrderStopLoss() + 5*pips2dbl ) { // TakeProfit > OrderTakeProfit() + 5*Point
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
                  TradeIsNotBusy();
                  AlertText = orderComment + " " + Symbol() + " BUY order modification attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5);
                  f_SendAlerts(AlertText);                  
            }
         }
         if(OrderType()==OP_SELL && OrderMagicNumber()  == magic_number_1  && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 1 ) {
            StopLoss = NormalizeDouble(Bid + SL * pips2dbl, Digits);
            TakeProfit = NormalizeDouble(Bid - TP * pips2dbl, Digits);
            RefreshRates();
            if ( TakeProfit < OrderTakeProfit() - 5*pips2dbl|| StopLoss < OrderStopLoss() - 5*pips2dbl )  { // TakeProfit < OrderTakeProfit() - 5*Point
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
                  TradeIsNotBusy();
                  AlertText = orderComment + " " + Symbol() + " SELL order modification attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5);
                  f_SendAlerts(AlertText);                  
            }
         } 
       }
    }
}
// MONEY MANAGEMENT
         Lots =  maxLots;
         contracts = f_Money_Management() - f_OrdersTotal(magic_number_1);
// ENTER MARKET CONDITIONS
if( f_OrdersTotal(magic_number_1) < contracts )   {
// check for long position (BUY) possibility
      if(LongBuy == true )      { // pozycja z sygnalu
         StopLoss = NormalizeDouble(Ask - SL * pips2dbl, Digits);
         TakeProfit = NormalizeDouble(Ask + TP * pips2dbl, Digits);
   //--------Transaction
         check = f_SendOrders(OP_BUY, contracts - f_OrdersTotal(magic_number_1), Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
   //--------
         if(check==0)         {
              AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5) + ", L = " + DoubleToStr(H, 5);
         }  else AlertText = "Error opening BUY order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", L = " + DoubleToStr(H, 5);
         f_SendAlerts(AlertText); 
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
         StopLoss = NormalizeDouble(Bid + SL * pips2dbl, Digits);
         TakeProfit = NormalizeDouble(Bid - TP * pips2dbl, Digits);
   //--------Transaction
         check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
   //--------
         if(check==0)         {
               AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5);
         }  else AlertText = "Error opening SELL order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5); 
         f_SendAlerts(AlertText);
      }
} 
   return(0); // exit
}
///////////////////////////  //////////////////////////////////////
bool NewBar()  {
   if(BarTime != Time[0]) {
      BarTime = Time[0];
      return(true);
   } else {
      return(false);
   }
}
bool NewDay() {
   if(Today!=DayOfWeek()) {
      Today=DayOfWeek();
      return(true);
   }
   return(false);
}