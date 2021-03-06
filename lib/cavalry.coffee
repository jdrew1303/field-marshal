model = require '../lib/model.coffee'
util = require '../lib/util.coffee'
request = require 'request'
SECRET = process.env.CAVALRYPASS or "testingpass"
CAVALRY_PORT = parseInt process.env.CAVALRYPORT
CAVALRY_PORT = 3000 if isNaN(CAVALRY_PORT)

parseJSON = (str) ->
  try
    str = JSON.parse str
  catch err
  return str

Cavalry = ->
  @slaveUrl = (slave) ->
   "http://#{model.slaves[slave].ip}:#{CAVALRY_PORT}"
  @postJSON = (arg, slave, opts, cb) ->
    url = "#{@slaveUrl(slave)}/#{arg}"
    request
      json: opts
      auth:
        user: "master"
        pass: SECRET
      url: url
    , (error, response, body) ->
      body = parseJSON body
      cb error, body
  @getJSON = (arg, slave, cb) ->
    url = "#{@slaveUrl(slave)}/#{arg}"
    request.get
      url: url
      auth:
        user: "master"
        pass: SECRET
    , (error, response, body) ->
      body = parseJSON body
      cb error, body
  @spawn = (slave, opts, cb) =>
    @postJSON "#{util.apiVersion}/spawn", slave, opts, cb
  @exec = (slave, opts, cb) =>
    @postJSON "#{util.apiVersion}/exec", slave, opts, cb
  @stop = (slave, opts, cb) =>
    @postJSON "#{util.apiVersion}/stop", slave, opts, cb
  @restart = (slave, opts, cb) =>
    @postJSON "#{util.apiVersion}/restart", slave, opts, cb
  @fetch = (slave, opts, cb) =>
    @postJSON "fetch", slave, opts, cb
  @port = (slave, cb) =>
    @getJSON "port", slave, cb
  @ps = (slave, cb) ->
    @getJSON "ps", slave, cb
  @sendRouting = (slave, table, cb) =>
    @postJSON "routingTable", slave, table, cb

  return this

cavalry = new Cavalry()
module.exports = cavalry
