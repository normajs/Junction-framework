Template.complexObjects.onCreated ->

  @.subscribe "blocks"


Template.complexObjects.helpers

  complexObjects: ->

    complexObjects = Blocks.find(
      "complex-object": "true"
      "class":
        $exists: true
    ).fetch()

    console.log complexObjects

    filteredObjects = []

    for _object in complexObjects
      if _object.block is _object.class
        filteredObjects.push _object
        continue

      if _object.element is _object.class
        parent = _.findWhere(complexObjects, {block : _object.block})
        parent.element = _object
        continue

    return filteredObjects


Template.complexObjects.onRendered ->
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
