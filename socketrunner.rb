require 'rubygems'
require 'daemons'

begin
  Daemons.run('websock.rb')
rescue
  return
end
