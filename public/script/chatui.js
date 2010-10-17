var server;
var MAX_COMMITS = 3;
var message_buffer = [];
var MAX_ISSUES = 3;
var gravatars_map = new Object();
var top_message_id = 0;
var oldest_message_id = 0;

function fromISO(date) 
{
  date = date.replace(/\D/g, " ");
  var dtcomps = date.split(" ");
  
  dtcomps[1]--;
  return new Date(Date.UTC(dtcomps[0], dtcomps[1], dtcomps[2], dtcomps[3], dtcomps[4], dtcomps[5]));
}

$(document).ready(function() {
  oldest_message_id = ($('#earliest-chat-id')[0].innerText ? $('#earliest-chat-id')[0].innerText : 0) ;
  
  if($('#display > .message').not('#original-message').first().get()[0] != undefined) {
    top_message_id = $('div.message').not('#original-message').first().get()[0].id.substr(3);
  }
  
  function isFullScreen() { }

  if (window.location.hash === '#fs' ) {
    $('#lpane').addClass('fullscreen');
    $('#account').addClass('fullscreen');
    $('#rpane').addClass('fullscreen');
  }
  $('#fullscreen').click(function(){
    if ($('#lpane').hasClass('fullscreen')) {
      $('#lpane').removeClass('fullscreen');
	  $('#account').removeClass('fullscreen');
	  $('#rpane').removeClass('fullscreen');
	  window.location.hash = '';
	  return false;
	} else {
      $('#lpane').addClass('fullscreen');
	  $('#account').addClass('fullscreen');
	  $('#rpane').addClass('fullscreen');
	  window.location.hash = '#fs';
	  return false;
	}
  });

  // Hooks up event handlers
  server =  new EventDispatcher("ws://"+window.location.hostname+":8000");
  server.bind('user join', new_user);
  server.bind('user leave', user_leave);
  server.bind('new message', new_message);
  server.bind('new commit', new_commit);
  server.bind('new issue', new_issue);
  server.bind('new connection handshake', assign_uuid);
  server.bind('close', reconnect);
  server.bind('chat users', verify_user_list);
  server.bind('user idle',user_idle);
  server.bind('set unidle', user_unidle);


  // Send a handshake to the socket server identifying the current
  // chat context.
  
  if($(':input:hidden')[0] === undefined) {
    server.send('new connection handshake', {"creator":$('#repo-user').text(),
                                             "repository":$('#repo-repo').text()});
  } else {
    server.send('new connection handshake', {"session_key":$(':input:hidden')[0].value,
                                             "creator":$('#repo-user').text(),
                                             "repository":$('#repo-repo').text()});
  }
  
                                           
  // Prepares the page a bit;
  scroll_to_bottom();
  
  //$('#scroll-button').hide();
  //$('#scroll-button').click(scroll_click_cb);
  
  retrieve_commits();
  retrieve_issues();
  setInterval("retrieve_issues()", 12000);
  setInterval("retrieve_commits()", 12000);

  
  // Updates number of users in each fork chat
  $('#forks').click((function(evt) {
    // Keep the id around in the closure
    // so we can kill the recurring event
    var interval_id = 0;
    
    return (function() {
      if(!$(this).hasClass('clicked')) {
        interval_id = setInterval("update_user_counts()", 5000);
      } else {
        clearInterval(interval_id);
      }
    });
  }()));
  
  
  
  // Submits text
  $('#send > * > *').keypress(function(evt) {
    if(event.keyCode === 13) {
      var message = $(this).val(); 
      var current_time = new Date();
      var user_token  = $(':input:hidden')[0].value;
    
      server.send("new message", {"author":user_token,
                                  "text":message,
                                  "time":current_time.getTime(),
                                  "issue":{},
                                  "commit":{}});
      $(this).last().val("");
      scroll_to_bottom();
     }
  });
  
  $('#display').scroll(function() {
    if(($(this).scrollTop() == 0) && (oldest_message_id != top_message_id)) {
      //$('#scroll-button').show();
    }
  });
  
  if(oldest_message_id == top_message_id) {
    $('#original-message').show();
  }
  
  // Checks if we need new data from the server for old messages.
  $('#display').bind('mousewheel',(function() {
    
   // Local variable closure
   var previous_scroll = 0;
   
   return (function() {
     var new_scroll = $('#display').scrollTop();
     if((previous_scroll > new_scroll) &&
          (new_scroll < 100))
      {
        if(message_buffer.length == 0 && top_message_id > oldest_message_id) {
            retrieve_old_messages(new Date(parseInt($('#msg'+top_message_id+'>.timestamp')[0].innerText)));
        } else {
          display_old_messages();
        }
      } else if(previous_scroll < new_scroll)
      {
        previous_scroll  = new_scroll;
        return;
      }
   }); 
  }()));
  
});

