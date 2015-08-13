#!/usr/bin/env python
#

"""
fifofum: FIFO pipe server

Usage: python fifofum.py [--addr=...] [--port=...] [--multiplex=1] [--passthru=1] [--input=pipe0.fifo] pipe1.fifo ...

Specifying "-" or "_" as pipe name uses stdin for input and/or stdout for output

Streams PNG images and text from named pipes created by fifopiper.c via a browser.
Newline terminated printable text should be written to the pipe.
Images should be output as data URLs terminated by newlines ("data:image/png;base64,...\n").

Different pipes are treated as different channels, named using the basename of the FIFO file.
Each channel is displayed separately.

For multiplexed pipes, a directive line of the form "channel: name\n" is used to switch channels within a pipe.
(The multiplex option is useful even for a single channel, if multiple blocks of lines always need to be displayed together,
because lines are skipped until the channel directive is encountered.)

--passthru option "pipes" non-image output data to standard output (for logging)

--background specifies the URL of a background image. The image should cover exactly the same domain as the data being plotted.
  For example, if using cyclindrical projection over the whole globe, the NASA Blue Marble image can be used as the background
  --background=http://eoimages.gsfc.nasa.gov/images/imagerecords/74000/74092/world.200407.3x5400x2700.jpg

If the subdirectory "www" is present where the source for this file is located, then it will be used to serve files (including "index.html").

Usage: 
  python ~/normal2/fifofum/fifofum.py --input=testin.fifo testout.fifo

"""

from tornado.options import define, options, parse_command_line

from tornado import httpserver, ioloop, web, websocket

import fcntl
import functools
import json
import logging
import os
import os.path
import sys
import time

Doc_rootdir = os.path.join(os.path.dirname(__file__), "www")

Web_sockets = []
Pipes = {}
Input_pipe = None

