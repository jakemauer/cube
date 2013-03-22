# puts 'hello'
require 'nfc'
require 'hallon'
require 'hallon-openal'



# songs = {
#   "spotify:track:1mxqozpIELFEnfwEzTdjLs" : 
# }

# spotify:track:6rpueTXRoz00kWOCNhHeSP - A Bad Place 
# spotify:track:1mxqozpIELFEnfwEzTdjLs - Surfer Blood

session = Hallon::Session.initialize(IO.read('./spotify_appkey.key'))
session.login!('jakemauer', 'spifK@m1nsk1')



track = Hallon::Track.new("spotify:track:6rpueTXRoz00kWOCNhHeSP")
track.load

puts track

player = Hallon::Player.new(Hallon::OpenAL)
#puts player
puts "ready"
NFC.instance.find do |tag|
  player.play!(track)
end


