ElixirCmdView = require './elixir-cmd-view'
path = require 'path'
fs = require 'fs'
module.exports =
  elixirCmdView: null

  activate: (state) ->
    return unless fs.existsSync("#{atom.project.getPath()}/mix.exs")
    @elixirCmdView = new ElixirCmdView(state.elixirCmdViewState)
    atom.workspaceView.on 'core:cancel core:close', (event) =>
      @elixirCmdView?.close()

  deactivate: ->
    if @elixirCmdView
      @elixirCmdView.destroy()
      atom.workspaceView.off 'core:cancel core:close'

  serialize: ->
    elixirCmdViewState: @elixirCmdView?.serialize()