Index_html = """
<!DOCTYPE html>
<html>
<head>
<title>FIFO pipe server</title>
<script>
    var displayInputBox = %(input_box)s;  // SUBSTITUTE
    var imageBackground = '%(image_background)s';  // SUBSTITUTE

    function appendPipeElement(pipeName, containerId)
    {
        var container = document.getElementById(containerId);
        container.appendChild(document.createElement("hr"));

        var div = document.createElement("div");
        div.id = "div_"+pipeName;
        div.innerHTML = "<p><h3>"+pipeName+" output<\h3>";
        container.appendChild(div);

        var img = document.createElement("img");
        img.id = "img_"+pipeName;
        img.src = "";
        if (imageBackground) {
           img.style["background-image"] = "url('"+imageBackground+"')";
           img.style["background-size"] = "100%% 100%%";
           }
        div.appendChild(img);

        var pre = document.createElement("div");
        pre.id = "pre_"+pipeName;
        pre.style["white-space"] = "pre-wrap";
        pre.style["font-family"] = "monospace";
        div.appendChild(pre);
    }

    function sendData() {
        var inputElem = document.getElementById("inputElement");
        var msg = inputElem.value;
        console.log("fifofum: sendData: ", msg);
        FIFOsocket.send(msg);
    }

    function raw_to_png(b64data) {
       /* Converts raw base64 image pixel data to PNG, returning the data URL
       Raw byte format: width mod 256, width/256, height mod 256, height/256, 256*(r,g,b,a) table, width*height*color_index
       */
       var i, j, pixel, color_offset;
       var raw = window.atob(b64data);
       var rawLength = raw.length;
       var rawData = new Uint8Array(new ArrayBuffer(rawLength));
       for (i = 0; i < rawLength; i++) {
          rawData[i] = raw.charCodeAt(i);
       }

       var width = rawData[0] + 256*rawData[1];
       var height = rawData[2] + 256*rawData[3];

       var cmap_offset = 4;
       var pixel_offset = cmap_offset + 4*256;

       // console.log("raw_to_png: b64_len, raw_len, expected_raw_len, width, height", b64data.length, rawLength, pixel_offset+width*height, width, height);
       // console.log("raw_to_png: R,G,B,A,img_0,img_n-1", rawData[cmap_offset], rawData[cmap_offset+1], rawData[cmap_offset+2], rawData[cmap_offset+3], rawData[pixel_offset], rawData[rawLength-1]);

       var canvas = document.createElement("canvas");
       canvas.width = width;
       canvas.height = height;

       var ctx = canvas.getContext("2d");
       var imageData = ctx.getImageData(0, 0,canvas.width, canvas.height);
       var data = imageData.data;

       for (i = 0; i < rawLength-pixel_offset; i++) {
          j = i * 4;
          pixel = rawData[pixel_offset+i];
          color_offset = cmap_offset+pixel*4;
          data[j]  =  rawData[color_offset];
          data[j+1] = rawData[color_offset+1];
          data[j+2] = rawData[color_offset+2];
          data[j+3] = rawData[color_offset+3];
       }

       ctx.putImageData(imageData, 0, 0);
       return canvas.toDataURL("image/png");
    }
    
    var protoPrefix = (window.location.protocol === 'https:') ? 'wss:' : 'ws:';
    var FIFOsocket = new WebSocket(protoPrefix + '//' + window.location.host + '/ws');

    FIFOsocket.onopen = function(){
        console.log("FIFOsocket.onopen:");
        var inp = document.getElementById("inputBox");
        if (!displayInputBox)
            inp.style["display"] = "none";

        document.getElementById('inputElement').onkeypress=function(evt) {
              if (evt.keyCode==13)
                  document.getElementById('inputButton').click();
            }
    };

    var rawImagePrefix = "data:image/x-raw;base64,";

    FIFOsocket.onmessage = function(evt){
        var msg = evt.data;  
        var pipeName = "pipe";
        var content = msg;

        var indx = msg.indexOf(":");
        if (indx > 0) {
            // Message of the form 'pipeName:data_URL' (no colons allowed in pipeName)
            pipeName = msg.substr(0,indx);
            content = msg.substr(indx+1);
        }

        var contentType = content.substr(0,11) === "data:image/" ? "image" : "text"; // Default action is to display text 

        //console.log("FIFOsocket.onmessage:", pipeName, contentType);
        if (document.getElementById("div_"+pipeName) === null)
            appendPipeElement(pipeName, "pipeContainer");

        if (contentType === "image") {
           if (content.substr(0,rawImagePrefix.length) === rawImagePrefix) {
              // Convert raw image to data URL
              content = raw_to_png(content.substr(rawImagePrefix.length));
           }
           document.getElementById("img_"+pipeName).src = content;
        } else if (contentType === "text") {
           document.getElementById("pre_"+pipeName).innerHTML = content;
        }
    };

    FIFOsocket.onclose = function(evt) {
        console.log("FIFOsocket.onclose:", evt);
    };

    FIFOsocket.onerror = function(evt) {
        console.log("FIFOsocket.onerror:", evt);
    };
  </script>
</head>

<body>
  <h2>fifofum server</h2>
  <div id="inputBox">
    Input: <input id="inputElement" type="text" maxlength=50></input> <button id="inputButton" onclick="sendData();">Send</button>
  </div>

  <div id="pipeContainer">
  </div>
</body>

</html>
"""

class GetHandler(web.RequestHandler):
    def get(self, path):
        opts = {"input_box": "true" if options.input else "false",
                "image_background": options.background}
        self.write(Index_html % opts)


class SocketHandler(websocket.WebSocketHandler):
    def check_origin(self, origin):
        return True

    def open(self):
        logging.warning("fifofum: websocket.open")
        if self not in Web_sockets:
            Web_sockets.append(self)

    def on_message(self, message):
        if Input_pipe is not None:
            try:
                Input_pipe.write(message+"\n")
                Input_pipe.flush()
            except Exception, excp:
                logging.error("fifofum: on_message: Error in transmitting input to %s: %sd", options.input, excp)

    def on_close(self):
        if self in Web_sockets:
            Web_sockets.remove(self)

