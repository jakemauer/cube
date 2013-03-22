#!/usr/bin/env ruby
# encoding: utf-8

require 'ffi'
require 'logger'

module Spotify
  extend FFI::Library

  ffi_lib "spotify"

  enum :sp_connectionstate, [ :logged_out, :logged_in, :disconnected, :undefined, :offline ]

  attach_function :sp_session_process_events, [ :pointer, :pointer ], :int
  attach_function :sp_session_create, [ :pointer, :pointer ], :int
  attach_function :sp_session_login, [ :pointer, :pointer, :pointer, :bool, :pointer ], :int
  attach_function :sp_session_connectionstate, [ :pointer ], :sp_connectionstate
  attach_function :sp_session_playlistcontainer, [ :pointer ], :pointer
  attach_function :sp_playlistcontainer_is_loaded, [ :pointer ], :bool

  class SessionConfig < FFI::Struct
    layout api_version: :int,
           cache_location: :pointer,
           settings_location: :pointer,
           application_key: :pointer,
           application_key_size: :size_t,
           user_agent: :pointer,
           callbacks: :pointer,
           userdata: :pointer,
           compress_playlists: :bool,
           dont_save_metadata_for_playlists: :bool,
           initially_unload_playlists: :bool,
           device_id: :pointer,
           proxy: :pointer,
           proxy_username: :pointer,
           proxy_password: :pointer,
           ca_certs_filename: :pointer,
           tracefile: :pointer
  end
end

def process_events(session)
  ptr = FFI::MemoryPointer.new(:int)
  ptr.autorelease = false
  Spotify.sp_session_process_events(session, ptr)
  return Rational(ptr.read_int, 1000)
end

def poll(session)
  until yield
    process_events(session)
    sleep(0.01)
  end
end

def env(name)
  ENV.fetch(name) { raise "Missing ENV['#{name}']." }
end

config = Spotify::SessionConfig.new
config[:api_version] = 12
appkey = IO.read("./spotify_appkey.key", encoding: "BINARY")
config[:application_key] = FFI::MemoryPointer.from_string(appkey).tap { |ptr| ptr.autorelease = false }
config[:application_key_size] = appkey.bytesize
config[:cache_location] = FFI::MemoryPointer.from_string(".spotify/").tap { |ptr| ptr.autorelease = false }
config[:settings_location] = FFI::MemoryPointer.from_string(".spotify/").tap { |ptr| ptr.autorelease = false }
config[:tracefile] = FFI::MemoryPointer.from_string("spotify_tracefile.txt").tap { |ptr| ptr.autorelease = false }
config[:user_agent] = FFI::MemoryPointer.from_string("spotify for ruby").tap { |ptr| ptr.autorelease = false }
config[:callbacks] = FFI::Pointer::NULL

puts "Size: #{Spotify::SessionConfig.size}"
Spotify::SessionConfig.members.each do |member|
  puts "Offset of #{member}: #{Spotify::SessionConfig.offset_of(member)}"
end

config.pointer.autorelease = false

puts "Creating session."
session = nil
FFI::MemoryPointer.new(:pointer) do |ptr|
  error = Spotify.sp_session_create(config, ptr)
  abort "Error: #{Spotify.sp_error_message(error)}" if error != 0
  ptr.autorelease = false
  session = ptr.read_pointer
end

puts "Created! Logging in."
username = FFI::MemoryPointer.from_string(env("SPOTIFY_USERNAME")).tap { |ptr| ptr.autorelease = false }
password = FFI::MemoryPointer.from_string(env("SPOTIFY_PASSWORD")).tap { |ptr| ptr.autorelease = false }
Spotify.sp_session_login(session, username, password, false, FFI::Pointer::NULL)

puts "Log in requested. Waiting forever until logged in."
poll(session) { Spotify.sp_session_connectionstate(session) == :logged_in }

# This part is what makes the process crash at times.
puts "Loading playlist container…"
container = Spotify.sp_session_playlistcontainer(session)
poll(session) { Spotify.sp_playlistcontainer_is_loaded(container) }

puts "Container loaded! Exiting in 4…"

sleep 4