function scroll_click_cb()
{
    if(message_buffer.length == 0 && parseInt(top_message_id) > oldest_message_id) {
        retrieve_old_messages(new Date(parseInt($('#msg'+top_message_id+'>.timestamp')[0].innerText)));
    } else {
      display_old_messages();
    }
    return false;
}

function user_idle(evt)
{
  var users = $.merge($('#admins > li'),$('#others > li'));
  
  for(var p = 0; p < users.length; p++)
  {
    if(evt.username == users[p].children()[2].innerText) {
      users[p].addClass('idle');
    }
  }
}

function user_unidle(evt)
{
  var users = $.merge($('#admins > li'),$('#others > li'));
  
  for(var p = 0; p < users.length; p++)
  {
    if(evt.username == users[p].children()[2].innerText) {
      users[p].removeClass('idle');
    }
  }
}


function verify_user_list(evt)
{
  var users = $.merge($('#admins > li'),$('#others > li'));
  
  if(users.length == 1)
  {
    users = [users];
  }
  
  for(var p = 0; p < users.length; p++)
  {
    var remove = true;
    for(var i = 0; i < evt.length; i++) 
    {
      if(evt[i].username == users[p].children()[2].innerText) {
        remove = false;
      }
    }
    if(remove) {
      users[p].remove();
    }
  }
}

function reconnect()
{
  server.refresh();
  if($(':input:hidden')[0] === undefined) {
    server.send('new connection handshake', {"creator":$('#repo-user').text(),
                                             "repository":$('#repo-repo').text()});
  } else {
    server.send('new connection handshake', {"session_key":$(':input:hidden')[0].value,
                                             "creator":$('#repo-user').text(),
                                             "repository":$('#repo-repo').text()});
  }
}

function retrieve_old_messages(date)
{
  var req_url = "/"+$('#repo-user').text() +"/"+ $('#repo-repo').text()+"/messages/" + date.getTime().toString();
  $.ajax({
    url:req_url,
    success:function(data) {
      $('#display').bind('mousewheel', function() {});
      
      if(data.length == 0) return;
      var objs = data;
      var msg_template = "<div id='msg{0}' class='message {1}'>" +
                            "<div class='author'> {2} </div>" +
                            "<div class='timestamp'> {3} </div>" +
                            "</pre><p>{4}</p></pre>" +
                         "</div>";
      
      for(var i = 0; i < objs.length; i++)
      {
        if(i > 0) {
          var follow = (objs[i - 1].author == objs[i].author) ? 'follow' : '';
        } else {
          var follow = '';
        }
        var result = format(msg_template, objs[i].id, follow ,objs[i].author, objs[i].created_at, objs[i].text);
        message_buffer.push(result);
      }
      
      //top_message_id = $(message_buffer[0])[0].id.substr(3);
      display_old_messages();
    }
  });

}

function display_old_messages() {
  var old_top = top_message_id;
  var result;
  for(var i = 0; i < 10; i++)
  {
    result = message_buffer.pop();
    $(result).prependTo('#display');
    top_message_id = $('#display > .message').first().get()[0].id.substr(3);
  }
  $('#display').scrollTop($("#msg"+old_top)[0].offsetTop);
  
  //var button = $('#scroll-button').get()[0];
  var flag = $('#original-message').get()[0];
  
 // $('#scroll-button').remove();
  $('#original-message').remove();
  
  //$(button).prependTo('#display');
  $(flag).prependTo('#display');
  
  //$('#scroll-button').click(scroll_click_cb);
  
  if(parseInt(top_message_id) == parseInt(oldest_message_id))
  {
    $('#original-message').show();
    //$('#scroll-button').hide();
  }
};

function get_gravatar(username,callback){
	if (username== "") 
		callback("default-image");
	if (username in gravatars_map){
		callback(gravatars_map[username]);
	}else {
		$.ajax({url:"http://github.com/api/v2/json/user/show/"+username,
		dataType:'jsonp',
		success: function(data){
			var gravatar = data["user"]["gravatar_id"];
			gravatars_map[username] = gravatar;
			callback(gravatar);
			}});
		}
}

