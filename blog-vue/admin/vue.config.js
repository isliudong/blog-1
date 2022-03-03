module.exports = {
  productionSourceMap: false,
  devServer: {
    proxy: {
      "/api": {
        target: "http://50.158.17.182:9090",
        changeOrigin: true,
        pathRewrite: {
          "^/api": ""
        }
      }
    },
    disableHostCheck: true
  },
  chainWebpack: config => {
    config.resolve.alias.set("@", resolve("src"));
  }
};

const path = require("path");
function resolve(dir) {
  return path.join(__dirname, dir);
}
