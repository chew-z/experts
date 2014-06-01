//+------------------------------------------------------------------+
//             Copyright © 2012, 2013m 2014 chew-z                   |
// v 1.02B - fade trendlines                                         |
// 1) exit @ N or the other trendline?                               |
// 2) N seems safer, lower drawdown but misses                       |
// 3) This version is linked to trendline_2b indicator               |
//+------------------------------------------------------------------+
#property copyright "Tin-tin Pullback © 2012, 2013, 2014 chew-z"
#include <TradeContext.mq4>
#include <TradeTools.mqh>
#include <stdlib.mqh>
extern int F = 5;
int magic_number_1 = 10701267;
int StopLevel;
string AlertText ="";
string orderComment = "Tin-tin Fade 1.02B";
static int BarTime;
//--------------------------
int init()     {
   AlertEmailSubject = Symbol() + " Tin-tin";
   GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0);
   BarTime = 0;
   Today = DayOfWeek();
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits == 5 || Digits == 3){    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits_pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits_pips = 0; }
}
int deinit()   {
   return;
}
//-------------------------
int start()    { 
bool isNewBar, isNewDay;  
double StopLoss, TakeProfit;
bool  ShortBuy = false, LongBuy = false;
bool ShortExit = false, LongExit = false;
int cnt, ticket, check, half;
int contracts = 0;
double Lots;
double N;

isNewBar = NewBar();
isNewDay = NewDay();
if ( isNewDay ) {
     GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0); // zerowanie o północy
}
// DISCOVER SIGNALS
   if (isNewBar )   {
     half = MathRound((rangeX - blindRange) /2);
     int max1 = iHighest(NULL, 0, MODE_HIGH, rangeX, half+1); //roughly 24 H1 bars per day
     int max2 = iHighest(NULL, 0, MODE_HIGH, half, blindRange);
     if (max1-max2 < blindRange) max2 = iHighest(NULL, 0, MODE_HIGH, half-blindRange, blindRange);
     int min1 = iLowest(NULL, 0, MODE_LOW, rangeX, half+1);
     int min2 = iLowest(NULL, 0, MODE_LOW, half, blindRange);
     if (min1-min2 < blindRange) min2 = iLowest(NULL, 0, MODE_LOW, half-blindRange, blindRange);
     double deltaYh = (High[max1]-High[max2]) / (max1 - max2);    // delta Y High
     double deltaYl = (Low[min2]-Low[min1]) / (min1 - min2);          // delta Y Low 
      H  = High[max1] - (max1) * deltaYh;
      L  = Low[min1] + (min1) * deltaYl;
      N = NormalizeDouble((H + L) / 2, 5);
      if ( H > L && (High[1] - H) > F * pips2dbl && (Close[2] - H - deltaYh) <  F * pips2dbl)  {
            ShortBuy = true;
            LongExit = true;  
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 2); // Zajmuje dwie pozycje(loty)
      }
      if ( H > L && (L - Low[1]) > F * pips2dbl && (Close[2] - L + deltaYl) > F * pips2dbl )  {
            LongBuy = true;
            ShortExit = true; 
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 2); 
      }
}
// EXIT MARKET 
if( isNewBar ) {  
   for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position 
                                                      && OrderSymbol() == Symbol()                 // check for symbol
                                                      && (OrderMagicNumber()  == magic_number_1) ) // my magic number    
      {
         // JeÅ›li do koÅ„ca dnia pozycja zarobiona to przymknij 1 lot
         if(OrderType() == OP_BUY && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) > 1  && Close[1] > N  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(), Bid, 5, Violet); // close 1/2 position
                  TradeIsNotBusy();
                  GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); // 1/2 position closed
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5));
         }
         if(OrderType() == OP_SELL && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) > 1  && Close[1] < N )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(), Ask, 5, Violet); // close 1/2 position
                  TradeIsNotBusy();
                  GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); // 1/2 position closed
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
         // JeÅ›li przymknÄ…Å‚eÅ› poÅ‚owÄ™ albo siÄ™ da to przesuÅ„ SL do breakeven
         if(OrderType()== OP_BUY && OrderMagicNumber()  == magic_number_1  ) {
            StopLoss = NormalizeDouble(L , Digits);
            TakeProfit = NormalizeDouble(H , Digits);
            RefreshRates();
            if ( TakeProfit != OrderTakeProfit() || StopLoss > OrderStopLoss() + 5*pips2dbl ) { // TakeProfit > OrderTakeProfit() + 5*Point
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
                  TradeIsNotBusy();
                  AlertText = orderComment + " " + Symbol() + " BUY order modification attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5);
                  f_SendAlerts(AlertText);                  
            }
         }
         if(OrderType()==OP_SELL && OrderMagicNumber()  == magic_number_1   ) {
            StopLoss = NormalizeDouble(H , Digits);
            TakeProfit = NormalizeDouble(L , Digits);
            RefreshRates();
            if ( TakeProfit != OrderTakeProfit() || StopLoss < OrderStopLoss() + 5*pips2dbl )  { // TakeProfit < OrderTakeProfit() - 5*Point
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
         StopLoss = NormalizeDouble(f_initialStop_L(), Digits);
         TakeProfit = NormalizeDouble(H , Digits);
   //--------Transaction
         check = f_SendOrders(OP_BUY, contracts - f_OrdersTotal(magic_number_1), Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
   //--------
         if(check==0)         {
              AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5) + ", L = " + DoubleToStr(L, 5);
         }  else { AlertText = "Error opening BUY order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5); }
         f_SendAlerts(AlertText); 
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
         StopLoss = NormalizeDouble(f_initialStop_S(), Digits);
         TakeProfit = NormalizeDouble(L , Digits);
   //--------Transaction
         check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
   //--------
         if(check==0)         {
               AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Bid, 5) + ", H = " + DoubleToStr(H, 5);
         }  else { AlertText = "Error opening SELL order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5); }
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