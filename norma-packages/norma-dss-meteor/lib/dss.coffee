
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

# Replace link with HTML wrapped version
Dss.parser(
  "link"
  (i, line, block) ->


    exp = /https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)/

    return line.replace exp, (match) ->
      return '<a href="' + match + '">' + match + '</a>'
)



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
