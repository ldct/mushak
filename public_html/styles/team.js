
activeTab = null;
activePanel = null;
function activate(selectedTab,panelId) {
 
  if(activeTab != null)
    activeTab.className = 'tab';
  activeTab = selectedTab;
  activeTab.className = 'tab selected';

  if(activePanel != null)
	  activePanel.style.visibility = 'hidden';
  
   activePanel = document.getElementById(panelId);
   activePanel.style.visibility = 'visible';
}

function highlight(highlightTab,on) {
  if(activeTab == null || activeTab != highlightTab) {
    if(on)
       highlightTab.className = 'tab highlight';
    else
       highlightTab.className = 'tab';
  }
}
