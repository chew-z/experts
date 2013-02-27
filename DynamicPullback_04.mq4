//+------------------------------------------------------------------+
//             Copyright © RRJ                                       |
// v 0.4 - ...                                                       |
// 1) strategia Dynamic Pullback                                     |
// 2) nowe podejœcie..                                               |
// 3) Brakuje dobrego pomys³u na trailing SL                         |
// 4) Wiêcej oddechu, kompromis miêdzy H/L a exitem ze Stochastica.  |
//+------------------------------------------------------------------+
#property copyright "Dynamic Pullback 0.4 © RRJ"
#include <TradeContext.mq4>
#include <TradeTools.mqh>
#include <stdlib.mqh>
int magic_number_1 = 10001236;
int StopLevel;
string AlertText ="";
string orderComment = "Dynamic Pullback 04";
static int BarTime;
//--------------------------
int init()     {
   BarTime = 0;				// 
   Comment("Look for pullbacks, and take position in direction of main trend");
   StopLevel = (MarketInfo(Symbol(), MODE_STOPLEVEL) + MarketInfo(Symbol(), MODE_SPREAD));
   if (Digits % 2 == 1)
      pips2points = 10;
   else 
      pips2points =  1;
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
double L, H, MA;

isNewBar = NewBar();
// DISCOVER SIGNALS
   if (isNewBar)   {
     lookBackDays = f_lookBackDays(); // 
     H = iHigh(NULL, PERIOD_D1, iHighest(NULL,PERIOD_D1,MODE_HIGH,lookBackDays,1)); 
     L = iLow (NULL, PERIOD_D1, iLowest (NULL,PERIOD_D1,MODE_LOW,lookBackDays,1));
    MA = iMA(NULL, PERIOD_D1, EMA, 0, MODE_EMA, PRICE_CLOSE, 1);
      if (isRecentHigh_L() && isPullback_L()   )  
            LongBuy = true;  
      if (isRecentLow_S() && isPullback_S()   )  
            ShortBuy = true; 
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
                  f_SendAlerts(orderComment + " trade exit attempted.\rResult = " + ErrorDescription(GetLastError()));
         }
         if(OrderType() == OP_SELL && ( isExit_S() && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 2 )  )   {
                  RefreshRates();
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderClose(OrderTicket(),OrderLots(), Ask, 5, Violet); // close position
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
            //StopLoss = NormalizeDouble(OrderStopLoss() , Digits);
            TakeProfit = NormalizeDouble(1.005* H, Digits);
            RefreshRates();
            //if (Ask - StopLoss <  StopLevel * Point )
            //      StopLoss = Ask - StopLevel * Point;
            if ( TakeProfit > OrderTakeProfit() + 5*Point ) { // StopLoss > OrderStopLoss() ||
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderModify(OrderTicket(),OrderOpenPrice(), OrderStopLoss(), TakeProfit, 0, Gold);
                  TradeIsNotBusy();
                  AlertText = orderComment + " " + Symbol() + " BUY order modification attempted.\rResult = " + ErrorDescription(GetLastError());
                  f_SendAlerts(AlertText);                  
            }
         }
         if(OrderType()==OP_SELL && OrderMagicNumber()  == magic_number_1  && iBarShift(NULL, PERIOD_D1, OrderOpenTime(), false) > 1 ) {
            //StopLoss = NormalizeDouble(OrderStopLoss() , Digits);
            TakeProfit = NormalizeDouble(0.995 * L, Digits);
            RefreshRates();
            //if (StopLoss - Bid <  StopLevel * Point )
            //      StopLoss = Bid + StopLevel * Point;
            if ( TakeProfit < OrderTakeProfit() - 5*Point )  { // StopLoss < OrderStopLoss() ||
                  if(TradeIsBusy() < 0) // Trade Busy semaphore 
                     return(-1);   
                  OrderModify(OrderTicket(),OrderOpenPrice(), OrderStopLoss(), TakeProfit, 0, Gold);
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
if( f_OrdersTotal(magic_number_1) < contracts )   {
// check for long position (BUY) possibility
      if(LongBuy == true )      { // pozycja z sygnalu
         StopLoss = NormalizeDouble(f_initialStop_L(), Digits);
         TakeProfit = NormalizeDouble(H, Digits);
   //--------Transaction
         check = f_SendOrders(OP_BUY, contracts - f_OrdersTotal(magic_number_1), Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
   //--------
         if(check==0)         {
              AlertText = "BUY order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened \r";
         }  else AlertText = "Error opening BUY order : " + ErrorDescription(check); 
         f_SendAlerts(AlertText); 
      }
// check for short position (SELL) possibility
      if(ShortBuy == true )      { // pozycja z sygnalu
         StopLoss = NormalizeDouble(f_initialStop_S(), Digits);
         TakeProfit = NormalizeDouble(L, Digits);
   //--------Transaction
         check = f_SendOrders(OP_SELL, contracts, Lots, StopLoss, TakeProfit, magic_number_1, orderComment);                       
   //--------
         if(check==0)         {
               AlertText = "SELL order opened : " + Symbol() + ", " + TFToStr(Period())+ " -\r"
               + orderComment + " " + contracts + " order(s) opened \r";
         }  else AlertText = "Error opening SELL order : " + ErrorDescription(check); 
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