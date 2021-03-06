path = require 'path'
{spawnSync} = require 'child_process'
{BufferedProcess} = require 'atom'

getFlowCommand = ->
  #TODO Can we do better than this?
  if atom.config.get('ide-flow.flowPath') is ""
    _flowCommand = spawnSync('which', ['flow']).stdout.toString()
    if _flowCommand is ""
      console.error "Could not find a 'flow' binary on your PATH, go to package settings and set 'Flow Path'"
    else
      atom.config.set 'ide-flow.flowPath', _flowCommand
  return atom.config.get('ide-flow.flowPath')

run = ({onMessage, onComplete, onFailure, args, cwd, input}) ->
  options = if cwd then { cwd: cwd } else {}

  bufferedprocess = new BufferedProcess
    command: getFlowCommand()
    args: args
    options: options
    stdout: (data) ->
      console.debug data
      onMessage data
    stderr: (data) ->
      console.debug data
    exit: -> onComplete?()

  if input
    bufferedprocess.process.stdin.end(input)

  # on error hack (from http://discuss.atom.io/t/catching-exceptions-when-using-bufferedprocess/6407)
  bufferedprocess.process.on 'error', (node_error) ->
    # TODO this error should be in output view log tab
    console.error "Flow utility not found at '/Users/lukeh/Downloads/flow/flow'"
    onFailure?()

  bufferedprocess

runSync = ({args, cwd, input}) ->
    options = if cwd then { cwd: cwd } else {}
    if input
      options.input = input

    done = spawnSync getFlowCommand(), args, options
    console.debug done?.stdout.toString()
    done?.stdout

module.exports =

  startServer: ->
    editor = atom.workspace.activePaneItem
    filename = editor.getPath()
    dir = path.dirname filename
    process = run
      args: [ 'server', '--lib', 'lib' ]
      cwd: dir
      onMessage: (output) ->
    process

  check: ({fileName, onResult, onComplete, onFailure, onDone})->
    dir = path.dirname fileName
    if !@servers then @servers = {}
    if !@servers[dir] then @servers[dir] = @startServer()
    process = run
      args: [ '--json' ]
      cwd: dir
      onMessage: (output) ->
        result = JSON.parse output
        onResult result

  typeAtPos: ({fileName, bufferPt, text, onResult, onComplete, onFailure, onDone}) ->
    run
      args: ['type-at-pos', bufferPt.row + 1, bufferPt.column + 1, '--json', '--path', fileName]
      cwd: path.dirname fileName
      input: text
      onMessage: (output) ->
        result = JSON.parse output
        onResult result

  getDef: ({fileName, bufferPt, onResult, onComplete, onFailure, onDone}) ->
    run
      args: ['get-def', fileName, bufferPt.row + 1, bufferPt.column + 1, '--json']
      cwd: path.dirname fileName
      onMessage: (output) ->
        result = JSON.parse output
        onResult result

  autocomplete: ({fileName, bufferPt, text, onResult, onComplete, onFailure, onDone}) ->
    run
      args: ['autocomplete', fileName, bufferPt.row + 1, bufferPt.column + 1, '--json']
      cwd: path.dirname fileName
      input: text
      onMessage: (output) ->
        result = JSON.parse output
        onResult result

  autocompleteSync: ({fileName, bufferPt, text}) ->
    output = runSync
      args: ['autocomplete', fileName, bufferPt.row + 1, bufferPt.column + 1, '--json']
      cwd: path.dirname fileName
      input: text
    result = JSON.parse output
    result
