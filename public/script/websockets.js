  /* Websockets wrapper 
  * API based on Ismael Celis' Websockets presentation, "Websockets and Ruby EventMachine"
  * */

// Create an event ger with the given socket server URL.
var EventDispatcher = function(url)
{
  var connection = new WebSocket(url);
  var callbacks = {};
  var ready = false;
  var message_queue = [];
  var unique_id;
  
  var _url = url;
  
  var reconnect_pause = 1;
  
  this.assign_id = function(id)
  {
    unique_id = id;
  }
  // Bind a callback to an event.
  this.bind = function(event_name, callback)
  {
    // Make sure this specific element is initialized
    callbacks[event_name] = callbacks[event_name] || [];
    callbacks[event_name].push(callback);
    return this;
  };
  
  // When this connection recieves a message, dispatch to all interested
  // parties.
  connection.onmessage = function(event)
  {
    var message = JSON.parse(event.data);
    dispatch(message.event, message.data);
  };
  
  connection.onclose = function()
  {
    
    dispatch('close', null);
  }

  connection.onopen = function()
  {
    ready = true;
    
    if(message_queue.length > 0)
    {
      message_queue.reverse();
      for(i = 0; i < message_queue.length; i++)
      {
        connection.send(message_queue.pop());
      }
    }
    dispatch('open', null);
  }
  
  
  // Send a javascript object to the socket server.
  //
  // Takes a string event name and an object to send.
  this.send = function(event_name, event_data)
  {
    var payload = JSON.stringify({event:event_name, data:event_data, uuid:unique_id});
    if(!ready) {
        message_queue.push(payload);
        return;
    }
    
    connection.send(payload);
    
    return this;
  };

  /*this.refresh = function()
  {
      return;
      setInterval(function() {
        connection = null;
        connection = new WebSocket(_url);
        reconnect_pause = 2*reconnect_pause;
      }, reconnect_pause * 1000);
  }*/
  
  this.reset_timeout = function()
  {
    this.reconnect_pause = 1;
  }

  // Dispatch some data on an event.
  var dispatch = function(event_name, data)
  {
    var all_callbacks = callbacks[event_name];

    if(all_callbacks === undefined) return;
    for(i = 0; i < all_callbacks.length; i++)
    {
      all_callbacks[i](data);
    }
  }
}

