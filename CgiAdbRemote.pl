#!/usr/bin/perl -s
#
#  Options:
die "Use -port=01, not -port 1\n" if $port eq '1';
die "Use -banner=Something, not -banner Something\n" if $banner eq '1';

$port ||= 8080;
$foreground ||= 0;
$banner ||= "WARNING: TESTS MAY BE RUNNING";
{
  package MyWebServer;

  use HTTP::Server::Simple::CGI;
  use base qw( HTTP::Server::Simple::CGI );

  my %dispatch = (
      '/' => \&resp_root,
      '/screenshot' => \&resp_screenshot,
      '/console' => \&resp_console,
      '/killServer' => \&resp_killServer,
      '/touch' => \&resp_touch,
      #'/touch' => { status => "204 No content", response => \&resp_touch },
      # ...
  );

  sub handle_request {
      my $self = shift;
      my $cgi  = shift;
    
      my $path = $cgi->path_info();
      my $handler = $dispatch{$path};

      if (ref($handler) eq "CODE") {
          print "HTTP/1.0 200 OK\r\n";
          $handler->($cgi);
      }
      elsif (ref($handler) eq "HASH") {
          print "HTTP/1.0 $$handler{status}\r\n";
          $$handler{response}($cgi);
      }
      else {
          print "HTTP/1.0 404 Not found\r\n";
          print $cgi->header,
                $cgi->start_html('Not found'),
                $cgi->h1('Not found'),
		"The path $path was not found",
                $cgi->end_html;
      }
  }

  sub resp_root {
      my $cgi  = shift;   # CGI.pm object
      return if !ref $cgi;
      
      my $who = $cgi->param('name');
      $cmd="adb devices";
      @devices = `$cmd`;
      
      print $cgi->header,
            $cgi->start_html("Devices");
      my $myself = $cgi->self_url;
      print $cgi->h1($cmd . localtime());
      print $cgi->start_ul();
      for (@devices) {
        if (/^(\S+)\s+device$/) {
            print $cgi->li($cgi->a({href=>"/console?device=$1"}, "$_"));
        }
        else {
            print $cgi->li($_);
        }
      }
      print $cgi->end_ul();
      print <<END;
<script type="text/javascript">
function killServer() {
    if (!confirm("Are you really sure you want to kill ADB?")) {
      alert("User uncertain. Aborted.");
    }
    else {
      if (confirm("Are any tests running? (OK=YES)")) {
        alert("Tests were running, Aborted.");
      }
      else {
        here = window.location.href.split("/");
        here.pop();
        here = here.join("/");
        url=here+"/killServer";
        window.frames["stdout"].location=url;
      }
    }
}
</script>
<input type='button' value="kill-server" onclick="killServer()">
<iframe height=50 width=500 align=left id=stdout name=stdout></iframe><br>
END
      print $cgi->end_html;
  }

  sub resp_console {
      my $cgi  = shift;   # CGI.pm object
      return if !ref $cgi;
      
      my $who = $cgi->param('device');

      my $myself = $cgi->self_url;

      print $cgi->header,
            $cgi->start_html("$who");
      print <<END;
<script type="text/javascript">
document.dragstart = function() { return false; }
function mouseDown(i, e) {
    document.lastDown = e;

    xoff = i.x - window.pageXOffset;
    yoff = i.y - window.pageYOffset;

    x1 = (e.clientX-xoff);
    y1 = (e.clientY-yoff);

    here = window.location.href.split("/");
    here.pop();
    here = here.join("/");
    url=here+"/touch?device=$who" +
        "&down=?" + x1 + "," + y1;
    window.frames["stdout"].location=url;
    return true;
}
function mouseUp(i, e) {
    f=document.lastDown;

    xoff = i.x - window.pageXOffset;
    yoff = i.y - window.pageYOffset;

    x1 = (f.clientX-xoff);
    y1 = (f.clientY-yoff);

    x2 = (e.x-xoff);
    y2 = (e.y-yoff);

    here = window.location.href.split("/");
    here.pop();
    here = here.join("/");
    url=here+"/touch?device=$who" +
        "&down=?" + x1 + "," + y1 +
        "&swipe=?" + x2 + "," + y2;

    window.frames["stdout"].location=url;
    document.bumped = 3;
    return true;
}
function keyPress(i, e) {
// Try to handle keypress and keydown together: assume charCode=0 if press.
    if (e.keyCode == 8) {
      keyEvent(i, 67);
    }
    else if (e.charCode == 0) {
      return;
    }
    else if (e.charCode == 32) {
      keyEvent(i, 62);
    }
    else {
      here = window.location.href.split("/");
      here.pop();
      here = here.join("/");
      url=here+"/touch?device=$who&text="+String.fromCharCode(e.charCode);
      window.frames["stdout"].location=url;
    }
    document.bumped = 3; // Slower autorefresh for typing.
    return true;
}
function keyEvent(i, e) {
    here = window.location.href.split("/");
    here.pop();
    here = here.join("/");
    url=here + "/touch?device=$who&key="+e;
    window.frames["stdout"].location=url;
    document.bumped = 3;
    return true;
}
function rotate(i) {
    i = document.getElementById("screen");
    w = (i.width/2) + 'px';
    h = (i.height/2) + 'px';
    i.style.webkitTransform='translate(-'+w+',-'+h+') ' +
                            'rotate(90deg) ' +
                            'translate('+w+',-'+h+')'; 
}
function interval() {
  if (document.bumped > 0) {
    document.bumped = document.bumped - 1;
    if (document.bumped == 0) {
      screen = document.getElementById("screen");
      screen.src = screen.src.split("#")[0] + "#" + new Date();
    }
  }
}
function maybeRotate(image) {
  if (window.location.hash == "#90deg") {
    rotate(image);   
  }
}
setInterval(interval, 500);
</script>
<h1 style="color: red">$::banner</h1>
<iframe height=500 width=100 align=left id=stdout name=stdout></iframe><br>
<input type="button" value="home" onclick="keyEvent(this, 3)">
<input type="button" value="menu" onclick="keyEvent(this, 82)">
<input type="button" value="back" onclick="keyEvent(this, 4)">
<input type="button" value="power" onclick="keyEvent(this, 26)">
<input type="text" id="textEntry" value="Type here" onkeypress="keyPress(this, event)" onkeydown="keyPress(this, event)">
<input type="button" value="refresh 0deg" onclick="window.location='$myself#0deg'; window.location.reload()">
<input type="button" value="refresh 90deg" onclick="window.location='$myself#90deg'; window.location.reload()">
<br>
<img id="screen" style="border:5px dotted grey" draggable="false"
  onmousedown="mouseDown(this, event)"
  onmouseup="mouseUp(this,event)"
  onload="maybeRotate(this)"
  src="/screenshot?device=$who">
<script type="text/javascript">
  document.getElementById("textEntry").focus();
</script>
END
      print $cgi->end_html;
  }

  sub resp_touch {
      my $cgi  = shift;   # CGI.pm object
      return if !ref $cgi;
      
      my $who = $cgi->param('device');
 
      my $coords = $cgi->param('coords');
      my $up = $cgi->param('swipe');
      my $down = $cgi->param('down');
      my $text = $cgi->param('text');
      my $key = $cgi->param('key');

      warn "coords $coords  up $up  down $down ".$cgi->query_string();

      print $cgi->header,
            $cgi->start_html("$who");

# http://blog.softteco.com/2011/03/android-low-level-shell-click-on-screen.html
      if ($coords =~ /\?(\d+),(\d+)$/) {
          my $cmd = "adb -s $who shell input tap $1 $2";
          warn $cmd;
          print `$cmd`;
          print $cmd;
      }
      if ($text eq ' ') {
        $text = undef; $key = 62;
      }
      if ($text) {
          my $cmd = "adb -s $who shell input text $text";
          warn $cmd;
          print `$cmd`;
          print $cmd;
      }
      if ($key) {
          my $cmd = "adb -s $who shell input keyevent $key";
          warn $cmd;
          print `$cmd`;
          print $cmd;
      }
      if ("$down$up" =~ /\?(\d+),(\d+)\?(\d+),(\d+)$/) {
          my $cmd = ($1 == $3 and $2 == $4)
            ? "adb -s $who shell input tap $1 $2"
            : "adb -s $who shell input swipe $1 $2 $3 $4";
          warn $cmd;
          print `$cmd`;
          print $cmd;
      }
  }

  sub resp_screenshot {
      my $cgi  = shift;   # CGI.pm object
      return if !ref $cgi;
      
      my $who = $cgi->param('device');

      my $cmd = "adb -s $who  shell screencap -p";
      warn "RUNNING $cmd";
      $image = `$cmd`;
      $image =~ s/\r\n/\n/g;
      $image =~ s/^\* daemon not running\. starting it now on port \d+ \*\s+\* daemon started successfully \*\s+//;
      print $cgi->header( -type => 'image/png' ), $image;
  }

  sub resp_killServer {
      my $cgi  = shift;   # CGI.pm object
      return if !ref $cgi;
      
      my $cmd = "adb kill-server";
      warn "RUNNING $cmd";
      $image = $cmd.`$cmd`;
      print $cgi->header,
            $cgi->start_html("$who"), $image;
  }
}

# start the server on $port
if ($foreground) {
  print "Ctrl-C to interrupt the server\n";
  MyWebServer->new($port)->run();
}
else {
  my $pid = MyWebServer->new($port)->background();
  print "Use 'kill $pid' to stop server running on port $port.\n";
}
