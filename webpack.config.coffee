module.exports = (options) ->
  path              = require 'path'
  webpack           = require 'webpack'
  ExtractTextPlugin = require 'extract-text-webpack-plugin'
  HtmlWebpackPlugin = require 'html-webpack-plugin'
  CompressionPlugin = require 'compression-webpack-plugin'
  connectConstants  = require './connect-constants'
  tcConstants       = require './tc-constants'

  { dirname, entry, template } = options

  dirname = dirname || __dirname

  TEST  = false
  BUILD = false
  isTC  = process.argv.filter (arg) -> arg == '--tc'
  SITE  = if isTC then 'TC' else 'CONNECT'
  ENV   = process.env.ENV || if isTC then 'DEV' else 'MOCK'

  process.argv.forEach (arg) ->
    TEST  = true   if arg == '--test'
    BUILD = true   if arg == '--build'

    ENV = 'DEV'    if arg == '--dev'
    ENV = 'QA'     if arg == '--qa'
    ENV = 'PROD'   if arg == '--prod'

  if SITE == 'CONNECT'
    envConstants = connectConstants(ENV)
  else if SITE == 'TC'
    envConstants = tcConstants(ENV)

  console.log 'Assigning the following constants to process.env:'
  console.log envConstants
  console.log '\n'

  Object.assign process.env, envConstants

  # Reference: http://webpack.github.io/docs/configuration.html
  config         = {}
  config.context = dirname

  # Reference: http://webpack.github.io/docs/configuration.html#entry
  if TEST && !entry
    config.entry = {}
  else if entry
    config.entry = entry
  else
    config.entry = path.join dirname, '/example/example.coffee'

  # Reference: http://webpack.github.io/docs/configuration.html#output
  if TEST
    config.output = {}
  else
    config.output =
      path          : path.join(dirname, '/dist')
      filename      : '[name].[hash].js'
      chunkFilename : '[name].[hash].js'

  # Reference: http://webpack.github.io/docs/configuration.html#devtool
  if TEST
    config.devtool = 'inline-source-map'
  else if BUILD
    config.devtool = 'source-map'
  else
    config.devtool = 'eval'

  # Reference: http://webpack.github.io/docs/configuration.html#module-loaders
  # List: http://webpack.github.io/docs/list-of-loaders.html
  config.module =
    preLoaders: []
    loaders: [
      test: /\.js$/
      loader: 'babel'
      exclude: /node_modules\/(?!appirio-tech.*)/
      include: path.join dirname, '..'
      query:
        presets: [ 'es2015', 'react' ]
    ,
      test: /input\-moment/
      loader: 'babel'
      query:
        presets: [ 'es2015', 'react' ]
    ,
      test: /^(?!.*\.react\.jade$)(.*\.jade$)/
      loader: 'jade'
    ,
      test: /\.react\.jade$/
      loader: 'jade-react'
    ,
      test: /\.jader$/
      loader: 'jade-react'
    ,
      test: /\.coffee|litcoffee|cjsx$/
      loader: 'babel?presets[]=react,presets[]=es2015!coffee!cjsx'
    ,
      test: /\.json$/
      loader: 'json'
    ,
      test: /\.scss$/
      loader: ExtractTextPlugin.extract 'style-loader', 'css-loader!sass-loader'
    ,
      test: /\.css$/
      loader: ExtractTextPlugin.extract 'style-loader', 'css-loader'
    ,
      # ASSET LOADER
      # Reference: https:#github.com/webpack/file-loader
      # Copy png, jpg, jpeg, gif, svg, woff, woff2, ttf, eot files to output
      # Rename the file using the asset hash
      # Pass along the updated reference to your code
      # You can add here any file extension you want to get copied to your output
      test: /\.(png|jpg|jpeg|gif)$/
      loader: 'file'
    ,
      test: /\.woff(2)?(\?v=[0-9]\.[0-9]\.[0-9])?$/
      loader: 'file'
    ,
      test: /\.(ttf|eot|svg)(\?v=[0-9]\.[0-9]\.[0-9])?$/
      loader: 'file'
    ]
    postLoaders: [
      test: /\.js|\.coffee|\.cjsx$/
      loader: 'transform/cacheable?envify'
    ]

  config.resolveLoader =
    root: path.join dirname, '/node_modules/'

  config.resolve =
    root: path.join dirname, '/node_modules/'
    modulesDirectories: ['node_modules']
    extensions: [
      ''
      '.js'
      '.json'
      '.coffee'
      '.jade'
      '.jader'
      '.scss'
      '.svg'
      '.png'
      '.gif'
      '.jpg'
      '.cjsx'
    ]

  config.sassLoader =
    includePaths: [
      path.join dirname, '/node_modules/bourbon/app/assets/stylesheets'
      path.join dirname, '/node_modules/appirio-styles/styles'
    ]


  # Reference: http://webpack.github.io/docs/configuration.html#plugins
  # List: http://webpack.github.io/docs/list-of-plugins.html
  config.plugins = []

  config.plugins.push new ExtractTextPlugin '[name].[hash].css'

  if !TEST
    config.plugins.push new HtmlWebpackPlugin
      template: template || './example/index.html'
      inject: 'body'
      favicon: options.favicon
      NEW_RELIC_APPLICATION_ID: process.env.NEW_RELIC_APPLICATION_ID

  if BUILD
    # Reference: http://webpack.github.io/docs/list-of-plugins.html#noerrorsplugin
    # Only emit files when there are no errors
    config.plugins.push new webpack.NoErrorsPlugin()

    # Reference: http://webpack.github.io/docs/list-of-plugins.html#dedupeplugin
    # Dedupe modules in the output
    config.plugins.push new webpack.optimize.DedupePlugin()

    config.plugins.push new webpack.optimize.UglifyJsPlugin
      mangle:
        except: ['Auth0']

    config.plugins.push new CompressionPlugin
      asset: "{file}",
      algorithm: "gzip",
      regExp: /\.js$|\.css$/,
      threshold: 10240,
      minRatio: 0.8

  config
