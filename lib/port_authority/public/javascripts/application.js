var live_search_timeout;
var live_search_last_keypress;
var live_search_interval = 750;

$(function() {

  $(".message").each(function() {
    if($(this).attr("class") == "message") // And not combined with another class...
      $(this).effect("highlight", { "color": "#e1f4d4" }, 2000);
  });
  
  $(".error").effect("highlight", { "color": "#f00" }, 2000);

  $(".live_search input").keyup(function(e) {
    if ( e.keyCode == 224 || e.keyCode == 91 || e.keyCode == 9 || (e.keyCode >=37 && e.keyCode <= 40) ) return;

    if ( $(this).val().length == 1 ) return;

    if ( e.keyCode == 13 ) {
      window.clearTimeout(live_search_timeout);
    }
    else {
      window.clearTimeout(live_search_timeout);
            
      if(live_search_last_keypress) {
        live_search_interval = (new Date() - live_search_last_keypress) > 500 ? 1000 : 400;
      }
      
      live_search_last_keypress = new Date();
      live_search_timeout = window.setTimeout(function() {
        $(".live_search").trigger("submit");
      }, live_search_interval);
    }
  });

  $(".live_search").submit(function() {
    var query = $(this).serialize();
    $(".preserve_location").each(function() {
      this.href = mergeParams(this.href, query);
    });
    $(this).next("table").load(window.location + "?" + query);
    return false;
  });

});

function mergeParams(url, params) {
  var location = null;
  var query_string = null;
  
  if(/\?/.test(url)) {
    var capture = url.match(/^(.*?)\?(.*)$/);
    location = capture[1];
    query_string = capture[2];
  } else {
    location = url;
  }
  
  if(query_string) {
    query_string = query_string + "&" + params;
  } else {
    query_string = params;
  }
  
  // Transform query-string...
  
  return location + "?" + query_string;
}

function deleteWithModal(link) {
  modal = $("#delete_modal");
  modal.load(link.href);
  openModal(modal);
  return false;
}

function openModal(content) {
  content.modal();
  $(window).keyup(function(e) { if ( e.keyCode == 27 ) closeModal(); });
}

function closeModal() {
  $(window).unbind('keyup');
  $('.modalClose').click();
}