function retrieve_issues()
{
  var current_repo = $('#repo-user').text() +"/"+ $('#repo-repo').text();
  var issues_web_url = "http://github.com/"+current_repo+"/issues#issue/";
  var issues_url = "http://github.com/api/v2/json/issues/list/" + current_repo;
		$.ajax({url: issues_url+"/open",
		          dataType:"jsonp",
		          success: function(data) {
			 		$.ajax({url: issues_url+"/closed",
							dataType: "jsonp",
							success: function(data2){
								v= $.merge(data["issues"],data2["issues"]);
								v.sort(function(a,b) {return fromISO(b.created_at) - fromISO(a.created_at)} )
								display_issues(issues_web_url,v);
							}});
						}
					});
}



function display_issues(url,issues){
  function display_issue(issue){
	if (issue === null || issue === undefined ) return
	if($('.item.issue').length >= MAX_ISSUES) return;
		/*var dupe_checks = $('.issue-number').map(function() {return $(this)[0].href.split("/").pop() == data["id"];}).get();

	    for(var i = 0; i < dupe_checks.length; i++)
	    {
	      if(dupe_checks[i]) {
	        return;
	      }
	    }*/
	var issues_list = $('.issue').map(function(){
		var iss = new Object();
		iss["number"] = parseInt($(this).find(".issue-number").text()); 
		iss["state"] = $(this).find(".state").text();
		iss["ref"] = $(this);
		return iss;
		//return $($(this)[0]).text();
		}).get();
	for (var i = 0; i < issues_list.length; i++){
		var curr_issue = issues_list[i];
		if (curr_issue["number"] == issue["number"]){
			
			if (curr_issue.state != issue.state){
				if (curr_issue.state == "open"){
					$(curr_issue.ref).removeClass("open").addClass(issue.state);
					$(curr_issue.ref).find(".state").text(issue.state);
				}else if (curr_issue.state == "closed"){
					$(curr_issue.ref).removeClass("closed").addClass(issue.state);
					$(curr_issue.ref).find(".state").text(issue.state);
				}
				
			}
			return;			
		}
	}

	get_gravatar(issue.user,
		function(gravatar){

			//var gravatar = data["user"]["gravatar_id"];
  			var issue_template = "<div class='item issue {0}'>" +
                            "<strong class='state'>{1}</strong>" +
                            "<a class='title' href='" + url + issue.number+ "'"+ ">{2}</a>" +
							"<div class='issue-number' style='display:none'>"+issue.number+"</div>"+
                            "<div class='wide'></div>" +
                            "<a class='person' href='{3}'>" +
                              "<img src='http://www.gravatar.com/avatar/{4}?s=15&r=pg&d=mm'>" +
                              "<span class='user-name'>{5}</span>" +
                            "</a>" +
                            "<div class='date'>{6}</div>" +
                        "</div>";
					
						var result = format(issue_template,issue.state, issue.state, issue.title, "http://github.com/"+issue.user, gravatar, issue.user, beautify_date(issue.created_at) );
						$(result).hide().appendTo('#issues-feed').fadeIn('slow');
	});
	}
	
	for (var i = 0; i < MAX_ISSUES; i++){
		display_issue(issues[i]);
	}
	
}


function retrieve_commits()
{
  var current_repo = $('#repo-user').text() +"/"+ $('#repo-repo').text();
  
  $.ajax({url: "http://github.com/api/v2/json/commits/list/" + current_repo + "/master",
          dataType:"jsonp",
          success: function(data) {display_commits(data); }});
}

