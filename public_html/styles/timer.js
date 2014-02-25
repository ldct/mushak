var hours = 0; 		// hours remaining
var mins =  0;		// minutes remaining
var secs =  0;		// seconds remaining

var wakeup = null;	// name of function to call on wakeup

var timerID = 0;
var tStart = null;
var tExpires = null;
var tTot = 0;

var barWidth = 500;

function leadZero(n){
   return n < 10 ? "0" + n : n;
}

function UpdateTimer() {
   if(timerID) {
      clearTimeout(timerID);
   }
   var tDate = new Date();
   var tDiff = tExpires.getTime() - tDate.getTime();
   tDate.setTime(tDiff + 1000);
   if (tDate.getTime() < 1000) {
      document.quiz.time.value = "00:00:00";
      document.greenImg.width = 0;
      document.redImg.width = barWidth;

      wakeup();

   } else {
      document.quiz.time.value = leadZero(tDate.getUTCHours()) + ":"
                                      + leadZero(tDate.getUTCMinutes()) + ":"
                                      + leadZero(tDate.getUTCSeconds());

      document.greenImg.width = barWidth * tDiff / tTot;
      document.redImg.width = barWidth - document.greenImg.width;
      timerID = setTimeout("UpdateTimer()", 1000);
   }
}

function SetWakeup(w) {
  wakeup=w;
}

function SetTimer(h,m,s) {
  hours=h;
  mins=m;
  secs=s;
}

function Start() {
   tStart = new Date();
   tExpires = new Date();
   tTot = hours*60*60*1000 + mins*60*1000 + secs*1000;
   tExpires.setTime(tStart.getTime() + tTot);
   timerID = setTimeout("UpdateTimer()", 1);
}

function Stop() {
   if(timerID) {
      clearTimeout(timerID);
      timerID  = 0;
   }
   tStart = null;
   tExpires = null;
}
