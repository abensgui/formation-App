module.exports = {
  default: {
    require: ["steps/**/*.js"],
    paths: ["features/**/*.feature"],
    format: ["progress", "allure-cucumberjs/reporter"],
    formatOptions: {
      resultsDir: "allure-results",
    },
  },
};