function display_commits(response)
{

	function display_commit(login,data){
		var dupe_checks = $('.hash').map(function() {return $(this)[0].href.split("/").pop() == data["id"];}).get();

	    for(var i = 0; i < dupe_checks.length; i++)
	    {
	      if(dupe_checks[i]) {
	        return;
	      }
	    }
		if($('.item.commit').length >= MAX_COMMITS) return;
			get_gravatar(login, function(gravatar){
			var user = data["author"];
			var result = "";
			var profile_link = "http://github.com/";

			var commit_template = "<div class='item commit'>" +
			"<p>{0}</p>" +
			"<a class='hash' href='"+data["url"]+"'"+">{1}</a>" +
			"<a class='person' href='{2}'>" +
			"<img src='http://www.gravatar.com/avatar/{3}?s=15&r=pg&d=mm'>" +
			"<span class='user-name'>{4}</span>" +
			"</a>" +
			"<div class='date'>{5}</div>" +
			"</div>";

			result = format(commit_template,
				data["message"].slice(0,50),
				data["id"].slice(0,20),
				profile_link + user["login"],
				gravatar,
				(user["name"] ? user["name"] : user["login"]),
				beautify_date(fromISO(data["committed_date"])));

				$(result).hide().appendTo('#commits-feed').fadeIn('slow');
			});
		}


		for(var i = 0; i < MAX_COMMITS; i++)
		{
			var login = response["commits"][i]["author"]["login"];
			var data = response["commits"][i];
			display_commit(login,data);
		}  
	}


// Assigns a unique ID to this websocket, given by the server.
function assign_uuid(evt)
{
  server.assign_id(evt.uuid);
  for(var i = 0; i < evt.users.length; i++)
  {
    if(evt.users[i].real_name) {
        var user_template = "<li><img src='http://www.gravatar.com/avatar/{0}?s=50&r=pg&d=mm'>" +
                        "<div class='user-name'>{1}</div>" +
                        "<div class='user-id'>{2}</div></li>";
        var name = evt.users[i].real_name;
        var content = format(user_template, evt.users[i].gravatar, evt.users[i].real_name, evt.users[i].username);
    } else {
        var user_template = "<li><img src='http://www.gravatar.com/avatar/{0}?s=50&r=pg&d=mm'>" +
                        "<div class='user-id norealname'>{1}</div></li>";
        var name = evt.users[i].username;
        var content = format(user_template, evt.users[i].gravatar, evt.users[i].username);
    }
    
    if($('#repo-user')[0].innerHTML == evt.users[i].username) {
      $(content).hide().appendTo('#admins').fadeIn('fast');
    } else {
      $(content).hide().appendTo('#others').fadeIn('fast');
    }
  }
}


// Fills in the number of users in a chatroom on the forks pane
function update_user_counts()
{
  $('#your-forks .repo-user, #other-forks .repo-user').each(function() {
    var user = $(this)[0].innerHTML.split('/')[0];
    var source_repo = $(this)[0].innerHTML.split('/')[1];
    var num_users = 0;
    
    // Send request to get number of users once we have the server up.
    
    if(num_users > 0) {
      var target = $(this).next();
      $("<a class='repo-chat' href='#'>chat (<span class='number'>" +
          num_users + "</span>)</a>").appendTo($(this).parent());
      target.remove();
    }
  });
}

// Scrolls the main chat window to the bottom.
function scroll_to_bottom()
{
  $('#display').each(function() {
    var scrollHeight = Math.max(this.scrollHeight, this.clientHeight);
    this.scrollTop = scrollHeight - this.clientHeight;
  });
}

// Callback for when a new user joins the chat.
function new_user(evt)
{
  if(evt.username == $('#username-hidden')[0].innerHTML) return;
  
  var user = new User(evt.profile_link, evt.gravatar, evt.username, evt.real_name, evt.repositories, evt.seen_before);
  
  if(user.real_name) {
      var user_template = "<li><img src='http://www.gravatar.com/avatar/{0}?s=50&r=pg&d=mm'>" +
                      "<div class='user-name'>{1}</div>" +
                      "<div class='user-id'>{2}</div></li>";
      var name = user.real_name;
      var content = format(user_template, user.gravatar, user.real_name, user.username);
  } else {
      var user_template = "<li><img src='http://www.gravatar.com/avatar/{0}?s=50&r=pg&d=mm'>" +
                      "<div class='user-id norealname'>{1}</div></li>";
      var name = user.username;
      var content = format(user_template, user.gravatar, user.username);
  }

  if($('#repo-user')[0].innerHTML == user.username) {
    $(content).hide().appendTo('#admins').fadeIn('fast');

  } else {
    $(content).hide().appendTo('#others').fadeIn('fast');
  }
}

