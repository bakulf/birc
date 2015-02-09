#!/usr/bin/env ruby

=begin
  birc - a wrapper for weechat for bterm
=end

require 'rubygems'
require 'optparse'
require 'socket'
require "gtk2"
require "vte.so"
require "yaml"

class BIrc
  def run(options)
    @mutex = Mutex.new
    @showUI = false
    @clients = []

    @usocket_file = '/tmp/birc.socket'
    exit if check_usocket
    create_usocket

    @options = options;

    @bterm_configuration = [
      { :key => 'audible_bell', :func => 'set_audible_bell', :type => :boolean },
      { :key => 'visible_bell', :func => 'set_visible_bell', :type => :boolean },
      { :key => 'scroll_background', :func => 'set_scroll_background', :type => :boolean },
      { :key => 'scroll_on_output', :func => 'set_scroll_on_output', :type => :boolean },
      { :key => 'scrollback_lines', :func => 'set_scrollback_lines', :type => :integer },
      { :key => 'scroll_on_keystroke', :func => 'set_scroll_on_keystroke', :type => :boolean },
      { :key => 'color_dim', :func => 'set_color_dim', :type => :color },
      { :key => 'color_bold', :func => 'set_color_bold', :type => :color },
      { :key => 'color_foreground', :func => 'set_color_foreground', :type => :color },
      { :key => 'color_background', :func => 'set_color_background', :type => :color },
      { :key => 'colors', :internal => true, :func => 'set_colors', :type => :string },
      { :key => 'color_cursor', :func => 'set_color_cursor', :type => :color },
      { :key => 'color_highlight', :func => 'set_color_highlight', :type => :color },
      { :key => 'background_opacity', :func => 'set_background_opacity', :type => :float },
      { :key => 'background_transparent', :func => 'set_background_transparent', :type => :boolean },
      { :key => 'cursor_blinks', :func => 'set_cursor_blinks', :type => :boolean },
      { :key => 'font', :func => 'set_font', :type => :string },
      { :key => 'backspace_binding', :func => 'set_backspace_binding', :internal => true, :type => :string },
      { :key => 'delete_binding', :func => 'set_delete_binding', :internal => true, :type => :string },
      { :key => 'word_chars', :func => 'set_word_chars', :type => :string },
      { :key => 'mouse_autohide', :func => 'set_mouse_autohide', :type => :boolean }
    ]
    @window = Gtk::Window.new("BIrc - a wrapper for weechat");

    @window.fullscreen if options[:fullscreen]
    @window.decorated = false if options[:fullscreen]

    read_config

    colormap = @window.screen.rgba_colormap
    @window.set_colormap @window.screen.rgba_colormap if not colormap.nil?

    if not options[:fullscreen]
      @window.signal_connect("size-allocate") do |widget, a|
        filename = ENV['HOME'] + '/.birc.yml'
        file = File.open filename, 'w'
        file.write "# Don't edit this file. It's auto-generated.\n"
        file.write "birc:\n"
        file.write "  width: #{a.width}\n"
        file.write "  height: #{a.height}\n"
        file.close
      end
    end

    @window.signal_connect("destroy") do |widget|
      destroy
    end

    terminal = Vte::Terminal.new
    terminal.signal_connect("child-exited") do |widget|
      destroy
    end

    terminal.signal_connect("window-title-changed") do |widget|
      @window.title = widget.window_title
    end

    terminal.signal_connect("resize-window") do |widget, width, height|
      puts "#{width} #{height}"
    end

    filename = ENV['HOME'] + '/.bterm.yml'
    @settings = read_bterm_config filename if File.exist? filename
    @bterm_configuration.each do |c|
      next if @settings.nil? or @settings[c[:key]].nil?

      value =
        if c[:type] == :boolean
          @settings[c[:key]] ? true : false
        elsif c[:type] == :color
          @settings[c[:key]] = Gdk::Color.parse(@settings[c[:key]])
        elsif c[:type] == :float
          @settings[c[:key]] = @settings[c[:key]].to_f
        elsif c[:type] == :integer
           @settings[c[:key]] = @settings[c[:key]].to_i
        else
           @settings[c[:key]]
        end

      if c.include? :internal and c[:internal] == true
        send(c[:func], terminal, value)
      else
        terminal.send(c[:func], value)
      end
    end

    options = { :argv => [ 'birc', '-e' ] }
    terminal.fork_command options

    terminal.show
    @window.add terminal
    terminal.grab_focus

    GLib::Timeout.add 200 do
      returnValue = true
      @mutex.lock
      if @showUI
        returnValue = show
        @showUI = false
      end
      @mutex.unlock
      returnValue
    end

    ag = Gtk::AccelGroup.new
    ag.connect(Gdk::Keyval.from_name('Escape'), nil, Gtk::ACCEL_VISIBLE) do
      time = Time.now.to_i
      hide if not @time.nil? and time - @time <= 1
      @time = time
    end

    ag.connect(Gdk::Keyval.from_name('Escape'), Gdk::Window::SHIFT_MASK, Gtk::ACCEL_VISIBLE) do
      time = Time.now.to_i
      destroy if not @time.nil? and time - @time <= 1
      @time = time
    end
    @window.add_accel_group(ag)

    icon = Gtk::StatusIcon.new
    icon.set_file("/usr/share/pixmaps/birc/birc.png")
    icon.set_title("Birc");
    @statusIcon = icon

    icon.signal_connect("activate") do |widget|
      @window.show
      @window.present
    end

    @window.show_all
    Gtk.main
  end

