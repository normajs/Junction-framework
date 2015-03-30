
Through = require "through"
Fs = require "fs"
Path = require "path"
Buffer = require("buffer").Buffer
Handlebars = require "handlebars"
Dss = require "dss"
Norma = require "normajs"
File = require "vinyl"
Crypto = require "crypto"


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



module.exports = (template) ->

  template or= "index.html"

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
    config = Norma.config()
    tmpl = Fs.readFileSync Path.join(__dirname, "./default.handlebars"), {
      encoding: "utf8"
    }

    try
      html = Handlebars.compile(tmpl)({
        project: config
        files: contents
      })
    catch e
      Norma.emit "error", e

    if html

      joinedPath = Path.join(firstFile.base, template);

      templateFile = new File({
        cwd: firstFile.cwd
        base: firstFile.base
        path: joinedPath
        contents: new Buffer html
      })

      @.emit("data", templateFile)

    @.emit "end"


  return Through read, end
