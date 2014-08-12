{WorkspaceView} = require 'atom'
ElixirCmd = require '../lib/elixir-cmd'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "ElixirCmd", ->
  activationPromise = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('elixir-cmd')

  describe "when the elixir-cmd:toggle event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(atom.workspaceView.find('.elixir-cmd')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.workspaceView.trigger 'elixir-cmd:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.elixir-cmd')).toExist()
        atom.workspaceView.trigger 'elixir-cmd:toggle'
        expect(atom.workspaceView.find('.elixir-cmd')).not.toExist()
