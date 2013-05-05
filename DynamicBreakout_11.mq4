//+------------------------------------------------------------------+
//             Copyright © 2012, 2013 chew-z                         |
// v 1.1 - ... z MM, wysyła alerty                                   |
// 1) fork _10, z elementami kodu pin-pin                            |
// 2) nie działa - (GlobalVariable?)                                 |
// 3) (a bez początkowego SL) genialnie                              |
// 4)                                                                |
//+------------------------------------------------------------------+
#property copyright "Dynamic Breakout 1.1 © 2012, 2013 chew-z"
#include <TradeContext.mq4>
#include <TradeTools.mqh>
#include <stdlib.mqh>
int magic_number_1 = 108701235;
int StopLevel;
string AlertText ="";
string orderComment = "Dynamic Breakout 1.1";
static int BarTime;
//--------------------------
int init()     {
   BarTime = 0;       // 
   Comment("Dynamic Breakout ");
   Today = DayOfWeek();
   GlobalVariableSet(DoubleToStr(magic_number_1, 0), 0);
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits == 5 || Digits == 3){    // Adjust for five (5) digit brokers.
      pips2dbl    = Point*10; pips2points = 10;   Digits.pips = 1;
   } else {    pips2dbl    = Point;    pips2points =  1;   Digits.pips = 0; }
}

int deinit()  {
   GlobalVariableDel(DoubleToStr(magic_number_1, 0));
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
double MA, exitLevel;

isNewDay = NewDay();
isNewBar = NewBar();
if ( isNewDay ) {
     lookBackDays = f_lookBackDays(); // 
     H = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,lookBackDays,1)); // kurwa magic ale chyba dzia³a
     L = iLow (NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,lookBackDays,1)); 
     GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 0); // zerowanie o północy
}
// DISCOVER SIGNALS
if (isNewBar && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) < 1 )   {
     //lookBackDays = f_lookBackDays(); //  
      if ( Close[1] > H && isTrending_L() ) {
            LongBuy = true;
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 2); // Zajmuje dwie pozycje(loty)
      }  
      if ( Close[1] < L && isTrending_S() ) {
            ShortBuy = true; 
            GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 2); // Zajmuje dwie pozycje(loty)
      }
} 

// EXIT MARKET pin-pin like
if( isNewBar ) {  
   for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position 
                                                      && OrderSymbol() == Symbol()                 // check for symbol
                                                      && (OrderMagicNumber()  == magic_number_1) ) // my magic number    
      {
         // Jeśli do końca dnia pozycja zarobiona to przymknij 1 lot
         if(OrderType() == OP_BUY && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) > 1  && (Ask - OrderOpenPrice()) > TP * pips2dbl  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(), Bid, 5, Violet); // close 1/2 position
                  TradeIsNotBusy();
                  GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); // 1/2 position closed
                  LongBuy = false;
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Ask, 5));
         }
         if(OrderType() == OP_SELL && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) > 1  && (OrderOpenPrice() - Bid) > TP * pips2dbl )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(), Ask, 5, Violet); // close 1/2 position
                  TradeIsNotBusy();
                  GlobalVariableSet(StringConcatenate(Symbol(), magic_number_1), 1); // 1/2 position closed
                  ShortBuy = false;
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()) + ". \rPrice = " + DoubleToStr(Bid, 5));
         }
         
      }
   }
}
// MODIFY ORDERS 
if( isNewBar  ) { 
   for(cnt=OrdersTotal()-1;cnt>=0;cnt--) {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL                    // check for opened position 
                                                      && OrderSymbol() == Symbol()                 // check for symbol
                                                      && OrderMagicNumber()  == magic_number_1 ) {
         // Jeśli przymknąłeś połowę albo się da to przesuń SL do breakeven
         if(OrderType()== OP_BUY && OrderMagicNumber()  == magic_number_1 && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) < 2 ) {
            StopLoss = OrderOpenPrice();
            TakeProfit = NormalizeDouble(H , Digits);
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
         if(OrderType()==OP_SELL && OrderMagicNumber()  == magic_number_1 && GlobalVariableGet(StringConcatenate(Symbol(), magic_number_1)) < 2 ) {
            StopLoss = OrderOpenPrice();
            TakeProfit = NormalizeDouble(L , Digits);
            RefreshRates();
            if ( TakeProfit < OrderTakeProfit() - 5*pips2dbl || StopLoss < OrderStopLoss() - 5*pips2dbl )  { // TakeProfit < OrderTakeProfit() - 5*Point
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
          StopLoss = NormalizeDouble(H - SL * pips2dbl, Digits);
          TakeProfit = NormalizeDouble(f_tp_L(), Digits);
//--------Transaction
       check = f_SendOrders(OP_BUY, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5);
       else { AlertText = "Error opening BUY order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Ask, 5) + ", H = " + DoubleToStr(H, 5); }
       f_SendAlerts(AlertText);
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
               StopLoss = NormalizeDouble(L + SL * pips2dbl, Digits);
               TakeProfit = NormalizeDouble(f_tp_S(), Digits);
//--------Transaction
       check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened. \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5);
       else { AlertText = "Error opening SELL order : " + ErrorDescription(check) + ". \rPrice = " + DoubleToStr(Bid, 5) + ", L = " + DoubleToStr(L, 5); }
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
   } else {
      return(false);
   }
}