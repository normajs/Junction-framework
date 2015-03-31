
HTTP = require "http"
Fs = require "fs"
Path = require "path"
Querystring = require "querystring"
Url = require "url"

Through = require "through"
Dss = require "dss"
Crypto = require "crypto"
Norma = require "normajs"


# handle variables
Dss.parser "variable", (i, line, block, css) ->

  fileVariables = {}
  fileVariablesRx = /^[\$|@]([a-zA-Z0-9_-]+):([^\;]+)\;/gim
  lineSplitRx = /((\s|-\s)+)/
  variables = {}

  hash = Crypto.createHash('md5').update(css).digest('hex')

  if !fileVariables[hash]
    while (match = fileVariablesRx.exec(css)) != null
      variables[match[1].trim()] = match[2].trim()
    fileVariables[hash] = variables

  # Extract name and any delimiter with description
  tokens = line.split(lineSplitRx, 2)
  name = tokens[0].trim()

  if variables.hasOwnProperty(name)
    return {
      name: name
      description: line.replace(tokens.join(""), "")
      value: variables[name]
      markup:
        example: "$#{name}"
    }
  return

makeDescription = (name) ->
  return Dss.parser(name, (i, line, block, file) ->
    parameter = line.split(' - ')
    return {
      name: if (parameter[0]) then Dss.trim(parameter[0]) else ''
      description: if (parameter[1]) then Dss.trim(parameter[1]) else ''
    }
  )

descriptive = [
  "parameter"
  "bugs"
]

makeDescription(item) for item in descriptive


makeBlock = (name) ->
  return Dss.parser(name, (i, line, block, file) ->
    # taken from dss.markup

    # find the next instance of a parser (if there is one based on the @ symbol)
    # in order to isolate the current multi-line parser

    ###

      Warning! bad/weird code follows!

      In order to handle sass (which uses @ symbols in directives)
      while still breaking between parser tags, I did this
      weird regex lookup and counting method. Sadly my regex skills are
      quite awful so this could be WAY better with someone smarter than
      me

    ###
    # remove all prior comments
    smallBlock = block.split("").splice(i - 1).join("")
    # split into indiviual lines for cleaning
    smallBlock = smallBlock.split("\n")
    # remove first whitespace character of each line
    for _line, index in smallBlock
      smallBlock[index] = _line.substring(1, _line.length)
    # rebuild into block

    smallBlock = smallBlock.join("\n")

    # set finalChunk to chunk for early returns
    finalChunk = smallBlock


    console.log "checking #{name}..."

    _filter = (chunk, index) ->

      match = chunk.match /[\t\f ]\@/gm

      if not match
        # safe to split normally
        console.log "@#{name} is safe to split"

        nextParserIndex = chunk.indexOf('@', index)

        markupLength = if nextParserIndex > -1 then nextParserIndex else chunk.length

        return markupLength


      currentTotal = 1
      for _match, index in match
        oldTotal = chunk.indexOf("@", currentTotal)
        currentTotal = chunk.indexOf("@", oldTotal + 1)

      markupLength = currentTotal - 1
      return markupLength



    _chunkSize = _filter smallBlock, 1
    finalChunk = smallBlock.split("").splice(1, _chunkSize - 1).join("")

    markup = finalChunk

    markup = do (markup) ->
      ret = []
      lines = markup.split('\n')
      lines.forEach (line) ->
        pattern = '*'
        index = line.indexOf(pattern)
        if index > 0 and index < 10
          line = line.split('').splice(index + pattern.length, line.length).join('')
        # multiline
        if lines.length <= 2
          line = Dss.trim(line)

        if line and line != "@#{name}"
          ret.push line
        return
      ret.join '\n'

    obj =
      example: markup

    if name is "markup"
      obj.escaped = markup.replace(/</g, '&lt;').replace(/>/g, '&gt;')

    return obj

  )

findBlocks = [
  "css"
  "scss"
  "markup"
]

makeBlock(item) for item in findBlocks


# # Replace link with HTML wrapped version
# Dss.parser(
#   "link"
#   (i, line, block) ->
#
#
#     exp = /https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)/
#
#     return line.replace exp, (match) ->
#       return match
# )

makePlain = (_string) ->
  return Dss.parser(_string, (i, line, block) ->
    return line
  )

plainReturns = [
  "complex-object"
  "block"
  "element"
  "modifier"
  "mixin"
  "link"
]

makePlain(item) for item in plainReturns

module.exports = (dest) ->

  dest or= "localhost:3000/api/v1/blocks"

  firstFile = null
  contents = null

  read = (file) ->

    if file.isNull()
      return

    if file.isStream()

      Norma.emit "error", new Error("Streams are not supported.")

      return

    parseOptions = {}

    Dss.parse file.contents.toString(), parseOptions, (dssFile) ->

      console.log dssFile.blocks

      isBlank = (dssFile) ->
        dssFile.blocks.length == 0

      isValid = (block) ->
        return block.name isnt undefined

      firstFile or= file
      contents or= []

      dssFile.blocks = (blocks for blocks in dssFile.blocks if isValid)

      if isBlank(dssFile)
        return

      dssFile["file"] = Path.basename file.path

      contents.push dssFile


    return


  end = ->

    Norma.log "updating application..."

    loc = Url.parse dest


    options =
      hostname: loc.hostname
      path: loc.path
      method: "POST"
      headers:
        "Content-Type": "application/json"

    if loc.port
      options.port = Number loc.port

    req = HTTP.request options, (res) ->
      res.setEncoding 'utf8'
      res.on 'data', (chunk) ->
        Norma.log "updated app with: #{chunk}"
        return
      return


    req.write JSON.stringify contents

    req.end()


    @.emit "end"




  return Through read, end
