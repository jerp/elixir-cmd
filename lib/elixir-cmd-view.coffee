{View, BufferedProcess, $$} = require 'atom'
AnsiFilter = require 'ansi-to-html'

elixirModule = /^((?:[A-Z][a-zA-Z0-9_-]*)(?:\.[A-Z][a-zA-Z0-9_-]*)*)$/
elixirModuleFunction = /^((?:[A-Z][a-zA-Z0-9_-]*)(?:\.[A-Z][a-zA-Z0-9_-]*)*)\.([a-z][a-zA-Z0-9_-]*)$/
kernelFunction = /^([a-z][a-zA-Z0-9_-]*)/

# Functions for escaping and unescaping strings to/from HTML interpolation.
# List of HTML entities for escaping.
escape = (() ->
  escaping =
    "&": "&amp;"
    "<": "&lt;"
    ">": "&gt;"
    "\"": "&quot;"
    "'": "&#x27;"
    "`": "&#x60;"
  replacer= (match) -> escaping[match]
  reString = "(?:" + (for k of escaping then k).join("|") + ")"
  reTest = RegExp(reString)
  reMatch = RegExp(reString, "g")
  return (string) ->
    string = (if not string? then "" else "" + string)
    if reTest.test(string)
      string.replace(reMatch, replacer)
    else string)()

# Runs a portion of a script through an interpreter and displays it line by line
module.exports =
class ElixirCmdView extends View
  @bufferedProcess: null

  @content: ->
    @div =>
#      @subview 'headerView', new HeaderView()

      # Display layout and outlets
      css = 'tool-panel panel panel-bottom padding elixir-cmd-view
        native-key-bindings'
      @div class: css, outlet: 'script', tabindex: -1, =>
        @div class: 'panel-body padded output', outlet: 'output'

  initialize: (serializeState, @runOptions) ->
    # Bind commands
    atom.workspaceView.command 'elixir-cmd:build', => @buildProject()
    atom.workspaceView.command 'elixir-cmd:test', => @testProject()
    atom.workspaceView.command 'elixir-cmd:doc', => @keywordDocumentation()
    atom.workspaceView.command 'elixir-cmd:kill-process', => @stop()

    @ansiFilter = new AnsiFilter

  serialize: ->

  buildProject: ->
    @resetView()
    @saveAll()
    @run 'mix', ['compile']

  testProject: ->
    @resetView()
    @saveAll()
    @run 'mix', ['test']

  keywordDocumentation: ->
    return unless (kw=@keywordGet())?
    args = ['-S', 'mix', 'run', '-e']
    switch
      when matches=kw.match elixirModule
        [_matching, moduleName] = matches
        @resetView()
        args.push "require IEx\nApplication.put_env(:iex, :colors, [enabled: true])\nIEx.Introspection.h(#{moduleName})"
      when matches=kw.match elixirModuleFunction
        [_matching, moduleName, functionName] = matches
        @resetView()
        args.push "require IEx\nApplication.put_env(:iex, :colors, [enabled: true])\nIEx.Introspection.h(#{moduleName}, :#{functionName})"
      when matches=kw.match kernelFunction
        [_matching, functionName] = matches
        @resetView()
        args.push "require IEx\nApplication.put_env(:iex, :colors, [enabled: true])\nIEx.Introspection.h(Kernel, :#{functionName})"
      else return
    @run 'elixir', args

  keywordGet:  ->
    editor    = atom.workspace.getActiveEditor()
    selection = editor.getSelection().getText()

    return selection if selection

    scopes       = editor.getCursorScopes()
    currentScope = scopes[scopes.length - 1]

    # Use the current cursor scope if available. If the current scope is a
    # string, comment or not available, get the current word under the cursor.
    # Ignore: comment (any), string (any), meta (html), markup (md).
    if scopes.length > 1 && !/^(?:comment|string|meta|markup)(?:\.|$)/.test(currentScope)
      range = editor.bufferRangeForScopeAtCursor(currentScope)
    else
      range = editor.getCursor().getCurrentWordBufferRange()
    start = range.start.column
    range.start.column = 0
    text = editor.getTextInBufferRange(range)
    validNameChars = /[a-zA-Z]/
    while start>1 and text.charAt(start-1) == "." and validNameChars.test(text.charAt(start-2))
      start-=1
      while start > 0 and validNameChars.test(text.charAt(start-1)) then start-=1
    text.slice(start, range.end.column)

  keywordExtendLeft: (range) ->



  resetView: (title = 'Loading...') ->
    # Display window and load message

    # First run, create view
    atom.workspaceView.prependToBottom this unless @hasParent()

    # Close any existing process and start a new one
    @stop()

    # Get script view ready
    @output.empty()

  saveAll: ->
    atom.project.buffers.forEach (buffer) -> buffer.save() if buffer.isModified()

  close: ->
    # Stop any running process and dismiss window
    @stop()
    @detach() if @hasParent()

  handleError: (err) ->
    # Display error and kill process
    @output.append err
    @stop()

  run: (command, args, stdout = (output) => @display 'stdout', output) ->
#    atom.emit 'achievement:unlock', msg: 'Homestar Runner'

    # Default to where the user opened atom
    options =
      cwd: @getCwd()
      env: process.env

    stderr = (output) => @display 'stderr', output
    exit = (returnCode) =>
      console.log "Exited with #{returnCode}"

    # Run process
    @bufferedProcess = new BufferedProcess({
      command, args, options, stdout, stderr, exit
    })

    @bufferedProcess.process.on 'error', (nodeError) =>
      @output.append $$ ->
        @h1 'Unable to run'
        @pre escape command
        @h2 'Is it on your path?'
        @pre "PATH: #{escape process.env.PATH}"

  getCwd: ->
    atom.project.getPath()

  stop: ->
    # Kill existing process if available
    if @bufferedProcess? and @bufferedProcess.process?
      @display 'stdout', '^C'
      @bufferedProcess.kill()

  display: (css, line) ->
    line = escape(line)
    line = @ansiFilter.toHtml(line)

    @output.append $$ ->
      @pre class: "line #{css}", =>
        @raw line
