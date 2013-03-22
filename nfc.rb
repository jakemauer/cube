require 'nfc'

NFC.instance.find do |tag|
  p tag.uid.class
end