class PipeReader(object):
    def __init__(self, name, filepath):
        self.name = name
        self.filepath = filepath
        if filepath in "-_":
            self.file = None
            self.fd = 0          # stdin
        else:
            self.file = open(filepath, "r")
            self.fd = self.file.fileno()

        fcntl.fcntl(self.fd, fcntl.F_SETFL, fcntl.fcntl(self.fd, fcntl.F_GETFL)|os.O_NONBLOCK) # Non-blocking

        self.line_buffer = []
        self.channel = ""
        self.skip_line = True

    def on_read(self, fd, events):
        try:
            data = os.read(self.fd, 81)
        except Exception, excp:
            logging.error("fifofum: on_read: Error in reading from %s: %sd", self.filepath, excp)
            data = ""
            self.skip_line = True
            time.sleep(1)
    
        while data:
            # Search for line break
            head, sep, data = data.partition("\n")

            # Append head to current line
            self.line_buffer.append(head)
        
            if not sep: # No line break found in data
                break

            full_line = "".join(self.line_buffer)
            self.line_buffer = []

            # Process line
            if full_line.startswith("channel:") and options.multiplex:
                # Channel switch directive line
                _, sep, self.channel = full_line.partition(":")

                self.channel = self.channel.strip().replace(":","_").replace(" ","_") # No colons/spaces allowed in channel name
                ##print "CHANNEL: ", self.channel
                continue

            if not full_line.startswith("data:"):
                # Not channel or data directive
                if self.skip_line:
                    # Skip possibly incomplete first line
                    self.skip_line = False
                    continue

                if options.passthru:
                    # Transmit to STDOUT
                    if len(Pipes) > 1:
                        print self.name + ":" + full_line
                    else:
                        print full_line
            
            if options.multiplex and not self.channel:
                # Channel must be defined for multiplexed pipes before data is processed (to avoid processing incomplete line blocks)
                continue   # Discard line

            # Transmit buffered line as message pipeName:data_URL or plain text line
            channel_name = self.channel if self.channel else self.name

            msg = channel_name + ":" + full_line

            ##print "MSG: ", msg
            for ws in Web_sockets:
                ws.write_message(msg)

        
def stop_server():
    Http_server.stop()
    IO_loop.stop()

def main():
    global Http_server, Input_pipe, IO_loop, Pipes

    define("addr", default="127.0.0.1", help="IP address")
    define("port", default=8008, help="IP port")
    define("input", default="", help="Input capture pipe file")
    define("passthru", default=0, help="passthru=1 to pass through non-image output to stdout")
    define("multiplex", default=0, help="multiplex=1 for multiplexed pipes")
    define("background", default="", help="URL of background image")

    options.logging = None
    args = parse_command_line()

    if not args:
        sys.exit("Usage: fifofum.py [--addr=...] [--port=...] [--multiplex=1] [--passthru=1] [--input=pipe0.fifo] pipe1.fifo ...")

    IO_loop = ioloop.IOLoop.instance()

    for arg in args:
        if arg not in "-_" and not os.path.exists(arg):
            logging.error("Pipe %s not found", arg)
            sys.exit(1)
        name = os.path.splitext(os.path.basename(arg))[0].replace(":","_").replace(" ","_") # No colons/spaces allowed in channel name
        logging.warning("fifofum: Opening pipe %s: %s", name, arg)
        Pipes[name] = PipeReader(name, arg)
        fhandle = Pipes[name].file if Pipes[name].file else Pipes[name].fd  # Note: using fd does not always seem to work
        IO_loop.add_handler(fhandle, Pipes[name].on_read, IO_loop.READ)

    if options.input:
        Input_pipe = sys.stdout if options.input in "-_" else open(options.input, "w")
        logging.warning("fifofum: Transmitting input via %s", options.input)
        print Input_pipe

    handlers = [
        (r"/ws", SocketHandler),
        ]

    if os.path.isdir(Doc_rootdir):
        handlers += [ (r"/(.*)", web.StaticFileHandler, {"path": Doc_rootdir, "default_filename": "index.html"}) ]
        dir_msg = ", serving files from directory " + Doc_rootdir
    else:
        dir_msg = ""
        handlers += [ (r"/(.*)", GetHandler) ]

    application = web.Application(handlers)
    Http_server = httpserver.HTTPServer(application)
    Http_server.bind(options.port, address=options.addr)
    Http_server.start()
    logging.warning("fifofum: Listening on %s:%d %s", options.addr, options.port, dir_msg)


    IO_loop.start()

if __name__ == "__main__":
    main()


