
menu =  
   [
	 {
	 	label: "Menu 1",
	  	items: 
	  		[
				{
					label: "First group",
					items:
					  [
			     		{ label: "ola" },
			     		{ label: "ole" },
			     		{ label: "oli" } 
        	    	  ]
     			},
        		{
					label: "Second Group",
					items: 
					 [
			     		{ label: "hello" },
			     		{ label: "olla" },
		     			{ label: "oi" }
					 ]
				}
     	 	]
       },
       {
	 	label: "Menu 2",
	  	items: 
	  		[
				{
					label: "Another group",
					items:
					  [
			     		{ label: "ola" },
			     		{ label: "ole" },
			     		{ label: "oli" } 
        	    	  ]
     			},
        		{
					label: "Yet another group",
					items: 
					 [
			     		{ label: "hello" },
			     		{ label: "olla" },
		     			{ label: "oi" }
					 ]
				}
     	 	]
       }
       
   ];



function menuBar(menuBarData) {
	 document.writeln("<div class='menubar'>");
	 for(var button in menuBarData) 
	   menuButton(menuBarData[button]);
	 document.writeln("</div>");
}


function menuButton(menuButtonData) {
 	 document.write("<span class='menubutton'");
 	 document.writeln(" onclick='showMenu(this)'>");
	 document.writeln(menuButtonData.label);
	 document.writeln("<div class='menu'>");
	 for(var item in menuButtonData.items)
	   menuItem(menuButtonData.items[item]);
	 document.writeln("</div>");
	 document.writeln("</span>");
}


function menuItem(menuItemData) {
 	 document.write("<div class='menuitem'");
	 document.write("	 onMouseOver='selectItem(this)'");
	 document.write("	 onMouseOut='unselectItem(this)'");
	 document.write("	 onClick='executeItem(this);'");
	 document.writeln(">");
	 document.writeln(menuItemData.label);
	 document.writeln("</div>");
}

var activeMenuButton=true; // menu buttons are inactivated when processing items
function showMenu(menuButton) {
   var menu = menuButton.getElementsByTagName("div")[0];
   var divs = menuButton.parentNode.getElementsByTagName("div");
   var otherMenu;
   
   if(menu.style.visibility == 'visible')
   			menu.style.visibility = 'hidden';
   else {
   		// hide other menus
	   for(var i= 0; i< divs.length; i++ )
    	  if(divs[i].className == 'menu')
	    	 divs[i].style.visibility = 'hidden';
	  
   		if(activeMenuButton)
   	  		menu.style.visibility = 'visible';
   		else
      		activeMenuButton = true; // reactivate menu buttons 
	}
}

function executeItem(menuItem) {
   menuItem.parentNode.style.visibility = 'hidden';
   activeMenuButton = false;
}


function selectItem(item) {
	item.className = "menuitem selected";
}

function unselectItem(item) {
	item.className = "menuitem";
}
