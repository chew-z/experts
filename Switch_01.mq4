//+------------------------------------------------------------------+
//             Copyright © 2012, 2013 chew-z                         |
// v .01 - switch isTrending()                                       |
// 1) Tylko Daily D1                                                 |
// 2) Jedno wejœcie w cyklu, gdy nowy sygna³ isTrending() = 1        |
// 3) SL jest OK ale czasem zamyka i omija ca³y cykl trendu          |
// 4) Nie ma TP i exitu                                              |
//+------------------------------------------------------------------+
#property copyright "Switch © 2012, 2013 chew-z"
#include <TradeContext.mq4>
#include <TradeTools.mqh>
#include <stdlib.mqh>
int magic_number_1 = 10009935;
int StopLevel;
string AlertText ="";
string orderComment = "Switch 0.01";
static int BarTime;
int Today;

//--------------------------
int init()     {
   BarTime = 0;				// 
   Comment("Katastrofa, gdy nie ma trendu! - przyjemny system, gdy trend jest.");
   Today = DayOfWeek();
   GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1);
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits == 5 || Digits == 3){    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits.pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits.pips = 0; } 
}

int deinit()                                    // Special funct. deinit()
   {
   GlobalVariableDel(StringConcatenate(Symbol(), magic_number_1));
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
double L, H;

if ( NewDay()) {
   GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0);
}
isNewBar = NewBar();
// DISCOVER SIGNALS
   if (isNewBar && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) < 1 )   {
      lookBackDays = f_lookBackDays(); // 
      H = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,lookBackDays,1)); // kurwa magic ale chyba dzia³a
      L = iLow (NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,lookBackDays,1));
      if ( isTrending_L1(0) && !isTrending_L1(1))  {
            LongBuy = true; 
            ShortExit = true; 
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1);
      }
      if ( isTrending_S1(0) && !isTrending_S1(1))  {
            ShortBuy = true; 
            LongExit = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1);
      }
      if ( !isTrending_L()  )  { //lepiej daily close
            LongExit = true;
      }
      if ( !isTrending_S()  )  { //jw.
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
if( isNewBar ) {
for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position 
                                                      && OrderSymbol() == Symbol()                 // check for symbol
                                                      && OrderMagicNumber()  == magic_number_1 ) {
         if(OrderType()==OP_BUY && OrderMagicNumber()  == magic_number_1  && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 1 ) {
            StopLoss = NormalizeDouble(L, Digits);
            TakeProfit = OrderTakeProfit();
            RefreshRates();
            if (Ask - StopLoss <  StopLevel * Point )
                  StopLoss = Ask - StopLevel * Point;
            if (StopLoss > OrderStopLoss()+ 5*Point || TakeProfit > OrderTakeProfit() + 5*Point) {
               if(TradeIsBusy() < 0) // Trade Busy semaphore 
                  return(-1);   
               OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
               TradeIsNotBusy();
               AlertText = orderComment + " " + Symbol() + " BUY order modification attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5);
               f_SendAlerts(AlertText);
               }
         }
         if(OrderType()==OP_SELL && OrderMagicNumber()  == magic_number_1  && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 1 ) {
            StopLoss = NormalizeDouble(H, Digits);
            TakeProfit = 0.00;
            RefreshRates();
            if (StopLoss - Bid <  StopLevel * Point )
                  StopLoss = Bid + StopLevel * Point;
            if (StopLoss < OrderStopLoss() - 5*Point ||  TakeProfit < OrderTakeProfit() - 5*Point)  {
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
if( contracts > 0 )   {
// check for long position (BUY) possibility
      if(LongBuy == true )      { // pozycja z sygnalu
          StopLoss = NormalizeDouble(L, Digits);
          TakeProfit = OrderTakeProfit();
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
               StopLoss = NormalizeDouble(H, Digits);
               TakeProfit = 0.0;
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