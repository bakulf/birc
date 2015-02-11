require 'socket'

@window = nil
@thread = nil

def birc
  system 'birc -f &'
  check_thread
end

def window_created(window)
  @window = window
end

def check_thread
  if @thread.nil?
    @thread = Thread.new do
      while 1 do
        if not File.exist? '/tmp/birc.socket'
          sleep 1
          next
        end

        begin
          socket = UNIXSocket.open '/tmp/birc.socket'
        rescue
          socket = -1
        end

        break if socket != -1
        sleep 1
      end

      socket.send 'cb', 0

      while 1 do
        begin
          line = socket.recv 1024
        rescue
          line = 'destroy'
        end

        line.strip.split("\n").each do |l|
          l = l.strip
          if l == 'hidden'
            @window.show
            @window.present
          elsif l == 'destroy'
            socket.close
            @thread = nil
          end
        end

        break if @thread.nil?
      end
    end
  end
end

check_thread
@@bterm.register_hooks :window_created, method(:window_created)
