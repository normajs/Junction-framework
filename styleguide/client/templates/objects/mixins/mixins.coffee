Template.mixins.onCreated ->

  @.subscribe "blocks"


Template.mixins.helpers

  mixins: ->

    mixins = Blocks.find(
      "mixin": "true"
    ).fetch()

    return mixins



Template.mixins.onRendered ->
  self = @

  self.autorun(_.bind( ->
    # set up cursor in autorun
    blocks = Blocks.find()

    # preform a look up when data is ready to flush tracker
    blocks.forEach((post) -> return)

    # all data should be rendered so highlightBlock
    Tracker.afterFlush(_.bind(->
      @.$("pre code").each (i, block) ->
        hljs.highlightBlock block
        return
    ), @)
  ), self)
