const path = require('path')
const webpack = require('webpack')
const { CheckerPlugin } = require('awesome-typescript-loader')
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CleanWebpackPlugin = require('clean-webpack-plugin')
const CopyWebpackPlugin = require('copy-webpack-plugin')

// Since Webpack will be run directly within Phoenix, we'll use the `MIX_ENV`
// variable instead of `NODE_ENV`.
const env = process.env.MIX_ENV === 'prod' ? 'production' : 'development'

const plugins = {
  production: [],
  development: []
}

module.exports = {
  mode: env,
  devtool: 'source-map',
  entry: [
    path.join(__dirname, 'assets/js/app.tsx'),
    path.join(__dirname, 'assets/scss/app.scss')
  ],
  output: {
    path: path.join(__dirname, '/priv/static'),
    filename: 'js/app.js'
  },
  module: {
    rules: [
      {
             test: /\.mjs$/,
             include: /node_modules/,
             type: 'javascript/auto'
      },
      {
        test: /\.tsx?$/,
        use: [
            {
                loader: 'awesome-typescript-loader',
                options: {
                    "useBabel": true,
                    "babelCore": "@babel/core"
                },
            }

        ],
        include: path.join(__dirname, 'assets/js'),
        exclude: /node_modules/
      },
      {
        test: /\.scss$/,
        use: [
          MiniCssExtractPlugin.loader,
          'css-loader',
          'postcss-loader',
          'sass-loader',
        ]
      },
      {
        test: /\.(png|woff|woff2|eot|ttf|svg|jpg)$/,
        use: [
          {
            loader: 'url-loader',
            options: {
              limit: 10000,
              outputPath: 'images/',
            }
          }
        ]
      }
    ]
  },
  // optimization: {
  //   splitChunks: {
  //     cacheGroups: {
  //       styles: {
  //         name: 'styles',
  //         test: /\.css$/,
  //         chunks: 'all',
  //         enforce: true
  //       }
  //     }
  //   }
  //},
  plugins: [
    new CleanWebpackPlugin(),
    // Type checker for `awesome-typescript-loader`
    new CheckerPlugin(),
    // Add this plugin so Webpack won't output the files when anything errors
    // during the build process
    new webpack.NoEmitOnErrorsPlugin(),
    new MiniCssExtractPlugin({
      // Options similar to the same options in webpackOptions.output
      // both options are optional
      filename: "css/app.css",
    }),
    new CopyWebpackPlugin([
      { from: path.join(__dirname, 'assets', 'static') }
    ])
  ].concat(plugins[env]),
  resolve: {
    modules: [
      'node_modules',
      'assets/js'
    ],
    // Add '.ts' and '.tsx' as resolvable extensions.
    extensions: ['.ts', '.tsx', '.js', '.json'],
    alias: {
      phoenix: path.join(__dirname, '/deps/phoenix/priv/static/phoenix.js'),
      phoenix_html: path.join(__dirname, '/deps/phoenix_html/priv/static/phoenix_html.js')
    }
  }
}
