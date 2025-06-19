module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2021, // 最新の JavaScript 機能をサポート
    sourceType: "module", // ES Modules をサポート
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "max-len": ["warn", {"code": 120, "ignoreComments": true, "ignoreStrings": true}],
    "require-jsdoc": "off", // Google スタイルガイドのルールを無効化
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