// Callback for a new message being received.
function new_message(evt)
{  
  var last_author = "";
  if($('#display > div > .author').last()[0] != undefined)
  {
    last_author = $('#display > div > .author').last()[0].textContent;
  }
  var message_template = "<div class='{0}'><div class='author'>{1}</div><pre><p>{2}</p></pre></div>";
  
  // Prefer real (first) name, but fall back on username.
  if(evt.author.real_name) {
    var name = evt.author.real_name.split(" ")[0];
  } else {
    var name = evt.author.username;
  }
  
  if(evt.author.real_name.split(" ")[0] == last_author || 
     evt.author.username == last_author) 
  {
    
    $(format(message_template, "message follow", name, evt.text)).appendTo('#display');
  } else {
    $(format(message_template, "message", name, evt.text)).appendTo('#display');
  }
}

// Callback for a new commit message appearing.
function new_commit(evt)
{
  var commit_link = format("http://www.github.com/{0}/commit/{1}", evt.repository, evt.hash);
  var commit_template = "<div class='item commit'>" +
                            "<p>{0}</p>" +
                            "<a class='hash' href='"+commit_link+"'"+">{1}</a>" +
                            "<a class='person' href='{2}'>" +
                              "<img src='http://www.gravatar.com/avatar/{3}?s=15&r=pg&d=mm'>" +
                              "<span class='user-name'>{4}</span>" +
                            "</a>" +
                            "<div class='date'>{5}</div>" +
                        "</div>";
  
  // Prefer real (first) name, but fall back on username.
  var name = (evt.author.real_name ? evt.author.real_name : evt.author.username);
  
  var content = format(commit_template, evt.commit_msg.slice(0,50), evt.hash.slice(0,20),
                        evt.author.profile_link, evt.author.gravatar,
                        name, beautify_date(evt.time));
                        
  $(content).hide().appendTo('#commits-feed').fadeIn('fast');
  clip_feed_items();
}

// Callback for a new issue appearing.
function new_issue(evt)
{
  var issue_link = format("http://www.github.com/{0}/issues#issue/{1}", evt.repo, evt.github_id);
  
  var issue_template = "<div class='item issue {0}'>" +
                            "<strong>{1}</strong>" +
                            "<a class='title' href='" + issue_link + "'" + ">{2}</a>" +
                            "<div class='wide'></div>" +
                            "<a class='person' href='{3}'>" +
                              "<img src='http://www.gravatar.com/avatar/{4}?s=15&r=pg&d=mm'>" +
                              "<span class='user-name'>{5}</span>" +
                            "</a>" +
                            "<div class='date'>{6}</div>" +
                        "</div>";
  
  
  // Different behavior for open and closed issues
  if(evt.open) 
  {
    var name = (evt.creator.real_name ? evt.creator.real_name : evt.creator.username);
    var content = format(issue_template, "", "Opened", evt.title,
                                            evt.creator.profile_link, evt.creator.gravatar, name,
                                            beautify_date(evt.created_date));
  } else {
    // We can't trust that there will be a closer as all we have is a guess
    // to begin with.
    if(evt.closer) {
      var name = (evt.closer.real_name ? evt.closer.real_name : evt.closer.username);
      var content = format(issue_template, "closed", "Closed", evt.title,
                                              evt.closer.profile_link, evt.closer.gravatar, name,
                                              beautify_date(evt.closed_date));
    } else {
      // If we can't determine the closer server side, display as much as we can
      var content = format(issue_template, "closed", "Closed", evt.title,
                                            "", "", "", beautify_date(evt.closed_date));
    }
  }
  $(content).hide().appendTo('#issues-feed').fadeIn('fast');
  clip_feed_items();
}

// Callback for user leaving chat
function user_leave(evt)
{
  var name = (evt.real_name ? evt.real_name : evt.username);
  var target = $("#users .user-name:contains("+name+")").parent();
  target.fadeOut(function(){target.remove();});
}

// Takes a UTC millisec offset and returns a date string of the form
// showing the whole day, month and year if the date is not today, and
// just the time otherwise.
function beautify_date(ms_offset)
{
  var date = new Date(ms_offset);
  var today = new Date();
  
  if((date.getDay() == today.getDay()) && (date.getMonth() == today.getMonth()))
  {
    return date.toLocaleTimeString();
  } else {
    var day_pos = date.toLocaleDateString().indexOf(",");
    return date.toLocaleDateString().substr(day_pos + 2);
  }
}


// Variable argument formatted string function.
function format(str)
{
  for(i = 1; i < arguments.length; i++)
  {
    str = str.replace("{" + (i - 1) + "}", arguments[i]);
  }
  return str;
}
