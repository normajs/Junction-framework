Blocks = new Mongo.Collection "blocks"
Files = new Mongo.Collection "files"


api = {}

api["/api/v1/blocks"] =

    post: (data) ->

      data = JSON.parse data.toString()

      for block in data
        file = block.file

        for parts, index in block.blocks by -1
          for item of parts
            if not parts[item]
              delete parts[item]

          # delete empty item
          if not Object.keys(parts).length
            block.blocks.splice(index, 1)
            # console.log index
            continue

          parts.file = block.file

          Blocks.upsert(
            name: parts.name
            parts
          )


        if block.blocks.length is 0
          Blocks.remove(
            file: file
          )
          Files.remove(
            name: file
          )
          continue


        Files.upsert(
          name: file
          {
            name: file
          }
        )

        # Remove any blocks that are no longer in file
        existingBlocks = Blocks.find({file: file}).fetch()

        for _exists, index in existingBlocks by -1
          for _inFile in block.blocks
            if _inFile.name is _exists.name
              existingBlocks.splice(index, 1)
              continue

        if existingBlocks.length
          for _item in existingBlocks
            Blocks.remove(_item._id)



      return "success"

HTTP.methods api
