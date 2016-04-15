require 'socket'

def weechat_init
  Weechat.register("bterm", "Baku", "1.0", "BSD", "BTerm integration", "", "")

  Weechat.hook_signal("irc_notify_join", "online_cb", "")
  Weechat.hook_signal("irc_notify_quit", "offline_cb", "")
  Weechat.hook_signal("irc_notify_away", "offline_cb", "")
  Weechat.hook_signal("irc_pv", "pv_cb", "")
  Weechat.hook_signal("weechat_highlight", "highlight_cb", "")

  return Weechat::WEECHAT_RC_OK
end

def write(what)
  file = '/tmp/bterm.socket'
  return if file.nil?

  begin
    socket = UNIXSocket.open file
  rescue
    socket = -1
  end

  if socket == -1
    return
  end

  socket.write "notify #{what}"
  socket.close
end

def online_cb(a, b, c)
  c = c.split(',')
  write "#{c[1]} is online"
  return Weechat::WEECHAT_RC_OK
end

def offline_cb(a, b, c)
  c = c.split(',')
  write "#{c[1]} is offline"
  return Weechat::WEECHAT_RC_OK
end

def pv_cb(a, b, c)
  c = c[1..-1] if c[0] == ':'
  who = c.split('!')[0]
  write "#{who} is talking"
  return Weechat::WEECHAT_RC_OK
end

def highlight_cb(a, b, c)
  who = c.split("\t")[0]
  write "#{who} is talking"
  return Weechat::WEECHAT_RC_OK
end
