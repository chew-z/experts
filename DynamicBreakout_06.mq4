//+------------------------------------------------------------------+
//             Copyright © RRJ                                       |
// v 0.6 - ... z MM, wysy³a alerty                                  |
// 1) strategia Dynamic Breakout                                     |
// 2) nowe podejœcie do zakresu HH/LL i zmiennoœci                   |
// 3) bardziej agresywna, pod k¹tem BossaFX 2012                     |
// 4)                                                                |
//+------------------------------------------------------------------+
#property copyright "Dynamic Breakout 0.6 © RRJ"
#include <TradeContext.mq4>
#include <TradeTools.mqh>
#include <stdlib.mqh>
int magic_number_1 = 10001235;
int StopLevel;
string AlertText ="";
string orderComment = "Dynamic Breakout 06";
static int BarTime;
//--------------------------
int init()     {
   BarTime = 0;				// 
   Comment("Look for breakouts in direction of a long term trend");
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
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
double L, H, MA, exitLevel;

isNewBar = NewBar();
// DISCOVER SIGNALS
   if (isNewBar )   {
     lookBackDays = f_lookBackDays(); // 
     H = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,lookBackDays,1)); // value(shift(symbol, okres, etc.. ) - kurwa magic ale chyba dzia³a
     L = iLow (NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,lookBackDays,1));
  
      if ( Close[1] > H && isTrending_L() )  
            LongBuy = true;  
      if ( Close[1] < L && isTrending_S() )  
            ShortBuy = true; 
      if ( isExit_L1()  )  { //|| isExit_L()
            LongExit = true;
      }
      if ( isExit_S1() )  { //|| isExit_S()
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
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()));
         }
         if(OrderType() == OP_SELL && ( ShortExit  )  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(),Ask,5,Violet); // close position
                  TradeIsNotBusy();
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()));
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
            StopLoss = NormalizeDouble((OrderOpenPrice() ), Digits);
            TakeProfit = NormalizeDouble(H, Digits);
            RefreshRates();
            if (Ask - StopLoss <  StopLevel * Point )
                  StopLoss = Ask - StopLevel * Point;
            if (StopLoss > OrderStopLoss()+ 5*Point || TakeProfit > OrderTakeProfit() + 5*Point) {
               if(TradeIsBusy() < 0) // Trade Busy semaphore 
                  return(-1);   
               OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
               TradeIsNotBusy();
               AlertText = orderComment + " " + Symbol() + " BUY order modification attempted.\rResult = " + ErrorDescription(GetLastError());
               f_SendAlerts(AlertText);
               }
         }
         if(OrderType()==OP_SELL && OrderMagicNumber()  == magic_number_1  && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 1 ) {
            StopLoss = NormalizeDouble((OrderOpenPrice() ), Digits);
            TakeProfit = NormalizeDouble(L, Digits);
            RefreshRates();
            if (StopLoss - Bid <  StopLevel * Point )
                  StopLoss = Bid + StopLevel * Point;
            if (StopLoss < OrderStopLoss() - 5*Point ||  TakeProfit < OrderTakeProfit() - 5*Point)  {
               if(TradeIsBusy() < 0) // Trade Busy semaphore 
                  return(-1);   
               OrderModify(OrderTicket(),OrderOpenPrice(), StopLoss, TakeProfit, 0, Gold);
               TradeIsNotBusy();
               AlertText = orderComment + " " + Symbol() + " SELL order modification attempted.\rResult = " + ErrorDescription(GetLastError());
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
          StopLoss = NormalizeDouble(f_initialStop_L(), Digits);
          TakeProfit = NormalizeDouble(f_tp_L(), Digits);
//--------Transaction
       check = f_SendOrders(OP_BUY, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened.";
       else AlertText = "Error opening BUY order : " + ErrorDescription(check); 
       f_SendAlerts(AlertText);
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
               StopLoss = NormalizeDouble(f_initialStop_S(), Digits);
               TakeProfit = NormalizeDouble(f_tp_S(), Digits);
//--------Transaction
       check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
//--------
       if(check==0)
            AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
            + orderComment + " " + contracts + " order(s) opened.";
       else AlertText = "Error opening SELL order : " + ErrorDescription(check); 
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