fs = require 'fs'
path = require 'path'
model = require '../lib/model.coffee'
cavalry = require '../lib/cavalry.coffee'

manifestDir = path.resolve __dirname, '..', 'manifest'
Surveyor = ->
  @getManifest = (cb) ->
    manifest = {}
    fs.readdir manifestDir, (err, files) ->
      errs = null
      parts = 0
      for file in files
        parts++
        do (file) ->
          fs.readFile path.join(manifestDir, file), (err, data) ->
            try
              parsed = JSON.parse data
            catch e
              errs = [] if !errs?
              errs.push {file: file, error: e}
            for name, data of parsed
              if manifest[name]?
                errs = [] if !errs?
                errs.push "#{name} is duplicated"
              manifest[name] = data
            parts--
            model.manifest = manifest
            cb errs if parts is 0
  @ps = (cb) ->
    ps = {}
    errs = []
    jobs = 0
    for slave of model.slaves
      jobs++
      do (slave) ->
        cavalry.ps slave, (err, procs) ->
          errs.push err if err?
          ps[slave] = procs
          jobs--
          cb errs, ps if jobs is 0
  @buildRequired = (cb) ->
    for repo, repoData of model.manifest
      if repoData.instances is '*'
        required = repoData.required = []
        for slave, slaveData of model.slaves
          present = false
          for pid, procData of slaveData.processes
            present = true if procData.repo is repo and procData.status is 'running' and procData.commit is repoData.opts.commit
          required.push slave unless present
      else
        running = 0
        for slave, slaveData of model.slaves
          for pid, procData of slaveData.processes
            running++ if procData.repo is repo and procData.status is 'running' and procData.commit is repoData.opts.commit
        repoData.delta = repoData.instances - running
    cb()
  @sortSlaves = ->
    ([k, v.load] for k, v of model.slaves).sort (a,b) ->
      a[1] - b[1]
    .map (n) -> n[0]
  @populateOptions = (slave, opts, cb) ->
    opts = JSON.parse JSON.stringify opts
    required = {}
    errs = null
    required.port = true if opts.env? and opts.env.PORT is "RANDOM_PORT"
    checkDone = ->
      cb errs, opts if Object.keys(required).length is 0
    checkDone()
    if required.port
      cavalry.port slave, (err, res) ->
        if err?
          errs = [] if !errs?
          errs.push {slave: slave, err: err}
        opts.env.PORT = res.port
        delete required.port
        checkDone()

  @spawnMissing = (cb) =>
    errs = null
    procs = {}
    numProcs = 0
    checkDone = (slave, err, proc) ->
      numProcs--
      if err?
        errs = [] if !errs?
        errs.push {slave: slave, err: err}
      else
        for pid, data of proc
          procs[pid] = data
      cb errs, procs if numProcs is 0

    for repo, repoData of model.manifest
      if repoData.required?
        numProcs += repoData.required.length
        for slave in repoData.required
          do (slave) =>
            @spawn slave, repoData.opts, checkDone
      else if repoData.delta > 0
        numProcs += repoData.delta
        while repoData.delta > 0
          target = @sortSlaves()[0]
          target.load += repoData.load
          repoData.delta--
          do (target) =>
            @spawn target, repoData.opts, checkDone
  @spawn = (slave, opts, cb) ->
    @populateOptions slave, opts, (err, opts) ->
      return checkDone slave, err, null if err?
      cavalry.spawn slave, opts, (err, res) ->
        cb slave, err, res
  @updatePortMap = (slave, opts, pid) ->
    if opts.env? and opts.env.PORT?
      model.portMap ?= {}
      model.portMap[slave] ?= {}
      model.portMap[slave][pid] =
        repo: opts.name
        port: opts.env.PORT
        commit: opts.commit

  return this

surveyor = new Surveyor()
module.exports = surveyor
