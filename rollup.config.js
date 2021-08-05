import resolve from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import json from "@rollup/plugin-json";
export default [
  {
    input: `build/index.js`,
    output: {
      format: "cjs",
      file: `dist/bundle_doricimagepicker.js`,
      sourcemap: true,
    },
    plugins: [resolve({ mainFields: ["jsnext"] }), commonjs(), json()],
    external: ["reflect-metadata", "doric"],
    onwarn: function (warning) {
      if (warning.code === "THIS_IS_UNDEFINED") {
        return;
      }
      console.warn(warning.message);
    },
  },
];
