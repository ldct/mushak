
/*
  Set action of form with name of current controller
*/
function setAction(form) {	 
      var match = /execute\/([0-9]+)/.exec(document.location);
      document[form].action=match[1];
}

function disableEditing() {
    disableCheckboxElements(true);
    alert("\n\nTempo Terminado\n\n");
}

/*
  
*/
function checkOut() {
   if((answer = confirm('Terminar a avaliação?'))) {
     disableCheckboxElements(false);
   }
   return answer;
}


/*
  Enable/Disable editing, acording to status,
  in checkbox elements of quiz form
*/

function disableCheckboxElements(status) {
     form = document.forms.quiz;
     for(var el in form.elements) {
        if( "checkbox" != form.elements[el].type) continue;
	form.elements[el].disabled = status;		
     }
}

countOptions = new Array();

function declareMissing(ref) {
    form = document.forms.quiz;
    form.total.value++;
    form.total.disabled=true;
    form.missing.options[form.total.value] = new Option(ref,ref);
    countOptions[ref]=0;
}

function jumpMissing(q) {
    ref=q.options[q.selectedIndex].text;
    q.selectedIndex=0;
    window.open("#"+ref,"_self");
}

/* 
   Mark as question ref as missing, if checked,
   otherwise unmark it
 */
function markAsMissing(ref,checked) {
    var i,j,t;
    
    if(checked) {	
	removeQuestion(ref);
	countOptions[ref]++;
    } else {
	countOptions[ref]--;
	if(countOptions[ref]==0) {
	    insertQuestion(ref);
	}
    }
}

/*
  Remove ref from question options menu
  and decrease missing questions count
*/
function removeQuestion(ref) {
    with(document.forms.quiz.missing) {       
	for(i=0; i < options.length; i++) 
	    if(options[i].text==ref)
		break;	    
	if(i < options.length) {
	    for(j=i; j<options.length-1; j++) {
		options[j].text=options[j+1].text;
		options[j].value=options[j+1].value;
	    }
	    options[options.length-1]=null;
	    document.quiz.total.value--;
	}
    }
}

/* 
   Insert ref in mising questions option menu,
   run bubble sort on it to reorder array,
   and increase missing questions count
 */
function insertQuestion(ref) {
    var i,j,t;

    with(document.forms.quiz) {
	missing.options[++total.value] = new Option(ref,ref);
	with(missing)
	    for(i=1;i<missing.options.length;i++)
		if(greater(options[i].text,options[options.length-1].text)) {
		    t=options[i].text;
		    options[i].text=options[options.length-1].text;
		    options[options.length-1].text=t;
		    
		    t=options[i].value;
		    options[i].value=options[options.length-1].value;
		    options[options.length-1].value=t;	
		}
	
    }
}

/*
  compare references (ex. 2.12.2 > 2.2.5)
*/
function greater(s,r) {
    var as=s.split(".");
    var ar=r.split(".");
    var i;
    
    for(i=0; i<as.length && ar.length && as[i]==ar[i]; i++);
    return parseInt(as[i])>parseInt(ar[i]);
}
