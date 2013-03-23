//+------------------------------------------------------------------+
//             Copyright © 2012, 2013 chew-z                         |
// v .01 - Trend - anty-Trend tub                                    |
// 1)                                                                |
// 2)                                                                |
// 3)                                                                |
// 4)                                                                |
//+------------------------------------------------------------------+
#property copyright "Dynamic pre-Breakout 1.01 © 2012, 2013 chew-z"
#include <TradeContext.mq4>
#include <TradeTools.mqh>
#include <stdlib.mqh>
int magic_number_1 = 11102235;
int StopLevel;
string AlertText ="";
string orderComment = "Trend Anty-Trend .01";
static int BarTime;
int Today;
double L, H;

//--------------------------
int init()     {
   BarTime = 0;				// 
   Comment("Comment ");
   Today = DayOfWeek();
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits == 5 || Digits == 3){    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits.pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits.pips = 0; } 
}

int deinit()                                    // Special funct. deinit()
   {
   return;
   }
//-------------------------
int start()    { 
bool isNewBar;  
double StopLoss, TakeProfit;
bool  ShortBuy = false, LongBuy = false;
bool ShortExit = false, LongExit = false;
int cnt, ticket, check;
int contracts = 0;
double Lots;

isNewBar = NewBar();
if ( NewDay()) {
     lookBackDays = f_lookBackDays(); // 
     H = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,lookBackDays,1)); 
     L = iLow (NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,lookBackDays,1));
     GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0);
}

// DISCOVER SIGNALS
   if ( GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) < 1 )   { // Only first breakout of the day
     
      if ( isBreakout_H() )  {
            ShortBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 

      }
      if ( isBreakout_L() )  {
            LongBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); 

      }
      if ( false )  { //spierdalamy przy cofnieciu
            LongExit = true;
      }
      if ( false )  { //jw.
            ShortExit = true;
      }

   }

// EXIT MARKET 
if( isNewBar ) {  
   for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position 
                                                      && OrderSymbol() == Symbol()                 // check for symbol
                                                      && (OrderMagicNumber()  == magic_number_1) ) // my magic number    
      {
         if(OrderType() == OP_BUY && ( LongExit )  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(),Bid,5,Violet); // close position
                  TradeIsNotBusy();
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5) );
         }
         if(OrderType() == OP_SELL && ( ShortExit  )  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(),Ask,5,Violet); // close position
                  TradeIsNotBusy();
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5) );
         }
      }
   }
}
// MODIFY ORDERS 

// MONEY MANAGEMENT
         Lots =  maxLots;
         contracts = f_Money_Management() - f_OrdersTotal(magic_number_1);
// ENTER MARKET CONDITIONS
if( contracts > 0 )   {
// check for long position (BUY) possibility
      if(LongBuy == true )      { // pozycja z sygnalu
          StopLoss = NormalizeDouble(Bid - 20*pips2dbl, Digits);
          TakeProfit = NormalizeDouble(Open[1], Digits);
//--------Transaction
       check = f_SendOrders(OP_BUY, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5);
       else AlertText = "Error opening BUY order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5); 
       f_SendAlerts(AlertText);
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
            StopLoss = NormalizeDouble(Ask + 20*pips2dbl, Digits);
            TakeProfit = NormalizeDouble(Open[1], Digits);
//--------Transaction
       check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5);
       else AlertText = "Error opening SELL order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5);
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

bool NewDay() {
   if(Today!=DayOfWeek()) {
      Today=DayOfWeek();
      return(true);
   }
   return(false);
} 

bool isBreakout_H() {
   if ( Ask > H && ((H - Open[0]  > 20 * pips2dbl) ) )
      return(true);
   return(false);

}

bool isBreakout_L() {
   if ( Bid < L && ((Open[0] - L  > 20 * pips2dbl)  ) )
      return(true);
   return(false);

}

double sl_H() {
   if (Open[0] < H)
      return(Open[0]);
      
   return(H);   

}

double sl_L() {
   if (Open[0] > L)
      return(Open[0]);
      
   return(L);   

}