private
  def check_usocket
    begin
      socket = UNIXSocket.open @usocket_file
      return false if socket == -1
    rescue
      return false
    end

    socket.write "show"
    puts "BIrc already running. Let's open it."
    return true
  end

  def create_usocket
    @thr = Thread.new do
      File.unlink @usocket_file if File.exists? @usocket_file
      socket = UNIXServer.open @usocket_file
      if socket == -1
        puts "Error creating the unixsocket!"
        exit
      end

      while 1 do
        client = socket.accept
        line = client.recv 1024
        line = line.strip
        if line == 'show'
          @mutex.lock
          @showUI = true
          @mutex.unlock
          client.close
        elsif line == 'cb'
          @mutex.lock
          @clients.push client
          @mutex.unlock
        else
          client.close
        end
      end
    end
  end

  def read_config
    filename = ENV['HOME'] + '/.birc.yml'
    return if not File.exist? filename

    config = YAML.load_file(filename)
    return if config == false or config.nil? or config['birc'].nil?

    @window.resize config['birc']['width'], config['birc']['height'] if not @options[:fullscreen]
  end

  def read_bterm_config(configfile)
    config = YAML.load_file(configfile)
    return nil if config == false or config.nil? or config['bterm'].nil?
    return config['bterm']
  end

  def set_colors(terminal, what)
    colors = []
    what.split(':').each do |c|
      colors.push(Gdk::Color.parse(c))
    end

    terminal.set_colors(@settings['color_foreground'],
                        @settings['color_background'], colors);
  end

  def set_backspace_binding(terminal, what)
    if what == 'ASCII_DELETE'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::ASCII_DELETE
    elsif what == 'ASCII_BACKSPACE'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::ASCII_BACKSPACE
    elsif what == 'AUTO'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::AUTO
    elsif what == 'DELETE_SEQUENCE'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::DELETE_SEQUENCE
    elsif what == 'TTY'
      terminal.set_backspace_binding Vte::Terminal::EraseBinding::TTY
    end
  end

  def set_delete_binding(terminal, what)
    if what == 'ASCII_DELETE'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::ASCII_DELETE
    elsif what == 'ASCII_BACKSPACE'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::ASCII_BACKSPACE
    elsif what == 'AUTO'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::AUTO
    elsif what == 'DELETE_SEQUENCE'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::DELETE_SEQUENCE
    elsif what == 'TTY'
      terminal.set_delete_binding Vte::Terminal::EraseBinding::TTY
    end
  end

  def show
    return false if @window.nil?

    @window.show
    @window.present
    true
  end

  def hide
    @window.hide
    windowHiddenCallback
  end

  def windowHiddenCallback
    @mutex.lock

    @clients.each do |c|
      write_socket c, "hidden\n"
    end

    @mutex.unlock
  end

  def destroyCallback
    @mutex.lock

    @clients.each do |c|
      ret = write_socket c, "destroy\n"
      c.close if ret == true
    end

    @mutex.unlock
  end

  def write_socket(c, what)
    begin
      c.send what, 0
      return true
    rescue
    end

    @clients.delete c
    return false
  end

  def destroy
    if not @statusIcon.nil?
      @statusIcon.visible = false
      @statusIcon = nil
    end

    @window.destroy
    @window = nil

    windowHiddenCallback
    quit
  end

  def quit
    destroyCallback

    Gtk.main_quit
    File.unlink @usocket_file if File.exists? @usocket_file
  end
end

options = {
  :fullscreen => false
}

opts = OptionParser.new do |opts|
  opts.banner = "Usage: birc [options]"
  opts.version = '0.1'

  opts.separator ""
  opts.separator "Options:"

  opts.on('-f', '--fullscreen', 'Fullscreen enabled') do
    options[:fullscreen] = true
  end

  opts.on('-e', '--exec', 'Exec weechat directly') do
    options[:exec] = true
  end

  opts.on('-h', '--help', 'Display this screen.') do
    puts opts
    exit
  end

  opts.separator ""
  opts.separator "BSD license - Andrea Marchesini <baku@ippolita.net>"
  opts.separator ""
end

# I don't want to show exceptions if the params are wrong:
begin
  opts.parse!
rescue
  puts opts
  exit
end

if options[:exec] == true
  ENV['TERM'] = 'xterm-256color'
  exec 'weechat'
end

birc = BIrc.new
birc.run options